#if DEBUG
import Foundation
import JohnCore

private struct Fixture: Decodable {
    let sourceHashes: [String: String]
    let cases: [SearchCase]
    let parsedReferences: [ParsedCase]
    let parserProbes: ParserProbes
}

private struct ParserProbes: Decodable {
    let normalized: [NormalizationProbe]
    let utf16EditDistance: [EditDistanceProbe]
    let ftsQueries: [FTSProbe]
}

private struct NormalizationProbe: Decodable { let value: String; let expected: String }
private struct EditDistanceProbe: Decodable { let left: String; let right: String; let expected: Int }
private struct FTSProbe: Decodable { let query: String; let expected: String? }

private struct SearchCase: Decodable {
    let requestID: String
    let request: SearchRequest
    let expected: ExpectedResponse
}

private struct SearchRequest: Decodable {
    let id: String
    let translationID: String
    let scope: String
    let query: String
    let limit: Int?
}

private struct ExpectedResponse: Codable, Equatable {
    let results: [ExpectedResult]
    let correctedQuery: String?
    let isReference: Bool
}

private struct ExpectedResult: Codable, Equatable {
    let id: Int64
    let bookCode: String
    let bookName: String
    let group: String
    let chapter: Int
    let verse: String
    let verseOrder: Int
    let text: String
    let reference: String
}

private struct ParsedCase: Decodable {
    let query: String
    let byEdition: [String: JSONValue]
}

private enum JSONValue: Decodable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([JSONValue].self)) }
    }
}

private struct SearchComparison: Codable {
    let requestID: String
    let matchesSource: Bool
    let actual: ExpectedResponse
}

private struct ParserComparison: Codable {
    let query: String
    let edition: String
    let matchesSource: Bool
    let actual: JSONValueOutput?
}

private struct JSONValueOutput: Codable {
    let code: String
    let group: String
    let order: Int
    let chapter: Int
    let startVerse: String?
    let endVerse: String?

    private enum CodingKeys: String, CodingKey { case code, group, order, chapter, startVerse, endVerse }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(group, forKey: .group)
        try container.encode(order, forKey: .order)
        try container.encode(chapter, forKey: .chapter)
        if let startVerse { try container.encode(startVerse, forKey: .startVerse) }
        else { try container.encodeNil(forKey: .startVerse) }
        if let endVerse { try container.encode(endVerse, forKey: .endVerse) }
        else { try container.encodeNil(forKey: .endVerse) }
    }
}

private struct Report: Codable {
    let formatVersion: Int
    let fixtureSourceHashes: [String: String]
    let searchCount: Int
    let searchMatches: Int
    let searchMismatches: [String]
    let parserCount: Int
    let parserMatches: Int
    let parserMismatches: [String]
    let normalizationCount: Int
    let normalizationMatches: Int
    let normalizationMismatches: [String]
    let editDistanceCount: Int
    let editDistanceMatches: Int
    let editDistanceMismatches: [String]
    let ftsProbeCount: Int
    let ftsProbeMatches: Int
    let ftsProbeMismatches: [String]
    let searches: [SearchComparison]
    let parsers: [ParserComparison]
}

public enum L09FixtureComparison {
    @discardableResult
    public static func run(fixtureURL: URL, appRoot: URL, databaseURL: URL, outputURL: URL) async throws -> URL {
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: fixtureURL))
        guard fixture.cases.count == 41, fixture.parsedReferences.count == 19,
              fixture.parserProbes.normalized.count == 4,
              fixture.parserProbes.utf16EditDistance.count == 3,
              fixture.parserProbes.ftsQueries.count == 6 else {
            throw NSError(domain: "L09FixtureComparison", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "fixture case counts do not match the L09 contract"])
        }
        let repository = SQLiteSearchRepository(databaseURL: databaseURL, resourceRoots: ResourceRoots(app: appRoot))

        var searches: [SearchComparison] = []
        var searchMismatches: [String] = []
        for item in fixture.cases {
            guard let translationID = TranslationID(rawValue: item.request.translationID),
                  let scope = BibleSearchScope(rawValue: item.request.scope) else {
                searchMismatches.append(item.requestID)
                continue
            }
            let request = BibleSearchRequest(requestID: item.request.id, query: item.request.query,
                                             translationID: translationID, scope: scope,
                                             limit: item.request.limit ?? 60)
            let response = try await repository.search(request)
            let actual = ExpectedResponse(results: response.results.map {
                ExpectedResult(id: $0.id, bookCode: $0.bookCode, bookName: $0.bookName,
                               group: $0.group, chapter: $0.chapter, verse: $0.verse,
                               verseOrder: $0.verseOrder, text: $0.text, reference: $0.reference)
            }, correctedQuery: response.correctedQuery, isReference: response.isReference)
            let matches = response.requestID == item.request.id && actual == item.expected
            searches.append(SearchComparison(requestID: item.requestID, matchesSource: matches, actual: actual))
            if !matches { searchMismatches.append(item.requestID) }
        }

        var parsers: [ParserComparison] = []
        var parserMismatches: [String] = []
        for item in fixture.parsedReferences {
            for edition in ["web-ce", "douay-rheims", "vulgate"] {
                let manifestURL = appRoot.appendingPathComponent("Bible/\(edition)/manifest.json")
                let books = try JSONDecoder().decode([SearchBookMetadata].self, from: Data(contentsOf: manifestURL))
                let parsed = BibleReferenceParser.parse(item.query, books: books)
                let actual: JSONValueOutput?
                let actualObject: Any
                if let parsed {
                    actual = JSONValueOutput(code: parsed.book.code, group: parsed.book.group,
                                             order: parsed.book.order, chapter: parsed.chapter,
                                             startVerse: parsed.startVerse, endVerse: parsed.endVerse)
                    actualObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(actual!))
                } else {
                    actual = nil
                    actualObject = NSNull()
                }
                let expected = item.byEdition[edition] ?? .null
                let expectedObject = foundationObject(expected)
                let matches = equalJSON(expectedObject, actualObject)
                let key = "\(item.query)|\(edition)"
                parsers.append(ParserComparison(query: item.query, edition: edition, matchesSource: matches, actual: actual))
                if !matches { parserMismatches.append(key) }
            }
        }

        let normalizationMismatches = fixture.parserProbes.normalized.compactMap { probe in
            BibleReferenceParser.normalize(probe.value) == probe.expected ? nil : probe.value
        }
        let editDistanceMismatches = fixture.parserProbes.utf16EditDistance.compactMap { probe in
            BibleReferenceParser.editDistance(probe.left, probe.right) == probe.expected
                ? nil : "\(probe.left)|\(probe.right)"
        }
        let ftsProbeMismatches = fixture.parserProbes.ftsQueries.compactMap { probe in
            SQLiteSearchRepository.buildFTSQuery(probe.query) == probe.expected ? nil : probe.query
        }

        let report = Report(formatVersion: 1, fixtureSourceHashes: fixture.sourceHashes,
                            searchCount: searches.count, searchMatches: searches.filter(\.matchesSource).count,
                            searchMismatches: searchMismatches, parserCount: parsers.count,
                            parserMatches: parsers.filter(\.matchesSource).count,
                            parserMismatches: parserMismatches,
                            normalizationCount: fixture.parserProbes.normalized.count,
                            normalizationMatches: fixture.parserProbes.normalized.count - normalizationMismatches.count,
                            normalizationMismatches: normalizationMismatches,
                            editDistanceCount: fixture.parserProbes.utf16EditDistance.count,
                            editDistanceMatches: fixture.parserProbes.utf16EditDistance.count - editDistanceMismatches.count,
                            editDistanceMismatches: editDistanceMismatches,
                            ftsProbeCount: fixture.parserProbes.ftsQueries.count,
                            ftsProbeMatches: fixture.parserProbes.ftsQueries.count - ftsProbeMismatches.count,
                            ftsProbeMismatches: ftsProbeMismatches, searches: searches, parsers: parsers)
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: outputURL, options: .atomic)
        return outputURL
    }

    private static func foundationObject(_ value: JSONValue) -> Any {
        switch value {
        case let .object(values): return values.mapValues(foundationObject)
        case let .array(values): return values.map(foundationObject)
        case let .string(text): return text
        case let .number(number): return number
        case let .bool(boolean): return boolean
        case .null: return NSNull()
        }
    }

    private static func equalJSON(_ left: Any, _ right: Any) -> Bool {
        guard JSONSerialization.isValidJSONObject(left), JSONSerialization.isValidJSONObject(right),
              let leftData = try? JSONSerialization.data(withJSONObject: left, options: [.sortedKeys]),
              let rightData = try? JSONSerialization.data(withJSONObject: right, options: [.sortedKeys]) else {
            return (left as? NSNull) != nil && (right as? NSNull) != nil
        }
        return leftData == rightData
    }
}

#endif
