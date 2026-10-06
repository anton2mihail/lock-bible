import Foundation

public enum BibleSearchScope: String, Codable, Sendable {
    case all
    case ot
    case nt
}

public struct BibleSearchRequest: Codable, Hashable, Sendable {
    public let requestID: String
    public let query: String
    public let translationID: TranslationID
    public let scope: BibleSearchScope
    public let limit: Int

    public init(requestID: String, query: String, translationID: TranslationID,
                scope: BibleSearchScope = .all, limit: Int = 60) {
        self.requestID = requestID
        self.query = query
        self.translationID = translationID
        self.scope = scope
        self.limit = limit
    }
}

public struct BibleSearchResult: Codable, Hashable, Sendable {
    public let id: Int64
    public let bookCode: String
    public let bookName: String
    public let group: String
    public let chapter: Int
    public let verse: String
    public let verseOrder: Int
    public let text: String
    public let reference: String
}

public struct BibleSearchResponse: Codable, Hashable, Sendable {
    public let requestID: String
    public let results: [BibleSearchResult]
    public let correctedQuery: String?
    public let isReference: Bool
}

/// This actor owns the read-only search database connection and manifest cache.
public actor SQLiteSearchRepository {
    private enum Parameter {
        case text(String)
        case integer(Int64)
    }

    private struct VerseRow {
        let id: Int64
        let bookCode: String
        let bookName: String
        let group: String
        let chapter: Int
        let verse: String
        let verseOrder: Int
        let text: String
    }

    private struct VocabularyRow {
        let word: String
        let frequency: Int64
        let sourceIndex: Int
    }

    private let databaseURL: URL
    private var database: SQLiteConnection?
    private let resourceRoots: ResourceRoots
    private var manifests: [TranslationID: [SearchBookMetadata]] = [:]

    /// Store resource URLs only. A blank query does not open SQLite.
    public init(databaseURL: URL, resourceRoots: ResourceRoots) {
        self.databaseURL = databaseURL
        self.resourceRoots = resourceRoots
    }

    public func search(_ request: BibleSearchRequest) throws -> BibleSearchResponse {
        let query = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return BibleSearchResponse(requestID: request.requestID, results: [], correctedQuery: nil, isReference: false)
        }
        let books = try manifest(for: request.translationID)
        if let reference = BibleReferenceParser.parse(query, books: books) {
            let results = try searchReference(reference, request: request)
            return BibleSearchResponse(requestID: request.requestID, results: results, correctedQuery: nil, isReference: true)
        }

        let originalResults = try searchText(query, translationID: request.translationID, scope: request.scope, limit: request.limit)
        if !originalResults.isEmpty {
            return BibleSearchResponse(requestID: request.requestID, results: originalResults, correctedQuery: nil, isReference: false)
        }

        let corrected = try correctQuery(query, translationID: request.translationID)
        if corrected == Self.searchableTokens(query).joined(separator: " ") {
            return BibleSearchResponse(requestID: request.requestID, results: [], correctedQuery: nil, isReference: false)
        }
        let correctedResults = try searchText(corrected, translationID: request.translationID, scope: request.scope, limit: request.limit)
        return BibleSearchResponse(requestID: request.requestID, results: correctedResults,
                                   correctedQuery: correctedResults.isEmpty ? nil : corrected, isReference: false)
    }

    private func manifest(for translationID: TranslationID) throws -> [SearchBookMetadata] {
        if let cached = manifests[translationID] { return cached }
        let url = try resourceRoots.appResource("Bible", translationID.rawValue, "manifest.json")
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw CoreError.missingResource("search book manifest") }
        let decoded: [SearchBookMetadata]
        do { decoded = try JSONDecoder().decode([SearchBookMetadata].self, from: data) }
        catch { throw CoreError.invalidResource("search book manifest") }
        guard !decoded.isEmpty,
              decoded.allSatisfy({ !$0.code.isEmpty && $0.chapterCount > 0 }),
              Set(decoded.map(\.code)).count == decoded.count else {
            throw CoreError.invalidResource("search book manifest entries")
        }
        manifests[translationID] = decoded
        return decoded
    }

    private func connection() throws -> SQLiteConnection {
        if let database { return database }
        let opened = try SQLiteConnection(url: databaseURL, readOnly: true)
        database = opened
        return opened
    }

    private func searchReference(_ reference: ParsedBibleReference, request: BibleSearchRequest) throws -> [BibleSearchResult] {
        var sql = "SELECT v.id, v.book_code, v.book_name, v.group_name, v.chapter, v.verse, v.verse_order, v.text FROM verses v WHERE v.translation_id = ? AND v.book_code = ? AND v.chapter = ?"
        var parameters: [Parameter] = [.text(request.translationID.rawValue), .text(reference.book.code), .integer(Int64(reference.chapter))]
        if let startText = reference.startVerse {
            let start = try sqliteIntegerPrefix(startText)
            let end = try sqliteIntegerPrefix(reference.endVerse ?? startText)
            sql += " AND CAST(v.verse AS INTEGER) BETWEEN ? AND ?"
            parameters += [.integer(min(start, end)), .integer(max(start, end))]
        }
        sql += scopeClause(request.scope)
        sql += " ORDER BY v.verse_order LIMIT ?"
        parameters.append(.integer(try checkedLimit(request.limit)))
        return try queryVerses(sql, parameters: parameters)
    }

    private func searchText(_ query: String, translationID: TranslationID, scope: BibleSearchScope, limit: Int) throws -> [BibleSearchResult] {
        guard let fts = Self.buildFTSQuery(query) else { return [] }
        let sql = "SELECT v.id, v.book_code, v.book_name, v.group_name, v.chapter, v.verse, v.verse_order, v.text FROM verse_search JOIN verses v ON v.id = verse_search.rowid WHERE verse_search MATCH ? AND v.translation_id = ?\(scopeClause(scope)) ORDER BY bm25(verse_search), v.book_order, v.chapter, v.verse_order LIMIT ?"
        let parameters: [Parameter] = [.text(fts), .text(translationID.rawValue), .integer(try checkedLimit(limit))]
        return try queryVerses(sql, parameters: parameters)
    }

    private func queryVerses(_ sql: String, parameters: [Parameter]) throws -> [BibleSearchResult] {
        let database = try connection()
        let statement = try database.prepare(sql)
        defer { _ = statement.finalize() }
        for (offset, parameter) in parameters.enumerated() {
            let index = Int32(offset + 1)
            switch parameter {
            case let .text(value): try statement.bind(value, at: index)
            case let .integer(value): try statement.bind(value, at: index)
            }
        }
        var results: [BibleSearchResult] = []
        while try statement.step() {
            let group = try statement.text(3)
            guard ["ot", "deutero", "nt"].contains(group) else { throw CoreError.invalidResource("search verse group") }
            let chapter = statement.integer(4)
            let verseOrder = statement.integer(6)
            guard let chapterValue = Int(exactly: chapter), let verseOrderValue = Int(exactly: verseOrder) else {
                throw CoreError.invalidResource("search result coordinates")
            }
            let bookName = try statement.text(2)
            let verse = try statement.text(5)
            results.append(BibleSearchResult(
                id: statement.integer(0), bookCode: try statement.text(1), bookName: bookName,
                group: group, chapter: chapterValue, verse: verse, verseOrder: verseOrderValue,
                text: try statement.text(7), reference: "\(bookName) \(chapterValue):\(verse)"
            ))
        }
        return results
    }

    private func correctQuery(_ query: String, translationID: TranslationID) throws -> String {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("\"") { return query }
        return try Self.searchableTokens(query).map { try correctedWord($0, translationID: translationID) }.joined(separator: " ")
    }

    private func correctedWord(_ token: String, translationID: TranslationID) throws -> String {
        let database = try connection()
        let length = token.utf16.count
        if length < 4 { return token }
        let exact = try database.prepare("SELECT word FROM vocabulary WHERE translation_id = ? AND word = ?")
        try exact.bind(translationID.rawValue, at: 1)
        try exact.bind(token, at: 2)
        defer { _ = exact.finalize() }
        if try exact.step() { return token }

        let maximum = length >= 5 ? 2 : 1
        let candidates = try database.prepare("SELECT word, frequency FROM vocabulary WHERE translation_id = ? AND substr(word, 1, 1) = substr(?, 1, 1) AND length(word) BETWEEN ? AND ? ORDER BY frequency DESC LIMIT 300")
        try candidates.bind(translationID.rawValue, at: 1)
        try candidates.bind(token, at: 2)
        try candidates.bind(Int64(length - maximum), at: 3)
        try candidates.bind(Int64(length + maximum), at: 4)
        defer { _ = candidates.finalize() }
        var rows: [VocabularyRow] = []
        while try candidates.step() {
            rows.append(VocabularyRow(word: try candidates.text(0), frequency: candidates.integer(1), sourceIndex: rows.count))
        }
        let matches = rows.compactMap { row -> (VocabularyRow, Int)? in
            let distance = BibleReferenceParser.editDistance(token, row.word, maximum: maximum)
            return distance <= maximum ? (row, distance) : nil
        }
        let winner = matches.min { left, right in
            if left.1 != right.1 { return left.1 < right.1 }
            if left.0.frequency != right.0.frequency { return left.0.frequency > right.0.frequency }
            return left.0.sourceIndex < right.0.sourceIndex
        }
        return winner?.0.word ?? token
    }

    private func scopeClause(_ scope: BibleSearchScope) -> String {
        switch scope {
        case .all: return ""
        case .ot: return " AND v.group_name IN ('ot', 'deutero')"
        case .nt: return " AND v.group_name = 'nt'"
        }
    }

    public nonisolated static func buildFTSQuery(_ query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.count > 2,
           !trimmed.contains("\n"), !trimmed.contains("\r"),
           !trimmed.contains("\u{2028}"), !trimmed.contains("\u{2029}") {
            let phrase = String(trimmed.dropFirst().dropLast())
            let cleaned = searchableTokens(phrase).joined(separator: " ")
            return cleaned.isEmpty ? nil : "\"\(cleaned.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        let tokens = searchableTokens(query)
        guard !tokens.isEmpty else { return nil }
        return tokens.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"*" }.joined(separator: " AND ")
    }

    private nonisolated static func searchableTokens(_ query: String) -> [String] {
        // Search tokenization keeps punctuation as a boundary. Reference
        // normalization removes periods for book-name matching, so do not use it here.
        let compatibility = query.decomposedStringWithCompatibilityMapping
        let withoutMarks = String(String.UnicodeScalarView(compatibility.unicodeScalars.filter {
            !CharacterSet.nonBaseCharacters.contains($0)
        }))
        let normalized = withoutMarks.lowercased(with: Locale(identifier: "en"))
        guard let regex = try? NSRegularExpression(pattern: #"[\p{L}\p{N}]+(?:['’][\p{L}\p{N}]+)*"#) else { return [] }
        let range = NSRange(normalized.startIndex..., in: normalized)
        return regex.matches(in: normalized, range: range).compactMap { match in
            guard let tokenRange = Range(match.range, in: normalized) else { return nil }
            return String(normalized[tokenRange])
        }
    }

    private func checkedLimit(_ limit: Int) throws -> Int64 {
        guard let value = Int64(exactly: limit) else { throw CoreError.invalidResource("search result limit") }
        return value
    }

    private func sqliteIntegerPrefix(_ value: String) throws -> Int64 {
        let prefix = value.prefix(while: { $0 >= "0" && $0 <= "9" })
        guard !prefix.isEmpty, let number = Int64(prefix) else { throw CoreError.invalidResource("reference verse number") }
        return number
    }
}
