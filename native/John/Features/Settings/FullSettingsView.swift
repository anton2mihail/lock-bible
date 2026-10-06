import SwiftUI
import JohnCore

struct FullSettingsView: View {
    let onOpenCalendarNotifications: () -> Void

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var metadata: [TranslationID: BibleTranslationMetadata] = [:]
    @State private var coverage: CalendarCoverage?
    @State private var loadFailed = false
    @State private var saveMessage: String?
    @State private var saveGeneration = 0

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var orderedTranslations: [TranslationID] { [.webCE, .douayRheims, .vulgate] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(JohnTypography.sans(36, weight: .bold))
                    .foregroundStyle(colors.text)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("settings-title")

                if let saveMessage {
                    Text(saveMessage).font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
                        .contentAnnouncement(saveMessage)
                }
                if loadFailed {
                    Text("Some installed reading information could not be opened.")
                        .font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
                }

                section("Reading") {
                    SettingsChoiceGroup(label: "Text size", options: [
                        .init(title: "Small", selected: preferences.reading.textSize == .small) { save(.setReaderTextSize(.small)) },
                        .init(title: "Default", selected: preferences.reading.textSize == .medium) { save(.setReaderTextSize(.medium)) },
                        .init(title: "Large", selected: preferences.reading.textSize == .large) { save(.setReaderTextSize(.large)) },
                        .init(title: "Extra large", selected: preferences.reading.textSize == .extraLarge) { save(.setReaderTextSize(.extraLarge)) },
                    ])
                    SettingsChoiceGroup(label: "Line spacing", topSeparator: true, options: [
                        .init(title: "Compact", selected: preferences.reading.lineSpacing == .compact) { save(.setReaderLineSpacing(.compact)) },
                        .init(title: "Comfortable", selected: preferences.reading.lineSpacing == .comfortable) { save(.setReaderLineSpacing(.comfortable)) },
                        .init(title: "Relaxed", selected: preferences.reading.lineSpacing == .relaxed) { save(.setReaderLineSpacing(.relaxed)) },
                    ])
                    SettingsChoiceGroup(label: "Scripture typeface", topSeparator: true, options: [
                        .init(title: "Serif", selected: preferences.reading.typeface == .serif) { save(.setReaderTypeface(.serif)) },
                        .init(title: "Sans", selected: preferences.reading.typeface == .sans) { save(.setReaderTypeface(.sans)) },
                    ])
                    SettingsChoiceGroup(label: "Layout", topSeparator: true, hint: "With VoiceOver on, the reader always goes verse by verse.", options: [
                        .init(title: "Paragraphs", selected: preferences.reading.layout == .paragraphs) { save(.setReaderLayout(.paragraphs)) },
                        .init(title: "Verse by verse", selected: preferences.reading.layout == .verses) { save(.setReaderLayout(.verses)) },
                    ])
                    SettingsChoiceGroup(label: "Appearance", topSeparator: true, options: [
                        .init(title: "System", selected: preferences.appearance == .system) { save(.setThemeScheme(nil)) },
                        .init(title: "Light", selected: preferences.appearance == .light) { save(.setThemeScheme("light")) },
                        .init(title: "Dark", selected: preferences.appearance == .dark) { save(.setThemeScheme("dark")) },
                    ])
                }

                section("Translation") {
                    ForEach(Array(orderedTranslations.enumerated()), id: \.element) { index, id in
                        SettingsListRow(title: metadata[id]?.fullName ?? id.rawValue,
                                        selected: preferences.translation == id,
                                        topSeparator: index > 0) { save(.setTranslationID(id.rawValue)) }
                            .accessibilityIdentifier("translation-\(id.rawValue)")
                    }
                    Text("\(orderedTranslations.count) complete Catholic editions are available offline. Your choice also controls the rotating verse and lock-screen widget.")
                        .font(JohnTypography.sans(12)).foregroundStyle(colors.textDim).padding(.vertical, 12)
                }

                section("Verse pool") {
                    SettingsListRow(title: "Full Bible", selected: preferences.scope == .full) { save(.setVerseScope(.full)) }
                    SettingsListRow(title: "Old Testament", selected: preferences.scope == .ot, topSeparator: true) { save(.setVerseScope(.ot)) }
                    SettingsListRow(title: "New Testament", selected: preferences.scope == .nt, topSeparator: true) { save(.setVerseScope(.nt)) }
                    Text("Which part of Scripture the rotating verse is drawn from. Old Testament includes the deuterocanonical books.")
                        .font(JohnTypography.sans(12)).foregroundStyle(colors.textDim).padding(.vertical, 12)
                }

                section("Verse rotation") {
                    ForEach(Array(intervalOptions.enumerated()), id: \.element.minutes) { index, option in
                        SettingsListRow(title: option.title, selected: preferences.intervalMinutes == option.minutes,
                                        topSeparator: index > 0) { save(.setRotationInterval(option.minutes)) }
                    }
                    Text("How often the Verse of the Moment and your lock screen widget change.")
                        .font(JohnTypography.sans(12)).foregroundStyle(colors.textDim).padding(.vertical, 12)
                }

                section("Lock screen widgets") {
                    Text("1. Touch and hold your lock screen, then tap Customize.\n2. Tap the box under the clock and choose this app.\n3. Choose “Daily Verse” for rotating Scripture or “Daily Reading” for today’s Gospel. You can add both. “Verse Countdown” shows time until the next rotating verse.\n4. Pick the rectangular size for full text, or the inline/circular size for a compact view.")
                        .font(JohnTypography.sans(16)).lineSpacing(4).foregroundStyle(colors.text).padding(.vertical, 12)
                }

                section("Calendar notifications") {
                    Button(action: onOpenCalendarNotifications) {
                        HStack(spacing: 16) {
                            Image(systemName: "bell")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(colors.tint)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Saints, feasts & daily readings").font(JohnTypography.sans(16, weight: .medium)).foregroundStyle(colors.text)
                                Text("Choose a delivery time and turn notices on or off")
                                    .font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
                            }
                            Spacer(minLength: 0)
                            Text("›").font(JohnTypography.sans(24)).foregroundStyle(colors.tint)
                        }
                        .frame(minHeight: 72)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-calendar-notifications")
                }

                section("John 1:1 · Scripture & Prayer") {
                    Text("A little closer to God, every day.").font(JohnTypography.sans(16)).foregroundStyle(colors.text).padding(.top, 8)
                    Text("United States · Roman Rite. Offline reading references: \(coverage?.label ?? "No offline dates installed"). Local observances can differ.")
                        .font(JohnTypography.sans(14)).foregroundStyle(colors.text).padding(.top, 8)
                    Text("Original sacred illustrations created for John 1:1 with AI. Prayer introductions and teaching summaries are editorial guides; source references are provided alongside them.")
                        .font(JohnTypography.sans(14)).foregroundStyle(colors.text).padding(.top, 8)
                    Text("Reading metadata: catholic-readings-api (MIT). Celebration calendar: romcal (MIT). Reflections stay on this device. Confession notes are never saved.")
                        .font(JohnTypography.sans(14)).foregroundStyle(colors.text).padding(.top, 8)
                    if let selected = metadata[preferences.translation] {
                        Text(selected.attribution).font(JohnTypography.sans(14)).foregroundStyle(colors.text).padding(.top, 8)
                        Text(selected.copyrightNotice).font(JohnTypography.sans(12)).foregroundStyle(colors.textDim).padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(colors.background)
        .task { await loadInformation() }
    }

    private var intervalOptions: [(minutes: Int, title: String)] {
        [(10, "Every 10 minutes"), (15, "Every 15 minutes"), (30, "Every 30 minutes"),
         (60, "Every hour"), (180, "Every 3 hours"), (360, "Every 6 hours"),
         (720, "Every 12 hours"), (1440, "Once a day")]
    }

    @ViewBuilder private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(JohnTypography.sans(16, weight: .medium)).foregroundStyle(colors.textDim)
            VStack(alignment: .leading, spacing: 0, content: content)
                .padding(.horizontal, 16)
                .background(colors.card, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func save(_ mutation: NativeStateMutation) {
        saveGeneration += 1
        let generation = saveGeneration
        Task {
            let success = await runtime.applyWithResult(mutation)
            guard generation == saveGeneration else { return }
            saveMessage = success ? nil : "The setting could not be saved. Your previous choice is still active."
        }
    }

    @MainActor private func loadInformation() async {
        for id in orderedTranslations {
            if let value = await runtime.translationMetadata(id) { metadata[id] = value }
        }
        coverage = await runtime.installedCalendarCoverage()
        loadFailed = coverage == nil || metadata.count != orderedTranslations.count
    }
}

private struct SettingsChoiceGroup: View {
    struct Option: Identifiable {
        let title: String
        let selected: Bool
        let action: () -> Void
        var id: String { title }
        init(title: String, selected: Bool, action: @escaping () -> Void) {
            self.title = title; self.selected = selected; self.action = action
        }
    }

    let label: String
    var topSeparator = false
    var hint: String?
    let options: [Option]
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if topSeparator { Rectangle().fill(colors.separator).frame(height: 1).padding(.horizontal, -16) }
            Text(label).font(JohnTypography.sans(14, weight: .medium)).foregroundStyle(colors.text)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(options) { option in
                    Button(action: option.action) {
                        Text(option.title).font(JohnTypography.sans(14, weight: .medium))
                            .foregroundStyle(option.selected ? colors.card : colors.text)
                            .padding(.horizontal, 12).frame(minHeight: 44)
                            .frame(maxWidth: .infinity)
                            .background(option.selected ? colors.tint : colors.background, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(option.selected ? colors.tint : colors.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement().accessibilityLabel("\(label), \(option.title)")
                    .accessibilityAddTraits(option.selected ? .isSelected : [])
                    .accessibilityIdentifier("settings-\(label.lowercased().replacingOccurrences(of: " ", with: "-"))-\(option.title.lowercased().replacingOccurrences(of: " ", with: "-"))")
                }
            }
            if let hint { Text(hint).font(JohnTypography.sans(12)).foregroundStyle(colors.textDim) }
        }
        .padding(.vertical, 12)
    }
}

private struct SettingsListRow: View {
    let title: String
    let selected: Bool
    var topSeparator = false
    let action: () -> Void
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title).font(JohnTypography.sans(16)).foregroundStyle(colors.text)
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(colors.tint) }
            }
            .frame(minHeight: 56)
            .overlay(alignment: .top) { if topSeparator { Rectangle().fill(colors.separator).frame(height: 1) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement().accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
