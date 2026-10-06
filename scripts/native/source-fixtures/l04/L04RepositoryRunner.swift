#if DEBUG
import Foundation
import CryptoKit
import JohnCore
import CSQLite
import CZlib

/// Bounded app-runner checks for the production Core repositories.
/// Main supplies process-owned fixture and output paths. This file does not launch an app.
public enum L04RepositoryRunner {
    private struct RotationFixture: Decodable {
        let outputs: [RotationOutput]
    }
    private struct RotationOutput: Decodable {
        let editionId: String
        let scope: RotationScope
        let cadenceMinutes: Int
        let timezone: String
        let timezoneOffsetMinutes: Int
        let instant: String
        let localSlot: Int64
        let poolCount: Int
        let poolIndex: Int
        let verse: RotationVerse
        let nextRotationInstant: String
        enum CodingKeys: String, CodingKey {
            case editionId, scope, cadenceMinutes, timezone, timezoneOffsetMinutes
            case instant, localSlot, poolCount, poolIndex, verse, nextRotationInstant
        }
    }
    private struct RotationVerse: Decodable {
        let ref: String
        let book: String
        let chapter: Int
        let verse: String
        let text: String
    }
    private struct BibleFixture: Decodable { let outputs: [BibleOutput] }
    private struct BibleOutput: Decodable {
        let edition: String
        let book: BibleBookExpected
        let chapter: BibleChapter
        let passage: BiblePassageExpected
    }
    private struct BibleBookExpected: Decodable { let code: String; let name: String; let order: Int }
    private struct BiblePassageExpected: Decodable {
        let startIndex: Int; let endIndex: Int; let startVerse: String; let endVerse: String
        let scriptureText: String; let verses: [BiblePassageVerseExpected]
    }
    private struct BiblePassageVerseExpected: Decodable { let verse: String; let index: Int; let text: String }

    /// Compare the copied closed-WAL library, run bounded repository checks, and write one JSON result.
    /// `databaseURL` must point inside `outputRoot`; Core can write only this test-owned copy.
    public static func run(
        roots: ResourceRoots,
        databaseURL: URL,
        expectedClosedSourceSHA256: String,
        recoveryDirectory: URL,
        bibleFixtureURL: URL,
        rotationFixtureURL: URL,
        unsupportedSchemaURL: URL,
        expectedUnsupportedSchemaSHA256: String,
        damagedDatabaseURL: URL,
        expectedDamagedDatabaseSHA256: String,
        outputURL: URL
    ) async throws {
        let outputRoot = outputURL.deletingLastPathComponent().standardizedFileURL
        let database = databaseURL.standardizedFileURL
        guard database.path.hasPrefix(outputRoot.path + "/"),
              !FileManager.default.fileExists(atPath: outputURL.path) else {
            throw CoreError.invalidIdentity("runner output must be new and contain the copied database")
        }

        var checks: [[String: Any]] = []
        let before = try fileSnapshot(database)
        guard before.hash == expectedClosedSourceSHA256, before.sidecars.isEmpty else {
            throw CoreError.invalidResource("closed source does not match its proof hash or has sidecars")
        }
        let summary = try await SQLiteLibraryBoundary(databaseURL: database).inspect()
        guard summary.schemaVersion == 1, summary.bookmarkCount == 2,
              summary.highlightCount == 1, summary.noteCount == 1 else {
            throw CoreError.invalidResource("closed-WAL library counts did not match 2/1/1")
        }
        let afterInspect = try fileSnapshot(database)
        guard before == afterInspect else { throw CoreError.invalidResource("read-only inspect changed the source library") }
        checks.append(["name": "closedSourceInspect", "passed": true,
                       "schema": summary.schemaVersion, "bookmarks": summary.bookmarkCount,
                       "highlights": summary.highlightCount, "notes": summary.noteCount,
                       "sourceSnapshotUnchanged": true, "sha256": before.hash,
                       "sidecars": before.sidecars])

        let unsupportedBefore = try fileSnapshot(unsupportedSchemaURL)
        guard unsupportedBefore.hash == expectedUnsupportedSchemaSHA256, unsupportedBefore.sidecars.isEmpty else {
            throw CoreError.invalidResource("schema 77 fixture hash or sidecar set is wrong")
        }
        do {
            _ = try await SQLiteLibraryBoundary(databaseURL: unsupportedSchemaURL).inspect()
            throw CoreError.invalidResource("schema 77 library unexpectedly opened")
        } catch CoreError.unsupportedSchema(77) {
            let unsupportedAfter = try fileSnapshot(unsupportedSchemaURL)
            guard unsupportedBefore == unsupportedAfter else { throw CoreError.invalidResource("schema 77 input changed") }
            checks.append(["name": "unsupportedSchema", "passed": true, "schema": 77,
                           "sourceUnchanged": true, "sha256": unsupportedBefore.hash, "sidecars": unsupportedBefore.sidecars])
        }
        let damagedBefore = try fileSnapshot(damagedDatabaseURL)
        guard damagedBefore.hash == expectedDamagedDatabaseSHA256, damagedBefore.sidecars.isEmpty else {
            throw CoreError.invalidResource("damaged closed-file fixture hash or sidecar set is wrong")
        }
        do {
            _ = try await SQLiteLibraryBoundary(databaseURL: damagedDatabaseURL).inspect()
            throw CoreError.invalidResource("damaged library unexpectedly opened")
        } catch let error as CoreError {
            switch error {
            case .sqlite(code: 26, _): break
            case .unreadableLibrary(let message) where message.contains("sqlite(code: 26"): break
            default: throw error
            }
            let damagedAfter = try fileSnapshot(damagedDatabaseURL)
            guard damagedBefore == damagedAfter else { throw CoreError.invalidResource("damaged input changed") }
            checks.append(["name": "damagedClosedLibrary", "passed": true,
                           "sqliteCode": 26, "sourceUnchanged": true,
                           "sha256": damagedBefore.hash, "sidecars": damagedBefore.sidecars])
        }

        let workspaceCountBefore = privateReadWorkspaceCount()
        var library: SQLiteLibraryRepository? = SQLiteLibraryRepository(databaseURL: database, recoveryDirectory: recoveryDirectory)
        let initialItems = try await library!.listSavedItems()
        guard privateReadWorkspaceCount() == workspaceCountBefore + 1 else {
            throw CoreError.invalidResource("private read workspace was not created")
        }
        let afterSavedRead = try fileSnapshot(database)
        guard before == afterSavedRead else { throw CoreError.invalidResource("saved-item read changed the closed source") }
        guard initialItems.count == 4,
              initialItems.filter({ $0.kind == .bookmark }).count == 2,
              initialItems.filter({ $0.kind == .highlight }).count == 1,
              initialItems.filter({ $0.kind == .note }).count == 1,
              let noteItem = initialItems.first(where: { $0.kind == .note }),
              noteItem.noteText == "Synthetic migration fixture note.",
              initialItems.contains(where: { $0.kind == .bookmark && $0.bookCode == "JHN" && $0.chapter == 3 && $0.startVerse == "16" }) else {
            throw CoreError.invalidResource("saved rows did not match the fixture")
        }
        guard let translation = TranslationID(rawValue: noteItem.translationID) else {
            throw CoreError.invalidIdentity("saved note translation")
        }
        let passageID = try PassageID(translationID: translation,
            bookCode: BookCode(noteItem.bookCode), chapter: noteItem.chapter,
            startVerse: VerseLabel(noteItem.startVerse), endVerse: VerseLabel(noteItem.endVerse))
        let bible = BundledBibleRepository(roots: roots)
        let selection = try await bible.passage(id: passageID, startIndex: noteItem.startIndex, endIndex: noteItem.endIndex)
        let beforeNote = try await library!.note(for: passageID)
        let updatedNote = "L04 repository runner note update"
        try await library!.saveNote(selection, text: updatedNote)
        guard privateReadWorkspaceCount() == workspaceCountBefore else {
            throw CoreError.invalidResource("private read workspace was not removed before write")
        }
        let afterNote = try await library!.note(for: passageID)
        guard beforeNote != updatedNote, afterNote == updatedNote else {
            throw CoreError.invalidResource("note read after write did not return the new value")
        }
        let backupFiles = (try? FileManager.default.contentsOfDirectory(atPath: recoveryDirectory.path)) ?? []
        guard let backupName = backupFiles.first(where: { $0.hasPrefix("library-") && $0.hasSuffix(".sqlite") }) else {
            throw CoreError.failedBackup("a validated pre-write backup was not created")
        }
        let backupURL = recoveryDirectory.appendingPathComponent(backupName)
        let backupSummary = try await SQLiteLibraryBoundary(databaseURL: backupURL).inspect()
        let backupRepository = SQLiteLibraryRepository(databaseURL: backupURL,
            recoveryDirectory: recoveryDirectory.appendingPathComponent("backup-read"))
        let backupNote = try await backupRepository.note(for: passageID)
        let backupItems = try await backupRepository.listSavedItems()
        guard backupSummary.schemaVersion == 1, backupSummary.bookmarkCount == 2,
              backupSummary.highlightCount == 1, backupSummary.noteCount == 1, backupNote == beforeNote,
              backupItems == initialItems else {
            throw CoreError.failedBackup("pre-write backup validation failed")
        }
        library = nil
        for _ in 0..<20 where privateReadWorkspaceCount() != workspaceCountBefore { await Task.yield() }
        guard privateReadWorkspaceCount() == workspaceCountBefore else {
            throw CoreError.invalidResource("private read workspace was not removed after repository release")
        }
        checks.append(["name": "readSaveReadAndBackup", "passed": true,
                       "oldNotePresent": true, "newNoteReadBack": true,
                       "backupSchema": backupSummary.schemaVersion, "backupNotes": backupSummary.noteCount,
                       "backupOriginalNoteMatched": true, "privateWorkspaceCleanup": true,
                       "backupFiles": backupFiles.sorted()])
        checks.append(try await rotationChecks(roots: roots, fixtureURL: rotationFixtureURL))
        checks.append(contentsOf: try await repositoryChecks(roots: roots, fixtureURL: bibleFixtureURL))
        checks.append(contentsOf: try await syntheticWorksChecks(sourceRoots: roots, outputRoot: outputRoot))

        let sqliteProbe = SQLiteOpenProbe.runLibraryReadTransaction(url: backupURL)
        let expectedProbeValues: [[String]] = [["1"], ["ok"], ["2"], ["1"], ["1"]]
        guard sqliteProbe.openResult == 0, sqliteProbe.beginResult == 0,
              sqliteProbe.commitResult == 0, sqliteProbe.closeResult == 0,
              sqliteProbe.statements.count == 5,
              zip(sqliteProbe.statements, expectedProbeValues).allSatisfy({ pair in
                  pair.0.prepareResult == SQLITE_OK && pair.0.stepResults.last == SQLITE_DONE &&
                  pair.0.finalizeResult == SQLITE_OK && pair.0.values == pair.1
              }) else {
            throw CoreError.sqlite(code: sqliteProbe.openResult == 0 ? -1 : sqliteProbe.openResult,
                                   message: "runtime read transaction did not validate backup contents")
        }
        let result: [String: Any] = [
            "formatVersion": 1,
            "runtimeBehaviorObserved": true,
            "checks": checks,
            "runtime": ["sqliteVersion": sqliteProbe.sqliteVersion,
                        "sqliteProbeCloseStatus": sqliteProbe.closeResult,
                        "zlibVersion": String(cString: zlibVersion())],
        ]
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: outputURL, options: .atomic)
    }

    private struct FileState: Equatable {
        let hash: String
        let sidecars: [String]
    }

    private static func fileSnapshot(_ url: URL) throws -> FileState {
        let bytes = try Data(contentsOf: url)
        let sidecars = try ["-wal", "-shm", "-journal"].compactMap { suffix -> String? in
            let sidecarURL = URL(fileURLWithPath: url.path + suffix)
            guard FileManager.default.fileExists(atPath: sidecarURL.path) else { return nil }
            let sidecar = try Data(contentsOf: sidecarURL)
            let digest = SHA256.hash(data: sidecar).map { String(format: "%02x", $0) }.joined()
            return "\(suffix):\(sidecar.count):\(digest)"
        }
        return FileState(hash: SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(), sidecars: sidecars)
    }

    private static func privateReadWorkspaceCount() -> Int {
        ((try? FileManager.default.contentsOfDirectory(atPath: FileManager.default.temporaryDirectory.path)) ?? [])
            .filter { $0.hasPrefix("JohnLibraryRead-") }.count
    }

    private static func rotationChecks(roots: ResourceRoots, fixtureURL: URL) async throws -> [String: Any] {
        let fixture = try JSONDecoder().decode(RotationFixture.self, from: Data(contentsOf: fixtureURL))
        guard fixture.outputs.count == 792 else { throw CoreError.invalidResource("rotation fixture must contain exactly 792 rows") }
        let appRepository = IndexedRotationRepository(roots: roots, resourceRoot: .app)
        let widgetRepository = IndexedRotationRepository(roots: roots, resourceRoot: .widget)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for row in fixture.outputs {
            guard let edition = TranslationID(rawValue: row.editionId), let instant = formatter.date(from: row.instant),
                  let expectedBoundary = formatter.date(from: row.nextRotationInstant) else {
                throw CoreError.invalidResource("rotation fixture row cannot be decoded")
            }
            let actualCount = try await appRepository.poolCount(translation: edition, scope: row.scope)
            guard actualCount == row.poolCount else { throw CoreError.invalidResource("rotation pool count mismatch") }
            let appVerse = try await appRepository.verse(translation: edition, scope: row.scope, at: row.poolIndex)
            let widgetVerse = try await widgetRepository.verse(translation: edition, scope: row.scope, at: row.poolIndex)
            let offsetSeconds = -row.timezoneOffsetMinutes * 60
            let slot = try RotationMath.slot(at: instant, utcOffsetSeconds: offsetSeconds, intervalMinutes: row.cadenceMinutes)
            let index = try RotationMath.index(for: slot, count: row.poolCount)
            let boundary = try RotationMath.nextBoundary(after: instant, utcOffsetSeconds: offsetSeconds, intervalMinutes: row.cadenceMinutes)
            guard appVerse == widgetVerse, appVerse.reference == row.verse.ref,
                  appVerse.bookCode == row.verse.book, appVerse.chapter == row.verse.chapter,
                  appVerse.verseLabel == row.verse.verse, appVerse.text == row.verse.text,
                  slot == row.localSlot, index == row.poolIndex,
                  abs(boundary.timeIntervalSince(expectedBoundary)) <= 0.0005 else {
                throw CoreError.invalidResource("rotation source parity failed for \(row.editionId)/\(row.scope.rawValue)/\(row.cadenceMinutes)/\(row.timezone)")
            }
        }
        return ["name": "rotationAppWidgetAndMath", "passed": true,
                "rows": fixture.outputs.count, "editions": 3, "scopes": 3, "appWidgetRecordsMatch": true]
    }

    private static func repositoryChecks(roots: ResourceRoots, fixtureURL: URL) async throws -> [[String: Any]] {
        let bible = BundledBibleRepository(roots: roots)
        let expected = try JSONDecoder().decode(BibleFixture.self, from: Data(contentsOf: fixtureURL))
        guard expected.outputs.count == 9 else { throw CoreError.invalidResource("Bible source fixture must contain nine cases") }
        var bibleRows = 0
        for row in expected.outputs {
            guard let translation = TranslationID(rawValue: row.edition) else { throw CoreError.invalidResource("Bible fixture edition") }
            let descriptor = try await bible.manifest(for: translation).first { $0.code == row.book.code }
            guard let descriptor, descriptor.name == row.book.name, descriptor.order == row.book.order else {
                throw CoreError.invalidResource("Bible book manifest differs from source fixture")
            }
            let chapter = try await bible.chapter(translation: translation, book: BookCode(row.book.code), chapter: row.chapter.number)
            guard chapter == row.chapter else { throw CoreError.invalidResource("Bible chapter differs from source fixture") }
            let passageID = try PassageID(translationID: translation, bookCode: BookCode(row.book.code),
                chapter: row.chapter.number, startVerse: VerseLabel(row.passage.startVerse), endVerse: VerseLabel(row.passage.endVerse))
            let passage = try await bible.passage(id: passageID, startIndex: row.passage.startIndex, endIndex: row.passage.endIndex)
            guard passage.bookName == row.book.name, passage.bookOrder == row.book.order,
                  passage.scriptureText == row.passage.scriptureText,
                  passage.verses.map(\.verse.rawValue) == row.passage.verses.map(\.verse),
                  passage.verses.map(\.index) == row.passage.verses.map(\.index),
                  passage.verses.map(\.text) == row.passage.verses.map(\.text) else {
                throw CoreError.invalidResource("Bible passage differs from source fixture")
            }
            bibleRows += 1
        }

        let works = SQLiteWorksRepository(roots: roots)
        let catalog = try await works.catalog()
        guard let work = catalog.works.first(where: { $0.sectionCount > 0 }),
              let section = try? await works.section(workID: work.id, index: 0), !section.paragraphs.isEmpty else {
            throw CoreError.invalidResource("Works real BLOB sample did not decode")
        }
        var checks: [[String: Any]] = [["name": "bibleChapterAndPassageParity", "passed": true,
                                         "editions": TranslationID.allCases.count, "sampleChapters": bibleRows],
                                       ["name": "worksRealSection", "passed": true,
                                        "workID": work.id, "section": section.index,
                                        "paragraphs": section.paragraphs.count, "characters": section.paragraphs.reduce(0) { $0 + $1.utf16.count }]]
        for missing in [("__missing_l04_work__", 0), (work.id, Int.max)] {
            do {
                _ = try await works.section(workID: missing.0, index: missing.1)
                throw CoreError.invalidResource("Works missing or out-of-range request unexpectedly succeeded")
            } catch CoreError.missingSection { }
            catch CoreError.invalidIdentity { }
        }
        checks.append(["name": "worksMissingBounds", "passed": true, "cases": 2])
        return checks
    }

    private static func syntheticWorksChecks(sourceRoots: ResourceRoots, outputRoot: URL) async throws -> [[String: Any]] {
        let appRoot = outputRoot.appendingPathComponent("works-synthetic/App", isDirectory: true)
        let catalogs = appRoot.appendingPathComponent("Catalogs", isDirectory: true)
        let databases = appRoot.appendingPathComponent("Databases", isDirectory: true)
        try FileManager.default.createDirectory(at: catalogs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: databases, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: try sourceRoots.appResource("Catalogs", "works-catalog.json"),
                                         to: catalogs.appendingPathComponent("works-catalog.json"))
        let databaseURL = databases.appendingPathComponent("works.db")
        try createSyntheticWorksDatabase(at: databaseURL)
        let repository = SQLiteWorksRepository(roots: ResourceRoots(app: appRoot))
        let blob = try await repository.section(workID: "fixture", index: 0)
        let text = try await repository.section(workID: "fixture", index: 1)
        guard blob.paragraphs == ["zlib fixture section"], text.paragraphs == ["text fixture section"] else {
            throw CoreError.invalidResource("Works BLOB or TEXT fixture did not decode")
        }
        do {
            _ = try await repository.section(workID: "fixture", index: 2)
            throw CoreError.invalidResource("invalid Works TEXT unexpectedly decoded")
        } catch CoreError.damagedSection { }
        do {
            _ = try await repository.section(workID: "fixture", index: 3)
            throw CoreError.invalidResource("oversized Works TEXT unexpectedly decoded")
        } catch CoreError.oversizedContent(let limit) where limit == SQLiteWorksRepository.decodedSectionLimit { }
        do {
            _ = try await repository.section(workID: "fixture", index: 4)
            throw CoreError.invalidResource("invalid Works BLOB unexpectedly decoded")
        } catch CoreError.damagedSection { }
        do {
            _ = try await repository.section(workID: "fixture", index: 5)
            throw CoreError.invalidResource("missing Works section unexpectedly decoded")
        } catch CoreError.missingSection { }
        return [["name": "worksSyntheticRows", "passed": true, "validBlob": true,
                 "validText": true, "invalidText": true, "oversizedText": true,
                 "invalidBlob": true, "missing": true]]
    }

    private static func createSyntheticWorksDatabase(at url: URL) throws {
        var database: OpaquePointer?
        let openStatus = sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        guard openStatus == SQLITE_OK, let database else {
            throw CoreError.invalidResource("cannot create synthetic Works database")
        }
        defer { sqlite3_close(database) }
        let schema = """
        CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        INSERT INTO metadata VALUES ('schemaVersion', '2');
        INSERT INTO metadata VALUES ('paragraphEncoding', 'zlib-json');
        CREATE TABLE sections (work_id TEXT NOT NULL, idx INTEGER NOT NULL, title TEXT NOT NULL, words INTEGER NOT NULL, paragraphs BLOB NOT NULL, PRIMARY KEY(work_id, idx));
        """
        guard sqlite3_exec(database, schema, nil, nil, nil) == SQLITE_OK else {
            throw CoreError.invalidResource("cannot create synthetic Works schema")
        }
        let json = Data("[\"zlib fixture section\"]".utf8)
        var compressed = Data(count: Int(compressBound(uLong(json.count))))
        var compressedLength = uLongf(compressed.count)
        let compressionStatus = compressed.withUnsafeMutableBytes { destination in
            json.withUnsafeBytes { source in
                compress2(destination.baseAddress!.assumingMemoryBound(to: Bytef.self), &compressedLength,
                          source.baseAddress!.assumingMemoryBound(to: Bytef.self), uLong(json.count), Z_BEST_COMPRESSION)
            }
        }
        guard compressionStatus == Z_OK else { throw CoreError.invalidResource("cannot compress synthetic Works BLOB") }
        compressed.count = Int(compressedLength)
        var statement: OpaquePointer?
        let sql = "INSERT INTO sections(work_id,idx,title,words,paragraphs) VALUES('fixture',?,'fixture',1,?)"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw CoreError.invalidResource("cannot prepare synthetic Works insert")
        }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        func insert(_ index: Int32, bytes: Data, columnType: Int32) throws {
            guard sqlite3_reset(statement) == SQLITE_OK else { throw CoreError.invalidResource("cannot reset synthetic Works insert") }
            sqlite3_clear_bindings(statement)
            guard sqlite3_bind_int(statement, 1, index) == SQLITE_OK else { throw CoreError.invalidResource("cannot bind Works index") }
            let bindStatus = bytes.withUnsafeBytes { source -> Int32 in
                if columnType == SQLITE_TEXT {
                    return sqlite3_bind_text(statement, 2, source.baseAddress!.assumingMemoryBound(to: CChar.self), Int32(bytes.count), transient)
                }
                return sqlite3_bind_blob(statement, 2, source.baseAddress!, Int32(bytes.count), transient)
            }
            guard bindStatus == SQLITE_OK, sqlite3_step(statement) == SQLITE_DONE else {
                throw CoreError.invalidResource("cannot insert synthetic Works row")
            }
        }
        try insert(0, bytes: compressed, columnType: SQLITE_BLOB)
        try insert(1, bytes: Data("[\"text fixture section\"]".utf8), columnType: SQLITE_TEXT)
        try insert(2, bytes: Data("not-json".utf8), columnType: SQLITE_TEXT)
        try insert(3, bytes: Data(repeating: 0x20, count: SQLiteWorksRepository.decodedSectionLimit + 1), columnType: SQLITE_TEXT)
        try insert(4, bytes: Data([0x78, 0x9c, 0x00]), columnType: SQLITE_BLOB)
    }
}
#endif
