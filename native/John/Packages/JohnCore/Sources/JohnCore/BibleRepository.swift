import Foundation

public protocol BibleRepository: Sendable {
    func translationIDs() async throws -> [TranslationID]
    func metadata(for translation: TranslationID) async throws -> BibleTranslationMetadata
    func manifest(for translation: TranslationID) async throws -> [BibleBookDescriptor]
    func chapter(translation: TranslationID, book: BookCode, chapter: Int) async throws -> BibleChapter
    func passage(id: PassageID, startIndex: Int, endIndex: Int) async throws -> PassageSelection
}

public actor BundledBibleRepository: BibleRepository {
    private let roots: ResourceRoots
    private var editionCache: [TranslationID: (BibleTranslationMetadata, [BibleBookDescriptor])] = [:]

    public init(roots: ResourceRoots) { self.roots = roots }

    public func translationIDs() async throws -> [TranslationID] { TranslationID.allCases }

    public func metadata(for translation: TranslationID) async throws -> BibleTranslationMetadata {
        try loadEdition(translation).0
    }

    public func manifest(for translation: TranslationID) async throws -> [BibleBookDescriptor] {
        try loadEdition(translation).1
    }

    public func chapter(translation: TranslationID, book: BookCode, chapter: Int) async throws -> BibleChapter {
        guard chapter > 0 else { throw CoreError.missingChapter(chapter) }
        let (_, descriptors) = try loadEdition(translation)
        guard let descriptor = descriptors.first(where: { $0.code == book.rawValue }) else { throw CoreError.missingBook(book.rawValue) }
        let url = try roots.appResource("Bible", translation.rawValue, "\(book.rawValue).json")
        let raw: RawBibleBook
        do { raw = try JSONDecoder().decode(RawBibleBook.self, from: Data(contentsOf: url)) }
        catch { throw CoreError.invalidResource("Bible book \(translation.rawValue)/\(book.rawValue): \(error)") }
        guard raw.code == book.rawValue, raw.name == descriptor.name,
              raw.longName == descriptor.longName, raw.group == descriptor.group,
              raw.chapters.count == descriptor.chapterCount,
              raw.chapters.enumerated().allSatisfy({ $0.element.number == $0.offset + 1 }) else {
            throw CoreError.invalidResource("Bible book identity or chapter count mismatch: \(book.rawValue)")
        }
        guard let rawChapter = raw.chapters.first(where: { $0.number == chapter }) else { throw CoreError.missingChapter(chapter) }
        guard !rawChapter.verses.isEmpty,
              rawChapter.verses.allSatisfy({ !$0.label.isEmpty }) else {
            throw CoreError.invalidResource("invalid Bible chapter \(book.rawValue) \(chapter)")
        }
        return rawChapter
    }

    public func passage(id: PassageID, startIndex: Int, endIndex: Int) async throws -> PassageSelection {
        guard startIndex >= 0, endIndex >= startIndex else { throw CoreError.invalidIdentity("passage indices") }
        let chapter = try await self.chapter(translation: id.translationID, book: id.bookCode, chapter: id.chapter)
        guard endIndex < chapter.verses.count else { throw CoreError.invalidIdentity("passage index outside chapter") }
        let selected = Array(chapter.verses[startIndex...endIndex])
        guard selected.first?.label == id.startVerse.rawValue, selected.last?.label == id.endVerse.rawValue else {
            throw CoreError.invalidIdentity("passage labels do not match selected indices")
        }
        let descriptor = try loadEdition(id.translationID).1.first { $0.code == id.bookCode.rawValue }
        guard let descriptor else { throw CoreError.missingBook(id.bookCode.rawValue) }
        let verses = try selected.enumerated().map { offset, verse in
            PassageVerse(verse: try VerseLabel(verse.label), index: startIndex + offset, text: verse.text)
        }
        return try PassageSelection(id: id, bookName: descriptor.name, bookOrder: descriptor.order,
                                    startIndex: startIndex, endIndex: endIndex,
                                    scriptureText: selected.map { "\($0.label) \($0.text)" }.joined(separator: " "),
                                    verses: verses)
    }

    private func loadEdition(_ id: TranslationID) throws -> (BibleTranslationMetadata, [BibleBookDescriptor]) {
        if let cached = editionCache[id] { return cached }
        let metaURL = try roots.appResource("Bible", id.rawValue, "meta.json")
        let manifestURL = try roots.appResource("Bible", id.rawValue, "manifest.json")
        do {
            let metadata = try JSONDecoder().decode(BibleTranslationMetadata.self, from: Data(contentsOf: metaURL))
            let descriptors = try JSONDecoder().decode([BibleBookDescriptor].self, from: Data(contentsOf: manifestURL))
            guard metadata.id == id.rawValue, !descriptors.isEmpty,
                  Set(descriptors.map(\.code)).count == descriptors.count,
                  descriptors.enumerated().allSatisfy({ $0.element.order == $0.offset && $0.element.chapterCount > 0 }) else {
                throw CoreError.invalidResource("Bible manifest metadata mismatch: \(id.rawValue)")
            }
            let result = (metadata, descriptors)
            editionCache[id] = result
            return result
        } catch let error as CoreError { throw error }
        catch { throw CoreError.invalidResource("Bible edition \(id.rawValue): \(error)") }
    }
}

private struct RawBibleBook: Decodable {
    let code: String
    let name: String
    let longName: String
    let group: String
    let chapters: [BibleChapter]
    enum CodingKeys: String, CodingKey { case code, name, longName, group, chapters }
}

enum RawBibleAtom: Decodable {
    case integer(Int)
    case string(String)
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if let number = try? value.decode(Int.self) { self = .integer(number); return }
        if let string = try? value.decode(String.self) { self = .string(string); return }
        throw CoreError.invalidResource("invalid Bible structure value")
    }
}
