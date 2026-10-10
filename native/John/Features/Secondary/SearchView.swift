import SwiftUI
import JohnCore

struct SearchView: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var searchFieldFocused: Bool
    @State private var query = ""
    @State private var scope: BibleSearchScope = .all
    @State private var response: BibleSearchResponse?
    @State private var activeRequestID: String?
    @State private var errorMessage: String?
    @State private var isSearching = false
    @State private var searchTerms: [String] = []
    @State private var responseTranslation: TranslationID = .webCE
    // E11: scope tokens, suggested completions, and recent searches.
    @State private var bookToken: BibleBookDescriptor?
    @State private var editionOverride: TranslationID?
    @State private var books: [BibleBookDescriptor] = []
    @State private var recents: [String] = SearchRecents.load()

    private var effectiveTranslation: TranslationID { editionOverride ?? preferences.translation }
    private var suggestions: [BibleBookDescriptor] {
        SearchRecents.completions(for: cleanQuery, in: books, excluding: bookToken)
    }

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var cleanQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 0) {
            Text("Search Scripture")
                .font(.custom("SpaceGrotesk-Bold", size: 36, relativeTo: .largeTitle))
                .foregroundStyle(colors.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 24)
                .padding(.top, 16)
            searchField
            tokenRow
            scopePicker
            suggestionRow
            content
        }
        .background(colors.background.ignoresSafeArea())
        .task(id: cleanQuery + "|" + scope.rawValue + "|" + effectiveTranslation.rawValue + "|" + (bookToken?.code ?? "")) {
            await runSearchAfterDelay()
        }
        .task(id: effectiveTranslation) { books = await runtime.books(translation: effectiveTranslation) }
        .onAppear { searchFieldFocused = true }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            FeatherIcon(name: "search", color: colors.textDim)
            TextField("Search Scripture", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFieldFocused)
                .accessibilityIdentifier("search-query-input")
            if !query.isEmpty {
                Button {
                    query = ""
                    response = nil
                    errorMessage = nil
                } label: {
                    FeatherIcon(name: "x", color: colors.textDim)
                }
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("search-clear-button")
            }
            if isSearching {
                ProgressView().controlSize(.small).accessibilityLabel("Searching")
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 48)
        .background(colors.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.border, lineWidth: 1))
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    /// Scope tokens: the book scope and the edition scope. A tap on a token removes it.
    private var tokenRow: some View {
        AdaptiveChipStack {
            if let bookToken {
                tokenButton(title: bookToken.name, id: "search-book-token", label: "Book scope \(bookToken.name). Remove.") {
                    self.bookToken = nil
                }
            }
            ForEach(TranslationID.allCases, id: \.rawValue) { edition in
                let selected = effectiveTranslation == edition
                Button {
                    editionOverride = edition == preferences.translation ? nil : edition
                } label: {
                    Text(edition.shareLabel)
                        .font(JohnTypography.sans(13, weight: .medium))
                        .foregroundStyle(selected ? colors.card : colors.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(selected ? colors.tint : colors.card, in: Capsule())
                        .overlay(Capsule().stroke(selected ? colors.tint : colors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search-edition-\(edition.rawValue)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private func tokenButton(title: String, id: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(JohnTypography.sans(13, weight: .semibold))
                FeatherIcon(name: "x", color: colors.card)
            }
            .foregroundStyle(colors.card)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(colors.tint, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    /// Suggested completions: books whose name starts with the typed text. A tap makes the book a scope token.
    @ViewBuilder private var suggestionRow: some View {
        let items = suggestions
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.element.code) { offset, book in
                        Button {
                            bookToken = book
                            query = ""
                            response = nil
                        } label: {
                            Text("In \(book.name)")
                                .font(JohnTypography.sans(14, weight: .medium))
                                .foregroundStyle(colors.text)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(colors.card, in: Capsule())
                                .overlay(Capsule().stroke(colors.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("search-suggestion-\(offset + 1)")
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    @ViewBuilder private var recentsList: some View {
        if recents.isEmpty {
            emptyMessage("Search by reference, keyword, or exact phrase.", title: "Find a passage", icon: "magnifyingglass")
        } else {
            List {
                Section {
                    ForEach(Array(recents.enumerated()), id: \.element) { offset, text in
                        Button { query = text } label: {
                            Label(text, systemImage: "clock.arrow.circlepath")
                                .foregroundStyle(colors.text)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .accessibilityIdentifier("search-recent-\(offset + 1)")
                        .listRowBackground(colors.background)
                    }
                } header: {
                    HStack {
                        Text("Recent searches")
                        Spacer()
                        Button("Clear") { recents = SearchRecents.clear() }
                            .accessibilityIdentifier("search-recents-clear")
                    }
                    .font(JohnTypography.sans(12, weight: .medium))
                    .textCase(nil)
                    .foregroundStyle(colors.textDim)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("search-status")
        }
    }

    private var scopePicker: some View {
        AdaptiveChipStack {
            ForEach(SearchScopeChoice.allCases) { choice in
                Button {
                    scope = choice.scope
                } label: {
                    Text(choice.title)
                        .font(JohnTypography.sans(14, weight: .medium))
                        .foregroundStyle(scope == choice.scope ? colors.card : colors.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(scope == choice.scope ? colors.tint : colors.card, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(scope == choice.scope ? colors.tint : colors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search-scope-\(choice.scope.rawValue)")
                .accessibilityAddTraits(scope == choice.scope ? .isSelected : [])
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .sensoryFeedback(.selection, trigger: scope)
    }

    @ViewBuilder private var content: some View {
        if cleanQuery.count < 2 {
            recentsList
        } else if let errorMessage {
            emptyMessage(errorMessage, title: "Search failed", icon: "exclamationmark.triangle")
        } else if let response, scoped(response).isEmpty {
            emptyMessage("No passages found. Try fewer words or check the reference.", title: "No results", icon: "text.magnifyingglass")
        } else if let response {
            resultList(response)
        } else {
            emptyMessage("Search by a word or reference.", title: "Find a passage", icon: "magnifyingglass")
        }
    }

    /// The results that match the book scope token. The search itself has no book filter, so this filter runs on the list.
    private func scoped(_ response: BibleSearchResponse) -> [BibleSearchResult] {
        guard let bookToken else { return response.results }
        return response.results.filter { $0.bookCode == bookToken.code }
    }

    private func resultList(_ response: BibleSearchResponse) -> some View {
        let results = scoped(response)
        return List {
            if let corrected = response.correctedQuery {
                Text("Showing results for “\(corrected)”")
                    .font(JohnTypography.sans(14))
                    .foregroundStyle(colors.tint)
                    .listRowBackground(colors.background)
                    .accessibilityIdentifier("search-correction-notice")
            }
            Section {
                ForEach(Array(results.enumerated()), id: \.element.id) { offset, result in
                    Button { open(result, translation: responseTranslation) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(result.reference)
                                    .font(JohnTypography.sans(14, weight: .semibold))
                                    .foregroundStyle(colors.text)
                                Spacer(minLength: 8)
                            }
                            highlightedText(result.text)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("search-result-\(offset + 1)")
                    .accessibilityLabel("\(result.reference). \(result.text)")
                    .listRowBackground(colors.background)
                }
            } header: {
                Text("\(results.count == 60 ? "60+" : String(results.count)) \(results.count == 1 ? "result" : "results")")
                    .font(JohnTypography.sans(12, weight: .medium))
                    .textCase(nil)
                    .foregroundStyle(colors.textDim)
                    .numericChange(results.count)
                    .accessibilityIdentifier("search-result-count")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// The prompt, no-result, and error states. The description keeps the message text and the `search-status` identifier.
    private func emptyMessage(_ text: String, title: String, icon: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(text)
                .accessibilityIdentifier("search-status")
        }
    }

    private func runSearchAfterDelay() async {
        let requestID = UUID().uuidString
        let submittedQuery = cleanQuery
        let submittedScope = scope
        let submittedTranslation = effectiveTranslation
        activeRequestID = requestID
        errorMessage = nil
        guard submittedQuery.count >= 2 else {
            isSearching = false
            response = nil
            searchTerms = []
            return
        }
        isSearching = true
        do {
            try await Task.sleep(for: .milliseconds(220))
            try Task.checkCancellation()
            let request = BibleSearchRequest(requestID: requestID, query: submittedQuery,
                                             translationID: submittedTranslation, scope: submittedScope, limit: 60)
            let result = try await runtime.search(request)
            guard !Task.isCancelled, activeRequestID == result.requestID else { return }
            response = result
            responseTranslation = submittedTranslation
            searchTerms = ((result.correctedQuery ?? submittedQuery).replacingOccurrences(of: "\"", with: ""))
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            isSearching = false
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, activeRequestID == requestID else { return }
            errorMessage = "Search could not be completed. Try a different phrase."
            isSearching = false
        }
    }

    private func open(_ result: BibleSearchResult, translation: TranslationID) {
        searchFieldFocused = false
        recents = SearchRecents.record(cleanQuery)
        Task {
            guard let passage = await runtime.passage(translation: translation,
                                                       bookCode: result.bookCode, chapter: result.chapter,
                                                       startVerse: result.verse, endVerse: result.verse) else { return }
            router.openReader(passage: passage)
        }
    }

    private func highlightedText(_ value: String) -> some View {
        var attributed = AttributedString(value)
        attributed.font = .custom("Georgia", size: 17)
        attributed.foregroundColor = colors.text
        guard !searchTerms.isEmpty else { return Text(attributed).lineSpacing(6) }
        let alternatives = searchTerms.map(NSRegularExpression.escapedPattern(for:))
        guard let expression = try? NSRegularExpression(pattern: "(\(alternatives.joined(separator: "|")))", options: [.caseInsensitive]) else {
            return Text(attributed).lineSpacing(6)
        }
        for match in expression.matches(in: value, range: NSRange(value.startIndex..., in: value)) {
            guard let range = Range(match.range, in: attributed) else { continue }
            attributed[range].font = .custom("Georgia", size: 17).weight(.semibold)
            attributed[range].backgroundColor = colorScheme == .dark
                ? Color(red: 0.957, green: 0.847, blue: 0.604).opacity(0.24)
                : Color(hex: 0xF4D89A)
        }
        return Text(attributed).lineSpacing(6)
    }
}

private enum SearchScopeChoice: String, CaseIterable, Identifiable {
    case all, ot, nt
    var id: String { rawValue }
    var scope: BibleSearchScope { BibleSearchScope(rawValue: rawValue)! }
    var title: String {
        switch self { case .all: "All"; case .ot: "Old Testament"; case .nt: "New Testament" }
    }
}

/// Recent searches (E11). The list lives in UserDefaults. The helpers are pure, apart from the load and save calls.
enum SearchRecents {
    static let key = "search.recents.v1"
    static let limit = 8

    static func load() -> [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }

    static func record(_ query: String) -> [String] {
        let updated = merged(load(), adding: query)
        UserDefaults.standard.set(updated, forKey: key)
        return updated
    }

    static func clear() -> [String] {
        UserDefaults.standard.removeObject(forKey: key)
        return []
    }

    static func merged(_ existing: [String], adding query: String) -> [String] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { return existing }
        let others = existing.filter { $0.caseInsensitiveCompare(clean) != .orderedSame }
        return Array(([clean] + others).prefix(limit))
    }

    /// Books whose name starts with the typed text. It returns nothing for a text that is a longer phrase.
    static func completions(for query: String, in books: [BibleBookDescriptor],
                            excluding token: BibleBookDescriptor?) -> [BibleBookDescriptor] {
        let typed = query.lowercased()
        guard !typed.isEmpty, typed.count <= 12 else { return [] }
        return Array(books.filter { book in
            book.code != token?.code && (book.name.lowercased().hasPrefix(typed) || book.longName.lowercased().hasPrefix(typed))
                && book.name.lowercased() != typed
        }.prefix(5))
    }
}
