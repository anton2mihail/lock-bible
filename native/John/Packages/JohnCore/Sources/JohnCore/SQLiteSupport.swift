import Foundation
import CSQLite
import CZlib

final class SQLiteConnection {
    let handle: OpaquePointer

    init(url: URL, readOnly: Bool, createIfMissing: Bool = false) throws {
        var opened: OpaquePointer?
        let flags = readOnly ? SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX : SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX | (createIfMissing ? SQLITE_OPEN_CREATE : 0)
        let result = sqlite3_open_v2(url.path, &opened, flags, nil)
        guard result == SQLITE_OK, let opened else {
            let message = opened.map { String(cString: sqlite3_errmsg($0)) } ?? "no SQLite handle"
            if let opened { sqlite3_close_v2(opened) }
            throw CoreError.sqlite(code: result, message: message)
        }
        self.handle = opened
        sqlite3_busy_timeout(opened, 5_000)
    }

    deinit { sqlite3_close_v2(handle) }

    func prepare(_ sql: String) throws -> SQLiteStatement {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard result == SQLITE_OK, let statement else { throw failure(result) }
        return SQLiteStatement(statement, database: self)
    }

    func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(handle, sql, nil, nil, &errorMessage)
        defer { if let errorMessage { sqlite3_free(errorMessage) } }
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(handle))
            throw CoreError.sqlite(code: result, message: message)
        }
    }

    func failure(_ code: Int32) -> CoreError { .sqlite(code: code, message: String(cString: sqlite3_errmsg(handle))) }
}

final class SQLiteStatement {
    private let handle: OpaquePointer
    private let database: SQLiteConnection
    init(_ handle: OpaquePointer, database: SQLiteConnection) { self.handle = handle; self.database = database }
    deinit { sqlite3_finalize(handle) }

    func bind(_ value: String, at index: Int32) throws {
        let result = value.withCString { sqlite3_bind_text(handle, index, $0, -1, Self.transient) }
        guard result == SQLITE_OK else { throw database.failure(result) }
    }
    func bind(_ value: Int32, at index: Int32) throws {
        let result = sqlite3_bind_int(handle, index, value)
        guard result == SQLITE_OK else { throw database.failure(result) }
    }
    func bind(_ value: Int64, at index: Int32) throws {
        let result = sqlite3_bind_int64(handle, index, value)
        guard result == SQLITE_OK else { throw database.failure(result) }
    }
    func step() throws -> Bool {
        let result = sqlite3_step(handle)
        if result == SQLITE_ROW { return true }
        if result == SQLITE_DONE { return false }
        throw database.failure(result)
    }
    func text(_ index: Int32) throws -> String {
        guard sqlite3_column_type(handle, index) != SQLITE_NULL else { throw CoreError.invalidResource("unexpected SQL NULL") }
        guard let value = sqlite3_column_text(handle, index) else { return "" }
        let bytes = Int(sqlite3_column_bytes(handle, index))
        return String(decoding: UnsafeBufferPointer(start: value, count: bytes), as: UTF8.self)
    }
    func integer(_ index: Int32) -> Int64 { sqlite3_column_int64(handle, index) }
    func columnType(_ index: Int32) -> Int32 { sqlite3_column_type(handle, index) }
    func blob(_ index: Int32) throws -> Data {
        guard sqlite3_column_type(handle, index) == SQLITE_BLOB else { throw CoreError.invalidResource("expected SQLite BLOB") }
        let count = Int(sqlite3_column_bytes(handle, index))
        guard count > 0, let pointer = sqlite3_column_blob(handle, index) else { throw CoreError.invalidResource("empty SQLite BLOB") }
        return Data(bytes: pointer, count: count)
    }
    func reset() throws {
        let result = sqlite3_reset(handle)
        guard result == SQLITE_OK else { throw database.failure(result) }
        let clear = sqlite3_clear_bindings(handle)
        guard clear == SQLITE_OK else { throw database.failure(clear) }
    }
    var columnType3: Int32 { sqlite3_column_type(handle, 3) }
    func textBytes(_ index: Int32, limit: Int) throws -> Data {
        guard sqlite3_column_type(handle, index) == SQLITE_TEXT else { throw CoreError.invalidResource("expected SQLite TEXT") }
        let count = Int(sqlite3_column_bytes(handle, index))
        guard count >= 0, count <= limit else { throw CoreError.oversizedContent(limit: limit) }
        if count == 0 { return Data() }
        guard let pointer = sqlite3_column_text(handle, index) else { throw CoreError.invalidResource("null SQLite TEXT pointer") }
        return Data(bytes: pointer, count: count)
    }
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}

enum BoundedZlib {
    static func inflate(_ compressed: Data, limit: Int) throws -> Data {
        guard limit > 0, !compressed.isEmpty else { throw CoreError.damagedSection("empty compressed section") }
        var output = Data(count: limit)
        var outputLength = uLongf(limit)
        let status: Int32 = output.withUnsafeMutableBytes { destination in
            compressed.withUnsafeBytes { source in
                guard let dst = destination.baseAddress?.assumingMemoryBound(to: Bytef.self),
                      let src = source.baseAddress?.assumingMemoryBound(to: Bytef.self) else { return Z_DATA_ERROR }
                return uncompress(dst, &outputLength, src, uLong(compressed.count))
            }
        }
        if status == Z_BUF_ERROR { throw CoreError.oversizedContent(limit: limit) }
        guard status == Z_OK else { throw CoreError.damagedSection("zlib status \(status)") }
        output.count = Int(outputLength)
        return output
    }
}
