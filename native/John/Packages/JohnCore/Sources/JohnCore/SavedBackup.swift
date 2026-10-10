import Foundation

/// JSON backup of saved items and tags. The library database format does not change.
public struct SavedBackup: Codable, Hashable, Sendable {
    public static let formatName = "john-saved-backup"
    public let format: String
    public let version: Int
    public let exportedAt: Int64
    public let items: [SavedItem]
    /// Tags by saved item ID. Older backups do not have this key.
    public let tags: [String: [String]]

    public init(items: [SavedItem], tags: [String: [String]], exportedAt: Int64) {
        format = Self.formatName; version = 1; self.items = items; self.tags = tags; self.exportedAt = exportedAt
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        format = try values.decode(String.self, forKey: .format)
        guard format == Self.formatName else { throw CoreError.invalidIdentity("backup format") }
        version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 1
        exportedAt = try values.decodeIfPresent(Int64.self, forKey: .exportedAt) ?? 0
        items = try values.decode([SavedItem].self, forKey: .items)
        tags = try values.decodeIfPresent([String: [String]].self, forKey: .tags) ?? [:]
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> SavedBackup {
        try JSONDecoder().decode(SavedBackup.self, from: data)
    }

    /// Items whose ID is not in `existingIDs`. Duplicate IDs inside the backup count once.
    public func newItems(existingIDs: Set<String>) -> [SavedItem] {
        var seen = existingIDs
        return items.filter { seen.insert($0.id).inserted }
    }
}

public enum SavedTags {
    public static func normalize(_ raw: String) -> String? {
        let tag = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "#", with: "")
        return tag.isEmpty ? nil : String(tag.prefix(40))
    }

    public static func merge(_ a: [String: [String]], _ b: [String: [String]]) -> [String: [String]] {
        var result = a
        for (id, tags) in b {
            var combined = result[id] ?? []
            for tag in tags where !combined.contains(tag) { combined.append(tag) }
            result[id] = combined
        }
        return result
    }
}

/// Tags live in a separate JSON file. Old data stays valid because the database has no tag column.
public actor SavedTagStore {
    private let url: URL
    private var cache: [String: [String]]?

    public init(url: URL) { self.url = url }

    public func all() -> [String: [String]] {
        if let cache { return cache }
        let loaded = (try? JSONDecoder().decode([String: [String]].self, from: Data(contentsOf: url))) ?? [:]
        cache = loaded
        return loaded
    }

    public func tags(for id: String) -> [String] { all()[id] ?? [] }

    public func set(_ tags: [String], for id: String) throws {
        var current = all()
        let clean = tags.compactMap(SavedTags.normalize)
        var unique: [String] = []
        for tag in clean where !unique.contains(tag) { unique.append(tag) }
        current[id] = unique.isEmpty ? nil : unique
        try write(current)
    }

    public func merge(_ incoming: [String: [String]]) throws {
        try write(SavedTags.merge(all(), incoming))
    }

    private func write(_ value: [String: [String]]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
        cache = value
    }
}

public enum SavedSmartFolder: String, CaseIterable, Sendable {
    case recent, highlightsThisWeek, untagged

    public var title: String {
        switch self {
        case .recent: "Recent"
        case .highlightsThisWeek: "Highlights this week"
        case .untagged: "Untagged"
        }
    }

    /// `nowMilliseconds` is the clock value. Recent means the last 7 days.
    public func matches(_ item: SavedItem, tags: [String], nowMilliseconds: Int64) -> Bool {
        let week: Int64 = 7 * 24 * 3600 * 1000
        let recent = nowMilliseconds - item.updatedAt <= week
        switch self {
        case .recent: return recent
        case .highlightsThisWeek: return item.kind == .highlight && recent
        case .untagged: return tags.isEmpty
        }
    }
}

public enum SavedMarkdown {
    public static func render(items: [SavedItem], tags: [String: [String]]) -> String {
        var out = "# Saved passages\n"
        for kind in [SavedItemKind.note, .highlight, .bookmark] {
            let group = items.filter { $0.kind == kind }
            guard !group.isEmpty else { continue }
            out += "\n## \(kind == .note ? "Notes" : kind == .highlight ? "Highlights" : "Bookmarks")\n"
            for item in group {
                out += "\n### \(item.reference) (\(item.translationID.uppercased()))\n\n"
                out += item.scriptureText.split(separator: "\n", omittingEmptySubsequences: false)
                    .map { "> \($0)" }.joined(separator: "\n") + "\n"
                if kind == .highlight, let color = item.color { out += "\nColor: \(color.rawValue)\n" }
                if let note = item.noteText, !note.isEmpty { out += "\n\(note)\n" }
                if let list = tags[item.id], !list.isEmpty { out += "\nTags: " + list.map { "#\($0)" }.joined(separator: " ") + "\n" }
            }
        }
        return out
    }
}
