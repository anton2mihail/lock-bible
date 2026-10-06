import Foundation
import CSQLite

public enum SavedFilter: String, Codable, Sendable { case all, bookmark, highlight, note }

public struct ChapterHighlight: Codable, Hashable, Sendable {
    public let verse: String
    public let color: HighlightColor
    public init(verse: String, color: HighlightColor) { self.verse = verse; self.color = color }
}

/// Schema-1 library access. This actor keeps the original database path and rows.
public actor SQLiteLibraryRepository {
    private let databaseURL: URL
    private let recoveryDirectory: URL
    private let clock: any CoreClock
    private let boundary: SQLiteLibraryBoundary
    private var readHandle: SQLiteLibraryReadHandle?
    private var writeDatabase: SQLiteConnection?
    private var backupVerified = false

    public init(databaseURL: URL, recoveryDirectory: URL, clock: any CoreClock = SystemCoreClock()) {
        self.databaseURL = databaseURL.standardizedFileURL
        self.recoveryDirectory = recoveryDirectory.standardizedFileURL
        self.clock = clock
        self.boundary = SQLiteLibraryBoundary(databaseURL: databaseURL)
    }

    public func listSavedItems(filter: SavedFilter = .all) async throws -> [SavedItem] {
        let db = try await connection()
        var ordered: [SavedItem] = []
        if filter == .all || filter == .bookmark {
            let query = try db.prepare("SELECT passage_key, translation_id, book_code, book_name, book_order, chapter, start_verse, end_verse, start_index, end_index, scripture_text, created_at, updated_at FROM bookmarks ORDER BY updated_at DESC")
            while try query.step() { ordered.append(try passageItem(query, kind: .bookmark, note: nil)) }
        }
        if filter == .all || filter == .note {
            let query = try db.prepare("SELECT passage_key, translation_id, book_code, book_name, book_order, chapter, start_verse, end_verse, start_index, end_index, scripture_text, created_at, updated_at, note_text FROM notes ORDER BY updated_at DESC")
            while try query.step() { ordered.append(try passageItem(query, kind: .note, note: query.text(13))) }
        }
        if filter == .all || filter == .highlight {
            let query = try db.prepare("SELECT verse_key, batch_id, translation_id, book_code, book_name, book_order, chapter, verse, verse_index, verse_text, color, created_at, updated_at FROM highlights ORDER BY updated_at DESC, verse_index")
            var rows: [HighlightRow] = []
            while try query.step() { rows.append(try highlightRow(query)) }
            ordered.append(contentsOf: try groupHighlightRows(rows))
        }
        let result = ordered.enumerated().sorted {
            if $0.element.updatedAt != $1.element.updatedAt { return $0.element.updatedAt > $1.element.updatedAt }
            return $0.offset < $1.offset
        }.map(\.element)
        try validateReadSource()
        return result
    }

    public func isBookmarked(_ id: PassageID) async throws -> Bool {
        let query = try await connection().prepare("SELECT 1 FROM bookmarks WHERE passage_key = ?")
        try query.bind(id.legacyKey, at: 1)
        let result = try query.step()
        try validateReadSource()
        return result
    }

    @discardableResult
    public func toggleBookmark(_ selection: PassageSelection) async throws -> Bool {
        let db = try await writableConnection()
        let query = try db.prepare("SELECT 1 FROM bookmarks WHERE passage_key = ?")
        try query.bind(selection.id.legacyKey, at: 1)
        if try query.step() {
            try transaction(db) {
                let delete = try db.prepare("DELETE FROM bookmarks WHERE passage_key = ?")
                try delete.bind(selection.id.legacyKey, at: 1)
                _ = try delete.step()
            }
            return false
        }
        let now = try timestampMilliseconds(clock.now().instant)
        try transaction(db) {
            let insert = try db.prepare("""
            INSERT INTO bookmarks (passage_key, translation_id, book_code, book_name, book_order, chapter,
              start_verse, end_verse, start_index, end_index, scripture_text, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """)
            try bind(selection, to: insert, startingAt: 1)
            try insert.bind(now, at: 12); try insert.bind(now, at: 13); _ = try insert.step()
        }
        return true
    }

    public func applyHighlight(_ selection: PassageSelection, color: HighlightColor) async throws {
        let db = try await writableConnection()
        let now = try timestampMilliseconds(clock.now().instant)
        let batchID = "\(selection.id.legacyKey):\(now)"
        try transaction(db) {
            let insert = try db.prepare("""
            INSERT OR REPLACE INTO highlights (verse_key, batch_id, translation_id, book_code, book_name,
              book_order, chapter, verse, verse_index, verse_text, color, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """)
            for verse in selection.verses {
                let key = Self.verseKey(selection.id, verse: verse.verse.rawValue)
                try insert.bind(key, at: 1); try insert.bind(batchID, at: 2)
                try insert.bind(selection.id.translationID.rawValue, at: 3)
                try insert.bind(selection.id.bookCode.rawValue, at: 4)
                try insert.bind(selection.bookName, at: 5)
                try bindInt(selection.bookOrder, at: 6, to: insert)
                try bindInt(selection.id.chapter, at: 7, to: insert)
                try insert.bind(verse.verse.rawValue, at: 8)
                try bindInt(verse.index, at: 9, to: insert)
                try insert.bind(verse.text, at: 10); try insert.bind(color.rawValue, at: 11)
                try insert.bind(now, at: 12); try insert.bind(now, at: 13); _ = try insert.step()
                try insert.reset()
            }
        }
    }

    public func clearHighlight(_ selection: PassageSelection) async throws {
        let db = try await writableConnection()
        try transaction(db) {
            let delete = try db.prepare("DELETE FROM highlights WHERE verse_key = ?")
            for verse in selection.verses {
                try delete.bind(Self.verseKey(selection.id, verse: verse.verse.rawValue), at: 1)
                _ = try delete.step(); try delete.reset()
            }
        }
    }

    public func chapterHighlights(translationID: String, bookCode: String, chapter: Int) async throws -> [ChapterHighlight] {
        let query = try await connection().prepare("SELECT verse, color FROM highlights WHERE translation_id = ? AND book_code = ? AND chapter = ?")
        try query.bind(translationID, at: 1); try query.bind(bookCode, at: 2); try bindInt(chapter, at: 3, to: query)
        var result: [ChapterHighlight] = []
        while try query.step() {
            guard let color = HighlightColor(rawValue: try query.text(1)) else { throw CoreError.invalidResource("unknown saved highlight color") }
            result.append(ChapterHighlight(verse: try query.text(0), color: color))
        }
        try validateReadSource()
        return result
    }

    public func note(for id: PassageID) async throws -> String {
        let query = try await connection().prepare("SELECT note_text FROM notes WHERE passage_key = ?")
        try query.bind(id.legacyKey, at: 1)
        let result = try query.step() ? query.text(0) : ""
        try validateReadSource()
        return result
    }

    public func saveNote(_ selection: PassageSelection, text: String) async throws {
        let db = try await writableConnection()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try transaction(db) {
                let delete = try db.prepare("DELETE FROM notes WHERE passage_key = ?")
                try delete.bind(selection.id.legacyKey, at: 1); _ = try delete.step()
            }
            return
        }
        let now = try timestampMilliseconds(clock.now().instant)
        try transaction(db) {
            let upsert = try db.prepare("""
            INSERT INTO notes (passage_key, translation_id, book_code, book_name, book_order, chapter,
              start_verse, end_verse, start_index, end_index, scripture_text, note_text, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(passage_key) DO UPDATE SET note_text = excluded.note_text,
              scripture_text = excluded.scripture_text, updated_at = excluded.updated_at
            """)
            try bind(selection, to: upsert, startingAt: 1)
            try upsert.bind(trimmed, at: 12); try upsert.bind(now, at: 13); try upsert.bind(now, at: 14)
            _ = try upsert.step()
        }
    }

    public func delete(_ item: SavedItem) async throws {
        let db = try await writableConnection()
        try transaction(db) {
            switch item.kind {
            case .bookmark, .note:
                let prefix = item.kind == .bookmark ? "bookmark:" : "note:"
                let key = item.id.hasPrefix(prefix) ? String(item.id.dropFirst(prefix.count)) : item.id
                let table = item.kind == .bookmark ? "bookmarks" : "notes"
                let statement = try db.prepare("DELETE FROM \(table) WHERE passage_key = ?")
                try statement.bind(key, at: 1); _ = try statement.step()
            case .highlight:
                let statement = try db.prepare("DELETE FROM highlights WHERE verse_key = ?")
                for key in item.verseKeys ?? [] { try statement.bind(key, at: 1); _ = try statement.step(); try statement.reset() }
            }
        }
    }

    /// Restore the source undo payload with its original IDs, batches, and millisecond times.
    public func restore(_ item: SavedItem) async throws {
        let db = try await writableConnection()
        try transaction(db) {
            switch item.kind {
            case .bookmark, .note:
                let key = passageKey(item)
                if item.kind == .bookmark {
                    let insert = try db.prepare("INSERT OR REPLACE INTO bookmarks VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
                    try bind(item, passageKey: key, to: insert, note: nil); _ = try insert.step()
                } else {
                    let insert = try db.prepare("INSERT OR REPLACE INTO notes VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
                    try bind(item, passageKey: key, to: insert, note: item.noteText ?? ""); _ = try insert.step()
                }
            case .highlight:
                guard !((item.highlightVerses ?? []).isEmpty) else { return }
                let insert = try db.prepare("INSERT OR REPLACE INTO highlights VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
                for verse in item.highlightVerses ?? [] {
                    try insert.bind(verse.verseKey, at: 1); try insert.bind(verse.batchID, at: 2)
                    try insert.bind(item.translationID, at: 3); try insert.bind(item.bookCode, at: 4)
                    try insert.bind(item.bookName, at: 5); try bindInt(item.bookOrder, at: 6, to: insert)
                    try bindInt(item.chapter, at: 7, to: insert); try insert.bind(verse.verse.rawValue, at: 8)
                    try bindInt(verse.verseIndex, at: 9, to: insert); try insert.bind(verse.verseText, at: 10)
                    try insert.bind((item.color ?? .gold).rawValue, at: 11)
                    try insert.bind(verse.createdAt, at: 12); try insert.bind(verse.updatedAt, at: 13)
                    _ = try insert.step(); try insert.reset()
                }
            }
        }
    }

    private func connection() async throws -> SQLiteConnection {
        if let writeDatabase { return writeDatabase }
        if let readHandle {
            try readHandle.validateSourceUnchanged()
            return readHandle.connection
        }
        let handle = try await boundary.openReadOnlyConnection()
        if let writeDatabase {
            try handle.close()
            return writeDatabase
        }
        if let readHandle {
            try handle.close()
            try readHandle.validateSourceUnchanged()
            return readHandle.connection
        }
        readHandle = handle
        return handle.connection
    }

    private func validateReadSource() throws {
        try readHandle?.validateSourceUnchanged()
    }

    private func writableConnection() async throws -> SQLiteConnection {
        if let writeDatabase { return writeDatabase }
        _ = try await boundary.inspect()
        if let writeDatabase { return writeDatabase }
        if !backupVerified {
            let sourceSummary = try await boundary.inspect()
            do { try FileManager.default.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true) }
            catch { throw CoreError.failedBackup("recovery directory cannot be created") }
            let backupURL = recoveryDirectory.appendingPathComponent("library-\(UUID().uuidString).sqlite")
            try await boundary.makeConsistentBackup(to: backupURL)
            let backupSummary = try await SQLiteLibraryBoundary(databaseURL: backupURL).inspect()
            guard sourceSummary == backupSummary else { throw CoreError.failedBackup("recovery backup does not match the source schema and row counts") }
            backupVerified = true
        }
        if let writeDatabase { return writeDatabase }
        try invalidateReadHandle()
        do { writeDatabase = try SQLiteConnection(url: databaseURL, readOnly: false) }
        catch { throw CoreError.unreadableLibrary("library cannot be opened for writing") }
        guard let writeDatabase else { throw CoreError.unreadableLibrary("library write connection is unavailable") }
        return writeDatabase
    }

    private func invalidateReadHandle() throws {
        guard let readHandle else { return }
        self.readHandle = nil
        try readHandle.close()
    }

    private func transaction(_ db: SQLiteConnection, body: () throws -> Void) throws {
        try db.execute("BEGIN IMMEDIATE")
        do { try body(); try db.execute("COMMIT") }
        catch { try? db.execute("ROLLBACK"); throw error }
    }

    private func passageItem(_ row: SQLiteStatement, kind: SavedItemKind, note: String?) throws -> SavedItem {
        let key = try row.text(0), translation = try row.text(1), book = try row.text(2), name = try row.text(3)
        let order = try int(row.integer(4)), chapter = try int(row.integer(5))
        let start = try row.text(6), end = try row.text(7), startIndex = try int(row.integer(8)), endIndex = try int(row.integer(9))
        let text = try row.text(10), created = row.integer(11), updated = row.integer(12)
        let reference = Self.reference(name, chapter: chapter, start: start, end: end)
        return SavedItem(id: "\(kind.rawValue):\(key)", kind: kind, translationID: translation, bookCode: book,
            bookName: name, bookOrder: order, chapter: chapter, startVerse: start, endVerse: end,
            startIndex: startIndex, endIndex: endIndex, scriptureText: text, reference: reference,
            createdAt: created, updatedAt: updated, noteText: note)
    }

    private func highlightRow(_ row: SQLiteStatement) throws -> HighlightRow {
        guard let color = HighlightColor(rawValue: try row.text(10)) else { throw CoreError.invalidResource("unknown saved highlight color") }
        return HighlightRow(verseKey: try row.text(0), batchID: try row.text(1), translationID: try row.text(2),
            bookCode: try row.text(3), bookName: try row.text(4), bookOrder: try int(row.integer(5)),
            chapter: try int(row.integer(6)), verse: try row.text(7), verseIndex: try int(row.integer(8)),
            verseText: try row.text(9), color: color, createdAt: row.integer(11), updatedAt: row.integer(12))
    }

    private func bind(_ selection: PassageSelection, to statement: SQLiteStatement, startingAt index: Int32) throws {
        try statement.bind(selection.id.legacyKey, at: index)
        try statement.bind(selection.id.translationID.rawValue, at: index + 1)
        try statement.bind(selection.id.bookCode.rawValue, at: index + 2)
        try statement.bind(selection.bookName, at: index + 3); try bindInt(selection.bookOrder, at: index + 4, to: statement)
        try bindInt(selection.id.chapter, at: index + 5, to: statement)
        try statement.bind(selection.id.startVerse.rawValue, at: index + 6); try statement.bind(selection.id.endVerse.rawValue, at: index + 7)
        try bindInt(selection.startIndex, at: index + 8, to: statement); try bindInt(selection.endIndex, at: index + 9, to: statement)
        try statement.bind(selection.scriptureText, at: index + 10)
    }

    private func bind(_ item: SavedItem, passageKey: String, to statement: SQLiteStatement, note: String?) throws {
        try statement.bind(passageKey, at: 1); try statement.bind(item.translationID, at: 2); try statement.bind(item.bookCode, at: 3)
        try statement.bind(item.bookName, at: 4); try bindInt(item.bookOrder, at: 5, to: statement); try bindInt(item.chapter, at: 6, to: statement)
        try statement.bind(item.startVerse, at: 7); try statement.bind(item.endVerse, at: 8)
        try bindInt(item.startIndex, at: 9, to: statement); try bindInt(item.endIndex, at: 10, to: statement)
        try statement.bind(item.scriptureText, at: 11)
        if let note { try statement.bind(note, at: 12); try statement.bind(item.createdAt, at: 13); try statement.bind(item.updatedAt, at: 14) }
        else { try statement.bind(item.createdAt, at: 12); try statement.bind(item.updatedAt, at: 13) }
    }

    private func bindInt(_ value: Int, at index: Int32, to statement: SQLiteStatement) throws {
        guard let exact = Int64(exactly: value) else { throw CoreError.invalidIdentity("SQLite integer range") }
        try statement.bind(exact, at: index)
    }

    private func int(_ value: Int64) throws -> Int {
        guard let exact = Int(exactly: value) else { throw CoreError.invalidResource("saved library integer range") }
        return exact
    }

    private func timestampMilliseconds(_ date: Date) throws -> Int64 {
        let value = date.timeIntervalSince1970 * 1_000
        guard value.isFinite, let exact = Int64(exactly: value.rounded(.towardZero)) else {
            throw CoreError.invalidIdentity("timestamp is outside the SQLite integer range")
        }
        return exact
    }

    private static func verseKey(_ id: PassageID, verse: String) -> String {
        "\(id.translationID.rawValue):\(id.bookCode.rawValue):\(id.chapter):\(verse)"
    }

    private static func reference(_ name: String, chapter: Int, start: String, end: String) -> String {
        "\(name) \(chapter):\(start == end ? start : "\(start)–\(end)")"
    }

    private func passageKey(_ item: SavedItem) -> String {
        "\(item.translationID):\(item.bookCode):\(item.chapter):\(item.startVerse):\(item.endVerse)"
    }
}

public struct HighlightRow: Sendable {
    public let verseKey: String; public let batchID: String; public let translationID: String
    public let bookCode: String; public let bookName: String; public let bookOrder: Int
    public let chapter: Int; public let verse: String; public let verseIndex: Int
    public let verseText: String; public let color: HighlightColor; public let createdAt: Int64; public let updatedAt: Int64
    public init(verseKey: String, batchID: String, translationID: String, bookCode: String, bookName: String,
                bookOrder: Int, chapter: Int, verse: String, verseIndex: Int, verseText: String,
                color: HighlightColor, createdAt: Int64, updatedAt: Int64) {
        self.verseKey = verseKey; self.batchID = batchID; self.translationID = translationID; self.bookCode = bookCode
        self.bookName = bookName; self.bookOrder = bookOrder; self.chapter = chapter; self.verse = verse
        self.verseIndex = verseIndex; self.verseText = verseText; self.color = color
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

private func groupHighlightRows(_ rows: [HighlightRow]) throws -> [SavedItem] {
    var groups: [(key: String, rows: [HighlightRow])] = []
    var indexByKey: [String: Int] = [:]
    for row in rows {
        let key = "\(row.batchID):\(row.bookCode):\(row.chapter):\(row.color.rawValue)"
        if let index = indexByKey[key] { groups[index].rows.append(row) }
        else { indexByKey[key] = groups.count; groups.append((key, [row])) }
    }
    var items: [SavedItem] = []
    for group in groups {
        let sorted = group.rows.sorted { $0.verseIndex < $1.verseIndex }
        var contiguous: [HighlightRow] = []
        func flush() throws {
            guard let first = contiguous.first, let last = contiguous.last else { return }
            let selected = contiguous
            items.append(SavedItem(id: "highlight:\(group.key):\(first.verseIndex):\(last.verseIndex)", kind: .highlight,
                translationID: first.translationID, bookCode: first.bookCode, bookName: first.bookName,
                bookOrder: first.bookOrder, chapter: first.chapter, startVerse: first.verse, endVerse: last.verse,
                startIndex: first.verseIndex, endIndex: last.verseIndex,
                scriptureText: selected.map { "\($0.verse) \($0.verseText)" }.joined(separator: " "),
                reference: "\(first.bookName) \(first.chapter):\(first.verse == last.verse ? first.verse : "\(first.verse)–\(last.verse)")",
                createdAt: selected.map(\.createdAt).min() ?? first.createdAt,
                updatedAt: selected.map(\.updatedAt).max() ?? last.updatedAt, color: first.color,
                verseKeys: selected.map(\.verseKey),
                highlightVerses: try selected.map { row in
                    try SavedHighlightVerse(verseKey: row.verseKey, batchID: row.batchID,
                        verse: try VerseLabel(row.verse), verseIndex: row.verseIndex,
                        verseText: row.verseText, createdAt: row.createdAt, updatedAt: row.updatedAt)
                }))
            contiguous = []
        }
        for row in sorted {
            if let previous = contiguous.last, row.verseIndex != previous.verseIndex + 1 { try flush() }
            contiguous.append(row)
        }
        try flush()
    }
    return items
}
