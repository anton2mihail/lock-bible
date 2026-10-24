import Testing
@testable import JohnCore

// Ways the library access rules can fail. Each test below maps to one entry.
//
// F1. A paying reader is never affected here, but a non-paying reader could read a paid section
//     because an index past the sample is treated as free.
// F2. The free sample could be missing: section 0 of a paid work reads as locked.
// F3. A negative or garbage index could read as free.
// F4. The whole Apostolic Fathers collection could lock after its first section.
// F5. The Confessions could lock after its first section.
// F6. A work whose id only starts with a free collection's name (no dot boundary) could read as free.
// F7. A work with a single section could show an unlock notice it never needs.
// F8. Someone who installed before the purchase existed (build 28 or lower) could lose the library.
// F9. Someone who installed build 29 or later could get the library free.
// F10. A sandbox, TestFlight or Xcode install reports "1.0" and could be grandfathered by mistake.
// F11. An empty, non-numeric or oddly formatted original version could grandfather by mistake.

@Suite("Fathers library access")
struct FathersLibraryAccessTests {
    @Test("F1: sections past the sample are locked in a paid work")
    func pastSampleLocked() {
        #expect(!FathersLibraryAccess.isSectionFree(workID: "ambrose.on-the-duties-of-the-clergy", index: 1))
        #expect(!FathersLibraryAccess.isSectionFree(workID: "aquinas.first-part", index: 50))
    }

    @Test("F2: the first section of every work is free")
    func sampleFree() {
        #expect(FathersLibraryAccess.isSectionFree(workID: "ambrose.on-the-duties-of-the-clergy", index: 0))
    }

    @Test("F3: a negative index is not free")
    func negativeIndex() {
        #expect(!FathersLibraryAccess.isSectionFree(workID: "ambrose.on-the-duties-of-the-clergy", index: -1))
    }

    @Test("F4: the Apostolic Fathers are free throughout")
    func apostolicFree() {
        #expect(FathersLibraryAccess.isSectionFree(workID: "apostolic-fathers.the-didache", index: 7))
    }

    @Test("F5: the Confessions are free throughout")
    func confessionsFree() {
        #expect(FathersLibraryAccess.isSectionFree(workID: "augustine.the-confessions", index: 12))
        #expect(!FathersLibraryAccess.isSectionFree(workID: "augustine.the-city-of-god", index: 12))
    }

    @Test("F6: a look-alike collection prefix is not free")
    func lookAlikePrefix() {
        #expect(!FathersLibraryAccess.isSectionFree(workID: "apostolic-fathers-extra.work", index: 3))
        #expect(!FathersLibraryAccess.isSectionFree(workID: "apostolic-fathers", index: 3))
        #expect(!FathersLibraryAccess.isSectionFree(workID: ".apostolic-fathers", index: 3))
    }

    @Test("F7: single-section works and free works need no unlock notice")
    func wholeWorkFree() {
        #expect(FathersLibraryAccess.isWorkFree(workID: "leo-great.letters", sectionCount: 1))
        #expect(FathersLibraryAccess.isWorkFree(workID: "augustine.the-confessions", sectionCount: 13))
        #expect(!FathersLibraryAccess.isWorkFree(workID: "augustine.the-city-of-god", sectionCount: 22))
    }

    @Test("F8: installs before build 29 are grandfathered", arguments: ["13", "18", "20", "28", "28.1"])
    func earlyInstalls(version: String) {
        #expect(FathersLibraryAccess.isGrandfathered(originalAppVersion: version, environment: .production))
    }

    @Test("F9: installs from build 29 on are not grandfathered", arguments: ["29", "30", "112"])
    func lateInstalls(version: String) {
        #expect(!FathersLibraryAccess.isGrandfathered(originalAppVersion: version, environment: .production))
    }

    @Test("F10: test environments never grandfather")
    func testEnvironments() {
        #expect(!FathersLibraryAccess.isGrandfathered(originalAppVersion: "1.0", environment: .sandbox))
        #expect(!FathersLibraryAccess.isGrandfathered(originalAppVersion: "13", environment: .xcode))
    }

    @Test("F11: malformed versions never grandfather", arguments: ["", " ", "abc", "-5", "２０", "1e3"])
    func malformed(version: String) {
        #expect(!FathersLibraryAccess.isGrandfathered(originalAppVersion: version, environment: .production))
    }
}
