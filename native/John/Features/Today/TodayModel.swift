import Foundation
import Observation
import JohnCore

enum LiturgicalSeason: String, Sendable {
    case advent, christmas, lent, triduum, easter, ordinary

    var title: String {
        switch self {
        case .advent: "Advent"
        case .christmas: "Christmas"
        case .lent: "Lent"
        case .triduum: "The Sacred Triduum"
        case .easter: "Easter"
        case .ordinary: "Ordinary Time"
        }
    }

    var artworkName: String {
        switch self {
        case .advent: "advent.jpg"
        case .christmas: "joyful-3.jpg"
        case .lent: "sorrowful-1.jpg"
        case .triduum: "sorrowful-5.jpg"
        case .easter: "glorious-1.jpg"
        case .ordinary: "scripture.jpg"
        }
    }
}

@MainActor @Observable final class TodayModel {
    private(set) var now = Date()
    private(set) var verse: RotatingVerse?
    private(set) var loadError: String?

    @ObservationIgnored private let appResources: URL?
    @ObservationIgnored private let rotation: (any RotationRepository)?
    @ObservationIgnored private let clock: any CoreClock

    init(appResources: URL?, rotation: (any RotationRepository)?, clock: any CoreClock = SystemCoreClock()) {
        self.appResources = appResources
        self.rotation = rotation
        self.clock = clock
    }

    var dateKey: String { Self.key(for: now) }
    var season: LiturgicalSeason { Self.season(for: now) }
    var dateLine: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d"
        return "JOHN 1:1  /  \(formatter.string(from: now))"
    }
    var heroTitle: String { season.title }
    var suggestedRosary: (id: String, title: String) {
        let ids = ["glorious", "joyful", "sorrowful", "glorious", "luminous", "sorrowful", "joyful"]
        let names = ["glorious": "The Glorious Mysteries", "joyful": "The Joyful Mysteries", "sorrowful": "The Sorrowful Mysteries", "luminous": "The Luminous Mysteries"]
        let id = ids[Calendar.current.component(.weekday, from: now) - 1]
        return (id, names[id] ?? "The Joyful Mysteries")
    }
    var sundayDate: Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let offset = (8 - weekday) % 7
        return calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) ?? now
    }
    var sundaySubtitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM d"
        return "\(formatter.string(from: sundayDate)) · Read, reflect, return"
    }
    var artworkDirectory: URL? { appResources?.appendingPathComponent("Artwork", isDirectory: true) }

    func artworkURL(_ name: String) -> URL? { artworkDirectory?.appendingPathComponent(name) }

    func refresh(translation: TranslationID, scope: RotationScope, intervalMinutes: Int,
                 at requestedDate: Date? = nil, timeZone requestedTimeZone: TimeZone = .autoupdatingCurrent) async {
        let clockReading = clock.now()
        let instant = requestedDate ?? clockReading.instant
        let utcOffsetSeconds = requestedDate.map { requestedTimeZone.secondsFromGMT(for: $0) }
            ?? clockReading.utcOffsetSeconds
        now = instant
        guard let rotation else { verse = nil; return }
        do {
            let count = try await rotation.poolCount(translation: translation, scope: scope)
            guard count > 0 else { verse = nil; return }
            let slot = try RotationMath.slot(at: instant, utcOffsetSeconds: utcOffsetSeconds, intervalMinutes: max(1, intervalMinutes))
            let index = try RotationMath.index(for: slot, count: count)
            verse = try await rotation.verse(translation: translation, scope: scope, at: index)
        } catch {
            verse = nil
            loadError = "The daily verse could not be loaded."
        }
    }

    private static func key(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func season(for date: Date) -> LiturgicalSeason {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        func day(_ date: Date, _ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date)) ?? date
        }
        let year = calendar.component(.year, from: date)
        let easter = easterSunday(year, calendar: calendar)
        var christmasParts = DateComponents(); christmasParts.year = year; christmasParts.month = 12; christmasParts.day = 25
        let christmas = calendar.date(from: christmasParts) ?? date
        let christmasWeekday = calendar.component(.weekday, from: christmas)
        let jsWeekday = christmasWeekday - 1
        let daysBackToSunday = jsWeekday == 0 ? 7 : jsWeekday
        let advent = day(christmas, -daysBackToSunday - 21)
        let januarySecond = calendar.date(from: DateComponents(year: year, month: 1, day: 2)) ?? date
        let janSecondWeekday = calendar.component(.weekday, from: januarySecond)
        let epiphany = day(januarySecond, (8 - janSecondWeekday) % 7)
        let epiphanyDay = calendar.component(.day, from: epiphany)
        let baptism = day(epiphany, epiphanyDay >= 7 ? 1 : 7)
        let current = calendar.startOfDay(for: date)
        if current <= baptism || current >= calendar.startOfDay(for: christmas) { return .christmas }
        if current >= advent { return .advent }
        if current >= easter && current <= day(easter, 49) { return .easter }
        if current >= day(easter, -3) && current < easter { return .triduum }
        if current >= day(easter, -46) && current < easter { return .lent }
        return .ordinary
    }

    private static func easterSunday(_ year: Int, calendar: Calendar) -> Date {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let n = h + l - 7 * m + 114
        let month = n / 31
        let date = n % 31 + 1
        return calendar.date(from: DateComponents(year: year, month: month, day: date)) ?? Date()
    }
}
