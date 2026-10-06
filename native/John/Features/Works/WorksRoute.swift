import Foundation
import JohnCore

enum WorksRoute: Hashable, Sendable {
    case library
    case collection(id: String)
    case work(id: String, section: Int?)
    case chapterCommentary(bookCode: String, chapter: Int, bookName: String)
}

enum WorksSourceText {
    static let kindOrder = ["commentary", "sermons", "letters", "treatise", "devotional", "prayers", "autobiography", "rule", "history"]

    static func kindLabel(_ kind: String) -> String {
        switch kind {
        case "commentary": "On Scripture"
        case "sermons": "Sermons & Homilies"
        case "letters": "Letters"
        case "treatise": "Treatises"
        case "devotional": "Devotional"
        case "prayers": "Prayers & Meditations"
        case "autobiography": "Life & Confessions"
        case "rule": "Rules of Life"
        case "history": "History"
        default: kind
        }
    }

    static func sectionNoun(_ kind: String) -> String {
        switch kind {
        case "sermons": "homily"
        case "letters": "letter"
        case "treatise", "devotional", "history", "rule": "chapter"
        case "prayers": "prayer"
        case "autobiography": "book"
        default: "section"
        }
    }

    static func plural(_ count: Int, _ noun: String) -> String { "\(count) \(noun)\(count == 1 ? "" : "s")" }

    static func readingLength(_ words: Int) -> String {
        let minutes = max(1, Int((Double(words) / 200).rounded()))
        if minutes < 60 { return "\(minutes) min" }
        let hours = Int((Double(minutes) / 60).rounded())
        return hours == 1 ? "about an hour" : "about \(hours) hours"
    }

    static func corpusSize(_ words: Int) -> String {
        if words >= 1_000_000 { return String(format: "%.1fm words", locale: Locale(identifier: "en_US_POSIX"), Double(words) / 1_000_000) }
        return "\(Int((Double(words) / 1000).rounded()))k words"
    }

    static func positionIndex(_ value: WorkReadingPosition?, key: String, fallback: Int = 0) -> Int {
        guard case let .number(number)? = value?.fields[key], number.isFinite,
              number >= 0, number < Double(Int.max) else { return fallback }
        return Int(number)
    }
}
