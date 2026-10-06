import SwiftUI
import UIKit
import JohnCore

struct PrayerDetailView: View {
    let id: String
    let onNavigate: (CompanionRoute) -> Void

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var prayer: PrayerCatalogItem?
    @State private var loaded = false
    @State private var loadFailed = false
    @State private var isSavingFavorite = false
    @State private var feedback = ""

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var isFavorite: Bool { runtime.committedNativeState?.favoritePrayerIDs.contains(id) == true }

    var body: some View {
        Group {
            if let prayer {
                prayerContent(prayer)
            } else if loadFailed {
                ContentPage(title: "Prayer is not available", eyebrow: "Prayer", subtitle: nil) {
                    ContentMutedText(text: "The prayer could not be loaded. Please try again later.")
                }
            } else if loaded {
                notFound
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(colors.background)
            }
        }
        .task(id: id) {
            prayer = nil
            loaded = false
            loadFailed = false
            await loadPrayer()
        }
    }

    private func prayerContent(_ prayer: PrayerCatalogItem) -> some View {
        ContentPage(title: prayer.title, eyebrow: prayer.category,
                    subtitle: prayer.subtitle) {
            prayerArtwork(for: prayer.id)
                .aspectRatio(1.7, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityHidden(true)

            Text(prayer.text)
                .font(JohnTypography.serif(24))
                .lineSpacing(ContentTypography.additionalSpacing(fontName: "Lora-Regular", size: 24, targetLineHeight: 36))
                .foregroundStyle(colors.text)
                .textSelection(.enabled)

            if prayer.id == "angelus" {
                ContentActionRow(title: "Hail Mary", subtitle: "Open the complete prayer") {
                    onNavigate(.prayer(id: "hail-mary"))
                }
            }

            Button(action: toggleFavorite) {
                Text(isFavorite ? "Remove from favorites" : "Keep in favorites")
                    .font(JohnTypography.sans(16, weight: .medium))
                    .foregroundStyle(colors.text)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .padding(.horizontal, 12)
            }
            .buttonStyle(ContentDefaultButtonStyle(
                colors: colors,
                pressedColor: colors.background
            ))
            .disabled(isSavingFavorite)
            .accessibilityIdentifier("prayer-favorite")

            if !feedback.isEmpty {
                Text(feedback)
                    .font(JohnTypography.sans(16))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 16, targetLineHeight: 24))
                    .foregroundStyle(colors.textDim)
                    .contentAnnouncement(feedback)
            }
            ContentMutedText(text: prayer.source)
        }
    }

    private var notFound: some View {
        ContentPage(title: "Prayer not found", eyebrow: nil, subtitle: nil) {
            ContentMutedText(text: "This prayer is not in the library.")
            ContentButton(title: "Prayer library") { onNavigate(.prayers) }
        }
    }

    @ViewBuilder private func prayerArtwork(for prayerID: String) -> some View {
        let name = ["angelus", "hail-mary", "regina-caeli"].contains(prayerID) ? "mary" : "prayer"
        if let root = Bundle.main.resourceURL?.appendingPathComponent("App/Artwork/\(name).jpg"),
           let image = UIImage(contentsOfFile: root.path) {
            Image(uiImage: image).resizable()
        } else {
            Rectangle().fill(colors.card)
        }
    }

    @MainActor private func loadPrayer() async {
        guard let repository = runtime.companionRepository else {
            loadFailed = true
            loaded = true
            return
        }
        let requestedID = id
        do {
            let catalog = try await repository.devotionalCatalog()
            guard !Task.isCancelled, requestedID == id else { return }
            prayer = catalog.prayers.first { $0.id == requestedID }
        } catch {
            guard !Task.isCancelled, requestedID == id else { return }
            prayer = nil
            loadFailed = true
        }
        loaded = true
    }

    @MainActor private func toggleFavorite() {
        guard !isSavingFavorite else { return }
        isSavingFavorite = true
        feedback = ""
        Task { @MainActor in
            let saved = await PrayerFavoriteQueue.toggle(id, using: runtime)
            feedback = saved ? "" : "Could not update favorites. Please try again."
            isSavingFavorite = false
        }
    }
}

@MainActor
private enum PrayerFavoriteQueue {
    private static var lastOperation: Task<Bool, Never>?

    static func toggle(_ id: String, using runtime: JohnRuntime) async -> Bool {
        let previous = lastOperation
        let operation = Task { @MainActor in
            if let previous { _ = await previous.value }
            guard var ids = runtime.committedNativeState?.favoritePrayerIDs else { return false }
            if let index = ids.firstIndex(of: id) {
                ids.remove(at: index)
            } else {
                ids.append(id)
            }
            return await runtime.applyWithResult(.setFavoritePrayerIDs(ids))
        }
        lastOperation = operation
        return await operation.value
    }
}
