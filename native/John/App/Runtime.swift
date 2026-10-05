import Foundation
import Observation
import SwiftUI
import JohnCore

@MainActor @Observable final class SharedPreferencesModel {
    var reading = ReadingPreferences.sourceDefaults
    var translation: TranslationID = .webCE
    var scope: RotationScope = .full
    var intervalMinutes = NativePersistentState().rotationIntervalMinutes
    var appearance: AppearanceMode = .system

    func setTextSize(_ value: ReaderTextSize) { reading = ReadingPreferences(textSize: value, lineSpacing: reading.lineSpacing, typeface: reading.typeface, layout: reading.layout) }
    func setLineSpacing(_ value: ReaderLineSpacing) { reading = ReadingPreferences(textSize: reading.textSize, lineSpacing: value, typeface: reading.typeface, layout: reading.layout) }
    func setTypeface(_ value: ReaderTypeface) { reading = ReadingPreferences(textSize: reading.textSize, lineSpacing: reading.lineSpacing, typeface: value, layout: reading.layout) }
    func setLayout(_ value: ReaderLayout) { reading = ReadingPreferences(textSize: reading.textSize, lineSpacing: reading.lineSpacing, typeface: reading.typeface, layout: value) }

    func colors(for colorScheme: ColorScheme) -> JohnColors {
        switch appearance { case .light: .light; case .dark: .dark; case .system: colorScheme == .dark ? .dark : .light }
    }
    var preferredColorScheme: ColorScheme? {
        switch appearance { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable, Hashable {
    case system, light, dark
    var id: String { rawValue }
}

@MainActor @Observable final class JohnRuntime {
    let preferences = SharedPreferencesModel()
    let reader = ReaderModel()
    let today: TodayModel
    let novenaNames: [String: String] = [:]
    private(set) var startupStatus = "Ready"
    @ObservationIgnored private let appResourceRoot: URL?
    @ObservationIgnored private let bible: BundledBibleRepository?
    @ObservationIgnored private let works: SQLiteWorksRepository?
    @ObservationIgnored private let rotation: IndexedRotationRepository?

    init(bundle: Bundle = .main) {
        let root = bundle.resourceURL?.appendingPathComponent("App", isDirectory: true)
        appResourceRoot = root
        if let root {
            let roots = ResourceRoots(app: root)
            let bibleRepository = BundledBibleRepository(roots: roots)
            let rotationRepository = IndexedRotationRepository(roots: roots)
            bible = bibleRepository
            rotation = rotationRepository
            works = SQLiteWorksRepository(roots: roots)
            today = TodayModel(appResources: root, rotation: rotationRepository)
        } else {
            bible = nil
            rotation = nil
            works = nil
            today = TodayModel(appResources: nil, rotation: nil)
            startupStatus = "App resources are missing."
        }
    }

    func passage(translation: TranslationID, bookCode: String, chapter number: Int,
                 startVerse: String, endVerse: String) async -> PassageSelection? {
        guard let bible, let code = BookCode(rawValue: bookCode),
              let start = VerseLabel(rawValue: startVerse), let end = VerseLabel(rawValue: endVerse) else { return nil }
        do {
            let chapter = try await bible.chapter(translation: translation, book: code, chapter: number)
            guard let firstIndex = chapter.verses.firstIndex(where: { $0.label == startVerse }),
                  let lastIndex = chapter.verses.firstIndex(where: { $0.label == endVerse }), firstIndex <= lastIndex else { return nil }
            let id = try PassageID(translationID: translation, bookCode: code, chapter: number, startVerse: start, endVerse: end)
            return try await bible.passage(id: id, startIndex: firstIndex, endIndex: lastIndex)
        } catch { return nil }
    }

    func passage(reference: String, translation: TranslationID) async -> PassageSelection? {
        guard let (book, chapter, first, last) = ReferenceParser.parse(reference), let bible else { return nil }
        do {
            let manifest = try await bible.manifest(for: translation)
            let normalized = book.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            guard let descriptor = manifest.first(where: {
                [$0.name, $0.longName, $0.code].contains { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) == normalized }
            }) else { return nil }
            return await passage(translation: translation, bookCode: descriptor.code, chapter: chapter, startVerse: first, endVerse: last)
        } catch { return nil }
    }
}

private enum ReferenceParser {
    static func parse(_ text: String) -> (String, Int, String, String)? {
        let pattern = #"^\s*(.+?)\s+(\d+)\s*:\s*([\p{L}\p{N}]+)(?:\s*[-–]\s*([\p{L}\p{N}]+))?\s*$"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let bookRange = Range(match.range(at: 1), in: text), let chapterRange = Range(match.range(at: 2), in: text),
              let firstRange = Range(match.range(at: 3), in: text) else { return nil }
        let lastRange = Range(match.range(at: 4), in: text)
        guard let chapter = Int(text[chapterRange]) else { return nil }
        let first = String(text[firstRange])
        return (String(text[bookRange]), chapter, first, lastRange.map { String(text[$0]) } ?? first)
    }
}
