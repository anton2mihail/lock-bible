import SwiftUI
import UIKit
import JohnCore

/// A chapter that the paged Reader loaded ahead, so a page turn across a chapter boundary needs no load.
private struct PrefetchedChapter {
    let book: BibleBookDescriptor
    let chapter: BibleChapter
    let layout: ChapterLayout
    let highlights: [Int: HighlightColor]
}

/// Page state of the paged Reader: the paginated open chapter, its two neighbors, and the page on screen.
@MainActor @Observable final class ReaderPagesModel {
    private(set) var current: ScripturePageID?
    private(set) var revision = 0
    private(set) var decorationRevision = 0
    private(set) var turnRequest: ScripturePageTurnRequest?
    @ObservationIgnored private var paginations: [ScriptureChapterKey: ScriptureChapterPagination] = [:]
    @ObservationIgnored private var prefetched: [ScriptureChapterKey: PrefetchedChapter] = [:]
    @ObservationIgnored private var paginationKey: ScripturePaginationKey?
    @ObservationIgnored private var prefetchTask: Task<Void, Never>?
    @ObservationIgnored private var prefetchGeneration = 0
    /// The chapters that the running prefetch loads. A second request for the same chapters does not restart it.
    @ObservationIgnored private var prefetchKeys: [ScriptureChapterKey] = []
    /// The Reader chapter request that the current pages belong to.
    @ObservationIgnored private var requestID: UUID?
    @ObservationIgnored private var handledRestoreID: UUID?
    @ObservationIgnored private var highlightsRevision: Int?

    func pagination(_ key: ScriptureChapterKey) -> ScriptureChapterPagination? { paginations[key] }

    var currentPagination: ScriptureChapterPagination? { current.flatMap { paginations[$0.key] } }

    var statusLabel: String {
        guard let current, let pagination = paginations[current.key] else { return "" }
        return "\(pagination.title), page \(current.page + 1) of \(pagination.pageCount)"
    }

    static func key(for reader: ReaderScreenModel) -> ScriptureChapterKey? {
        guard let book = reader.book, let number = reader.chapterNumber, reader.chapter?.number == number else { return nil }
        return ScriptureChapterKey(translation: reader.edition, bookCode: book.code, chapter: number)
    }

    func neighbor(of key: ScriptureChapterKey, forward: Bool, reader: ReaderScreenModel) -> ScriptureChapterKey? {
        guard let next = reader.adjacentChapter(from: key.bookCode, chapter: key.chapter, offset: forward ? 1 : -1) else { return nil }
        return ScriptureChapterKey(translation: key.translation, bookCode: next.book.code, chapter: next.chapter)
    }

    func decorations(for key: ScriptureChapterKey, reader: ReaderScreenModel, spokenIndex: Int?) -> ScripturePageDecorations {
        guard key == Self.key(for: reader) else {
            return ScripturePageDecorations(highlights: prefetched[key]?.highlights ?? [:])
        }
        return ScripturePageDecorations(highlights: reader.highlightColors, selection: reader.selectedRange,
                                        context: spokenIndex.map { $0...$0 } ?? reader.contextRange)
    }

    func redrawDecorations() { decorationRevision &+= 1 }

    /// Brings the pages up to date with the Reader model, the layout, and any pending restore or context verse.
    func sync(reader: ReaderScreenModel, key newPaginationKey: ScripturePaginationKey,
              location: ReaderLocation?, focusVerse: Int? = nil, runtime: JohnRuntime) {
        guard let book = reader.book, let chapter = reader.chapter, let layout = reader.layout,
              let key = Self.key(for: reader), let activeRequest = reader.activeChapterRequestID else { return }
        var preserved: (key: ScriptureChapterKey, anchor: ReaderAnchor)?
        var rebuilt = false
        if newPaginationKey != paginationKey {
            if let current, let old = paginations[current.key], let anchor = old.anchor(forPage: current.page) {
                preserved = (current.key, anchor)
            }
            cancelPrefetch()
            paginations = [:]
            paginationKey = newPaginationKey
            rebuilt = true
        }
        if paginations[key] == nil {
            paginations[key] = ScripturePaginator.paginate(key: key, bookName: book.name, chapter: chapter,
                                                           layout: layout, paginationKey: newPaginationKey)
            rebuilt = true
        }
        guard let pagination = paginations[key] else { return }
        var page = current?.key == key ? current!.page : 0
        if requestID != activeRequest {
            // A new chapter request: a context verse wins, then a saved place, then the first page.
            requestID = activeRequest
            if let index = reader.pendingContextIndex, let target = pagination.page(forVerse: index) {
                page = target
            } else if let restore = reader.pendingRestoreAnchor, restore.chapterRequestID == activeRequest {
                page = pagination.page(for: restore.anchor) ?? 0
                handledRestoreID = restore.id
                reader.clearPendingRestoreAnchor(restore.id)
            } else if let anchor = location?.anchor, location?.bookCode.rawValue == key.bookCode,
                      location?.chapter == key.chapter, current?.key != key {
                page = pagination.page(for: anchor) ?? 0
            } else if current?.key != key {
                page = 0
            }
            if reader.pendingRestoreScrollY != nil, reader.pendingRestoreAnchor == nil { reader.clearPendingRestore() }
        } else if let restore = reader.pendingRestoreAnchor, restore.id != handledRestoreID,
                  restore.chapterRequestID == activeRequest {
            // The Read tab appeared again and asked to restore the saved place.
            page = pagination.page(for: restore.anchor) ?? page
            handledRestoreID = restore.id
            reader.clearPendingRestoreAnchor(restore.id)
        } else if let preserved, preserved.key == key {
            // Text size, layout, or the page size changed: keep the same verse on screen. While read aloud speaks,
            // the spoken verse is the verse to keep.
            if let focusVerse, let target = pagination.page(forVerse: focusVerse) {
                page = target
            } else {
                page = pagination.page(for: preserved.anchor) ?? page
            }
        }
        page = min(max(page, 0), pagination.pageCount - 1)
        let target = ScripturePageID(key: key, page: page)
        if current != target { current = target }
        if rebuilt { revision &+= 1 }
        schedulePrefetch(around: key, reader: reader, runtime: runtime)
    }

    /// The open chapter's highlights changed (an undo, a redo, or a change in another place). Neighbor highlights
    /// load again with their next prefetch.
    func savedDataChanged(reader: ReaderScreenModel, runtime: JohnRuntime) {
        prefetched = [:]
        for key in paginations.keys where key != Self.key(for: reader) { paginations.removeValue(forKey: key) }
        if let key = Self.key(for: reader) { schedulePrefetch(around: key, reader: reader, runtime: runtime) }
        revision &+= 1
    }

    /// Loads and paginates the chapters on each side of the open one on a background task.
    private func schedulePrefetch(around key: ScriptureChapterKey, reader: ReaderScreenModel, runtime: JohnRuntime) {
        guard let paginationKey else { return }
        let wanted = [true, false].compactMap { forward -> (ScriptureChapterKey, BibleBookDescriptor)? in
            guard let next = reader.adjacentChapter(from: key.bookCode, chapter: key.chapter, offset: forward ? 1 : -1) else { return nil }
            return (ScriptureChapterKey(translation: key.translation, bookCode: next.book.code, chapter: next.chapter), next.book)
        }
        let keep = Set([key] + wanted.map(\.0))
        paginations = paginations.filter { keep.contains($0.key) }
        prefetched = prefetched.filter { keep.contains($0.key) }
        let missing = wanted.filter { paginations[$0.0] == nil }
        guard !missing.isEmpty else { return }
        if prefetchTask != nil, prefetchKeys == missing.map(\.0) { return }
        cancelPrefetch()
        prefetchKeys = missing.map(\.0)
        let generation = prefetchGeneration
        prefetchTask = Task { @MainActor [weak self] in
            defer {
                if let self, self.prefetchGeneration == generation { self.prefetchTask = nil; self.prefetchKeys = [] }
            }
            for (neighborKey, book) in missing {
                guard let loaded = await runtime.chapter(translation: neighborKey.translation, bookCode: book.code,
                                                         number: neighborKey.chapter),
                      !Task.isCancelled else { return }
                let labels = await runtime.chapterHighlights(translation: neighborKey.translation, bookCode: book.code,
                                                             chapter: neighborKey.chapter)
                let bookName = book.name
                let result = await Task.detached(priority: .userInitiated) { () -> (ChapterLayout, ScriptureChapterPagination)? in
                    guard let layout = try? ChapterLayout.build(loaded) else { return nil }
                    return (layout, ScripturePaginator.paginate(key: neighborKey, bookName: bookName, chapter: loaded,
                                                                layout: layout, paginationKey: paginationKey))
                }.value
                guard let self, !Task.isCancelled, self.prefetchGeneration == generation,
                      self.paginationKey == paginationKey, let result else { return }
                let highlights = labels.reduce(into: [Int: HighlightColor]()) { values, item in
                    if let index = loaded.verses.firstIndex(where: { $0.label == item.key }) { values[index] = item.value }
                }
                self.paginations[neighborKey] = result.1
                self.prefetched[neighborKey] = PrefetchedChapter(book: book, chapter: loaded, layout: result.0,
                                                                 highlights: highlights)
                self.revision &+= 1
            }
        }
    }

    /// A page turn finished. A turn into a neighbor chapter makes it the open chapter. Returns true when the reader
    /// is on the last page of the open chapter.
    @discardableResult
    func settle(_ id: ScripturePageID, reader: ReaderScreenModel, runtime: JohnRuntime) -> Bool {
        if id.key != Self.key(for: reader) {
            guard let data = prefetched[id.key] else { return false }
            // Keep the chapter that was open, so a turn back into it can adopt it again without a load.
            if let previousKey = Self.key(for: reader), let book = reader.book, let chapter = reader.chapter,
               let layout = reader.layout {
                prefetched[previousKey] = PrefetchedChapter(book: book, chapter: chapter, layout: layout,
                                                            highlights: reader.highlightColors)
            }
            reader.adoptPagedChapter(data.book, number: id.key.chapter, chapter: data.chapter, layout: data.layout,
                                     highlights: data.highlights)
            requestID = reader.activeChapterRequestID
            prefetched.removeValue(forKey: id.key)
            schedulePrefetch(around: id.key, reader: reader, runtime: runtime)
        }
        current = id
        guard let pagination = paginations[id.key], let request = reader.activeChapterRequestID else { return false }
        let anchor = pagination.anchor(forPage: id.page)
        Task { await reader.saveScrollLocation(0, bookCode: id.key.bookCode, chapter: id.key.chapter,
                                               requestID: request, anchor: anchor, using: runtime) }
        return id.page == pagination.pageCount - 1
    }

    /// Read aloud goes on: show the page of the spoken verse when it is not on screen.
    func follow(verse index: Int) {
        guard let current, let pagination = paginations[current.key],
              !pagination.verse(index, isOnPage: current.page),
              let page = pagination.page(forVerse: index), page != current.page else { return }
        let target = ScripturePageID(key: current.key, page: page)
        turnRequest = ScripturePageTurnRequest(target: target, forward: page > current.page)
        self.current = target
    }

    func cancelPrefetch() {
        prefetchTask?.cancel()
        prefetchTask = nil
        prefetchKeys = []
        prefetchGeneration &+= 1
    }
}

/// The paged Reader for the open chapter. The caller gives the chrome. The page area fills the screen and does not
/// change size when the chrome or the tab bar shows or hides, so the pages are not built again.
struct ReaderPagedView<TopChrome: View, BottomContent: View>: View {
    let model: ReaderScreenModel
    let reading: ReadingPreferences
    let dynamicTypeScale: CGFloat
    let isDark: Bool
    let spokenIndex: Int?
    let location: ReaderLocation?
    let savedRevision: Int
    let chromeVisible: Bool
    /// True while the audio mini player shows over the bottom of the page. The pages then keep their text and
    /// footer above it.
    let audioBarVisible: Bool
    let onToggleChrome: () -> Void
    let onHideChrome: () -> Void
    /// A tap on a verse while a selection is active, or a VoiceOver activation.
    let onTapVerse: (Int) -> Void
    /// Returns true when the tap only closed something (for example the Aa sheet).
    let onBackgroundTap: () -> Bool
    let onReachedChapterEnd: () -> Void
    @ViewBuilder let topChrome: () -> TopChrome
    @ViewBuilder let bottomContent: () -> BottomContent

    @Environment(JohnRuntime.self) private var runtime
    @State private var pages = ReaderPagesModel()

    private var colors: ScripturePageColors { ScripturePageColors(isDark: isDark) }

    private struct DecorationState: Equatable {
        let highlights: [Int: HighlightColor]
        let selection: ClosedRange<Int>?
        let context: ClosedRange<Int>?
    }

    private struct SyncState: Equatable {
        let key: ScripturePaginationKey
        let request: UUID?
        let hasChapter: Bool
        let restore: UUID?
        let context: Int?
    }

    var body: some View {
        GeometryReader { proxy in
            let paginationKey = makePaginationKey(size: proxy.size)
            Group {
                if let current = pages.current, pages.pagination(current.key) != nil {
                    ScripturePageBook(
                        current: current,
                        revision: pages.revision,
                        decorationRevision: pages.decorationRevision,
                        turnRequest: pages.turnRequest,
                        background: colors.background,
                        pagination: { pages.pagination($0) },
                        neighbor: { pages.neighbor(of: $0, forward: $1, reader: model) },
                        decorations: { pages.decorations(for: $0, reader: model, spokenIndex: spokenIndex) },
                        onTap: handleTap,
                        onLongPress: { key, verse in
                            guard key == ReaderPagesModel.key(for: model) else { return }
                            if model.selectedRange?.contains(verse) != true { onTapVerse(verse) }
                        },
                        onActivateVerse: { key, verse in
                            guard key == ReaderPagesModel.key(for: model) else { return }
                            onTapVerse(verse)
                        },
                        onSettle: { id, byUser in
                            let atEnd = pages.settle(id, reader: model, runtime: runtime)
                            if byUser { onHideChrome() }
                            if atEnd, byUser { onReachedChapterEnd() }
                        },
                        onDragStart: onHideChrome
                    )
                } else {
                    Color(uiColor: colors.background)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onChange(of: SyncState(key: paginationKey, request: model.activeChapterRequestID,
                                    hasChapter: model.chapter != nil, restore: model.pendingRestoreAnchor?.id,
                                    context: model.pendingContextIndex), initial: true) { _, _ in
                pages.sync(reader: model, key: paginationKey, location: location, focusVerse: spokenIndex,
                           runtime: runtime)
            }
        }
        .ignoresSafeArea()
        .overlay { chrome }
        .onChange(of: DecorationState(highlights: model.highlightColors, selection: model.selectedRange,
                                      context: spokenIndex.map { $0...$0 } ?? model.contextRange)) { _, _ in
            pages.redrawDecorations()
        }
        .onChange(of: spokenIndex) { _, index in
            if let index { pages.follow(verse: index) }
        }
        .onChange(of: savedRevision) { _, _ in pages.savedDataChanged(reader: model, runtime: runtime) }
        // A chapter that fits on one page counts as read after 2 s on screen, as in the scroll Reader.
        .task(id: "\(pages.current?.key.bookCode ?? "")-\(pages.current?.key.chapter ?? 0)-\(pages.currentPagination?.pageCount ?? 0)") {
            guard pages.currentPagination?.pageCount == 1 else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, pages.currentPagination?.pageCount == 1 else { return }
            onReachedChapterEnd()
        }
        .onDisappear { pages.cancelPrefetch() }
    }

    /// True when the selection panel would cover the selected verses at the bottom of the page. The panel then
    /// shows at the top of the page, as the Apple Books menu moves away from the selected text.
    private var bottomContentAtTop: Bool {
        guard let range = model.selectedRange, let current = pages.current,
              current.key == ReaderPagesModel.key(for: model), let pagination = pages.currentPagination,
              let extent = pagination.verticalExtent(ofVerses: range, onPage: current.page) else { return false }
        let height = pagination.geometry.size.height
        return extent.upperBound > height - Self.selectionPanelHeight && extent.lowerBound > Self.selectionPanelHeight + 40
    }

    /// About the height of the selection panel with its margins.
    private static var selectionPanelHeight: CGFloat { 220 }

    private var chrome: some View {
        VStack(spacing: 0) {
            if chromeVisible { topChrome() }
            let atTop = bottomContentAtTop
            if atTop { bottomContent().padding(.top, 8) }
            Spacer(minLength: 0)
            if !atTop { bottomContent() }
            // The page position for VoiceOver and UI tests. The page footer draws the same text, so this element
            // has no visible text of its own.
            Text(pages.statusLabel)
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .accessibilityLabel(pages.statusLabel)
                .accessibilityIdentifier("reader-page-status")
        }
    }

    private func handleTap(_ tap: ScripturePageTap) -> ScripturePageTapResult {
        if onBackgroundTap() { return .none }
        if model.selectedRange != nil {
            // With a selection, a tap on a verse changes the selection, and any other tap only clears it.
            if let verse = tap.verse, tap.key == ReaderPagesModel.key(for: model) { onTapVerse(verse) }
            else { model.clearSelection() }
            return .none
        }
        switch tap.zone {
        case .leading: return .turn(forward: false)
        case .trailing: return .turn(forward: true)
        case .middle:
            onToggleChrome()
            return .none
        }
    }

    private func makePaginationKey(size: CGSize) -> ScripturePaginationKey {
        let insets = Self.windowSafeAreaInsets
        // The mini player floats over the page bottom, also when the tab bar hides. It is about 48 pt high and sits
        // 36 pt above the bottom safe area line.
        let bottom = audioBarVisible ? max(insets.bottom + Self.audioBarReserve, 64) : insets.bottom
        let style = ScripturePageStyle(textSize: reading.textSize, lineSpacing: reading.lineSpacing,
                                       typeface: reading.typeface, layout: reading.layout,
                                       dynamicTypeScale: dynamicTypeScale, isDark: isDark,
                                       hyphenates: model.edition != .vulgate)
        let geometry = ScripturePageGeometry.make(size: size, safeTop: insets.top, safeBottom: bottom,
                                                  safeLeft: insets.left, safeRight: insets.right, style: style)
        return ScripturePaginationKey(style: style, geometry: geometry)
    }

    /// The space that the audio mini player takes above the bottom safe area, with a small gap.
    private static var audioBarReserve: CGFloat { 40 }

    /// The device safe area (status bar, Dynamic Island, home indicator). It does not include the tab bar, so the
    /// pages keep their size when the tab bar hides.
    private static var windowSafeAreaInsets: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.safeAreaInsets ?? .zero
    }
}
