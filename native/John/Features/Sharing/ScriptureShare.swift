import SwiftUI
import UniformTypeIdentifiers
import JohnCore

extension TranslationID {
    var shareLabel: String {
        switch self {
        case .webCE: "WEB-CE"
        case .douayRheims: "DRB"
        case .vulgate: "VUL"
        }
    }
}

/// One Scripture item to share. It exports a rendered card image and a text form.
struct ScriptureShareItem: Transferable, Sendable {
    let text: String
    let reference: String
    let translationLabel: String

    var plainText: String { "\(text) — \(reference) (\(translationLabel))" }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            await item.renderedPNG()
        }
        ProxyRepresentation(exporting: \.plainText)
    }

    @MainActor static func render(text: String, reference: String, translationLabel: String,
                                  width: CGFloat, scale: CGFloat) -> UIImage? {
        let card = ShareCardSurface(text: text, reference: reference, translationLabel: translationLabel,
                                    plum: false, artworkFailed: .constant(false))
            .frame(width: width, alignment: .leading)
            .frame(minHeight: width * 480 / 390)
            .fixedSize(horizontal: false, vertical: true)
        let renderer = ImageRenderer(content: card)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return renderer.uiImage
    }

    private func renderedPNG() async -> Data {
        let item = self
        let data = await MainActor.run {
            Self.render(text: item.text, reference: item.reference, translationLabel: item.translationLabel,
                        width: 390, scale: 1080 / 390)?.pngData()
        }
        return data ?? Data()
    }
}

/// A `ShareLink` for one verse, card, or note. The preview shows the rendered Scripture card.
struct ScriptureShareLink<Label: View>: View {
    let text: String
    let reference: String
    let translationLabel: String
    @ViewBuilder let label: () -> Label
    @State private var preview: UIImage?

    var body: some View {
        let item = ScriptureShareItem(text: text, reference: reference, translationLabel: translationLabel)
        ShareLink(item: item,
                  subject: Text(reference),
                  preview: SharePreview(reference, image: Image(uiImage: preview ?? UIImage(systemName: "book.closed")!)),
                  label: label)
            .task(id: text + reference) {
                preview = ScriptureShareItem.render(text: text, reference: reference,
                                                    translationLabel: translationLabel, width: 195, scale: 2)
            }
    }
}
