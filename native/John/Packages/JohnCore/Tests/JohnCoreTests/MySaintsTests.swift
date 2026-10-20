import Foundation
import Testing
@testable import JohnCore

struct MySaintsTests {
    private var root: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<7 { url.deleteLastPathComponent() }
        return url
    }
    private func saints() throws -> [PersonalSaint] {
        try JSONDecoder().decode([PersonalSaint].self, from: Data(contentsOf: root.appendingPathComponent("src/services/companion/data/my-saints.json")))
    }
    private func date(_ key: String) -> Date { CompanionCalendar.parseDate(key, fallback: .now, timeZone: .gmt) }

    @Test func everyReviewedIdentityResolvesToTheBundledCalendar() throws {
        let values = try saints()
        #expect(values.count == 9)
        #expect(Set(values.map(\.id)).count == values.count)
        for saint in values {
            for observance in saint.commemorations {
                let catalog = try JSONDecoder().decode(SaintsCalendar.self, from: Data(contentsOf: root.appendingPathComponent("src/services/companion/data/saints-\(observance.tradition).json")))
                let entry = try #require(catalog.entries.first { $0.id == observance.entryID })
                #expect(entry.monthDay == observance.monthDay)
                #expect(entry.sourceURL == observance.sourceURL)
                #expect(entry.calendarURL == observance.calendarURL)
                #expect((entry.summary ?? entry.excerpt) == observance.account)
            }
        }
        #expect(values.first { $0.id == "st-therese" }?.artwork == nil)
        #expect(values.first { $0.id == "st-padre-pio" }?.artwork == nil)
    }

    @Test func oldStateDecodesWithoutLosingExistingPreferences() throws {
        let data = try JSONEncoder().encode(NativePersistentState(themeScheme: "dark", favoritePrayerIDs: ["morning"]))
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "saints")
        let decoded = try JSONDecoder().decode(NativePersistentState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.mySaints.profiles.isEmpty)
        #expect(decoded.themeScheme == "dark")
        #expect(decoded.favoritePrayerIDs == ["morning"])
    }

    @Test func unsavingDoesNotDeleteNotesRemindersOrWidgetChoice() throws {
        var state = NativePersistentState()
        var profile = SaintProfile()
        profile.saved = true; profile.reason = "Private reason"; profile.reminderEnabled = true
        profile.notes = [SaintNote(kind: "thanks", text: "Private thanks")]
        state.apply(.setSaintProfile(id: "st-joseph", value: profile))
        state.apply(.setSaintWidget(id: "st-joseph", quiet: true))
        profile.saved = false
        state.apply(.setSaintProfile(id: "st-joseph", value: profile))
        let decoded = try JSONDecoder().decode(NativePersistentState.self, from: JSONEncoder().encode(state))
        #expect(decoded.mySaints.profiles["st-joseph"]?.notes.count == 1)
        #expect(decoded.mySaints.profiles["st-joseph"]?.reminderEnabled == true)
        #expect(decoded.mySaints.widgetSaintID == "st-joseph")
        #expect(decoded.mySaints.widgetQuiet)
    }

    @Test func widgetProjectionContainsNoPrivateState() throws {
        let saint = try #require(saints().first)
        let projection = SaintWidgetContent(saint: saint, observance: saint.commemorations[0])
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(projection)) as? [String: Any])
        #expect(Set(object.keys) == Set(["id", "name", "artwork", "text", "source", "monthDay", "calendarName"]))
    }

    @Test func datesCoverTodayYearBoundaryLeapYearsAndDifferentTraditions() throws {
        #expect(SaintDates.nextOccurrence(monthDay: "03-19", from: date("2027-03-19"), timeZone: .gmt) == date("2027-03-19"))
        #expect(SaintDates.nextOccurrence(monthDay: "03-19", from: date("2027-03-20"), timeZone: .gmt) == date("2028-03-19"))
        #expect(SaintDates.nextOccurrence(monthDay: "02-29", from: date("2027-01-01"), timeZone: .gmt) == date("2028-02-29"))
        #expect(SaintDates.nextOccurrence(monthDay: "01-01", from: date("2027-12-31"), timeZone: .gmt) == date("2028-01-01"))
        let benedict = try #require(saints().first { $0.id == "st-benedict" })
        #expect(Set(benedict.commemorations.map(\.monthDay)) == ["03-14", "07-11"])
    }

    @Test func reminderAfterTodaysTimeMovesToNextYearAndPlanNeverMarksPrayer() throws {
        let zone = try #require(TimeZone(identifier: "America/Toronto"))
        let now = try #require(ISO8601DateFormatter().date(from: "2027-03-19T13:00:00Z"))
        let next = try #require(SaintDates.reminderDate(monthDay: "03-19", hour: 8, minute: 0, after: now, timeZone: zone))
        #expect(CompanionCalendar.dateKey(next, timeZone: zone) == "2028-03-19")
        #expect(CompanionCalendar.gregorianCalendar(timeZone: zone).component(.hour, from: next) == 8)
        var profile = SaintProfile(); profile.plannedFeastDate = "2027-03-19"
        #expect(!SaintDates.planIsDue(profile, now: date("2027-03-09"), timeZone: .gmt))
        #expect(SaintDates.planIsDue(profile, now: date("2027-03-10"), timeZone: .gmt))
        #expect(SaintDates.planIsDue(profile, now: date("2027-03-18"), timeZone: .gmt))
        #expect(!SaintDates.planIsDue(profile, now: date("2027-03-19"), timeZone: .gmt))
        var state = NativePersistentState()
        state.apply(.setSaintProfile(id: "st-joseph", value: profile))
        #expect(state.novenaProgress.isEmpty)
    }
}
