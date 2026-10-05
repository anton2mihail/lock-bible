import Foundation
import CSQLite
import Darwin

public struct LibrarySchemaSummary: Codable, Hashable, Sendable {
    public let schemaVersion: Int32
    public let bookmarkCount: Int64
    public let highlightCount: Int64
    public let noteCount: Int64
}

/// Read-only schema inspection and consistent backup support. This boundary does not migrate or write library rows.
public actor SQLiteLibraryBoundary {
    private let databaseURL: URL
    #if DEBUG
    private let checkpoint: (@Sendable (NativeImportCheckpoint) -> Void)?
    public init(databaseURL: URL, checkpoint: (@Sendable (NativeImportCheckpoint) -> Void)? = nil) {
        self.databaseURL = databaseURL.standardizedFileURL
        self.checkpoint = checkpoint
    }
    #else
    public init(databaseURL: URL) { self.databaseURL = databaseURL.standardizedFileURL }
    #endif

    /// Create schema 1 only when no database path or recovery sidecar exists.
    public func prepareForStartup(allowCreate: Bool = true) async throws -> LibrarySchemaSummary {
        if !FileManager.default.fileExists(atPath: databaseURL.path) {
            guard allowCreate else { throw CoreError.unreadableLibrary("library database is missing") }
            return try createSchemaAtomically()
        }
        return try inspect()
    }

    private func createSchemaAtomically() throws -> LibrarySchemaSummary {
        let directory = databaseURL.deletingLastPathComponent()
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { throw CoreError.unreadableLibrary("library directory cannot be created") }
        for suffix in ["-wal", "-shm", "-journal"] {
            guard !FileManager.default.fileExists(atPath: databaseURL.path + suffix) else {
                throw CoreError.unreadableLibrary("library database is missing but recovery sidecars exist")
            }
        }

        let temporaryURL = directory.appendingPathComponent(".\(databaseURL.lastPathComponent).bootstrap-\(UUID().uuidString).tmp")
        defer {
            for suffix in ["", "-wal", "-shm", "-journal"] {
                try? FileManager.default.removeItem(atPath: temporaryURL.path + suffix)
            }
        }
        var validatedSummary: LibrarySchemaSummary?
        do {
            let database = try SQLiteConnection(url: temporaryURL, readOnly: false, createIfMissing: true)
            try database.execute("PRAGMA journal_mode=DELETE; PRAGMA foreign_keys=ON; BEGIN IMMEDIATE;")
            do {
                try database.execute(Self.schema1SQL)
                try database.execute("COMMIT")
            } catch {
                try? database.execute("ROLLBACK")
                throw CoreError.unreadableLibrary("schema 1 could not be created in one transaction")
            }
            #if DEBUG
            checkpoint?(.afterFreshLibraryTransaction)
            #endif
            let summary = try inspect(database)
            validatedSummary = summary
            let integrity = try database.prepare("PRAGMA integrity_check")
            guard try integrity.step(), try integrity.text(0) == "ok", try !integrity.step() else {
                throw CoreError.unreadableLibrary("temporary library integrity check failed")
            }
            let walMode = try database.prepare("PRAGMA journal_mode=WAL")
            guard try walMode.step(), try walMode.text(0).lowercased() == "wal" else {
                throw CoreError.unreadableLibrary("temporary library cannot use WAL mode")
            }
            let checkpoint = try database.prepare("PRAGMA wal_checkpoint(TRUNCATE)")
            guard try checkpoint.step(), checkpoint.integer(0) == 0,
                  checkpoint.integer(1) == checkpoint.integer(2) else {
                throw CoreError.unreadableLibrary("temporary library WAL checkpoint failed")
            }
        } catch {
            if let coreError = error as? CoreError { throw coreError }
            throw CoreError.unreadableLibrary("temporary library schema could not be prepared")
        }

        for suffix in ["-wal", "-shm", "-journal"] {
            guard !FileManager.default.fileExists(atPath: temporaryURL.path + suffix) else {
                throw CoreError.unreadableLibrary("temporary library has uncheckpointed sidecars")
            }
        }
        #if DEBUG
        checkpoint?(.beforeFreshLibraryPublish)
        #endif

        let publishStatus = temporaryURL.path.withCString { source in
            databaseURL.path.withCString { destination in renamex_np(source, destination, UInt32(RENAME_EXCL)) }
        }
        guard publishStatus == 0 else {
            throw CoreError.unreadableLibrary("complete schema 1 database could not be published without replacement")
        }
        #if DEBUG
        checkpoint?(.afterFreshLibraryPublish)
        #endif
        let directoryFD = open(directory.path, O_RDONLY)
        guard directoryFD >= 0 else { throw CoreError.unreadableLibrary("library directory cannot be opened for sync") }
        defer { _ = close(directoryFD) }
        guard fsync(directoryFD) == 0 else { throw CoreError.unreadableLibrary("library directory sync failed") }
        guard let validatedSummary else { throw CoreError.unreadableLibrary("temporary library validation did not finish") }
        return validatedSummary
    }

    public func inspect() throws -> LibrarySchemaSummary {
        let db = try openExistingLibrary()
        return try inspect(db)
    }

    private func inspect(_ db: SQLiteConnection) throws -> LibrarySchemaSummary {
        let versionQuery = try db.prepare("PRAGMA user_version")
        guard try versionQuery.step() else { throw CoreError.unreadableLibrary("user_version could not be read") }
        let rawVersion = versionQuery.integer(0)
        guard let version = Int32(exactly: rawVersion) else {
            throw CoreError.invalidResource("library schema version is outside the supported integer range")
        }
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

    private static let schema1SQL = """
    CREATE TABLE bookmarks (passage_key TEXT PRIMARY KEY NOT NULL, translation_id TEXT NOT NULL, book_code TEXT NOT NULL, book_name TEXT NOT NULL, book_order INTEGER NOT NULL, chapter INTEGER NOT NULL, start_verse TEXT NOT NULL, end_verse TEXT NOT NULL, start_index INTEGER NOT NULL, end_index INTEGER NOT NULL, scripture_text TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
    CREATE INDEX bookmarks_updated_idx ON bookmarks(updated_at DESC);
    CREATE TABLE highlights (verse_key TEXT PRIMARY KEY NOT NULL, batch_id TEXT NOT NULL, translation_id TEXT NOT NULL, book_code TEXT NOT NULL, book_name TEXT NOT NULL, book_order INTEGER NOT NULL, chapter INTEGER NOT NULL, verse TEXT NOT NULL, verse_index INTEGER NOT NULL, verse_text TEXT NOT NULL, color TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
    CREATE INDEX highlights_reference_idx ON highlights(translation_id, book_code, chapter, verse_index);
    CREATE INDEX highlights_updated_idx ON highlights(updated_at DESC);
    CREATE TABLE notes (passage_key TEXT PRIMARY KEY NOT NULL, translation_id TEXT NOT NULL, book_code TEXT NOT NULL, book_name TEXT NOT NULL, book_order INTEGER NOT NULL, chapter INTEGER NOT NULL, start_verse TEXT NOT NULL, end_verse TEXT NOT NULL, start_index INTEGER NOT NULL, end_index INTEGER NOT NULL, scripture_text TEXT NOT NULL, note_text TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
    CREATE INDEX notes_updated_idx ON notes(updated_at DESC);
    PRAGMA user_version=1;
    """
}
