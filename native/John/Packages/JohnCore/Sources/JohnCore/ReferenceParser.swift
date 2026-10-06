import Foundation

public struct SearchBookMetadata: Decodable, Hashable, Sendable {
    public let code: String
    public let name: String
    public let longName: String
    public let group: String
    public let order: Int
    public let chapterCount: Int
}

public struct ParsedBibleReference: Hashable, Sendable {
    public let book: SearchBookMetadata
    public let chapter: Int
    public let startVerse: String?
    public let endVerse: String?
}

public enum BibleReferenceParser {
    private static let aliases: [String: [String]] = [
        "GEN": ["gen"], "EXO": ["ex", "exod"], "LEV": ["lev"], "NUM": ["num"],
        "DEU": ["deut", "dt"], "JOS": ["josh"], "JDG": ["judg"],
        "PSA": ["ps", "psalm", "psalms"], "PRO": ["prov"], "ECC": ["eccl"],
        "SNG": ["song", "song of songs", "songs", "sos"], "ISA": ["isa"],
        "JER": ["jer"], "LAM": ["lam"], "EZK": ["ezek", "ezk"], "DAN": ["dan"],
        "OBA": ["obad"], "MIC": ["mic"], "NAM": ["nah", "nahum"], "HAB": ["hab"],
        "ZEP": ["zeph"], "HAG": ["hag"], "ZEC": ["zech"], "MAL": ["mal"],
        "MAT": ["matt", "mt"], "MRK": ["mark", "mk"], "LUK": ["luke", "lk"],
        "JHN": ["john", "jn"], "ACT": ["acts"], "ROM": ["rom"], "GAL": ["gal"],
        "EPH": ["eph"], "PHP": ["phil", "philippians"], "COL": ["col"],
        "TIT": ["tit"], "PHM": ["phlm", "philemon"], "HEB": ["heb"],
        "JAS": ["jas", "james"], "JUD": ["jude"], "REV": ["rev", "revelation"],
    ]

    public static func normalize(_ value: String) -> String {
        let decomposed = value.decomposedStringWithCompatibilityMapping
        let withoutMarks = String(String.UnicodeScalarView(decomposed.unicodeScalars.filter {
            !CharacterSet.nonBaseCharacters.contains($0)
        }))
        let folded = withoutMarks.lowercased(with: Locale(identifier: "en"))
        let noPeriods = folded.replacingOccurrences(of: ".", with: "")
        let collapsed = noPeriods.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Match JavaScript string indexing by comparing UTF-16 code units.
    public static func editDistance(_ left: String, _ right: String, maximum: Int = Int.max) -> Int {
        let leftUnits = Array(left.utf16)
        let rightUnits = Array(right.utf16)
        if abs(leftUnits.count - rightUnits.count) > maximum { return maximum == Int.max ? Int.max : maximum + 1 }
        if leftUnits.isEmpty { return rightUnits.count }
        if rightUnits.isEmpty { return leftUnits.count }
        var previous = Array(0...rightUnits.count)
        var current = Array(repeating: 0, count: rightUnits.count + 1)
        for leftIndex in 1...leftUnits.count {
            current[0] = leftIndex
            var rowMinimum = current[0]
            for rightIndex in 1...rightUnits.count {
                let substitution = previous[rightIndex - 1] + (leftUnits[leftIndex - 1] == rightUnits[rightIndex - 1] ? 0 : 1)
                current[rightIndex] = min(previous[rightIndex] + 1, current[rightIndex - 1] + 1, substitution)
                rowMinimum = min(rowMinimum, current[rightIndex])
            }
            if rowMinimum > maximum { return maximum == Int.max ? rowMinimum : maximum + 1 }
            swap(&previous, &current)
        }
        return previous[rightUnits.count]
    }

    public static func parse(_ query: String, books: [SearchBookMetadata]) -> ParsedBibleReference? {
        let normalizedDashes = query.replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "—", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^(.+?)\s+([0-9]+)(?:(?:\s*:\s*|\s+)([0-9]+[a-z]?)(?:\s*-\s*([0-9]+[a-z]?))?)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: normalizedDashes, range: NSRange(normalizedDashes.startIndex..., in: normalizedDashes)),
              let bookRange = Range(match.range(at: 1), in: normalizedDashes),
              let chapterRange = Range(match.range(at: 2), in: normalizedDashes),
              let chapter = Int(normalizedDashes[chapterRange]), chapter > 0,
              let book = findBook(String(normalizedDashes[bookRange]), in: books),
              chapter <= book.chapterCount else { return nil }
        let start = capture(match, group: 3, in: normalizedDashes)
        let end = capture(match, group: 4, in: normalizedDashes) ?? start
        return ParsedBibleReference(book: book, chapter: chapter, startVerse: start, endVerse: end)
    }

    private static func capture(_ match: NSTextCheckingResult, group: Int, in text: String) -> String? {
        guard match.range(at: group).location != NSNotFound, let range = Range(match.range(at: group), in: text) else { return nil }
        return String(text[range])
    }

    private static func aliases(for book: SearchBookMetadata) -> [String] {
        let numbered = book.name.replacingOccurrences(of: #"^([1-4])\s+"#, with: "$1", options: .regularExpression)
        return ([book.code, book.name, book.longName, numbered] + (aliases[book.code] ?? []))
            .map(normalize).filter { !$0.isEmpty }
    }

    private static func findBook(_ value: String, in books: [SearchBookMetadata]) -> SearchBookMetadata? {
        let normalized = normalize(value)
        for book in books where aliases(for: book).contains(normalized) { return book }
        let length = normalized.utf16.count
        guard length >= 4 else { return nil }
        let maximum = length >= 8 ? 2 : 1
        var best: (book: SearchBookMetadata, distance: Int)?
        for book in books {
            for alias in aliases(for: book) {
                let distance = editDistance(normalized, alias, maximum: maximum)
                if distance <= maximum, best == nil || distance < best!.distance {
                    best = (book, distance)
                }
            }
        }
        return best?.book
    }
}
