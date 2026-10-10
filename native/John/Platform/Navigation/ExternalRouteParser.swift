import Foundation
import JohnCore

/// A parsed `nrsv://` URL.
///
/// The old app let Expo Router open the route and let each screen decide what
/// to do with its parameters, so a bad parameter never rejected the URL. It
/// selected a fallback. The parser keeps that rule. `AppRouter.receive` checks
/// book and chapter against the edition.
enum ExternalRoute: Sendable {
    /// `nil` when the URL has no date, or a date that fails the source check.
    case daily(String?)
    case rosary
    /// Opens the Saved tab. Spotlight uses it for a saved item.
    case saved
    case read(bookCode: String?, chapter: Int?, verse: String?, endVerse: String?, translation: TranslationID?)
}

enum ExternalRouteParser {
    static func parse(_ url: URL) -> ExternalRoute? {
        guard url.scheme?.lowercased() == "nrsv",
              let host = url.host?.lowercased(),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let values = Dictionary(components.queryItems?.map { ($0.name, $0.value ?? "") } ?? [], uniquingKeysWith: { first, _ in first })
        if host == "daily" {
            // Old app: `parseDate` (src/services/companion/calendar.ts:13-18) uses today for a missing or bad date.
            return .daily(values["date"].flatMap { isValidDateKey($0) ? $0 : nil })
        }
        if host == "saved" { return .saved }
        if host == "pray", components.path == "/rosary" { return .rosary }
        guard host == "read" else { return nil }
        // Old app: ReaderScreen.tsx:84-90 reads book, chapter, verse, endVerse, and contextRequest only.
        // It never reads `translation`, so that value cannot change the route. Native keeps a valid value.
        return .read(bookCode: nonEmpty(values["book"]),
                     chapter: values["chapter"].flatMap { Int($0) },
                     verse: nonEmpty(values["verse"]),
                     endVerse: nonEmpty(values["endVerse"]),
                     translation: values["translation"].flatMap { TranslationID(rawValue: $0) })
    }

    /// An empty value equals an absent value. The old Reader tests truthiness (ReaderScreen.tsx:129-130, :287, :299-300).
    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private static func isValidDateKey(_ value: String) -> Bool {
        guard value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { return false }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value) else { return false }
        return formatter.string(from: date) == value
    }
}
