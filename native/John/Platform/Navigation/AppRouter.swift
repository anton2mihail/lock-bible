import Foundation
import Observation
import SwiftUI
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
    /// A Reader pushed on the origin tab's stack (E5). `sourceID` names the list row that zooms into it.
    case reader(ReaderChapterRequest, sourceID: String?)
}

struct VerseMomentSelection: Hashable, Sendable {
    let verse: RotatingVerse
    let translation: TranslationID
}

enum AppSheet: String, Identifiable {
    case readerAppearance
    /// Go to, shown as a sheet over the Reader (audit B6). The Reader passes its current book and chapter.
    case goTo
    var id: String { rawValue }
}

/// The five root tabs, in source order. The raw value is the exact visible label.
enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case today = "Today"
    case read = "Read"
    case saved = "Saved"
    case pray = "Pray"
    case settings = "Settings"

    var id: String { rawValue }
    /// The accessibility identifier of the tab bar button, for example `tab-read`. UI tests select tabs with it.
    var identifier: String { "tab-\(rawValue.lowercased())" }
}

@MainActor @Observable final class AppRouter {
    private(set) var selectedTab: AppTab = .today
    /// Changes each time the selection moves into the Read tab. The shell uses it as the identity of the Read root,
    /// so each Read-tab entry creates a new `ReaderView`, as the flat-bar shell did. The `ReaderView` `.task` and
    /// `ReaderScreenModel.receive` request handling (commit 9d3753c) were verified with that lifecycle.
    private(set) var readEntryID = UUID()
    var sheet: AppSheet?
    /// An App Intent sets this. The Reader starts read aloud when the chapter is ready, then clears it.
    var pendingReadAloud = false
    private(set) var latestPassageRequest: PassageRequest?
    private(set) var latestChapterRequest: ReaderChapterRequest?
    private var paths: [AppTab: [AppRoute]] = [:]

    /// The tab that code changed last (a programmatic select, a deep link, a notification route, or an `openReader…` call),
    /// and when. SwiftUI can write the selected tab back through the `TabView` binding after a programmatic change
    /// (an echo). For a short time `selectFromTabBar` treats a same-tab write for this tab as such an echo and does not pop.
    @ObservationIgnored private var routedByCode: (tab: AppTab, at: ContinuousClock.Instant)?
    private static let echoWindow: Duration = .seconds(1)

    private func markRoutedByCode(_ tab: AppTab) { routedByCode = (tab, ContinuousClock.now) }
    private func isRecentlyRoutedByCode(_ tab: AppTab) -> Bool {
        guard let mark = routedByCode, mark.tab == tab else { return false }
        return mark.at.duration(to: ContinuousClock.now) < Self.echoWindow
    }
    private func applySelection(_ tab: AppTab) {
        guard tab != selectedTab else { return }
        selectedTab = tab
        if tab == .read { readEntryID = UUID() }
    }

    /// Changes the selected tab from code. It marks the tab as routed by code, also when the tab is already selected,
    /// because the caller changes that tab's path right after. The system tab bar writes through `selectFromTabBar`.
    func select(_ tab: AppTab) {
        markRoutedByCode(tab)
        applySelection(tab)
    }

    /// A write from the tab bar binding. A real tap on the tab that is already selected pops that tab to its root, as iOS
    /// users expect. While the tab is marked as routed by code (about 1 s), a same-tab write is treated as an echo: it
    /// clears the mark and returns without popping. A write for a different tab clears the mark. A real re-tap within
    /// that short time after a deep link is ignored.
    func selectFromTabBar(_ tab: AppTab) {
        let same = tab == selectedTab
        let pathCount = paths[tab, default: []].count
        var popped = false
        var echo = false
        if same {
            if isRecentlyRoutedByCode(tab) {
                echo = true
            } else {
                popped = pathCount > 0
                paths[tab] = []
            }
            routedByCode = nil
        } else {
            routedByCode = nil
            applySelection(tab)
        }
        #if DEBUG
        NSLog("JOHN_TABBAR_WRITE tab=%@ same=%d pathCount=%d popped=%d ignoredEcho=%d", tab.rawValue, same ? 1 : 0,
              pathCount, popped ? 1 : 0, echo ? 1 : 0)
        #endif
    }

    func path(for tab: AppTab) -> [AppRoute] { paths[tab, default: []] }
    func setPath(_ path: [AppRoute], for tab: AppTab) { paths[tab] = path }
    func push(_ route: AppRoute) { paths[selectedTab, default: []].append(route) }
    func pop() {
        guard !paths[selectedTab, default: []].isEmpty else { return }
        paths[selectedTab]?.removeLast()
    }
    func openReader(passage: PassageSelection) {
        select(.read)
        paths[.read] = []
        latestPassageRequest = PassageRequest(passage: passage)
        #if DEBUG
        NSLog("John Reader request created id=%@ kind=passage", latestPassageRequest!.id.uuidString)
        #endif
    }
    func openReader(bookCode: String, chapter: Int, translation: TranslationID, verse: String? = nil, endVerse: String? = nil) {
        select(.read)
        paths[.read] = []
        latestChapterRequest = ReaderChapterRequest(bookCode: bookCode, chapter: chapter, translationID: translation,
                                                    verse: verse, endVerse: endVerse)
        #if DEBUG
        NSLog("John Reader request created id=%@ kind=chapter", latestChapterRequest!.id.uuidString)
        #endif
    }
    /// Pushes a Reader for `passage` on the selected tab's stack. Back returns to the list that opened it.
    func pushReader(passage: PassageSelection, sourceID: String? = nil) {
        let request = ReaderChapterRequest(bookCode: passage.bookCode.rawValue, chapter: passage.chapter,
                                           translationID: passage.translationID,
                                           verse: passage.startVerse.rawValue, endVerse: passage.endVerse.rawValue)
        paths[selectedTab, default: []].append(.reader(request, sourceID: sourceID))
        #if DEBUG
        NSLog("John Reader pushed id=%@ tab=%@", request.id.uuidString, selectedTab.rawValue)
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
        pushReader(passage: passage, sourceID: "saved-\(item.id)")
        return true
    }
    /// Shows the chapter list of a book. `chapter` 0 is below the valid range, so the Reader model opens the list.
    func openReaderChapterList(bookCode: String, translation: TranslationID) {
        select(.read)
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
            select(.today)
            paths[.today, default: []].append(.daily(key))
            markRoutedByCode(.today)
        case .saved:
            select(.saved)
            paths[.saved] = []
            markRoutedByCode(.saved)
        case .rosary:
            select(.pray)
            paths[.pray] = [.companion(.rosaryHome)]
            markRoutedByCode(.pray)
        case .readAloud:
            let location = runtime.preferences.readerLocation
            pendingReadAloud = true
            openReader(bookCode: location?.bookCode.rawValue ?? "JHN", chapter: location?.chapter ?? 1,
                       translation: runtime.preferences.translation)
        case .note:
            let translation = runtime.preferences.translation
            if let passage = await runtime.passage(translation: translation, bookCode: "JHN", chapter: 1,
                                                   startVerse: "1", endVerse: "1") {
                select(.read)
                paths[.read] = [.noteEditor(passage)]
                markRoutedByCode(.read)
            } else {
                openReader(bookCode: "JHN", chapter: 1, translation: translation)
            }
        case let .read(bookCode, chapter, verse, endVerse, requestedTranslation):
            // Old app: the Read tab opens for every `read` URL. Then ReaderScreen.tsx:286-308 decides.
            let translation = requestedTranslation ?? runtime.preferences.translation
            let books = await runtime.books(translation: translation)
            guard let bookCode, let book = books.first(where: { $0.code == bookCode }) else {
                // Unknown or missing book: the old effect returns (ReaderScreen.tsx:287-289). Only the tab changes.
                select(.read)
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

// MARK: - Today zoom transitions (audit item B7)

extension EnvironmentValues {
    /// The Today tab publishes this namespace. Other tabs leave it nil, so their pushes keep the standard transition.
    @Entry var todayZoomNamespace: Namespace.ID?
}

extension EnvironmentValues {
    /// Every tab publishes this namespace. Saved and Search rows are sources of the zoom into a pushed Reader.
    @Entry var readerZoomNamespace: Namespace.ID?
}

extension View {
    func readerZoomSource(id: String) -> some View { modifier(ReaderZoomSource(id: id)) }
    func readerZoomDestination(sourceID: String?) -> some View { modifier(ReaderZoomDestination(sourceID: sourceID)) }
}

private struct ReaderZoomSource: ViewModifier {
    let id: String
    @Environment(\.readerZoomNamespace) private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder func body(content: Content) -> some View {
        if let namespace, !reduceMotion { content.matchedTransitionSource(id: id, in: namespace) } else { content }
    }
}

private struct ReaderZoomDestination: ViewModifier {
    let sourceID: String?
    @Environment(\.readerZoomNamespace) private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder func body(content: Content) -> some View {
        if let namespace, let sourceID, !reduceMotion {
            content.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else { content }
    }
}

extension View {
    /// Marks a Today card as the source of the zoom into the page that `route` opens.
    func todayZoomSource(_ route: CompanionRoute, cornerRadius: CGFloat = 0) -> some View {
        modifier(TodayZoomSource(route: .companion(route), cornerRadius: cornerRadius))
    }

    /// Makes a page that Today opens zoom from its card. Other routes keep the standard push.
    func todayZoomDestination(_ route: AppRoute) -> some View {
        modifier(TodayZoomDestination(route: route))
    }
}

private struct TodayZoomSource: ViewModifier {
    let route: AppRoute
    let cornerRadius: CGFloat
    @Environment(\.todayZoomNamespace) private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder func body(content: Content) -> some View {
        if let namespace, !reduceMotion {
            content.matchedTransitionSource(id: route, in: namespace) {
                $0.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        } else {
            content
        }
    }
}

private struct TodayZoomDestination: ViewModifier {
    let route: AppRoute
    @Environment(\.todayZoomNamespace) private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The routes that a Today card pushes with a zoom: the daily readings, the Rosary guide, and Sunday.
    private var isTodayCardRoute: Bool {
        switch route {
        case .companion(.daily), .companion(.rosaryGuide), .companion(.sunday): true
        default: false
        }
    }

    @ViewBuilder func body(content: Content) -> some View {
        if let namespace, !reduceMotion, isTodayCardRoute {
            content.navigationTransition(.zoom(sourceID: route, in: namespace))
        } else {
            content
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
