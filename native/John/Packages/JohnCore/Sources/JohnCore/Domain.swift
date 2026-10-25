import Foundation

public enum CoreError: Error, Sendable, Equatable {
    case missingResource(String)
    case invalidResource(String)
    case invalidIdentity(String)
    case unsupportedSchema(Int32)
    case unreadableLibrary(String)
    case failedBackup(String)
    case sqlite(code: Int32, message: String)
    case missingBook(String)
    case missingChapter(Int)
    case missingSection(workID: String, index: Int)
    case damagedSection(String)
    case oversizedContent(limit: Int)
    case unsupportedNativeState(Int)
    case unrecoverableNativeState(String)
    case failedNativeStateWrite(String)
}

public enum TranslationID: String, Codable, CaseIterable, Sendable {
    case webCE = "web-ce"
    case douayRheims = "douay-rheims"
    case vulgate
}

public struct BookCode: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String
    public init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }
    public init(_ value: String) throws {
        guard let code = Self(rawValue: value) else { throw CoreError.invalidIdentity("book code") }
        self = code
    }
}

public struct VerseLabel: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String
    public init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }
    public init(_ value: String) throws {
        guard let label = Self(rawValue: value) else { throw CoreError.invalidIdentity("verse label") }
        self = label
    }
}

public struct PassageID: Codable, Hashable, Sendable {
    public let translationID: TranslationID
    public let bookCode: BookCode
    public let chapter: Int
    public let startVerse: VerseLabel
    public let endVerse: VerseLabel

    public init(translationID: TranslationID, bookCode: BookCode, chapter: Int,
                startVerse: VerseLabel, endVerse: VerseLabel) throws {
        guard chapter > 0 else { throw CoreError.invalidIdentity("chapter") }
        self.translationID = translationID
        self.bookCode = bookCode
        self.chapter = chapter
        self.startVerse = startVerse
        self.endVerse = endVerse
    }

    /// Keep the legacy key format used by `passage_key`.
    public var legacyKey: String {
        "\(translationID.rawValue):\(bookCode.rawValue):\(chapter):\(startVerse.rawValue):\(endVerse.rawValue)"
    }
}

public struct PassageVerse: Codable, Hashable, Sendable {
    public let verse: VerseLabel
    public let index: Int
    public let text: String
    public init(verse: VerseLabel, index: Int, text: String) { self.verse = verse; self.index = index; self.text = text }
}

public struct PassageSelection: Codable, Hashable, Sendable {
    public let id: PassageID
    public let bookName: String
    public let bookOrder: Int
    public let startIndex: Int
    public let endIndex: Int
    public let scriptureText: String
    public let verses: [PassageVerse]
    public var translationID: TranslationID { id.translationID }
    public var bookCode: BookCode { id.bookCode }
    public var chapter: Int { id.chapter }
    public var startVerse: VerseLabel { id.startVerse }
    public var endVerse: VerseLabel { id.endVerse }

    public init(id: PassageID, bookName: String, bookOrder: Int, startIndex: Int, endIndex: Int,
                scriptureText: String, verses: [PassageVerse]) throws {
        guard startIndex >= 0, endIndex >= startIndex, verses.count == endIndex - startIndex + 1,
              verses.enumerated().allSatisfy({ $0.element.index == startIndex + $0.offset }),
              verses.first?.verse == id.startVerse, verses.last?.verse == id.endVerse else {
            throw CoreError.invalidIdentity("passage indices")
        }
        self.id = id; self.bookName = bookName; self.bookOrder = bookOrder
        self.startIndex = startIndex; self.endIndex = endIndex
        self.scriptureText = scriptureText; self.verses = verses
    }
}

public struct ReaderAnchor: Codable, Hashable, Sendable {
    public let verseLabel: VerseLabel
    public let utf16Offset: Int
    public init(verseLabel: VerseLabel, utf16Offset: Int) throws {
        guard utf16Offset >= 0 else { throw CoreError.invalidIdentity("reader anchor") }
        self.verseLabel = verseLabel; self.utf16Offset = utf16Offset
    }
}

public struct WorksAnchor: Codable, Hashable, Sendable {
    public let sectionIndex: Int
    public let paragraphIndex: Int
    public let utf16Offset: Int
    public init(sectionIndex: Int, paragraphIndex: Int, utf16Offset: Int) throws {
        guard sectionIndex >= 0, paragraphIndex >= 0, utf16Offset >= 0 else { throw CoreError.invalidIdentity("works anchor") }
        self.sectionIndex = sectionIndex; self.paragraphIndex = paragraphIndex; self.utf16Offset = utf16Offset
    }
}

public enum ReaderTextSize: String, Codable, Sendable { case small, medium, large, extraLarge }
public enum ReaderLineSpacing: String, Codable, Sendable { case compact, comfortable, relaxed }
public enum ReaderTypeface: String, Codable, Sendable { case sans, serif }
public enum ReaderLayout: String, Codable, Sendable { case paragraphs, verses }
/// How the Reader shows a chapter: horizontal pages (as in Apple Books) or one vertical scroll.
public enum ReaderMode: String, Codable, Sendable { case pages, scroll }

public struct ReadingPreferences: Codable, Hashable, Sendable {
    public let textSize: ReaderTextSize
    public let lineSpacing: ReaderLineSpacing
    public let typeface: ReaderTypeface
    public let layout: ReaderLayout
    /// Pages is the default. State that was saved before this field existed decodes as pages.
    public let mode: ReaderMode
    public static let sourceDefaults = ReadingPreferences(textSize: .medium, lineSpacing: .comfortable, typeface: .serif,
                                                          layout: .paragraphs, mode: .pages)
    public init(textSize: ReaderTextSize = .medium, lineSpacing: ReaderLineSpacing = .comfortable,
                typeface: ReaderTypeface = .serif, layout: ReaderLayout = .paragraphs, mode: ReaderMode = .pages) {
        self.textSize = textSize; self.lineSpacing = lineSpacing; self.typeface = typeface; self.layout = layout
        self.mode = mode
    }

    private enum CodingKeys: String, CodingKey { case textSize, lineSpacing, typeface, layout, mode }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(textSize: values.decode(ReaderTextSize.self, forKey: .textSize),
                      lineSpacing: values.decode(ReaderLineSpacing.self, forKey: .lineSpacing),
                      typeface: values.decode(ReaderTypeface.self, forKey: .typeface),
                      layout: values.decode(ReaderLayout.self, forKey: .layout),
                      mode: values.decodeIfPresent(ReaderMode.self, forKey: .mode) ?? .pages)
    }

    /// A copy with one value changed.
    public func with(textSize: ReaderTextSize? = nil, lineSpacing: ReaderLineSpacing? = nil,
                     typeface: ReaderTypeface? = nil, layout: ReaderLayout? = nil,
                     mode: ReaderMode? = nil) -> ReadingPreferences {
        ReadingPreferences(textSize: textSize ?? self.textSize, lineSpacing: lineSpacing ?? self.lineSpacing,
                           typeface: typeface ?? self.typeface, layout: layout ?? self.layout,
                           mode: mode ?? self.mode)
    }
}

public struct ReaderLocation: Codable, Hashable, Sendable {
    public let bookCode: BookCode
    public let chapter: Int
    public let scrollY: Double
    public let updatedAt: Int64
    public let anchor: ReaderAnchor?

    private enum CodingKeys: String, CodingKey { case bookCode, chapter, scrollY, updatedAt, anchor }

    public init(bookCode: BookCode, chapter: Int, scrollY: Double, updatedAt: Int64 = 0,
                anchor: ReaderAnchor? = nil) throws {
        guard chapter > 0, scrollY.isFinite,
              anchor.map({ $0.utf16Offset >= 0 && !$0.verseLabel.rawValue.isEmpty }) ?? true else {
            throw CoreError.invalidIdentity("reader location")
        }
        self.bookCode = bookCode
        self.chapter = chapter
        self.scrollY = max(0, scrollY)
        self.updatedAt = updatedAt
        self.anchor = anchor
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let decodedScrollY = try values.decode(Double.self, forKey: .scrollY)
        guard decodedScrollY >= 0 else {
            throw CoreError.invalidIdentity("reader location")
        }
        try self.init(
            bookCode: values.decode(BookCode.self, forKey: .bookCode),
            chapter: values.decode(Int.self, forKey: .chapter),
            scrollY: decodedScrollY,
            updatedAt: values.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? 0,
            anchor: values.decodeIfPresent(ReaderAnchor.self, forKey: .anchor)
        )
    }
}

public struct SavedHighlightVerse: Codable, Hashable, Sendable {
    public let verseKey: String; public let batchID: String; public let verse: VerseLabel
    public let verseIndex: Int; public let verseText: String; public let createdAt: Int64; public let updatedAt: Int64
    public init(verseKey: String, batchID: String, verse: VerseLabel, verseIndex: Int, verseText: String,
                createdAt: Int64, updatedAt: Int64) throws {
        guard !verseKey.isEmpty, !batchID.isEmpty, verseIndex >= 0 else { throw CoreError.invalidIdentity("saved highlight") }
        self.verseKey = verseKey; self.batchID = batchID; self.verse = verse; self.verseIndex = verseIndex
        self.verseText = verseText; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}
public enum SavedItemKind: String, Codable, Sendable { case bookmark, highlight, note }
public enum HighlightColor: String, Codable, Sendable { case gold, sage, rose, blue }
public struct SavedItem: Codable, Hashable, Sendable {
    public let id: String; public let kind: SavedItemKind; public let translationID: String; public let bookCode: String
    public let bookName: String; public let bookOrder: Int; public let chapter: Int
    public let startVerse: String; public let endVerse: String; public let startIndex: Int; public let endIndex: Int
    public let scriptureText: String; public let reference: String
    public let createdAt: Int64; public let updatedAt: Int64
    public let color: HighlightColor?; public let noteText: String?
    public let verseKeys: [String]?; public let highlightVerses: [SavedHighlightVerse]?
    public init(id: String, kind: SavedItemKind, translationID: String, bookCode: String, bookName: String,
                bookOrder: Int, chapter: Int, startVerse: String, endVerse: String, startIndex: Int, endIndex: Int,
                scriptureText: String, reference: String, createdAt: Int64, updatedAt: Int64,
                color: HighlightColor? = nil, noteText: String? = nil, verseKeys: [String]? = nil,
                highlightVerses: [SavedHighlightVerse]? = nil) {
        self.id = id; self.kind = kind; self.translationID = translationID; self.bookCode = bookCode
        self.bookName = bookName; self.bookOrder = bookOrder; self.chapter = chapter
        self.startVerse = startVerse; self.endVerse = endVerse; self.startIndex = startIndex; self.endIndex = endIndex
        self.scriptureText = scriptureText; self.reference = reference; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.color = color; self.noteText = noteText; self.verseKeys = verseKeys; self.highlightVerses = highlightVerses
    }
}

public struct BibleTranslationMetadata: Codable, Hashable, Sendable {
    public let id: String; public let name: String; public let fullName: String
    public let abbreviation: String; public let language: String; public let isPublicDomain: Bool
    public let attribution: String; public let copyrightNotice: String
}

public struct BibleBookDescriptor: Codable, Hashable, Sendable {
    public let code: String; public let name: String; public let longName: String
    public let group: String; public let order: Int; public let chapterCount: Int
}

public struct VerseBreak: Codable, Hashable, Sendable { public let offset: Int; public let kind: String }
public struct VerseHeading: Codable, Hashable, Sendable { public let kind: String; public let text: String; public let offset: Int? }
public struct BibleVerse: Decodable, Hashable, Sendable {
    public let label: String; public let text: String; public let breaks: [VerseBreak]; public let headings: [VerseHeading]
    private enum CodingKeys: String, CodingKey { case label = "n", text = "t", breaks = "br", headings = "hd" }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        text = try container.decode(String.self, forKey: .text)
        let rawBreaks = try container.decodeIfPresent([[RawBibleAtom]].self, forKey: .breaks) ?? []
        breaks = try rawBreaks.map { row in
            guard row.count == 2, case let .integer(offset) = row[0], case let .string(kind) = row[1] else {
                throw CoreError.invalidResource("invalid Bible verse break")
            }
            return VerseBreak(offset: offset, kind: kind)
        }
        let rawHeadings = try container.decodeIfPresent([[RawBibleAtom]].self, forKey: .headings) ?? []
        headings = try rawHeadings.map { row in
            guard row.count == 2 || row.count == 3, case let .string(kind) = row[0], case let .string(text) = row[1] else {
                throw CoreError.invalidResource("invalid Bible verse heading")
            }
            let offset: Int?
            if row.count == 3 {
                guard case let .integer(value) = row[2] else { throw CoreError.invalidResource("invalid heading offset") }
                offset = value
            } else { offset = nil }
            return VerseHeading(kind: kind, text: text, offset: offset)
        }
    }
}
public struct BibleChapter: Decodable, Hashable, Sendable {
    public let number: Int; public let verses: [BibleVerse]
    private enum CodingKeys: String, CodingKey { case number = "c", verses }
}
public struct BibleBook: Decodable, Hashable, Sendable {
    public let code: String; public let name: String; public let longName: String; public let group: String
    public let chapters: [BibleChapter]
}

public struct WorkCollection: Codable, Hashable, Sendable {
    public let id: String; public let title: String; public let author: String; public let era: String?
    public let translation: String; public let attribution: String; public let workCount: Int
    public let sectionCount: Int; public let words: Int; public let order: Int
}
public struct WorkMetadata: Codable, Hashable, Sendable {
    public let id: String; public let collectionID: String; public let title: String
    public let order: Int; public let sectionCount: Int; public let words: Int
    public let book: String?; public let kind: String
    private enum CodingKeys: String, CodingKey { case id, collectionID = "collectionId", title, order, sectionCount, words, book, kind }
}
public struct WorkCatalog: Codable, Hashable, Sendable {
    public let collections: [WorkCollection]; public let works: [WorkMetadata]
    public let commentary: [String: [String: [CommentaryEntry]]]
}
public struct CommentaryEntry: Codable, Hashable, Sendable {
    public let workID: String; public let workTitle: String; public let sectionIndex: Int
    public let sectionTitle: String; public let collectionID: String
    /// Verse range, present for verse-by-verse commentary (the Catena Aurea, 2.2.0). Older entries cover a chapter.
    public let fromVerse: Int?; public let toVerse: Int?
    private enum CodingKeys: String, CodingKey { case workID = "workId", workTitle, sectionIndex, sectionTitle, collectionID = "collectionId", fromVerse, toVerse }
    public init(workID: String, workTitle: String, sectionIndex: Int, sectionTitle: String, collectionID: String,
                fromVerse: Int? = nil, toVerse: Int? = nil) {
        self.workID = workID; self.workTitle = workTitle; self.sectionIndex = sectionIndex
        self.sectionTitle = sectionTitle; self.collectionID = collectionID; self.fromVerse = fromVerse; self.toVerse = toVerse
    }
}
public struct WorkSection: Codable, Hashable, Sendable {
    public let index: Int; public let title: String; public let words: Int; public let paragraphs: [String]
    public init(index: Int, title: String, words: Int, paragraphs: [String]) throws {
        guard index >= 0, words >= 0 else { throw CoreError.invalidIdentity("work section") }
        self.index = index; self.title = title; self.words = words; self.paragraphs = paragraphs
    }
}

public struct WorkSectionSummary: Codable, Hashable, Sendable {
    public let index: Int
    public let title: String
    public let words: Int

    public init(index: Int, title: String, words: Int) throws {
        guard index >= 0, words >= 0 else { throw CoreError.invalidIdentity("work section summary") }
        self.index = index
        self.title = title
        self.words = words
    }
}

public enum RotationScope: String, Codable, CaseIterable, Sendable { case full, ot, nt }
public enum SearchScope: String, Codable, CaseIterable, Sendable { case all, ot, nt }
public struct RotatingVerse: Codable, Hashable, Sendable {
    public let reference: String; public let bookCode: String; public let chapter: Int
    public let verseLabel: String; public let text: String
}

public struct ClockReading: Sendable, Equatable {
    public let instant: Date; public let timeZoneIdentifier: String; public let utcOffsetSeconds: Int
    public init(instant: Date, timeZoneIdentifier: String, utcOffsetSeconds: Int) {
        self.instant = instant; self.timeZoneIdentifier = timeZoneIdentifier; self.utcOffsetSeconds = utcOffsetSeconds
    }
}
public protocol CoreClock: Sendable { func now() -> ClockReading }
public struct SystemCoreClock: CoreClock {
    public init() {}
    public func now() -> ClockReading {
        let instant = Date(); let zone = TimeZone.current
        return ClockReading(instant: instant, timeZoneIdentifier: zone.identifier, utcOffsetSeconds: zone.secondsFromGMT(for: instant))
    }
}

public struct ResourceRoots: Sendable {
    /// URL of the staged `App` resource directory. Callers supply bundle lookup.
    public let app: URL
    /// URL of the staged `Widget` resource directory when it is available.
    public let widget: URL?
    public init(app: URL, widget: URL? = nil) { self.app = app; self.widget = widget }
    public func appResource(_ components: String...) throws -> URL { try resolve(components, under: app) }
    public func widgetResource(_ components: String...) throws -> URL {
        guard let widget else { throw CoreError.missingResource("widget root") }
        return try resolve(components, under: widget)
    }
    private func resolve(_ components: [String], under root: URL) throws -> URL {
        guard !components.isEmpty, components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("/") }) else {
            throw CoreError.invalidResource("resource path")
        }
        let url = components.reduce(root) { $0.appendingPathComponent($1) }.standardizedFileURL
        guard url.path.hasPrefix(root.standardizedFileURL.path + "/") else { throw CoreError.invalidResource("resource path escaped root") }
        return url
    }
}
