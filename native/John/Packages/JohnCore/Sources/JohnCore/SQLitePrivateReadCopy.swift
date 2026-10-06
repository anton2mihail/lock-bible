import Foundation
import CryptoKit
import CSQLite
import Darwin

/// Owns a read connection and, when needed, its private normalized database copy.
final class SQLiteLibraryReadHandle: @unchecked Sendable {
    let connection: SQLiteConnection
    private let sourceURL: URL?
    private let sourceHash: String?
    private let sourceSidecars: [String]?
    private let workspaceURL: URL?
    private var isClosed = false

    private init(connection: SQLiteConnection) {
        self.connection = connection
        self.sourceURL = nil
        self.sourceHash = nil
        self.sourceSidecars = nil
        self.workspaceURL = nil
    }

    private init(connection: SQLiteConnection, sourceURL: URL, sourceHash: String,
                 sourceSidecars: [String], workspaceURL: URL) {
        self.connection = connection
        self.sourceURL = sourceURL
        self.sourceHash = sourceHash
        self.sourceSidecars = sourceSidecars
        self.workspaceURL = workspaceURL
    }

    static func direct(_ connection: SQLiteConnection) -> SQLiteLibraryReadHandle {
        SQLiteLibraryReadHandle(connection: connection)
    }

    static func privateCopy(for sourceURL: URL) throws -> SQLiteLibraryReadHandle {
        let source = sourceURL.standardizedFileURL
        let original = try sourceSnapshot(source)
        guard original.sidecars.isEmpty, try isWALHeader(source) else {
            throw CoreError.sqlite(code: SQLITE_CANTOPEN, message: "private read copy does not match the closed WAL trigger")
        }

        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("JohnLibraryRead-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: false,
                                                    attributes: [.posixPermissions: 0o700])
        } catch {
            throw CoreError.unreadableLibrary("private read directory cannot be created")
        }
        var keepWorkspace = false
        defer {
            if !keepWorkspace { try? FileManager.default.removeItem(at: workspace) }
        }

        let copy = workspace.appendingPathComponent(source.lastPathComponent, isDirectory: false)
        do { try FileManager.default.copyItem(at: source, to: copy) }
        catch { throw CoreError.unreadableLibrary("private read copy cannot be created") }
        let afterCopy = try sourceSnapshot(source)
        guard afterCopy == original, try fileSHA256(copy) == original.hash else {
            throw CoreError.unreadableLibrary("library changed while the private read copy was created")
        }

        let writable: SQLiteConnection
        do { writable = try SQLiteConnection(url: copy, readOnly: false) }
        catch { throw CoreError.unreadableLibrary("private read copy cannot be opened") }
        do {
            try setDeleteJournalMode(writable)
            try requirePrivateCopySidecars(copy, allowSharedMemory: true)
            let closeStatus = writable.close()
            guard closeStatus == SQLITE_OK else {
                throw CoreError.unreadableLibrary("private read copy close failed status=\(closeStatus)")
            }
            try removePrivateCopySidecars(copy)
            try requireDeleteHeader(copy)
            guard try sourceSnapshot(source) == original else {
                throw CoreError.unreadableLibrary("library changed during private read normalization")
            }
            guard try fileSHA256(copy) != original.hash else {
                throw CoreError.unreadableLibrary("private read copy journal mode did not change")
            }

            let readOnly: SQLiteConnection
            do { readOnly = try SQLiteConnection(url: copy, readOnly: true) }
            catch { throw CoreError.unreadableLibrary("normalized private read copy cannot open read-only") }
            keepWorkspace = true
            return SQLiteLibraryReadHandle(connection: readOnly, sourceURL: source,
                                           sourceHash: original.hash, sourceSidecars: original.sidecars,
                                           workspaceURL: workspace)
        } catch {
            _ = writable.close()
            throw error
        }
    }

    var isPrivateCopy: Bool { workspaceURL != nil }

    func validateSourceUnchanged() throws {
        guard let sourceURL, let sourceHash, let sourceSidecars else { return }
        let current = try Self.sourceSnapshot(sourceURL)
        guard current.hash == sourceHash, current.sidecars == sourceSidecars else {
            throw CoreError.unreadableLibrary("source library changed while its private read copy was in use")
        }
    }

    func close() throws {
        guard !isClosed else { return }
        let result = connection.close()
        guard result == SQLITE_OK else { throw CoreError.sqlite(code: result, message: "library read connection close failed") }
        isClosed = true
        if let workspaceURL {
            do { try FileManager.default.removeItem(at: workspaceURL) }
            catch { throw CoreError.unreadableLibrary("private read copy cleanup failed") }
        }
    }

    deinit {
        if connection.close() == SQLITE_OK, let workspaceURL {
            try? FileManager.default.removeItem(at: workspaceURL)
        }
    }

    private struct SourceSnapshot: Equatable {
        let hash: String
        let sidecars: [String]
    }

    private static func sourceSnapshot(_ url: URL) throws -> SourceSnapshot {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, (values.fileSize ?? 0) > 0 else {
            throw CoreError.unreadableLibrary("library database is not a nonempty regular file")
        }
        let sidecars = ["-wal", "-shm", "-journal"].filter {
            FileManager.default.fileExists(atPath: url.path + $0)
        }.sorted()
        return SourceSnapshot(hash: try fileSHA256(url), sidecars: sidecars)
    }

    private static func fileSHA256(_ url: URL) throws -> String {
        let handle: FileHandle
        do { handle = try FileHandle(forReadingFrom: url) }
        catch { throw CoreError.unreadableLibrary("library hash input cannot be opened") }
        defer { try? handle.close() }
        var hasher = SHA256()
        do {
            while let bytes = try handle.read(upToCount: 1_048_576), !bytes.isEmpty {
                hasher.update(data: bytes)
            }
        } catch {
            throw CoreError.unreadableLibrary("library hash input cannot be read")
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func isWALHeader(_ url: URL) throws -> Bool {
        let handle: FileHandle
        do { handle = try FileHandle(forReadingFrom: url) }
        catch { throw CoreError.unreadableLibrary("library header cannot be opened") }
        defer { try? handle.close() }
        let bytes: Data
        do { bytes = try handle.read(upToCount: 20) ?? Data() }
        catch { throw CoreError.unreadableLibrary("library header cannot be read") }
        return bytes.count >= 20 && bytes[18] == 2 && bytes[19] == 2
    }

    private static func setDeleteJournalMode(_ database: SQLiteConnection) throws {
        let statement = try database.prepare("PRAGMA journal_mode=DELETE")
        let mode: String
        do {
            guard try statement.step() else { throw CoreError.sqlite(code: SQLITE_ERROR, message: "private journal mode returned no row") }
            mode = try statement.text(0).lowercased()
            guard try !statement.step() else { throw CoreError.sqlite(code: SQLITE_ERROR, message: "private journal mode returned extra rows") }
        } catch {
            _ = statement.finalize()
            throw error
        }
        let finalize = statement.finalize()
        guard finalize == SQLITE_OK, mode == "delete" else {
            throw CoreError.sqlite(code: finalize == SQLITE_OK ? SQLITE_ERROR : finalize,
                                   message: "private journal mode normalization failed")
        }
    }

    private static func requirePrivateCopySidecars(_ url: URL, allowSharedMemory: Bool) throws {
        let wal = URL(fileURLWithPath: url.path + "-wal")
        let journal = URL(fileURLWithPath: url.path + "-journal")
        let shm = URL(fileURLWithPath: url.path + "-shm")
        if FileManager.default.fileExists(atPath: journal.path) {
            throw CoreError.unreadableLibrary("private read copy has a rollback journal")
        }
        if FileManager.default.fileExists(atPath: wal.path) {
            let size = (try? FileManager.default.attributesOfItem(atPath: wal.path)[.size] as? NSNumber)?.intValue ?? -1
            guard size == 0 else { throw CoreError.unreadableLibrary("private read copy has a nonempty WAL") }
        }
        if !allowSharedMemory && FileManager.default.fileExists(atPath: shm.path) {
            throw CoreError.unreadableLibrary("private read copy has a shared-memory sidecar")
        }
    }

    private static func removePrivateCopySidecars(_ url: URL) throws {
        try requirePrivateCopySidecars(url, allowSharedMemory: true)
        for suffix in ["-wal", "-shm"] {
            let sidecar = url.path + suffix
            if FileManager.default.fileExists(atPath: sidecar) {
                do { try FileManager.default.removeItem(atPath: sidecar) }
                catch { throw CoreError.unreadableLibrary("private read sidecar cleanup failed") }
            }
        }
        try requirePrivateCopySidecars(url, allowSharedMemory: false)
    }

    private static func requireDeleteHeader(_ url: URL) throws {
        let handle: FileHandle
        do { handle = try FileHandle(forReadingFrom: url) }
        catch { throw CoreError.unreadableLibrary("private read header cannot be opened") }
        defer { try? handle.close() }
        let bytes = try handle.read(upToCount: 20) ?? Data()
        guard bytes.count >= 20, bytes[18] == 1, bytes[19] == 1 else {
            throw CoreError.unreadableLibrary("private read copy is not in DELETE journal mode")
        }
    }
}
