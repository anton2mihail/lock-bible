import Foundation

/// A built-in reading plan. A plan reads one book in a fixed number of days.
public struct ReadingPlan: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let bookCode: String
    public let bookName: String
    public let chapterCount: Int
    public let days: Int

    public static let all: [ReadingPlan] = [
        ReadingPlan(id: "john-21", title: "John in 21 days", bookCode: "JHN", bookName: "John", chapterCount: 21, days: 21),
        ReadingPlan(id: "john-7", title: "John in 7 days", bookCode: "JHN", bookName: "John", chapterCount: 21, days: 7),
    ]
    public static func plan(id: String) -> ReadingPlan? { all.first { $0.id == id } }

    /// The chapters for a zero-based day. A day after the end gives the last day.
    public func chapters(forDay day: Int) -> [Int] {
        let index = min(max(day, 0), days - 1)
        let lower = index * chapterCount / days + 1
        let upper = (index + 1) * chapterCount / days
        return upper >= lower ? Array(lower...upper) : []
    }
}

public struct ReadingReminderSettings: Codable, Sendable, Equatable {
    public var enabled: Bool
    public var hour: Int
    public var minute: Int
    /// Optional so an older file stays valid. `nil` means a normal reminder.
    public var timeSensitive: Bool?
    public init(enabled: Bool = false, hour: Int = 8, minute: Int = 0, timeSensitive: Bool? = nil) {
        self.enabled = enabled; self.hour = hour; self.minute = minute; self.timeSensitive = timeSensitive
    }
}

/// The saved data. Every new field is optional so an older file stays valid.
public struct ReadingProgressData: Codable, Sendable, Equatable {
    public var version = 1
    /// Book code to the sorted chapter numbers that the user read.
    public var read: [String: [Int]] = [:]
    public var planID: String?
    /// The start of day for the plan, as a `yyyy-MM-dd` key in the user's calendar.
    public var planStartKey: String?
    public var reminder: ReadingReminderSettings?
    /// "A Year with the Fathers": the date of the person's Day 1 (`yyyy-MM-dd`). Read days are in `read`
    /// under `YearPlanSchedule.progressKey`, so they sync like read chapters.
    public var yearStartKey: String?
    /// The date the person started (`yyyy-MM-dd`). With "Join today" it is later than Day 1; days before it are
    /// open to read but never counted as missed.
    public var yearJoinedKey: String?
    /// The daily reminder for the year plan.
    public var yearReminder: ReadingReminderSettings?
    public init() {}

    public var yearDaysRead: Set<Int> { readChapters(YearPlanSchedule.progressKey) }

    public func readChapters(_ book: String) -> Set<Int> { Set(read[book] ?? []) }
    public func totalRead(counts: [String: Int]) -> Int {
        read.reduce(0) { sum, item in
            guard let count = counts[item.key] else { return sum }
            return sum + Set(item.value).filter { (1...count).contains($0) }.count
        }
    }
}

public enum ReadingProgressMath {
    /// The part of a book that is read, from 0 to 1.
    public static func fraction(read: Int, total: Int) -> Double {
        total > 0 ? min(1, max(0, Double(read) / Double(total))) : 0
    }

    public static func dayKey(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Whole days from the start key to today. It is never negative.
    public static func dayIndex(startKey: String, today: Date, timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = startKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let start = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return 0 }
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: today)
        return max(0, calendar.dateComponents([.day], from: from, to: to).day ?? 0)
    }
}

/// Reading progress lives in its own JSON file. The database and the main state file do not change.
public actor ReadingProgressStore {
    private let url: URL
    private var cache: ReadingProgressData?

    public init(url: URL) { self.url = url }

    public func data() -> ReadingProgressData {
        if let cache { return cache }
        return (try? load()) ?? ReadingProgressData()
    }

    private func load() throws -> ReadingProgressData {
        if let cache { return cache }
        guard FileManager.default.fileExists(atPath: url.path) else {
            cache = ReadingProgressData(); return ReadingProgressData()
        }
        let raw = try Data(contentsOf: url)
        do {
            let loaded = try JSONDecoder().decode(ReadingProgressData.self, from: raw)
            cache = loaded
            return loaded
        } catch {
            var target = url.appendingPathExtension("corrupt")
            var n = 1
            while FileManager.default.fileExists(atPath: target.path) {
                target = url.appendingPathExtension("corrupt\(n)"); n += 1
            }
            try FileManager.default.moveItem(at: url, to: target)
            cache = ReadingProgressData()
            return ReadingProgressData()
        }
    }

    private func write(_ value: ReadingProgressData) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
        cache = value
    }

    public func setRead(_ isRead: Bool, book: String, chapter: Int) throws {
        var value = try load()
        var set = Set(value.read[book] ?? [])
        if isRead { set.insert(chapter) } else { set.remove(chapter) }
        value.read[book] = set.isEmpty ? nil : set.sorted()
        try write(value)
    }

    /// Adds read chapters from another device. It never removes a chapter.
    public func mergeRead(_ incoming: [String: [Int]]) throws {
        var value = try load()
        let merged = SyncMerge.mergeRead(value.read, incoming)
        guard merged != value.read else { return }
        value.read = merged
        try write(value)
    }

    public func startPlan(_ id: String?, startKey: String?) throws {
        var value = try load()
        value.planID = id
        value.planStartKey = id == nil ? nil : startKey
        try write(value)
    }

    public func setReminder(_ settings: ReadingReminderSettings) throws {
        var value = try load()
        value.reminder = settings
        try write(value)
    }

    public func startYear(startKey: String?, joinedKey: String? = nil) throws {
        var value = try load()
        value.yearStartKey = startKey
        value.yearJoinedKey = startKey == nil ? nil : (joinedKey ?? startKey)
        try write(value)
    }

    public func setYearReminder(_ settings: ReadingReminderSettings) throws {
        var value = try load()
        value.yearReminder = settings
        try write(value)
    }

    /// Clears chapters read and the plan. The reminder choice and "A Year with the Fathers" stay.
    public func reset() throws {
        var value = try load()
        let year = value.read[YearPlanSchedule.progressKey]
        value.read = year.map { [YearPlanSchedule.progressKey: $0] } ?? [:]
        value.planID = nil
        value.planStartKey = nil
        try write(value)
    }
}
