import Foundation
import UserNotifications

public enum NoticeAuthorizationStatus: String, Codable, Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case provisional
    case ephemeral
}

public enum NoticeSound: Codable, Sendable, Equatable {
    case defaultSound
    case none
    case custom
}

public enum NoticeInterruption: String, Codable, Sendable, Equatable {
    case active
    case timeSensitive
}

/// Identifiers for the reading reminder category and its actions (E17).
public enum ReadingNoticeAction {
    public static let category = "john.reading"
    public static let markRead = "john.reading.markRead"
    public static let snooze = "john.reading.snooze"
    public static let open = "john.reading.open"
    public static let snoozeIdentifier = "john-reading:snooze"
    public static let snoozeSeconds: TimeInterval = 3_600
}

public enum NoticeTrigger: Codable, Sendable, Equatable {
    case calendarDate(Date, timeZoneIdentifier: String)
    case daily(hour: Int, minute: Int, timeZoneIdentifier: String)
    case weekly(weekday: Int, hour: Int, minute: Int, timeZoneIdentifier: String)
    case calendarComponents(DateComponents, repeats: Bool)
    case interval(seconds: TimeInterval, repeats: Bool)
    case unsupported
}

// UNNotificationRequest is immutable. The service keeps this snapshot on MainActor for rollback.
public struct NoticeRequest: @unchecked Sendable, Equatable {
    public let identifier: String
    public let title: String
    public let body: String
    public let userInfo: [String: String]
    public let sound: NoticeSound
    public let trigger: NoticeTrigger
    public let interruption: NoticeInterruption
    public let category: String?
    public let thread: String?
    fileprivate let originalSystemRequest: UNNotificationRequest?

    public init(identifier: String, title: String, body: String, userInfo: [String: String],
                sound: NoticeSound = .defaultSound, trigger: NoticeTrigger,
                interruption: NoticeInterruption = .active, category: String? = nil, thread: String? = nil) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.userInfo = userInfo
        self.sound = sound
        self.trigger = trigger
        self.interruption = interruption
        self.category = category
        self.thread = thread
        self.originalSystemRequest = nil
    }

    fileprivate init(identifier: String, title: String, body: String, userInfo: [String: String],
                     sound: NoticeSound, trigger: NoticeTrigger, interruption: NoticeInterruption,
                     category: String?, thread: String?, originalSystemRequest: UNNotificationRequest) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.userInfo = userInfo
        self.sound = sound
        self.trigger = trigger
        self.interruption = interruption
        self.category = category
        self.thread = thread
        self.originalSystemRequest = originalSystemRequest
    }

    public static func == (lhs: NoticeRequest, rhs: NoticeRequest) -> Bool {
        lhs.identifier == rhs.identifier && lhs.title == rhs.title && lhs.body == rhs.body &&
            lhs.userInfo == rhs.userInfo && lhs.sound == rhs.sound && lhs.trigger == rhs.trigger &&
            lhs.interruption == rhs.interruption && lhs.category == rhs.category && lhs.thread == rhs.thread
    }
}

@MainActor
public protocol NoticeCenter: AnyObject {
    func authorizationStatus() async -> NoticeAuthorizationStatus
    func requestAuthorization() async throws -> NoticeAuthorizationStatus
    func pendingRequests() async throws -> [NoticeRequest]
    func add(_ request: NoticeRequest) async throws
    func restore(_ request: NoticeRequest) async throws
    func removePendingRequest(identifier: String) async throws
}

@MainActor
public extension NoticeCenter {
    func restore(_ request: NoticeRequest) async throws { try await add(request) }
}

@MainActor
public final class SystemNoticeCenter: NoticeCenter {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter? = nil) {
        self.center = center ?? .current()
    }

    public func authorizationStatus() async -> NoticeAuthorizationStatus {
        let settings = await center.notificationSettings()
        return Self.status(settings.authorizationStatus)
    }

    public func requestAuthorization() async throws -> NoticeAuthorizationStatus {
        _ = try await center.requestAuthorization(options: [.alert, .sound])
        return await authorizationStatus()
    }

    public func pendingRequests() async throws -> [NoticeRequest] {
        await center.pendingNotificationRequests().map(Self.noticeRequest)
    }

    public func add(_ request: NoticeRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.userInfo = request.userInfo
        switch request.sound {
        case .defaultSound: content.sound = .default
        case .none: break
        case .custom: throw LocalNoticeError.unsupportedSound
        }
        switch request.interruption {
        case .active: break
        case .timeSensitive: content.interruptionLevel = .timeSensitive
        }
        if let category = request.category { content.categoryIdentifier = category }
        if let thread = request.thread ?? Self.defaultThread(for: request.identifier) { content.threadIdentifier = thread }
        let trigger = try Self.systemTrigger(request.trigger)
        try await center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger))
    }

    public func restore(_ request: NoticeRequest) async throws {
        if let original = request.originalSystemRequest {
            try await center.add(original)
        } else {
            try await add(request)
        }
    }

    public func removePendingRequest(identifier: String) async throws {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private static func status(_ value: UNAuthorizationStatus) -> NoticeAuthorizationStatus {
        switch value {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .provisional: .provisional
        case .ephemeral: .ephemeral
        @unknown default: .denied
        }
    }

    private static func noticeRequest(_ request: UNNotificationRequest) -> NoticeRequest {
        let info = request.content.userInfo.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String { result[key] = value }
        }
        let trigger: NoticeTrigger
        if let calendar = request.trigger as? UNCalendarNotificationTrigger {
            trigger = .calendarComponents(calendar.dateComponents, repeats: calendar.repeats)
        } else if let interval = request.trigger as? UNTimeIntervalNotificationTrigger {
            trigger = .interval(seconds: interval.timeInterval, repeats: interval.repeats)
        } else {
            trigger = .unsupported
        }
        return NoticeRequest(identifier: request.identifier, title: request.content.title,
            body: request.content.body, userInfo: info,
            sound: Self.noticeSound(request.content.sound), trigger: trigger,
            interruption: request.content.interruptionLevel == .timeSensitive ? .timeSensitive : .active,
            category: request.content.categoryIdentifier.isEmpty ? nil : request.content.categoryIdentifier,
            thread: request.content.threadIdentifier.isEmpty ? nil : request.content.threadIdentifier,
            originalSystemRequest: request)
    }

    /// Groups the notices by thread when the service gives no thread.
    private static func defaultThread(for identifier: String) -> String? {
        if identifier.hasPrefix(LocalNoticeService.calendarPrefix) { return "john.calendar" }
        if identifier.hasPrefix("john-rosary:") { return "john.rosary" }
        if identifier.hasPrefix("john-reading:") { return "john.reading" }
        return nil
    }

    private static func noticeSound(_ value: UNNotificationSound?) -> NoticeSound {
        guard let value else { return .none }
        return value.isEqual(UNNotificationSound.default) ? .defaultSound : .custom
    }

    private static func systemTrigger(_ value: NoticeTrigger) throws -> UNNotificationTrigger {
        switch value {
        case let .calendarDate(date, identifier):
            guard let zone = TimeZone(identifier: identifier) else { throw LocalNoticeError.invalidTimeZone }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let fields = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            var components = fields
            components.calendar = calendar
            components.timeZone = zone
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        case let .daily(hour, minute, identifier):
            guard let zone = TimeZone(identifier: identifier) else { throw LocalNoticeError.invalidTimeZone }
            var components = DateComponents()
            components.calendar = Calendar(identifier: .gregorian)
            components.timeZone = zone
            components.hour = hour
            components.minute = minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case let .weekly(weekday, hour, minute, identifier):
            guard let zone = TimeZone(identifier: identifier) else { throw LocalNoticeError.invalidTimeZone }
            var components = DateComponents()
            components.calendar = Calendar(identifier: .gregorian)
            components.timeZone = zone
            components.weekday = weekday
            components.hour = hour
            components.minute = minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case let .calendarComponents(components, repeats):
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        case let .interval(seconds, repeats):
            return UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: repeats)
        case .unsupported:
            throw LocalNoticeError.unsupportedTrigger
        }
    }
}

public enum LocalNoticeError: Error, LocalizedError, Sendable {
    case permissionDenied(String)
    case scheduleFull
    case noCalendarDates
    case invalidTimeZone
    case unsupportedTrigger
    case unsupportedSound
    case refreshFailures([String])
    case transactionFailed(operation: String, cause: String, rollbackFailures: [String])

    public var errorDescription: String? {
        switch self {
        case let .permissionDenied(message): message
        case .scheduleFull: "Your notification schedule is full. Remove a reminder and try again."
        case .noCalendarDates: "No upcoming calendar dates are installed. Update John 1:1 to refresh the calendar."
        case .invalidTimeZone: "The time zone is not valid."
        case .unsupportedTrigger: "The saved notification trigger is not supported."
        case .unsupportedSound: "The saved notification sound is not supported."
        case let .refreshFailures(failures): "Notification refresh failed: \(failures.joined(separator: "; "))"
        case let .transactionFailed(operation, cause, rollbackFailures):
            if rollbackFailures.isEmpty { "\(operation) failed: \(cause)" }
            else { "\(operation) failed: \(cause). Recovery also failed: \(rollbackFailures.joined(separator: "; "))" }
        }
    }
}
