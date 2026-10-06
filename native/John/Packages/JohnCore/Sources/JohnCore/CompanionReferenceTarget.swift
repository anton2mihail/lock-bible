import Foundation

public struct CompanionReferenceTarget: Codable, Hashable, Sendable {
    public let originalCitation: String
    public let bookCode: String
    public let chapter: Int

    public init(originalCitation: String, bookCode: String, chapter: Int) throws {
        guard !originalCitation.isEmpty, !bookCode.isEmpty, chapter > 0 else {
            throw CoreError.invalidIdentity("companion reference target")
        }
        self.originalCitation = originalCitation
        self.bookCode = bookCode
        self.chapter = chapter
    }
}

public enum CompanionReferenceTargetParser {
    /// Map one citation to a WEB-CE book and whole chapter. Keep its source text for display.
    public static func parse(_ citation: String, webCEBooks: [BibleBookDescriptor]) -> CompanionReferenceTarget? {
        let collapsed = citation
            .replacingOccurrences(of: #"^See\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        var normalized = collapsed
        normalized = normalized.replacingOccurrences(of: #"^Joel 3:"#, with: "Joel 2:", options: [.regularExpression, .caseInsensitive])
        normalized = normalized.replacingOccurrences(of: #"^Joel 4:"#, with: "Joel 3:", options: [.regularExpression, .caseInsensitive])
        let esther: [String: String] = ["A": "1", "B": "3", "C": "4", "D": "5", "E": "8", "F": "10"]
        for (letter, chapter) in esther {
            normalized = normalized.replacingOccurrences(
                of: #"^Esther "# + letter + #":"#,
                with: "Esther \(chapter):", options: [.regularExpression, .caseInsensitive]
            )
        }
        normalized = normalized.replacingOccurrences(
            of: #"^(Philemon|Jude|2 John|3 John) ([0-9]+)(?![0-9:])"#,
            with: "$1 1:$2", options: [.regularExpression, .caseInsensitive]
        )
        guard let regex = try? NSRegularExpression(pattern: #"^(.+?)\s+([0-9]+):"#, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
              let bookRange = Range(match.range(at: 1), in: normalized),
              let chapterRange = Range(match.range(at: 2), in: normalized),
              let chapter = Int(normalized[chapterRange]) else { return nil }
        guard let manifestData = try? JSONEncoder().encode(webCEBooks),
              let searchBooks = try? JSONDecoder().decode([SearchBookMetadata].self, from: manifestData) else { return nil }
        guard let parsed = BibleReferenceParser.parse("\(normalized[bookRange]) \(chapter)", books: searchBooks),
              let target = try? CompanionReferenceTarget(originalCitation: citation, bookCode: parsed.book.code, chapter: parsed.chapter) else {
            return nil
        }
        return target
    }
}
