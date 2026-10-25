import Foundation

/// Advent (2.2.0): which week it is, and the O Antiphon of 17–23 December.
///
/// The antiphons are quoted, Latin and English, from Dom Prosper Guéranger, *The Liturgical Year: Advent*
/// (2nd ed., Dublin: James Duffy, 1870), pp. 509–531, public domain. The app adds no words of its own to them.
public enum AdventCalendar {
    public struct Antiphon: Equatable, Sendable {
        public let day: Int        // December day: 17...23
        public let title: String   // "O Wisdom"
        public let latin: String
        public let english: String
    }

    public static let source = "Dom Prosper Guéranger, The Liturgical Year: Advent (Dublin, 1870)"

    public static let antiphons: [Antiphon] = [
        Antiphon(day: 17, title: "O Wisdom",
                 latin: "O Sapientia, quae ex ore Altissimi prodiisti, attingens a fine usque ad finem, fortiter suaviterque disponens omnia: veni ad docendum nos viam prudentiae.",
                 english: "O Wisdom, that proceedest from the mouth of the Most High, reaching from end to end, disposing all things with strength and sweetness! come and teach us the way of prudence."),
        Antiphon(day: 18, title: "O Adonai",
                 latin: "O Adonai, et dux domus Israel, qui Moysi in igne flammae rubi apparuisti, et ei in Sina legem dedisti: veni ad redimendum nos in brachio extento.",
                 english: "O Adonai, and leader of the house of Israel, who appearedst to Moses in the fire of the flaming bush, and gavest him the law on Sinai: come and redeem us by thy outstretched arm."),
        Antiphon(day: 19, title: "O Root of Jesse",
                 latin: "O Radix Jesse, qui stas in signum populorum, super quem continebunt reges os suum, quem gentes deprecabuntur: veni ad liberandum nos, jam noli tardare.",
                 english: "O Root of Jesse, who standest as the standard of the people; before whom kings shall not open their lips; to whom the nations shall pray: come and deliver us; tarry now no more."),
        Antiphon(day: 20, title: "O Key of David",
                 latin: "O Clavis David, et sceptrum domus Israel; qui aperis, et nemo claudit; claudis, et nemo aperit: veni, et educ vinctum de domo carceris, sedentem in tenebris, et umbra mortis.",
                 english: "O Key of David, and Sceptre of the house of Israel! who openest, and no man shutteth; who shuttest, and no man openeth: come and lead the captive from prison, sitting in darkness and in the shadow of death."),
        Antiphon(day: 21, title: "O Orient",
                 latin: "O Oriens, splendor lucis aeternae, et sol justitiae: veni, et illumina sedentes in tenebris, et umbra mortis.",
                 english: "O Orient! splendour of eternal light, and Sun of Justice! come and enlighten them that sit in darkness, and in the shadow of death."),
        Antiphon(day: 22, title: "O King of Nations",
                 latin: "O Rex gentium, et desideratus earum, lapisque angularis, qui facis utraque unum: veni, et salva hominem, quem de limo formasti.",
                 english: "O King of nations, and their Desired One, and the Corner-Stone that makest both one: come and save man, whom thou formedst out of slime."),
        Antiphon(day: 23, title: "O Emmanuel",
                 latin: "O Emmanuel, Rex et legifer noster, exspectatio gentium, et salvator earum: veni ad salvandum nos, Domine Deus noster.",
                 english: "O Emmanuel, our King and Lawgiver, the Expectation and Saviour of the nations! come and save us, O Lord our God!"),
    ]

    private static func calendar(_ zone: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = zone; return c
    }

    /// The first Sunday of Advent of `year`: the fourth Sunday before Christmas.
    public static func firstSunday(year: Int, timeZone: TimeZone) -> Date? {
        let cal = calendar(timeZone)
        guard let christmas = cal.date(from: DateComponents(year: year, month: 12, day: 25, hour: 12)) else { return nil }
        let weekday = cal.component(.weekday, from: christmas) // 1 = Sunday
        let back = (weekday == 1 ? 7 : weekday - 1) + 21
        return cal.date(byAdding: .day, value: -back, to: christmas)
    }

    /// The week of Advent (1...4) on `date`, or nil outside Advent (Advent ends on 24 December).
    public static func week(on date: Date, timeZone: TimeZone) -> Int? {
        let cal = calendar(timeZone)
        let parts = cal.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let start = firstSunday(year: year, timeZone: timeZone),
              let day = cal.date(from: DateComponents(year: year, month: parts.month, day: parts.day, hour: 12)) else { return nil }
        guard parts.month == 12 ? (parts.day ?? 0) <= 24 : true else { return nil }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: day)).day ?? -1
        guard days >= 0 else { return nil }
        return min(days / 7 + 1, 4)
    }

    /// The O Antiphon for `date` (17–23 December), else nil.
    public static func antiphon(on date: Date, timeZone: TimeZone) -> Antiphon? {
        let parts = calendar(timeZone).dateComponents([.month, .day], from: date)
        guard parts.month == 12, let day = parts.day else { return nil }
        return antiphons.first { $0.day == day }
    }
}
