import SwiftUI
import JohnCore

struct CitationContextView: View {
    let reference: String
    let onOpenSearch: () -> Void
    let onOpenLectio: (PassageSelection) -> Void

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var target: CompanionReferenceTarget?
    @State private var chapter: BibleChapter?
    @State private var books: [BibleBookDescriptor] = []
    @State private var bookName = ""
    @State private var attribution = ""
    @State private var loading = true
    @State private var loadFailed = false
    @State private var loadGeneration = 0

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var verseFontSize: CGFloat {
        switch preferences.reading.textSize {
        case .small: 16
        case .medium: 18
        case .large: 21
        case .extraLarge: 24
        }
    }
    private var verseLineHeight: CGFloat {
        let multiplier: CGFloat = switch preferences.reading.lineSpacing {
        case .compact: 1.45
        case .comfortable: 1.67
        case .relaxed: 1.9
        }
        return (verseFontSize * multiplier).rounded()
    }
    private var verseFont: Font {
        preferences.reading.typeface == .serif
            ? .custom("Georgia", size: verseFontSize)
            : JohnTypography.sans(verseFontSize)
    }

    var body: some View {
        ContentPage(title: target.map { "\(bookName) \($0.chapter)" } ?? "Passage unavailable",
                    eyebrow: target == nil ? nil : "Scripture in context",
                    subtitle: target == nil ? nil : "Reading reference: \(reference)") {
            if loading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            } else if let target, let chapter {
                ContentMutedText(text: "WEB-CE · Complete chapter. References with lettered verse portions or multiple chapters are shown in context; use Next chapter to continue.")
                ContentMutedText(text: "Tap a verse to pray with it.")
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(chapter.verses.enumerated()), id: \.offset) { pair in
                        let verse = pair.element
                        Button {
                            let requestedGeneration = loadGeneration
                            Task {
                                guard let selection = await runtime.passage(
                                    translation: .webCE, bookCode: target.bookCode,
                                    chapter: target.chapter, startVerse: verse.label,
                                    endVerse: verse.label
                                ), requestedGeneration == loadGeneration else { return }
                                onOpenLectio(selection)
                            }
                        } label: {
                            (Text("\(verse.label)  ")
                                .font(JohnTypography.sans(14))
                                .foregroundColor(colors.tint)
                             + Text(verse.text).font(verseFont).foregroundColor(colors.text))
                                .lineSpacing(ContentTypography.additionalSpacing(
                                    fontName: preferences.reading.typeface == .serif ? "Georgia" : "SpaceGrotesk-Regular",
                                    size: verseFontSize, targetLineHeight: verseLineHeight
                                ))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Verse \(verse.label). Pray with this verse.")
                    }
                }
                .padding(.vertical, 8)
                HStack(spacing: 12) {
                    ContentButton(title: "Previous chapter", expandsToFill: false) {
                        load(bookCode: target.bookCode, chapterNumber: target.chapter - 1)
                    }
                    .disabled(target.chapter <= 1)
                    Spacer(minLength: 0)
                    ContentButton(title: "Next chapter", expandsToFill: false) {
                        load(bookCode: target.bookCode, chapterNumber: target.chapter + 1)
                    }
                    .disabled(target.chapter >= (books.first(where: { $0.code == target.bookCode })?.chapterCount ?? target.chapter))
                }
                ContentMutedText(text: attribution)
            } else {
                ContentMutedText(text: "This reference could not be opened. You can find the passage using Bible search.")
                ContentButton(title: "Search the Bible", action: onOpenSearch)
            }
        }
        .task(id: reference) { await loadReference() }
        .onDisappear { loadGeneration &+= 1 }
    }

    @MainActor private func loadReference() async {
        loadGeneration &+= 1
        target = nil
        chapter = nil
        loadFailed = false
        loading = true
        let generation = loadGeneration
        let books = await runtime.books(translation: .webCE)
        guard !Task.isCancelled, generation == loadGeneration else { return }
        self.books = books
        guard let value = CompanionReferenceTargetParser.parse(reference, webCEBooks: books),
              let descriptor = books.first(where: { $0.code == value.bookCode }) else {
            loadFailed = true
            loading = false
            return
        }
        guard let result = await runtime.chapter(translation: .webCE, bookCode: value.bookCode, number: value.chapter) else {
            guard generation == loadGeneration else { return }
            loadFailed = true
            loading = false
            return
        }
        guard generation == loadGeneration else { return }
        target = value
        bookName = descriptor.name
        chapter = result
        attribution = await runtime.translationAttribution(.webCE)
        guard !Task.isCancelled, generation == loadGeneration else { return }
        loading = false
    }

    @MainActor private func load(bookCode: String, chapterNumber: Int) {
        guard chapterNumber > 0, let current = target else { return }
        loadGeneration &+= 1
        let generation = loadGeneration
        target = nil
        chapter = nil
        loadFailed = false
        loading = true
        Task {
            guard let result = await runtime.chapter(translation: .webCE, bookCode: bookCode, number: chapterNumber) else {
                guard generation == loadGeneration else { return }
                loadFailed = true
                loading = false
                return
            }
            guard generation == loadGeneration else { return }
            chapter = result
            target = try? CompanionReferenceTarget(originalCitation: current.originalCitation,
                                                   bookCode: current.bookCode, chapter: chapterNumber)
            loading = false
        }
    }
}
