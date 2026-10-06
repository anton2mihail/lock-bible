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

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var cleanQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Search Scripture")
                    .font(JohnTypography.sans(36, weight: .bold))
                    .foregroundStyle(colors.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            searchField
            scopePicker
            content
        }
        .background(colors.background.ignoresSafeArea())
        .task(id: cleanQuery + "|" + scope.rawValue + "|" + preferences.translation.rawValue) {
            await runSearchAfterDelay()
        }
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
            emptyMessage("Search by reference, keyword, or exact phrase.", title: "Find a passage", icon: "magnifyingglass")
        } else if let errorMessage {
            emptyMessage(errorMessage, title: "Search failed", icon: "exclamationmark.triangle")
        } else if let response, response.results.isEmpty {
            emptyMessage("No passages found. Try fewer words or check the reference.", title: "No results", icon: "text.magnifyingglass")
        } else if let response {
            resultList(response)
        } else {
            emptyMessage("Search by a word or reference.", title: "Find a passage", icon: "magnifyingglass")
        }
    }

    private func resultList(_ response: BibleSearchResponse) -> some View {
        List {
            if let corrected = response.correctedQuery {
                Text("Showing results for “\(corrected)”")
                    .font(JohnTypography.sans(14))
                    .foregroundStyle(colors.tint)
                    .listRowBackground(colors.background)
                    .accessibilityIdentifier("search-correction-notice")
            }
            Section {
                ForEach(Array(response.results.enumerated()), id: \.element.id) { offset, result in
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
                Text("\(response.results.count == 60 ? "60+" : String(response.results.count)) \(response.results.count == 1 ? "result" : "results")")
                    .font(JohnTypography.sans(12, weight: .medium))
                    .textCase(nil)
                    .foregroundStyle(colors.textDim)
                    .numericChange(response.results.count)
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
        let submittedTranslation = preferences.translation
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
