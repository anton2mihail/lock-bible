import Foundation
import Observation
import JohnCore

@MainActor @Observable final class ReaderScreenModel {
    enum Screen: Equatable { case books, chapters, chapter }

    private(set) var screen: Screen = .books
    private(set) var books: [BibleBookDescriptor] = []
    private(set) var book: BibleBookDescriptor?
    private(set) var chapterNumber: Int?
    private(set) var currentChapterNumber: Int?
    private(set) var chapter: BibleChapter?
    private(set) var layout: ChapterLayout?
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var edition: TranslationID = .webCE
    private(set) var selectedRange: ClosedRange<Int>?
    private(set) var contextRange: ClosedRange<Int>?
    private(set) var lastRead: (bookCode: String, chapter: Int)?
    private(set) var pendingRestoreScrollY: Double?
    private(set) var pendingRestoreAnchor: ReaderAnchorRestoreRequest?
    private(set) var highlightColors: [Int: HighlightColor] = [:]
    private(set) var editionAttribution = ""
    private(set) var pendingContextIndex: Int?
    private(set) var activeChapterRequestID: UUID?
    /// Set when a chapter open has no restore target. The view drops the previous chapter offset.
    private(set) var chapterScrollResetID: UUID?
    private var handledRequestID: UUID?
    private var manifestLoadID: UUID?
    private var chapterLoadID: UUID?

    var selectedPassage: PassageSelection? {
        guard let range = selectedRange, let chapter, let book,
              chapter.verses.indices.contains(range.lowerBound),
              chapter.verses.indices.contains(range.upperBound),
              let start = VerseLabel(rawValue: chapter.verses[range.lowerBound].label),
              let end = VerseLabel(rawValue: chapter.verses[range.upperBound].label),
              let code = BookCode(rawValue: book.code),
              let id = try? PassageID(translationID: edition, bookCode: code, chapter: chapter.number,
                                      startVerse: start, endVerse: end) else { return nil }
        let selectedVerses = Array(chapter.verses[range.lowerBound...range.upperBound])
        let verses = selectedVerses.enumerated().compactMap { offset, verse -> PassageVerse? in
            guard let label = VerseLabel(rawValue: verse.label) else { return nil }
            return PassageVerse(verse: label, index: range.lowerBound + offset, text: verse.text)
        }
        guard verses.count == selectedVerses.count else { return nil }
        return try? PassageSelection(id: id, bookName: book.name, bookOrder: book.order,
                                     startIndex: range.lowerBound, endIndex: range.upperBound,
                                     scriptureText: selectedVerses.map { "\($0.label) \($0.text)" }.joined(separator: " "),
                                     verses: verses)
    }

    var selectedHighlightColor: HighlightColor? {
        guard let range = selectedRange, range.allSatisfy({ highlightColors[$0] != nil }),
              let first = highlightColors[range.lowerBound],
              range.allSatisfy({ highlightColors[$0] == first }) else { return nil }
        return first
    }

    var selectedHasHighlight: Bool {
        guard let range = selectedRange else { return false }
        return range.contains(where: { highlightColors[$0] != nil })
    }

    func applyVisibleHighlight(_ color: HighlightColor?, to passage: PassageSelection) {
        for verse in passage.verses {
            if let color { highlightColors[verse.index] = color }
            else { highlightColors.removeValue(forKey: verse.index) }
        }
    }

    /// Reloads the visible highlights after an undo or redo changed saved data.
    func reloadHighlights(using runtime: JohnRuntime) async {
        guard let chapter, let book else { return }
        guard let number = chapterNumber else { return }
        let loaded = await runtime.chapterHighlights(translation: edition, bookCode: book.code, chapter: number)
        guard self.chapter?.verses.count == chapter.verses.count, self.book?.code == book.code, chapterNumber == number else { return }
        highlightColors = loaded.reduce(into: [:]) { result, item in
            if let index = chapter.verses.firstIndex(where: { $0.label == item.key }) { result[index] = item.value }
        }
    }

    func loadBooks(translation: TranslationID, using runtime: JohnRuntime) async {
        invalidatePendingChapterLoad()
        let requestID = UUID()
        manifestLoadID = requestID
        edition = translation
        let loadedBooks = await runtime.books(translation: translation)
        guard manifestLoadID == requestID else { return }
        books = loadedBooks
        if let book, let updated = books.first(where: { $0.code == book.code }) {
            self.book = updated
            if let chapterNumber {
                if chapterNumber > updated.chapterCount { goBackToChapters() }
                else if screen == .chapter {
                    let location = runtime.preferences.readerLocation
                    let matches = location?.bookCode.rawValue == updated.code && location?.chapter == chapterNumber
                    // Showing the Read tab again reloads the open chapter. Keep the verse selection across that
                    // reload. `openChapter` clears it, so restore it when the same chapter is open afterwards.
                    let keptSelection = selectedRange
                    await openChapter(updated, number: chapterNumber,
                                      scrollY: matches ? location?.scrollY ?? 0 : 0,
                                      anchor: matches ? location?.anchor : nil,
                                      using: runtime)
                    if let keptSelection, selectedRange == nil, screen == .chapter,
                       self.book?.code == updated.code, self.chapterNumber == chapterNumber,
                       let loaded = chapter, keptSelection.upperBound < loaded.verses.count {
                        selectedRange = keptSelection
                    }
                }
            }
        } else if book != nil {
            self.book = nil
            chapter = nil
            layout = nil
            chapterNumber = nil
            screen = .books
        }
    }

    func receive(_ request: ReaderChapterRequest, using runtime: JohnRuntime) async {
        guard handledRequestID != request.id else { return }
        invalidatePendingChapterLoad()
        manifestLoadID = request.id
        edition = request.translationID
        let loadedBooks = await runtime.books(translation: request.translationID)
        // Mark the request handled only after its manifest load wins. When the Read tab appears, ReaderView's
        // `.task` runs `loadBooks`, which can take `manifestLoadID` from a request that `onChange` started.
        // That request must stay unhandled, so the `receive` call after `loadBooks` in the same `.task` applies it.
        guard manifestLoadID == request.id, handledRequestID != request.id else { return }
        handledRequestID = request.id
        books = loadedBooks
        guard let requestedBook = books.first(where: { $0.code == request.bookCode }) else {
            message = "This passage is not available in this edition."
            screen = .books
            return
        }
        // A known book with a chapter out of range shows that book's chapter list, as the old Reader does.
        guard (1...requestedBook.chapterCount).contains(request.chapter) else {
            openBook(requestedBook)
            return
        }
        await openChapter(requestedBook, number: request.chapter, verse: request.verse,
                          endVerse: request.endVerse, using: runtime)
    }

    func openBook(_ book: BibleBookDescriptor) {
        let sameBook = self.book?.code == book.code
        invalidatePendingChapterLoad()
        manifestLoadID = nil
        self.book = book
        chapter = nil
        layout = nil
        chapterNumber = nil
        if !sameBook { currentChapterNumber = nil }
        selectedRange = nil
        contextRange = nil
        message = nil
        screen = .chapters
    }

    func openChapter(_ book: BibleBookDescriptor, number: Int, verse: String? = nil,
                     endVerse: String? = nil, scrollY: Double = 0, anchor: ReaderAnchor? = nil,
                     using runtime: JohnRuntime) async {
        guard (1...book.chapterCount).contains(number) else { return }
        let requestedEdition = edition
        let loadID = UUID()
        chapterLoadID = loadID
        activeChapterRequestID = loadID
        isLoading = true
        message = nil
        highlightColors = [:]
        editionAttribution = ""
        pendingContextIndex = nil
        self.book = book
        chapterNumber = number
        currentChapterNumber = number
        chapter = nil
        layout = nil
        pendingRestoreScrollY = scrollY > 0 ? scrollY : nil
        selectedRange = nil
        contextRange = nil
        screen = .chapter
        lastRead = (book.code, number)
        pendingRestoreAnchor = anchor.map { ReaderAnchorRestoreRequest(id: UUID(), anchor: $0, chapterRequestID: loadID) }
        // The Reader scroll position outlives the chapter ScrollView. Clear it before the next
        // chapter view is created, or the previous chapter's offset opens the new chapter.
        if pendingRestoreScrollY == nil, pendingRestoreAnchor == nil {
            chapterScrollResetID = loadID
        }
        await runtime.saveReaderLocation(bookCode: book.code, chapter: number, scrollY: scrollY, anchor: anchor)
        guard chapterLoadID == loadID else { return }
        defer { if chapterLoadID == loadID { isLoading = false } }
        guard let loaded = await runtime.chapter(translation: requestedEdition, bookCode: book.code, number: number) else {
            guard chapterLoadID == loadID else { return }
            chapter = nil
            layout = nil
            message = "This chapter is not available."
            return
        }
        guard chapterLoadID == loadID else { return }
        do {
            let loadedLayout = try ChapterLayout.build(loaded)
            let loadedHighlights = await runtime.chapterHighlights(translation: requestedEdition, bookCode: book.code, chapter: number)
            guard chapterLoadID == loadID, self.book?.code == book.code,
                  chapterNumber == number, self.edition == requestedEdition else { return }
            let loadedAttribution = await runtime.translationAttribution(requestedEdition)
            guard chapterLoadID == loadID, self.book?.code == book.code,
                  chapterNumber == number, self.edition == requestedEdition else { return }
            chapter = loaded
            layout = loadedLayout
            highlightColors = loadedHighlights.reduce(into: [:]) { result, item in
                if let index = loaded.verses.firstIndex(where: { $0.label == item.key }) {
                    result[index] = item.value
                }
            }
            editionAttribution = loadedAttribution
            lastRead = (book.code, number)
            if let verse, let first = loaded.verses.firstIndex(where: { $0.label == verse }) {
                let requestedEnd = endVerse.flatMap { end in loaded.verses.firstIndex(where: { $0.label == end }) } ?? first
                contextRange = min(first, requestedEnd)...max(first, requestedEnd)
                pendingContextIndex = first
            }
        } catch {
            chapter = nil
            layout = nil
            message = "This chapter has an invalid layout."
        }
    }

    func goBack() {
        invalidatePendingChapterLoad()
        manifestLoadID = nil
        switch screen {
        case .books: break
        case .chapters: screen = .books
        case .chapter: goBackToChapters()
        }
        selectedRange = nil
        contextRange = nil
    }

    func goBackToChapters() {
        invalidatePendingChapterLoad()
        manifestLoadID = nil
        chapter = nil
        layout = nil
        chapterNumber = nil
        selectedRange = nil
        contextRange = nil
        screen = book == nil ? .books : .chapters
    }

    private func invalidatePendingChapterLoad() {
        chapterLoadID = nil
        activeChapterRequestID = nil
        isLoading = false
    }

    func selectVerse(_ index: Int) {
        guard chapter?.verses.indices.contains(index) == true else { return }
        if let current = selectedRange, current.lowerBound == index && current.upperBound == index {
            selectedRange = nil
        } else if let current = selectedRange {
            selectedRange = min(current.lowerBound, index)...max(current.lowerBound, index)
        } else {
            selectedRange = index...index
        }
        contextRange = nil
    }

    func clearSelection() {
        selectedRange = nil
        contextRange = nil
    }

    func adjacentBook(_ offset: Int) -> BibleBookDescriptor? {
        guard let book, let index = books.firstIndex(where: { $0.code == book.code }) else { return nil }
        let nextIndex = index + offset
        guard books.indices.contains(nextIndex) else { return nil }
        return books[nextIndex]
    }

    func moveChapter(_ offset: Int, using runtime: JohnRuntime) async {
        guard let book, let number = currentChapterNumber else { return }
        let next = number + offset
        if (1...book.chapterCount).contains(next) {
            await openChapter(book, number: next, using: runtime)
        } else if let adjacent = adjacentBook(offset) {
            await openChapter(adjacent, number: offset > 0 ? 1 : adjacent.chapterCount, using: runtime)
        }
    }

    func saveScrollLocation(_ offset: Double, bookCode: String, chapter: Int,
                            requestID: UUID, anchor: ReaderAnchor?, using runtime: JohnRuntime) async {
        guard activeChapterRequestID == requestID,
              book?.code == bookCode, chapterNumber == chapter else { return }
        await runtime.saveReaderLocation(bookCode: bookCode, chapter: chapter,
                                         scrollY: max(0, offset), anchor: anchor)
    }

    func restoreLocation(_ location: ReaderLocation?) {
        guard screen == .books, handledRequestID == nil,
              let location,
              let book = books.first(where: { $0.code == location.bookCode.rawValue }),
              (1...book.chapterCount).contains(location.chapter) else { return }
        lastRead = (book.code, location.chapter)
    }

    func prepareVisibleLocationRestore(_ location: ReaderLocation?) {
        guard screen == .chapter,
              let location,
              location.bookCode.rawValue == book?.code,
              location.chapter == chapterNumber,
              let requestID = activeChapterRequestID else { return }
        pendingRestoreScrollY = location.scrollY > 0 ? location.scrollY : nil
        pendingRestoreAnchor = location.anchor.map {
            ReaderAnchorRestoreRequest(id: UUID(), anchor: $0, chapterRequestID: requestID)
        }
    }

    func clearPendingRestore() { pendingRestoreScrollY = nil }

    func clearPendingRestoreAnchor(_ requestID: UUID) {
        guard pendingRestoreAnchor?.id == requestID else { return }
        pendingRestoreAnchor = nil
        pendingRestoreScrollY = nil
    }

    func adjacentChapter(_ offset: Int) -> (book: BibleBookDescriptor, chapter: Int)? {
        guard let book, let currentChapterNumber else { return nil }
        return adjacentChapter(from: book.code, chapter: currentChapterNumber, offset: offset)
    }

    /// The chapter before or after any chapter, across book boundaries. The paged Reader uses it for its neighbors.
    func adjacentChapter(from bookCode: String, chapter number: Int, offset: Int) -> (book: BibleBookDescriptor, chapter: Int)? {
        guard let index = books.firstIndex(where: { $0.code == bookCode }) else { return nil }
        let book = books[index]
        let value = number + offset
        if (1...book.chapterCount).contains(value) { return (book, value) }
        let nextIndex = index + (offset > 0 ? 1 : -1)
        guard books.indices.contains(nextIndex) else { return nil }
        let adjacent = books[nextIndex]
        return (adjacent, offset > 0 ? 1 : adjacent.chapterCount)
    }

    /// Makes a chapter that the paged Reader already loaded and paginated the open chapter, after a page turn across
    /// a chapter boundary. It does the same as `openChapter` without a load, so the turn shows no loading state.
    /// The caller saves the Reader location for the page that shows.
    func adoptPagedChapter(_ book: BibleBookDescriptor, number: Int, chapter loaded: BibleChapter,
                           layout loadedLayout: ChapterLayout, highlights: [Int: HighlightColor]) {
        let loadID = UUID()
        chapterLoadID = loadID
        activeChapterRequestID = loadID
        manifestLoadID = nil
        isLoading = false
        message = nil
        self.book = book
        chapterNumber = number
        currentChapterNumber = number
        chapter = loaded
        layout = loadedLayout
        highlightColors = highlights
        pendingContextIndex = nil
        pendingRestoreScrollY = nil
        pendingRestoreAnchor = nil
        selectedRange = nil
        contextRange = nil
        screen = .chapter
        lastRead = (book.code, number)
    }
}
