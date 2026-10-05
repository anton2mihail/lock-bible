import Foundation
import Darwin
import CoreFoundation

public actor NativeStateStore {
    private enum ExistingEnvelope {
        case missing
        case valid(NativeStateEnvelope)
        case unsupported(String)
        case damaged(String)
    }

    private let stateDirectory: URL
    private let primaryURL: URL
    private let previousURL: URL
    private let libraryURL: URL
    private let roots: ResourceRoots
    private let library: SQLiteLibraryBoundary
    private let legacyReader: (any LegacyMMKVReading)?
    private var committedEnvelope: NativeStateEnvelope?
    private var libraryCapability: String?
    private var primaryNeedsPreservation = false
    private var startupTask: Task<StartupState, Never>?
    private var stateWriteBlocked = false
    #if DEBUG
    private let checkpoint: (@Sendable (NativeImportCheckpoint) -> Void)?
    private let failureInjector: (@Sendable (NativeStateFailurePoint) -> Bool)?
    #endif

    #if DEBUG
    public init(applicationSupportURL: URL, libraryURL: URL, roots: ResourceRoots,
                legacyReader: (any LegacyMMKVReading)?,
                checkpoint: (@Sendable (NativeImportCheckpoint) -> Void)? = nil,
                failureInjector: (@Sendable (NativeStateFailurePoint) -> Bool)? = nil) {
        self.stateDirectory = applicationSupportURL.appendingPathComponent("John", isDirectory: true)
        self.primaryURL = self.stateDirectory.appendingPathComponent("native-state-v1.json")
        self.previousURL = self.stateDirectory.appendingPathComponent("native-state-v1.previous.json")
        self.libraryURL = libraryURL.standardizedFileURL
        self.roots = roots
        self.library = SQLiteLibraryBoundary(databaseURL: libraryURL, checkpoint: checkpoint)
        self.legacyReader = legacyReader
        self.checkpoint = checkpoint
        self.failureInjector = failureInjector
    }
    #else
    public init(applicationSupportURL: URL, libraryURL: URL, roots: ResourceRoots,
                legacyReader: (any LegacyMMKVReading)?) {
        self.stateDirectory = applicationSupportURL.appendingPathComponent("John", isDirectory: true)
        self.primaryURL = self.stateDirectory.appendingPathComponent("native-state-v1.json")
        self.previousURL = self.stateDirectory.appendingPathComponent("native-state-v1.previous.json")
        self.libraryURL = libraryURL.standardizedFileURL
        self.roots = roots
        self.library = SQLiteLibraryBoundary(databaseURL: libraryURL)
        self.legacyReader = legacyReader
    }
    #endif

    /// Return persistent state only after a valid envelope is read or the first envelope is durable.
    public func loadOrImport() async -> StartupState {
        if let startupTask { return await startupTask.value }
        if let committedEnvelope {
            return StartupState(envelope: committedEnvelope, libraryCapability: libraryCapability,
                                nativeStateCapability: stateWriteBlocked ? "A previous state write has an uncertain result. Restart the app before you change saved state." : nil)
        }
        let task = Task { await self.performLoadOrImport() }
        startupTask = task
        let result = await task.value
        startupTask = nil
        return result
    }

    private func performLoadOrImport() async -> StartupState {
        if let committedEnvelope { return StartupState(envelope: committedEnvelope, libraryCapability: libraryCapability) }

        let primary = readEnvelope(primaryURL)
        switch primary {
        case let .valid(envelope):
            committedEnvelope = envelope
            libraryCapability = await inspectLibrary(allowCreate: false)
            return StartupState(envelope: committedEnvelope, libraryCapability: libraryCapability)
        case let .unsupported(message):
            return StartupState(envelope: nil, libraryCapability: await inspectLibrary(allowCreate: false), nativeStateCapability: message)
        case let .damaged(primaryMessage):
            switch readEnvelope(previousURL) {
            case let .valid(envelope):
                primaryNeedsPreservation = true
                committedEnvelope = envelope
                libraryCapability = await inspectLibrary(allowCreate: false)
                return StartupState(envelope: committedEnvelope, libraryCapability: libraryCapability,
                                    nativeStateCapability: "The primary state file is damaged. The previous valid state is active.")
            case .missing:
                return StartupState(envelope: nil, libraryCapability: await inspectLibrary(allowCreate: false),
                                    nativeStateCapability: "State recovery failed: \(primaryMessage)")
            case .unsupported, .damaged:
                return StartupState(envelope: nil, libraryCapability: await inspectLibrary(allowCreate: false),
                                    nativeStateCapability: "State recovery failed. The existing state files remain unchanged.")
            }
        case .missing:
            let previous = readEnvelope(previousURL)
            switch previous {
            case let .valid(envelope):
                committedEnvelope = envelope
                libraryCapability = await inspectLibrary(allowCreate: false)
                return StartupState(envelope: committedEnvelope, libraryCapability: libraryCapability,
                                    nativeStateCapability: "The primary state file is missing. The previous valid state is active.")
            case .unsupported, .damaged:
                return StartupState(envelope: nil, libraryCapability: await inspectLibrary(allowCreate: false),
                                    nativeStateCapability: "State recovery failed. The previous state file remains unchanged.")
            case .missing:
                break
            }
        }

        do {
            let libraryExistedAtStart = FileManager.default.fileExists(atPath: libraryURL.path)
            let novenaIDs = try loadNovenaIDs()
            #if DEBUG
            checkpoint?(.beforeStaging)
            #endif
            let requiredKeys = LegacyStateNormalizer.knownKeys(legacyKeys: [], novenaIDs: novenaIDs)
            let snapshot = try await legacyReader?.readKnownValues(requiredKeys)
            // Actor calls can suspend. Another startup may have committed while the adapter read.
            if let committedEnvelope { return StartupState(envelope: committedEnvelope, libraryCapability: libraryCapability) }
            // A legacy MMKV snapshot proves this is an update, not a fresh install.
            // Never replace a missing former library with an empty schema.
            libraryCapability = await inspectLibrary(allowCreate: snapshot == nil)
            if let committedEnvelope { return StartupState(envelope: committedEnvelope, libraryCapability: libraryCapability) }
            // A fresh install is complete only when both the first library and state file are ready.
            // If schema publication fails, leave no envelope so a later launch can retry creation.
            if !libraryExistedAtStart, snapshot == nil, let libraryCapability {
                throw CoreError.unreadableLibrary("fresh library setup failed: \(libraryCapability)")
            }
            if libraryExistedAtStart, libraryCapability == nil {
                do { try await preserveExistingLibraryBeforeImport() }
                catch {
                    libraryCapability = String(describing: error)
                    throw error
                }
            }
            let normalized = LegacyStateNormalizer.normalize(snapshot: snapshot, novenaIDs: novenaIDs)
            let envelope = NativeStateEnvelope(revision: 1, importVersion: 1,
                importSourceHashes: snapshot?.sourceHashes ?? [:], state: normalized.state,
                issues: normalized.issues)
            #if DEBUG
            checkpoint?(.beforeDurableCommit)
            #endif
            try durableCommit(envelope, preserving: nil)
            #if DEBUG
            checkpoint?(.afterDurableCommit)
            #endif
            committedEnvelope = envelope
            return StartupState(envelope: envelope, libraryCapability: libraryCapability)
        } catch let error as CoreError {
            return StartupState(envelope: nil, libraryCapability: libraryCapability,
                                nativeStateCapability: "Native state import failed: \(error)")
        } catch {
            return StartupState(envelope: nil, libraryCapability: libraryCapability,
                                nativeStateCapability: "Native state import failed.")
        }
    }

    public func currentState() async -> StartupState {
        await loadOrImport()
    }

    /// Apply one action to the actor's latest state. Do not pass a whole UI snapshot.
    public func update(_ mutation: NativeStateMutation) async throws -> NativeStateEnvelope {
        _ = await loadOrImport()
        guard !stateWriteBlocked else { throw CoreError.failedNativeStateWrite("state commit result is uncertain; restart is required") }
        guard let current = committedEnvelope else { throw CoreError.unrecoverableNativeState("no committed state is available") }
        guard current.revision < Int64.max else { throw CoreError.failedNativeStateWrite("revision is out of range") }
        if primaryNeedsPreservation {
            try preserveDamagedPrimary()
            primaryNeedsPreservation = false
        }
        var nextState = current.state
        nextState.apply(mutation)
        let next = NativeStateEnvelope(revision: current.revision + 1, importVersion: current.importVersion,
            importSourceHashes: current.importSourceHashes, state: nextState, issues: current.issues)
        var primaryWasReplaced = false
        do { try durableCommit(next, preserving: current, afterPrimaryRename: { primaryWasReplaced = true }) }
        catch {
            if primaryWasReplaced { stateWriteBlocked = true }
            throw CoreError.failedNativeStateWrite(String(describing: error))
        }
        committedEnvelope = next
        return next
    }

    private func inspectLibrary(allowCreate: Bool) async -> String? {
        do {
            if allowCreate { _ = try await library.prepareForStartup(allowCreate: true) }
            else { _ = try await library.inspect() }
            return nil
        }
        catch let error as CoreError { return String(describing: error) }
        catch { return "Library is not available." }
    }

    private func preserveExistingLibraryBeforeImport() async throws {
#if DEBUG
        NSLog("[JohnCoreImport] stage=source-summary-begin")
#endif
        let sourceSummary: LibrarySchemaSummary
        do { sourceSummary = try await library.inspect() }
        catch {
#if DEBUG
            NSLog("[JohnCoreImport] stage=source-summary-failed")
#endif
            throw error
        }
#if DEBUG
        NSLog("[JohnCoreImport] stage=source-summary-complete")
#endif
        let recoveryDirectory = stateDirectory.appendingPathComponent("recovery", isDirectory: true)
        do { try FileManager.default.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true) }
        catch { throw CoreError.failedBackup("recovery directory cannot be created") }
        try Self.syncDirectory(stateDirectory, failure: "recovery directory entry cannot be synced")
        let backupURL = recoveryDirectory.appendingPathComponent("library-import-\(UUID().uuidString).sqlite")
#if DEBUG
        NSLog("[JohnCoreImport] stage=backup-create-begin")
#endif
        do { try await library.makeConsistentBackup(to: backupURL) }
        catch {
#if DEBUG
            NSLog("[JohnCoreImport] stage=backup-create-failed")
#endif
            throw error
        }
#if DEBUG
        NSLog("[JohnCoreImport] stage=backup-create-complete")
        NSLog("[JohnCoreImport] stage=backup-summary-begin")
#endif
        let backupSummary: LibrarySchemaSummary
        do { backupSummary = try await SQLiteLibraryBoundary(databaseURL: backupURL).inspect() }
        catch {
#if DEBUG
            NSLog("[JohnCoreImport] stage=backup-summary-failed")
#endif
            throw error
        }
#if DEBUG
        NSLog("[JohnCoreImport] stage=backup-summary-complete")
#endif
        guard sourceSummary == backupSummary else {
            throw CoreError.failedBackup("recovery backup does not match the source schema and row counts")
        }
    }

    /// Keep a damaged primary file before the first update replaces it with the recovered state.
    private func preserveDamagedPrimary() throws {
        let damagedBytes: Data
        do { damagedBytes = try Data(contentsOf: primaryURL) }
        catch { throw CoreError.failedNativeStateWrite("damaged state file cannot be preserved") }
        let recoveryDirectory = stateDirectory.appendingPathComponent("recovery", isDirectory: true)
        do { try FileManager.default.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true) }
        catch { throw CoreError.failedNativeStateWrite("state recovery directory cannot be created") }
        try Self.syncDirectory(stateDirectory, failure: "state recovery directory entry cannot be synced")
        let archiveURL = recoveryDirectory.appendingPathComponent("native-state-damaged-\(UUID().uuidString).json")
        let descriptor = open(archiveURL.path, O_WRONLY | O_CREAT | O_EXCL, mode_t(S_IRUSR | S_IWUSR))
        guard descriptor >= 0 else { throw CoreError.failedNativeStateWrite("damaged state archive cannot be created") }
        var closed = false
        defer { if !closed { _ = close(descriptor) } }
        let writeResult: CoreError? = damagedBytes.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return nil }
            var offset = 0
            while offset < buffer.count {
                let count = Darwin.write(descriptor, base.advanced(by: offset), buffer.count - offset)
                if count < 0 {
                    if errno == EINTR { continue }
                    return .failedNativeStateWrite("damaged state archive write failed")
                }
                if count == 0 { return .failedNativeStateWrite("damaged state archive write returned zero bytes") }
                offset += count
            }
            return nil
        }
        if let writeResult { throw writeResult }
        guard fsync(descriptor) == 0 else { throw CoreError.failedNativeStateWrite("damaged state archive sync failed") }
        guard close(descriptor) == 0 else { closed = true; throw CoreError.failedNativeStateWrite("damaged state archive close failed") }
        closed = true
        guard (try? Data(contentsOf: archiveURL)) == damagedBytes else {
            throw CoreError.failedNativeStateWrite("damaged state archive did not validate")
        }
        try Self.syncDirectory(recoveryDirectory, failure: "state recovery directory sync failed")
    }

    private static func syncDirectory(_ directory: URL, failure: String) throws {
        let descriptor = open(directory.path, O_RDONLY)
        guard descriptor >= 0 else { throw CoreError.failedNativeStateWrite(failure) }
        defer { _ = close(descriptor) }
        guard fsync(descriptor) == 0 else { throw CoreError.failedNativeStateWrite(failure) }
    }

    private func loadNovenaIDs() throws -> [String] {
        struct Catalog: Decodable { let novenas: [Entry] }
        struct Entry: Decodable { let id: String }
        let url = try roots.appResource("Catalogs", "devotional-catalogs.json")
        let catalog: Catalog
        do { catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url)) }
        catch { throw CoreError.invalidResource("devotional novena catalog is invalid") }
        let ids = catalog.novenas.map(\.id)
        guard !ids.isEmpty, Set(ids).count == ids.count else { throw CoreError.invalidResource("devotional novena IDs are invalid") }
        return ids
    }

    private func readEnvelope(_ url: URL) -> ExistingEnvelope {
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { return .damaged("state file cannot be read") }
        guard let raw = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed),
              let fields = raw as? [String: Any], let rawVersion = fields["formatVersion"] as? NSNumber,
              CFGetTypeID(rawVersion) != CFBooleanGetTypeID(),
              let version = Int(exactly: rawVersion.doubleValue) else { return .damaged("state header is invalid") }
        guard version == 1 else { return .unsupported("Unsupported native state format version \(version). The state file was not changed.") }
        do {
              let envelope = try JSONDecoder().decode(NativeStateEnvelope.self, from: data)
            guard envelope.importVersion == 1 else {
                return .unsupported("Unsupported native state import version. The state file was not changed.")
            }
            try envelope.validate()
            return .valid(envelope)
        } catch { return .damaged("state payload is invalid") }
    }

    private func durableCommit(_ envelope: NativeStateEnvelope, preserving previous: NativeStateEnvelope?,
                               afterPrimaryRename: () -> Void = {}) throws {
        try envelope.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes: Data
        do { bytes = try encoder.encode(envelope) }
        catch { throw CoreError.failedNativeStateWrite("state encoding failed") }
        do { try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true) }
        catch { throw CoreError.failedNativeStateWrite("state directory cannot be created") }
        if let previous {
            let oldBytes = try encoder.encode(previous)
            try Self.durableReplace(oldBytes, at: previousURL)
        }
        #if DEBUG
        try Self.durableReplace(bytes, at: primaryURL, afterRename: { [checkpoint, failureInjector] in
            afterPrimaryRename()
            checkpoint?(.afterPrimaryRename)
            if failureInjector?(.afterPrimaryRename) == true {
                throw CoreError.failedNativeStateWrite("debug failure after primary state replacement")
            }
        })
        #else
        try Self.durableReplace(bytes, at: primaryURL, afterRename: { afterPrimaryRename() })
        #endif
        guard let verified = try? Data(contentsOf: primaryURL), verified == bytes,
              case let .valid(decoded) = readEnvelope(primaryURL), decoded == envelope else {
            throw CoreError.failedNativeStateWrite("state replacement did not validate")
        }
    }

    private static func durableReplace(_ data: Data, at destination: URL,
                                       afterRename: () throws -> Void = {}) throws {
        let directory = destination.deletingLastPathComponent()
        let temporary = directory.appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL, mode_t(S_IRUSR | S_IWUSR))
        guard fd >= 0 else { throw CoreError.failedNativeStateWrite("temporary state file cannot be created") }
        var shouldRemoveTemporary = true
        defer { if shouldRemoveTemporary { _ = unlink(temporary.path) } }
        var writeError: CoreError?
        data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            var offset = 0
            while offset < rawBuffer.count {
                let count = Darwin.write(fd, base.advanced(by: offset), rawBuffer.count - offset)
                if count < 0 {
                    if errno == EINTR { continue }
                    writeError = .failedNativeStateWrite("temporary state write failed")
                    return
                }
                if count == 0 { writeError = .failedNativeStateWrite("temporary state write returned zero bytes"); return }
                offset += count
            }
        }
        if let writeError { _ = close(fd); throw writeError }
        guard fsync(fd) == 0 else { _ = close(fd); throw CoreError.failedNativeStateWrite("temporary state sync failed") }
        guard close(fd) == 0 else { throw CoreError.failedNativeStateWrite("temporary state close failed") }
        guard rename(temporary.path, destination.path) == 0 else { throw CoreError.failedNativeStateWrite("state replacement failed") }
        shouldRemoveTemporary = false
        try afterRename()
        let directoryFD = open(directory.path, O_RDONLY)
        guard directoryFD >= 0 else { throw CoreError.failedNativeStateWrite("state directory cannot be opened for sync") }
        defer { _ = close(directoryFD) }
        guard fsync(directoryFD) == 0 else { throw CoreError.failedNativeStateWrite("state directory sync failed") }
    }
}
