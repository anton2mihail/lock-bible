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
        case .read:
            ReaderView()
        case .saved:
            SavedView()
        case .pray:
            PrayerHomeView(timeZone: runtime.featureTimeZone, clock: { runtime.featureNow() },
                           onNavigate: { router.push(.companion($0)) }, onClose: {})
        case .settings:
            FullSettingsView(onOpenCalendarNotifications: { router.push(.calendarNotifications) })
        case .today:
            CompanionTodayView(onNavigate: { router.push(.companion($0)) },
                               onClose: {},
                               onOpenVerseMoment: {
                                   router.push(.verseMoment(VerseMomentSelection(verse: $0, translation: preferences.translation)))
                               })
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
    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    var body: some View {
        @Bindable var preferences = preferences
        SurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Text size", selection: Binding(
                    get: { preferences.reading.textSize.rawValue },
                    set: { value in
                        guard let size = ReaderTextSize(rawValue: value) else { return }
                        Task { await runtime.apply(.setReaderTextSize(size)) }
                    }
                )) {
                    Text("Small").tag(ReaderTextSize.small.rawValue)
                    Text("Default").tag(ReaderTextSize.medium.rawValue)
                    Text("Large").tag(ReaderTextSize.large.rawValue)
                    Text("Extra large").tag(ReaderTextSize.extraLarge.rawValue)
                }
                .accessibilityIdentifier("settings-text-size")
                .accessibilityValue(textSizeAccessibilityValue)
                Picker("Reading layout", selection: Binding(
                    get: { preferences.reading.layout.rawValue },
                    set: { value in
                        guard let layout = ReaderLayout(rawValue: value) else { return }
                        Task { await runtime.apply(.setReaderLayout(layout)) }
                    }
                )) {
                    Text("Paragraphs").tag(ReaderLayout.paragraphs.rawValue)
                    Text("Verse by verse").tag(ReaderLayout.verses.rawValue)
                }
                .accessibilityIdentifier("settings-reading-layout")
                .accessibilityHint("With VoiceOver on, the reader always goes verse by verse.")
                Picker("Appearance", selection: Binding(
                    get: { preferences.appearance },
                    set: { value in Task { await runtime.apply(.setThemeScheme(value == .system ? nil : value.rawValue)) } }
                )) {
                    ForEach(AppearanceMode.allCases) { mode in Text(mode.rawValue.capitalized).tag(mode) }
                }
                .accessibilityIdentifier("settings-appearance")
                Picker("Bible", selection: Binding(
                    get: { preferences.translation.rawValue },
                    set: { value in
                        guard let translation = TranslationID(rawValue: value) else { return }
                        Task { await runtime.apply(.setTranslationID(translation.rawValue)) }
                    }
                )) {
                    Text("WEB").tag(TranslationID.webCE.rawValue)
                    Text("Douay-Rheims").tag(TranslationID.douayRheims.rawValue)
                    Text("Vulgate").tag(TranslationID.vulgate.rawValue)
                }
                .accessibilityIdentifier("settings-translation")
                Picker("Line spacing", selection: Binding(
                    get: { preferences.reading.lineSpacing.rawValue },
                    set: { value in
                        guard let spacing = ReaderLineSpacing(rawValue: value) else { return }
                        Task { await runtime.apply(.setReaderLineSpacing(spacing)) }
                    }
                )) {
                    Text("Compact").tag(ReaderLineSpacing.compact.rawValue)
                    Text("Comfortable").tag(ReaderLineSpacing.comfortable.rawValue)
                    Text("Relaxed").tag(ReaderLineSpacing.relaxed.rawValue)
                }
                .accessibilityIdentifier("settings-line-spacing")
                Picker("Scripture typeface", selection: Binding(
                    get: { preferences.reading.typeface.rawValue },
                    set: { value in
                        guard let typeface = ReaderTypeface(rawValue: value) else { return }
                        Task { await runtime.apply(.setReaderTypeface(typeface)) }
                    }
                )) {
                    Text("Serif").tag(ReaderTypeface.serif.rawValue)
                    Text("Sans").tag(ReaderTypeface.sans.rawValue)
                }
                .accessibilityIdentifier("settings-scripture-typeface")
            }
            .pickerStyle(.menu)
        }
    }

    private var textSizeAccessibilityValue: String {
        switch preferences.reading.textSize {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra large"
        }
    }
}
