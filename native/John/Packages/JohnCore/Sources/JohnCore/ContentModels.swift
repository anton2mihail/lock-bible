import Foundation

public struct DevotionalCatalog: Codable, Sendable {
    public let formatVersion: Int
    public let novenas: [NovenaCatalogItem]
    public let prayers: [PrayerCatalogItem]
    public let teachings: [TeachingCatalogItem]
    public let rosary: JSONValue

    public func validate() throws {
        guard formatVersion == 1, novenas.count == 27, prayers.count == 12, teachings.count == 5,
              unique(novenas.map(\.id)), unique(prayers.map(\.id)), unique(teachings.map(\.id)),
              prayers.allSatisfy({ ["Daily rhythm", "In times of need", "Traditional prayers"].contains($0.category) }),
              teachings.allSatisfy({ ["mary", "prayer", "scripture"].contains($0.artwork) }) else {
            throw CoreError.invalidResource("devotional catalog shape")
        }
    }

    private func unique(_ values: [String]) -> Bool { Set(values).count == values.count && values.allSatisfy { !$0.isEmpty } }
}

public struct NovenaCatalogItem: Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let about: String
    public let patronage: String
    public let traditionalStart: String?
    public let feastDay: String?
    public let sourceName: String
    public let sourceUrl: String
    public let searchTerms: [String]
    public let opening: String?
    public let sections: [NovenaPrayerSection]
}

public struct NovenaPrayerSection: Codable, Hashable, Sendable {
    public let title: String?
    public let paragraphs: [String]
    public let response: String?
}

public struct PrayerCatalogItem: Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let category: String
    public let text: String
    public let source: String
}

public struct TeachingCatalogItem: Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let artwork: String
    public let summary: String
    public let references: [String]
    public let catechism: String
    public let url: String
    public let reflection: String
}

public struct ReadingsCalendar: Codable, Sendable {
    public let dates: [String: CalendarReadingsEntry]

    public init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer()
        dates = try values.decode([String: CalendarReadingsEntry].self)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.singleValueContainer()
        try values.encode(dates)
    }
}

public struct CalendarReadingsEntry: Codable, Hashable, Sendable {
    public let title: String
    public let readings: [CalendarReadingReference]
}

public struct CalendarReadingReference: Codable, Hashable, Sendable {
    public let label: String
    public let reference: String
}

public struct CelebrationsCalendar: Codable, Sendable {
    public let dates: [String: CalendarCelebration]

    public init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer()
        dates = try values.decode([String: CalendarCelebration].self)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.singleValueContainer()
        try values.encode(dates)
    }
}

public struct CalendarCelebration: Codable, Hashable, Sendable {
    public let title: String
    public let season: String
    public let rank: String
    public let color: String?
}

public struct CalendarCoverage: Codable, Hashable, Sendable {
    public let firstDate: String
    public let lastDate: String
    public let count: Int
    public var label: String { "\(firstDate) to \(lastDate)" }
}

public struct TodayNovena: Codable, Hashable, Sendable {
    public let novena: NovenaCatalogItem
    public let progress: NovenaProgress
    public let firstIncompleteDay: Int
    public var subtitle: String { "Continue with day \(firstIncompleteDay)" }
}
