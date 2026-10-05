import Foundation

struct LegacyStateNormalization: Sendable {
    let state: NativePersistentState
    let issues: [String]
}

enum LegacyStateNormalizer {
    private static let translationIDs: Set<String> = ["web-ce", "douay-rheims", "vulgate"]
    private static let rotationIntervals: Set<Double> = [10, 15, 30, 60, 180, 360, 720, 1440]
    private static let novenaDays = 9

    private static func safeTimestampHint(_ value: Double) -> Int64? {
        guard value.isFinite else { return nil }
        let truncated = value.rounded(.towardZero)
        let lowerBound = -9_223_372_036_854_775_808.0
        let upperBound = 9_223_372_036_854_775_808.0
        guard truncated >= lowerBound, truncated < upperBound else { return nil }
        return Int64(truncated)
    }

    static let fixedKeys = [
        "ignite.themeScheme",
        "bible.translationId", "bible.rotationInterval", "bible.verseScope",
        "bible.reader.location", "bible.reader.textSize", "bible.reader.lineSpacing",
        "bible.reader.typeface", "bible.reader.layout", "bible.widgetGuideDismissed",
        "bible.reader.selectionHintDismissed", "vesper.prayer.favorites",
        "john.calendar-notifications.v1", "rosary.reminder.v1", "works.position.v1",
    ]

    static func knownKeys(legacyKeys: Set<String>, novenaIDs: [String]) -> [String] {
        let novenaKeys = novenaIDs.map { "novena.\($0).progress.v1" }
        let reflectionKeys = legacyKeys.filter { $0.hasPrefix("vesper.sunday.") }
        return Array(Set(fixedKeys + novenaKeys + reflectionKeys)).sorted()
    }

    static func normalize(snapshot: LegacyMMKVSnapshot?, novenaIDs: [String]) -> LegacyStateNormalization {
        let values = snapshot?.stringValues ?? [:]
        let keys = snapshot?.keys ?? []
        var issues = Set<String>()
        var parsedCache: [String: JSONValue] = [:]
        func loaded(_ key: String) -> JSONValue? {
            if let cached = parsedCache[key] { return cached }
            guard let raw = values[key] else {
                if keys.contains(key) { issues.insert(key) }
                return nil
            }
            let value: JSONValue
            do { value = try JSONValue.parse(Data(raw.utf8)) }
            catch { value = .string(raw) } // Match storage.load(): return the original string after JSON.parse fails.
            parsedCache[key] = value
            return value
        }
        func object(_ key: String) -> [String: JSONValue]? {
            guard let value = loaded(key) else { return nil }
            guard case let .object(fields) = value else { issues.insert(key); return nil }
            return fields
        }
        func string(_ value: JSONValue?) -> String? {
            guard case let .string(item) = value else { return nil }
            return item
        }
        func number(_ value: JSONValue?) -> Double? {
            guard case let .number(item) = value, item.isFinite else { return nil }
            return item
        }
        func integer(_ value: JSONValue?) -> Int? {
            guard let value = number(value) else { return nil }
            return Int(exactly: value)
        }
        func boolTrue(_ value: JSONValue?) -> Bool { value == .bool(true) }

        let rawTheme = values["ignite.themeScheme"]
        let idValue = loaded("bible.translationId")
        let translationID = string(idValue).flatMap { translationIDs.contains($0) ? $0 : nil } ?? "web-ce"
        if idValue != nil && (string(idValue).map { !translationIDs.contains($0) } ?? true) { issues.insert("bible.translationId") }

        let intervalValue = loaded("bible.rotationInterval")
        let intervalNumber = number(intervalValue)
        let interval = intervalNumber.flatMap { rotationIntervals.contains($0) ? Int($0) : nil } ?? 1440
        if intervalValue != nil && (intervalNumber.map { !rotationIntervals.contains($0) } ?? true) { issues.insert("bible.rotationInterval") }

        let scopeValue = loaded("bible.verseScope")
        let scope = string(scopeValue).flatMap(RotationScope.init(rawValue:)) ?? .full
        if scopeValue != nil && (string(scopeValue).flatMap(RotationScope.init(rawValue:)) == nil) { issues.insert("bible.verseScope") }

        var location: ReaderLocation?
        if let fields = object("bible.reader.location") {
            let book = string(fields["book"])
            let chapter = integer(fields["chapter"])
            let scrollY = number(fields["scrollY"])
            let updated: Int64
            if let raw = fields["updatedAt"] {
                if case let .number(rawUpdated) = raw, let safeValue = safeTimestampHint(rawUpdated) {
                    updated = safeValue
                } else {
                    updated = 0
                    issues.insert("bible.reader.location")
                }
            } else {
                updated = 0
            }
            if let book, let chapter, chapter >= 1, let scrollY {
                do { location = try ReaderLocation(bookCode: BookCode(book), chapter: chapter, scrollY: scrollY, updatedAt: updated) }
                catch { issues.insert("bible.reader.location") }
            } else if fields.isEmpty == false { issues.insert("bible.reader.location") }
        }

        func enumString(_ key: String, allowed: Set<String>, fallback: String) -> String {
            guard let value = loaded(key) else { return fallback }
            guard let parsed = string(value), allowed.contains(parsed) else { issues.insert(key); return fallback }
            return parsed
        }
        let textSize = enumString("bible.reader.textSize", allowed: ["small", "medium", "large", "extraLarge"], fallback: "medium")
        let lineSpacing = enumString("bible.reader.lineSpacing", allowed: ["compact", "comfortable", "relaxed"], fallback: "comfortable")
        let typeface = enumString("bible.reader.typeface", allowed: ["sans", "serif"], fallback: "serif")
        let layout = enumString("bible.reader.layout", allowed: ["paragraphs", "verses"], fallback: "paragraphs")
        let preferences = ReadingPreferences(textSize: ReaderTextSize(rawValue: textSize) ?? .medium,
            lineSpacing: ReaderLineSpacing(rawValue: lineSpacing) ?? .comfortable,
            typeface: ReaderTypeface(rawValue: typeface) ?? .serif,
            layout: ReaderLayout(rawValue: layout) ?? .paragraphs)

        func strictTrue(_ key: String) -> Bool {
            guard let value = loaded(key) else { return false }
            if case .bool = value { return boolTrue(value) }
            issues.insert(key); return false
        }
        let guideDismissed = strictTrue("bible.widgetGuideDismissed")
        let selectionDismissed = strictTrue("bible.reader.selectionHintDismissed")

        var reflections: [String: SundayReflection] = [:]
        for key in keys where key.hasPrefix("vesper.sunday.") {
            let fields = object(key) ?? [:]
            let before = string(fields["before"]) ?? ""
            let after = string(fields["after"]) ?? ""
            if (fields["before"] != nil && string(fields["before"]) == nil) ||
                (fields["after"] != nil && string(fields["after"]) == nil) { issues.insert(key) }
            reflections[String(key.dropFirst("vesper.sunday.".count))] = SundayReflection(before: before, after: after)
        }

        var favorites: [String] = []
        if let value = loaded("vesper.prayer.favorites") {
            if case let .array(entries) = value {
                favorites = entries.compactMap(string)
                if favorites.count != entries.count { issues.insert("vesper.prayer.favorites") }
            } else { issues.insert("vesper.prayer.favorites") }
        }

        var calendar = CalendarNotificationSettings()
        if let fields = object("john.calendar-notifications.v1") {
            let hour = integer(fields["hour"])
            let minute = integer(fields["minute"])
            calendar = CalendarNotificationSettings(enabled: boolTrue(fields["enabled"]),
                hour: hour.flatMap { (0...23).contains($0) ? $0 : nil } ?? 8,
                minute: minute.flatMap { (0...59).contains($0) ? $0 : nil } ?? 0)
            if (fields["enabled"] != nil && fields["enabled"] != .bool(true) && fields["enabled"] != .bool(false)) ||
                (fields["hour"] != nil && (hour.map { !(0...23).contains($0) } ?? true)) ||
                (fields["minute"] != nil && (minute.map { !(0...59).contains($0) } ?? true)) { issues.insert("john.calendar-notifications.v1") }
        }

        var rosary = RosaryReminderSettings()
        if let fields = object("rosary.reminder.v1") {
            let frequency = string(fields["frequency"]) == "weekly" ? "weekly" : "daily"
            let hour = integer(fields["hour"])
            let minute = integer(fields["minute"])
            let weekday = integer(fields["weekday"])
            let notificationID = string(fields["notificationId"])
            rosary = RosaryReminderSettings(enabled: boolTrue(fields["enabled"]), frequency: frequency,
                hour: hour.flatMap { (0...23).contains($0) ? $0 : nil } ?? 20,
                minute: minute.flatMap { (0...59).contains($0) ? $0 : nil } ?? 0,
                weekday: weekday.flatMap { (1...7).contains($0) ? $0 : nil } ?? 2,
                notificationID: notificationID)
            if (fields["enabled"] != nil && fields["enabled"] != .bool(true) && fields["enabled"] != .bool(false)) ||
                (fields["frequency"] != nil && string(fields["frequency"]) == nil) ||
                (fields["hour"] != nil && (hour.map { !(0...23).contains($0) } ?? true)) ||
                (fields["minute"] != nil && (minute.map { !(0...59).contains($0) } ?? true)) ||
                (fields["weekday"] != nil && (weekday.map { !(1...7).contains($0) } ?? true)) ||
                (fields["notificationId"] != nil && notificationID == nil) { issues.insert("rosary.reminder.v1") }
        }

        var positions: [String: WorkReadingPosition] = [:]
        if let fields = object("works.position.v1") {
            for (workID, value) in fields {
                guard case let .object(positionFields) = value,
                      case let .number(sectionIndex)? = positionFields["sectionIndex"], sectionIndex.isFinite else {
                    issues.insert("works.position.v1")
                    continue
                }
                positions[workID] = WorkReadingPosition(fields: positionFields)
            }
        }

        var progress: [String: NovenaProgress] = [:]
        for id in novenaIDs {
            let key = "novena.\(id).progress.v1"
            guard keys.contains(key) else { continue }
            let fields = object(key) ?? [:]
            let completed: [Int]
            if case let .array(values)? = fields["completedDays"] {
                completed = Array(Set(values.compactMap(integer).filter { (1...novenaDays).contains($0) })).sorted()
                if values.contains(where: { integer($0).map { !(1...novenaDays).contains($0) } ?? true }) { issues.insert(key) }
            } else {
                completed = []
                if fields["completedDays"] != nil { issues.insert(key) }
            }
            let selected = integer(fields["selectedDay"]).flatMap { (1...novenaDays).contains($0) ? $0 : nil } ?? 1
            let intention = string(fields["intention"]) ?? ""
            if (fields["selectedDay"] != nil && selected == 1 && integer(fields["selectedDay"]) != 1) ||
                (fields["intention"] != nil && string(fields["intention"]) == nil) { issues.insert(key) }
            progress[id] = NovenaProgress(completedDays: completed, selectedDay: selected, intention: intention)
        }

        let state = NativePersistentState(themeScheme: rawTheme, translationID: translationID,
            rotationIntervalMinutes: interval, verseScope: scope, readerLocation: location,
            readingPreferences: preferences, widgetGuideDismissed: guideDismissed,
            selectionHintDismissed: selectionDismissed, reflections: reflections,
            favoritePrayerIDs: favorites, calendarNotifications: calendar, rosaryReminder: rosary,
            worksPositions: positions, novenaProgress: progress)
        return LegacyStateNormalization(state: state, issues: issues.sorted())
    }
}
