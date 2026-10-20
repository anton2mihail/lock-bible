import Foundation
import Testing
@testable import JohnCore

struct SaintsCalendarTests {
    private func catalogs() throws -> [SaintsCalendar] {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<7 { root.deleteLastPathComponent() }
        return try ["vatican", "byzantine"].map {
            let url = root.appendingPathComponent("src/services/companion/data/saints-\($0).json")
            return try JSONDecoder().decode(SaintsCalendar.self, from: Data(contentsOf: url))
        }
    }

    private func date(_ key: String, zone: TimeZone = .gmt) -> Date {
        CompanionCalendar.parseDate(key, fallback: Date(), timeZone: zone)
    }

    @Test func completeSourceCalendarsDecodeAndValidate() throws {
        let values = try catalogs()
        for catalog in values {
            try catalog.validate()
            #expect(catalog.entries.count > 400)
            for key in catalog.checkedDates {
                #expect(String(CompanionCalendar.dateKey(date("2024-\(key)"), timeZone: .gmt).suffix(5)) == key)
            }
        }
    }

    @Test func differentTraditionsKeepDifferentDates() throws {
        let values = try catalogs()
        let roman = values[0], byzantine = values[1]
        #expect(roman.entries(on: date("2026-07-11"), timeZone: .gmt).contains { $0.name.contains("Benedict") })
        #expect(byzantine.entries(on: date("2026-03-14"), timeZone: .gmt).contains { $0.name.contains("Benedict") })
        // July 11 also has a relic commemoration in Benedictine communities.
        #expect(byzantine.entries(on: date("2026-07-11"), timeZone: .gmt).contains {
            $0.name.contains("Benedictine communities")
        })
    }

    @Test func cassianUsesOfficialNonLeapYearRule() throws {
        let catalog = try catalogs()[1]
        #expect(catalog.entries(on: date("2027-02-28"), timeZone: .gmt).contains { $0.name.contains("Cassian") })
        #expect(!catalog.entries(on: date("2028-02-28"), timeZone: .gmt).contains { $0.name.contains("Cassian") })
        #expect(catalog.entries(on: date("2028-02-29"), timeZone: .gmt).contains { $0.name.contains("Cassian") })
    }

    @Test func biographiesKeepCalendarDatesAndSourceLanguages() throws {
        let values = try catalogs()
        let schuster = try #require(values[0].entries.first { $0.name.contains("Schuster") })
        #expect(schuster.monthDay == "08-31")
        #expect(schuster.sourceURL.contains("/08/30"))
        #expect(schuster.calendarURL.contains("/08/31"))
        #expect(schuster.sourceLanguage == "it")
        #expect(schuster.summary?.contains("Milan") == true)
        #expect(schuster.excerpt.isEmpty)
        #expect(values[1].entries.contains { $0.monthDay == "07-17" && $0.name.contains("Gojdič") })
        #expect(!values[1].entries.contains { $0.name.contains("Tone 2") })
    }

    @Test func localDateAndYearBoundaryChooseCorrectSaints() throws {
        let catalog = try catalogs()[0]
        let instant = ISO8601DateFormatter().date(from: "2027-01-01T02:00:00Z")!
        let toronto = TimeZone(identifier: "America/Toronto")!
        let beforeMidnight = catalog.entries(on: instant, timeZone: toronto)
        #expect(beforeMidnight.allSatisfy { $0.monthDay == "12-31" })
        #expect(catalog.entries(on: instant, timeZone: .gmt).allSatisfy { $0.monthDay == "01-01" })
    }

    @Test func noticeIncludesEveryCommemorationAndLabelsGospel() throws {
        let values = try catalogs()
        let day = date("2035-09-01") // Works beyond the finite Mass readings catalog.
        let body = SaintsNotice.body(calendars: values, date: day, timeZone: .gmt, gospel: "Luke 4:16–30")
        for catalog in values {
            for saint in catalog.entries(on: day, timeZone: .gmt) {
                #expect(body.contains(saint.name))
            }
        }
        #expect(body.contains("Byzantine Catholic · Ruthenian"))
        #expect(body.contains("Roman Rite Gospel: Luke 4:16–30"))
        #expect(!SaintsNotice.body(calendars: values, date: day, timeZone: .gmt, gospel: nil).contains("Gospel:"))
    }
}
