#if DEBUG
import CryptoKit
import Foundation
import JohnCore

/// A bounded scenario runner for the main app target. The caller owns the MMKV adapter.
public enum L04ScenarioRunner {
    private struct ExpectedReaderLocation: Decodable {
        let bookCode: String
        let chapter: Int
        let scrollY: Double
        let updatedAt: Int64
    }

    private struct ExpectedState: Decodable {
        let themeScheme: String
        let translationID: String
        let rotationIntervalMinutes: Int
        let verseScope: RotationScope
        let readerLocation: ExpectedReaderLocation
        let readingPreferences: ReadingPreferences
        let widgetGuideDismissed: Bool
        let selectionHintDismissed: Bool
        let reflections: [String: SundayReflection]
        let favoritePrayerIDs: [String]
        let calendarNotifications: CalendarNotificationSettings
        let rosaryReminder: RosaryReminderSettings
        let worksPositions: [String: WorkReadingPosition]
        let novenaProgress: [String: NovenaProgress]
    }

    public enum Scenario: String, CaseIterable, Sendable {
        case validLegacyImport
        case invalidLegacyField
        case concurrentStartupAndMutation
        case freshInstall
        case freshBootstrapFailureThenRetry
        case missingLibraryWithState
        case unsupportedLibrary
        case damagedLibrary
        case damagedMMKVData
        case damagedMMKVCRC
        case wrongMMKVCRC
        case backupFailureThenRetry
        case afterRenameFailure
    }

    public struct Result: Codable, Sendable {
        public let scenario: String
        public let passed: Bool
        public let revision: Int64?
        public let translationID: String?
        public let themeScheme: String?
        public let textSize: String?
        public let libraryCapability: String?
        public let nativeStateCapability: String?
        public let library: LibrarySchemaSummary?
        public let sourceHashes: [String: String]
        public let details: [String: String]
    }

    public typealias ReaderFactory = @Sendable (URL) -> any LegacyMMKVReading

    private final class CheckpointRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [String] = []
        func append(_ checkpoint: NativeImportCheckpoint) {
            lock.lock(); values.append(checkpoint.rawValue); lock.unlock()
        }
        func snapshot() -> [String] {
            lock.lock(); defer { lock.unlock() }; return values
        }
    }

    /// Run one bounded scenario and write a result for success or a thrown error.
    /// A process crash cannot write a result; Main must record process status separately.
    @discardableResult
    public static func runRecording(
        _ scenario: Scenario,
        fixtureRoot: URL,
        outputRoot: URL,
        roots: ResourceRoots,
        legacyReaderFactory: ReaderFactory,
        checkpoint: (@Sendable (NativeImportCheckpoint) -> Void)? = nil,
        failureInjector: (@Sendable (NativeStateFailurePoint) -> Bool)? = nil
    ) async throws -> Result {
        guard !FileManager.default.fileExists(atPath: outputRoot.path) else {
            throw CoreError.invalidResource("scenario output path already exists")
        }
        let inputPath = fixtureRoot.standardizedFileURL.resolvingSymlinksInPath()
        let outputPath = outputRoot.standardizedFileURL.resolvingSymlinksInPath()
        guard !isWithin(outputPath, root: inputPath) && !isWithin(inputPath, root: outputPath) else {
            throw CoreError.invalidResource("scenario output and fixture input paths must not overlap")
        }
        let recorder = CheckpointRecorder()
        let recordingCheckpoint: @Sendable (NativeImportCheckpoint) -> Void = { checkpointValue in
            recorder.append(checkpointValue)
            checkpoint?(checkpointValue)
        }
        do {
            let result = try await run(scenario, fixtureRoot: fixtureRoot, outputRoot: outputRoot,
                                       roots: roots, legacyReaderFactory: legacyReaderFactory,
                                       checkpoint: recordingCheckpoint, failureInjector: failureInjector)
            var details = result.details
            details["checkpoints"] = recorder.snapshot().joined(separator: ",")
            let recorded = Result(scenario: result.scenario, passed: result.passed,
                                  revision: result.revision, translationID: result.translationID,
                                  themeScheme: result.themeScheme, textSize: result.textSize,
                                  libraryCapability: result.libraryCapability,
                                  nativeStateCapability: result.nativeStateCapability,
                                  library: result.library, sourceHashes: result.sourceHashes, details: details)
            try write(recorded, to: outputRoot)
            return recorded
        } catch {
            try? FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
            let manifest = fixtureRoot.appendingPathComponent("fixture-manifest.json")
            let hashes = hashIfPresent(manifest).map { ["fixture-manifest.json": $0] } ?? [:]
            let details = [
                "stage": recorder.snapshot().last.map { "after checkpoint \($0)" } ?? "before first checkpoint",
                "checkpoints": recorder.snapshot().joined(separator: ","),
                "error": String(describing: error),
            ]
            let result = Result(scenario: scenario.rawValue, passed: false, revision: nil,
                                translationID: nil, themeScheme: nil, textSize: nil,
                                libraryCapability: nil, nativeStateCapability: String(describing: error),
                                library: nil, sourceHashes: hashes, details: details)
            _ = try? write(result, to: outputRoot)
            return result
        }
    }

    /// Run one scenario. `outputRoot` must be a new directory. The input tree is read-only.
    public static func run(
        _ scenario: Scenario,
        fixtureRoot: URL,
        outputRoot: URL,
        roots: ResourceRoots,
        legacyReaderFactory: ReaderFactory,
        checkpoint: (@Sendable (NativeImportCheckpoint) -> Void)? = nil,
        failureInjector: (@Sendable (NativeStateFailurePoint) -> Bool)? = nil
    ) async throws -> Result {
        guard !FileManager.default.fileExists(atPath: outputRoot.path) else {
            throw CoreError.invalidResource("scenario output path already exists")
        }
        let inputRoot = fixtureRoot.standardizedFileURL.resolvingSymlinksInPath()
        let newOutputRoot = outputRoot.standardizedFileURL.resolvingSymlinksInPath()
        guard !Self.isWithin(newOutputRoot, root: inputRoot) && !Self.isWithin(inputRoot, root: newOutputRoot) else {
            throw CoreError.invalidResource("scenario output and fixture input paths must not overlap")
        }
        guard FileManager.default.fileExists(atPath: fixtureRoot.appendingPathComponent("fixture-manifest.json").path) else {
            throw CoreError.missingResource("L04 fixture manifest")
        }
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        let input = fixtureRoot.appendingPathComponent("input", isDirectory: true)
        let support = outputRoot.appendingPathComponent("Application Support", isDirectory: true)
        let libraryURL = outputRoot.appendingPathComponent("Documents/SQLite/user-library.db")
        let legacyRoot: URL?
        let shouldCopyLibrary: Bool
        switch scenario {
        case .validLegacyImport, .concurrentStartupAndMutation:
            legacyRoot = input.appendingPathComponent("legacy/mmkv", isDirectory: true)
            shouldCopyLibrary = true
        case .invalidLegacyField:
            legacyRoot = input.appendingPathComponent("invalid-legacy/mmkv", isDirectory: true)
            shouldCopyLibrary = false
        case .unsupportedLibrary:
            legacyRoot = nil
            shouldCopyLibrary = false
        case .damagedLibrary:
            legacyRoot = nil
            shouldCopyLibrary = false
        case .damagedMMKVData:
            legacyRoot = input.appendingPathComponent("mmkv-errors/truncated-data", isDirectory: true)
            shouldCopyLibrary = false
        case .damagedMMKVCRC:
            legacyRoot = input.appendingPathComponent("mmkv-errors/truncated-crc", isDirectory: true)
            shouldCopyLibrary = false
        case .wrongMMKVCRC:
            legacyRoot = input.appendingPathComponent("mmkv-errors/wrong-crc", isDirectory: true)
            shouldCopyLibrary = false
        case .backupFailureThenRetry:
            legacyRoot = nil
            shouldCopyLibrary = true
        case .afterRenameFailure:
            legacyRoot = nil
            shouldCopyLibrary = false
        case .freshInstall:
            legacyRoot = nil
            shouldCopyLibrary = false
        case .freshBootstrapFailureThenRetry, .missingLibraryWithState:
            legacyRoot = nil
            shouldCopyLibrary = false
        }

        if shouldCopyLibrary {
            try FileManager.default.createDirectory(at: libraryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: input.appendingPathComponent("library/user-library.db"), to: libraryURL)
            try FileManager.default.copyItem(at: input.appendingPathComponent("library/user-library.db-wal"), to: URL(fileURLWithPath: libraryURL.path + "-wal"))
        } else if scenario == .unsupportedLibrary || scenario == .damagedLibrary {
            let source = input.appendingPathComponent(scenario == .unsupportedLibrary
                ? "library-variants/unsupported-schema.db" : "library-variants/damaged-library.db")
            try FileManager.default.createDirectory(at: libraryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: source, to: libraryURL)
            let sidecarSuffixes = scenario == .damagedLibrary ? ["-wal", "-shm"] : ["-wal"]
            for suffix in sidecarSuffixes where FileManager.default.fileExists(atPath: source.path + suffix) {
                try FileManager.default.copyItem(atPath: source.path + suffix, toPath: libraryURL.path + suffix)
            }
        }

        if scenario == .freshBootstrapFailureThenRetry {
            try FileManager.default.createDirectory(at: libraryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("synthetic WAL obstruction".utf8).write(to: URL(fileURLWithPath: libraryURL.path + "-wal"))
        }

        let reader = legacyRoot.map(legacyReaderFactory)
        if scenario == .backupFailureThenRetry {
            let recoveryPath = support.appendingPathComponent("John/recovery", isDirectory: true)
            try FileManager.default.createDirectory(at: recoveryPath.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("synthetic obstruction".utf8).write(to: recoveryPath)
        }
        let store = NativeStateStore(applicationSupportURL: support, libraryURL: libraryURL,
                                      roots: roots, legacyReader: reader,
                                      checkpoint: checkpoint, failureInjector: failureInjector)
        var details: [String: String] = ["inputRoot": input.path, "outputRoot": outputRoot.path]
        var started: StartupState
        switch scenario {
        case .concurrentStartupAndMutation:
            async let first = store.loadOrImport()
            async let second = store.loadOrImport()
            let pair = await (first, second)
            let mutation = try await store.update(.setThemeScheme("light"))
            started = await store.loadOrImport()
            details["concurrentRevisions"] = "\(pair.0.revision ?? -1),\(pair.1.revision ?? -1)"
            details["mutationRevision"] = String(mutation.revision)
        case .afterRenameFailure:
            let baselineStore = NativeStateStore(applicationSupportURL: support, libraryURL: libraryURL,
                                                  roots: roots, legacyReader: nil,
                                                  checkpoint: checkpoint, failureInjector: nil)
            let baseline = await baselineStore.loadOrImport()
            details["baselineRevision"] = String(baseline.revision ?? -1)
            let injectedStore = NativeStateStore(applicationSupportURL: support, libraryURL: libraryURL,
                                                  roots: roots, legacyReader: nil,
                                                  checkpoint: checkpoint, failureInjector: failureInjector)
            _ = await injectedStore.loadOrImport()
            do {
                _ = try await injectedStore.update(.setThemeScheme("light"))
                details["injectedWrite"] = "unexpected-success"
            } catch {
                details["injectedWrite"] = "failed-as-requested"
            }
            do {
                _ = try await injectedStore.update(.setThemeScheme("ignored"))
                details["secondWrite"] = "unexpected-success"
            } catch {
                details["secondWrite"] = "blocked"
            }
            let blocked = await injectedStore.loadOrImport()
            details["blockedCapability"] = blocked.nativeStateCapability ?? "missing"
            let restarted = NativeStateStore(applicationSupportURL: support, libraryURL: libraryURL,
                                              roots: roots, legacyReader: nil,
                                              checkpoint: checkpoint, failureInjector: nil)
            started = await restarted.loadOrImport()
            details["restartRevision"] = String(started.revision ?? -1)
            details["restartTheme"] = started.state?.themeScheme ?? "missing"
        case .freshBootstrapFailureThenRetry:
            let failed = await store.loadOrImport()
            details["firstAttemptHasEnvelope"] = failed.envelope == nil ? "false" : "true"
            details["firstAttemptCapability"] = failed.libraryCapability ?? "none"
            details["primaryAfterFailure"] = FileManager.default.fileExists(atPath: support.appendingPathComponent("John/native-state-v1.json").path) ? "true" : "false"
            try FileManager.default.removeItem(at: URL(fileURLWithPath: libraryURL.path + "-wal"))
            started = await store.loadOrImport()
            details["retryLibraryCapability"] = started.libraryCapability ?? "none"
        case .missingLibraryWithState:
            _ = await store.loadOrImport()
            for suffix in ["", "-wal", "-shm"] where FileManager.default.fileExists(atPath: libraryURL.path + suffix) {
                try FileManager.default.removeItem(atPath: libraryURL.path + suffix)
            }
            let restarted = NativeStateStore(applicationSupportURL: support, libraryURL: libraryURL,
                                              roots: roots, legacyReader: nil,
                                              checkpoint: checkpoint, failureInjector: nil)
            started = await restarted.loadOrImport()
            details["libraryRecreated"] = FileManager.default.fileExists(atPath: libraryURL.path) ? "true" : "false"
        case .backupFailureThenRetry:
            started = await store.loadOrImport()
            details["firstAttemptCapability"] = started.nativeStateCapability ?? "missing"
            details["firstAttemptHasEnvelope"] = started.envelope == nil ? "false" : "true"
            details["primaryAfterFailure"] = FileManager.default.fileExists(atPath: support.appendingPathComponent("John/native-state-v1.json").path) ? "true" : "false"
            try FileManager.default.removeItem(at: support.appendingPathComponent("John/recovery"))
            let retryStore = NativeStateStore(applicationSupportURL: support, libraryURL: libraryURL,
                                               roots: roots, legacyReader: nil,
                                               checkpoint: checkpoint, failureInjector: failureInjector)
            started = await retryStore.loadOrImport()
            details["retryCapability"] = started.nativeStateCapability ?? "none"
            let recoveryDirectory = support.appendingPathComponent("John/recovery", isDirectory: true)
            let recoveryFiles = (try? FileManager.default.contentsOfDirectory(at: recoveryDirectory, includingPropertiesForKeys: nil)) ?? []
            if let backup = recoveryFiles.first(where: { $0.lastPathComponent.hasPrefix("library-import-") }),
               let summary = try? await SQLiteLibraryBoundary(databaseURL: backup).inspect() {
                details["validatedBackup"] = summary.schemaVersion == 1 && summary.bookmarkCount == 2
                    && summary.highlightCount == 1 && summary.noteCount == 1 ? "true" : "false"
            } else { details["validatedBackup"] = "false" }
        default:
            started = await store.loadOrImport()
        }

        if scenario == .freshInstall {
            let restartedStore = NativeStateStore(applicationSupportURL: support, libraryURL: libraryURL,
                                                  roots: roots, legacyReader: nil,
                                                  checkpoint: checkpoint, failureInjector: failureInjector)
            let relaunched = await restartedStore.loadOrImport()
            details["freshDatabaseExists"] = FileManager.default.fileExists(atPath: libraryURL.path) ? "true" : "false"
            details["relaunchRevision"] = String(relaunched.revision ?? -1)
            details["relaunchLibraryCapability"] = relaunched.libraryCapability ?? "none"
        }

        var librarySummary: LibrarySchemaSummary?
        if FileManager.default.fileExists(atPath: libraryURL.path) {
            do {
                librarySummary = try await SQLiteLibraryBoundary(databaseURL: libraryURL).inspect()
                if let librarySummary {
                    details["postRunLibraryInspect"] = "ok schema=\(librarySummary.schemaVersion) bookmarks=\(librarySummary.bookmarkCount) highlights=\(librarySummary.highlightCount) notes=\(librarySummary.noteCount)"
                }
            } catch {
                details["postRunLibraryInspect"] = "failed: \(error)"
            }
        } else {
            details["postRunLibraryInspect"] = "library path does not exist"
        }
        var libraryItems: [SavedItem] = []
        if scenario == .validLegacyImport {
            let repository = SQLiteLibraryRepository(databaseURL: libraryURL,
                recoveryDirectory: support.appendingPathComponent("John/recovery", isDirectory: true))
            libraryItems = (try? await repository.listSavedItems()) ?? []
        }
        var hashes = hashTree(legacyRoot)
        hashes["fixture-manifest.json"] = hashIfPresent(fixtureRoot.appendingPathComponent("fixture-manifest.json"))
        hashes["library.db"] = hashIfPresent(libraryURL)
        hashes["library.wal"] = hashIfPresent(URL(fileURLWithPath: libraryURL.path + "-wal"))
        let state = started.state
        var passed = false
        switch scenario {
        case .validLegacyImport:
            let expectedURL = fixtureRoot.appendingPathComponent("expected-state.json")
            let expected = (try? Data(contentsOf: expectedURL)).flatMap { try? JSONDecoder().decode(ExpectedState.self, from: $0) }
            let locationMatches = state?.readerLocation.map {
                $0.bookCode.rawValue == expected?.readerLocation.bookCode
                    && $0.chapter == expected?.readerLocation.chapter
                    && $0.scrollY == expected?.readerLocation.scrollY
                    && $0.updatedAt == expected?.readerLocation.updatedAt
            } ?? false
            let fullStateMatches = if let state, let expected {
                locationMatches
                    && state.themeScheme == expected.themeScheme
                    && state.translationID == expected.translationID
                    && state.rotationIntervalMinutes == expected.rotationIntervalMinutes
                    && state.verseScope == expected.verseScope
                    && state.readingPreferences == expected.readingPreferences
                    && state.widgetGuideDismissed == expected.widgetGuideDismissed
                    && state.selectionHintDismissed == expected.selectionHintDismissed
                    && state.reflections == expected.reflections
                    && state.favoritePrayerIDs == expected.favoritePrayerIDs
                    && state.calendarNotifications == expected.calendarNotifications
                    && state.rosaryReminder == expected.rosaryReminder
                    && state.worksPositions == expected.worksPositions
                    && state.novenaProgress == expected.novenaProgress
            } else { false }
            passed = fullStateMatches
                && !(started.envelope?.issues.contains("l04.unknown.preserved") ?? true)
                && librarySummary?.bookmarkCount == 2 && librarySummary?.highlightCount == 1
                && librarySummary?.noteCount == 1
                && libraryItems.contains(where: { $0.id == "bookmark:web-ce:JHN:3:16:16" && $0.scriptureText == "For God so loved the world." })
                && libraryItems.contains(where: { $0.id == "note:web-ce:JHN:1:1:1" && $0.noteText == "Synthetic migration fixture note." })
                && libraryItems.contains(where: { $0.kind == .highlight && $0.highlightVerses?.first?.verseText == "In the beginning." })
        case .invalidLegacyField:
            passed = state?.readingPreferences.textSize == .medium
                && (started.envelope?.issues.contains("bible.reader.textSize") ?? false)
        case .concurrentStartupAndMutation:
            passed = state?.themeScheme == "light" && started.revision == 2
                && details["concurrentRevisions"] == "1,1"
        case .freshInstall:
            passed = state != nil && librarySummary?.schemaVersion == 1 && librarySummary?.bookmarkCount == 0
                && details["freshDatabaseExists"] == "true"
                && details["relaunchRevision"] == String(started.revision ?? -2)
                && details["relaunchLibraryCapability"] == "none"
        case .freshBootstrapFailureThenRetry:
            passed = details["firstAttemptHasEnvelope"] == "false"
                && details["firstAttemptCapability"] != "none"
                && details["primaryAfterFailure"] == "false"
                && started.envelope != nil && started.revision == 1
                && started.libraryCapability == nil
                && librarySummary?.schemaVersion == 1
        case .missingLibraryWithState:
            passed = started.envelope != nil && started.libraryCapability != nil
                && details["libraryRecreated"] == "false"
        case .unsupportedLibrary:
            passed = state != nil && started.libraryCapability?.contains("unsupportedSchema(77)") == true
        case .damagedLibrary:
            passed = state != nil && started.libraryCapability != nil
        case .damagedMMKVData, .damagedMMKVCRC, .wrongMMKVCRC:
            passed = state == nil && started.nativeStateCapability != nil
        case .backupFailureThenRetry:
            passed = details["firstAttemptCapability"]?.contains("failedBackup") == true
                && details["firstAttemptHasEnvelope"] == "false"
                && details["primaryAfterFailure"] == "false"
                && started.envelope != nil && started.libraryCapability == nil
                && details["validatedBackup"] == "true"
        case .afterRenameFailure:
            passed = details["injectedWrite"] == "failed-as-requested"
                && details["secondWrite"] == "blocked"
                && details["baselineRevision"] == "1"
                && details["restartRevision"] == "2" && details["restartTheme"] == "light"
        }
        return Result(scenario: scenario.rawValue, passed: passed, revision: started.revision,
                      translationID: state?.translationID, themeScheme: state?.themeScheme,
                      textSize: state?.readingPreferences.textSize.rawValue,
                      libraryCapability: started.libraryCapability,
                      nativeStateCapability: started.nativeStateCapability,
                      library: librarySummary, sourceHashes: hashes, details: details)
    }

    /// Write the JSON result in a new directory. The function returns the result for a UI summary.
    @discardableResult
    public static func write(_ result: Result, to outputRoot: URL) throws -> URL {
        let url = outputRoot.appendingPathComponent("scenario-result.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(result).write(to: url, options: .atomic)
        return url
    }

    private static func hashTree(_ root: URL?) -> [String: String] {
        guard let root, let files = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return [:] }
        return Dictionary(uniqueKeysWithValues: files.filter { !$0.hasDirectoryPath }.compactMap { file in
            guard let hash = hashIfPresent(file) else { return nil }
            return (file.lastPathComponent, hash)
        })
    }

    private static func hashIfPresent(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func isWithin(_ candidate: URL, root: URL) -> Bool {
        let candidatePath = candidate.path.hasSuffix("/") ? candidate.path : candidate.path + "/"
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return candidate == root || candidatePath.hasPrefix(rootPath)
    }
}
#endif
