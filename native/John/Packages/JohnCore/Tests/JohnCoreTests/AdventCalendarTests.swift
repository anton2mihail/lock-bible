import Foundation
import Testing
@testable import JohnCore

// Ways the Advent calendar can fail. Each test maps to one entry.
//
// A1. The first Sunday of Advent is wrong when Christmas falls on a Sunday or a weekday.
// A2. A day of Advent gets the wrong week, or week 5.
// A3. A day before Advent or after 24 December reads as Advent.
// A4. The local date is taken in UTC, so a late-evening date in Toronto moves a day.
// O1. 17–23 December do not each have their own antiphon, in order.
// O2. 16 or 24 December, or another month's 17th, gets an antiphon.

@Suite("Advent calendar")
struct AdventCalendarTests {
    let toronto = TimeZone(identifier: "America/Toronto")!
    func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var c = Calendar(identifier: .gregorian); c.timeZone = toronto
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }
    func key(_ date: Date?) -> String? {
        guard let date else { return nil }
        let f = DateFormatter(); f.timeZone = toronto; f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }

    @Test("A1") func firstSunday() {
        #expect(key(AdventCalendar.firstSunday(year: 2026, timeZone: toronto)) == "2026-11-29") // Christmas on Friday
        #expect(key(AdventCalendar.firstSunday(year: 2027, timeZone: toronto)) == "2027-11-28") // Christmas on Saturday
        #expect(key(AdventCalendar.firstSunday(year: 2022, timeZone: toronto)) == "2022-11-27") // Christmas on Sunday
    }
    @Test("A2") func weeks() {
        #expect(AdventCalendar.week(on: day(2026, 11, 29), timeZone: toronto) == 1)
        #expect(AdventCalendar.week(on: day(2026, 12, 5), timeZone: toronto) == 1)
        #expect(AdventCalendar.week(on: day(2026, 12, 6), timeZone: toronto) == 2)
        #expect(AdventCalendar.week(on: day(2026, 12, 20), timeZone: toronto) == 4)
        #expect(AdventCalendar.week(on: day(2026, 12, 24), timeZone: toronto) == 4)
    }
    @Test("A3") func outside() {
        #expect(AdventCalendar.week(on: day(2026, 11, 28), timeZone: toronto) == nil)
        #expect(AdventCalendar.week(on: day(2026, 12, 25), timeZone: toronto) == nil)
        #expect(AdventCalendar.week(on: day(2027, 1, 3), timeZone: toronto) == nil)
    }
    @Test("A4") func localDay() {
        // 29 Nov 2026 at 23:30 in Toronto is already 30 Nov in UTC; still week 1 locally, and 28 Nov 23:30 is not Advent.
        #expect(AdventCalendar.week(on: day(2026, 11, 29, 23), timeZone: toronto) == 1)
        #expect(AdventCalendar.week(on: day(2026, 11, 28, 23), timeZone: toronto) == nil)
    }
    @Test("O1") func antiphons() {
        #expect(AdventCalendar.antiphons.map(\.day) == Array(17...23))
        #expect(AdventCalendar.antiphon(on: day(2026, 12, 17), timeZone: toronto)?.title == "O Wisdom")
        #expect(AdventCalendar.antiphon(on: day(2026, 12, 23), timeZone: toronto)?.title == "O Emmanuel")
    }
    @Test("O2") func noAntiphon() {
        #expect(AdventCalendar.antiphon(on: day(2026, 12, 16), timeZone: toronto) == nil)
        #expect(AdventCalendar.antiphon(on: day(2026, 12, 24), timeZone: toronto) == nil)
        #expect(AdventCalendar.antiphon(on: day(2026, 11, 17), timeZone: toronto) == nil)
    }
}
