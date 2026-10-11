import Foundation

/// One synced saved item. A tombstone has `deleted == true` and no item.
/// `stamp` is the time of the last change in milliseconds. A tombstone stamp is the delete time.
public struct SyncRecord: Codable, Hashable, Sendable {
    public let id: String
    public let stamp: Int64
    public let deleted: Bool
    public let item: SavedItem?
    public init(id: String, stamp: Int64, deleted: Bool, item: SavedItem?) {
        self.id = id; self.stamp = stamp; self.deleted = deleted; self.item = item
    }
    public static func live(_ item: SavedItem, stamp: Int64? = nil) -> SyncRecord {
        SyncRecord(id: item.id, stamp: stamp ?? item.updatedAt, deleted: false, item: item)
    }
    public static func tombstone(id: String, at stamp: Int64) -> SyncRecord {
        SyncRecord(id: id, stamp: stamp, deleted: true, item: nil)
    }
}

/// What this device knew at the last sync for one item ID. A `deleted` entry is a local tombstone.
public struct SyncLedgerEntry: Codable, Hashable, Sendable {
    public var stamp: Int64
    public var deleted: Bool
    public init(stamp: Int64, deleted: Bool) { self.stamp = stamp; self.deleted = deleted }
}

public struct SyncPlan: Equatable, Sendable {
    /// Items to write to the local library. Each one is new or newer than the local copy.
    public var applyItems: [SavedItem] = []
    /// IDs to remove locally. Only a remote tombstone that is newer than the local item gives an ID here.
    public var deleteIDs: [String] = []
    /// Records to send to iCloud.
    public var push: [SyncRecord] = []
    /// The ledger after the plan runs.
    public var ledger: [String: SyncLedgerEntry] = [:]
    public var changesLocalData: Bool { !applyItems.isEmpty || !deleteIDs.isEmpty }
}

/// Pure merge rules for optional iCloud sync. Newer `updatedAt` wins. Local data is never replaced by older data.
public enum SyncMerge {
    public static func plan(local: [SavedItem], ledger oldLedger: [String: SyncLedgerEntry],
                            remote: [String: SyncRecord], now: Int64) -> SyncPlan {
        var plan = SyncPlan()
        var ledger = oldLedger
        let localByID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { a, b in a.updatedAt >= b.updatedAt ? a : b })

        // A live ledger entry with no local item means the user deleted it here. That is a new tombstone.
        for (id, entry) in oldLedger where !entry.deleted && localByID[id] == nil {
            ledger[id] = SyncLedgerEntry(stamp: now, deleted: true)
        }
        // An item that is back after a local delete (for example Undo) is live again. Its stamp is now.
        var localStamp: [String: Int64] = [:]
        for item in localByID.values {
            if let entry = ledger[item.id], entry.deleted {
                localStamp[item.id] = max(item.updatedAt, now)
                ledger[item.id] = SyncLedgerEntry(stamp: max(item.updatedAt, now), deleted: false)
            } else {
                localStamp[item.id] = max(item.updatedAt, ledger[item.id]?.stamp ?? 0)
            }
        }

        let ids = Set(localByID.keys).union(ledger.filter { $0.value.deleted }.keys).union(remote.keys)
        for id in ids.sorted() {
            let item = localByID[id]
            let tomb = ledger[id].flatMap { $0.deleted ? $0.stamp : nil }
            let record = remote[id]
            switch (item, tomb, record) {
            case let (item?, _, record?):
                let stamp = localStamp[id] ?? item.updatedAt
                if record.deleted {
                    if record.stamp > stamp {
                        plan.deleteIDs.append(id)
                        ledger[id] = SyncLedgerEntry(stamp: record.stamp, deleted: true)
                    } else {
                        plan.push.append(.live(item, stamp: max(stamp, record.stamp + 1)))
                        ledger[id] = SyncLedgerEntry(stamp: max(stamp, record.stamp + 1), deleted: false)
                    }
                } else if let remoteItem = record.item {
                    // Reuse the backup rule: apply only when the remote item is newer by `updatedAt`.
                    let apply = SavedBackup(items: [remoteItem], tags: [:], exportedAt: now).itemsToApply(existing: [item])
                    if let newer = apply.first {
                        plan.applyItems.append(newer)
                        ledger[id] = SyncLedgerEntry(stamp: max(record.stamp, newer.updatedAt), deleted: false)
                    } else if item.updatedAt > remoteItem.updatedAt || stamp > record.stamp {
                        plan.push.append(.live(item, stamp: max(stamp, record.stamp + (item == remoteItem ? 0 : 1))))
                        ledger[id] = SyncLedgerEntry(stamp: stamp, deleted: false)
                    } else {
                        ledger[id] = SyncLedgerEntry(stamp: max(stamp, record.stamp), deleted: false)
                    }
                }
            case let (nil, deletedAt?, record?):
                if record.deleted {
                    ledger[id] = SyncLedgerEntry(stamp: max(deletedAt, record.stamp), deleted: true)
                } else if let remoteItem = record.item, remoteItem.updatedAt > deletedAt {
                    // The item changed elsewhere after the local delete. Keep the newer data.
                    plan.applyItems.append(remoteItem)
                    ledger[id] = SyncLedgerEntry(stamp: record.stamp, deleted: false)
                } else if !record.deleted {
                    plan.push.append(.tombstone(id: id, at: deletedAt))
                }
            case let (nil, nil, record?):
                if let remoteItem = record.item, !record.deleted {
                    plan.applyItems.append(remoteItem)
                    ledger[id] = SyncLedgerEntry(stamp: record.stamp, deleted: false)
                } else {
                    ledger[id] = SyncLedgerEntry(stamp: record.stamp, deleted: true)
                }
            case let (item?, _, nil):
                let stamp = localStamp[id] ?? item.updatedAt
                plan.push.append(.live(item, stamp: stamp))
                ledger[id] = SyncLedgerEntry(stamp: stamp, deleted: false)
            case let (nil, deletedAt?, nil):
                plan.push.append(.tombstone(id: id, at: deletedAt))
            case (nil, nil, nil):
                break
            }
        }
        plan.ledger = ledger
        return plan
    }

    /// Tags only grow in a merge. A tag that one device removed stays on another device.
    public static func mergeTags(_ a: [String: [String]], _ b: [String: [String]]) -> [String: [String]] {
        SavedTags.merge(a, b)
    }

    /// Read chapters only grow in a merge.
    public static func mergeRead(_ a: [String: [Int]], _ b: [String: [Int]]) -> [String: [Int]] {
        var result = a
        for (book, chapters) in b { result[book] = Array(Set(result[book] ?? []).union(chapters)).sorted() }
        return result
    }
}

/// Everything that sync keeps on disk between runs: the ledger and the last known remote records.
public struct CloudSyncSnapshot: Codable, Sendable, Equatable {
    public var ledger: [String: SyncLedgerEntry] = [:]
    public var remote: [String: SyncRecord] = [:]
    public var remoteTags: [String: [String]] = [:]
    public var remoteRead: [String: [Int]] = [:]
    public var lastSyncAt: Int64?
    public init() {}
}

public actor CloudSyncSnapshotStore {
    private let url: URL
    private var cache: CloudSyncSnapshot?
    public init(url: URL) { self.url = url }

    public func load() -> CloudSyncSnapshot {
        if let cache { return cache }
        let value = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(CloudSyncSnapshot.self, from: $0) } ?? CloudSyncSnapshot()
        cache = value
        return value
    }

    public func save(_ value: CloudSyncSnapshot) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
        cache = value
    }
}
