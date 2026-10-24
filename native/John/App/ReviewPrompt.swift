import Foundation
import JohnCore

/// Counts what the rating rule needs, in UserDefaults on this device only. See `ReviewPromptPolicy`.
@MainActor enum ReviewPrompt {
    private static let prayersKey = "john.review.prayersCompleted"
    private static let openDaysKey = "john.review.openDays"
    private static let lastOpenDayKey = "john.review.lastOpenDay"
    private static let lastAskedKey = "john.review.lastAskedAt"

    /// Call when the app becomes active. Counts each local calendar day once.
    static func recordOpen(defaults: UserDefaults = .standard, now: Date = Date(), timeZone: TimeZone = .autoupdatingCurrent) {
        let key = ReviewPromptPolicy.dayKey(for: now, timeZone: timeZone)
        guard defaults.string(forKey: lastOpenDayKey) != key else { return }
        defaults.set(key, forKey: lastOpenDayKey)
        defaults.set(defaults.integer(forKey: openDaysKey) + 1, forKey: openDaysKey)
    }

    /// Call right after a person finishes a Rosary or a novena day. Calls `ask` when the rule allows it.
    static func prayerCompleted(defaults: UserDefaults = .standard, now: Date = Date(), ask: () -> Void) {
        #if DEBUG
        // Debug builds (simulator work, UI tests, screenshots) never show the system rating sheet,
        // unless `-JohnReviewPromptEnabled` is passed to check the prompt by hand.
        guard ProcessInfo.processInfo.arguments.contains("-JohnReviewPromptEnabled") else { return }
        #endif
        let prayers = defaults.integer(forKey: prayersKey) + 1
        defaults.set(prayers, forKey: prayersKey)
        let lastAsked = defaults.object(forKey: lastAskedKey) as? Date
        guard ReviewPromptPolicy.shouldAsk(prayersCompleted: prayers,
                                           distinctOpenDays: defaults.integer(forKey: openDaysKey),
                                           lastAsked: lastAsked, now: now) else { return }
        defaults.set(now, forKey: lastAskedKey)
        ask()
    }
}
