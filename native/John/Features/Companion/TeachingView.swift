import SwiftUI
import JohnCore

struct TeachingView: View {
    let id: String?
    let onNavigate: (CompanionRoute) -> Void

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @State private var catalog: DevotionalCatalog?
    @State private var loadMessage: String?
    @State private var linkMessage: String?

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var teaching: TeachingCatalogItem? { catalog?.teachings.first { $0.id == id } }

    var body: some View {
        Group {
            if let loadMessage {
                ContentPage(title: "Faith, rooted in Scripture", eyebrow: "Explore & understand",
                            subtitle: "Small introductions to Catholic belief, with places to read more.") {
                    ContentMutedText(text: loadMessage)
                }
            } else if let id, catalog != nil, teaching == nil {
                ContentPage(title: "Topic not found", eyebrow: nil, subtitle: nil) {
                    ContentButton(title: "Explore the faith") { onNavigate(.learn) }
                }
            } else if let teaching {
                detail(teaching)
            } else {
                library
            }
        }
        .task { await loadCatalog() }
    }

    private var library: some View {
        ContentPage(title: "Faith, rooted in Scripture", eyebrow: "Explore & understand",
                    subtitle: "Small introductions to Catholic belief, with places to read more.") {
            if let catalog {
                ForEach(catalog.teachings, id: \.id) { item in
                    ContentArtCard(artwork: item.artwork, title: item.title,
                                   subtitle: item.subtitle) {
                        onNavigate(.teaching(id: item.id))
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            }
        }
    }

    private func detail(_ item: TeachingCatalogItem) -> some View {
        ContentPage(title: item.title, eyebrow: "Scripture & Catholic teaching",
                    subtitle: item.subtitle) {
            ContentArtwork(name: item.artwork)
                .scaledToFill()
                .aspectRatio(1.7, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityHidden(true)
            Text(item.summary)
                .font(JohnTypography.sans(17))
                .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 17, targetLineHeight: 28))
                .foregroundStyle(colors.text)
                .textSelection(.enabled)
            ContentPanel {
                ContentSectionTitle(title: "Read in Scripture")
                ForEach(item.references, id: \.self) { reference in
                    ContentActionRow(title: reference, subtitle: "Open in context · WEB-CE") {
                        onNavigate(.citationContext(reference: reference))
                    }
                }
            }
            ContentPanel {
                ContentSectionTitle(title: "Bring it to prayer")
                Text(item.reflection)
                    .font(JohnTypography.serif(24))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "Lora-Regular", size: 24, targetLineHeight: 36))
                    .foregroundStyle(colors.text)
            }
            ContentMutedText(text: "John 1:1 introduction · Based on \(item.catechism). This summary is not a quotation from the Catechism.")
            if let linkMessage {
                ContentMutedText(text: linkMessage)
                    .contentAnnouncement(linkMessage)
            }
            ContentButton(title: "Read \(item.catechism) ↗") {
                guard let url = URL(string: item.url) else {
                    linkMessage = "The Catechism could not be opened. Please try again when connected."
                    return
                }
                openURL(url) { accepted in
                    if !accepted {
                        linkMessage = "The Catechism could not be opened. Please try again when connected."
                    } else {
                        linkMessage = nil
                    }
                }
            }
        }
    }

    @MainActor private func loadCatalog() async {
        guard let repository = runtime.companionRepository else {
            loadMessage = "These introductions are not available right now."
            return
        }
        do {
            catalog = try await repository.devotionalCatalog()
            loadMessage = nil
        } catch {
            loadMessage = "These introductions are not available right now."
        }
    }
}
