import Foundation

public enum RotationResourceRoot: Sendable {
    case app
    case widget
}

public protocol RotationRepository: Sendable {
    func poolCount(translation: TranslationID, scope: RotationScope) async throws -> Int
    func verse(translation: TranslationID, scope: RotationScope, at index: Int) async throws -> RotatingVerse
}

public actor IndexedRotationRepository: RotationRepository {
    private struct Counts: Decodable { let formatVersion: Int; let counts: Values }
    private struct Values: Decodable { let full: Int; let ot: Int; let nt: Int }
    private struct Corpus {
        let bytes: Data
        let offsets: [UInt32]
        let ot: [UInt32]
        let nt: [UInt32]
        let counts: Values
    }
    private let roots: ResourceRoots
    private let resourceRoot: RotationResourceRoot
    private var corpora: [TranslationID: Corpus] = [:]
    private let maximumRecordBytes = 64 * 1024

    public init(roots: ResourceRoots, resourceRoot: RotationResourceRoot = .app) {
        self.roots = roots
        self.resourceRoot = resourceRoot
    }

    public func poolCount(translation: TranslationID, scope: RotationScope) async throws -> Int {
        let corpus = try load(translation)
        switch scope {
        case .full: return corpus.counts.full
        case .ot: return corpus.counts.ot
        case .nt: return corpus.counts.nt
        }
    }

    public func verse(translation: TranslationID, scope: RotationScope, at index: Int) async throws -> RotatingVerse {
        let corpus = try load(translation)
        let globalIndex: Int
        switch scope {
        case .full:
            guard index >= 0, index < corpus.counts.full else { throw CoreError.invalidIdentity("rotation index") }
            globalIndex = index
        case .ot:
            guard index >= 0, index < corpus.ot.count else { throw CoreError.invalidIdentity("OT rotation index") }
            globalIndex = Int(corpus.ot[index])
        case .nt:
            guard index >= 0, index < corpus.nt.count else { throw CoreError.invalidIdentity("NT rotation index") }
            globalIndex = Int(corpus.nt[index])
        }
        let start = Int(corpus.offsets[globalIndex])
        let end = Int(corpus.offsets[globalIndex + 1])
        guard start >= 0, end > start, end <= corpus.bytes.count, end - start <= maximumRecordBytes else {
            throw CoreError.invalidResource("rotation record bounds")
        }
        let row: RotationRecord
        do { row = try JSONDecoder().decode(RotationRecord.self, from: corpus.bytes.subdata(in: start..<end)) }
        catch { throw CoreError.invalidResource("rotation record \(globalIndex): \(error)") }
        return RotatingVerse(reference: row.reference, bookCode: row.bookCode, chapter: row.chapter,
                             verseLabel: row.verseLabel, text: row.text)
    }

    private func load(_ translation: TranslationID) throws -> Corpus {
        if let corpus = corpora[translation] { return corpus }
        let prefix = translation.rawValue
        let dataURL = try resource(edition: prefix, suffix: ".dat")
        let offsetsURL = try resource(edition: prefix, suffix: ".offsets")
        let otURL = try resource(edition: prefix, suffix: ".ot")
        let ntURL = try resource(edition: prefix, suffix: ".nt")
        let metadataURL = try resource(edition: prefix, suffix: ".meta.json")
        guard FileManager.default.fileExists(atPath: dataURL.path) else { throw CoreError.missingResource(dataURL.lastPathComponent) }
        do {
            let data = try Data(contentsOf: dataURL, options: .mappedIfSafe)
            let offsetsData = try Data(contentsOf: offsetsURL)
            let otData = try Data(contentsOf: otURL)
            let ntData = try Data(contentsOf: ntURL)
            let metadata = try JSONDecoder().decode(Counts.self, from: Data(contentsOf: metadataURL))
            guard metadata.formatVersion == 1, metadata.counts.full > 0,
                  metadata.counts.ot >= 0, metadata.counts.nt >= 0,
                  metadata.counts.ot <= metadata.counts.full,
                  metadata.counts.nt == metadata.counts.full - metadata.counts.ot,
                  offsetsData.count.isMultiple(of: 4), offsetsData.count >= 8,
                  otData.count.isMultiple(of: 4), ntData.count.isMultiple(of: 4),
                  metadata.counts.full == offsetsData.count / 4 - 1,
                  metadata.counts.ot == otData.count / 4, metadata.counts.nt == ntData.count / 4 else {
                throw CoreError.invalidResource("rotation metadata or index size mismatch: \(prefix)")
            }
            let offsets = try Self.uint32Values(offsetsData)
            let ot = try Self.uint32Values(otData)
            let nt = try Self.uint32Values(ntData)
            guard offsets.first == 0, let lastOffset = offsets.last, Int(lastOffset) == data.count else { throw CoreError.invalidResource("rotation offset endpoints: \(prefix)") }
            for pair in zip(offsets, offsets.dropFirst()) {
                guard pair.0 < pair.1, Int(pair.1) <= data.count, Int(pair.1 - pair.0) <= maximumRecordBytes else {
                    throw CoreError.invalidResource("rotation offset bounds: \(prefix)")
                }
            }
            guard Self.isValidIndexMap(ot, fullCount: metadata.counts.full), Self.isValidIndexMap(nt, fullCount: metadata.counts.full) else {
                throw CoreError.invalidResource("rotation scope index map: \(prefix)")
            }
            let scoped = Set(ot).union(nt)
            guard scoped.count == metadata.counts.full,
                  Set(ot).isDisjoint(with: Set(nt)) else {
                throw CoreError.invalidResource("rotation scope coverage: \(prefix)")
            }
            let corpus = Corpus(bytes: data, offsets: offsets, ot: ot, nt: nt, counts: metadata.counts)
            corpora[translation] = corpus
            return corpus
        } catch let error as CoreError { throw error }
        catch { throw CoreError.invalidResource("rotation corpus \(prefix): \(error)") }
    }

    private func resource(edition: String, suffix: String) throws -> URL {
        switch resourceRoot {
        case .app: return try roots.appResource("Rotation", edition + suffix)
        case .widget: return try roots.widgetResource(edition + suffix)
        }
    }

    private static func uint32Values(_ data: Data) throws -> [UInt32] {
        guard data.count.isMultiple(of: 4) else { throw CoreError.invalidResource("UInt32 index byte count") }
        var result: [UInt32] = []
        result.reserveCapacity(data.count / 4)
        for index in stride(from: 0, to: data.count, by: 4) {
            let b0 = UInt32(data[index])
            let b1 = UInt32(data[index + 1]) << 8
            let b2 = UInt32(data[index + 2]) << 16
            let b3 = UInt32(data[index + 3]) << 24
            result.append(b0 | b1 | b2 | b3)
        }
        return result
    }

    private static func isValidIndexMap(_ values: [UInt32], fullCount: Int) -> Bool {
        guard !values.isEmpty, values.allSatisfy({ Int($0) < fullCount }) else { return false }
        return zip(values, values.dropFirst()).allSatisfy { $0 < $1 }
    }
}

private struct RotationRecord: Decodable {
    let reference: String; let bookCode: String; let chapter: Int; let verseLabel: String; let text: String
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        reference = try container.decode(String.self)
        bookCode = try container.decode(String.self)
        chapter = try container.decode(Int.self)
        verseLabel = try container.decode(String.self)
        text = try container.decode(String.self)
        guard container.isAtEnd, !reference.isEmpty, !bookCode.isEmpty, chapter > 0, !verseLabel.isEmpty else {
            throw CoreError.invalidResource("invalid positional rotation record")
        }
    }
}
