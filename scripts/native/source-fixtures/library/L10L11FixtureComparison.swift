#if DEBUG
import Foundation
import CoreFoundation
import JohnCore

private struct L10HighlightVerse: Encodable {
    let verseKey: String
    let batchId: String
    let verse: String
    let verseIndex: Int
    let verseText: String
    let createdAt: Int64
    let updatedAt: Int64

    init(_ value: SavedHighlightVerse) {
        verseKey = value.verseKey; batchId = value.batchID; verse = value.verse.rawValue
        verseIndex = value.verseIndex; verseText = value.verseText
        createdAt = value.createdAt; updatedAt = value.updatedAt
    }
}

private struct L10SavedItem: Encodable {
    let id: String
    let kind: String
    let translationId: String
    let bookCode: String
    let bookName: String
    let bookOrder: Int
    let chapter: Int
    let startVerse: String
    let endVerse: String
    let startIndex: Int
    let endIndex: Int
    let scriptureText: String
    let reference: String
    let createdAt: Int64
    let updatedAt: Int64
    let color: String?
    let noteText: String?
    let verseKeys: [String]?
    let highlightVerses: [L10HighlightVerse]?

    init(_ value: SavedItem) {
        id = value.id; kind = value.kind.rawValue; translationId = value.translationID
        bookCode = value.bookCode; bookName = value.bookName; bookOrder = value.bookOrder
        chapter = value.chapter; startVerse = value.startVerse; endVerse = value.endVerse
        startIndex = value.startIndex; endIndex = value.endIndex; scriptureText = value.scriptureText
        reference = value.reference; createdAt = value.createdAt; updatedAt = value.updatedAt
        color = value.color?.rawValue; noteText = value.noteText; verseKeys = value.verseKeys
        highlightVerses = value.highlightVerses?.map(L10HighlightVerse.init)
    }
}

private final class L10SequenceClock: CoreClock, @unchecked Sendable {
    private let lock = NSLock()
    private var call = 0

    func now() -> ClockReading {
        lock.lock()
        defer { lock.unlock() }
        let milliseconds = Int64(1_800_000_000_000) + Int64(call)
        call += 1
        return ClockReading(instant: Date(timeIntervalSince1970: Double(milliseconds) / 1_000),
                            timeZoneIdentifier: "UTC", utcOffsetSeconds: 0)
    }
}

private struct L10Report: Encodable {
    let formatVersion: Int
    let sourceHashes: [String: String]
    let comparisonCount: Int
    let matchCount: Int
    let mismatches: [String]
    let observations: [String: L10JSON]
}

private enum L10JSON: Encodable {
    case object([String: L10JSON])
    case array([L10JSON])
    case string(String)
    case integer(Int64)
    case boolean(Bool)
    case null

    init(_ value: Any) throws {
        switch value {
        case is NSNull: self = .null
        case let value as String: self = .string(value)
        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() { self = .boolean(value.boolValue) }
            else { self = .integer(value.int64Value) }
        case let value as [Any]: self = .array(try value.map(L10JSON.init))
        case let value as [String: Any]: self = .object(try value.mapValues(L10JSON.init))
        default: throw CoreError.invalidResource("L10 fixture JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .object(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .integer(value): try container.encode(value)
        case let .boolean(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

/// Run this only with a new, test-owned schema-1 database path.
public enum L10L11FixtureComparison {
    @discardableResult
    public static func run(fixtureURL: URL, databaseURL: URL, recoveryDirectory: URL,
                           outputURL: URL) async throws -> URL {
        let fileManager = FileManager.default
        let fixtureURL = fixtureURL.standardizedFileURL
        let databaseURL = databaseURL.standardizedFileURL
        let recoveryDirectory = recoveryDirectory.standardizedFileURL
        let outputURL = outputURL.standardizedFileURL
        let paths = [fixtureURL.path, databaseURL.path, recoveryDirectory.path, outputURL.path]
        for left in paths.indices {
            for right in paths.indices where right > left {
                guard !pathsOverlap(paths[left], paths[right]) else {
                    throw CoreError.invalidIdentity("L10 fixture paths overlap")
                }
            }
        }
        guard !fileManager.fileExists(atPath: databaseURL.path),
              !fileManager.fileExists(atPath: outputURL.path),
              !["-wal", "-shm", "-journal"].contains(where: {
                  fileManager.fileExists(atPath: databaseURL.path + $0)
              }) else {
            throw CoreError.invalidIdentity("L10 comparison requires new output and database paths")
        }
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL)) as? [String: Any]
        guard let root, let sourceHashes = root["sourceHashes"] as? [String: String],
              let snapshots = root["snapshots"] as? [String: Any] else {
            throw CoreError.invalidResource("L10 source fixture shape")
        }
        let requiredSnapshots = [
            "bookmarkAdd", "afterBookmarkAdd", "bookmarkRemove", "afterBookmarkRemove", "bookmarkRestore",
            "highlightRows", "highlightGroups", "noteAfterTrimmedSave", "noteAfterEmptySave", "noteAfterFinalSave",
            "saved-all", "saved-bookmark", "saved-highlight", "saved-note", "afterDelete", "afterUndo",
            "restoredHighlightRows", "noteAfterBOMOnlySave", "noteAfterNELOnlySave",
        ]
        guard requiredSnapshots.count == 19, requiredSnapshots.allSatisfy({ snapshots[$0] != nil }) else {
            throw CoreError.invalidResource("L10 source fixture snapshot set")
        }
        let initial = try await SQLiteLibraryBoundary(databaseURL: databaseURL).prepareForStartup()
        guard initial.schemaVersion == 1, initial.bookmarkCount == 0,
              initial.highlightCount == 0, initial.noteCount == 0 else {
            throw CoreError.invalidIdentity("L10 comparison needs an empty test database")
        }
        let repository = SQLiteLibraryRepository(databaseURL: databaseURL,
                                                 recoveryDirectory: recoveryDirectory,
                                                 clock: L10SequenceClock())
        var observations: [String: L10JSON] = [:]
        var mismatches: [String] = []

        func compare(_ key: String, _ actual: Any) throws {
            guard let expected = snapshots[key] else { throw CoreError.invalidResource("L10 fixture missing \(key)") }
            let actualJSON = try L10JSON(actual)
            observations[key] = actualJSON
            if try canonicalJSON(actual) != canonicalJSON(expected) { mismatches.append(key) }
        }
        func saved(_ filter: SavedFilter) async throws -> [SavedItem] {
            try await repository.listSavedItems(filter: filter)
        }
        func fixtureItems(_ items: [SavedItem]) throws -> [[String: Any]] {
            try items.map { try foundationObject(L10SavedItem($0)) as! [String: Any] }
        }
        func savedResult(_ items: [SavedItem]) throws -> [String: Any] {
            ["ids": items.map(\.id), "items": try fixtureItems(items)]
        }

        let bookmark = try selection(15, 17)
        let add = try await repository.toggleBookmark(bookmark)
        try compare("bookmarkAdd", add)
        try compare("afterBookmarkAdd", try fixtureItems(try await saved(.all)))
        let remove = try await repository.toggleBookmark(bookmark)
        try compare("bookmarkRemove", remove)
        try compare("afterBookmarkRemove", try fixtureItems(try await saved(.all)))
        let restoreBookmark = try await repository.toggleBookmark(bookmark)
        try compare("bookmarkRestore", restoreBookmark)

        let highlightActions: [(HighlightColor, PassageSelection)] = [
            (.gold, try selection(15, 17)), (.sage, try selection(18, 18)),
            (.rose, try selection(20, 21)), (.blue, try selection(22, 22)),
        ]
        for (color, passage) in highlightActions { try await repository.applyHighlight(passage, color: color) }
        let highlights = try await saved(.highlight)
        try compare("highlightRows", rawHighlightRows(highlights))
        try compare("highlightGroups", try fixtureItems(highlights.sorted { $0.startIndex < $1.startIndex }))

        let notePassage = try selection(15, 17)
        try await repository.saveNote(notePassage, text: "  Keep this private note. \n ")
        try compare("noteAfterTrimmedSave", rawNoteRows(try await saved(.note)))
        try await repository.saveNote(notePassage, text: " \n  ")
        try compare("noteAfterEmptySave", rawNoteRows(try await saved(.note)))
        try await repository.saveNote(notePassage, text: "Final note")
        try compare("noteAfterFinalSave", rawNoteRows(try await saved(.note)))

        for (name, filter) in [("all", SavedFilter.all), ("bookmark", .bookmark),
                               ("highlight", .highlight), ("note", .note)] {
            try compare("saved-\(name)", try savedResult(try await saved(filter)))
        }
        let beforeDelete = try await saved(.all)
        guard let deleteTarget = beforeDelete.first(where: { $0.kind == .highlight && $0.color == .gold }) else {
            throw CoreError.invalidResource("L10 gold highlight group is missing")
        }
        try await repository.delete(deleteTarget)
        try compare("afterDelete", try fixtureItems(try await saved(.all)))
        try await repository.restore(deleteTarget)
        try compare("afterUndo", try fixtureItems(try await saved(.all)))
        try compare("restoredHighlightRows", rawHighlightRows(try await saved(.highlight)))

        try await repository.saveNote(try selection(30, 30), text: "\u{FEFF}")
        let bomRow: Any = rawNoteRows(try await saved(.note)).first { $0["start_index"] as? Int == 30 } ?? NSNull()
        try compare("noteAfterBOMOnlySave", bomRow)
        try await repository.saveNote(try selection(31, 31), text: "\u{0085}")
        let nelRow: Any = rawNoteRows(try await saved(.note)).first { $0["start_index"] as? Int == 31 } ?? NSNull()
        try compare("noteAfterNELOnlySave", nelRow)

        let report = L10Report(formatVersion: 1, sourceHashes: sourceHashes,
                               comparisonCount: observations.count,
                               matchCount: observations.count - mismatches.count,
                               mismatches: mismatches, observations: observations)
        guard observations.count == 19 else { throw CoreError.invalidResource("L10 comparison observation count") }
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: outputURL, options: .atomic)
        return outputURL
    }

    private static func selection(_ start: Int, _ end: Int) throws -> PassageSelection {
        guard start >= 0, end >= start, let translation = TranslationID(rawValue: "web-ce"),
              let book = BookCode(rawValue: "JHN") else { throw CoreError.invalidIdentity("L10 selection") }
        let labels = try (start...end).map { index -> PassageVerse in
            guard let label = VerseLabel(rawValue: String(index + 1)) else { throw CoreError.invalidIdentity("L10 verse") }
            return PassageVerse(verse: label, index: index, text: "Source verse \(index + 1)")
        }
        guard let first = labels.first?.verse, let last = labels.last?.verse else {
            throw CoreError.invalidIdentity("L10 verse range")
        }
        let id = try PassageID(translationID: translation, bookCode: book, chapter: 3,
                               startVerse: first, endVerse: last)
        let text = labels.map { "\($0.verse.rawValue) \($0.text)" }.joined(separator: " ")
        return try PassageSelection(id: id, bookName: "John", bookOrder: 65,
                                    startIndex: start, endIndex: end,
                                    scriptureText: text, verses: labels)
    }

    private static func rawNoteRows(_ items: [SavedItem]) -> [[String: Any]] {
        items.filter { $0.kind == .note }.map { item in
            ["passage_key": String(item.id.dropFirst("note:".count)),
             "translation_id": item.translationID, "book_code": item.bookCode,
             "book_name": item.bookName, "book_order": item.bookOrder, "chapter": item.chapter,
             "start_verse": item.startVerse, "end_verse": item.endVerse,
             "start_index": item.startIndex, "end_index": item.endIndex,
             "scripture_text": item.scriptureText, "created_at": item.createdAt,
             "updated_at": item.updatedAt, "note_text": item.noteText ?? ""]
        }
    }

    private static func rawHighlightRows(_ items: [SavedItem]) -> [[String: Any]] {
        items.flatMap { item in
            (item.highlightVerses ?? []).map { verse in
                ["verse_key": verse.verseKey, "batch_id": verse.batchID,
                 "translation_id": item.translationID, "book_code": item.bookCode,
                 "book_name": item.bookName, "book_order": item.bookOrder,
                 "chapter": item.chapter, "verse": verse.verse.rawValue,
                 "verse_index": verse.verseIndex, "verse_text": verse.verseText,
                 "color": item.color?.rawValue ?? "", "created_at": verse.createdAt,
                 "updated_at": verse.updatedAt]
            }
        }.sorted { ($0["verse_index"] as? Int ?? 0) < ($1["verse_index"] as? Int ?? 0) }
    }

    private static func canonicalJSON(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed])
    }

    private static func pathsOverlap(_ left: String, _ right: String) -> Bool {
        left == right || left.hasPrefix(right + "/") || right.hasPrefix(left + "/")
    }

    private static func foundationObject<T: Encodable>(_ value: T) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
}

#endif
