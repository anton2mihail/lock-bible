import Foundation
import Testing
@testable import JohnCore

/// Lent and Holy Week (2.3.0). Failure list L1–L8 and H1 in docs/john/lent-holyweek-office-year-plan.md.
struct LentCalendarTests {
    private func date(_ text: String, _ zone: String = "America/Toronto") -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: zone)!
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text)!
    }

    private let toronto = TimeZone(identifier: "America/Toronto")!

    private func key(_ date: Date, _ zone: TimeZone) -> String {
        CompanionCalendar.dateKey(date, timeZone: zone)
    }

    /// L1: Ash Wednesday and Easter for several years, including late Easters.
    @Test func ashWednesdayAndEaster() {
        let expected: [Int: (String, String)] = [
            2027: ("2027-02-10", "2027-03-28"),
            2028: ("2028-03-01", "2028-04-16"),
            2038: ("2038-03-10", "2038-04-25"),
            2045: ("2045-02-22", "2045-04-09"),
            2026: ("2026-02-18", "2026-04-05"),
        ]
        for (year, (ash, easter)) in expected {
            #expect(LentCalendar.ashWednesday(year: year, timeZone: toronto).map { key($0, toronto) } == ash)
            #expect(CompanionCalendar.easterSunday(year: year, timeZone: toronto).map { key($0, toronto) } == easter)
        }
    }

    /// L2: the week of Lent, and nothing outside Lent.
    @Test func weeksOfLent() {
        #expect(LentCalendar.day(on: date("2027-02-10 09:00"), timeZone: toronto)?.key == "ash-wed")
        #expect(LentCalendar.day(on: date("2027-02-10 09:00"), timeZone: toronto)?.week == 0)
        #expect(LentCalendar.day(on: date("2027-02-13 09:00"), timeZone: toronto)?.key == "ash-sat")
        #expect(LentCalendar.day(on: date("2027-02-14 09:00"), timeZone: toronto)?.key == "lent1-sun")
        #expect(LentCalendar.day(on: date("2027-02-14 09:00"), timeZone: toronto)?.week == 1)
        #expect(LentCalendar.day(on: date("2027-02-20 09:00"), timeZone: toronto)?.key == "lent1-sat")
        #expect(LentCalendar.day(on: date("2027-03-14 09:00"), timeZone: toronto)?.key == "lent5-sun")
        #expect(LentCalendar.day(on: date("2027-03-20 09:00"), timeZone: toronto)?.key == "lent5-sat")
        #expect(LentCalendar.day(on: date("2027-02-09 12:00"), timeZone: toronto) == nil)
        #expect(LentCalendar.day(on: date("2027-03-29 09:00"), timeZone: toronto) == nil)
        #expect(LentCalendar.day(on: date("2027-07-01 09:00"), timeZone: toronto) == nil)
    }

    /// L3: every day from Ash Wednesday to Easter Sunday has its own key, 47 in all, none shared.
    @Test func everyDayHasOneKey() {
        var keys: [String] = []
        var day = LentCalendar.ashWednesday(year: 2027, timeZone: toronto)!
        for _ in 0..<47 {
            keys.append(LentCalendar.day(on: day, timeZone: toronto)!.key)
            day = CompanionCalendar.addDays(day, 1, timeZone: toronto)
        }
        #expect(keys == LentCalendar.allKeys)
        #expect(Set(keys).count == 47)
        #expect(LentCalendar.lentKeys.count == 39)
        #expect(LentCalendar.holyWeekKeys == ["palm-sun", "holy-mon", "holy-tue", "holy-wed", "holy-thu", "good-fri", "holy-sat", "easter-sun"])
    }

    /// L4: Sundays, Fridays and Passiontide.
    @Test func sundaysFridaysAndPassiontide() {
        let sunday = LentCalendar.day(on: date("2027-02-21 09:00"), timeZone: toronto)!
        #expect(sunday.isSunday && !sunday.isFriday)
        let friday = LentCalendar.day(on: date("2027-02-12 09:00"), timeZone: toronto)!
        #expect(friday.isFriday && friday.key == "ash-fri")
        #expect(!LentCalendar.day(on: date("2027-03-13 09:00"), timeZone: toronto)!.isPassiontide)
        #expect(LentCalendar.day(on: date("2027-03-14 09:00"), timeZone: toronto)!.isPassiontide)
        #expect(LentCalendar.day(on: date("2027-03-26 09:00"), timeZone: toronto)!.isPassiontide)
    }

    /// H1, H3: Holy Week runs from Palm Sunday (Easter − 7) to Easter Sunday; Good Friday is a Friday of Holy Week.
    @Test func holyWeek() {
        for year in [2027, 2028, 2038, 2045] {
            let easter = CompanionCalendar.easterSunday(year: year, timeZone: toronto)!
            let palm = CompanionCalendar.addDays(easter, -7, timeZone: toronto)
            #expect(LentCalendar.day(on: palm, timeZone: toronto)?.key == "palm-sun")
            #expect(LentCalendar.day(on: palm, timeZone: toronto)?.isHolyWeek == true)
            #expect(LentCalendar.day(on: CompanionCalendar.addDays(palm, -1, timeZone: toronto), timeZone: toronto)?.isHolyWeek == false)
            let goodFriday = LentCalendar.day(on: CompanionCalendar.addDays(easter, -2, timeZone: toronto), timeZone: toronto)!
            #expect(goodFriday.key == "good-fri" && goodFriday.isFriday && goodFriday.isHolyWeek)
            let easterDay = LentCalendar.day(on: easter, timeZone: toronto)!
            #expect(easterDay.key == "easter-sun" && easterDay.isEasterSunday && easterDay.isHolyWeek)
        }
    }

    /// L6: Lent and Advent never share a day.
    @Test func neverAdventAndLent() {
        var day = date("2027-01-01 12:00")
        for _ in 0..<730 {
            #expect(!(LentCalendar.day(on: day, timeZone: toronto) != nil && AdventCalendar.week(on: day, timeZone: toronto) != nil))
            day = CompanionCalendar.addDays(day, 1, timeZone: toronto)
        }
    }

    /// L7: 23:30 on Shrove Tuesday in Toronto is not Lent, and 00:05 on Ash Wednesday is, in every time zone.
    @Test func timeZoneEdges() {
        #expect(LentCalendar.day(on: date("2027-02-09 23:30"), timeZone: toronto) == nil)
        for zone in ["Pacific/Kiritimati", "Pacific/Pago_Pago", "America/Toronto", "UTC", "Asia/Kolkata"] {
            let tz = TimeZone(identifier: zone)!
            #expect(LentCalendar.day(on: date("2027-02-10 00:05", zone), timeZone: tz)?.key == "ash-wed")
            #expect(LentCalendar.day(on: date("2027-03-28 23:55", zone), timeZone: tz)?.key == "easter-sun")
            #expect(LentCalendar.day(on: date("2027-03-29 00:05", zone), timeZone: tz) == nil)
        }
    }

    /// L8: Leo's 14 sermons on Lent and the Passion (sections 191–204) read free from Ash Wednesday to Easter Sunday.
    @Test func leoIsFreeInLent() {
        let leo = LentCalendar.leoWorkID
        let shrove = date("2027-02-09 12:00"), ash = date("2027-02-10 00:05")
        let easter = date("2027-03-28 23:00"), monday = date("2027-03-29 09:00")
        for index in 191...204 {
            #expect(!FathersLibraryAccess.isSectionFree(workID: leo, index: index, on: shrove, timeZone: toronto))
            #expect(FathersLibraryAccess.isSectionFree(workID: leo, index: index, on: ash, timeZone: toronto))
            #expect(FathersLibraryAccess.isSectionFree(workID: leo, index: index, on: easter, timeZone: toronto))
            #expect(!FathersLibraryAccess.isSectionFree(workID: leo, index: index, on: monday, timeZone: toronto))
        }
        #expect(!FathersLibraryAccess.isSectionFree(workID: leo, index: 190, on: ash, timeZone: toronto))
        #expect(!FathersLibraryAccess.isSectionFree(workID: leo, index: 205, on: ash, timeZone: toronto))
        #expect(!FathersLibraryAccess.isSectionFree(workID: "augustine.the-city-of-god", index: 195, on: ash, timeZone: toronto))
        // The sample rules still apply on every date.
        #expect(FathersLibraryAccess.isSectionFree(workID: leo, index: 0, on: monday, timeZone: toronto))
    }

    /// The labels the Today row and the pages show.
    @Test func labels() {
        #expect(LentCalendar.day(on: date("2027-02-11 09:00"), timeZone: toronto)!.weekLabel == "The days after Ash Wednesday")
        #expect(LentCalendar.day(on: date("2027-02-14 09:00"), timeZone: toronto)!.weekLabel == "Week 1 of Lent")
        #expect(LentCalendar.day(on: date("2027-03-14 09:00"), timeZone: toronto)!.weekLabel == "Week 5 of Lent")
        #expect(LentCalendar.day(on: date("2027-03-21 09:00"), timeZone: toronto)!.weekLabel == "Holy Week")
        #expect(LentCalendar.day(on: date("2027-03-25 09:00"), timeZone: toronto)!.dayTitle == "Holy Thursday")
        #expect(LentCalendar.day(on: date("2027-03-26 09:00"), timeZone: toronto)!.dayTitle == "Good Friday")
        #expect(LentCalendar.day(on: date("2027-03-28 09:00"), timeZone: toronto)!.dayTitle == "Easter Sunday")
    }
}
