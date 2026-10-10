import CoreSpotlight
import Foundation
import UniformTypeIdentifiers
import JohnCore

/// Spotlight index for books, chapters, and saved bookmarks and notes (slice B2a, item E10).
/// The identifier of an item says what it opens. `route(forIdentifier:)` turns it into an `nrsv://` URL
/// that the existing router path handles.
enum SpotlightIndexer {
    static let chapterDomain = "com.nrsv.spotlight.chapter"
    static let savedDomain = "com.nrsv.spotlight.saved"
    private static let chapterVersion = "v1"

    // MARK: Identifiers and routes (pure, unit-testable)

    static func chapterIdentifier(translation: String, bookCode: String, chapter: Int) -> String {
        "nrsv.chapter.\(translation).\(bookCode).\(chapter)"
    }

    static func savedIdentifier(_ id: String) -> String { "nrsv.saved.\(id)" }

    /// A chapter identifier opens the Reader. A saved identifier opens the Saved tab. Other values return nil.
    static func route(forIdentifier identifier: String) -> URL? {
        let parts = identifier.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        if parts.count >= 5, parts[0] == "nrsv", parts[1] == "chapter", let chapter = Int(parts[parts.count - 1]) {
            // The book code is the second-to-last part. The edition ID has no dot.
            var components = URLComponents()
            components.scheme = "nrsv"
            components.host = "read"
            components.queryItems = [
                URLQueryItem(name: "book", value: parts[parts.count - 2]),
                URLQueryItem(name: "chapter", value: String(chapter)),
                URLQueryItem(name: "translation", value: parts[2]),
            ]
            return components.url
        }
        if parts.count >= 3, parts[0] == "nrsv", parts[1] == "saved" { return URL(string: "nrsv://saved") }
        return nil
    }

    // MARK: Index updates

    /// Indexes one item for each book and one for each chapter of the edition. Runs once for each edition and version.
    static func indexBible(translation: TranslationID, books: [BibleBookDescriptor]) async {
        let key = "spotlight.bible.\(translation.rawValue).\(chapterVersion)"
        guard !books.isEmpty, !UserDefaults.standard.bool(forKey: key) else { return }
        var items: [CSSearchableItem] = []
        for book in books {
            items.append(item(id: chapterIdentifier(translation: translation.rawValue, bookCode: book.code, chapter: 1),
                              title: book.longName, text: "\(book.name) · \(book.chapterCount) chapters",
                              domain: chapterDomain, keywords: [book.name, book.longName]))
            guard book.chapterCount > 1 else { continue }
            for chapter in 2...book.chapterCount {
                items.append(item(id: chapterIdentifier(translation: translation.rawValue, bookCode: book.code, chapter: chapter),
                                  title: "\(book.name) \(chapter)", text: book.longName,
                                  domain: chapterDomain, keywords: [book.name]))
            }
        }
        do {
            try await CSSearchableIndex.default().indexSearchableItems(items)
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            #if DEBUG
            NSLog("John Spotlight bible index failed: %@", String(describing: error))
            #endif
        }
    }

    /// Replaces all saved items in the index. Note text is never indexed: only the reference and a fixed title.
    /// Returns false if the delete or the index call failed. Pass nil when the saved list could not load: the domain is cleared.
    @discardableResult
    static func replaceSaved(_ saved: [SavedItem]?) async -> Bool {
        let index = CSSearchableIndex.default()
        let items = (saved ?? []).filter { $0.kind != .highlight }.map { entry in
            item(id: savedIdentifier(entry.id),
                 title: entry.kind == .note ? "Note on \(entry.reference)" : entry.reference,
                 text: entry.reference,
                 domain: savedDomain,
                 keywords: [entry.bookName, entry.kind.rawValue])
        }
        do {
            try await index.deleteSearchableItems(withDomainIdentifiers: [savedDomain])
            if !items.isEmpty { try await index.indexSearchableItems(items) }
            return true
        } catch {
            #if DEBUG
            NSLog("John Spotlight saved index failed: %@", String(describing: error))
            #endif
            return false
        }
    }

    private static func item(id: String, title: String, text: String, domain: String, keywords: [String]) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = title
        attributes.contentDescription = text
        attributes.keywords = keywords
        return CSSearchableItem(uniqueIdentifier: id, domainIdentifier: domain, attributeSet: attributes)
    }
}
