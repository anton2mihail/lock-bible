import Foundation

/// Lent and Holy Week (2.3.0): which day of Lent it is, from Ash Wednesday (Easter − 46) to Easter Sunday.
///
/// Each day has a key ("ash-wed", "lent1-sun" … "lent5-sat", "palm-sun" … "easter-sun") that names its Collect
/// and its Holy Week texts in `Catalogs/lent.json`. Week 5 begins on Passion Sunday.
public enum LentCalendar {
    public struct Day: Equatable, Sendable {
        public let key: String
        /// 0 for Ash Wednesday to Saturday, 1...5 for the weeks of Lent, 6 for Holy Week and Easter Sunday.
        public let week: Int
        /// 1 = Sunday ... 7 = Saturday.
        public let weekday: Int
        /// Days since Ash Wednesday, 0...46.
        public let offset: Int

        public var isSunday: Bool { weekday == 1 }
        public var isFriday: Bool { weekday == 6 }
        /// From Passion Sunday (the fifth Sunday) to Holy Saturday.
        public var isPassiontide: Bool { offset >= 32 && offset < 46 }
        /// Palm Sunday to Easter Sunday.
        public var isHolyWeek: Bool { offset >= 39 }
        public var isEasterSunday: Bool { offset == 46 }

        /// "The days after Ash Wednesday", "Week 3 of Lent", "Holy Week".
        public var weekLabel: String {
            switch week {
            case 0: "The days after Ash Wednesday"
            case 6: "Holy Week"
            default: "Week \(week) of Lent"
            }
        }

        /// The day's own name in Holy Week and on Ash Wednesday, else nil.
        public var dayTitle: String? {
            if offset == 0 { return "Ash Wednesday" }
            guard offset >= 39 else { return nil }
            return LentCalendar.holyWeekTitles[offset - 39]
        }
    }

    public static let leoWorkID = "leo-great.the-letters-and-sermons-of-leo-the-great"
    /// St Leo the Great, "On Lent" I, II, IV, VIII, XI, the Transfiguration homily and "On the Passion": free from
    /// Ash Wednesday to Easter Sunday (decision L1).
    public static let leoSections = 191...204

    static let weekdayKeys = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
    public static let holyWeekKeys = ["palm-sun", "holy-mon", "holy-tue", "holy-wed", "holy-thu", "good-fri", "holy-sat", "easter-sun"]
    public static let holyWeekTitles = ["Palm Sunday", "Monday of Holy Week", "Tuesday of Holy Week", "Wednesday of Holy Week",
                                        "Holy Thursday", "Good Friday", "Holy Saturday", "Easter Sunday"]
    /// Ash Wednesday to the Saturday before Palm Sunday: 39 days.
    public static let lentKeys: [String] = ["ash-wed", "ash-thu", "ash-fri", "ash-sat"]
        + (1...5).flatMap { week in weekdayKeys.map { "lent\(week)-\($0)" } }
    public static let allKeys = lentKeys + holyWeekKeys

    public static func ashWednesday(year: Int, timeZone: TimeZone) -> Date? {
        CompanionCalendar.easterSunday(year: year, timeZone: timeZone).map { CompanionCalendar.addDays($0, -46, timeZone: timeZone) }
    }

    /// The day of Lent or Holy Week on `date` in `timeZone`, or nil before Ash Wednesday and after Easter Sunday.
    public static func day(on date: Date, timeZone: TimeZone) -> Day? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let ash = ashWednesday(year: year, timeZone: timeZone),
              let noon = calendar.date(from: DateComponents(year: year, month: parts.month, day: parts.day, hour: 12)),
              let offset = calendar.dateComponents([.day], from: calendar.startOfDay(for: ash), to: calendar.startOfDay(for: noon)).day,
              (0...46).contains(offset) else { return nil }
        let key = allKeys[offset]
        let week = offset < 4 ? 0 : (offset < 39 ? (offset - 4) / 7 + 1 : 6)
        return Day(key: key, week: week, weekday: calendar.component(.weekday, from: noon), offset: offset)
    }

    /// True from Ash Wednesday to Easter Sunday: Leo's sermons on Lent and the Passion read free.
    public static func isLeoSeason(on date: Date, timeZone: TimeZone) -> Bool {
        day(on: date, timeZone: timeZone) != nil
    }
}

extension FathersLibraryAccess {
    /// `isSectionFree`, plus St Leo's sermons on Lent and the Passion from Ash Wednesday to Easter Sunday (L1).
    public static func isSectionFree(workID: String, index: Int, on date: Date, timeZone: TimeZone) -> Bool {
        if isSectionFree(workID: workID, index: index) { return true }
        return workID == LentCalendar.leoWorkID && LentCalendar.leoSections.contains(index)
            && LentCalendar.isLeoSeason(on: date, timeZone: timeZone)
    }
}
