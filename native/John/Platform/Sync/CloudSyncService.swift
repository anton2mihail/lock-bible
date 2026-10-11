import CloudKit
import Foundation
import JohnCore

/// What the Settings row shows. Sync is off by default.
enum CloudSyncStatus: Equatable, Sendable {
    case off
    case starting
    case needsAccount
    case upToDate(Date?)
    case waiting(String)
    case failed(String)
}

struct CloudSyncLocal: Sendable {
    var items: [SavedItem]
    var tags: [String: [String]]
    var read: [String: [Int]]
}

/// The local data that sync reads and writes. `apply` never removes data except the IDs that the merge plan names.
protocol CloudSyncLocalStore: Sendable {
    func snapshot() async -> CloudSyncLocal
    func writeSafetyBackup() async
    func apply(items: [SavedItem], deleteIDs: [String], tags: [String: [String]], read: [String: [Int]]) async throws
}

private struct EngineFile: Codable {
    var state: CKSyncEngine.State.Serialization?
    var fields: [String: Data] = [:]
}

/// CloudKit private database sync with CKSyncEngine. The merge rules are in `SyncMerge` (JohnCore).
actor CloudSyncEngineService: CKSyncEngineDelegate {
    private static let zoneID = CKRecordZone.ID(zoneName: "NRSVSync", ownerName: CKCurrentUserDefaultName)
    private static let recordType = "SyncRecord"
    private static let tagsName = "tags"
    private static let progressName = "progress"
    private static let itemPrefix = "item:"

    private let local: any CloudSyncLocalStore
    private let snapshotStore: CloudSyncSnapshotStore
    private let engineURL: URL
    private let report: @Sendable (CloudSyncStatus) -> Void
    private var engine: CKSyncEngine?
    private var snapshot = CloudSyncSnapshot()
    private var file = EngineFile()
    private var reconciling = false
    private var reconcileAgain = false
    private var sawError = false

    init(local: any CloudSyncLocalStore, directory: URL, report: @escaping @Sendable (CloudSyncStatus) -> Void) {
        self.local = local
        self.report = report
        snapshotStore = CloudSyncSnapshotStore(url: directory.appendingPathComponent("cloud-sync-snapshot-v1.json"))
        engineURL = directory.appendingPathComponent("cloud-sync-engine-v1.json")
    }

    // MARK: Lifecycle

    func start() async {
        report(.starting)
        guard FileManager.default.ubiquityIdentityToken != nil else { report(.needsAccount); return }
        let container = CKContainer.default()
        do {
            guard try await container.accountStatus() == .available else { report(.needsAccount); return }
        } catch {
            report(.waiting("Cannot reach iCloud now. Sync will try again.")); return
        }
        snapshot = await snapshotStore.load()
        if let data = try? Data(contentsOf: engineURL), let loaded = try? JSONDecoder().decode(EngineFile.self, from: data) { file = loaded }
        var configuration = CKSyncEngine.Configuration(database: container.privateCloudDatabase,
                                                       stateSerialization: file.state, delegate: self)
        configuration.automaticallySync = true
        let engine = CKSyncEngine(configuration)
        self.engine = engine
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
        await reconcile()
        await syncNow()
    }

    func stop() { engine = nil }

    /// Fetches, merges and sends. Local data stays in place if this fails.
    func syncNow() async {
        guard let engine else { return }
        await reconcile()
        do {
            try await engine.fetchChanges()
            try await engine.sendChanges()
        } catch {
            handle(error)
        }
    }

    func localDataChanged() async {
        guard engine != nil else { return }
        await reconcile()
    }

    // MARK: Merge

    private func reconcile() async {
        guard let engine else { return }
        if reconciling { reconcileAgain = true; return }
        reconciling = true
        defer { reconciling = false }
        repeat {
            reconcileAgain = false
            let current = await local.snapshot()
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let plan = SyncMerge.plan(local: current.items, ledger: snapshot.ledger, remote: snapshot.remote, now: now)
            let tags = SyncMerge.mergeTags(current.tags, snapshot.remoteTags)
            let read = SyncMerge.mergeRead(current.read, snapshot.remoteRead)
            let tagsToApply = tags == current.tags ? [:] : tags
            let readToApply = read == current.read ? [:] : read
            if plan.changesLocalData || !tagsToApply.isEmpty || !readToApply.isEmpty {
                await local.writeSafetyBackup()
                do {
                    try await local.apply(items: plan.applyItems, deleteIDs: plan.deleteIDs, tags: tagsToApply, read: readToApply)
                } catch {
                    report(.failed("Sync could not update this device. Your data is unchanged."))
                    return
                }
            }
            var changes: [CKSyncEngine.PendingRecordZoneChange] = []
            for record in plan.push {
                snapshot.remote[record.id] = record
                changes.append(.saveRecord(Self.recordID(Self.itemPrefix + record.id)))
            }
            if tags != snapshot.remoteTags {
                snapshot.remoteTags = tags
                changes.append(.saveRecord(Self.recordID(Self.tagsName)))
            }
            if read != snapshot.remoteRead {
                snapshot.remoteRead = read
                changes.append(.saveRecord(Self.recordID(Self.progressName)))
            }
            snapshot.ledger = plan.ledger
            await persistSnapshot()
            if !changes.isEmpty { engine.state.add(pendingRecordZoneChanges: changes) }
        } while reconcileAgain
    }

    // MARK: Delegate

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case let .stateUpdate(update):
            file.state = update.stateSerialization
            persistEngine()
        case let .accountChange(change):
            switch change.changeType {
            case .signOut: report(.needsAccount)
            case .switchAccounts:
                // Local data stays. The new account starts empty and receives the local data.
                snapshot.remote = [:]; snapshot.remoteTags = [:]; snapshot.remoteRead = [:]
                file.fields = [:]; await persistSnapshot(); persistEngine()
                syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
                await reconcile()
            case .signIn: report(.starting)
            @unknown default: break
            }
        case let .fetchedDatabaseChanges(changes):
            if changes.deletions.contains(where: { $0.zoneID == Self.zoneID }) {
                // The user cleared iCloud data. Keep local data and send it again.
                snapshot.remote = [:]; snapshot.remoteTags = [:]; snapshot.remoteRead = [:]
                file.fields = [:]; await persistSnapshot(); persistEngine()
                syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
                await reconcile()
            }
        case let .fetchedRecordZoneChanges(changes):
            for modification in changes.modifications { absorb(modification.record) }
            for deletion in changes.deletions {
                let name = deletion.recordID.recordName
                file.fields[name] = nil
                if name.hasPrefix(Self.itemPrefix) { snapshot.remote[String(name.dropFirst(Self.itemPrefix.count))] = nil }
            }
            await persistSnapshot(); persistEngine()
            await reconcile()
        case let .sentRecordZoneChanges(sent):
            for record in sent.savedRecords { file.fields[record.recordID.recordName] = Self.systemFields(of: record) }
            for failure in sent.failedRecordSaves { await handleFailedSave(failure, engine: syncEngine) }
            persistEngine()
        case .willFetchChanges, .willSendChanges:
            sawError = false
        case .didFetchChanges, .didSendChanges:
            if !sawError {
                snapshot.lastSyncAt = Int64(Date().timeIntervalSince1970 * 1000)
                await persistSnapshot()
                report(.upToDate(Date()))
            }
        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        var records: [CKRecord.ID: CKRecord] = [:]
        var missing: [CKSyncEngine.PendingRecordZoneChange] = []
        for change in pending {
            guard case let .saveRecord(id) = change else { continue }
            if let record = makeRecord(id) { records[id] = record } else { missing.append(change) }
        }
        if !missing.isEmpty { syncEngine.state.remove(pendingRecordZoneChanges: missing) }
        let ready = records
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending.filter { change in
            if case let .saveRecord(id) = change { return ready[id] != nil }
            return false
        }) { id in ready[id] }
    }

    // MARK: Records

    private static func recordID(_ name: String) -> CKRecord.ID { CKRecord.ID(recordName: name, zoneID: zoneID) }

    private func makeRecord(_ id: CKRecord.ID) -> CKRecord? {
        let name = id.recordName
        let payload: Data
        let stamp: Int64
        if name == Self.tagsName {
            guard let data = try? JSONEncoder().encode(snapshot.remoteTags) else { return nil }
            payload = data; stamp = snapshot.lastSyncAt ?? 0
        } else if name == Self.progressName {
            guard let data = try? JSONEncoder().encode(snapshot.remoteRead) else { return nil }
            payload = data; stamp = snapshot.lastSyncAt ?? 0
        } else if name.hasPrefix(Self.itemPrefix), let item = snapshot.remote[String(name.dropFirst(Self.itemPrefix.count))],
                  let data = try? JSONEncoder().encode(item) {
            payload = data; stamp = item.stamp
        } else { return nil }
        let record = file.fields[name].flatMap(Self.record(fromSystemFields:)) ?? CKRecord(recordType: Self.recordType, recordID: id)
        record["payload"] = payload as NSData
        record["stamp"] = NSNumber(value: stamp)
        return record
    }

    private func absorb(_ record: CKRecord) {
        let name = record.recordID.recordName
        guard let payload = record["payload"] as? Data else { return }
        file.fields[name] = Self.systemFields(of: record)
        let decoder = JSONDecoder()
        if name == Self.tagsName {
            if let tags = try? decoder.decode([String: [String]].self, from: payload) {
                snapshot.remoteTags = SyncMerge.mergeTags(snapshot.remoteTags, tags)
            }
        } else if name == Self.progressName {
            if let read = try? decoder.decode([String: [Int]].self, from: payload) {
                snapshot.remoteRead = SyncMerge.mergeRead(snapshot.remoteRead, read)
            }
        } else if name.hasPrefix(Self.itemPrefix), let item = try? decoder.decode(SyncRecord.self, from: payload) {
            // Keep the newer of two remote copies by stamp.
            if let old = snapshot.remote[item.id], old.stamp > item.stamp { return }
            snapshot.remote[item.id] = item
        }
    }

    private func handleFailedSave(_ failure: CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave, engine: CKSyncEngine) async {
        let id = failure.record.recordID
        switch failure.error.code {
        case .serverRecordChanged:
            if let server = failure.error.serverRecord { absorb(server) }
            engine.state.add(pendingRecordZoneChanges: [.saveRecord(id)])
            await reconcile()
        case .zoneNotFound:
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
            file.fields = [:]
            engine.state.add(pendingRecordZoneChanges: [.saveRecord(id)])
        case .unknownItem:
            file.fields[id.recordName] = nil
            engine.state.add(pendingRecordZoneChanges: [.saveRecord(id)])
        default:
            handle(failure.error)
        }
    }

    private func handle(_ error: Error) {
        sawError = true
        guard let cloud = error as? CKError else { report(.failed("Sync stopped. Your data is unchanged.")); return }
        switch cloud.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            report(.waiting("You are offline. Sync will resume when iCloud is reachable."))
        case .notAuthenticated, .accountTemporarilyUnavailable:
            report(.needsAccount)
        case .quotaExceeded:
            report(.failed("Your iCloud storage is full. Your data on this device is unchanged."))
        default:
            report(.failed("Sync stopped (\(cloud.code.rawValue)). Your data on this device is unchanged."))
        }
    }

    // MARK: Persistence

    private func persistSnapshot() async { try? await snapshotStore.save(snapshot) }

    private func persistEngine() {
        try? FileManager.default.createDirectory(at: engineURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(file) { try? data.write(to: engineURL, options: .atomic) }
    }

    private static func systemFields(of record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    private static func record(fromSystemFields data: Data) -> CKRecord? {
        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        coder.requiresSecureCoding = true
        defer { coder.finishDecoding() }
        return CKRecord(coder: coder)
    }
}
