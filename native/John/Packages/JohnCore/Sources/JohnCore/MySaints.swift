import Foundation

public struct SaintObservance: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let tradition: String
    public let entryID: String
    public let monthDay: String
    public let name: String
    public let sourceURL: String
    public let calendarURL: String
    public let account: String
    public let reviewedSummary: String?
    public var displayAccount: String { reviewedSummary ?? account }
    public var displayIsSummary: Bool { reviewedSummary != nil || isSummary }
    public let isSummary: Bool
    public let sourceLanguage: String
    public let observanceNote: String?
    public var calendarName: String {
        tradition == "byzantine" ? "Byzantine Catholic · Ruthenian" : "Vatican News"
    }
}

public struct PersonalSaint: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let subtitle: String
    public let artwork: String?
    public let artworkCredit: String?
    public let novenaID: String?
    public let commemorations: [SaintObservance]

    public func observance(for profile: SaintProfile) -> SaintObservance? {
        commemorations.first { $0.id == profile.observanceID } ?? commemorations.first
    }
}

public struct SaintNote: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let kind: String
    public let text: String
    public let createdAt: Date
    public init(id: String = UUID().uuidString, kind: String, text: String, createdAt: Date = .now) {
        self.id = id; self.kind = kind; self.text = text; self.createdAt = createdAt
    }
}

public struct SaintProfile: Codable, Hashable, Sendable {
    public var saved = false
    public var reason = ""
    public var notes: [SaintNote] = []
    public var observanceID: String?
    /// Fixed occurrence, not an automatically repeating prayer plan.
    public var plannedFeastDate: String?
    public var reminderEnabled = false
    public var reminderHour = 8
    public var reminderMinute = 0
    public init() {}
}

public struct MySaintsState: Codable, Hashable, Sendable {
    public var profiles: [String: SaintProfile] = [:]
    public var widgetSaintID: String?
    public var widgetQuiet = false
    public init() {}
}

/// Contains public devotional content only. Never add user notes or intentions here.
public struct SaintWidgetContent: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let artwork: String?
    public let text: String
    public let source: String
    public let monthDay: String
    public let calendarName: String
    public init(saint: PersonalSaint, observance: SaintObservance) {
        id = saint.id; name = saint.name; artwork = saint.artwork
        monthDay = observance.monthDay; calendarName = observance.calendarName
        // This response is already in the app's sourced St. Joseph novena.
        text = saint.id == "st-joseph"
            ? "St. Joseph, Patron of departing souls, pray for us. Amen"
            : observance.account
        source = saint.id == "st-joseph" ? "Novena to St. Joseph · EWTN" : observance.calendarName
    }
}

public enum SaintDates {
    /// Includes today. Skips impossible dates instead of rolling February 29 into March.
    public static func nextOccurrence(monthDay: String, from now: Date, timeZone: TimeZone) -> Date? {
        let calendar = CompanionCalendar.gregorianCalendar(timeZone: timeZone)
        let year = calendar.component(.year, from: now)
        let parts = monthDay.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        for candidate in year...(year + 8) {
            let components = DateComponents(timeZone: timeZone, year: candidate, month: parts[0], day: parts[1], hour: 12)
            guard let date = calendar.date(from: components),
                  String(CompanionCalendar.dateKey(date, timeZone: timeZone).suffix(5)) == monthDay,
                  calendar.startOfDay(for: date) >= calendar.startOfDay(for: now) else { continue }
            return date
        }
        return nil
    }

    public static func reminderDate(monthDay: String, hour: Int, minute: Int, after now: Date, timeZone: TimeZone) -> Date? {
        let calendar = CompanionCalendar.gregorianCalendar(timeZone: timeZone)
        guard let day = nextOccurrence(monthDay: monthDay, from: now, timeZone: timeZone),
              let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { return nil }
        if date > now { return date }
        return nextOccurrence(monthDay: monthDay, from: CompanionCalendar.addDays(day, 1, timeZone: timeZone), timeZone: timeZone)
            .flatMap { calendar.date(bySettingHour: hour, minute: minute, second: 0, of: $0) }
    }

    public static func novenaStart(feast: Date, timeZone: TimeZone) -> Date {
        CompanionCalendar.addDays(feast, -9, timeZone: timeZone)
    }

    public static func planIsDue(_ profile: SaintProfile, now: Date, timeZone: TimeZone) -> Bool {
        guard let key = profile.plannedFeastDate else { return false }
        let feast = CompanionCalendar.parseDate(key, fallback: now, timeZone: timeZone)
        guard CompanionCalendar.dateKey(feast, timeZone: timeZone) == key else { return false }
        let day = CompanionCalendar.dateKey(now, timeZone: timeZone)
        return day >= CompanionCalendar.dateKey(novenaStart(feast: feast, timeZone: timeZone), timeZone: timeZone) && day < key
    }
}
