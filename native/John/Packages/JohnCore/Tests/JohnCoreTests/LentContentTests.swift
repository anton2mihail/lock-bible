import Foundation
import Testing
@testable import JohnCore

/// The Lent data file (2.3.0). Failure list L3, L5, H2, H4 in docs/john/lent-holyweek-office-year-plan.md.
struct LentContentTests {
    private static let fileURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("src/services/lent/data/lent.json")

    private func content() throws -> LentContent { try LentContent.load(from: Self.fileURL) }

    private func isScan(_ url: String) -> Bool {
        ["missal0000vari", "manualofprayersf00cath", "TheMassEveryDayOfTheYear"].contains { url.hasPrefix("https://archive.org/details/\($0)/page/n") }
    }

    /// L3: every day from Ash Wednesday to Easter Sunday has exactly its own Collect, with a page and a scan.
    @Test func everyDayHasACollect() throws {
        let lent = try content()
        #expect(Set(lent.collects.keys) == Set(LentCalendar.allKeys))
        for key in LentCalendar.allKeys {
            let collect = try #require(lent.collects[key])
            #expect(collect.text.count > 40)
            #expect(collect.page > 100 && collect.page < 400)
            #expect(isScan(collect.scan))
        }
        // No two days quote the same text unless the Missal prints it twice; Sundays differ from weekdays.
        #expect(lent.collects["lent1-sun"]?.text != lent.collects["lent1-mon"]?.text)
    }

    /// H2: every day of Holy Week has its texts, each with pages and scans, and no two days share a section.
    @Test func holyWeekDays() throws {
        let lent = try content()
        #expect(lent.holyWeek.map(\.key) == LentCalendar.holyWeekKeys)
        for day in lent.holyWeek {
            #expect(!day.sections.isEmpty)
            #expect(Set(day.sections.map(\.id)).count == day.sections.count)
            for section in day.sections {
                #expect(!section.paragraphs.isEmpty && section.paragraphs.allSatisfy { !$0.isEmpty })
                #expect(!section.pages.isEmpty && section.scans.allSatisfy(isScan))
            }
        }
        let good = try #require(lent.holyWeekDay("good-fri"))
        #expect(good.sections.contains { $0.kind == "solemn-prayers" })
        #expect(good.sections.contains { $0.kind == "reproaches" })
        #expect(try #require(lent.holyWeekDay("holy-sat")).sections.contains { $0.id == "exsultet" })
        #expect(try #require(lent.holyWeekDay("easter-sun")).sections.contains { $0.kind == "sequence" })
    }

    /// L5: 14 Stations, each with its painting, text and page.
    @Test func fourteenStations() throws {
        let stations = try content().stations
        #expect(stations.stations.map(\.number) == Array(1...14))
        #expect(!stations.opening.paragraphs.isEmpty)
        for station in stations.stations {
            #expect(station.painting == String(format: "stations-%02d", station.number))
            #expect(!station.meditation.isEmpty && !station.prayer.isEmpty)
            #expect(station.verse.count == 4)
            #expect(!station.pages.isEmpty && station.scans.allSatisfy(isScan))
        }
    }

    @Test func penitentialPsalms() throws {
        #expect(try content().penitentialPsalms == [6, 31, 37, 50, 101, 129, 142])
    }
}
