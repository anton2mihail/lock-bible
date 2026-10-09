import SwiftUI
import UIKit
import JohnCore

struct ScriptureCardView: View {
    let passage: PassageSelection

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var plum = false
    @State private var artworkFailed = false
    @State private var shareBusy = false
    @State private var shareError: String?
    @State private var shareURL: URL?
    @State private var sharePresented = false
    @State private var attribution = ""
    @State private var shareGeneration = UUID()
    @State private var previewWidth: CGFloat = 360
    @State private var cardHeight: CGFloat = 480

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var reference: String {
        let start = passage.startVerse.rawValue
        let end = passage.endVerse.rawValue
        return start == end ? "\(passage.bookName) \(passage.chapter):\(start)" : "\(passage.bookName) \(passage.chapter):\(start)–\(end)"
    }
    private var translationLabel: String {
        passage.translationID.shareLabel
    }

    var body: some View {
        ContentPage(title: "A word worth sharing", eyebrow: "Scripture cards",
                    subtitle: "Choose a background. Keep the words at the center.") {
            HStack(spacing: 12) {
                preset(title: "Warm ivory", selected: !plum) { plum = false }
                preset(title: "Evening plum", selected: plum) { plum = true }
            }

            GeometryReader { proxy in
                ShareCardSurface(text: passage.scriptureText, reference: reference,
                                 translationLabel: translationLabel, plum: plum,
                                 artworkFailed: $artworkFailed)
                    .frame(width: proxy.size.width)
                    .frame(minHeight: 480, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .background {
                        GeometryReader { measured in
                            Color.clear.preference(key: ShareCardSizePreferenceKey.self, value: measured.size)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityElement(children: .combine)
            }
            .frame(height: cardHeight)
            .onPreferenceChange(ShareCardSizePreferenceKey.self) { size in
                guard size.width > 0, size.height > 0 else { return }
                previewWidth = size.width
                cardHeight = max(480, ceil(size.height))
            }

            if artworkFailed {
                ContentMutedText(text: "Artwork could not load. You can still share the words on a plain background.")
            }
            if shareBusy {
                HStack(spacing: 8) { ProgressView(); Text("Preparing Scripture card…") }
                    .font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
                    .accessibilityIdentifier("scripture-card-share-busy")
            }
            if let shareError {
                ContentMutedText(text: shareError)
                    .accessibilityIdentifier("scripture-card-share-error")
            }
            Button(action: prepareImageShare) {
                Text(shareURL == nil ? "Share Scripture card" : "Share Scripture card")
                    .font(JohnTypography.sans(16, weight: .medium))
                    .foregroundStyle(colors.text)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .padding(.horizontal, 12)
            }
            .buttonStyle(ContentDefaultButtonStyle(colors: colors, pressedColor: colors.background))
            .disabled(shareBusy)
            .accessibilityIdentifier("scripture-card-share-image")

            ScriptureShareLink(text: passage.scriptureText, reference: reference, translationLabel: translationLabel) {
                Text("Share text instead")
                    .font(JohnTypography.sans(14, weight: .medium))
                    .foregroundStyle(colors.text)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            ContentMutedText(text: attribution)
        }
        .task(id: passage.id.legacyKey) {
            attribution = await runtime.translationAttribution(passage.translationID)
        }
        .sheet(isPresented: $sharePresented, onDismiss: cleanupImage) {
            if let shareURL {
                ScriptureImageShareSheet(url: shareURL) { cleanupImage() }
                    .ignoresSafeArea()
            }
        }
        .onDisappear(perform: cleanupImage)
    }

    @ViewBuilder private func shareArtwork(width: CGFloat) -> some View {
        let surface = ShareCardSurface(text: passage.scriptureText, reference: reference,
                                       translationLabel: translationLabel, plum: plum,
                                       artworkFailed: $artworkFailed)
        surface.frame(width: width, alignment: .leading).frame(minHeight: 480)
            .fixedSize(horizontal: false, vertical: true)
    }

    @MainActor private func prepareImageShare() {
        shareBusy = true
        shareError = nil
        let generation = UUID()
        shareGeneration = generation
        let renderer = ImageRenderer(content: shareArtwork(width: previewWidth))
        renderer.scale = 1080 / previewWidth
        renderer.proposedSize = ProposedViewSize(width: previewWidth, height: nil)
        guard let image = renderer.uiImage, let png = image.pngData() else {
            shareBusy = false
            shareError = "The Scripture card could not be prepared. You can share the words instead."
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("john-scripture-card-\(generation.uuidString).png")
        do {
            try png.write(to: url, options: .atomic)
            guard generation == shareGeneration else {
                try? FileManager.default.removeItem(at: url)
                return
            }
            shareURL = url
            shareBusy = false
            sharePresented = true
        } catch {
            shareBusy = false
            shareError = "The card could not be shared. Please try again, or share the text."
        }
    }

    @MainActor private func cleanupImage() {
        if let shareURL { try? FileManager.default.removeItem(at: shareURL) }
        shareURL = nil
        sharePresented = false
    }

    private func preset(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(JohnTypography.sans(14, weight: .medium))
                .foregroundStyle(colors.text)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(selected ? colors.card : colors.background, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(colors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct ShareCardSurface: View {
    let text: String
    let reference: String
    let translationLabel: String
    let plum: Bool
    @Binding var artworkFailed: Bool

    private var background: Color { plum ? Color(red: 47.0 / 255, green: 29.0 / 255, blue: 44.0 / 255) : Color(red: 244.0 / 255, green: 234.0 / 255, blue: 219.0 / 255) }
    private var foreground: Color { plum ? Color(red: 1, green: 247.0 / 255, blue: 232.0 / 255) : Color(red: 52.0 / 255, green: 38.0 / 255, blue: 45.0 / 255) }
    private var fontSize: CGFloat { text.utf16.count > 900 ? 20 : 26 }
    private var targetHeight: CGFloat { text.utf16.count > 900 ? 31 : 39 }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                if let image = artworkImage {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped().overlay(background.opacity(0.13))
                } else { background.onAppear { artworkFailed = true } }
            }
            VStack(alignment: .leading, spacing: 32) {
                Text("JOHN 1:1").font(JohnTypography.sans(11, weight: .semibold)).tracking(5)
                Text(text)
                    .font(JohnTypography.serif(fontSize))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "Lora-Regular", size: fontSize, targetLineHeight: targetHeight))
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(reference).font(JohnTypography.sans(14, weight: .medium))
                    Text(translationLabel).font(JohnTypography.sans(12))
                }
                .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(foreground)
            .padding(32)
            .padding(.bottom, 88)
        }
        .background(background)
        .frame(maxWidth: .infinity, minHeight: 480, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var artworkImage: UIImage? {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("App/Artwork/\(plum ? "share-plum" : "share-ivory").jpg") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

private struct ShareCardSizePreferenceKey: PreferenceKey {
    static let defaultValue = CGSize.zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

private struct ScriptureImageShareSheet: UIViewControllerRepresentable {
    let url: URL
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onComplete() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
