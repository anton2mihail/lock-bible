import SwiftUI
import JohnCore

struct SecondaryRootView: View {
    let tab: AppTab
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        switch tab {
        case .read where runtime.reader.passage != nil:
            ReaderDestination(passage: runtime.reader.passage!)
        case .read:
            CompanionPage(title: "Read", eyebrow: "Scripture", subtitle: "Return to the words that hold you.") {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Open a passage")
                            .font(JohnTypography.serif(22))
                            .foregroundStyle(colors.text)
                        Button("John 1:1") {
                            Task {
                                if let passage = await runtime.passage(reference: "John 1:1", translation: preferences.translation) {
                                    router.openReader(passage: passage)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("read-open-john-1-1")
                        Button("Search Scripture") { router.push(.search) }
                            .accessibilityIdentifier("read-search")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case .saved:
            CompanionPage(title: "Saved", eyebrow: "Your library", subtitle: "Bookmarks, highlights, and notes.") {
                SurfaceCard { MutedText(text: "Saved items appear here after you add them in the reader.") }
            }
        case .pray:
            CompanionPage(title: "Pray", eyebrow: "Prayer", subtitle: "Make room for stillness.") {
                ActionLink(title: "The Rosary", subtitle: "Pray with the mysteries") { router.push(.rosaryGuide("joyful")) }
                ActionLink(title: "Morning offering", subtitle: "Begin with intention") { router.push(.prayer("morning")) }
            }
        case .settings:
            CompanionPage(title: "Settings", eyebrow: "Your practice", subtitle: "Choose how John 1:1 works for you.") {
                SettingsControls()
            }
        case .today:
            TodayView()
        }
    }
}

private struct ActionLink: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(JohnTypography.serif(21))
                    Text(subtitle).font(JohnTypography.sans(14)).foregroundStyle(preferences.colors(for: colorScheme).textDim)
                }
                Spacer()
                FeatherIcon(name: "chevron-right", color: preferences.colors(for: colorScheme).tint)
            }
            .padding(18)
            .background(preferences.colors(for: colorScheme).card, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

struct SettingsControls: View {
    @Environment(SharedPreferencesModel.self) private var preferences
    var body: some View {
        @Bindable var preferences = preferences
        SurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Bible", selection: Binding(
                    get: { preferences.translation.rawValue },
                    set: { preferences.translation = TranslationID(rawValue: $0) ?? .webCE }
                )) {
                    Text("WEB").tag(TranslationID.webCE.rawValue)
                    Text("Douay-Rheims").tag(TranslationID.douayRheims.rawValue)
                    Text("Vulgate").tag(TranslationID.vulgate.rawValue)
                }
                Picker("Appearance", selection: $preferences.appearance) {
                    ForEach(AppearanceMode.allCases) { mode in Text(mode.rawValue.capitalized).tag(mode) }
                }
                Picker("Text size", selection: Binding(
                    get: { preferences.reading.textSize.rawValue },
                    set: { preferences.setTextSize(ReaderTextSize(rawValue: $0) ?? .medium) }
                )) {
                    Text("Small").tag(ReaderTextSize.small.rawValue)
                    Text("Medium").tag(ReaderTextSize.medium.rawValue)
                    Text("Large").tag(ReaderTextSize.large.rawValue)
                    Text("Extra large").tag(ReaderTextSize.extraLarge.rawValue)
                }
                .accessibilityIdentifier("settings-text-size")
                .accessibilityValue(preferences.reading.textSize.rawValue.capitalized)
                Picker("Reading layout", selection: Binding(
                    get: { preferences.reading.layout.rawValue },
                    set: { preferences.setLayout(ReaderLayout(rawValue: $0) ?? .paragraphs) }
                )) {
                    Text("Paragraphs").tag(ReaderLayout.paragraphs.rawValue)
                    Text("Verses").tag(ReaderLayout.verses.rawValue)
                }
            }
            .pickerStyle(.menu)
        }
    }
}
