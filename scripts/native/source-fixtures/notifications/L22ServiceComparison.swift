#if DEBUG
import Foundation
import CryptoKit
import JohnCore

public struct L22ServiceObservation: Codable, Sendable {
    public let name: String
    public let passed: Bool
    public let detail: String
}

public struct L22ServiceReport: Codable, Sendable {
    public let sourceFixtureSHA256: String
    public let observations: [L22ServiceObservation]
    public let expectedObservationCount: Int
    public let passed: Bool

    public init(sourceFixtureSHA256: String, observations: [L22ServiceObservation], expectedObservationCount: Int = 25) {
        self.sourceFixtureSHA256 = sourceFixtureSHA256
        self.observations = observations
        self.expectedObservationCount = expectedObservationCount
        self.passed = observations.count == expectedObservationCount && observations.allSatisfy(\.passed)
    }
}

/// Compares the production service with executed TypeScript fixture output.
/// The helper uses injected centers and data. It does not call the OS center.
@MainActor
public enum L22ServiceComparison {
    public static func run(
        sourceFixtureURL: URL,
        readCalendars: @escaping LocalNoticeService.CalendarReader
    ) async throws -> L22ServiceReport {
        let sourceData = try Data(contentsOf: sourceFixtureURL)
        let root = try JSONSerialization.jsonObject(with: sourceData) as? [String: Any]
        let calendar = root?["calendar"] as? [String: Any]
        let plans = calendar?["plans"] as? [[String: Any]] ?? []
        guard plans.count == 14 else { throw FixtureError.invalid("expected 14 calendar plans") }

        var results: [L22ServiceObservation] = []
        for plan in plans {
            let name = plan["name"] as? String ?? "unnamed-plan"
            let zoneID = plan["timezone"] as? String ?? ""
            let zone = TimeZone(identifier: zoneID)
            let nowString = (plan["now"] as? [String: Any])?["iso"] as? String ?? ""
            guard let zone, let instant = parseDate(nowString) else {
                results.append(.init(name: name, passed: false, detail: "invalid source time or zone"))
                continue
            }
            let hour = plan["hour"] as? Int ?? 8
            let minute = plan["minute"] as? Int ?? 0
            let expected = plan["items"] as? [[String: Any]] ?? []
            let center = FixtureNoticeCenter()
            var committed = NativePersistentState()
            let service = LocalNoticeService(
                center: center,
                now: { instant },
                timeZone: { zone },
                readCommitted: { committed },
                readCalendars: readCalendars,
                commit: { mutation in
                    if case let .setCalendarNotifications(value) = mutation {
                        committed = NativePersistentState(calendarNotifications: value)
                    }
                }
            )
            do {
                _ = try await service.saveCalendar(.init(enabled: true, hour: hour, minute: minute))
                let actual = center.added.compactMap(Self.calendarItem).sorted { $0.identifier < $1.identifier }
                let expectedItems = expected.compactMap(Self.sourceCalendarItem).sorted { $0.identifier < $1.identifier }
                let pass = actual == expectedItems && actual.count == (plan["count"] as? Int ?? -1)
                results.append(.init(name: name, passed: pass,
                    detail: pass ? "\(actual.count) exact requests" : "expected \(expectedItems.count), observed \(actual.count)"))
            } catch {
                let noPlanError: Bool
                if let noticeError = error as? LocalNoticeError,
                   case .noCalendarDates = noticeError {
                    noPlanError = true
                } else {
                    noPlanError = false
                }
                let noPlanIsExpected = (plan["count"] as? Int) == 0 && expected.isEmpty && noPlanError
                results.append(.init(name: name, passed: noPlanIsExpected,
                    detail: noPlanIsExpected ? "source and native report no upcoming dates" : "service threw \(error.localizedDescription)"))
            }
        }

        results.append(contentsOf: await nativeContractObservations(readCalendars: readCalendars))
        return L22ServiceReport(sourceFixtureSHA256: sha256(sourceData), observations: results)
    }

    private static func nativeContractObservations(
        readCalendars: @escaping LocalNoticeService.CalendarReader
    ) async -> [L22ServiceObservation] {
        var output: [L22ServiceObservation] = []
        let zone = TimeZone(identifier: "America/Toronto")!
        let instant = parseDate("2026-10-06T11:00:00.000Z")!

        for (name, frequency, weekday, components) in [
            ("unchanged-daily-components", "daily", 2, DateComponents(hour: 20, minute: 0)),
            ("unchanged-weekly-components", "weekly", 2, DateComponents(hour: 20, minute: 0, weekday: 2)),
        ] {
            var parts = components
            parts.calendar = Calendar(identifier: .gregorian)
            parts.timeZone = zone
            let id = "legacy-reminder-id"
            let request = NoticeRequest(identifier: id, title: "A quiet moment for the Rosary",
                body: "Take a few minutes to pray with Mary and contemplate the life of Christ.",
                userInfo: ["url": "/pray/rosary"],
                trigger: .calendarComponents(parts, repeats: true))
            let center = FixtureNoticeCenter(requests: [request])
            let initial = NativePersistentState(rosaryReminder: .init(enabled: true, frequency: frequency,
                hour: 20, minute: 0, weekday: weekday, notificationID: id))
            let service = LocalNoticeService(center: center, now: { instant }, timeZone: { zone },
                readCommitted: { initial }, readCalendars: readCalendars, commit: { _ in })
            do {
                _ = try await service.saveRosary(initial.rosaryReminder)
                let passed = center.added.isEmpty && center.removed.isEmpty && center.requests == [request]
                output.append(.init(name: name, passed: passed,
                    detail: "system calendar-components request is retained without a remove/add cycle"))
            } catch {
                output.append(.init(name: name, passed: false, detail: error.localizedDescription))
            }
        }

        let unrelated = NoticeRequest(identifier: "unrelated-request", title: "Other feature", body: "Keep me",
            userInfo: ["url": "/other"], trigger: .interval(seconds: 3_600, repeats: false))
        let importedID = "source-imported-rosary-id"
        let oldImportedRequest = NoticeRequest(identifier: importedID, title: "A quiet moment for the Rosary",
            body: "Take a few minutes to pray with Mary and contemplate the life of Christ.",
            userInfo: ["url": "/pray/rosary"],
            trigger: .daily(hour: 19, minute: 0, timeZoneIdentifier: zone.identifier))
        let importCenter = FixtureNoticeCenter(requests: [unrelated, oldImportedRequest])
        let importedState = NativePersistentState(rosaryReminder: .init(enabled: true, frequency: "daily",
            hour: 19, minute: 0, notificationID: importedID))
        let importService = LocalNoticeService(center: importCenter, now: { instant }, timeZone: { zone },
            readCommitted: { importedState }, readCalendars: readCalendars, commit: { _ in })
        do {
            let saved = try await importService.saveRosary(.init(enabled: true, frequency: "daily", hour: 21,
                minute: 10, weekday: 2))
            let passed = saved.notificationID == importedID &&
                importCenter.requests.contains(where: { $0.identifier == unrelated.identifier }) &&
                importCenter.requests.contains(where: { $0.identifier == importedID && $0.trigger == .daily(hour: 21, minute: 10, timeZoneIdentifier: zone.identifier) })
            output.append(.init(name: "imported-id-and-unrelated-request-preserved", passed: passed,
                detail: "the source ID remains and unrelated requests stay pending"))
        } catch {
            output.append(.init(name: "imported-id-and-unrelated-request-preserved", passed: false, detail: error.localizedDescription))
        }

        // Permission wait crosses today's delivery time. Planning must use the later clock value.
        var clock = parseDate("2026-10-06T11:59:00.000Z")!
        let delayedCenter = FixtureNoticeCenter(onRequestAuthorization: { clock = parseDate("2026-10-06T12:01:00.000Z")! })
        var delayedState = NativePersistentState()
        let delayedService = LocalNoticeService(center: delayedCenter, now: { clock }, timeZone: { zone },
            readCommitted: { delayedState }, readCalendars: readCalendars, commit: { mutation in
                if case let .setCalendarNotifications(value) = mutation {
                    delayedState = NativePersistentState(calendarNotifications: value)
                }
            })
        do {
            _ = try await delayedService.saveCalendar(.init(enabled: true, hour: 8, minute: 0))
            let noPast = delayedCenter.added.allSatisfy {
                guard case let .calendarDate(date, _) = $0.trigger else { return false }
                return date > clock
            }
            output.append(.init(name: "permission-delay-replans-from-current-time", passed: noPast,
                detail: "all planned deliveries follow the clock after permission returns"))
        } catch {
            output.append(.init(name: "permission-delay-replans-from-current-time", passed: false, detail: error.localizedDescription))
        }

        // A failed durable commit must restore the full request value captured before removal.
        let original = NoticeRequest(identifier: LocalNoticeService.rosaryIdentifier, title: "Original title",
            body: "Original body", userInfo: ["url": "/original", "typed": "value"], sound: .none,
            trigger: .daily(hour: 19, minute: 15, timeZoneIdentifier: zone.identifier))
        let rollbackCenter = FixtureNoticeCenter(requests: [original])
        let originalSettings = NativePersistentState(rosaryReminder: .init(enabled: true, frequency: "daily",
            hour: 19, minute: 15, notificationID: LocalNoticeService.rosaryIdentifier))
        let rollbackService = LocalNoticeService(center: rollbackCenter, now: { instant }, timeZone: { zone },
            readCommitted: { originalSettings }, readCalendars: readCalendars,
            commit: { _ in throw FixtureError.injected("commit") })
        do {
            _ = try await rollbackService.saveRosary(.init(enabled: true, frequency: "weekly", hour: 20,
                minute: 0, weekday: 2, notificationID: LocalNoticeService.rosaryIdentifier))
            output.append(.init(name: "commit-failure-restores-original-request", passed: false, detail: "expected commit failure"))
        } catch {
            let restored = rollbackCenter.restored.last
            let passed = restored == original && rollbackCenter.requests.contains(original)
            output.append(.init(name: "commit-failure-restores-original-request", passed: passed,
                detail: passed ? "restore received original request values" : "original request was not restored"))
        }

        let partialCenter = FixtureNoticeCenter()
        partialCenter.status = .authorized
        partialCenter.failAddAt = 2
        var partialState = NativePersistentState()
        let partialStateBefore = partialState
        var partialCommitCount = 0
        let partialService = LocalNoticeService(center: partialCenter, now: { instant }, timeZone: { zone },
            readCommitted: { partialState }, readCalendars: readCalendars, commit: { mutation in
                partialCommitCount += 1
                if case let .setCalendarNotifications(value) = mutation {
                    partialState = NativePersistentState(calendarNotifications: value)
                }
            })
        do {
            _ = try await partialService.saveCalendar(.init(enabled: true, hour: 8, minute: 0))
            output.append(.init(name: "partial-calendar-add-restores-exact-initial-state", passed: false,
                detail: "expected failure on the second add"))
        } catch let error as LocalNoticeError {
            if case .transactionFailed = error {
                let passed = partialCenter.requests.isEmpty && partialCenter.added.count == 2 &&
                    partialCommitCount == 0 && partialState == partialStateBefore
                output.append(.init(name: "partial-calendar-add-restores-exact-initial-state", passed: passed,
                    detail: "first add succeeded; rollback restored empty pending state; no state commit ran"))
            } else {
                output.append(.init(name: "partial-calendar-add-restores-exact-initial-state", passed: false, detail: error.localizedDescription))
            }
        } catch {
            output.append(.init(name: "partial-calendar-add-restores-exact-initial-state", passed: false, detail: error.localizedDescription))
        }

        // Calendar catalog failure must not block cleanup of a disabled Rosary request.
        let disabledID = "disabled-rosary-id"
        let cleanupCenter = FixtureNoticeCenter(requests: [unrelated,
            NoticeRequest(identifier: disabledID, title: "Old Rosary", body: "", userInfo: [:],
                trigger: .daily(hour: 20, minute: 0, timeZoneIdentifier: zone.identifier))])
        cleanupCenter.status = .authorized
        let cleanupState = NativePersistentState(
            calendarNotifications: .init(enabled: true, hour: 8, minute: 0),
            rosaryReminder: .init(enabled: false, frequency: "daily", hour: 20, minute: 0,
                weekday: 2, notificationID: disabledID))
        let cleanupService = LocalNoticeService(center: cleanupCenter, now: { instant }, timeZone: { zone },
            readCommitted: { cleanupState },
            readCalendars: { throw FixtureFailure.catalog }, commit: { _ in })
        do {
            try await cleanupService.refresh()
            output.append(.init(name: "calendar-error-does-not-block-disabled-rosary-cleanup", passed: false,
                detail: "expected Calendar refresh error"))
        } catch {
            let passed = cleanupCenter.removed.contains(disabledID) &&
                cleanupCenter.requests.contains(where: { $0.identifier == unrelated.identifier })
            output.append(.init(name: "calendar-error-does-not-block-disabled-rosary-cleanup", passed: passed,
                detail: "Calendar error returned; disabled reminder removed; unrelated request kept"))
        }

        let fifoCenter = FixtureNoticeCenter()
        fifoCenter.status = .authorized
        var fifoState = NativePersistentState(
            calendarNotifications: .init(enabled: true, hour: 8, minute: 0),
            rosaryReminder: .init(enabled: true, frequency: "daily", hour: 20, minute: 0,
                weekday: 2, notificationID: LocalNoticeService.rosaryIdentifier)
        )
        var fifoEvents: [String] = []
        var fifoReadCount = 0
        var fifoCommitCount = 0
        fifoCenter.event = { fifoEvents.append($0) }
        fifoCenter.delayFirstPending = true
        let fifoService = LocalNoticeService(center: fifoCenter, now: { instant }, timeZone: { zone },
            readCommitted: {
                fifoReadCount += 1
                fifoEvents.append("state-read-\(fifoReadCount)")
                return fifoState
            }, readCalendars: readCalendars, commit: { mutation in
                fifoCommitCount += 1
                fifoEvents.append("state-commit-\(fifoCommitCount)")
                if case let .setCalendarNotifications(value) = mutation {
                    fifoState = NativePersistentState(calendarNotifications: value,
                        rosaryReminder: fifoState.rosaryReminder)
                }
                if case let .setRosaryReminder(value) = mutation {
                    fifoState = NativePersistentState(calendarNotifications: fifoState.calendarNotifications,
                        rosaryReminder: value)
                }
            })
        do {
            let calendarSave = Task { @MainActor in
                fifoEvents.append("invoke-calendar-save")
                _ = try await fifoService.saveCalendar(.init(enabled: false))
            }
            await Task.yield()
            let rosarySave = Task { @MainActor in
                fifoEvents.append("invoke-rosary-save")
                _ = try await fifoService.saveRosary(.init(enabled: false))
            }
            await Task.yield()
            let refresh = Task { @MainActor in
                fifoEvents.append("invoke-refresh")
                try await fifoService.refresh()
            }
            _ = try await (calendarSave.value, rosarySave.value, refresh.value)
            let calendarIndex = fifoEvents.firstIndex(of: "invoke-calendar-save") ?? -1
            let rosaryIndex = fifoEvents.firstIndex(of: "invoke-rosary-save") ?? -1
            let refreshIndex = fifoEvents.firstIndex(of: "invoke-refresh") ?? -1
            let firstRead = fifoEvents.firstIndex(of: "state-read-1") ?? -1
            let secondRead = fifoEvents.firstIndex(of: "state-read-2") ?? -1
            let thirdRead = fifoEvents.firstIndex(of: "state-read-3") ?? -1
            let firstPendingStart = fifoEvents.firstIndex(of: "pending-start-1") ?? -1
            let firstPendingEnd = fifoEvents.firstIndex(of: "pending-end-1") ?? -1
            let firstCommit = fifoEvents.firstIndex(of: "state-commit-1") ?? -1
            let secondCommit = fifoEvents.firstIndex(of: "state-commit-2") ?? -1
            let passed = calendarIndex >= 0 && calendarIndex < rosaryIndex && rosaryIndex < refreshIndex &&
                firstRead > calendarIndex && firstRead < secondRead && secondRead < thirdRead &&
                secondRead > rosaryIndex && thirdRead > refreshIndex &&
                firstPendingStart > firstRead && firstPendingEnd > firstPendingStart && firstPendingEnd < secondRead &&
                firstCommit > firstPendingEnd && firstCommit < secondRead && secondCommit > secondRead && secondCommit < thirdRead &&
                fifoReadCount == 3 && fifoCommitCount == 2 && fifoCenter.pendingCallCount == 4 && !fifoCenter.pendingOverlapDetected &&
                fifoEvents.filter { $0.hasPrefix("state-read-") }.count == 3
            output.append(.init(name: "save-and-refresh-follow-invocation-fifo", passed: passed,
                detail: "events: \(fifoEvents.joined(separator: ","))"))
        } catch {
            output.append(.init(name: "save-and-refresh-follow-invocation-fifo", passed: false, detail: error.localizedDescription))
        }

        // A failed rollback query must appear in the returned transaction error.
        let queryCenter = FixtureNoticeCenter(requests: [original])
        queryCenter.failAddAt = 1
        queryCenter.failPendingAfterMutation = true
        let queryService = LocalNoticeService(center: queryCenter, now: { instant }, timeZone: { zone },
            readCommitted: { originalSettings }, readCalendars: readCalendars,
            commit: { _ in throw FixtureError.injected("commit") })
        do {
            _ = try await queryService.saveRosary(.init(enabled: true, frequency: "weekly", hour: 20,
                minute: 0, weekday: 2, notificationID: LocalNoticeService.rosaryIdentifier))
            output.append(.init(name: "rollback-query-failure-is-reported", passed: false, detail: "expected transaction failure"))
        } catch let error as LocalNoticeError {
            if case let .transactionFailed(_, _, failures) = error {
                output.append(.init(name: "rollback-query-failure-is-reported",
                    passed: failures.contains(where: { $0.contains("read pending requests during rollback") }),
                    detail: failures.joined(separator: "; ")))
            } else {
                output.append(.init(name: "rollback-query-failure-is-reported", passed: false, detail: "wrong error type"))
            }
        } catch {
            output.append(.init(name: "rollback-query-failure-is-reported", passed: false, detail: error.localizedDescription))
        }

        let capacityRequests = (0..<62).map { index in
            NoticeRequest(identifier: "unrelated-\(index)", title: "Other", body: "", userInfo: [:],
                trigger: .interval(seconds: 60, repeats: false))
        }
        let capacityCenter = FixtureNoticeCenter(requests: capacityRequests)
        capacityCenter.status = .authorized
        var capacityState = NativePersistentState()
        let capacityService = LocalNoticeService(center: capacityCenter, now: { instant }, timeZone: { zone },
            readCommitted: { capacityState }, readCalendars: readCalendars, commit: { mutation in
                if case let .setCalendarNotifications(value) = mutation {
                    capacityState = NativePersistentState(calendarNotifications: value)
                }
            })
        do {
            _ = try await capacityService.saveCalendar(.init(enabled: true, hour: 8, minute: 0))
            output.append(.init(name: "sixty-two-unrelated-requests-block-calendar-plan", passed: false,
                detail: "expected schedule capacity error"))
        } catch let error as LocalNoticeError {
            if case .scheduleFull = error {
                output.append(.init(name: "sixty-two-unrelated-requests-block-calendar-plan",
                    passed: capacityCenter.requests.count == 62 && capacityCenter.added.isEmpty,
                    detail: "capacity error preserves 62 unrelated pending requests"))
            } else {
                output.append(.init(name: "sixty-two-unrelated-requests-block-calendar-plan", passed: false, detail: error.localizedDescription))
            }
        } catch {
            output.append(.init(name: "sixty-two-unrelated-requests-block-calendar-plan", passed: false, detail: error.localizedDescription))
        }

        let deniedBefore = [original, unrelated]
        let deniedCenter = FixtureNoticeCenter(requests: deniedBefore)
        deniedCenter.status = .denied
        deniedCenter.authorizationResult = .denied
        let deniedState = NativePersistentState(themeScheme: "dark", favoritePrayerIDs: ["source-favorite"],
            rosaryReminder: .init(enabled: false, frequency: "weekly", hour: 7, minute: 5, weekday: 3))
        let deniedStateBefore = deniedState
        var deniedCommitCount = 0
        let deniedService = LocalNoticeService(center: deniedCenter, now: { instant }, timeZone: { zone },
            readCommitted: { deniedState }, readCalendars: readCalendars, commit: { _ in deniedCommitCount += 1 })
        do {
            _ = try await deniedService.saveRosary(.init(enabled: true, frequency: "daily"))
            output.append(.init(name: "native-denial-preserves-committed-and-pending-state", passed: false,
                detail: "expected permission denial"))
        } catch {
            let permissionDenied: Bool
            if let noticeError = error as? LocalNoticeError, case .permissionDenied = noticeError {
                permissionDenied = true
            } else {
                permissionDenied = false
            }
            let passed = permissionDenied && deniedCenter.added.isEmpty && deniedCenter.removed.isEmpty &&
                deniedCenter.requests == deniedBefore && deniedCommitCount == 0 && deniedState == deniedStateBefore
            output.append(.init(name: "native-denial-preserves-committed-and-pending-state", passed: passed,
                detail: "denial makes zero commits and preserves two pending requests and the prior state"))
        }

        return output
    }

    private struct CalendarItem: Equatable {
        let identifier: String
        let title: String
        let body: String
        let url: String
        let milliseconds: Int64
    }

    private static func calendarItem(_ request: NoticeRequest) -> CalendarItem? {
        guard case let .calendarDate(date, _) = request.trigger,
              let url = request.userInfo["url"] else { return nil }
        return CalendarItem(identifier: request.identifier, title: request.title, body: request.body,
            url: url, milliseconds: Int64((date.timeIntervalSince1970 * 1_000).rounded()))
    }

    private static func sourceCalendarItem(_ value: [String: Any]) -> CalendarItem? {
        guard let id = value["identifier"] as? String, let title = value["title"] as? String,
              let body = value["body"] as? String, let url = value["url"] as? String,
              let date = value["date"] as? [String: Any], let milliseconds = date["epochMilliseconds"] as? Int64 else { return nil }
        return CalendarItem(identifier: id, title: title, body: body, url: url, milliseconds: milliseconds)
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private enum FixtureError: Error, LocalizedError {
        case invalid(String)
        case injected(String)
        var errorDescription: String? {
            switch self { case let .invalid(s), let .injected(s): s }
        }
    }
}

private enum FixtureFailure: Error { case catalog }

@MainActor
private final class FixtureNoticeCenter: NoticeCenter {
    var requests: [NoticeRequest]
    var added: [NoticeRequest] = []
    var removed: [String] = []
    var restored: [NoticeRequest] = []
    var status: NoticeAuthorizationStatus = .notDetermined
    var authorizationResult: NoticeAuthorizationStatus = .authorized
    var failAddAt: Int?
    var failPendingAfterMutation = false
    var delayFirstPending = false
    var event: ((String) -> Void)?
    private(set) var pendingCallCount = 0
    private var addCallCount = 0
    private(set) var pendingOverlapDetected = false
    var onRequestAuthorization: (() -> Void)?
    private var pendingFailureTriggered = false
    private var activePendingCalls = 0

    init(requests: [NoticeRequest] = [], onRequestAuthorization: (() -> Void)? = nil) {
        self.requests = requests
        self.onRequestAuthorization = onRequestAuthorization
    }

    func authorizationStatus() async -> NoticeAuthorizationStatus { status }
    func requestAuthorization() async throws -> NoticeAuthorizationStatus {
        onRequestAuthorization?()
        status = authorizationResult
        return status
    }
    func pendingRequests() async throws -> [NoticeRequest] {
        pendingCallCount += 1
        let call = pendingCallCount
        event?("pending-start-\(call)")
        activePendingCalls += 1
        if activePendingCalls > 1 { pendingOverlapDetected = true }
        if delayFirstPending && call == 1 {
            try await Task.sleep(for: .milliseconds(30))
        } else {
            await Task.yield()
        }
        activePendingCalls -= 1
        event?("pending-end-\(call)")
        if failPendingAfterMutation && !removed.isEmpty && !pendingFailureTriggered {
            pendingFailureTriggered = true
            throw FixtureError.pendingQuery
        }
        return requests
    }
    func add(_ request: NoticeRequest) async throws {
        addCallCount += 1
        event?("add-\(addCallCount)")
        added.append(request)
        if failAddAt == addCallCount { throw FixtureError.add }
        requests.removeAll { $0.identifier == request.identifier }
        requests.append(request)
    }
    func restore(_ request: NoticeRequest) async throws {
        event?("restore")
        restored.append(request)
        requests.removeAll { $0.identifier == request.identifier }
        requests.append(request)
    }
    func removePendingRequest(identifier: String) async throws {
        event?("remove")
        removed.append(identifier)
        requests.removeAll { $0.identifier == identifier }
    }

    private enum FixtureError: Error, LocalizedError {
        case add
        case pendingQuery
        var errorDescription: String? {
            switch self {
            case .add: "injected add failure"
            case .pendingQuery: "injected pending query failure"
            }
        }
    }
}
#endif
