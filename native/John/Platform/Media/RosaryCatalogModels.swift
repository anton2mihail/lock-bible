import Foundation
import JohnCore

struct RosaryHomeCatalog: Decodable, Sendable {
    let mysterySets: [RosaryMysterySet]
    let sevenSorrows: RosarySevenSorrows
    let mediaEpisodes: [RosaryMediaEpisode]

    var isValid: Bool {
        let expectedEpisodes = ["why-pray", "how-to-pray", "joyful", "sorrowful", "glorious", "luminous"]
        let expectedSets = Set(["joyful", "sorrowful", "glorious", "luminous"])
        return mysterySets.count == 4
            && Set(mysterySets.map(\.id)) == expectedSets
            && mysterySets.allSatisfy { $0.mysteries.count == 5 && !$0.title.isEmpty }
            && mediaEpisodes.map(\.id) == expectedEpisodes
            && Set(mediaEpisodes.map(\.id)).count == mediaEpisodes.count
            && mediaEpisodes.allSatisfy { !$0.title.isEmpty && !$0.subtitle.isEmpty && URL(string: $0.officialUrl)?.scheme == "https" }
            && sevenSorrows.id == "seven-sorrows" && !sevenSorrows.title.isEmpty
    }
}

struct RosaryMysterySet: Decodable, Identifiable, Sendable {
    let id: String
    let title: String
    let shortTitle: String
    let customaryDays: String
    let description: String
    let mysteries: [RosaryMystery]
}

struct RosaryMystery: Decodable, Sendable {
    let title: String
    let scriptureReference: String
    let fruit: String
}

struct RosarySevenSorrows: Decodable, Sendable {
    let id: String
    let title: String
    let shortTitle: String
    let customaryDays: String
    let description: String
}

struct RosaryMediaEpisode: Decodable, Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let officialUrl: String
    let mysterySetId: String?
    let videoUri: String?
    let audioUri: String?

    static let unavailable = RosaryMediaEpisode(
        id: "", title: "", subtitle: "", officialUrl: "", mysterySetId: nil,
        videoUri: nil, audioUri: nil
    )
}

enum RosaryCatalogAdapter {
    static func decode(_ value: JSONValue) throws -> RosaryHomeCatalog {
        let bytes = try JSONEncoder().encode(value)
        let catalog = try JSONDecoder().decode(RosaryHomeCatalog.self, from: bytes)
        guard catalog.isValid else { throw CoreError.invalidResource("Rosary catalog shape") }
        return catalog
    }
}
