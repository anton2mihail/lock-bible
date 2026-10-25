import Foundation

/// "The Fathers on today's Gospel" (2.2.0): find the commentary for a day's Gospel and make a short excerpt.
///
/// The Catena Aurea of St Thomas Aquinas (Matthew, Mark) is verse by verse, so its index entries carry a verse range.
/// Other Fathers' commentaries are indexed by chapter only; they are the fallback for Luke and John.
public enum GospelFathers {
    public struct Reference: Equatable, Sendable {
        public let bookCode: String; public let chapter: Int; public let verse: Int
        public init(bookCode: String, chapter: Int, verse: Int) { self.bookCode = bookCode; self.chapter = chapter; self.verse = verse }
    }

    private static let books = ["Matthew": "MAT", "Mark": "MRK", "Luke": "LUK", "John": "JHN"]

    /// The Gospel reference of a day: the last reading labelled "Gospel..." (Palm Sunday has two; the Mass Gospel is last).
    public static func gospelReference(in entry: CalendarReadingsEntry?) -> String? {
        entry?.readings.last { $0.label.lowercased().hasPrefix("gospel") }?.reference
    }

    /// Book, chapter and first verse of a reference such as "Matthew 9:35–10:1, 5a, 6-8" or "Luke 7:18b-23".
    public static func parse(_ reference: String) -> Reference? {
        let text = reference.replacingOccurrences(of: "\u{00A0}", with: " ")
        guard let match = text.firstMatch(of: /^\s*(Matthew|Mark|Luke|John)\s+(\d+)\s*:\s*(\d+)/),
              let code = books[String(match.1)], let chapter = Int(match.2), let verse = Int(match.3),
              chapter > 0, verse > 0 else { return nil }
        return Reference(bookCode: code, chapter: chapter, verse: verse)
    }

    /// The best commentary entry for a reference. Order: the Catena section that contains the verse; the Catena section
    /// that starts closest before it; any other Father on that chapter. Nil when no Father wrote on the chapter.
    public static func entry(for reference: Reference, in commentary: [String: [String: [CommentaryEntry]]]) -> CommentaryEntry? {
        guard let entries = commentary[reference.bookCode]?[String(reference.chapter)], !entries.isEmpty else { return nil }
        let ranged = entries.filter { $0.fromVerse != nil && $0.toVerse != nil }
            .sorted { ($0.fromVerse ?? 0, $0.sectionIndex) < ($1.fromVerse ?? 0, $1.sectionIndex) }
        if let hit = ranged.first(where: { ($0.fromVerse ?? 0) <= reference.verse && reference.verse <= ($0.toVerse ?? 0) }) { return hit }
        if let before = ranged.last(where: { ($0.fromVerse ?? 0) <= reference.verse }) { return before }
        if let first = ranged.first { return first }
        return entries.first
    }

    public struct Excerpt: Equatable, Sendable {
        public let father: String; public let text: String
    }

    private static let fathers: [String: String] = [
        "aug": "St Augustine", "augustine": "St Augustine", "chrys": "St John Chrysostom", "chrysostom": "St John Chrysostom",
        "pseudo-chrys": "Pseudo-Chrysostom", "greg": "St Gregory the Great", "gregory": "St Gregory the Great",
        "hil": "St Hilary", "hilary": "St Hilary", "jerome": "St Jerome", "hier": "St Jerome", "bede": "St Bede",
        "ambrose": "St Ambrose", "amb": "St Ambrose", "raban": "Rabanus Maurus", "rabanus": "Rabanus Maurus",
        "remig": "Remigius", "remigius": "Remigius", "theophyl": "Theophylact", "theophylact": "Theophylact",
        "gloss": "The Gloss", "orig": "Origen", "origen": "Origen", "cyril": "St Cyril", "leo": "St Leo the Great",
        "athan": "St Athanasius", "basil": "St Basil", "isidore": "St Isidore", "anselm": "St Anselm", "alcuin": "Alcuin",
        "pseudo-jerome": "Pseudo-Jerome", "victor": "Victor of Antioch", "severianus": "Severian", "dionysius": "Dionysius",
        "euseb": "Eusebius", "eusebius": "Eusebius", "cyprian": "St Cyprian", "pseudo-origen": "Pseudo-Origen",
    ]

    /// The comment Today shows from a Catena section (paragraph 0 is the Gospel text). It prefers the first comment by a
    /// named Father; the Gloss and works only attributed to a Father ("Pseudo-") are used when no other comment exists.
    /// "Aug., de Cons. Ev., ii, 1: ..." becomes father "St Augustine" and the text after the colon, cut near [limit].
    public static func excerpt(from paragraphs: [String], limit: Int = 360) -> Excerpt? {
        guard paragraphs.count > 1 else { return nil }
        let candidates = paragraphs.dropFirst().compactMap { split($0) }
        let preferred = candidates.first { $0.named && !$0.father.hasPrefix("Pseudo") && $0.father != "The Gloss" }
        guard let chosen = preferred ?? candidates.first else { return nil }
        return Excerpt(father: chosen.father, text: cut(chosen.body, limit: limit))
    }

    private static func split(_ comment: String) -> (father: String, body: String, named: Bool)? {
        var father = "The Fathers", body = comment, named = false
        if let colon = comment.firstIndex(of: ":"), comment.distance(from: comment.startIndex, to: colon) <= 60 {
            let label = String(comment[..<colon])
            let head = label.split(whereSeparator: { $0 == "," || $0 == " " }).first.map(String.init) ?? label
            let key = head.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")).trimmingCharacters(in: .whitespaces)
            if let name = fathers[key] { father = name; body = String(comment[comment.index(after: colon)...]); named = true }
        }
        body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? nil : (father, body, named)
    }

    static func cut(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let window = String(text.prefix(limit))
        if let end = window.lastIndex(where: { ".;?!".contains($0) }), window.distance(from: window.startIndex, to: end) >= limit / 3 {
            return String(window[...end])
        }
        let words = window.split(separator: " ").dropLast().joined(separator: " ")
        return words + "…"
    }
}
