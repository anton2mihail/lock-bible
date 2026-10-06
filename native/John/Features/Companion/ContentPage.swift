import SwiftUI
import UIKit

struct ContentPage<Content: View>: View {
    let title: String
    let eyebrow: String?
    let subtitle: String?
    @ViewBuilder var content: Content

    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    if let eyebrow {
                        Text(eyebrow.uppercased())
                            .font(JohnTypography.sans(11))
                            .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 11, targetLineHeight: 18))
                            .tracking(2)
                            .foregroundStyle(colors.tint)
                    }
                    Text(title)
                        .font(JohnTypography.title(36))
                        .tracking(-0.8)
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "Lora-Regular", size: 36, targetLineHeight: 46))
                        .foregroundStyle(colors.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier(title == "A little closer to God." ? "today-title" : "content-page-title")
                    if let subtitle {
                        Text(subtitle)
                            .font(JohnTypography.sans(16))
                            .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 16, targetLineHeight: 24))
                            .foregroundStyle(colors.textDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                content
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 48)
            .frame(maxWidth: 740, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(colors.background)
    }
}

struct ContentPanel<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(colors.separator, lineWidth: 1 / displayScale)
            }
    }
}

struct ContentActionRow: View {
    let title: String
    let subtitle: String?
    var icon = "arrow-up-right"
    var imageName: String?
    var onPress: () -> Void

    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        Button(action: onPress) {
            HStack(spacing: 16) {
                if let imageName, let url = Bundle.main.resourceURL?.appendingPathComponent("App/Artwork/\(imageName).jpg"),
                   let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(JohnTypography.sans(16, weight: .medium))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Medium", size: 16, targetLineHeight: 24))
                        .foregroundStyle(colors.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(JohnTypography.sans(14))
                            .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 14, targetLineHeight: 21))
                            .foregroundStyle(colors.textDim)
                    }
                }
                Spacer(minLength: 0)
                FeatherIcon(name: icon, size: 19, color: colors.tint)
            }
            .padding(.vertical, 12)
            .frame(minHeight: 72)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle().fill(colors.separator).frame(height: 1 / displayScale)
            }
        }
        .buttonStyle(ContentActionButtonStyle())
        .accessibilityLabel(subtitle.map { "\(title). \($0)" } ?? title)
    }
}

struct ContentSectionTitle: View {
    let title: String
    var detail: String?
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(JohnTypography.sans(20, weight: .medium))
                .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Medium", size: 20, targetLineHeight: 32))
                .foregroundStyle(preferences.colors(for: colorScheme).text)
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail)
                    .font(JohnTypography.sans(14))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 14, targetLineHeight: 21))
                    .foregroundStyle(preferences.colors(for: colorScheme).textDim)
            }
        }
    }
}

struct ContentButton: View {
    let title: String
    var expandsToFill = true
    var action: () -> Void
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(JohnTypography.sans(16, weight: .medium))
                .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Medium", size: 16, targetLineHeight: 20))
                .foregroundStyle(colors.text)
                .frame(maxWidth: expandsToFill ? .infinity : nil, minHeight: 56)
                .padding(.horizontal, 12)
        }
        .buttonStyle(ContentDefaultButtonStyle(
            colors: colors,
            pressedColor: colors.background
        ))
    }
}

struct ContentActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.65 : 1)
    }
}

struct ContentDefaultButtonStyle: ButtonStyle {
    let colors: JohnColors
    let pressedColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? pressedColor : colors.card,
                        in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(colors.border, lineWidth: 1))
    }
}

enum ContentTypography {
    static func additionalSpacing(fontName: String, size: CGFloat, targetLineHeight: CGFloat) -> CGFloat {
        let measured = UIFont(name: fontName, size: size)?.lineHeight ?? size
        return max(0, targetLineHeight - measured)
    }
}

struct ContentAnnouncementModifier: ViewModifier {
    let message: String?
    @State private var lastPostedMessage: String?

    func body(content: Content) -> some View {
        content
            .task(id: message) {
                guard let message, !message.isEmpty, message != lastPostedMessage else { return }
                lastPostedMessage = message
                UIAccessibility.post(notification: .announcement, argument: message)
            }
    }
}

extension View {
    func contentAnnouncement(_ message: String?) -> some View {
        modifier(ContentAnnouncementModifier(message: message))
    }
}
