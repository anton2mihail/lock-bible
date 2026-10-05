import Foundation
import JohnCore

enum ExternalRoute: Sendable {
    case daily(String)
    case read(bookCode: String, chapter: Int, verse: String, endVerse: String?, translation: TranslationID?)
}

enum ExternalRouteParser {
    static func parse(_ url: URL) -> ExternalRoute? {
        guard url.scheme?.lowercased() == "nrsv",
              let host = url.host?.lowercased(),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let values = Dictionary(components.queryItems?.map { ($0.name, $0.value ?? "") } ?? [], uniquingKeysWith: { first, _ in first })
        if host == "daily" {
            guard let date = values["date"], isValidDateKey(date) else { return nil }
            return .daily(date)
        }
        guard host == "read",
              let book = values["book"], !book.isEmpty,
              let chapter = values["chapter"].flatMap(Int.init), chapter > 0,
              let verse = values["verse"], !verse.isEmpty else { return nil }
        let translation: TranslationID?
        if let raw = values["translation"] {
            guard let parsed = TranslationID(rawValue: raw) else { return nil }
            translation = parsed
        } else {
            translation = nil
        }
        let endVerse = values["endVerse"]
        guard endVerse == nil || !(endVerse?.isEmpty ?? true) else { return nil }
        return .read(bookCode: book, chapter: chapter, verse: verse, endVerse: endVerse, translation: translation)
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
