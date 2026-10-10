import Foundation
import Testing
@testable import JohnCore

private func book(_ code: String, _ name: String, chapters: Int, order: Int) throws -> SearchBookMetadata {
    let json = """
    {"code":"\(code)","name":"\(name)","longName":"\(name)","group":"nt","order":\(order),"chapterCount":\(chapters)}
    """
    return try JSONDecoder().decode(SearchBookMetadata.self, from: Data(json.utf8))
}

@Suite struct ReferenceParserTests {
    @Test func parsesChapterAndVerseRange() throws {
        let books = [try book("JHN", "John", chapters: 21, order: 1)]
        let ref = try #require(BibleReferenceParser.parse("John 3:16-18", books: books))
        #expect(ref.book.code == "JHN")
        #expect(ref.chapter == 3)
        #expect(ref.startVerse == "16")
        #expect(ref.endVerse == "18")
    }

    @Test func parsesAliasAndChapterOnly() throws {
        let books = [try book("JHN", "John", chapters: 21, order: 1)]
        let ref = try #require(BibleReferenceParser.parse("jn 5", books: books))
        #expect(ref.chapter == 5)
        #expect(ref.startVerse == nil)
    }

    @Test func rejectsChapterOutOfRange() throws {
        let books = [try book("JHN", "John", chapters: 21, order: 1)]
        #expect(BibleReferenceParser.parse("John 22", books: books) == nil)
        #expect(BibleReferenceParser.parse("John 0", books: books) == nil)
    }

    @Test func editDistanceCountsEdits() {
        #expect(BibleReferenceParser.editDistance("john", "john") == 0)
        #expect(BibleReferenceParser.editDistance("john", "jon") == 1)
    }
}

@Suite struct SearchScopeTests {
    @Test func scopeRawValuesAreStable() {
        #expect(BibleSearchScope(rawValue: "all") == .all)
        #expect(BibleSearchScope(rawValue: "ot") == .ot)
        #expect(BibleSearchScope(rawValue: "nt") == .nt)
        #expect(BibleSearchScope(rawValue: "x") == nil)
    }

    @Test func normalizeIsCaseAndPunctuationInsensitive() {
        #expect(BibleReferenceParser.normalize("  John. ") == BibleReferenceParser.normalize("john"))
    }
}

@Suite struct RotationDateTests {
    @Test func slotAdvancesAtIntervalBoundary() throws {
        let t = Date(timeIntervalSince1970: 86_400 * 10)
        let a = try RotationMath.slot(at: t, utcOffsetSeconds: 0, intervalMinutes: 60)
        let b = try RotationMath.slot(at: t.addingTimeInterval(3_599), utcOffsetSeconds: 0, intervalMinutes: 60)
        let c = try RotationMath.slot(at: t.addingTimeInterval(3_600), utcOffsetSeconds: 0, intervalMinutes: 60)
        #expect(a == b)
        #expect(c == a + 1)
    }

    @Test func utcOffsetShiftsLocalDay() throws {
        let t = Date(timeIntervalSince1970: 86_400 * 10 - 60)
        let utc = try RotationMath.slot(at: t, utcOffsetSeconds: 0, intervalMinutes: 1_440)
        let east = try RotationMath.slot(at: t, utcOffsetSeconds: 3_600, intervalMinutes: 1_440)
        #expect(east == utc + 1)
    }

    @Test func nextBoundaryIsAfterInstant() throws {
        let t = Date(timeIntervalSince1970: 1_000_000)
        let next = try RotationMath.nextBoundary(after: t, utcOffsetSeconds: 0, intervalMinutes: 60)
        #expect(next > t)
        #expect(next.timeIntervalSince(t) <= 3_600)
    }

    @Test func indexStaysInRangeAndCoversPool() throws {
        var seen = Set<Int>()
        for slot in 0..<10 { seen.insert(try RotationMath.index(for: Int64(slot), count: 10)) }
        #expect(seen.count == 10)
        #expect(try RotationMath.index(for: 5, count: 0) == 0)
    }

    @Test func rejectsZeroInterval() {
        #expect(throws: (any Error).self) {
            try RotationMath.slot(at: Date(), utcOffsetSeconds: 0, intervalMinutes: 0)
        }
    }

    @Test func scopeMatching() {
        #expect(RotationMath.scopeMatches(group: "deutero", scope: .ot))
        #expect(!RotationMath.scopeMatches(group: "nt", scope: .ot))
        #expect(RotationMath.scopeMatches(group: "nt", scope: .nt))
        #expect(RotationMath.scopeMatches(group: "ot", scope: .full))
    }
}

@Suite struct SavedLibraryTests {
    @Test func newLibraryStartsEmpty() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let boundary = SQLiteLibraryBoundary(databaseURL: dir.appendingPathComponent("library.sqlite"))
        let summary = try await boundary.prepareForStartup()
        #expect(summary.bookmarkCount == 0)
        #expect(summary.highlightCount == 0)
        #expect(summary.noteCount == 0)
        let again = try await boundary.inspect()
        #expect(again == summary)
    }
}

@Suite struct SavedBackupTests {
    private func item(_ id: String, _ kind: SavedItemKind, updated: Int64 = 1000) -> SavedItem {
        SavedItem(id: id, kind: kind, translationID: "nrsv", bookCode: "JHN", bookName: "John", bookOrder: 1, chapter: 3,
                  startVerse: "16", endVerse: "16", startIndex: 0, endIndex: 0, scriptureText: "For God so loved",
                  reference: "John 3:16", createdAt: 1, updatedAt: updated, noteText: kind == .note ? "n" : nil)
    }

    @Test func roundTripAndMergeWithoutDuplicates() throws {
        let backup = SavedBackup(items: [item("a", .note), item("a", .note), item("b", .bookmark)], tags: ["a": ["x"]], exportedAt: 5)
        let decoded = try SavedBackup.decode(try backup.encoded())
        #expect(decoded.newItems(existingIDs: ["b"]).map(\.id) == ["a"])
        #expect(decoded.tags["a"] == ["x"])
    }

    @Test func oldBackupWithoutTagsDecodes() throws {
        let json = #"{"format":"john-saved-backup","items":[]}"#
        #expect(try SavedBackup.decode(Data(json.utf8)).tags.isEmpty)
        #expect(throws: (any Error).self) { try SavedBackup.decode(Data(#"{"format":"x","items":[]}"#.utf8)) }
    }

    @Test func smartFoldersAndTags() {
        let now: Int64 = 10 * 24 * 3600 * 1000
        let old = item("o", .highlight, updated: 0), fresh = item("f", .highlight, updated: now - 1000)
        #expect(!SavedSmartFolder.highlightsThisWeek.matches(old, tags: [], nowMilliseconds: now))
        #expect(SavedSmartFolder.highlightsThisWeek.matches(fresh, tags: [], nowMilliseconds: now))
        #expect(!SavedSmartFolder.untagged.matches(fresh, tags: ["a"], nowMilliseconds: now))
        #expect(SavedTags.normalize(" #Faith ") == "faith")
        #expect(SavedTags.merge(["a": ["x"]], ["a": ["x", "y"]])["a"] == ["x", "y"])
    }

    @Test func tagStorePersists() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tags-\(UUID()).json")
        let store = SavedTagStore(url: url)
        try await store.set(["Hope", "hope", ""], for: "a")
        #expect(await SavedTagStore(url: url).tags(for: "a") == ["hope"])
    }

    @Test func corruptTagFileIsKeptAndNotOverwritten() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tags-\(UUID()).json")
        try Data("{not json".utf8).write(to: url)
        let store = SavedTagStore(url: url)
        #expect(await store.all().isEmpty)
        try await store.set(["hope"], for: "a")
        let kept = try Data(contentsOf: url.appendingPathExtension("corrupt"))
        #expect(String(decoding: kept, as: UTF8.self) == "{not json")
        #expect(await SavedTagStore(url: url).tags(for: "a") == ["hope"])
    }

    @Test func importKeepsNewerItem() {
        let backup = SavedBackup(items: [item("a", .note, updated: 5), item("b", .note, updated: 9),
                                         item("b", .note, updated: 12), item("c", .note, updated: 1)], tags: [:], exportedAt: 0)
        let apply = backup.itemsToApply(existing: [item("a", .note, updated: 7), item("b", .note, updated: 9)])
        #expect(apply.map(\.id) == ["b", "c"])
        #expect(apply.first?.updatedAt == 12)
    }

    @Test func unknownVersionIsRejected() {
        let json = #"{"format":"john-saved-backup","version":2,"items":[]}"#
        #expect(throws: (any Error).self) { try SavedBackup.decode(Data(json.utf8)) }
    }
}
