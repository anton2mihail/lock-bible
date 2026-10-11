import Foundation
import Testing
@testable import JohnCore

struct SyncMergeTests {
    private func item(_ id: String, at updated: Int64, note: String = "n") -> SavedItem {
        SavedItem(id: id, kind: .note, translationID: "webce", bookCode: "JHN", bookName: "John", bookOrder: 43, chapter: 1,
                  startVerse: "1", endVerse: "1", startIndex: 0, endIndex: 0, scriptureText: "t", reference: "John 1:1",
                  createdAt: 1, updatedAt: updated, noteText: note)
    }

    @Test func newRemoteItemIsApplied() {
        let plan = SyncMerge.plan(local: [], ledger: [:], remote: ["a": .live(item("a", at: 5))], now: 100)
        #expect(plan.applyItems.map(\.id) == ["a"])
        #expect(plan.push.isEmpty)
    }

    @Test func localOnlyItemIsPushed() {
        let plan = SyncMerge.plan(local: [item("a", at: 5)], ledger: [:], remote: [:], now: 100)
        #expect(plan.push.map(\.id) == ["a"])
        #expect(!plan.changesLocalData)
    }

    @Test func newerLocalItemIsNeverOverwritten() {
        let plan = SyncMerge.plan(local: [item("a", at: 20, note: "local")], ledger: [:],
                                  remote: ["a": .live(item("a", at: 10, note: "remote"))], now: 100)
        #expect(plan.applyItems.isEmpty)
        #expect(plan.push.first?.item?.noteText == "local")
    }

    @Test func newerRemoteItemWins() {
        let plan = SyncMerge.plan(local: [item("a", at: 10, note: "local")], ledger: [:],
                                  remote: ["a": .live(item("a", at: 20, note: "remote"))], now: 100)
        #expect(plan.applyItems.first?.noteText == "remote")
        #expect(plan.push.isEmpty)
    }

    @Test func remoteTombstoneDeletesOlderLocalItem() {
        let plan = SyncMerge.plan(local: [item("a", at: 10)], ledger: [:],
                                  remote: ["a": .tombstone(id: "a", at: 30)], now: 100)
        #expect(plan.deleteIDs == ["a"])
        #expect(plan.ledger["a"]?.deleted == true)
    }

    @Test func remoteTombstoneNeverDeletesNewerLocalItem() {
        let plan = SyncMerge.plan(local: [item("a", at: 50)], ledger: [:],
                                  remote: ["a": .tombstone(id: "a", at: 30)], now: 100)
        #expect(plan.deleteIDs.isEmpty)
        #expect(plan.push.first?.deleted == false)
        #expect(plan.push.first?.stamp ?? 0 > 30)
    }

    @Test func localDeleteBecomesTombstoneAndIsPushed() {
        let plan = SyncMerge.plan(local: [], ledger: ["a": SyncLedgerEntry(stamp: 10, deleted: false)],
                                  remote: ["a": .live(item("a", at: 10))], now: 100)
        #expect(plan.applyItems.isEmpty)
        #expect(plan.push == [.tombstone(id: "a", at: 100)])
        #expect(plan.ledger["a"] == SyncLedgerEntry(stamp: 100, deleted: true))
    }

    @Test func remoteItemChangedAfterLocalDeleteComesBack() {
        let plan = SyncMerge.plan(local: [], ledger: ["a": SyncLedgerEntry(stamp: 50, deleted: true)],
                                  remote: ["a": .live(item("a", at: 80))], now: 100)
        #expect(plan.applyItems.map(\.id) == ["a"])
    }

    @Test func restoredItemAfterUndoBeatsOldTombstone() {
        let plan = SyncMerge.plan(local: [item("a", at: 10)], ledger: ["a": SyncLedgerEntry(stamp: 60, deleted: true)],
                                  remote: ["a": .tombstone(id: "a", at: 60)], now: 100)
        #expect(plan.deleteIDs.isEmpty)
        #expect(plan.push.first?.deleted == false)
    }

    @Test func mergeNeverRemovesTagsOrReadChapters() {
        #expect(SyncMerge.mergeTags(["a": ["x"]], ["a": ["y"], "b": ["z"]]) == ["a": ["x", "y"], "b": ["z"]])
        #expect(SyncMerge.mergeRead(["JHN": [3, 1]], ["JHN": [2, 3], "MAT": [1]]) == ["JHN": [1, 2, 3], "MAT": [1]])
    }

    @Test func snapshotStoreRoundTrips() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sync-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = CloudSyncSnapshotStore(url: url)
        var snapshot = CloudSyncSnapshot()
        snapshot.ledger["a"] = SyncLedgerEntry(stamp: 5, deleted: true)
        snapshot.remote["a"] = .tombstone(id: "a", at: 5)
        try await store.save(snapshot)
        #expect(await CloudSyncSnapshotStore(url: url).load() == snapshot)
    }
}
