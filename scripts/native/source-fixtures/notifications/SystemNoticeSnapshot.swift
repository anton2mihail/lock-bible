#if DEBUG
import CoreFoundation
import CoreLocation
import Foundation
import UserNotifications

/// Read-only notification-center evidence. This helper does not request permission or change requests.
@MainActor
enum SystemNoticeSnapshot {
    static func capture() async throws -> Report {
        let capturedAt = iso8601(Date())
        let capturedZone = TimeZone.current.identifier
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let pending = await center.pendingNotificationRequests()
        return Report(
            schemaVersion: 1,
            capturedAtUTC: capturedAt,
            completedAtUTC: iso8601(Date()),
            captureTimeZoneIdentifier: capturedZone,
            endingTimeZoneIdentifier: TimeZone.current.identifier,
            settings: SettingsSnapshot(settings),
            pendingRequestCount: pending.count,
            pendingRequests: pending.map(RequestSnapshot.init).sorted { $0.identifier < $1.identifier }
        )
    }

    static func encode(_ report: Report) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(report)
    }

    struct Report: Codable, Sendable {
        let schemaVersion: Int
        let capturedAtUTC: String
        let completedAtUTC: String
        let captureTimeZoneIdentifier: String
        let endingTimeZoneIdentifier: String
        let settings: SettingsSnapshot
        let pendingRequestCount: Int
        let pendingRequests: [RequestSnapshot]
    }

    struct SettingsSnapshot: Codable, Sendable {
        let authorizationStatus: String
        let alertSetting: String
        let soundSetting: String
        let badgeSetting: String
        let notificationCenterSetting: String
        let lockScreenSetting: String
        let carPlaySetting: String
        let alertStyle: String
        let showPreviewsSetting: String
        let criticalAlertSetting: String
        let providesAppNotificationSettings: Bool
        let announcementSetting: String
        let timeSensitiveSetting: String
        let scheduledDeliverySetting: String
        let directMessagesSetting: String

        init(_ value: UNNotificationSettings) {
            authorizationStatus = Self.authorization(value.authorizationStatus)
            alertSetting = Self.setting(value.alertSetting)
            soundSetting = Self.setting(value.soundSetting)
            badgeSetting = Self.setting(value.badgeSetting)
            notificationCenterSetting = Self.setting(value.notificationCenterSetting)
            lockScreenSetting = Self.setting(value.lockScreenSetting)
            carPlaySetting = Self.setting(value.carPlaySetting)
            alertStyle = Self.alertStyle(value.alertStyle)
            showPreviewsSetting = Self.preview(value.showPreviewsSetting)
            criticalAlertSetting = Self.setting(value.criticalAlertSetting)
            providesAppNotificationSettings = value.providesAppNotificationSettings
            announcementSetting = Self.setting(value.announcementSetting)
            timeSensitiveSetting = Self.setting(value.timeSensitiveSetting)
            scheduledDeliverySetting = Self.setting(value.scheduledDeliverySetting)
            directMessagesSetting = Self.setting(value.directMessagesSetting)
        }

        private static func authorization(_ value: UNAuthorizationStatus) -> String {
            switch value {
            case .notDetermined: "notDetermined"
            case .denied: "denied"
            case .authorized: "authorized"
            case .provisional: "provisional"
            case .ephemeral: "ephemeral"
            @unknown default: "unknown(\(value.rawValue))"
            }
        }

        private static func setting(_ value: UNNotificationSetting) -> String {
            switch value {
            case .notSupported: "notSupported"
            case .disabled: "disabled"
            case .enabled: "enabled"
            @unknown default: "unknown(\(value.rawValue))"
            }
        }

        private static func alertStyle(_ value: UNAlertStyle) -> String {
            switch value {
            case .none: "none"
            case .banner: "banner"
            case .alert: "alert"
            @unknown default: "unknown(\(value.rawValue))"
            }
        }

        private static func preview(_ value: UNShowPreviewsSetting) -> String {
            switch value {
            case .always: "always"
            case .whenAuthenticated: "whenAuthenticated"
            case .never: "never"
            @unknown default: "unknown(\(value.rawValue))"
            }
        }
    }

    struct RequestSnapshot: Codable, Sendable {
        let identifier: String
        let content: ContentSnapshot
        let trigger: TriggerSnapshot
        let secureArchiveBase64: String?
        let secureArchiveError: String?
        let unavailableFields: [String]

        init(_ request: UNNotificationRequest) {
            identifier = request.identifier
            content = ContentSnapshot(request.content)
            trigger = TriggerSnapshot(request.trigger)
            do {
                let archive = try NSKeyedArchiver.archivedData(
                    withRootObject: request,
                    requiringSecureCoding: true
                )
                secureArchiveBase64 = archive.base64EncodedString()
                secureArchiveError = nil
                unavailableFields = []
            } catch {
                secureArchiveBase64 = nil
                secureArchiveError = String(describing: error)
                unavailableFields = ["secureArchive"]
            }
        }
    }

    struct ContentSnapshot: Codable, Sendable {
        let title: String
        let subtitle: String
        let body: String
        let userInfo: [String: TypedValue]
        let userInfoUnavailableEntries: [String]
        let badge: TypedValue?
        let categoryIdentifier: String
        let threadIdentifier: String
        let launchImageName: String
        let targetContentIdentifier: String?
        let summaryArgument: String
        let summaryArgumentCount: Int
        let interruptionLevel: String
        let relevanceScore: Double
        let filterCriteria: String?
        let sound: String
        let attachments: [AttachmentSnapshot]
        let unavailableFields: [String]

        init(_ content: UNNotificationContent) {
            title = content.title
            subtitle = content.subtitle
            body = content.body
            var projectedInfo: [String: TypedValue] = [:]
            var unavailableInfo: [String] = []
            for (index, entry) in content.userInfo.enumerated() {
                guard let key = entry.key as? String else {
                    unavailableInfo.append("entry[\(index)].keyType=\(String(reflecting: type(of: entry.key)))")
                    continue
                }
                projectedInfo[key] = TypedValue(entry.value)
            }
            userInfo = projectedInfo
            userInfoUnavailableEntries = unavailableInfo
            badge = content.badge.map(TypedValue.init)
            categoryIdentifier = content.categoryIdentifier
            threadIdentifier = content.threadIdentifier
            launchImageName = content.launchImageName
            targetContentIdentifier = content.targetContentIdentifier
            summaryArgument = content.summaryArgument
            summaryArgumentCount = content.summaryArgumentCount
            interruptionLevel = Self.interruption(content.interruptionLevel)
            relevanceScore = content.relevanceScore
            filterCriteria = content.filterCriteria
            sound = Self.sound(content.sound)
            attachments = content.attachments.map(AttachmentSnapshot.init)
            unavailableFields = sound == "customOrOther" ? ["soundNameNotPubliclyExposed"] : []
        }

        private static func interruption(_ value: UNNotificationInterruptionLevel) -> String {
            switch value {
            case .passive: "passive"
            case .active: "active"
            case .timeSensitive: "timeSensitive"
            case .critical: "critical"
            @unknown default: "unknown(\(value.rawValue))"
            }
        }

        private static func sound(_ value: UNNotificationSound?) -> String {
            guard let value else { return "none" }
            if value.isEqual(UNNotificationSound.default) { return "default" }
            if value.isEqual(UNNotificationSound.defaultCritical) { return "defaultCritical" }
            return "customOrOther"
        }
    }

    struct AttachmentSnapshot: Codable, Sendable {
        let identifier: String
        let type: String
        let url: String

        init(_ value: UNNotificationAttachment) {
            identifier = value.identifier
            type = value.type
            url = value.url.absoluteString
        }
    }

    struct TriggerSnapshot: Codable, Sendable {
        let kind: String
        let triggerClassName: String?
        let repeats: Bool?
        let calendarComponents: ComponentsSnapshot?
        let timeIntervalSeconds: Double?
        let location: LocationSnapshot?
        let nextTriggerDateUTC: String?
        let unavailableFields: [String]

        init(_ trigger: UNNotificationTrigger?) {
            guard let trigger else {
                kind = "immediate"
                triggerClassName = nil
                repeats = nil
                calendarComponents = nil
                timeIntervalSeconds = nil
                location = nil
                nextTriggerDateUTC = nil
                unavailableFields = []
                return
            }

            triggerClassName = String(reflecting: type(of: trigger))
            repeats = trigger.repeats
            if let calendar = trigger as? UNCalendarNotificationTrigger {
                kind = "calendar"
                calendarComponents = ComponentsSnapshot(calendar.dateComponents)
                timeIntervalSeconds = nil
                location = nil
                nextTriggerDateUTC = calendar.nextTriggerDate().map(SystemNoticeSnapshot.iso8601)
                unavailableFields = []
            } else if let interval = trigger as? UNTimeIntervalNotificationTrigger {
                kind = "timeInterval"
                calendarComponents = nil
                timeIntervalSeconds = interval.timeInterval
                location = nil
                nextTriggerDateUTC = interval.nextTriggerDate().map(SystemNoticeSnapshot.iso8601)
                unavailableFields = []
            } else if let locationTrigger = trigger as? UNLocationNotificationTrigger {
                kind = "location"
                calendarComponents = nil
                timeIntervalSeconds = nil
                location = LocationSnapshot(locationTrigger.region)
                nextTriggerDateUTC = nil
                unavailableFields = ["locationTriggerNextDate"]
            } else if trigger is UNPushNotificationTrigger {
                kind = "push"
                calendarComponents = nil
                timeIntervalSeconds = nil
                location = nil
                nextTriggerDateUTC = nil
                unavailableFields = ["pushPayloadNotPubliclyAvailableOnPendingRequest"]
            } else {
                kind = String(reflecting: type(of: trigger))
                calendarComponents = nil
                timeIntervalSeconds = nil
                location = nil
                nextTriggerDateUTC = nil
                unavailableFields = ["unrecognizedTriggerPublicFields"]
            }
        }
    }

    struct ComponentsSnapshot: Codable, Sendable {
        let era: Int?
        let year: Int?
        let quarter: Int?
        let month: Int?
        let day: Int?
        let dayOfYear: Int?
        let hour: Int?
        let minute: Int?
        let second: Int?
        let nanosecond: Int?
        let weekday: Int?
        let weekdayOrdinal: Int?
        let weekOfMonth: Int?
        let weekOfYear: Int?
        let yearForWeekOfYear: Int?
        let isLeapMonth: Bool?
        let isRepeatedDay: Bool?
        let calendarIdentifier: String?
        let calendarTimeZoneIdentifier: String?
        let componentTimeZoneIdentifier: String?

        init(_ value: DateComponents) {
            era = value.era
            year = value.year
            quarter = value.quarter
            month = value.month
            day = value.day
            dayOfYear = value.dayOfYear
            hour = value.hour
            minute = value.minute
            second = value.second
            nanosecond = value.nanosecond
            weekday = value.weekday
            weekdayOrdinal = value.weekdayOrdinal
            weekOfMonth = value.weekOfMonth
            weekOfYear = value.weekOfYear
            yearForWeekOfYear = value.yearForWeekOfYear
            isLeapMonth = value.isLeapMonth
            isRepeatedDay = value.isRepeatedDay
            calendarIdentifier = value.calendar.map { String(describing: $0.identifier) }
            calendarTimeZoneIdentifier = value.calendar?.timeZone.identifier
            componentTimeZoneIdentifier = value.timeZone?.identifier
        }
    }

    struct LocationSnapshot: Codable, Sendable {
        let regionType: String
        let identifier: String
        let notifyOnEntry: Bool
        let notifyOnExit: Bool
        let centerLatitude: Double?
        let centerLongitude: Double?
        let radiusMeters: Double?
        let unavailableFields: [String]

        init(_ region: CLRegion) {
            identifier = region.identifier
            notifyOnEntry = region.notifyOnEntry
            notifyOnExit = region.notifyOnExit
            if let circle = region as? CLCircularRegion {
                regionType = "circular"
                centerLatitude = circle.center.latitude
                centerLongitude = circle.center.longitude
                radiusMeters = circle.radius
                unavailableFields = []
            } else {
                regionType = String(reflecting: type(of: region))
                centerLatitude = nil
                centerLongitude = nil
                radiusMeters = nil
                unavailableFields = ["regionGeometryNotProjected"]
            }
        }
    }

    enum TypedValue: Codable, Sendable, Equatable {
        case null
        case bool(Bool)
        case integer(Int64)
        case unsigned(UInt64)
        case number(Double)
        case string(String)
        case array([TypedValue])
        case object([String: TypedValue])
        case unavailable(type: String, reason: String)

        private enum CodingKeys: String, CodingKey { case type, value, reason }

        init(_ value: Any) {
            if value is NSNull {
                self = .null
            } else if let string = value as? String {
                self = .string(string)
            } else if let number = value as? NSNumber {
                if CFGetTypeID(number) == CFBooleanGetTypeID() {
                    self = .bool(number.boolValue)
                } else if Self.isUnsigned(number) {
                    self = .unsigned(number.uint64Value)
                } else if Self.isInteger(number) {
                    self = .integer(number.int64Value)
                } else if !number.doubleValue.isFinite {
                    self = .unavailable(type: "NSNumber", reason: "Non-finite number is not valid JSON")
                } else {
                    self = .number(number.doubleValue)
                }
            } else if let array = value as? [Any] {
                self = .array(array.map(TypedValue.init))
            } else if let dictionary = value as? [String: Any] {
                self = .object(dictionary.mapValues(TypedValue.init))
            } else {
                self = .unavailable(type: String(reflecting: type(of: value)), reason: "Not a supported JSON value")
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(String.self, forKey: .type) {
            case "null": self = .null
            case "bool": self = .bool(try container.decode(Bool.self, forKey: .value))
            case "integer": self = .integer(try container.decode(Int64.self, forKey: .value))
            case "unsigned": self = .unsigned(try container.decode(UInt64.self, forKey: .value))
            case "number": self = .number(try container.decode(Double.self, forKey: .value))
            case "string": self = .string(try container.decode(String.self, forKey: .value))
            case "array": self = .array(try container.decode([TypedValue].self, forKey: .value))
            case "object": self = .object(try container.decode([String: TypedValue].self, forKey: .value))
            case "unavailable":
                self = .unavailable(type: try container.decode(String.self, forKey: .value),
                                    reason: try container.decode(String.self, forKey: .reason))
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container,
                                                       debugDescription: "Unknown typed userInfo value")
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .null:
                try container.encode("null", forKey: .type)
            case let .bool(value):
                try container.encode("bool", forKey: .type)
                try container.encode(value, forKey: .value)
            case let .integer(value):
                try container.encode("integer", forKey: .type)
                try container.encode(value, forKey: .value)
            case let .unsigned(value):
                try container.encode("unsigned", forKey: .type)
                try container.encode(value, forKey: .value)
            case let .number(value):
                try container.encode("number", forKey: .type)
                try container.encode(value, forKey: .value)
            case let .string(value):
                try container.encode("string", forKey: .type)
                try container.encode(value, forKey: .value)
            case let .array(value):
                try container.encode("array", forKey: .type)
                try container.encode(value, forKey: .value)
            case let .object(value):
                try container.encode("object", forKey: .type)
                try container.encode(value, forKey: .value)
            case let .unavailable(type, reason):
                try container.encode("unavailable", forKey: .type)
                try container.encode(type, forKey: .value)
                try container.encode(reason, forKey: .reason)
            }
        }

        private static func isInteger(_ value: NSNumber) -> Bool {
            ["c", "C", "s", "S", "i", "I", "l", "L", "q"].contains(String(cString: value.objCType))
        }

        private static func isUnsigned(_ value: NSNumber) -> Bool {
            ["C", "S", "I", "L", "Q"].contains(String(cString: value.objCType))
        }
    }

    nonisolated private static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
#endif
