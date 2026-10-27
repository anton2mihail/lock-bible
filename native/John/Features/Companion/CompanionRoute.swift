import Foundation
import JohnCore

enum CompanionRoute: Hashable, Sendable {
    case prayerHome
    case daily(dateKey: String)
    case saints
    case mySaints
    case saint(id: String)
    case saintFeast(id: String)
    case saintWidget
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
    /// The Advent page (2.2.0); `nrsv://advent` and the Today card open it.
    case advent
    /// The Lent page (2.3.0); `nrsv://lent` and the Today row open it.
    case lent
    /// The Holy Week page (2.3.0), Palm Sunday to Easter Sunday; `nrsv://holyweek`.
    case holyWeek
    /// The Stations of the Cross by St Alphonsus Liguori (2.3.0); `nrsv://stations` and the Pray tab.
    case stations
    /// "A Year with the Fathers" (2.3.0): the start screen or the plan; `nrsv://year` and the Today card open it.
    case yearPlan
    /// One day's reading of the year plan.
    case yearDay(Int)
}
