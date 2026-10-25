import Foundation
import JohnCore

public struct LocalNoticePlan: Sendable, Equatable {
    public let requests: [NoticeRequest]
    public init(requests: [NoticeRequest]) { self.requests = requests }
}

@MainActor
public final class LocalNoticeService {
    public typealias CalendarReader = @MainActor () async throws -> (ReadingsCalendar, CelebrationsCalendar)
    public typealias StateReader = @MainActor () throws -> NativePersistentState
    public typealias StateCommitter = @MainActor (NativeStateMutation) async throws -> Void

    public static let calendarPrefix = "john-calendar:"
    public static let saintPrefix = "john-saint:"
    public static let rosaryIdentifier = "john-rosary:reminder"
    public static let readingIdentifier = "john-reading:reminder"
    /// "A Year with the Fathers" reminders, one request per day so each names its reading.
    public static let yearPrefix = "john-year:"

    private let center: any NoticeCenter
    private let now: @MainActor () -> Date
    private let timeZone: @MainActor () -> TimeZone
    private let readCommitted: StateReader
    private let readCalendars: CalendarReader
    private let readSaints: @MainActor () async throws -> [SaintsCalendar]
    private let readPersonalSaints: @MainActor () async throws -> [PersonalSaint]
    private let commit: StateCommitter
    private let readReadingReminder: (@Sendable () async -> ReadingReminderSettings?)?
    private let readExcerpt: (@Sendable () async -> String?)?
    private let readYearReminders: (@Sendable () async -> [NoticeRequest])?
    private var operationActive = false
    private var operationWaiters: [CheckedContinuation<Void, Never>] = []

    public init(center: any NoticeCenter,
                now: @escaping @MainActor () -> Date,
                timeZone: @escaping @MainActor () -> TimeZone,
                readCommitted: @escaping StateReader,
                readCalendars: @escaping CalendarReader,
                commit: @escaping StateCommitter,
                readReadingReminder: (@Sendable () async -> ReadingReminderSettings?)? = nil,
                readExcerpt: (@Sendable () async -> String?)? = nil,
                readYearReminders: (@Sendable () async -> [NoticeRequest])? = nil,
                readSaints: @escaping @MainActor () async throws -> [SaintsCalendar] = { [] },
                readPersonalSaints: @escaping @MainActor () async throws -> [PersonalSaint] = { [] }) {
        self.readPersonalSaints = readPersonalSaints
        self.readSaints = readSaints
        self.readExcerpt = readExcerpt
        self.readYearReminders = readYearReminders
        self.readReadingReminder = readReadingReminder
        self.center = center
        self.now = now
        self.timeZone = timeZone
        self.readCommitted = readCommitted
        self.readCalendars = readCalendars
        self.commit = commit
    }

    public func permissionStatus() async -> NoticeAuthorizationStatus {
        await withOperationQueue { await center.authorizationStatus() }
    }

    public func saveCalendar(_ requested: CalendarNotificationSettings) async throws -> CalendarNotificationSettings {
        try await withOperationQueue {
            let committed = try readCommitted()
            let settings = Self.normalize(requested)
            if settings.enabled { try await requirePermission(message: "Allow notifications in your device settings to receive calendar events.") }

            let pending = try await center.pendingRequests()
            let desired = try await devotionalDesired(settings: settings, saints: committed.mySaints, pending: pending)
            try await reconcileAndCommit(
                desired: desired,
                pending: pending,
                owned: Self.ownsDevotional,
                preserveSameIdentifier: false,
                restoreOnlyFutureCalendarRequests: true,
                operation: "Calendar notification update",
                mutation: committed.calendarNotifications == settings ? nil : .setCalendarNotifications(settings)
            )
            return settings
        }
    }

    /// A daily reading reminder (E7). The choice lives in the reading progress file, so no state mutation runs here.
    public func saveReadingReminder(_ requested: ReadingReminderSettings) async throws -> ReadingReminderSettings {
        try await withOperationQueue {
            let settings = ReadingReminderSettings(enabled: requested.enabled,
                                                   hour: min(23, max(0, requested.hour)),
                                                   minute: min(59, max(0, requested.minute)),
                                                   timeSensitive: requested.timeSensitive)
            if settings.enabled {
                try await requirePermission(message: "Notifications are disabled. You can allow them in your device settings.")
            }
            let pending = try await center.pendingRequests()
            let excerpt = await readExcerpt?()
            let desired = settings.enabled ? [Self.readingRequest(settings, excerpt: excerpt, zone: timeZone())] : []
            try await reconcileAndCommit(
                desired: desired,
                pending: pending,
                owned: { $0.identifier == Self.readingIdentifier },
                preserveSameIdentifier: false,
                restoreOnlyFutureCalendarRequests: false,
                operation: "Reading reminder update",
                mutation: nil)
            return settings
        }
    }

    /// The year plan reminders (2.3.0). `desired` is empty when the reminder is off. The choice lives in the reading
    /// progress file, so no state mutation runs here.
    public func saveYearReminders(_ desired: [NoticeRequest], enabled: Bool) async throws {
        try await withOperationQueue {
            if enabled {
                try await requirePermission(message: "Notifications are disabled. You can allow them in your device settings.")
            }
            let pending = try await center.pendingRequests()
            try await reconcileAndCommit(
                desired: enabled ? desired : [],
                pending: pending,
                owned: { $0.identifier.hasPrefix(Self.yearPrefix) },
                preserveSameIdentifier: false,
                restoreOnlyFutureCalendarRequests: false,
                operation: "Year plan reminder update",
                mutation: nil)
        }
    }

    /// The reading reminder. It has a scripture excerpt, the reading category for the actions, and one thread.
    static func readingRequest(_ settings: ReadingReminderSettings, excerpt: String?, zone: TimeZone) -> NoticeRequest {
        let trimmed = excerpt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let body = trimmed.isEmpty ? "Open today’s chapter and read a little." : String(trimmed.prefix(180))
        return NoticeRequest(
            identifier: readingIdentifier,
            title: "Your John reading is ready",
            body: body,
            userInfo: ["url": "/read/john"],
            trigger: .daily(hour: settings.hour, minute: settings.minute, timeZoneIdentifier: zone.identifier),
            interruption: settings.timeSensitive == true ? .timeSensitive : .active,
            category: ReadingNoticeAction.category,
            thread: "john.reading")
    }

    public func saveRosary(_ requested: RosaryReminderSettings) async throws -> RosaryReminderSettings {
        try await withOperationQueue {
            let committed = try readCommitted()
            let previous = committed.rosaryReminder
            let normalized = Self.normalize(requested)
            if normalized.enabled {
                try await requirePermission(message: "Notifications are disabled. You can allow them in your device settings.")
            }
            let identifier = normalized.enabled
                ? (previous.notificationID ?? Self.rosaryIdentifier)
                : nil
            let saved = RosaryReminderSettings(
                enabled: normalized.enabled,
                frequency: normalized.frequency,
                hour: normalized.hour,
                minute: normalized.minute,
                weekday: normalized.weekday,
                notificationID: identifier
            )
            let pending = try await center.pendingRequests()
            let zone = timeZone()
            var desired: [NoticeRequest] = []
            if saved.enabled, let identifier {
                let trigger: NoticeTrigger = saved.frequency == "weekly"
                    ? .weekly(weekday: saved.weekday, hour: saved.hour, minute: saved.minute, timeZoneIdentifier: zone.identifier)
                    : .daily(hour: saved.hour, minute: saved.minute, timeZoneIdentifier: zone.identifier)
                desired = [NoticeRequest(
                    identifier: identifier,
                    title: "A quiet moment for the Rosary",
                    body: "Take a few minutes to pray with Mary and contemplate the life of Christ.",
                    userInfo: ["url": "/pray/rosary"],
                    trigger: trigger
                )]
            }
            let ownedIDs = Set([previous.notificationID, Self.rosaryIdentifier].compactMap { $0 })
            try await reconcileAndCommit(
                desired: desired,
                pending: pending,
                owned: { ownedIDs.contains($0.identifier) },
                preserveSameIdentifier: false,
                restoreOnlyFutureCalendarRequests: false,
                operation: "Rosary reminder update",
                mutation: previous == saved ? nil : .setRosaryReminder(saved)
            )
            return saved
        }
    }

    public func refresh() async throws {
        try await withOperationQueue {
            let committed = try readCommitted()
            let currentPermission = await center.authorizationStatus()
            var failures: [String] = []
            let calendarSettings = committed.calendarNotifications
            do {
                let pending: [NoticeRequest]
                if (calendarSettings.enabled || committed.mySaints.profiles.values.contains { $0.reminderEnabled }), !currentPermission.canDeliver {
                    throw LocalNoticeError.permissionDenied("Allow notifications in device settings to receive feast reminders.")
                }
                pending = try await center.pendingRequests()
                let desired = try await devotionalDesired(settings: calendarSettings, saints: committed.mySaints, pending: pending)
                try await reconcileAndCommit(desired: desired, pending: pending,
                    owned: Self.ownsDevotional, preserveSameIdentifier: false,
                    restoreOnlyFutureCalendarRequests: true, operation: "Calendar refresh", mutation: nil)
            } catch {
                failures.append("Calendar: \(error.localizedDescription)")
            }

            do {
                let reminder = committed.rosaryReminder
                if reminder.enabled, !currentPermission.canDeliver {
                    throw LocalNoticeError.permissionDenied("Notifications are disabled. You can allow them in your device settings.")
                }
                let pending = try await center.pendingRequests()
                let zone = timeZone()
                let identifier = reminder.notificationID ?? Self.rosaryIdentifier
                let rosaryDesired: [NoticeRequest]
                if reminder.enabled {
                let trigger: NoticeTrigger = reminder.frequency == "weekly"
                    ? .weekly(weekday: reminder.weekday, hour: reminder.hour, minute: reminder.minute, timeZoneIdentifier: zone.identifier)
                    : .daily(hour: reminder.hour, minute: reminder.minute, timeZoneIdentifier: zone.identifier)
                rosaryDesired = [NoticeRequest(identifier: identifier,
                    title: "A quiet moment for the Rosary",
                    body: "Take a few minutes to pray with Mary and contemplate the life of Christ.",
                    userInfo: ["url": "/pray/rosary"], trigger: trigger)]
                } else {
                    rosaryDesired = []
                }
                let ownedIDs = Set([reminder.notificationID, Self.rosaryIdentifier].compactMap { $0 })
                let refreshedReminder = reminder.enabled && reminder.notificationID == nil
                    ? RosaryReminderSettings(enabled: true, frequency: reminder.frequency, hour: reminder.hour,
                        minute: reminder.minute, weekday: reminder.weekday, notificationID: identifier)
                    : reminder
                try await reconcileAndCommit(desired: rosaryDesired, pending: pending,
                    owned: { ownedIDs.contains($0.identifier) }, preserveSameIdentifier: false,
                    restoreOnlyFutureCalendarRequests: false, operation: "Rosary refresh",
                    mutation: refreshedReminder == reminder ? nil : .setRosaryReminder(refreshedReminder))
            } catch {
                failures.append("Rosary: \(error.localizedDescription)")
            }
            if let readReadingReminder {
                do {
                    let reading = await readReadingReminder() ?? ReadingReminderSettings()
                    let shouldSchedule = reading.enabled && currentPermission.canDeliver
                    let pending = try await center.pendingRequests()
                    let excerpt = await readExcerpt?()
                    let clamped = ReadingReminderSettings(enabled: reading.enabled, hour: min(23, max(0, reading.hour)),
                                                          minute: min(59, max(0, reading.minute)),
                                                          timeSensitive: reading.timeSensitive)
                    let desired = shouldSchedule ? [Self.readingRequest(clamped, excerpt: excerpt, zone: timeZone())] : []
                    try await reconcileAndCommit(desired: desired, pending: pending,
                        owned: { $0.identifier == Self.readingIdentifier }, preserveSameIdentifier: false,
                        restoreOnlyFutureCalendarRequests: false, operation: "Reading reminder refresh", mutation: nil)
                } catch {
                    failures.append("Reading: \(error.localizedDescription)")
                }
            }
            if let readYearReminders {
                do {
                    let desired = currentPermission.canDeliver ? await readYearReminders() : []
                    let pending = try await center.pendingRequests()
                    try await reconcileAndCommit(desired: desired, pending: pending,
                        owned: { $0.identifier.hasPrefix(Self.yearPrefix) }, preserveSameIdentifier: false,
                        restoreOnlyFutureCalendarRequests: false, operation: "Year plan reminder refresh", mutation: nil)
                } catch {
                    failures.append("Year plan: \(error.localizedDescription)")
                }
            }
            if !failures.isEmpty { throw LocalNoticeError.refreshFailures(failures) }
        }
    }

    public func saveSaint(id: String, profile: SaintProfile) async throws {
        try await withOperationQueue {
            let state = try readCommitted()
            if profile.reminderEnabled {
                try await requirePermission(message: "Allow notifications in device settings to receive feast reminders.")
            }
            var saints = state.mySaints
            saints.profiles[id] = profile
            let pending = try await center.pendingRequests()
            let desired = try await devotionalDesired(settings: state.calendarNotifications, saints: saints, pending: pending)
            try await reconcileAndCommit(desired: desired, pending: pending, owned: Self.ownsDevotional,
                preserveSameIdentifier: false, restoreOnlyFutureCalendarRequests: true,
                operation: "Feast reminder update", mutation: .setSaintProfile(id: id, value: profile))
        }
    }

    private static func ownsDevotional(_ request: NoticeRequest) -> Bool {
        request.identifier.hasPrefix(calendarPrefix) || request.identifier.hasPrefix(saintPrefix)
    }

    /// Reserve every explicitly chosen feast before filling the rolling daily calendar.
    /// At an identical time, the personal feast replaces the general calendar alert.
    private func devotionalDesired(settings: CalendarNotificationSettings, saints: MySaintsState,
                                   pending: [NoticeRequest]) async throws -> [NoticeRequest] {
        let zone = timeZone(), instant = now()
        var personal: [NoticeRequest] = []
        if saints.profiles.values.contains(where: { $0.reminderEnabled }) {
            for saint in try await readPersonalSaints() {
                guard let profile = saints.profiles[saint.id], profile.reminderEnabled,
                      let observance = saint.observance(for: profile),
                      let date = SaintDates.reminderDate(monthDay: observance.monthDay, hour: profile.reminderHour,
                        minute: profile.reminderMinute, after: instant, timeZone: zone) else { continue }
                personal.append(NoticeRequest(identifier: Self.saintPrefix + saint.id,
                    title: "Remember \(saint.name) today",
                    body: "\(observance.calendarName) commemoration. Open prayers and the saint’s life.",
                    userInfo: ["url": "nrsv://saint?id=\(saint.id)&feast=1"],
                    trigger: .calendarDate(date, timeZoneIdentifier: zone.identifier)))
            }
        }
        let capacity = max(0, 62 - pending.filter { !Self.ownsDevotional($0) }.count)
        guard personal.count <= capacity else { throw LocalNoticeError.scheduleFull }
        var daily: [NoticeRequest] = []
        if settings.enabled {
            let calendars = try await readCalendars()
            let catalogs = try await readSaints()
            daily = try makeCalendarPlan(settings, calendars: calendars, saints: catalogs, zone: zone, current: instant).requests
            let times = Set(personal.compactMap { request -> Date? in
                if case let .calendarDate(date, _) = request.trigger { return date }; return nil
            })
            daily.removeAll { if case let .calendarDate(date, _) = $0.trigger { return times.contains(date) }; return false }
            guard capacity > personal.count || !personal.isEmpty else { throw LocalNoticeError.scheduleFull }
            if daily.isEmpty && personal.isEmpty { throw LocalNoticeError.noCalendarDates }
        }
        return personal + daily.prefix(min(30, max(0, capacity - personal.count)))
    }

    public static func normalize(_ value: CalendarNotificationSettings) -> CalendarNotificationSettings {
        CalendarNotificationSettings(enabled: value.enabled,
            hour: (0...23).contains(value.hour) ? value.hour : 8,
            minute: (0...59).contains(value.minute) ? value.minute : 0)
    }

    public static func normalize(_ value: RosaryReminderSettings) -> RosaryReminderSettings {
        RosaryReminderSettings(enabled: value.enabled,
            frequency: value.frequency == "weekly" ? "weekly" : "daily",
            hour: (0...23).contains(value.hour) ? value.hour : 20,
            minute: (0...59).contains(value.minute) ? value.minute : 0,
            weekday: (1...7).contains(value.weekday) ? value.weekday : 2,
            notificationID: value.notificationID)
    }

    private func requirePermission(message: String) async throws {
        let status = await center.authorizationStatus()
        let result = status.canDeliver ? status : try await center.requestAuthorization()
        guard result.canDeliver else { throw LocalNoticeError.permissionDenied(message) }
    }

    private func makeCalendarPlan(_ settings: CalendarNotificationSettings,
                                  calendars: (ReadingsCalendar, CelebrationsCalendar),
                                  saints: [SaintsCalendar],
                                  zone: TimeZone, current: Date) throws -> LocalNoticePlan {
        guard settings.enabled else { return LocalNoticePlan(requests: []) }
        var output: [NoticeRequest] = []
        let calendar = CompanionCalendar.gregorianCalendar(timeZone: zone)
        for offset in 0...30 {
            let localDay = CompanionCalendar.addDays(current, offset, timeZone: zone)
            var components = calendar.dateComponents([.year, .month, .day], from: localDay)
            components.hour = settings.hour
            components.minute = settings.minute
            components.second = 0
            components.timeZone = zone
            guard let date = calendar.date(from: components) else { continue }
            guard date > current else { continue }
            let celebration = CompanionCalendar.celebration(for: date, from: calendars.1, timeZone: zone)
            let hasSaints = saints.contains { !$0.entries(on: date, timeZone: zone).isEmpty }
            guard celebration != nil || hasSaints else { continue }
            let readings = CompanionCalendar.readings(for: date, from: calendars.0, timeZone: zone)
            let gospel = readings?.readings.first(where: { $0.label == "Gospel" })?.reference
            let body = if hasSaints {
                SaintsNotice.body(calendars: saints, date: date, timeZone: zone, gospel: gospel)
            } else if let gospel, !gospel.isEmpty {
                "Today’s Gospel: \(gospel). Open your daily readings."
            } else {
                "Take a moment with today’s Catholic calendar and readings."
            }
            let milliseconds = date.timeIntervalSince1970 * 1_000
            guard milliseconds.isFinite, milliseconds >= Double(Int64.min), milliseconds < Double(Int64.max) else { continue }
            output.append(NoticeRequest(
                identifier: Self.calendarPrefix + String(Int64(milliseconds)),
                title: readings?.title ?? celebration?.title ?? "Today’s saints",
                body: body,
                userInfo: ["url": "/daily?date=\(CompanionCalendar.dateKey(date, timeZone: zone))"],
                trigger: .calendarDate(date, timeZoneIdentifier: zone.identifier)
            ))
        }
        return LocalNoticePlan(requests: Array(output.prefix(30)))
    }

    private func reconcileAndCommit(desired: [NoticeRequest], pending: [NoticeRequest],
                                   owned: (NoticeRequest) -> Bool,
                                   preserveSameIdentifier: Bool,
                                   restoreOnlyFutureCalendarRequests: Bool,
                                   operation: String,
                                   mutation: NativeStateMutation?) async throws {
        let original = Dictionary(pending.map { ($0.identifier, $0) }, uniquingKeysWith: { _, newer in newer })
        let desiredByID = Dictionary(desired.map { ($0.identifier, $0) }, uniquingKeysWith: { _, newer in newer })
        var removed: [NoticeRequest] = []
        var attemptedAddIDs: Set<String> = []
        do {
            for request in pending where owned(request) {
                guard let next = desiredByID[request.identifier] else {
                    removed.append(request)
                    try await center.removePendingRequest(identifier: request.identifier)
                    continue
                }
                let preserve = preserveSameIdentifier || Self.sameRequest(request, next)
                if !preserve {
                    removed.append(request)
                    try await center.removePendingRequest(identifier: request.identifier)
                }
            }
            for request in desired {
                if let old = original[request.identifier], owned(old), preserveSameIdentifier { continue }
                if let old = original[request.identifier], Self.sameRequest(old, request) { continue }
                attemptedAddIDs.insert(request.identifier)
                try await center.add(request)
            }
            if let mutation { try await commit(mutation) }
        } catch {
            let rollbackFailures = await rollback(removed: removed,
                attemptedAddIDs: attemptedAddIDs,
                restoreOnlyFutureCalendarRequests: restoreOnlyFutureCalendarRequests)
            throw LocalNoticeError.transactionFailed(operation: operation,
                cause: error.localizedDescription, rollbackFailures: rollbackFailures)
        }
    }

    private func rollback(removed: [NoticeRequest],
                          attemptedAddIDs: Set<String>,
                          restoreOnlyFutureCalendarRequests: Bool) async -> [String] {
        var failures: [String] = []
        for identifier in attemptedAddIDs {
            do { try await center.removePendingRequest(identifier: identifier) }
            catch { failures.append("remove \(identifier): \(error.localizedDescription)") }
        }
        var currentByID: [String: NoticeRequest]?
        do {
            let current = try await center.pendingRequests()
            currentByID = Dictionary(current.map { ($0.identifier, $0) }, uniquingKeysWith: { _, newer in newer })
        } catch {
            failures.append("read pending requests during rollback: \(error.localizedDescription)")
            currentByID = nil
        }
        let instant = now()
        for request in removed {
            if restoreOnlyFutureCalendarRequests && !isFutureCalendarRequest(request, after: instant) { continue }
            if let current = currentByID?[request.identifier], Self.sameRequest(current, request) { continue }
            do { try await center.restore(request) }
            catch { failures.append("restore \(request.identifier): \(error.localizedDescription)") }
        }
        return failures
    }

    private static func sameRequest(_ lhs: NoticeRequest, _ rhs: NoticeRequest) -> Bool {
        lhs.identifier == rhs.identifier && lhs.title == rhs.title && lhs.body == rhs.body &&
            lhs.userInfo == rhs.userInfo && lhs.sound == rhs.sound && sameTrigger(lhs.trigger, rhs.trigger)
    }

    private static func sameTrigger(_ lhs: NoticeTrigger, _ rhs: NoticeTrigger) -> Bool {
        switch (lhs, rhs) {
        case let (.daily(aHour, aMinute, aZone), .calendarComponents(parts, true)),
             let (.calendarComponents(parts, true), .daily(aHour, aMinute, aZone)):
            return parts.hour == aHour && parts.minute == aMinute && parts.weekday == nil &&
                parts.day == nil && parts.month == nil && parts.year == nil &&
                (parts.second == nil || parts.second == 0) &&
                matchesTimeZone(parts, aZone)
        case let (.weekly(aWeekday, aHour, aMinute, aZone), .calendarComponents(parts, true)),
             let (.calendarComponents(parts, true), .weekly(aWeekday, aHour, aMinute, aZone)):
            return parts.weekday == aWeekday && parts.hour == aHour && parts.minute == aMinute &&
                parts.day == nil && parts.month == nil && parts.year == nil &&
                (parts.second == nil || parts.second == 0) && matchesTimeZone(parts, aZone)
        case let (.calendarDate(date, zone), .calendarComponents(parts, false)),
             let (.calendarComponents(parts, false), .calendarDate(date, zone)):
            guard matchesTimeZone(parts, zone), let timeZone = TimeZone(identifier: zone) else { return false }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let expected = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            return expected.year == parts.year && expected.month == parts.month && expected.day == parts.day &&
                expected.hour == parts.hour && expected.minute == parts.minute && (parts.second ?? 0) == (expected.second ?? 0)
        case let (.daily(aHour, aMinute, aZone), .daily(bHour, bMinute, bZone)):
            return aHour == bHour && aMinute == bMinute && aZone == bZone
        case let (.weekly(aDay, aHour, aMinute, aZone), .weekly(bDay, bHour, bMinute, bZone)):
            return aDay == bDay && aHour == bHour && aMinute == bMinute && aZone == bZone
        case let (.calendarDate(aDate, aZone), .calendarDate(bDate, bZone)):
            return aDate == bDate && aZone == bZone
        case let (.calendarComponents(aParts, aRepeats), .calendarComponents(bParts, bRepeats)):
            return aParts == bParts && aRepeats == bRepeats
        case let (.interval(aSeconds, aRepeats), .interval(bSeconds, bRepeats)):
            return aSeconds == bSeconds && aRepeats == bRepeats
        default:
            return false
        }
    }

    private static func matchesTimeZone(_ components: DateComponents, _ desiredIdentifier: String) -> Bool {
        (components.timeZone ?? components.calendar?.timeZone ?? TimeZone.current).identifier == desiredIdentifier
    }

    private func isFutureCalendarRequest(_ request: NoticeRequest, after instant: Date) -> Bool {
        if request.identifier.hasPrefix(Self.saintPrefix) {
            switch request.trigger {
            case let .calendarDate(date, _): return date > instant
            case let .calendarComponents(parts, false):
                var calendar = parts.calendar ?? Calendar(identifier: .gregorian)
                calendar.timeZone = parts.timeZone ?? timeZone()
                return calendar.date(from: parts).map { $0 > instant } ?? false
            default: return false
            }
        }
        guard request.identifier.hasPrefix(Self.calendarPrefix),
              let milliseconds = Int64(request.identifier.dropFirst(Self.calendarPrefix.count)) else { return false }
        return Date(timeIntervalSince1970: Double(milliseconds) / 1_000) > instant
    }

    private func withOperationQueue<T>(_ operation: @MainActor () async throws -> T) async rethrows -> T {
        await acquireOperation()
        defer { releaseOperation() }
        return try await operation()
    }

    private func acquireOperation() async {
        if !operationActive {
            operationActive = true
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            operationWaiters.append(continuation)
        }
    }

    private func releaseOperation() {
        if operationWaiters.isEmpty {
            operationActive = false
        } else {
            operationWaiters.removeFirst().resume()
        }
    }
}

private extension NoticeAuthorizationStatus {
    var canDeliver: Bool {
        self == .authorized || self == .provisional || self == .ephemeral
    }
}
