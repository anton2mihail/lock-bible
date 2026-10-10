import Foundation
import Testing
@testable import JohnCore

struct ReadingProgressTests {
    @Test func planDaysCoverAllChapters() {
        for plan in ReadingPlan.all {
            let all = (0..<plan.days).flatMap { plan.chapters(forDay: $0) }
            #expect(all == Array(1...plan.chapterCount))
        }
        #expect(ReadingPlan.plan(id: "john-21")?.chapters(forDay: 4) == [5])
        #expect(ReadingPlan.plan(id: "john-21")?.chapters(forDay: 99) == [21])
    }

    @Test func dayIndexCounts() {
        let zone = TimeZone(identifier: "UTC")!
        let date = Date(timeIntervalSince1970: 1_767_225_600 + 3 * 86_400 + 3_600) // 2026-01-04 01:00 UTC
        #expect(ReadingProgressMath.dayKey(date, timeZone: zone) == "2026-01-04")
        #expect(ReadingProgressMath.dayIndex(startKey: "2026-01-01", today: date, timeZone: zone) == 3)
        #expect(ReadingProgressMath.dayIndex(startKey: "2026-02-01", today: date, timeZone: zone) == 0)
    }

    @Test func storePersistsAndResets() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rp-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ReadingProgressStore(url: url)
        try await store.setRead(true, book: "JHN", chapter: 3)
        try await store.setRead(true, book: "JHN", chapter: 1)
        try await store.startPlan("john-21", startKey: "2026-01-01")
        try await store.setReminder(ReadingReminderSettings(enabled: true, hour: 7, minute: 30))
        let reopened = ReadingProgressStore(url: url)
        let data = await reopened.data()
        #expect(data.read["JHN"] == [1, 3])
        #expect(data.planID == "john-21")
        #expect(data.totalRead(counts: ["JHN": 21]) == 2)
        try await reopened.reset()
        let after = await reopened.data()
        #expect(after.read.isEmpty && after.planID == nil && after.reminder?.enabled == true)
    }

    @Test func oldFileWithoutNewFieldsDecodes() throws {
        let json = Data(#"{"version":1,"read":{"JHN":[2]}}"#.utf8)
        let value = try JSONDecoder().decode(ReadingProgressData.self, from: json)
        #expect(value.readChapters("JHN") == [2])
    }
}
