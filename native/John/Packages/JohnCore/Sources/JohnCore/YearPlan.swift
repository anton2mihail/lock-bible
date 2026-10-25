import Foundation

/// "A Year with the Fathers" (2.3.0): one reading a day from the library through 2027.
///
/// The plan file (`Catalogs/year-plan.json`) is built by `scripts/build-year-plan.mjs` from works.db. Day 1 is
/// 1 January 2027, so the readings for a feast fall on that feast for anyone who joins on the day. A person can
/// also begin at Day 1 on any date; then the plan counts from that date.
public struct YearPlan: Codable, Sendable, Equatable {
    public struct Reading: Codable, Sendable, Equatable, Hashable {
        public let workId: String
        public let section: Int
        public let fromParagraph: Int
        public let toParagraph: Int
        public init(workId: String, section: Int, fromParagraph: Int, toParagraph: Int) {
            self.workId = workId; self.section = section; self.fromParagraph = fromParagraph; self.toParagraph = toParagraph
        }
    }

    public struct Day: Codable, Sendable, Equatable, Identifiable {
        public let day: Int
        /// The 2027 date of this day, `yyyy-MM-dd`.
        public let date: String
        public let season: String
        public let feast: String?
        public let author: String
        public let work: String
        public let title: String
        public let words: Int
        public let minutes: Int
        public let readings: [Reading]
        public var id: Int { day }
    }

    public let version: Int
    public let name: String
    public let year: Int
    public let startDate: String
    public let freeDays: Int
    public let days: [Day]

    public static func load(from url: URL) throws -> YearPlan {
        let plan: YearPlan
        do { plan = try JSONDecoder().decode(YearPlan.self, from: Data(contentsOf: url)) }
        catch { throw CoreError.invalidResource("Year plan: \(error)") }
        guard plan.version == 1, plan.days.map(\.day) == Array(1...plan.days.count) else {
            throw CoreError.invalidResource("Year plan days are not numbered 1 to \(plan.days.count)")
        }
        return plan
    }

    public func day(_ number: Int) -> Day? {
        guard number >= 1, number <= days.count else { return nil }
        return days[number - 1]
    }
}

/// Where a person is in the plan. All dates are calendar days in the person's time zone.
public enum YearPlanSchedule {
    /// Read days are kept in the reading progress file under this key, so they sync with read chapters.
    public static let progressKey = "fathers-year-2027"
    public static let yearStartKey = "2027-01-01"
    public static let dayCount = 365

    /// How a person starts the plan.
    public enum Start: String, Sendable, Equatable {
        /// Today's day of 2027, so the seasons match. Earlier days stay open to read.
        case joinToday
        /// Day 1 today; the plan counts from today.
        case beginAtDayOne
    }

    /// The day of 2027 for a date (1 = 1 January), or nil outside 2027.
    public static func dayOfYear(_ date: Date, timeZone: TimeZone) -> Int? {
        let number = dayNumber(startKey: yearStartKey, today: date, timeZone: timeZone)
        return (1...dayCount).contains(number) ? number : nil
    }

    /// True before 1 January 2027 in this time zone.
    public static func isBeforeYear(_ date: Date, timeZone: TimeZone) -> Bool {
        dayNumber(startKey: yearStartKey, today: date, timeZone: timeZone) < 1
    }

    /// The plan day for today: 1 on the start date. Zero or less before the start; more than 365 after the end.
    public static func dayNumber(startKey: String, today: Date, timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = startKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let start = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return 0 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: today)).day ?? 0
        return days + 1
    }

    /// The choice the start screen offers first: join in January (the seasons still match), begin later.
    public static func suggestedStart(_ date: Date, timeZone: TimeZone) -> Start {
        guard let day = dayOfYear(date, timeZone: timeZone) else { return .beginAtDayOne }
        return day <= 31 ? .joinToday : .beginAtDayOne
    }

    /// The start key to save for a choice made today.
    public static func startKey(_ start: Start, today: Date, timeZone: TimeZone) -> String {
        switch start {
        case .joinToday where !isBeforeYear(today, timeZone: timeZone): yearStartKey
        default: ReadingProgressMath.dayKey(today, timeZone: timeZone)
        }
    }

    /// Days before today that are not read, oldest first.
    public static func missedDays(read: Set<Int>, today: Int, joinedAt: Int = 1) -> [Int] {
        guard today > 1 else { return [] }
        return (max(1, joinedAt)..<min(today, dayCount + 1)).filter { !read.contains($0) }
    }

    /// Days after the free days need the library purchase.
    public static func isLocked(day: Int, freeDays: Int, libraryUnlocked: Bool) -> Bool {
        !libraryUnlocked && day > freeDays
    }

    /// The local dates and plan days of the next reminders, starting today if the time has not passed.
    /// Reminders are scheduled one by one, so each can name its reading, and stop after Day 365.
    public static func reminderDates(startKey: String, now: Date, hour: Int, minute: Int, timeZone: TimeZone,
                                     count: Int) -> [(day: Int, date: Date)] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var result: [(Int, Date)] = []
        var cursor = calendar.startOfDay(for: now)
        var guardCount = 0
        while result.count < count, guardCount < dayCount + 400 {
            guardCount += 1
            defer { cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86_400) }
            guard let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: cursor), fire > now else { continue }
            let day = dayNumber(startKey: startKey, today: cursor, timeZone: timeZone)
            if day > dayCount { break }
            if day >= 1 { result.append((day, fire)) }
        }
        return result
    }
}
