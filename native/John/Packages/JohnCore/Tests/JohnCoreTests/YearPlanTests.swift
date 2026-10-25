import Foundation
import Testing
@testable import JohnCore

/// "A Year with the Fathers" (2.3.0). Failure list Y3, Y4, Y7 in docs/john/lent-holyweek-office-year-plan.md.
struct YearPlanTests {
    private static let planURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("src/services/works/data/year-plan.json")

    private func date(_ text: String, _ zone: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: zone)!
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text)!
    }

    @Test func loadsThePlanFile() throws {
        let plan = try YearPlan.load(from: Self.planURL)
        #expect(plan.days.count == 365)
        #expect(plan.freeDays == 7)
        #expect(plan.day(1)?.date == "2027-01-01")
        #expect(plan.day(365)?.date == "2027-12-31")
        #expect(plan.day(87)?.feast == "Easter Sunday")
        #expect(plan.day(0) == nil && plan.day(366) == nil)
    }

    /// Y7: "Join today" on Ash Wednesday gives Day 41 in every time zone.
    @Test func joinTodayGivesTheSameDayEverywhere() {
        for zone in ["Pacific/Kiritimati", "Pacific/Pago_Pago", "America/Toronto", "UTC", "Asia/Kolkata"] {
            let tz = TimeZone(identifier: zone)!
            #expect(YearPlanSchedule.dayOfYear(date("2027-02-10 00:05", zone), timeZone: tz) == 41)
            #expect(YearPlanSchedule.dayOfYear(date("2027-02-10 23:55", zone), timeZone: tz) == 41)
        }
        let toronto = TimeZone(identifier: "America/Toronto")!
        let newYearsEve = date("2026-12-31 23:30", "America/Toronto")
        #expect(YearPlanSchedule.isBeforeYear(newYearsEve, timeZone: toronto))
        #expect(YearPlanSchedule.dayOfYear(newYearsEve, timeZone: toronto) == nil)
        #expect(YearPlanSchedule.dayOfYear(date("2027-01-01 00:00", "America/Toronto"), timeZone: toronto) == 1)
        #expect(YearPlanSchedule.dayOfYear(date("2027-12-31 23:59", "America/Toronto"), timeZone: toronto) == 365)
        #expect(YearPlanSchedule.dayOfYear(date("2028-01-01 00:00", "America/Toronto"), timeZone: toronto) == nil)
    }

    /// Y3: days count by calendar day across daylight-saving changes, and a missed day does not move the plan.
    @Test func dayNumberCountsCalendarDays() {
        let toronto = TimeZone(identifier: "America/Toronto")!
        // Clocks go forward on 14 March 2027 and back on 7 November 2027.
        #expect(YearPlanSchedule.dayNumber(startKey: "2027-03-01", today: date("2027-03-15 00:30", "America/Toronto"), timeZone: toronto) == 15)
        #expect(YearPlanSchedule.dayNumber(startKey: "2027-11-01", today: date("2027-11-08 23:30", "America/Toronto"), timeZone: toronto) == 8)
        #expect(YearPlanSchedule.dayNumber(startKey: "2027-01-01", today: date("2026-12-31 12:00", "America/Toronto"), timeZone: toronto) == 0)
        #expect(YearPlanSchedule.missedDays(read: [1, 2, 4], today: 6) == [3, 5])
        #expect(YearPlanSchedule.missedDays(read: [], today: 1) == [])
        #expect(YearPlanSchedule.missedDays(read: [], today: 400).count == 365)
        // Joined on Ash Wednesday: the 40 days before are open to read, not missed.
        #expect(YearPlanSchedule.missedDays(read: [], today: 41, joinedAt: 41) == [])
        #expect(YearPlanSchedule.missedDays(read: [41], today: 44, joinedAt: 41) == [42, 43])
    }

    @Test func startChoices() {
        let toronto = TimeZone(identifier: "America/Toronto")!
        let january = date("2027-01-15 09:00", "America/Toronto")
        let march = date("2027-03-02 09:00", "America/Toronto")
        let december = date("2026-12-20 09:00", "America/Toronto")
        #expect(YearPlanSchedule.suggestedStart(january, timeZone: toronto) == .joinToday)
        #expect(YearPlanSchedule.suggestedStart(march, timeZone: toronto) == .beginAtDayOne)
        #expect(YearPlanSchedule.suggestedStart(december, timeZone: toronto) == .beginAtDayOne)
        #expect(YearPlanSchedule.startKey(.joinToday, today: march, timeZone: toronto) == "2027-01-01")
        #expect(YearPlanSchedule.startKey(.beginAtDayOne, today: march, timeZone: toronto) == "2027-03-02")
        // Before the year begins, "Begin now" starts Day 1 today.
        #expect(YearPlanSchedule.startKey(.joinToday, today: december, timeZone: toronto) == "2026-12-20")
    }

    /// Y4: Day 8 and later need the library purchase; the first seven days never do.
    @Test func dayEightNeedsTheLibrary() {
        #expect(!YearPlanSchedule.isLocked(day: 7, freeDays: 7, libraryUnlocked: false))
        #expect(YearPlanSchedule.isLocked(day: 8, freeDays: 7, libraryUnlocked: false))
        #expect(!YearPlanSchedule.isLocked(day: 8, freeDays: 7, libraryUnlocked: true))
        #expect(!YearPlanSchedule.isLocked(day: 365, freeDays: 7, libraryUnlocked: true))
    }

    @Test func remindersNameTheirDaysAndStopAtTheEnd() {
        let toronto = TimeZone(identifier: "America/Toronto")!
        let early = YearPlanSchedule.reminderDates(startKey: "2027-01-01", now: date("2027-01-01 07:00", "America/Toronto"),
                                                   hour: 8, minute: 0, timeZone: toronto, count: 3)
        #expect(early.map(\.day) == [1, 2, 3])
        #expect(early.first?.date == date("2027-01-01 08:00", "America/Toronto"))
        let late = YearPlanSchedule.reminderDates(startKey: "2027-01-01", now: date("2027-01-01 09:00", "America/Toronto"),
                                                  hour: 8, minute: 0, timeZone: toronto, count: 2)
        #expect(late.map(\.day) == [2, 3])
        let before = YearPlanSchedule.reminderDates(startKey: "2027-01-01", now: date("2026-12-30 09:00", "America/Toronto"),
                                                    hour: 8, minute: 0, timeZone: toronto, count: 2)
        #expect(before.map(\.day) == [1, 2])
        let end = YearPlanSchedule.reminderDates(startKey: "2027-01-01", now: date("2027-12-30 07:00", "America/Toronto"),
                                                 hour: 8, minute: 0, timeZone: toronto, count: 14)
        #expect(end.map(\.day) == [364, 365])
    }

    @Test func progressKeepsTheYearAcrossAReset() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("yp-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ReadingProgressStore(url: url)
        try await store.startYear(startKey: "2027-01-01", joinedKey: "2027-02-10")
        try await store.setRead(true, book: YearPlanSchedule.progressKey, chapter: 1)
        try await store.setRead(true, book: "JHN", chapter: 2)
        try await store.setYearReminder(ReadingReminderSettings(enabled: true, hour: 7, minute: 15))
        let reopened = ReadingProgressStore(url: url)
        var data = await reopened.data()
        #expect(data.yearStartKey == "2027-01-01" && data.yearJoinedKey == "2027-02-10")
        #expect(data.yearDaysRead == [1] && data.yearReminder?.hour == 7)
        try await reopened.reset()
        data = await reopened.data()
        #expect(data.read["JHN"] == nil && data.yearDaysRead == [1] && data.yearStartKey == "2027-01-01")
    }
}
