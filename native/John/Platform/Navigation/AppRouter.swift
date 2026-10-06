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
    case noteEditor(PassageSelection)
    case goTo(bookCode: String?, chapter: Int?)
    case works
    case daily(String)
    case sunday
    case rosaryGuide(String)
    case prayer(String)
    case novena(String)
    case learn
    case confession
    case companion(CompanionRoute)
    case verseMoment(VerseMomentSelection)
    case calendarNotifications
    case rosaryReminder
    case rosaryMedia(String)
    case workCollection(String)
    case workReader(workID: String, section: Int?)
    case worksChapterCommentary(bookCode: String?, chapter: Int?, bookName: String)
}

struct VerseMomentSelection: Hashable, Sendable {
    let verse: RotatingVerse
    let translation: TranslationID
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
    /// Loads the passage that a saved item names, with the item's own edition. Returns nil when it cannot load.
    func savedItemPassage(_ item: SavedItem, using runtime: JohnRuntime) async -> PassageSelection? {
        guard let translation = TranslationID(rawValue: item.translationID) else { return nil }
        return await runtime.passage(translation: translation, bookCode: item.bookCode,
                                     chapter: item.chapter, startVerse: item.startVerse,
                                     endVerse: item.endVerse)
    }
    /// Opens a saved item in the Reader. Returns false, and changes nothing, when the passage cannot load.
    @discardableResult
    func openSavedItem(_ item: SavedItem, using runtime: JohnRuntime) async -> Bool {
        guard let passage = await savedItemPassage(item, using: runtime) else { return false }
        openReader(passage: passage)
        return true
    }
    /// Shows the chapter list of a book. `chapter` 0 is below the valid range, so the Reader model opens the list.
    func openReaderChapterList(bookCode: String, translation: TranslationID) {
        selectedTab = .read
        paths[.read] = []
        latestChapterRequest = ReaderChapterRequest(bookCode: bookCode, chapter: 0, translationID: translation)
        #if DEBUG
        NSLog("John Reader request created id=%@ kind=chapterList", latestChapterRequest!.id.uuidString)
        #endif
    }
    func receive(_ url: URL, using runtime: JohnRuntime) async {
        guard let external = ExternalRouteParser.parse(url) else { return }
        switch external {
        case let .daily(date):
            // Old app: a missing or bad date shows today's readings (src/services/companion/calendar.ts:13-18).
            let key = date ?? CompanionCalendar.dateKey(runtime.featureNow(), timeZone: runtime.featureTimeZone)
            selectedTab = .today
            paths[.today, default: []].append(.daily(key))
        case .rosary:
            selectedTab = .pray
            paths[.pray] = [.companion(.rosaryHome)]
        case let .read(bookCode, chapter, verse, endVerse, requestedTranslation):
            // Old app: the Read tab opens for every `read` URL. Then ReaderScreen.tsx:286-308 decides.
            let translation = requestedTranslation ?? runtime.preferences.translation
            let books = await runtime.books(translation: translation)
            guard let bookCode, let book = books.first(where: { $0.code == bookCode }) else {
                // Unknown or missing book: the old effect returns (ReaderScreen.tsx:287-289). Only the tab changes.
                selectedTab = .read
                return
            }
            guard let chapter, (1...book.chapterCount).contains(chapter) else {
                // Known book, chapter missing or out of range: chapter list (ReaderScreen.tsx:302-308).
                openReaderChapterList(bookCode: book.code, translation: translation)
                return
            }
            // A missing, empty, or unknown verse opens the chapter at its top with no selection (ReaderScreen.tsx:129-130, :186-193).
            openReader(bookCode: book.code, chapter: chapter, translation: translation, verse: verse, endVerse: endVerse)
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
