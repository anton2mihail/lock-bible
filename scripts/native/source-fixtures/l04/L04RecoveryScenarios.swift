#if DEBUG
import CryptoKit
import Foundation
import JohnCore

/// Small recovery checks for copied, test-owned native-state roots.
public enum L04RecoveryScenarios {
    public enum Scenario: String, CaseIterable, Sendable {
        case unsupportedEnvelope
        case damagedPrimaryWithValidPrevious
        case bothEnvelopesInvalid
    }

    public struct Result: Codable, Sendable {
        public let scenario: String
        public let passed: Bool
        public let revision: Int64?
        public let capability: String?
        public let sourceHashes: [String: String]
        public let details: [String: String]
    }

    /// Run one case below a new output path. This helper writes no fixture input.
    public static func run(_ scenario: Scenario, outputRoot: URL, roots: ResourceRoots) async throws -> Result {
        guard !FileManager.default.fileExists(atPath: outputRoot.path) else {
            throw CoreError.invalidResource("recovery output path already exists")
        }
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        let support = outputRoot.appendingPathComponent("Application Support", isDirectory: true)
        let libraryURL = outputRoot.appendingPathComponent("Documents/SQLite/user-library.db")
        let initialStore = NativeStateStore(applicationSupportURL: support, libraryURL: libraryURL,
                                            roots: roots, legacyReader: nil)
        let initial = await initialStore.loadOrImport()
        guard let envelope = initial.envelope, initial.libraryCapability == nil else {
            throw CoreError.unreadableLibrary("recovery fixture could not create a valid base state and library")
        }
        let stateDirectory = support.appendingPathComponent("John", isDirectory: true)
        let primaryURL = stateDirectory.appendingPathComponent("native-state-v1.json")
        let previousURL = stateDirectory.appendingPathComponent("native-state-v1.previous.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let validBytes = try encoder.encode(envelope)
        let damagedPrimary = Data("{\"invalid\":\n".utf8)
        let damagedPrevious = Data("not-json previous state".utf8)
        var details: [String: String] = [:]
        var passed = false
        var revision: Int64?
        var capability: String?

        switch scenario {
        case .unsupportedEnvelope:
            guard let object = try JSONSerialization.jsonObject(with: validBytes) as? [String: Any] else {
                throw CoreError.invalidResource("valid seed envelope is not a JSON object")
            }
            var unsupported = object
            unsupported["formatVersion"] = 2
            let bytes = try JSONSerialization.data(withJSONObject: unsupported, options: [.sortedKeys])
            try bytes.write(to: primaryURL, options: .atomic)
            let store = NativeStateStore(applicationSupportURL: support, libraryURL: libraryURL,
                                         roots: roots, legacyReader: nil)
            let startup = await store.loadOrImport()
            let updateWasBlocked: Bool
            do { _ = try await store.update(.setThemeScheme("dark")); updateWasBlocked = false }
            catch { updateWasBlocked = true }
            let after = try Data(contentsOf: primaryURL)
            details["unsupportedBytesPreserved"] = String(after == bytes)
            details["updateBlocked"] = String(updateWasBlocked)
            passed = startup.envelope == nil && startup.nativeStateCapability != nil && updateWasBlocked && after == bytes
            revision = startup.revision
            capability = startup.nativeStateCapability

        case .damagedPrimaryWithValidPrevious:
            try damagedPrimary.write(to: primaryURL, options: .atomic)
            try validBytes.write(to: previousURL, options: .atomic)
            let store = NativeStateStore(applicationSupportURL: support, libraryURL: libraryURL,
                                         roots: roots, legacyReader: nil)
            let recovered = await store.loadOrImport()
            details["recoveredRevision"] = String(recovered.revision ?? -1)
            details["primaryDamageCapability"] = recovered.nativeStateCapability ?? "none"
            let updated: NativeStateEnvelope?
            do { updated = try await store.update(.setThemeScheme("dark")) }
            catch { updated = nil; details["updateError"] = String(describing: error) }
            let recoveryDirectory = stateDirectory.appendingPathComponent("recovery", isDirectory: true)
            let archives = (try? FileManager.default.contentsOfDirectory(at: recoveryDirectory, includingPropertiesForKeys: nil)) ?? []
            let archived = archives.first(where: { $0.lastPathComponent.hasPrefix("native-state-damaged-") })
            let archivedBytes = archived.flatMap { try? Data(contentsOf: $0) }
            let primaryAfter = (try? Data(contentsOf: primaryURL)).flatMap { try? JSONDecoder().decode(NativeStateEnvelope.self, from: $0) }
            let archivedCorrectly = archivedBytes == damagedPrimary
            let primaryUpdated = primaryAfter?.revision == 2 && primaryAfter?.state.themeScheme == "dark"
            details["damagedPrimaryArchived"] = String(archivedCorrectly)
            details["recoveredPrimaryUpdated"] = String(primaryUpdated)
            details["archiveCount"] = String(archives.filter { $0.lastPathComponent.hasPrefix("native-state-damaged-") }.count)
            passed = recovered.revision == 1 && recovered.nativeStateCapability != nil &&
                updated?.revision == 2 && archivedCorrectly && primaryUpdated
            revision = updated?.revision
            capability = recovered.nativeStateCapability

        case .bothEnvelopesInvalid:
            try damagedPrimary.write(to: primaryURL, options: .atomic)
            try damagedPrevious.write(to: previousURL, options: .atomic)
            let store = NativeStateStore(applicationSupportURL: support, libraryURL: libraryURL,
                                         roots: roots, legacyReader: nil)
            let startup = await store.loadOrImport()
            let updateWasBlocked: Bool
            do { _ = try await store.update(.setThemeScheme("dark")); updateWasBlocked = false }
            catch { updateWasBlocked = true }
            let primaryAfter = try Data(contentsOf: primaryURL)
            let previousAfter = try Data(contentsOf: previousURL)
            details["primaryPreserved"] = String(primaryAfter == damagedPrimary)
            details["previousPreserved"] = String(previousAfter == damagedPrevious)
            details["updateBlocked"] = String(updateWasBlocked)
            passed = startup.envelope == nil && startup.nativeStateCapability != nil && updateWasBlocked &&
                primaryAfter == damagedPrimary && previousAfter == damagedPrevious
            revision = startup.revision
            capability = startup.nativeStateCapability
        }

        let primaryHash = sha256(primaryURL)
        let previousHash = sha256(previousURL)
        let recoveryFiles = (try? FileManager.default.contentsOfDirectory(
            at: stateDirectory.appendingPathComponent("recovery", isDirectory: true), includingPropertiesForKeys: nil
        )) ?? []
        var hashes: [String: String] = [:]
        if let primaryHash { hashes["primary"] = primaryHash }
        if let previousHash { hashes["previous"] = previousHash }
        for file in recoveryFiles where file.lastPathComponent.hasPrefix("native-state-damaged-") {
            if let hash = sha256(file) { hashes["recovery/\(file.lastPathComponent)"] = hash }
        }
        return Result(scenario: scenario.rawValue, passed: passed, revision: revision,
                      capability: capability, sourceHashes: hashes, details: details)
    }

    /// Read an existing, test-owned root after Main relaunches the app.
    /// This performs one startup call and does not repeat or retry the operation.
    public static func resumeExistingRoot(applicationSupportURL: URL, libraryURL: URL,
                                           roots: ResourceRoots, outputRoot: URL) async throws -> Result {
        guard !FileManager.default.fileExists(atPath: outputRoot.path) else {
            throw CoreError.invalidResource("resume output path already exists")
        }
        let support = applicationSupportURL.standardizedFileURL.resolvingSymlinksInPath()
        let library = libraryURL.standardizedFileURL.resolvingSymlinksInPath()
        let output = outputRoot.standardizedFileURL.resolvingSymlinksInPath()
        guard !isWithin(output, support), !isWithin(support, output),
              !isWithin(output, library), !isWithin(library, output) else {
            throw CoreError.invalidResource("resume output and existing state paths must not overlap")
        }
        let primary = support.appendingPathComponent("John/native-state-v1.json")
        let previous = support.appendingPathComponent("John/native-state-v1.previous.json")
        guard FileManager.default.fileExists(atPath: primary.path) || FileManager.default.fileExists(atPath: previous.path) else {
            throw CoreError.missingResource("resume requires an existing native state file")
        }
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        let primaryBefore = try? Data(contentsOf: primary)
        let previousBefore = try? Data(contentsOf: previous)
        let store = NativeStateStore(applicationSupportURL: applicationSupportURL, libraryURL: libraryURL,
                                     roots: roots, legacyReader: nil)
        let startup = await store.loadOrImport()
        let primaryAfter = try? Data(contentsOf: primary)
        let previousAfter = try? Data(contentsOf: previous)
        var details = [
            "primaryUnchanged": String(primaryBefore == primaryAfter),
            "previousUnchanged": String(previousBefore == previousAfter),
            "libraryCapability": startup.libraryCapability ?? "none",
            "nativeStateCapability": startup.nativeStateCapability ?? "none",
        ]
        if let envelope = startup.envelope { details["formatVersion"] = String(envelope.formatVersion) }
        var hashes: [String: String] = [:]
        if let value = primaryAfter { hashes["primary"] = Self.sha256(value) }
        if let value = previousAfter { hashes["previous"] = Self.sha256(value) }
        let passed = startup.envelope != nil && primaryBefore == primaryAfter && previousBefore == previousAfter
        let result = Result(scenario: "resumeExistingRoot", passed: passed,
                            revision: startup.revision,
                            capability: startup.nativeStateCapability ?? startup.libraryCapability,
                            sourceHashes: hashes, details: details)
        try Self.write(result, to: outputRoot)
        return result
    }

    /// Retry a test-owned import after Main relaunches from a before-commit interruption.
    /// The state files must still be absent. The existing copied library and injected reader stay in place.
    public static func resumeBeforeCommit(fixtureRoot: URL, applicationSupportURL: URL,
                                          libraryURL: URL, roots: ResourceRoots,
                                          legacyReader: any LegacyMMKVReading,
                                          outputRoot: URL) async throws -> Result {
        guard !FileManager.default.fileExists(atPath: outputRoot.path) else {
            throw CoreError.invalidResource("resume output path already exists")
        }
        let input = fixtureRoot.standardizedFileURL.resolvingSymlinksInPath()
        let output = outputRoot.standardizedFileURL.resolvingSymlinksInPath()
        let support = applicationSupportURL.standardizedFileURL.resolvingSymlinksInPath()
        let library = libraryURL.standardizedFileURL.resolvingSymlinksInPath()
        guard !isWithin(output, input), !isWithin(input, output),
              !isWithin(output, support), !isWithin(support, output),
              !isWithin(output, library), !isWithin(library, output) else {
            throw CoreError.invalidResource("resume output must not overlap the copied inputs or state")
        }
        guard FileManager.default.fileExists(atPath: fixtureRoot.appendingPathComponent("fixture-manifest.json").path) else {
            throw CoreError.missingResource("L04 fixture manifest")
        }
        let stateDirectory = support.appendingPathComponent("John", isDirectory: true)
        let primary = stateDirectory.appendingPathComponent("native-state-v1.json")
        let previous = stateDirectory.appendingPathComponent("native-state-v1.previous.json")
        guard !FileManager.default.fileExists(atPath: primary.path),
              !FileManager.default.fileExists(atPath: previous.path) else {
            throw CoreError.invalidResource("before-commit resume requires no state files")
        }
        guard FileManager.default.fileExists(atPath: library.path),
              ((try? library.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) > 0 else {
            throw CoreError.missingResource("before-commit resume requires a copied library")
        }
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        let libraryBefore = sha256(library)
        let walURL = URL(fileURLWithPath: library.path + "-wal")
        let walBefore = sha256(walURL)
        let store = NativeStateStore(applicationSupportURL: applicationSupportURL, libraryURL: libraryURL,
                                     roots: roots, legacyReader: legacyReader)
        let startup = await store.loadOrImport()
        let libraryAfter = sha256(library)
        let walAfter = sha256(walURL)
        let details = [
            "libraryUnchanged": String(libraryBefore == libraryAfter),
            "walUnchanged": String(walBefore == walAfter),
            "libraryCapability": startup.libraryCapability ?? "none",
            "nativeStateCapability": startup.nativeStateCapability ?? "none",
            "primaryExists": String(FileManager.default.fileExists(atPath: primary.path)),
        ]
        var hashes: [String: String] = [:]
        if let libraryBefore { hashes["library-before"] = libraryBefore }
        if let libraryAfter { hashes["library-after"] = libraryAfter }
        if let walBefore { hashes["wal-before"] = walBefore }
        if let walAfter { hashes["wal-after"] = walAfter }
        let passed = startup.revision == 1 && startup.nativeStateCapability == nil &&
            startup.libraryCapability == nil && libraryBefore != nil && libraryBefore == libraryAfter &&
            walBefore == walAfter && FileManager.default.fileExists(atPath: primary.path)
        let result = Result(scenario: "resumeBeforeCommit", passed: passed,
                            revision: startup.revision,
                            capability: startup.nativeStateCapability ?? startup.libraryCapability,
                            sourceHashes: hashes, details: details)
        try Self.write(result, to: outputRoot)
        return result
    }

    @discardableResult
    public static func write(_ result: Result, to outputRoot: URL) throws -> URL {
        let destination = outputRoot.appendingPathComponent("scenario-result.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(result).write(to: destination, options: .atomic)
        return destination
    }

    private static func sha256(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return sha256(data)
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func isWithin(_ candidate: URL, _ root: URL) -> Bool {
        if candidate == root { return true }
        return candidate.path.hasPrefix(root.path.hasSuffix("/") ? root.path : root.path + "/")
    }
}
#endif
