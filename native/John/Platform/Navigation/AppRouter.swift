import Foundation
import Observation
import JohnCore

struct PassageRequest: Identifiable, Sendable, Hashable {
    let id: UUID
    let passage: PassageSelection
    let requestedAt: Date

    init(passage: PassageSelection, requestedAt: Date = Date()) {
        id = UUID()
        self.passage = passage
        self.requestedAt = requestedAt
    }
}

struct ReaderChapterRequest: Identifiable, Sendable, Hashable {
    let id: UUID
    let bookCode: String
    let chapter: Int
    let translationID: TranslationID
    let verse: String?
    let endVerse: String?

    init(bookCode: String, chapter: Int, translationID: TranslationID, verse: String? = nil, endVerse: String? = nil) {
        self.init(id: UUID(), bookCode: bookCode, chapter: chapter, translationID: translationID, verse: verse, endVerse: endVerse)
    }

    init(id: UUID, bookCode: String, chapter: Int, translationID: TranslationID, verse: String? = nil, endVerse: String? = nil) {
        self.id = id
        self.bookCode = bookCode
        self.chapter = chapter
        self.translationID = translationID
        self.verse = verse
        self.endVerse = endVerse
    }
}

enum AppRoute: Hashable, Sendable {
    case search
    case passage(PassageSelection)
    case goTo(bookCode: String?, chapter: Int?)
    case works
    case daily(String)
    case sunday
    case rosaryGuide(String)
    case prayer(String)
    case novena(String)
    case verseMoment
    case learn
    case confession
}

enum AppSheet: String, Identifiable {
    case readerAppearance
    var id: String { rawValue }
}

@MainActor @Observable final class AppRouter {
    var selectedTab: AppTab = .today
    var sheet: AppSheet?
    private(set) var latestPassageRequest: PassageRequest?
    private(set) var latestChapterRequest: ReaderChapterRequest?
    private var paths: [AppTab: [AppRoute]] = [:]

    func path(for tab: AppTab) -> [AppRoute] { paths[tab, default: []] }
    func setPath(_ path: [AppRoute], for tab: AppTab) { paths[tab] = path }
    func push(_ route: AppRoute) { paths[selectedTab, default: []].append(route) }
    func pop() {
        guard !paths[selectedTab, default: []].isEmpty else { return }
        paths[selectedTab]?.removeLast()
    }
    func openReader(passage: PassageSelection) {
        selectedTab = .read
        paths[.read] = []
        latestPassageRequest = PassageRequest(passage: passage)
        #if DEBUG
        NSLog("John Reader request created id=%@ kind=passage", latestPassageRequest!.id.uuidString)
        #endif
    }
    func openReader(bookCode: String, chapter: Int, translation: TranslationID, verse: String? = nil, endVerse: String? = nil) {
        selectedTab = .read
        paths[.read] = []
        latestChapterRequest = ReaderChapterRequest(bookCode: bookCode, chapter: chapter, translationID: translation,
                                                    verse: verse, endVerse: endVerse)
        #if DEBUG
        NSLog("John Reader request created id=%@ kind=chapter", latestChapterRequest!.id.uuidString)
        #endif
    }
    func openSavedItem(_ item: SavedItem, using runtime: JohnRuntime) async {
        guard let translation = TranslationID(rawValue: item.translationID),
              let passage = await runtime.passage(translation: translation, bookCode: item.bookCode,
                                                  chapter: item.chapter, startVerse: item.startVerse,
                                                  endVerse: item.endVerse) else { return }
        openReader(passage: passage)
    }
    func receive(_ url: URL, using runtime: JohnRuntime) async {
        guard let external = ExternalRouteParser.parse(url) else { return }
        switch external {
        case let .daily(date):
            selectedTab = .today
            paths[.today, default: []].append(.daily(date))
        case let .read(bookCode, chapter, verse, endVerse, requestedTranslation):
            let translation = requestedTranslation ?? runtime.preferences.translation
            guard let passage = await runtime.passage(translation: translation, bookCode: bookCode,
                                                       chapter: chapter, startVerse: verse, endVerse: endVerse ?? verse) else { return }
            openReader(passage: passage)
        }
    }
}

@MainActor final class StartupURLQueue {
    static let shared = StartupURLQueue()
    private var urls: [URL] = []
    private init() {}
    func enqueue(_ url: URL) { urls.append(url) }
    func drain() -> [URL] { defer { urls.removeAll() }; return urls }
}

@MainActor @Observable final class ReaderModel {
    private(set) var openRequest: ReaderChapterRequest?
    private(set) var errorMessage: String?

    func accept(_ request: PassageRequest) {
        guard openRequest?.id != request.id else { return }
        openRequest = ReaderChapterRequest(id: request.id, bookCode: request.passage.bookCode.rawValue,
                                           chapter: request.passage.chapter,
                                           translationID: request.passage.translationID,
                                           verse: request.passage.startVerse.rawValue,
                                           endVerse: request.passage.endVerse.rawValue)
        errorMessage = nil
    }

    func accept(_ request: ReaderChapterRequest) {
        guard openRequest?.id != request.id else { return }
        openRequest = request
        errorMessage = nil
    }
}
