import Testing
@testable import JohnCore

// Ways "The Fathers on today's Gospel" can fail. Each test maps to one entry.
//
// P1. A reference that crosses chapters ("Matthew 9:35–10:1, 5a, 6-8") gives the wrong chapter or verse.
// P2. A verse with a letter ("Luke 7:18b-23") does not parse.
// P3. A non-Gospel book or a malformed reference returns a result.
// P4. A space after the colon or a no-break space ("Matthew 15: 21-28") does not parse.
// P5. The day's Gospel is taken from the wrong reading (Palm Sunday has a procession Gospel first).
// L1. The Catena section that contains the verse is not chosen.
// L2. Overlapping sections (the source shares boundary verses) choose the later one.
// L3. A verse after the last Catena section of a chapter finds nothing.
// L4. A chapter with no Catena falls back to nothing, though another Father wrote on it.
// L5. A chapter no Father wrote on returns an entry.
// E1. A Catena comment's Father is not expanded ("Aug., de Cons. Ev.:" should be St Augustine).
// E2. A long comment is not cut, or is cut mid-word.
// E3. A comment with no recognised Father loses its text.
// E4. A section with only the Gospel text produces an empty excerpt.
// E5. The Gloss or a Pseudo- work is shown although a named Father comments in the same section.
// E6. The anonymous "Greek Ex." of the Luke and John volumes is shown although a named Father comments.

@Suite("Gospel Fathers")
struct GospelFathersTests {
    @Test("P1") func crossChapter() {
        #expect(GospelFathers.parse("Matthew 9:35–10:1, 5a, 6-8") == .init(bookCode: "MAT", chapter: 9, verse: 35))
    }
    @Test("P2") func verseLetter() {
        #expect(GospelFathers.parse("Luke 7:18b-23") == .init(bookCode: "LUK", chapter: 7, verse: 18))
    }
    @Test("P3") func notGospel() {
        #expect(GospelFathers.parse("Psalm 80:2-3") == nil)
        #expect(GospelFathers.parse("Mark") == nil)
        #expect(GospelFathers.parse("Mark 0:1") == nil)
    }
    @Test("P4") func spacing() {
        #expect(GospelFathers.parse("Matthew 15: 21-28") == .init(bookCode: "MAT", chapter: 15, verse: 21))
        #expect(GospelFathers.parse("John\u{00A0}1:1-18") == .init(bookCode: "JHN", chapter: 1, verse: 1))
    }
    @Test("P5") func lastGospel() throws {
        let data = #"{"title":"Palm Sunday","readings":[{"label":"Gospel at the procession","reference":"Mark 11:1-10"},{"label":"First reading","reference":"Isaiah 50:4-7"},{"label":"Gospel","reference":"Mark 14:1–15:47"}]}"#
        let entry = try JSONDecoder().decode(CalendarReadingsEntry.self, from: Data(data.utf8))
        #expect(GospelFathers.gospelReference(in: entry) == "Mark 14:1–15:47")
    }

    private func catena(_ index: Int, _ from: Int, _ to: Int) -> CommentaryEntry {
        CommentaryEntry(workID: "aquinas.catena-aurea-matthew", workTitle: "Catena Aurea: Matthew", sectionIndex: index,
                        sectionTitle: "Matthew 1:\(from)", collectionID: "aquinas", fromVerse: from, toVerse: to)
    }
    private let chrysostom = CommentaryEntry(workID: "chrysostom.homilies-on-matthew", workTitle: "Homilies", sectionIndex: 4,
                                              sectionTitle: "Homily 5", collectionID: "chrysostom")

    @Test("L1") func contains() {
        let index = ["MAT": ["1": [catena(0, 1, 1), catena(1, 2, 5), catena(2, 6, 8)]]]
        #expect(GospelFathers.entry(for: .init(bookCode: "MAT", chapter: 1, verse: 4), in: index)?.sectionIndex == 1)
    }
    @Test("L2") func overlap() {
        let index = ["MAT": ["1": [catena(2, 6, 8), catena(1, 3, 6)]]]
        #expect(GospelFathers.entry(for: .init(bookCode: "MAT", chapter: 1, verse: 6), in: index)?.sectionIndex == 1)
    }
    @Test("L3") func afterLast() {
        let index = ["MAT": ["1": [catena(0, 1, 5), catena(1, 6, 8)]]]
        #expect(GospelFathers.entry(for: .init(bookCode: "MAT", chapter: 1, verse: 12), in: index)?.sectionIndex == 1)
    }
    @Test("L4") func otherFather() {
        let index = ["LUK": ["1": [chrysostom]]]
        #expect(GospelFathers.entry(for: .init(bookCode: "LUK", chapter: 1, verse: 26), in: index)?.workID == chrysostom.workID)
    }
    @Test("L5") func nobody() {
        #expect(GospelFathers.entry(for: .init(bookCode: "LUK", chapter: 2, verse: 1), in: ["LUK": ["1": [chrysostom]]]) == nil)
    }
    @Test("E1") func father() {
        let e = GospelFathers.excerpt(from: ["1. The book of the generation.", "Aug., de Cons. Ev., ii, 1: Matthew wrote for the Jews."])
        #expect(e?.father == "St Augustine")
        #expect(e?.text == "Matthew wrote for the Jews.")
    }
    @Test("E2") func cutLong() {
        let long = String(repeating: "The word was made flesh and dwelt among us. ", count: 20)
        let e = GospelFathers.excerpt(from: ["v", "Chrys.: " + long], limit: 120)
        #expect(e?.father == "St John Chrysostom")
        #expect((e?.text.count ?? 0) <= 120)
        #expect(e?.text.hasSuffix(".") == true)
    }
    @Test("E3") func unknown() {
        let e = GospelFathers.excerpt(from: ["v", "Some reader says: the light shines."])
        #expect(e?.father == "The Fathers")
        #expect(e?.text == "Some reader says: the light shines.")
    }
    @Test("E5") func prefersFather() {
        let e = GospelFathers.excerpt(from: ["v", "Gloss.: A note.", "Pseudo-Chrys.: Another.", "Jerome: The Father speaks."])
        #expect(e?.father == "St Jerome")
        #expect(GospelFathers.excerpt(from: ["v", "Gloss.: Only a note."])?.father == "The Gloss")
    }
    @Test("E6") func greekExpositor() {
        let e = GospelFathers.excerpt(from: ["v", "Greek Ex: A note.", "Titus Bost: The Father speaks."])
        #expect(e?.father == "Titus of Bostra")
        #expect(GospelFathers.excerpt(from: ["v", "Greek Ex: Only this."])?.father == GospelFathers.anonymousGreek)
    }
    @Test("E4") func gospelOnly() {
        #expect(GospelFathers.excerpt(from: ["1. In the beginning."]) == nil)
    }
}

import Foundation
