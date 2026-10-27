import Foundation

/// The texts of Lent, Holy Week and the Stations of the Cross (2.3.0), from `Catalogs/lent.json`.
///
/// Every text is quoted from a Church-approved book with its page and a link to the page scan: the Collects and the
/// Holy Week texts from The Missal (1926 printing; Imprimatur Westminster, 1921), the Stations by St Alphonsus
/// Liguori from A Manual of Prayers (Baltimore, 1889). One Collect (Ember Saturday) is from The Roman Missal (New York,
/// 1916; Imprimatur Farley), because the scan of the 1926 printing lacks its page. `src/services/lent/data/lent.json` is the source file.
public struct LentContent: Decodable, Sendable {
    public struct Source: Decodable, Sendable, Equatable {
        public let title: String
        public let approval: String
        public let url: String
    }

    public struct Collect: Decodable, Sendable, Equatable {
        /// The Mass's title as printed ("Thursday after Ash Wednesday").
        public let title: String
        public let text: String
        public let page: Int
        public let scan: String
        /// "massEveryDay" when the Collect is quoted from the 1916 Roman Missal (the 1926 scan lacks its page); else nil.
        public let book: String?
    }

    public struct Section: Decodable, Sendable, Equatable, Identifiable {
        public let id: String
        public let title: String
        public let kind: String
        public let paragraphs: [String]
        public let rubrics: [String]?
        public let pages: [Int]
        public let scans: [String]
    }

    public struct HolyWeekDay: Decodable, Sendable, Equatable, Identifiable {
        public let key: String
        public let title: String
        public let sections: [Section]
        public var id: String { key }
    }

    public struct Station: Decodable, Sendable, Equatable, Identifiable {
        public let number: Int
        public let title: String
        public let versicle: String
        public let response: String
        public let meditation: String
        public let prayer: String
        public let after: String
        public let verse: [String]
        public let pages: [Int]
        public let scans: [String]
        /// The painting's name in App/Artwork ("stations-03"); its credit is in the artwork credits.
        public let painting: String
        public var id: Int { number }
    }

    public struct Part: Decodable, Sendable, Equatable {
        public let title: String
        public let paragraphs: [String]
        public let pages: [Int]
        public let scans: [String]
    }

    public struct Stations: Decodable, Sendable, Equatable {
        public let opening: Part
        public let stations: [Station]
        public let closing: Part?
    }

    public let formatVersion: Int
    public let missal: Source
    public let massEveryDay: Source
    public let manual: Source
    /// One Collect for each key of `LentCalendar.allKeys`.
    public let collects: [String: Collect]
    public let holyWeek: [HolyWeekDay]
    public let stations: Stations
    /// The Seven Penitential Psalms, Douay-Rheims (Vulgate) numbers.
    public let penitentialPsalms: [Int]

    public static func load(from url: URL) throws -> LentContent {
        try JSONDecoder().decode(LentContent.self, from: Data(contentsOf: url))
    }

    public func collect(for day: LentCalendar.Day) -> Collect? { collects[day.key] }
    public func holyWeekDay(_ key: String) -> HolyWeekDay? { holyWeek.first { $0.key == key } }
}
