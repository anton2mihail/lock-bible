import Foundation
import Observation
import JohnCore

/// The state of optional iCloud sync. Sync is off by default. The user turns it on in Settings.
@MainActor @Observable final class CloudSyncModel {
    static let defaultsKey = "JohnCloudSyncEnabled"

    private(set) var status: CloudSyncStatus = .off
    private(set) var isEnabled: Bool
    @ObservationIgnored private var service: CloudSyncEngineService?
    @ObservationIgnored private weak var runtime: JohnRuntime?

    init() {
        #if DEBUG
        // UI tests pass `-JohnResetNativeState` to start with sync off.
        if ProcessInfo.processInfo.arguments.contains("-JohnResetNativeState") {
            UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
        }
        #endif
        isEnabled = UserDefaults.standard.bool(forKey: Self.defaultsKey)
    }

    var statusText: String {
        switch status {
        case .off: "Off. Your data stays on this device."
        case .starting: "Starting sync."
        case .needsAccount: "Sign in to iCloud in the Settings app to sync. Your data stays on this device."
        case let .upToDate(date):
            if let date { "Up to date. Last sync " + date.formatted(date: .abbreviated, time: .shortened) + "." } else { "Up to date." }
        case let .waiting(text): text
        case let .failed(text): text
        }
    }

    /// Called once when the app starts. It starts sync only if the user turned it on before.
    func attach(_ runtime: JohnRuntime) {
        self.runtime = runtime
        if isEnabled, service == nil { startService() }
    }

    func setEnabled(_ on: Bool) {
        guard on != isEnabled else { return }
        isEnabled = on
        UserDefaults.standard.set(on, forKey: Self.defaultsKey)
        if on { startService() } else {
            // Turning sync off never removes data on this device or in iCloud.
            if let service { Task { await service.stop() } }
            service = nil
            status = .off
        }
    }

    func syncNow() { if let service { Task { await service.syncNow() } } }
    func localDataChanged() { if let service { Task { await service.localDataChanged() } } }

    private func startService() {
        guard let runtime, let directory = runtime.syncDirectory else { status = .failed("Sync cannot find the app data folder."); return }
        let service = CloudSyncEngineService(local: RuntimeSyncStore(runtime: runtime), directory: directory) { [weak self] value in
            Task { @MainActor in self?.status = value }
        }
        self.service = service
        status = .starting
        Task { await service.start() }
    }
}

/// Reads and writes the local library for sync. Every write is an addition or an update by newer `updatedAt`,
/// except an ID that a newer remote delete names.
struct RuntimeSyncStore: CloudSyncLocalStore {
    let runtime: JohnRuntime

    func snapshot() async -> CloudSyncLocal {
        let items = (try? await runtime.savedItems()) ?? []
        let tags = await runtime.savedTags()
        let read = await runtime.readingProgress().read
        return CloudSyncLocal(items: items, tags: tags, read: read)
    }

    func writeSafetyBackup() async { await runtime.writeSyncSafetyBackup() }

    func apply(items: [SavedItem], deleteIDs: [String], tags: [String: [String]], read: [String: [Int]]) async throws {
        try await runtime.applySyncChanges(items: items, deleteIDs: deleteIDs, tags: tags, read: read)
    }
}

extension JohnRuntime {
    var syncDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("John/sync", isDirectory: true)
    }

    /// Saves a backup file before sync changes local data. The folder keeps the last five files.
    func writeSyncSafetyBackup() async {
        guard let directory = syncDirectory?.appendingPathComponent("backups", isDirectory: true),
              let bundle = try? await exportDocuments() else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        try? bundle.backup.write(to: directory.appendingPathComponent("before-sync-\(stamp).json"), options: .atomic)
        let files = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("before-sync-") }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for old in files.dropLast(5) { try? FileManager.default.removeItem(at: old) }
    }

    func applySyncChanges(items: [SavedItem], deleteIDs: [String], tags: [String: [String]], read: [String: [Int]]) async throws {
        // Add and update first. Delete last, and only the IDs that a newer remote delete named.
        for item in items { try await restoreSavedItem(item) }
        if !deleteIDs.isEmpty {
            let current = try await savedItems()
            for item in current where deleteIDs.contains(item.id) { try await deleteSavedItem(item) }
        }
        if !tags.isEmpty { try await tagStore?.merge(tags) }
        if !read.isEmpty { try await progressStore?.mergeRead(read); progressRevision += 1 }
        savedRevision += 1
    }
}
