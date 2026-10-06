import SwiftUI
import JohnCore

struct PrayerLibraryView: View {
    let onNavigate: (CompanionRoute) -> Void

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var prayers: [PrayerCatalogItem] = []
    @State private var query = ""
    @State private var loadMessage: String?
    @State private var loaded = false

    private let categories = ["Daily rhythm", "Traditional prayers", "In times of need"]
    private var favorites: Set<String> { Set(runtime.committedNativeState?.favoritePrayerIDs ?? []) }
    private var normalizedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    private var results: [PrayerCatalogItem] {
        guard !normalizedQuery.isEmpty else { return prayers }
        return prayers.filter {
            "\($0.title) \($0.subtitle) \($0.category)".lowercased().contains(normalizedQuery)
        }
    }

    var body: some View {
        ContentPage(title: "Prayer for every day", eyebrow: "Keep a little quiet",
                    subtitle: "Familiar words for ordinary moments, and the difficult ones too.") {
            TextField("Find a prayer…", text: $query)
                .font(JohnTypography.sans(16))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 40)
                .background(inputColor, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(inputBorder, lineWidth: 1))
                .accessibilityLabel("Search everyday prayers")
                .accessibilityIdentifier("prayer-search")

            if let loadMessage {
                ContentMutedText(text: loadMessage)
            } else if loaded {
                if query.isEmpty {
                    let kept = prayers.filter { favorites.contains($0.id) }
                    if !kept.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ContentSectionTitle(title: "Kept close")
                            ForEach(kept, id: \.id) { prayer in
                                ContentActionRow(title: prayer.title, subtitle: prayer.subtitle, icon: "heart") {
                                    onNavigate(.prayer(id: prayer.id))
                                }
                            }
                        }
                    }
                }

                ForEach(categories, id: \.self) { category in
                    let items = results.filter { $0.category == category }
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ContentSectionTitle(title: category)
                            ForEach(items, id: \.id) { prayer in
                                ContentActionRow(title: prayer.title, subtitle: prayer.subtitle) {
                                    onNavigate(.prayer(id: prayer.id))
                                }
                            }
                        }
                    }
                }
                if results.isEmpty {
                    ContentMutedText(text: "No prayers found. Try morning, Mary, or suffering.")
                }
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
            }
        }
        .task { await loadCatalog() }
    }

    private var inputColor: Color {
        preferences.colors(for: colorScheme).background
    }

    private var inputBorder: Color {
        preferences.colors(for: colorScheme).border
    }

    @MainActor private func loadCatalog() async {
        guard let repository = runtime.companionRepository else {
            loadMessage = "The prayer library is not available."
            loaded = true
            return
        }
        do {
            prayers = try await repository.devotionalCatalog().prayers
            loaded = true
        } catch {
            loadMessage = "The prayer library is not available."
            loaded = true
        }
    }
}

struct ContentMutedText: View {
    let text: String
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Text(text)
            .font(JohnTypography.sans(14))
            .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 14, targetLineHeight: 21))
            .foregroundStyle(preferences.colors(for: colorScheme).textDim)
            .fixedSize(horizontal: false, vertical: true)
    }
}
