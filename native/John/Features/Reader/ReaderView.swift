import SwiftUI
import JohnCore

struct ReaderView: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    private var model: ReaderScreenModel { runtime.readerScreen }
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        Group {
            switch model.screen {
            case .books:
                bookList
            case .chapters:
                chapterGrid
            case .chapter:
                chapterReader
            }
        }
        .background(colors.background)
        .task(id: preferences.translation) {
            await model.loadBooks(translation: preferences.translation, using: runtime)
            if let request = runtime.reader.openRequest { await model.receive(request, using: runtime) }
        }
        .onChange(of: runtime.reader.openRequest?.id) { _, _ in
            guard let request = runtime.reader.openRequest else { return }
            Task { await model.receive(request, using: runtime) }
        }
        .sheet(isPresented: Binding(get: { router.sheet == .readerAppearance }, set: { if !$0 { router.sheet = nil } })) {
            NavigationStack {
                SettingsControls()
                    .padding()
                    .navigationTitle("Reader appearance")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { router.sheet = nil }
                                .accessibilityIdentifier("reader-appearance-close")
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }

    private var bookList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Read the Bible")
                        .font(JohnTypography.title(36))
                        .tracking(-0.8)
                        .foregroundStyle(colors.text)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("reader-book-list-title")
                    Spacer()
                    Button("Search") { router.push(.search) }
                        .font(JohnTypography.sans(14, weight: .medium))
                        .foregroundStyle(colors.tint)
                        .accessibilityIdentifier("reader-search-button")
                }

                if let lastRead = model.lastRead,
                   let descriptor = model.books.first(where: { $0.code == lastRead.bookCode }) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Continue reading")
                            .font(JohnTypography.sans(13, weight: .medium))
                            .foregroundStyle(colors.textDim)
                        Button {
                            Task { await model.openChapter(descriptor, number: lastRead.chapter, using: runtime) }
                        } label: {
                            HStack {
                                Text("\(descriptor.name) \(lastRead.chapter)")
                                    .font(JohnTypography.serif(20))
                                Spacer()
                                FeatherIcon(name: "chevron-right", color: colors.tint)
                            }
                            .foregroundStyle(colors.text)
                            .padding(16)
                            .background(colors.card, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Continue reading \(descriptor.name) chapter \(lastRead.chapter)")
                        .accessibilityIdentifier("reader-continue-reading")
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("The Church Fathers")
                        .font(JohnTypography.sans(13, weight: .medium))
                        .foregroundStyle(colors.textDim)
                Button { router.push(.works) } label: {
                        HStack {
                            Text("Fathers and Doctors")
                                .font(JohnTypography.serif(19))
                            Spacer()
                            FeatherIcon(name: "chevron-right", color: colors.tint)
                        }
                        .foregroundStyle(colors.text)
                        .padding(16)
                        .background(colors.card, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("reader-works-link")
                }

                ForEach(BookGroupOrder.allCases, id: \.self) { group in
                    let groupBooks = model.books.filter { $0.group == group.rawValue }
                    if !groupBooks.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(group.title)
                                .font(JohnTypography.sans(13, weight: .medium))
                                .foregroundStyle(colors.textDim)
                                .padding(.bottom, 6)
                            ForEach(groupBooks, id: \.code) { book in
                                Button { model.openBook(book) } label: {
                                    HStack {
                                        Text(book.name)
                                            .font(JohnTypography.sans(16))
                                            .foregroundStyle(colors.text)
                                        Spacer()
                                        FeatherIcon(name: "chevron-right", color: colors.textDim)
                                    }
                                    .frame(minHeight: 52)
                                    .overlay(alignment: .bottom) { Rectangle().fill(colors.separator).frame(height: 1) }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(book.name), \(book.chapterCount) chapters")
                                .accessibilityIdentifier("reader-book-\(book.code)")
                            }
                        }
                    }
                }
                if let message = model.message { MutedText(text: message) }
            }
            .frame(maxWidth: 740, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("reader-book-list")
    }

    private var chapterGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ReaderHeader(title: model.book?.name ?? "Read", backLabel: "Back to books",
                             onBack: model.goBack, onTitlePress: openGoTo, onSearch: openSearch,
                             onTextSettings: nil, colors: colors)
                if let book = model.book {
                    Text("Choose a chapter")
                        .font(JohnTypography.sans(14))
                        .foregroundStyle(colors.textDim)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(52), spacing: 10), count: 5), spacing: 10) {
                        ForEach(1...book.chapterCount, id: \.self) { number in
                            Button {
                                Task { await model.openChapter(book, number: number, using: runtime) }
                            } label: {
                                Text(String(number))
                                    .font(JohnTypography.sans(16, weight: .medium))
                                    .foregroundStyle(colors.text)
                                    .frame(width: 52, height: 52)
                                    .background(colors.card, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(book.name) chapter \(number)")
                            .accessibilityIdentifier("reader-chapter-\(number)")
                        }
                    }
                }
            }
            .frame(maxWidth: 740, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
    }

    private var chapterReader: some View {
        VStack(spacing: 0) {
            if let book = model.book, let number = model.chapterNumber {
                ReaderHeader(title: "\(book.name) \(number)", backLabel: "Back to \(book.name) chapters",
                             onBack: model.goBack, onTitlePress: openGoTo, onSearch: openSearch,
                             onTextSettings: {
                                 #if DEBUG
                                 NSLog("John Aa action received")
                                 #endif
                                 router.sheet = .readerAppearance
                             }, requestID: runtime.reader.openRequest?.id.uuidString, colors: colors)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                if let chapter = model.chapter, let layout = model.layout {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            ScriptureTextView(
                                chapter: chapter,
                                layout: layout,
                                textSize: preferences.reading.textSize,
                                lineSpacing: preferences.reading.lineSpacing,
                                typeface: preferences.reading.typeface,
                                selectedRange: model.selectedRange,
                                contextRange: model.contextRange,
                                highlights: [:],
                                isDark: colorScheme == .dark,
                                onTapVerse: model.selectVerse
                            )
                            if let range = model.selectedRange, chapter.verses.indices.contains(range.lowerBound), chapter.verses.indices.contains(range.upperBound) {
                                Text("Selected: verses \(chapter.verses[range.lowerBound].label)–\(chapter.verses[range.upperBound].label)")
                                    .font(JohnTypography.sans(13, weight: .medium))
                                    .foregroundStyle(colors.tint)
                                    .accessibilityIdentifier("reader-selection-summary")
                            }
                            HStack(spacing: 12) {
                                if model.chapterNumber ?? 1 > 1 || model.adjacentBook(-1) != nil {
                                    Button {
                                        Task { await model.moveChapter(-1, using: runtime) }
                                    } label: {
                                        Label("Previous", systemImage: "chevron.left")
                                            .frame(maxWidth: .infinity, minHeight: 48)
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("reader-previous-chapter")
                                }
                                if model.chapterNumber ?? 1 < (model.book?.chapterCount ?? 1) || model.adjacentBook(1) != nil {
                                    Button {
                                        Task { await model.moveChapter(1, using: runtime) }
                                    } label: {
                                        Label("Next", systemImage: "chevron.right")
                                            .frame(maxWidth: .infinity, minHeight: 48)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityIdentifier("reader-next-chapter")
                                }
                            }
                        }
                        .frame(maxWidth: 740, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 44)
                        .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("reader-chapter-scroll")
                } else if model.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView("Chapter unavailable", systemImage: "book", description: Text(model.message ?? "Try another chapter."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func openGoTo() {
        router.push(.goTo(bookCode: model.book?.code, chapter: model.chapterNumber))
    }

    private func openSearch() { router.push(.search) }
}

enum BookGroupOrder: String, CaseIterable {
    case ot, deutero, nt
    var title: String {
        switch self {
        case .ot: "Old Testament"
        case .deutero: "Deuterocanon"
        case .nt: "New Testament"
        }
    }
}

private struct ReaderHeader: View {
    let title: String
    let backLabel: String
    let onBack: () -> Void
    let onTitlePress: () -> Void
    let onSearch: () -> Void
    let onTextSettings: (() -> Void)?
    var requestID: String? = nil
    let colors: JohnColors

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button(action: onBack) {
                    Label(backLabel, systemImage: "chevron.left")
                        .font(JohnTypography.sans(14, weight: .medium))
                        .foregroundStyle(colors.tint)
                }
                .accessibilityIdentifier("reader-back")
                Spacer()
                if let onTextSettings {
                    Button(action: onTextSettings) {
                        Text("Aa")
                            .font(JohnTypography.sans(18, weight: .semibold))
                            .foregroundStyle(colors.tint)
                    }
                    .accessibilityLabel("Text settings")
                    .accessibilityIdentifier("reader-appearance-button")
                }
                Button(action: onSearch) {
                    FeatherIcon(name: "search", color: colors.tint)
                        .frame(width: 36, height: 44)
                }
                .accessibilityLabel("Search Scripture")
                .accessibilityIdentifier("reader-search-button")
            }
            Button(action: onTitlePress) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(JohnTypography.title(32))
                        .tracking(-0.7)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    FeatherIcon(name: "chevron-down", color: colors.textDim)
                }
                .foregroundStyle(colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("reader-title")
            #if DEBUG
            .accessibilityValue(requestID ?? "")
            #endif
        }
    }
}
