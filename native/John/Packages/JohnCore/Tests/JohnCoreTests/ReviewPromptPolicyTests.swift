import Foundation
import Testing
@testable import JohnCore

// Ways the rating prompt rule can fail. Each test maps to one entry.
//
// R1. The app asks a new person who has not yet prayed three times or opened it on seven days.
// R2. The app never asks a person who reached either threshold.
// R3. The app asks again inside 120 days.
// R4. The app never asks again after 120 days.
// R5. Day keys follow UTC instead of the person's zone, so a late-evening open counts as the next day.

@Suite("Review prompt policy")
struct ReviewPromptPolicyTests {
    let now = Date(timeIntervalSince1970: 1_792_800_000)

    @Test("R1: no prompt before either threshold")
    func tooEarly() {
        #expect(!ReviewPromptPolicy.shouldAsk(prayersCompleted: 2, distinctOpenDays: 6, lastAsked: nil, now: now))
    }

    @Test("R2: either threshold allows the first prompt")
    func thresholds() {
        #expect(ReviewPromptPolicy.shouldAsk(prayersCompleted: 3, distinctOpenDays: 1, lastAsked: nil, now: now))
        #expect(ReviewPromptPolicy.shouldAsk(prayersCompleted: 0, distinctOpenDays: 7, lastAsked: nil, now: now))
    }

    @Test("R3: no second prompt inside 120 days")
    func cooldown() {
        let asked = now.addingTimeInterval(-119 * 86_400)
        #expect(!ReviewPromptPolicy.shouldAsk(prayersCompleted: 9, distinctOpenDays: 30, lastAsked: asked, now: now))
    }

    @Test("R4: a prompt is allowed again after 120 days")
    func afterCooldown() {
        let asked = now.addingTimeInterval(-120 * 86_400)
        #expect(ReviewPromptPolicy.shouldAsk(prayersCompleted: 9, distinctOpenDays: 30, lastAsked: asked, now: now))
    }

    @Test("R5: day keys use the person's time zone")
    func localDay() throws {
        // 2026-10-24 03:30 UTC is still 2026-10-23 in Toronto.
        let instant = Date(timeIntervalSince1970: 1_792_812_600)
        let toronto = try #require(TimeZone(identifier: "America/Toronto"))
        #expect(ReviewPromptPolicy.dayKey(for: instant, timeZone: toronto) == "2026-10-23")
        #expect(ReviewPromptPolicy.dayKey(for: instant, timeZone: .gmt) == "2026-10-24")
    }
}
