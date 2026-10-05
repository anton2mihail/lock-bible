import SwiftUI

struct CompanionPage<Content: View>: View {
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
                            .font(JohnTypography.sans(11, weight: .medium))
                            .tracking(2)
                            .foregroundStyle(colors.tint)
                    }
                    Text(title)
                        .font(JohnTypography.title(36))
                        .tracking(-0.8)
                        .foregroundStyle(colors.text)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("page-title-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
                    if let subtitle {
                        Text(subtitle)
                            .font(JohnTypography.sans(17))
                            .foregroundStyle(colors.textDim)
                    }
                }
                content
            }
            .frame(maxWidth: 740, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity)
        }
        .background(colors.background)
    }
}

struct SectionHeading: View {
    let title: String
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Text(title)
            .font(JohnTypography.sans(24, weight: .semibold))
            .foregroundStyle(preferences.colors(for: colorScheme).text)
            .accessibilityAddTraits(.isHeader)
    }
}

struct MutedText: View {
    let text: String
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Text(text)
            .font(JohnTypography.sans(16))
            .foregroundStyle(preferences.colors(for: colorScheme).textDim)
    }
}

struct SurfaceCard<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(preferences.colors(for: colorScheme).card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(preferences.colors(for: colorScheme).separator, lineWidth: 0.5))
    }
}
