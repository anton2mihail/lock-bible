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
            defer { _ = database.close() }
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
            let summary: LibrarySchemaSummary
            do { summary = try inspect(database) }
            catch { throw CoreError.unreadableLibrary("fresh schema inspection failed: \(error)") }
            validatedSummary = summary
            try Self.requireJournalMode(database, expected: "delete", context: "fresh schema")
            try Self.requireIntegrity(database, context: "fresh schema")
            let closeStatus = database.close()
            guard closeStatus == SQLITE_OK else {
                throw CoreError.unreadableLibrary("temporary library close failed status=\(closeStatus)")
            }
        } catch {
            if let coreError = error as? CoreError { throw coreError }
            throw CoreError.unreadableLibrary("temporary library schema could not be prepared")
        }

        try Self.requireNoSidecars(for: temporaryURL, context: "temporary library")
        try Self.syncFile(temporaryURL, error: "temporary library file sync failed")
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
        try Self.syncDirectory(directory, error: "library directory sync failed")
        guard let validatedSummary else { throw CoreError.unreadableLibrary("temporary library validation did not finish") }
        return validatedSummary
    }

    public func inspect() throws -> LibrarySchemaSummary {
        let db = try openExistingLibrary()
        return try inspect(db)
    }

    private func inspect(_ db: SQLiteConnection) throws -> LibrarySchemaSummary {
        let versionQuery = try db.prepare("PRAGMA user_version")
        defer { versionQuery.finalize() }
        guard try versionQuery.step() else { throw CoreError.unreadableLibrary("user_version could not be read") }
        let rawVersion = versionQuery.integer(0)
        guard try !versionQuery.step() else { throw CoreError.unreadableLibrary("user_version returned extra rows") }
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
#if DEBUG
        NSLog("[JohnCoreSQLite] stage=backup-source-inspect-begin")
#endif
        let sourceSummary: LibrarySchemaSummary
        do { sourceSummary = try inspect() }
        catch { throw CoreError.failedBackup("backup source inspection failed: \(error)") }
#if DEBUG
        NSLog("[JohnCoreSQLite] stage=backup-source-inspect-complete")
#endif
        let destination = destinationURL.standardizedFileURL
        guard destination != databaseURL else { throw CoreError.failedBackup("backup path equals library path") }
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw CoreError.failedBackup("backup destination already exists") }
        do { try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true) }
        catch { throw CoreError.failedBackup("cannot create backup directory: \(error)") }
        #if DEBUG
        NSLog("[JohnCoreSQLite] stage=backup-source-open-begin")
        #endif
        let source: SQLiteConnection
        do { source = try openExistingLibrary() }
        catch { throw CoreError.failedBackup("backup source open failed: \(error)") }
        defer { _ = source.close() }
        #if DEBUG
        NSLog("[JohnCoreSQLite] stage=backup-source-open-complete")
        NSLog("[JohnCoreSQLite] stage=backup-target-open-begin")
        #endif
        do { try Self.requireNoSidecars(for: destination, context: "backup destination") }
        catch { throw CoreError.failedBackup("backup destination sidecars already exist: \(error)") }
        do { try Self.createExclusiveFile(destination) }
        catch { throw CoreError.failedBackup("cannot create unique backup file: \(error)") }
        let target: SQLiteConnection
        do { target = try SQLiteConnection(url: destination, readOnly: false) }
        catch { throw CoreError.failedBackup("cannot create backup database: \(error)") }
        defer { _ = target.close() }
        #if DEBUG
        NSLog("[JohnCoreSQLite] stage=backup-target-open-complete")
        NSLog("[JohnCoreSQLite] stage=backup-init-begin")
        #endif
        guard let backup = sqlite3_backup_init(target.handle, "main", source.handle, "main") else {
            throw CoreError.failedBackup("backup initialization failed: \(String(cString: sqlite3_errmsg(target.handle)))")
        }
        #if DEBUG
        NSLog("[JohnCoreSQLite] stage=backup-init-complete")
        NSLog("[JohnCoreSQLite] stage=backup-copy-begin")
        #endif
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
#if DEBUG
        NSLog("[JohnCoreSQLite] stage=backup-copy-finish step=%d finish=%d", stepStatus, finishStatus)
#endif
        guard stepStatus == SQLITE_DONE, finishStatus == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(target.handle))
            throw CoreError.failedBackup("SQLite backup failed with status \(stepStatus)/\(finishStatus): \(errorMessage)")
        }
        do { try Self.requireJournalMode(target, expected: "delete", context: "backup") }
        catch { throw CoreError.failedBackup("backup journal mode could not be normalized: \(error)") }
        let backupSummary: LibrarySchemaSummary
        do { backupSummary = try inspect(target) }
        catch { throw CoreError.failedBackup("backup schema validation failed: \(error)") }
        guard sourceSummary == backupSummary else {
            throw CoreError.failedBackup("backup schema and row counts do not match the source")
        }
        do { try Self.requireIntegrity(target, context: "backup") }
        catch { throw CoreError.failedBackup("backup integrity check failed: \(error)") }
        try Self.requireQuiescent(target, context: "backup")
        let closeStatus = target.close()
        guard closeStatus == SQLITE_OK else { throw CoreError.failedBackup("backup database close failed status=\(closeStatus)") }
        try Self.requireDeleteJournalHeader(destination)
        try Self.removePrivateBackupSHM(destination)
        try Self.requireNoSidecars(for: destination, context: "backup")
        do { try Self.syncFile(destination, error: "backup file sync failed") }
        catch { throw CoreError.failedBackup("\(error)") }
        do { try Self.syncDirectory(destination.deletingLastPathComponent(), error: "backup directory sync failed") }
        catch { throw CoreError.failedBackup("\(error)") }
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
        defer { query.finalize() }
        var columns: [String] = []
        while try query.step() { columns.append(try query.text(1)) }
        guard columns == expected else { throw CoreError.unreadableLibrary("library schema mismatch in \(table)") }
    }

    private func rowCount(_ db: SQLiteConnection, table: String) throws -> Int64 {
        let query = try db.prepare("SELECT count(*) FROM \(table)")
        defer { query.finalize() }
        guard try query.step() else { throw CoreError.unreadableLibrary("library count query failed") }
        let count = query.integer(0)
        guard try !query.step() else { throw CoreError.unreadableLibrary("library count query returned extra rows") }
        return count
    }

    private static func requireJournalMode(_ database: SQLiteConnection, expected: String, context: String) throws {
        let statement = try database.prepare("PRAGMA journal_mode=\(expected.uppercased())")
        let mode: String
        do {
            guard try statement.step() else { throw CoreError.sqlite(code: SQLITE_ERROR, message: "\(context) journal mode returned no row") }
            mode = try statement.text(0).lowercased()
            guard try !statement.step() else { throw CoreError.sqlite(code: SQLITE_ERROR, message: "\(context) journal mode returned extra rows") }
        } catch {
            _ = statement.finalize()
            throw error
        }
        let finalizeStatus = statement.finalize()
        guard finalizeStatus == SQLITE_OK else { throw CoreError.sqlite(code: finalizeStatus, message: "\(context) journal mode finalize failed") }
        guard mode == expected else { throw CoreError.sqlite(code: SQLITE_ERROR, message: "\(context) journal mode is \(mode)") }
    }

    private static func requireIntegrity(_ database: SQLiteConnection, context: String) throws {
        let statement = try database.prepare("PRAGMA integrity_check")
        let result: String
        do {
            guard try statement.step() else { throw CoreError.sqlite(code: SQLITE_ERROR, message: "\(context) integrity check returned no row") }
            result = try statement.text(0)
            guard try !statement.step() else { throw CoreError.sqlite(code: SQLITE_CORRUPT, message: "\(context) integrity check returned more than one row") }
        } catch {
            _ = statement.finalize()
            throw error
        }
        let finalizeStatus = statement.finalize()
        guard finalizeStatus == SQLITE_OK else { throw CoreError.sqlite(code: finalizeStatus, message: "\(context) integrity check finalize failed") }
        guard result == "ok" else { throw CoreError.sqlite(code: SQLITE_CORRUPT, message: "\(context) integrity check: \(result)") }
    }

    private static func requireNoSidecars(for databaseURL: URL, context: String) throws {
        let sidecars = ["-wal", "-shm", "-journal"].compactMap { suffix -> String? in
            let path = databaseURL.path + suffix
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.intValue ?? -1
            return "\(suffix):\(size)"
        }
        guard sidecars.isEmpty else {
            throw CoreError.unreadableLibrary("\(context) has sidecars [\(sidecars.joined(separator: ", "))]")
        }
    }

    private static func requireQuiescent(_ database: SQLiteConnection, context: String) throws {
        let autocommit = sqlite3_get_autocommit(database.handle)
        let transaction = sqlite3_txn_state(database.handle, "main")
        var statement = sqlite3_next_stmt(database.handle, nil)
        var busyStatements: [String] = []
        while let current = statement {
            if sqlite3_stmt_busy(current) != 0 {
                busyStatements.append(sqlite3_sql(current).map(String.init(cString:)) ?? "<unknown>")
            }
            statement = sqlite3_next_stmt(database.handle, current)
        }
        guard autocommit != 0, transaction == SQLITE_TXN_NONE, busyStatements.isEmpty else {
            throw CoreError.failedBackup("\(context) has active SQLite work autocommit=\(autocommit) transaction=\(transaction) statements=[\(busyStatements.joined(separator: "; "))]")
        }
    }

    private static func requireDeleteJournalHeader(_ url: URL) throws {
        let header: Data
        do { header = try Data(contentsOf: url, options: .mappedIfSafe) }
        catch { throw CoreError.failedBackup("backup journal header cannot be read") }
        guard header.count >= 20 else { throw CoreError.failedBackup("backup journal header is truncated") }
        let first = header[18]
        let second = header[19]
#if DEBUG
        NSLog("[JohnCoreSQLite] backup journal header mode bytes=%d/%d", first, second)
#endif
        guard first == 1, second == 1 else {
            throw CoreError.failedBackup("backup header is not in DELETE journal mode (\(first)/\(second))")
        }
    }

    private static func removePrivateBackupSHM(_ url: URL) throws {
        let wal = url.path + "-wal"
        let journal = url.path + "-journal"
        let shm = url.path + "-shm"
        guard !FileManager.default.fileExists(atPath: wal), !FileManager.default.fileExists(atPath: journal) else {
            throw CoreError.failedBackup("backup has a WAL or rollback journal after DELETE normalization")
        }
        if FileManager.default.fileExists(atPath: shm) {
            do { try FileManager.default.removeItem(atPath: shm) }
            catch { throw CoreError.failedBackup("private backup SHM removal failed: \(error)") }
        }
        guard !FileManager.default.fileExists(atPath: shm) else {
            throw CoreError.failedBackup("private backup SHM remains after removal")
        }
    }

    private static func createExclusiveFile(_ url: URL) throws {
        let descriptor = url.path.withCString { open($0, O_WRONLY | O_CREAT | O_EXCL, mode_t(S_IRUSR | S_IWUSR)) }
        guard descriptor >= 0 else { throw CoreError.failedBackup("unique backup file could not be created") }
        let closeStatus = close(descriptor)
        guard closeStatus == 0 else { throw CoreError.failedBackup("unique backup file descriptor could not be closed") }
    }

    private static func syncFile(_ url: URL, error message: String) throws {
        let descriptor = url.path.withCString { open($0, O_RDWR) }
        guard descriptor >= 0 else { throw CoreError.unreadableLibrary(message) }
        let syncStatus = fsync(descriptor)
        let closeStatus = close(descriptor)
        guard syncStatus == 0, closeStatus == 0 else { throw CoreError.unreadableLibrary(message) }
    }

    private static func syncDirectory(_ url: URL, error message: String) throws {
        let descriptor = url.path.withCString { open($0, O_RDONLY) }
        guard descriptor >= 0 else { throw CoreError.unreadableLibrary(message) }
        let syncStatus = fsync(descriptor)
        let closeStatus = close(descriptor)
        guard syncStatus == 0, closeStatus == 0 else { throw CoreError.unreadableLibrary(message) }
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
