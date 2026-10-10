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
