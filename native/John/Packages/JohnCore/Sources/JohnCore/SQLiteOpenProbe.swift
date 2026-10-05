#if DEBUG
import Foundation
import CSQLite
import Darwin

public enum SQLiteOpenProbeMode: String, Codable, Sendable {
    case readOnly
    case deleteModeControl
}

public struct SQLiteOpenProbeResult: Codable, Sendable {
    public let path: String
    public let mode: SQLiteOpenProbeMode
    public let flags: Int32
    public let fileSize: Int64
    public let fileMode: UInt32
    public let posixOpenResult: Int32
    public let posixErrno: Int32
    public let sqliteOpenResult: Int32
    public let sqliteExtendedResult: Int32
    public let sqliteErrno: Int32
    public let sqliteOperation: String?
    public let sqliteOperationExtendedResult: Int32
    public let sqliteOperationErrno: Int32
    public let journalMode: String?
    public let journalStepResult: Int32
    public let journalFinishResult: Int32
    public let statementFinalizeResult: Int32
    public let closeResult: Int32
    public let sqliteVersion: String
    public let sqliteSourceID: String
    public let errorMessage: String?
}

public struct SQLiteReadProbeStatement: Codable, Sendable {
    public let operation: String
    public let prepareResult: Int32
    public let stepResults: [Int32]
    public let finalizeResult: Int32
    public let extendedResult: Int32
    public let systemErrno: Int32
    public let values: [String]
}

public struct SQLiteReadTransactionProbeResult: Codable, Sendable {
    public let path: String
    public let openResult: Int32
    public let openExtendedResult: Int32
    public let openSystemErrno: Int32
    public let beginResult: Int32
    public let beginExtendedResult: Int32
    public let beginSystemErrno: Int32
    public let statements: [SQLiteReadProbeStatement]
    public let commitResult: Int32
    public let commitExtendedResult: Int32
    public let commitSystemErrno: Int32
    public let rollbackResult: Int32
    public let rollbackExtendedResult: Int32
    public let rollbackSystemErrno: Int32
    public let closeResult: Int32
    public let sqliteVersion: String
    public let sqliteSourceID: String
}

/// Open only a caller-owned diagnostic database. Do not pass the live user library.
public enum SQLiteOpenProbe {
    /// Run a bounded read transaction on a caller-owned copied library database.
    public static func runLibraryReadTransaction(url: URL) -> SQLiteReadTransactionProbeResult {
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        let openResult = sqlite3_open_v2(url.path, &database, flags, nil)
        let openExtendedResult = database.map { sqlite3_extended_errcode($0) } ?? openResult
        let openSystemErrno = database.map { sqlite3_system_errno($0) } ?? errno
        var beginResult: Int32 = SQLITE_MISUSE
        var beginExtendedResult: Int32 = SQLITE_OK
        var beginSystemErrno: Int32 = 0
        var commitResult: Int32 = SQLITE_MISUSE
        var commitExtendedResult: Int32 = SQLITE_OK
        var commitSystemErrno: Int32 = 0
        var rollbackResult: Int32 = SQLITE_MISUSE
        var rollbackExtendedResult: Int32 = SQLITE_OK
        var rollbackSystemErrno: Int32 = 0
        var closeResult: Int32 = SQLITE_OK
        var statements: [SQLiteReadProbeStatement] = []
        var transactionOpen = false

        if openResult == SQLITE_OK, let database {
            var beginError: UnsafeMutablePointer<CChar>?
            beginResult = sqlite3_exec(database, "BEGIN", nil, nil, &beginError)
            if let beginError { sqlite3_free(beginError) }
            if beginResult != SQLITE_OK {
                beginExtendedResult = sqlite3_extended_errcode(database)
                beginSystemErrno = sqlite3_system_errno(database)
            }
            transactionOpen = beginResult == SQLITE_OK

            if transactionOpen {
                let queries: [(String, String)] = [
                    ("user-version", "PRAGMA user_version"),
                    ("integrity-check", "PRAGMA integrity_check"),
                    ("bookmark-count", "SELECT count(*) FROM bookmarks"),
                    ("highlight-count", "SELECT count(*) FROM highlights"),
                    ("note-count", "SELECT count(*) FROM notes"),
                ]
                for (operation, sql) in queries {
                    let statementResult = runReadStatement(database: database, operation: operation, sql: sql)
                    statements.append(statementResult)
                    guard statementResult.prepareResult == SQLITE_OK,
                          statementResult.stepResults.last == SQLITE_DONE,
                          statementResult.finalizeResult == SQLITE_OK else { break }
                }
                let allSucceeded = statements.count == queries.count && statements.allSatisfy {
                    $0.prepareResult == SQLITE_OK && $0.stepResults.last == SQLITE_DONE && $0.finalizeResult == SQLITE_OK
                }
                if allSucceeded {
                    commitResult = sqlite3_exec(database, "COMMIT", nil, nil, nil)
                    if commitResult != SQLITE_OK {
                        commitExtendedResult = sqlite3_extended_errcode(database)
                        commitSystemErrno = sqlite3_system_errno(database)
                    }
                    transactionOpen = commitResult != SQLITE_OK
                }
            }
            if transactionOpen {
                rollbackResult = sqlite3_exec(database, "ROLLBACK", nil, nil, nil)
                if rollbackResult != SQLITE_OK {
                    rollbackExtendedResult = sqlite3_extended_errcode(database)
                    rollbackSystemErrno = sqlite3_system_errno(database)
                }
            }
            closeResult = sqlite3_close(database)
        } else if let database {
            closeResult = sqlite3_close_v2(database)
        }

        return SQLiteReadTransactionProbeResult(
            path: url.path, openResult: openResult, openExtendedResult: openExtendedResult,
            openSystemErrno: openSystemErrno, beginResult: beginResult,
            beginExtendedResult: beginExtendedResult, beginSystemErrno: beginSystemErrno,
            statements: statements, commitResult: commitResult,
            commitExtendedResult: commitExtendedResult, commitSystemErrno: commitSystemErrno,
            rollbackResult: rollbackResult, rollbackExtendedResult: rollbackExtendedResult,
            rollbackSystemErrno: rollbackSystemErrno,
            closeResult: closeResult, sqliteVersion: String(cString: sqlite3_libversion()),
            sqliteSourceID: String(cString: sqlite3_sourceid())
        )
    }

    private static func runReadStatement(database: OpaquePointer, operation: String, sql: String) -> SQLiteReadProbeStatement {
        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        var stepResults: [Int32] = []
        var values: [String] = []
        var extendedResult = prepareResult == SQLITE_OK ? SQLITE_OK : sqlite3_extended_errcode(database)
        var systemErrno = prepareResult == SQLITE_OK ? 0 : sqlite3_system_errno(database)

        if prepareResult == SQLITE_OK, let statement {
            // Each query must return no more than ten rows. This keeps a damaged integrity report bounded.
            for _ in 0..<11 {
                let stepResult = sqlite3_step(statement)
                stepResults.append(stepResult)
                if stepResult == SQLITE_ROW {
                    if operation == "integrity-check" {
                        if let value = sqlite3_column_text(statement, 0) { values.append(String(cString: value)) }
                    } else if operation == "user-version" || operation.hasSuffix("-count") {
                        values.append(String(sqlite3_column_int64(statement, 0)))
                    }
                    continue
                }
                if stepResult != SQLITE_DONE {
                    extendedResult = sqlite3_extended_errcode(database)
                    systemErrno = sqlite3_system_errno(database)
                }
                break
            }
            if stepResults.count == 11, stepResults.last == SQLITE_ROW {
                extendedResult = sqlite3_extended_errcode(database)
                systemErrno = sqlite3_system_errno(database)
            }
        }
        let finalizeResult = statement.map { sqlite3_finalize($0) } ?? SQLITE_OK
        if finalizeResult != SQLITE_OK && extendedResult == SQLITE_OK {
            extendedResult = sqlite3_extended_errcode(database)
            systemErrno = sqlite3_system_errno(database)
        }
#if DEBUG
        NSLog("[JohnCoreSQLiteProbe] read operation=%@ prepare=%d steps=%@ finalize=%d extended=%d systemErrno=%d",
              operation, prepareResult, stepResults.map(String.init).joined(separator: ","),
              finalizeResult, extendedResult, systemErrno)
#endif
        return SQLiteReadProbeStatement(operation: operation, prepareResult: prepareResult,
                                        stepResults: stepResults, finalizeResult: finalizeResult,
                                        extendedResult: extendedResult, systemErrno: systemErrno, values: values)
    }

    public static func run(url: URL, mode: SQLiteOpenProbeMode) -> SQLiteOpenProbeResult {
        let flags: Int32 = mode == .readOnly
            ? SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
            : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        var metadata = stat()
        let statResult = url.path.withCString { stat($0, &metadata) }
        let fileSize = statResult == 0 ? Int64(metadata.st_size) : -1
        let fileMode = statResult == 0 ? UInt32(metadata.st_mode & 0o7777) : 0
        let descriptor = url.path.withCString { open($0, O_RDONLY) }
        let posixErrno = descriptor < 0 ? errno : 0
        if descriptor >= 0 { _ = Darwin.close(descriptor) }

        var database: OpaquePointer?
        let controlPathExists = mode == .deleteModeControl && FileManager.default.fileExists(atPath: url.path)
        let openResult: Int32
        if controlPathExists {
            openResult = SQLITE_CANTOPEN
        } else {
            openResult = sqlite3_open_v2(url.path, &database, flags, nil)
        }
        let sqliteErrno = database.map { sqlite3_system_errno($0) } ?? errno
        let extendedResult = database.map { sqlite3_extended_errcode($0) } ?? openResult
        var journalMode: String?
        var journalStepResult: Int32 = -1
        var journalFinishResult: Int32 = -1
        var finalizeResult: Int32 = SQLITE_OK
        var closeResult: Int32 = SQLITE_OK
        var errorMessage: String? = controlPathExists ? "control database path already exists" : nil
        var sqliteOperation: String?
        var operationExtendedResult: Int32 = SQLITE_OK
        var operationErrno: Int32 = 0

        if openResult == SQLITE_OK, let database {
            let sql = mode == .readOnly ? "PRAGMA journal_mode" : "PRAGMA journal_mode=DELETE"
            sqliteOperation = sql
            var statement: OpaquePointer?
            let prepareResult = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
            if prepareResult == SQLITE_OK, let statement {
                journalStepResult = sqlite3_step(statement)
                if journalStepResult == SQLITE_ROW, let value = sqlite3_column_text(statement, 0) {
                    journalMode = String(cString: value)
                    journalFinishResult = sqlite3_step(statement)
                }
                finalizeResult = sqlite3_finalize(statement)
                if journalStepResult != SQLITE_ROW || journalFinishResult != SQLITE_DONE {
                    operationExtendedResult = sqlite3_extended_errcode(database)
                    operationErrno = sqlite3_system_errno(database)
                    errorMessage = String(cString: sqlite3_errmsg(database))
                }
            } else {
                journalStepResult = prepareResult
                operationExtendedResult = sqlite3_extended_errcode(database)
                operationErrno = sqlite3_system_errno(database)
                errorMessage = String(cString: sqlite3_errmsg(database))
                if let statement { finalizeResult = sqlite3_finalize(statement) }
            }
            if journalStepResult != SQLITE_ROW || journalFinishResult != SQLITE_DONE {
                errorMessage = String(cString: sqlite3_errmsg(database))
#if DEBUG
                NSLog("[JohnCoreSQLiteProbe] operation-failed sql=%@ prepareOrStep=%d extended=%d systemErrno=%d",
                      sql, journalStepResult, operationExtendedResult, operationErrno)
#endif
            }
            closeResult = sqlite3_close(database)
        } else {
            errorMessage = database.map { String(cString: sqlite3_errmsg($0)) } ?? "no SQLite handle"
            if let database { closeResult = sqlite3_close_v2(database) }
        }

        return SQLiteOpenProbeResult(
            path: url.path, mode: mode, flags: flags, fileSize: fileSize, fileMode: fileMode,
            posixOpenResult: descriptor, posixErrno: posixErrno,
            sqliteOpenResult: openResult, sqliteExtendedResult: extendedResult,
            sqliteErrno: sqliteErrno, sqliteOperation: sqliteOperation,
            sqliteOperationExtendedResult: operationExtendedResult, sqliteOperationErrno: operationErrno,
            journalMode: journalMode,
            journalStepResult: journalStepResult, journalFinishResult: journalFinishResult,
            statementFinalizeResult: finalizeResult, closeResult: closeResult,
            sqliteVersion: String(cString: sqlite3_libversion()),
            sqliteSourceID: String(cString: sqlite3_sourceid()), errorMessage: errorMessage
        )
    }
}
#endif
