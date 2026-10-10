import ActivityKit
import Foundation

/// The Live Activity for the Rosary and the Lectio timer. The app and the widget extension share this file.
struct PrayerActivityAttributes: ActivityAttributes {
    enum Kind: String, Codable, Hashable, Sendable {
        case rosary
        case lectio
    }

    struct ContentState: Codable, Hashable, Sendable {
        var stepTitle: String
        var stepIndex: Int
        var stepCount: Int
        /// The end of the quiet minute. `nil` for the Rosary.
        var endDate: Date?
    }

    var kind: Kind
    var title: String
}
