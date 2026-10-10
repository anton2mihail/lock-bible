import AppIntents
import Foundation
import WidgetKit

/// Keys in the app group defaults. The app and the widget extension share this file.
/// The older keys (`translationId`, `scope`, `intervalMinutes`, `abbreviation`, `attribution`) do not change.
enum WidgetHandoff {
    static let readKey = "b4b.progress.read"
    static let totalKey = "b4b.progress.total"
    static let todayKey = "b4b.progress.today"
    static let pendingDoneKey = "b4b.progress.pendingDone"
    static let pendingRouteKey = "b4b.pendingRoute"
    static let progressWidgetKind = "ReadingProgressWidget"

    static var group: String {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? "group.com.nrsv.verse"
    }
    static var defaults: UserDefaults? { UserDefaults(suiteName: group) }
}

/// A button in the progress widget. It marks the chapters for today as read. The widget shows the result at once.
/// The app saves the chapters to the reading progress file when it opens next.
struct MarkTodayReadIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark today's reading done"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        if let defaults = WidgetHandoff.defaults {
            let today = defaults.array(forKey: WidgetHandoff.todayKey) as? [Int] ?? []
            let pending = defaults.array(forKey: WidgetHandoff.pendingDoneKey) as? [Int] ?? []
            defaults.set(Array(Set(pending + today)).sorted(), forKey: WidgetHandoff.pendingDoneKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetHandoff.progressWidgetKind)
        return .result()
    }
}

/// Control Center actions. Each one opens the app and leaves a route for the app to open.
struct OpenRosaryControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Open the Rosary"
    static let openAppWhenRun = true
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        WidgetHandoff.defaults?.set("nrsv://pray/rosary", forKey: WidgetHandoff.pendingRouteKey)
        return .result()
    }
}

struct StartLectioControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a Lectio timer"
    static let openAppWhenRun = true
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        WidgetHandoff.defaults?.set("nrsv://pray/lectio", forKey: WidgetHandoff.pendingRouteKey)
        return .result()
    }
}
