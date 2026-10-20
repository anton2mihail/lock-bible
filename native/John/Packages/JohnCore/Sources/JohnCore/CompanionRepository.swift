import Foundation

/// This actor reads each small App resource on first use. Its initializer does no I/O.
public actor BundledCompanionRepository {
    private let roots: ResourceRoots
    private var catalogCache: DevotionalCatalog?
    private var readingsCache: ReadingsCalendar?
    private var celebrationsCache: CelebrationsCalendar?
    private var saintsCache: [SaintsCalendar]?
    private var personalSaintsCache: [PersonalSaint]?

    public init(roots: ResourceRoots) { self.roots = roots }

    public func personalSaints() throws -> [PersonalSaint] {
        if let personalSaintsCache { return personalSaintsCache }
        let url = try roots.appResource("Calendar", "my-saints.json")
        let values = try JSONDecoder().decode([PersonalSaint].self, from: Data(contentsOf: url))
        guard !values.isEmpty, Set(values.map(\.id)).count == values.count,
              values.allSatisfy({ !$0.commemorations.isEmpty }) else {
            throw CoreError.invalidResource("My Saints catalog")
        }
        personalSaintsCache = values
        return values
    }

    public func saintsCalendars() throws -> [SaintsCalendar] {
        if let saintsCache { return saintsCache }
        let values = try ["vatican", "byzantine"].map { tradition in
            let url = try roots.appResource("Calendar", "saints-\(tradition).json")
            let value = try JSONDecoder().decode(SaintsCalendar.self, from: Data(contentsOf: url))
            try value.validate()
            return value
        }
        saintsCache = values
        return values
    }

    public func devotionalCatalog() throws -> DevotionalCatalog {
        if let catalogCache { return catalogCache }
        let url = try roots.appResource("Catalogs", "devotional-catalogs.json")
        let value = try JSONDecoder().decode(DevotionalCatalog.self, from: Data(contentsOf: url))
        try value.validate()
        catalogCache = value
        return value
    }

    public func readings() throws -> ReadingsCalendar {
        if let readingsCache { return readingsCache }
        let url = try roots.appResource("Calendar", "readings-us.json")
        let value = try JSONDecoder().decode(ReadingsCalendar.self, from: Data(contentsOf: url))
        guard value.dates.count == 858, value.dates["2025-09-18"] == nil,
              value.dates.keys.allSatisfy({ Self.isStrictDateKey($0) }),
              value.dates.values.allSatisfy({ !$0.title.isEmpty && !$0.readings.isEmpty && $0.readings.allSatisfy { !$0.label.isEmpty && !$0.reference.isEmpty } }) else {
            throw CoreError.invalidResource("readings calendar shape")
        }
        readingsCache = value
        return value
    }

    public func celebrations() throws -> CelebrationsCalendar {
        if let celebrationsCache { return celebrationsCache }
        let url = try roots.appResource("Calendar", "celebrations-us.json")
        let value = try JSONDecoder().decode(CelebrationsCalendar.self, from: Data(contentsOf: url))
        guard value.dates.count == 2_922, value.dates.keys.allSatisfy({ Self.isStrictDateKey($0) }),
              value.dates.values.allSatisfy({ !$0.title.isEmpty && !$0.season.isEmpty && !$0.rank.isEmpty }) else {
            throw CoreError.invalidResource("celebrations calendar shape")
        }
        celebrationsCache = value
        return value
    }

    private static func isStrictDateKey(_ key: String) -> Bool {
        guard key.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil,
              let zone = TimeZone(secondsFromGMT: 0) else { return false }
        let parsed = CompanionCalendar.parseDate(key, fallback: Date(timeIntervalSince1970: 0), timeZone: zone)
        return CompanionCalendar.dateKey(parsed, timeZone: zone) == key
    }
}

public enum CompanionCalendar {
    public static let label = "United States · Roman Rite"
    public static let seasonNames: [String: String] = [
        "advent": "Advent", "christmas": "Christmas", "lent": "Lent",
        "triduum": "The Sacred Triduum", "easter": "Easter", "ordinary": "Ordinary Time",
    ]

    public static func gregorianCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    public static func dateKey(_ date: Date, timeZone: TimeZone) -> String {
        let parts = gregorianCalendar(timeZone: timeZone).dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(String(format: "%02d", parts.month ?? 0))-\(String(format: "%02d", parts.day ?? 0))"
    }

    /// Parse a strict source date. Invalid input or a rolled date uses fallback local noon.
    public static func parseDate(_ value: String?, fallback: Date, timeZone: TimeZone) -> Date {
        let calendar = gregorianCalendar(timeZone: timeZone)
        func fallbackNoon() -> Date {
            let parts = calendar.dateComponents([.year, .month, .day], from: fallback)
            var noon = DateComponents(); noon.calendar = calendar; noon.timeZone = timeZone
            noon.year = parts.year; noon.month = parts.month; noon.day = parts.day; noon.hour = 12
            return calendar.date(from: noon) ?? fallback
        }
        guard let value, value.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil else {
            return fallbackNoon()
        }
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return fallbackNoon() }
        var input = DateComponents(); input.calendar = calendar; input.timeZone = timeZone
        // JavaScript Date(year, ...) adds 1900 when year is from 0 through 99.
        input.year = parts[0] <= 99 ? parts[0] + 1_900 : parts[0]
        input.month = parts[1]; input.day = parts[2]; input.hour = 12
        guard let date = calendar.date(from: input), dateKey(date, timeZone: timeZone) == value else {
            return fallbackNoon()
        }
        return date
    }

    public static func addDays(_ date: Date, _ count: Int, timeZone: TimeZone) -> Date {
        let calendar = gregorianCalendar(timeZone: timeZone)
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        var noon = DateComponents(); noon.calendar = calendar; noon.timeZone = timeZone
        noon.year = parts.year; noon.month = parts.month; noon.day = parts.day; noon.hour = 12
        guard let localNoon = calendar.date(from: noon), let result = calendar.date(byAdding: .day, value: count, to: localNoon) else {
            return date
        }
        return result
    }

    public static func upcomingSunday(_ date: Date, timeZone: TimeZone) -> Date {
        let weekday = gregorianCalendar(timeZone: timeZone).component(.weekday, from: date)
        return addDays(date, (8 - weekday) % 7, timeZone: timeZone)
    }

    public static func easterSunday(year: Int, timeZone: TimeZone) -> Date? {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451, n = h + l - 7 * m + 114
        var parts = DateComponents(); parts.calendar = gregorianCalendar(timeZone: timeZone); parts.timeZone = timeZone
        parts.year = year; parts.month = n / 31; parts.day = n % 31 + 1; parts.hour = 12
        return parts.calendar?.date(from: parts)
    }

    public static func season(_ date: Date, timeZone: TimeZone) -> String {
        let calendar = gregorianCalendar(timeZone: timeZone)
        let normalized = parseDate(dateKey(date, timeZone: timeZone), fallback: date, timeZone: timeZone)
        let p = calendar.dateComponents([.year, .month, .day], from: normalized)
        guard let year = p.year, let easter = easterSunday(year: year, timeZone: timeZone) else { return "ordinary" }
        func local(_ month: Int, _ day: Int) -> Date {
            var parts = DateComponents(); parts.calendar = calendar; parts.timeZone = timeZone
            parts.year = year; parts.month = month; parts.day = day; parts.hour = 12
            return calendar.date(from: parts) ?? date
        }
        let christmas = local(12, 25)
        let advent = addDays(christmas, -(calendar.component(.weekday, from: christmas) == 1 ? 7 : calendar.component(.weekday, from: christmas) - 1) - 21, timeZone: timeZone)
        let jan2 = local(1, 2)
        let epiphany = addDays(jan2, (8 - calendar.component(.weekday, from: jan2)) % 7, timeZone: timeZone)
        let baptism = addDays(epiphany, calendar.component(.day, from: epiphany) >= 7 ? 1 : 7, timeZone: timeZone)
        if normalized <= baptism || normalized >= christmas { return "christmas" }
        if normalized >= advent { return "advent" }
        if normalized >= easter && normalized <= addDays(easter, 49, timeZone: timeZone) { return "easter" }
        if normalized >= addDays(easter, -3, timeZone: timeZone) && normalized < easter { return "triduum" }
        if normalized >= addDays(easter, -46, timeZone: timeZone) && normalized < easter { return "lent" }
        return "ordinary"
    }

    public static func readings(for date: Date, from calendar: ReadingsCalendar, timeZone: TimeZone) -> CalendarReadingsEntry? {
        calendar.dates[dateKey(date, timeZone: timeZone)]
    }

    public static func celebration(for date: Date, from calendar: CelebrationsCalendar, timeZone: TimeZone) -> CalendarCelebration? {
        calendar.dates[dateKey(date, timeZone: timeZone)]
    }

    public static func coverage(_ dates: [String: some Sendable]) -> CalendarCoverage? {
        guard let first = dates.keys.min(), let last = dates.keys.max() else { return nil }
        return CalendarCoverage(firstDate: first, lastDate: last, count: dates.count)
    }

    public static func readingsURL(_ date: Date, timeZone: TimeZone) -> String {
        let p = gregorianCalendar(timeZone: timeZone).dateComponents([.year, .month, .day], from: date)
        return String(format: "https://bible.usccb.org/bible/readings/%02d%02d%02d.cfm", p.month ?? 0, p.day ?? 0, (p.year ?? 0) % 100)
    }
}

public enum NovenaProgressSelectors {
    public static func normalize(_ progress: NovenaProgress?) -> NovenaProgress {
        guard let progress else { return NovenaProgress() }
        let completed = Array(Set(progress.completedDays.filter { (1...9).contains($0) })).sorted()
        let selected = (1...9).contains(progress.selectedDay) ? progress.selectedDay : 1
        return NovenaProgress(completedDays: completed, selectedDay: selected, intention: progress.intention)
    }

    public static func setIntention(_ value: String, in progress: NovenaProgress) -> NovenaProgress {
        NovenaProgress(completedDays: progress.completedDays, selectedDay: progress.selectedDay, intention: value)
    }

    public static func selectDay(_ day: Int, in progress: NovenaProgress) throws -> NovenaProgress {
        guard (1...9).contains(day) else { throw CoreError.invalidIdentity("novena day") }
        return NovenaProgress(completedDays: progress.completedDays, selectedDay: day, intention: progress.intention)
    }

    public static func completeSelectedDay(_ progress: NovenaProgress) -> NovenaProgress {
        guard (1...9).contains(progress.selectedDay), !progress.completedDays.contains(progress.selectedDay) else { return progress }
        let completed = Array(Set(progress.completedDays + [progress.selectedDay])).sorted()
        let next = (1...9).first { !completed.contains($0) } ?? progress.selectedDay
        return NovenaProgress(completedDays: completed, selectedDay: next, intention: progress.intention)
    }

    public static func reset() -> NovenaProgress { NovenaProgress() }
}

public enum TodaySelectors {
    public static func prayer(hour: Int) -> (id: String, title: String, subtitle: String) {
        hour < 17 ? ("morning", "Morning Offering", "Apostleship of Prayer")
                  : ("evening", "Night Prayer", "The collect of Compline")
    }

    public static func prayer(date: Date, timeZone: TimeZone) -> (id: String, title: String, subtitle: String) {
        prayer(hour: CompanionCalendar.gregorianCalendar(timeZone: timeZone).component(.hour, from: date))
    }

    public static func rosaryWeekdaySet(date: Date, timeZone: TimeZone) -> String {
        let weekday = CompanionCalendar.gregorianCalendar(timeZone: timeZone).component(.weekday, from: date)
        return ["glorious", "joyful", "sorrowful", "glorious", "luminous", "sorrowful", "joyful"][weekday - 1]
    }

    public static func ongoingNovenas(catalog: DevotionalCatalog, progressByID: [String: NovenaProgress]) -> [TodayNovena] {
        catalog.novenas.compactMap { novena in
            let progress = NovenaProgressSelectors.normalize(progressByID[novena.id])
            guard (progress.completedDays.count > 0 || !isJavaScriptTrimEmpty(progress.intention)), progress.completedDays.count < 9 else { return nil }
            let next = (1...9).first { !progress.completedDays.contains($0) } ?? 9
            return TodayNovena(novena: novena, progress: progress, firstIncompleteDay: next)
        }
    }

    private static func isJavaScriptTrimEmpty(_ text: String) -> Bool {
        let trim: Set<UInt32> = [0x0009,0x000A,0x000B,0x000C,0x000D,0x0020,0x00A0,0x1680,0x2000,0x2001,0x2002,0x2003,0x2004,0x2005,0x2006,0x2007,0x2008,0x2009,0x200A,0x2028,0x2029,0x202F,0x205F,0x3000,0xFEFF]
        return text.unicodeScalars.allSatisfy { trim.contains($0.value) }
    }

    public static func title(readings: CalendarReadingsEntry?, celebration: CalendarCelebration?, season: String) -> String {
        readings?.title ?? celebration?.title ?? CompanionCalendar.seasonNames[season] ?? season
    }
}
