import SwiftUI

struct WorksPage<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                content
            }
            // 2.1.1: the same readable width as Settings, centred on iPad.
            .frame(maxWidth: 740, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(colors.background)
    }
}

struct WorksEyebrow: View {
    let text: String
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(JohnTypography.sans(12, weight: .semibold))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(preferences.colors(for: colorScheme).tint)
    }
}

struct WorksPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
    }
}
