import Foundation
import JohnCore

enum CompanionRoute: Hashable, Sendable {
    case prayerHome
    case daily(dateKey: String)
    case sunday
    case citationContext(reference: String)
    case prayers
    case prayer(id: String)
    case learn
    case teaching(id: String)
    case novena(id: String)
    case rosaryHome
    case rosaryGuide(set: String)
    case lectio(PassageSelection?)
    case confession
    case scriptureCard(PassageSelection)
}
