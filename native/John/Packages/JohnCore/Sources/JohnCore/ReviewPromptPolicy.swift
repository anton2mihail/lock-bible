import Foundation

/// When John 1:1 may ask for an App Store rating (2.1.0).
///
/// The app asks only right after a person finishes a prayer (a whole Rosary or a novena day), and only when
/// they have done that at least three times or opened the app on at least seven different days. It asks at
/// most once every 120 days. Apple also limits the system prompt to three times a year and may show nothing.
public enum ReviewPromptPolicy {
    public static let prayerThreshold = 3
    public static let openDayThreshold = 7
    public static let cooldownDays = 120

    public static func shouldAsk(prayersCompleted: Int, distinctOpenDays: Int, lastAsked: Date?, now: Date) -> Bool {
        guard prayersCompleted >= prayerThreshold || distinctOpenDays >= openDayThreshold else { return false }
        guard let lastAsked else { return true }
        return now.timeIntervalSince(lastAsked) >= Double(cooldownDays) * 86_400
    }

    /// A local calendar day key such as "2026-10-23", used to count distinct days the app was opened.
    public static func dayKey(for date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
