import Foundation
import CoreFoundation

public enum JSONValue: Codable, Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null; return }
        if let bool = try? value.decode(Bool.self) { self = .bool(bool); return }
        if let integer = try? value.decode(Int64.self) { self = .number(Double(integer)); return }
        if let number = try? value.decode(Double.self) { self = .number(number); return }
        if let string = try? value.decode(String.self) { self = .string(string); return }
        if let array = try? value.decode([JSONValue].self) { self = .array(array); return }
        self = .object(try value.decode([String: JSONValue].self))
    }

    public func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .null: try value.encodeNil()
        case let .bool(item): try value.encode(item)
        case let .number(item): try value.encode(item)
        case let .string(item): try value.encode(item)
        case let .array(item): try value.encode(item)
        case let .object(item): try value.encode(item)
        }
    }

    static func parse(_ data: Data) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: data)
    }

    static func from(_ value: Any) -> JSONValue? {
        if value is NSNull { return .null }
        if let value = value as? String { return .string(value) }
        if let value = value as? [Any] {
            let children = value.compactMap(Self.from)
            return children.count == value.count ? .array(children) : nil
        }
        if let value = value as? [String: Any] {
            var children: [String: JSONValue] = [:]
            for (key, child) in value {
                guard let converted = Self.from(child) else { return nil }
                children[key] = converted
            }
            return .object(children)
        }
        if let value = value as? NSNumber {
            if CFGetTypeID(value) == CFBooleanGetTypeID() { return .bool(value.boolValue) }
            return .number(value.doubleValue)
        }
        return nil
    }
}

public struct SundayReflection: Codable, Hashable, Sendable {
    public let before: String
    public let after: String
    public init(before: String = "", after: String = "") { self.before = before; self.after = after }
}

public struct CalendarNotificationSettings: Codable, Hashable, Sendable {
    public let enabled: Bool
    public let hour: Int
    public let minute: Int
    public init(enabled: Bool = false, hour: Int = 8, minute: Int = 0) {
        self.enabled = enabled; self.hour = hour; self.minute = minute
    }
}

public struct RosaryReminderSettings: Codable, Hashable, Sendable {
    public let enabled: Bool
    public let frequency: String
    public let hour: Int
    public let minute: Int
    public let weekday: Int
    public let notificationID: String?
    public init(enabled: Bool = false, frequency: String = "daily", hour: Int = 20, minute: Int = 0,
                weekday: Int = 2, notificationID: String? = nil) {
        self.enabled = enabled; self.frequency = frequency; self.hour = hour; self.minute = minute
        self.weekday = weekday; self.notificationID = notificationID
    }
}

public struct NovenaProgress: Codable, Hashable, Sendable {
    public let completedDays: [Int]
    public let selectedDay: Int
    public let intention: String
    public init(completedDays: [Int] = [], selectedDay: Int = 1, intention: String = "") {
        self.completedDays = completedDays; self.selectedDay = selectedDay; self.intention = intention
    }
}

public struct WorkReadingPosition: Codable, Hashable, Sendable {
    public let fields: [String: JSONValue]
    public var sectionIndex: Double? {
        guard case let .number(value) = fields["sectionIndex"], value.isFinite else { return nil }
        return value
    }
    public init(fields: [String: JSONValue]) { self.fields = fields }
}

public struct NativePersistentState: Codable, Hashable, Sendable {
    public private(set) var themeScheme: String?
    public private(set) var translationID: String
    public private(set) var rotationIntervalMinutes: Int
    public private(set) var verseScope: RotationScope
    public private(set) var readerLocation: ReaderLocation?
    public private(set) var readingPreferences: ReadingPreferences
    public private(set) var widgetGuideDismissed: Bool
    public private(set) var selectionHintDismissed: Bool
    public private(set) var reflections: [String: SundayReflection]
    public private(set) var favoritePrayerIDs: [String]
    public private(set) var calendarNotifications: CalendarNotificationSettings
    public private(set) var rosaryReminder: RosaryReminderSettings
    public private(set) var worksPositions: [String: WorkReadingPosition]
    public private(set) var novenaProgress: [String: NovenaProgress]

    public init(themeScheme: String? = nil, translationID: String = "web-ce", rotationIntervalMinutes: Int = 1440,
                verseScope: RotationScope = .full, readerLocation: ReaderLocation? = nil,
                readingPreferences: ReadingPreferences = .sourceDefaults, widgetGuideDismissed: Bool = false,
                selectionHintDismissed: Bool = false, reflections: [String: SundayReflection] = [:],
                favoritePrayerIDs: [String] = [], calendarNotifications: CalendarNotificationSettings = .init(),
                rosaryReminder: RosaryReminderSettings = .init(), worksPositions: [String: WorkReadingPosition] = [:],
                novenaProgress: [String: NovenaProgress] = [:]) {
        self.themeScheme = themeScheme; self.translationID = translationID
        self.rotationIntervalMinutes = rotationIntervalMinutes; self.verseScope = verseScope
        self.readerLocation = readerLocation; self.readingPreferences = readingPreferences
        self.widgetGuideDismissed = widgetGuideDismissed; self.selectionHintDismissed = selectionHintDismissed
        self.reflections = reflections; self.favoritePrayerIDs = favoritePrayerIDs
        self.calendarNotifications = calendarNotifications; self.rosaryReminder = rosaryReminder
        self.worksPositions = worksPositions; self.novenaProgress = novenaProgress
    }

    mutating func apply(_ mutation: NativeStateMutation) {
        switch mutation {
        case let .setThemeScheme(value): themeScheme = value
        case let .setTranslationID(value): translationID = value
        case let .setRotationInterval(value): rotationIntervalMinutes = value
        case let .setVerseScope(value): verseScope = value
        case let .setReaderLocation(value): readerLocation = value
        case let .setReadingPreferences(value): readingPreferences = value
        case let .setReaderTextSize(value): readingPreferences = readingPreferences.with(textSize: value)
        case let .setReaderLineSpacing(value): readingPreferences = readingPreferences.with(lineSpacing: value)
        case let .setReaderTypeface(value): readingPreferences = readingPreferences.with(typeface: value)
        case let .setReaderLayout(value): readingPreferences = readingPreferences.with(layout: value)
        case let .setReaderMode(value): readingPreferences = readingPreferences.with(mode: value)
        case let .setWidgetGuideDismissed(value): widgetGuideDismissed = value
        case let .setSelectionHintDismissed(value): selectionHintDismissed = value
        case let .setReflection(date, value): reflections[date] = value
        case let .setFavoritePrayerIDs(value): favoritePrayerIDs = value
        case let .setCalendarNotifications(value): calendarNotifications = value
        case let .setRosaryReminder(value): rosaryReminder = value
        case let .setWorksPosition(workID, value):
            if let value { worksPositions[workID] = value } else { worksPositions.removeValue(forKey: workID) }
        case let .setNovenaProgress(id, value): novenaProgress[id] = value
        }
    }

    func validate() throws {
        let validTranslations: Set<String> = ["web-ce", "douay-rheims", "vulgate"]
        let validIntervals: Set<Int> = [10, 15, 30, 60, 180, 360, 720, 1440]
        guard validTranslations.contains(translationID) else {
            throw CoreError.invalidResource("native state has an unsupported translation ID")
        }
        guard validIntervals.contains(rotationIntervalMinutes) else {
            throw CoreError.invalidResource("native state has an unsupported rotation interval")
        }
        if let readerLocation, readerLocation.chapter < 1 || !readerLocation.scrollY.isFinite || readerLocation.scrollY < 0 {
            throw CoreError.invalidResource("native state has an invalid reader location")
        }
        guard (0...23).contains(calendarNotifications.hour), (0...59).contains(calendarNotifications.minute) else {
            throw CoreError.invalidResource("native state has invalid calendar notification time")
        }
        guard ["daily", "weekly"].contains(rosaryReminder.frequency), (0...23).contains(rosaryReminder.hour),
              (0...59).contains(rosaryReminder.minute), (1...7).contains(rosaryReminder.weekday) else {
            throw CoreError.invalidResource("native state has invalid Rosary reminder settings")
        }
        for progress in novenaProgress.values {
            guard (1...9).contains(progress.selectedDay),
                  progress.completedDays.allSatisfy({ (1...9).contains($0) }),
                  Set(progress.completedDays).count == progress.completedDays.count else {
                throw CoreError.invalidResource("native state has invalid novena progress")
            }
        }
        for position in worksPositions.values {
            guard let sectionIndex = position.sectionIndex, sectionIndex.isFinite else {
                throw CoreError.invalidResource("native state has invalid Works position")
            }
        }
    }
}

public struct NativeStateEnvelope: Codable, Hashable, Sendable {
    public let formatVersion: Int
    public let revision: Int64
    public let importVersion: Int
    public let importSourceHashes: [String: String]
    public let state: NativePersistentState
    public let issues: [String]
    public init(formatVersion: Int = 1, revision: Int64, importVersion: Int,
                importSourceHashes: [String: String], state: NativePersistentState, issues: [String]) {
        self.formatVersion = formatVersion; self.revision = revision; self.importVersion = importVersion
        self.importSourceHashes = importSourceHashes; self.state = state; self.issues = issues
    }

    func validate() throws {
        guard formatVersion == 1, revision >= 0, importVersion == 1 else {
            throw CoreError.invalidResource("native state envelope version or revision is invalid")
        }
        for hash in importSourceHashes.values {
            guard hash.count == 64, hash.allSatisfy({ $0.isHexDigit }) else {
                throw CoreError.invalidResource("native state source hash is invalid")
            }
        }
        try state.validate()
    }
}

public struct StartupState: Sendable {
    public let envelope: NativeStateEnvelope?
    public let libraryCapability: String?
    public let nativeStateCapability: String?
    public var state: NativePersistentState? { envelope?.state }
    public var revision: Int64? { envelope?.revision }
    public init(envelope: NativeStateEnvelope?, libraryCapability: String?, nativeStateCapability: String? = nil) {
        self.envelope = envelope; self.libraryCapability = libraryCapability
        self.nativeStateCapability = nativeStateCapability
    }
}

public enum NativeStateMutation: Sendable {
    case setThemeScheme(String?)
    case setTranslationID(String)
    case setRotationInterval(Int)
    case setVerseScope(RotationScope)
    case setReaderLocation(ReaderLocation?)
    case setReadingPreferences(ReadingPreferences)
    case setReaderTextSize(ReaderTextSize)
    case setReaderLineSpacing(ReaderLineSpacing)
    case setReaderTypeface(ReaderTypeface)
    case setReaderLayout(ReaderLayout)
    case setReaderMode(ReaderMode)
    case setWidgetGuideDismissed(Bool)
    case setSelectionHintDismissed(Bool)
    case setReflection(date: String, value: SundayReflection)
    case setFavoritePrayerIDs([String])
    case setCalendarNotifications(CalendarNotificationSettings)
    case setRosaryReminder(RosaryReminderSettings)
    case setWorksPosition(workID: String, value: WorkReadingPosition?)
    case setNovenaProgress(id: String, value: NovenaProgress)
}

public enum NativeImportCheckpoint: String, Sendable {
    case beforeStaging
    case beforeDurableCommit
    case afterPrimaryRename
    case afterDurableCommit
    case afterFreshLibraryTransaction
    case beforeFreshLibraryPublish
    case afterFreshLibraryPublish
}

public enum NativeStateFailurePoint: Sendable {
    case afterPrimaryRename
}

public struct LegacyMMKVSnapshot: Sendable {
    public let keys: Set<String>
    public let stringValues: [String: String]
    public let sourceHashes: [String: String]
    public init(keys: Set<String>, stringValues: [String: String], sourceHashes: [String: String]) {
        self.keys = keys; self.stringValues = stringValues; self.sourceHashes = sourceHashes
    }
}

public protocol LegacyMMKVReading: Sendable {
    func readKnownValues(_ keys: [String]) async throws -> LegacyMMKVSnapshot?
}
