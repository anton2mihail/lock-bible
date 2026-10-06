import Foundation
import Observation
import JohnCore

@MainActor @Observable final class ReaderScreenModel {
    enum Screen: Equatable { case books, chapters, chapter }

    private(set) var screen: Screen = .books
    private(set) var books: [BibleBookDescriptor] = []
    private(set) var book: BibleBookDescriptor?
    private(set) var chapterNumber: Int?
    private(set) var chapter: BibleChapter?
    private(set) var layout: ChapterLayout?
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var edition: TranslationID = .webCE
    private(set) var selectedRange: ClosedRange<Int>?
    private(set) var contextRange: ClosedRange<Int>?
    private(set) var lastRead: (bookCode: String, chapter: Int)?
    private var handledRequestID: UUID?
    private var manifestLoadID: UUID?
    private var chapterLoadID: UUID?

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
                else if screen == .chapter { await openChapter(updated, number: chapterNumber, using: runtime) }
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
        handledRequestID = request.id
        manifestLoadID = request.id
        edition = request.translationID
        let loadedBooks = await runtime.books(translation: request.translationID)
        guard manifestLoadID == request.id, handledRequestID == request.id else { return }
        books = loadedBooks
        guard let requestedBook = books.first(where: { $0.code == request.bookCode }),
              (1...requestedBook.chapterCount).contains(request.chapter) else {
            message = "This passage is not available in this edition."
            screen = .books
            return
        }
        await openChapter(requestedBook, number: request.chapter, verse: request.verse,
                          endVerse: request.endVerse, using: runtime)
    }

    func openBook(_ book: BibleBookDescriptor) {
        invalidatePendingChapterLoad()
        manifestLoadID = nil
        self.book = book
        chapter = nil
        layout = nil
        chapterNumber = nil
        selectedRange = nil
        contextRange = nil
        message = nil
        screen = .chapters
    }

    func openChapter(_ book: BibleBookDescriptor, number: Int, verse: String? = nil,
                     endVerse: String? = nil, using runtime: JohnRuntime) async {
        guard (1...book.chapterCount).contains(number) else { return }
        let loadID = UUID()
        chapterLoadID = loadID
        isLoading = true
        message = nil
        self.book = book
        chapterNumber = number
        selectedRange = nil
        contextRange = nil
        screen = .chapter
        defer { if chapterLoadID == loadID { isLoading = false } }
        guard let loaded = await runtime.chapter(translation: edition, bookCode: book.code, number: number) else {
            guard chapterLoadID == loadID else { return }
            chapter = nil
            layout = nil
            message = "This chapter is not available."
            return
        }
        guard chapterLoadID == loadID else { return }
        do {
            chapter = loaded
            layout = try ChapterLayout.build(loaded)
            lastRead = (book.code, number)
            if let verse, let first = loaded.verses.firstIndex(where: { $0.label == verse }) {
                let requestedEnd = endVerse.flatMap { end in loaded.verses.firstIndex(where: { $0.label == end }) } ?? first
                contextRange = min(first, requestedEnd)...max(first, requestedEnd)
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

    func adjacentBook(_ offset: Int) -> BibleBookDescriptor? {
        guard let book, let index = books.firstIndex(where: { $0.code == book.code }) else { return nil }
        let nextIndex = index + offset
        guard books.indices.contains(nextIndex) else { return nil }
        return books[nextIndex]
    }

    func moveChapter(_ offset: Int, using runtime: JohnRuntime) async {
        guard let book, let chapterNumber else { return }
        let next = chapterNumber + offset
        if (1...book.chapterCount).contains(next) {
            await openChapter(book, number: next, using: runtime)
        } else if let adjacent = adjacentBook(offset) {
            await openChapter(adjacent, number: offset > 0 ? 1 : adjacent.chapterCount, using: runtime)
        }
    }

    func scrollLocationUpdated() {
        // L08 connects this temporary location to NativeStateStore.
    }
}
