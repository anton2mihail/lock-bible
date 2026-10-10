import ActivityKit
import Foundation
import Observation

/// Starts, updates, and ends the prayer Live Activity from the app.
/// It does nothing when the user turned Live Activities off in Settings.
@MainActor @Observable
final class PrayerActivityController {
    static let shared = PrayerActivityController()

    enum Status: String { case idle, active, unavailable }

    private(set) var status: Status = .idle
    private(set) var kind: PrayerActivityAttributes.Kind?
    private var activity: Activity<PrayerActivityAttributes>?

    func startOrUpdate(kind: PrayerActivityAttributes.Kind, title: String, state: PrayerActivityAttributes.ContentState) {
        if let activity, self.kind == kind {
            let content = ActivityContent(state: state, staleDate: state.endDate)
            // ActivityKit calls are thread safe. `Activity` is not `Sendable` in the SDK.
            nonisolated(unsafe) let live = activity
            Task { await live.update(content) }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = .unavailable
            return
        }
        end()
        do {
            let content = ActivityContent(state: state, staleDate: state.endDate)
            activity = try Activity.request(attributes: PrayerActivityAttributes(kind: kind, title: title),
                                            content: content, pushType: nil)
            self.kind = kind
            status = .active
        } catch {
            status = .unavailable
        }
    }

    func end() {
        let finished = activity
        activity = nil
        kind = nil
        status = .idle
        guard let finished else { return }
        nonisolated(unsafe) let live = finished
        Task { await live.end(nil, dismissalPolicy: .immediate) }
    }

    /// Ends an activity that a previous launch left. Call it once at launch.
    func endStale() {
        for stale in Activity<PrayerActivityAttributes>.activities where stale.id != activity?.id {
            nonisolated(unsafe) let live = stale
            Task { await live.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
