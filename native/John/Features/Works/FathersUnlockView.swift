import SwiftUI
import UIKit
import JohnCore

/// The one purchase page. The reader shows it in place of a locked section; Settings and the library open it too.
/// The price always comes from StoreKit. Content appears in its final state (no entrance animation).
struct FathersUnlockPanel: View {
    /// Shown above the title when the reader reached the end of a free sample.
    var sampleNotice: String?

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var catalog: WorkCatalog?

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var store: FathersLibraryStore { runtime.fathers }
    private var totalWords: Int { catalog?.collections.reduce(0) { $0 + $1.words } ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            artwork
            WorksEyebrow("THE FATHERS & DOCTORS")
            if let sampleNotice {
                Text(sampleNotice)
                    .font(JohnTypography.sans(14))
                    .foregroundStyle(colors.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(store.isUnlocked ? "The whole library is yours" : "Read the whole library")
                .font(JohnTypography.sans(28, weight: .bold))
                .foregroundStyle(colors.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(summary)
                .font(JohnTypography.sans(16))
                .lineSpacing(4)
                .foregroundStyle(colors.text)
                .fixedSize(horizontal: false, vertical: true)

            switch store.access {
            case .grandfathered:
                note("You installed John 1:1 before the library was sold, so it stays free for you. Thank you.")
            case .purchased:
                note("Thank you for supporting John 1:1.")
            case .checking, .locked:
                buyButton
                if case let .failed(message) = store.purchaseState { note(message) }
                if store.purchaseState == .pending { note("Your purchase is waiting for approval. The library unlocks as soon as it is approved.") }
                restoreButton
                if let message = store.restoreMessage { note(message).contentAnnouncement(message) }
                note("Everything else in John 1:1 stays free: the Bible, the Rosary, prayers, readings, saints and widgets. One payment, no subscription. Family Sharing is on.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            catalog = await runtime.worksCatalog()
            await store.loadProduct()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fathers-unlock")
    }

    /// 2.1.1: the bundled public-domain painting, "The Four Evangelists" by Abraham Bloemaert (artwork key
    /// `scripture`, credited in `assets/artwork/sources.json`). It shows at its final state, with no animation.
    @ViewBuilder private var artwork: some View {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("App/Artwork/scripture.jpg"),
           let image = UIImage(contentsOfFile: url.path) {
            VStack(alignment: .leading, spacing: 6) {
                Color.clear
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .overlay { Image(uiImage: image).resizable().scaledToFill() }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityHidden(true)
                Text("Abraham Bloemaert, The Four Evangelists, c. 1612–15")
                    .font(JohnTypography.sans(11))
                    .foregroundStyle(colors.textDim)
                    .accessibilityHidden(true)
            }
        }
    }

    private var summary: String {
        guard let catalog else { return "Every work of the Fathers and Doctors in the app, offline." }
        return "\(WorksSourceText.plural(catalog.collections.count, "author")), \(WorksSourceText.plural(catalog.works.count, "work")), \(WorksSourceText.corpusSize(totalWords)), offline. Augustine complete, the Summa of St Thomas Aquinas, Chrysostom, Jerome, Ambrose, Athanasius and more. The first part of every work, the Apostolic Fathers and the Confessions are free to read."
    }

    private var buyButton: some View {
        Button {
            Task { await store.purchase() }
        } label: {
            HStack(spacing: 8) {
                if store.purchaseState == .purchasing { ProgressView().tint(colors.background) }
                Text(buyTitle)
                    .font(JohnTypography.sans(16, weight: .semibold))
            }
            .foregroundStyle(colors.background)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(colors.tint, in: RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(WorksPressStyle())
        .disabled(store.purchaseState == .purchasing || store.access == .checking)
        .accessibilityIdentifier("fathers-buy")
    }

    private var buyTitle: String {
        if store.access == .checking { return "Checking your purchases…" }
        if let price = store.displayPrice { return "Unlock the library · \(price)" }
        return store.productLoadFailed ? "Unlock the library" : "Loading price…"
    }

    private var restoreButton: some View {
        ContentButton(title: "Restore Purchases") { Task { await store.restore() } }
            .accessibilityIdentifier("fathers-restore")
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(JohnTypography.sans(14))
            .foregroundStyle(colors.textDim)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The purchase page on its own, for Settings and the library header.
struct FathersUnlockScreen: View {
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                FathersUnlockPanel()
                    .frame(maxWidth: 620, alignment: .leading)
                    .padding(24)
                    .frame(maxWidth: .infinity)
            }
            .background(preferences.colors(for: colorScheme).background)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
