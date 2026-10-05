import Foundation
import CSQLite

public struct LibrarySchemaSummary: Codable, Hashable, Sendable {
    public let schemaVersion: Int32
    public let bookmarkCount: Int64
    public let highlightCount: Int64
    public let noteCount: Int64
}

/// Read-only schema inspection and consistent backup support. This boundary does not migrate or write library rows.
public actor SQLiteLibraryBoundary {
    private let databaseURL: URL
    public init(databaseURL: URL) { self.databaseURL = databaseURL.standardizedFileURL }

    public func inspect() throws -> LibrarySchemaSummary {
        let db = try openExistingLibrary()
        let versionQuery = try db.prepare("PRAGMA user_version")
        guard try versionQuery.step() else { throw CoreError.unreadableLibrary("user_version could not be read") }
        let version = Int32(versionQuery.integer(0))
        guard version == 1 else { throw CoreError.unsupportedSchema(version) }
        try requireColumns(db, table: "bookmarks", expected: ["passage_key", "translation_id", "book_code", "book_name", "book_order", "chapter", "start_verse", "end_verse", "start_index", "end_index", "scripture_text", "created_at", "updated_at"])
        try requireColumns(db, table: "highlights", expected: ["verse_key", "batch_id", "translation_id", "book_code", "book_name", "book_order", "chapter", "verse", "verse_index", "verse_text", "color", "created_at", "updated_at"])
        try requireColumns(db, table: "notes", expected: ["passage_key", "translation_id", "book_code", "book_name", "book_order", "chapter", "start_verse", "end_verse", "start_index", "end_index", "scripture_text", "note_text", "created_at", "updated_at"])
        return try LibrarySchemaSummary(schemaVersion: version,
            bookmarkCount: rowCount(db, table: "bookmarks"),
            highlightCount: rowCount(db, table: "highlights"),
            noteCount: rowCount(db, table: "notes"))
    }

    /// Creates a consistent SQLite backup at a new path. It never replaces an existing destination.
    /// A failed attempt can leave a partial destination. A retry must use a new path.
    public func makeConsistentBackup(to destinationURL: URL) throws {
        _ = try inspect()
        let destination = destinationURL.standardizedFileURL
        guard destination != databaseURL else { throw CoreError.failedBackup("backup path equals library path") }
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw CoreError.failedBackup("backup destination already exists") }
        do { try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true) }
        catch { throw CoreError.failedBackup("cannot create backup directory: \(error)") }
        let source = try openExistingLibrary()
        let target: SQLiteConnection
        do { target = try SQLiteConnection(url: destination, readOnly: false, createIfMissing: true) }
        catch { throw CoreError.failedBackup("cannot create backup database: \(error)") }
        guard let backup = sqlite3_backup_init(target.handle, "main", source.handle, "main") else {
            throw CoreError.failedBackup(String(cString: sqlite3_errmsg(target.handle)))
        }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        var stepStatus: Int32 = SQLITE_OK
        repeat {
            stepStatus = sqlite3_backup_step(backup, -1)
            if stepStatus == SQLITE_BUSY || stepStatus == SQLITE_LOCKED {
                guard clock.now < deadline else {
                    sqlite3_backup_finish(backup)
                    throw CoreError.failedBackup("SQLite backup exceeded five seconds")
                }
                Thread.sleep(forTimeInterval: 0.02)
            }
        } while stepStatus == SQLITE_OK || stepStatus == SQLITE_BUSY || stepStatus == SQLITE_LOCKED
        let finishStatus = sqlite3_backup_finish(backup)
        guard stepStatus == SQLITE_DONE, finishStatus == SQLITE_OK else {
            throw CoreError.failedBackup("SQLite backup failed with status \(stepStatus)/\(finishStatus)")
        }
    }

    private func openExistingLibrary() throws -> SQLiteConnection {
        guard FileManager.default.fileExists(atPath: databaseURL.path),
              (try? databaseURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0 > 0 else {
            throw CoreError.unreadableLibrary("library database is missing or empty")
        }
        do { return try SQLiteConnection(url: databaseURL, readOnly: true) }
        catch { throw CoreError.unreadableLibrary("library database cannot be opened: \(error)") }
    }

    private func requireColumns(_ db: SQLiteConnection, table: String, expected: [String]) throws {
        let query = try db.prepare("PRAGMA table_info(\(table))")
        var columns: [String] = []
        while try query.step() { columns.append(try query.text(1)) }
        guard columns == expected else { throw CoreError.unreadableLibrary("library schema mismatch in \(table)") }
    }

    private func rowCount(_ db: SQLiteConnection, table: String) throws -> Int64 {
        let query = try db.prepare("SELECT count(*) FROM \(table)")
        guard try query.step() else { throw CoreError.unreadableLibrary("library count query failed") }
        return query.integer(0)
    }
}
