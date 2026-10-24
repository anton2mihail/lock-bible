import SwiftUI
import JohnCore

struct PrayerHomeView: View {
    let onNavigate: (CompanionRoute) -> Void
    let clock: () -> Date
    let timeZone: TimeZone

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var loadedCatalog: DevotionalCatalog?
    private var catalog: DevotionalCatalog? { loadedCatalog ?? runtime.warmDevotionalCatalog }
    @State private var query = ""
    @State private var loadError = false

    init(timeZone: TimeZone = .autoupdatingCurrent, clock: @escaping () -> Date = Date.init,
         onNavigate: @escaping (CompanionRoute) -> Void) {
        self.timeZone = timeZone
        self.clock = clock
        self.onNavigate = onNavigate
    }

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var currentDate: Date { clock() }
    private var suggestedSet: String { TodaySelectors.rosaryWeekdaySet(date: currentDate, timeZone: timeZone) }
    private var currentState: NativePersistentState? { runtime.committedNativeState }
    private var results: [NovenaCatalogItem] {
        guard let novenas = catalog?.novenas else { return [] }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        guard !needle.isEmpty else { return novenas }
        return novenas.filter { item in
            ([item.title, item.subtitle, item.about, item.patronage] + item.searchTerms)
                .joined(separator: " ").localizedLowercase.contains(needle)
        }
    }

    var body: some View {
        NovenaLibraryPage {
            ContentArtCard(artwork: "mary", title: "Pray the Rosary",
                           subtitle: "\(mysteryTitle(suggestedSet)) · \(reminderSummary(currentState?.rosaryReminder))") {
                onNavigate(.rosaryHome)
            }
            ContentActionRow(title: "My Saints", subtitle: "Your saints, prayers, and feast days") { onNavigate(.mySaints) }
            VStack(alignment: .leading, spacing: 0) {
                ContentActionRow(title: "Our Lady of Sorrows",
                                 subtitle: "The Servite Rosary of the Seven Sorrows",
                                 imageName: "sorrows-6") {
                    onNavigate(.rosaryGuide(set: "seven-sorrows"))
                }
                ContentActionRow(title: "Everyday prayers",
                                 subtitle: "Traditional prayers and prayers of the saints") {
                    onNavigate(.prayers)
                }
                ContentActionRow(title: "Pray with Scripture", subtitle: "A quiet guide to lectio divina") {
                    onNavigate(.lectio(nil))
                }
                ContentActionRow(title: "Prepare for Confession",
                                 subtitle: "The Ten Commandments and the Catechism on Penance") {
                    onNavigate(.confession)
                }
                ContentActionRow(title: "Explore the Catholic faith", subtitle: "Scripture and the Catechism") {
                    onNavigate(.learn)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Novenas")
                    .font(JohnTypography.sans(20, weight: .medium))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Medium", size: 20, targetLineHeight: 32))
                    .foregroundStyle(colors.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Text("Nine days of prayer")
                    .font(JohnTypography.sans(12))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 12, targetLineHeight: 18))
                    .foregroundStyle(colors.textDim)
            }

            ContentInputField(placeholder: "Search by saint or need…", text: $query,
                              accessibilityLabel: "Search novenas", inputAppearance: .novenaSearch)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(javascriptTrim(query).isEmpty
                     ? "\(catalog?.novenas.count ?? 0) novenas" : "\(results.count) found")
                    .font(JohnTypography.sans(14, weight: .semibold))
                    .foregroundStyle(colors.text)
                Spacer(minLength: 0)
                ContentMutedText(text: "Available offline")
            }

            if let catalog {
                if results.isEmpty {
                    NovenaEmptyPanel {
                        ContentSectionTitle(title: "No novenas found")
                        Text("Try a saint’s name or a need such as healing or hope.")
                            .font(JohnTypography.sans(16))
                            .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 16, targetLineHeight: 24))
                            .foregroundStyle(colors.textDim)
                    }
                } else {
                    VStack(spacing: 16) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { row in
                            let index = row.offset
                            let item = row.element
                            NovenaLibraryCard(item: item,
                                progress: currentState?.novenaProgress[item.id] ?? NovenaProgress(),
                                emphasized: index == 0) {
                                onNavigate(.novena(id: item.id))
                            }
                        }
                    }
                }
            } else if loadError {
                ContentMutedText(text: "The prayer library is not available.")
            } else {
                Color.clear.frame(maxWidth: .infinity).frame(height: 72)
            }
        }
        .task { await loadCatalog() }
    }

    @MainActor private func loadCatalog() async {
        guard let repository = runtime.companionRepository else { if catalog == nil { loadError = true }; return }
        do { loadedCatalog = try await repository.devotionalCatalog() }
        catch { if catalog == nil { loadError = true } }
    }

    private func mysteryTitle(_ id: String) -> String {
        switch id {
        case "glorious": "The Glorious Mysteries"
        case "sorrowful": "The Sorrowful Mysteries"
        case "luminous": "The Luminous Mysteries"
        default: "The Joyful Mysteries"
        }
    }

    private func reminderSummary(_ reminder: RosaryReminderSettings?) -> String {
        guard let reminder, reminder.enabled else { return "No reminder set" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = DateComponents()
        components.year = 2024; components.month = 1; components.day = 7
        components.hour = reminder.hour; components.minute = reminder.minute
        let time = DateFormatter()
        time.locale = Locale.current
        time.timeZone = timeZone
        time.dateFormat = DateFormatter.dateFormat(fromTemplate: "j:mm", options: 0, locale: Locale.current)
        let timeText = time.string(from: calendar.date(from: components) ?? currentDate)
        guard reminder.frequency == "weekly" else { return "Every day at \(timeText)" }
        components.day = 6 + reminder.weekday
        components.hour = 12
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale.current
        weekdayFormatter.timeZone = timeZone
        weekdayFormatter.dateFormat = "EEEE"
        let weekday = weekdayFormatter.string(from: calendar.date(from: components) ?? currentDate)
        return "Every \(weekday) at \(timeText)"
    }

    private func javascriptTrim(_ value: String) -> String {
        let trim: Set<UInt32> = [0x0009,0x000A,0x000B,0x000C,0x000D,0x0020,0x00A0,0x1680,0x2000,0x2001,0x2002,0x2003,0x2004,0x2005,0x2006,0x2007,0x2008,0x2009,0x200A,0x2028,0x2029,0x202F,0x205F,0x3000,0xFEFF]
        let scalars = Array(value.unicodeScalars)
        var start = 0
        var end = scalars.count
        while start < end && trim.contains(scalars[start].value) { start += 1 }
        while end > start && trim.contains(scalars[end - 1].value) { end -= 1 }
        return String(String.UnicodeScalarView(scalars[start..<end]))
    }
}

private struct NovenaLibraryPage<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PRAYER LIBRARY")
                        .font(JohnTypography.sans(12, weight: .semibold))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-SemiBold", size: 12, targetLineHeight: 18))
                        .tracking(1.8)
                        .foregroundStyle(colors.tint)
                    Text("Prayer")
                        .font(JohnTypography.sans(36, weight: .bold))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Bold", size: 36, targetLineHeight: 44))
                        .foregroundStyle(colors.text)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("page-title-pray")
                    Text("Everyday prayer, the Rosary, and Catholic novenas. A little space to be with God.")
                        .font(JohnTypography.sans(16))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 16, targetLineHeight: 24))
                        .foregroundStyle(colors.textDim)
                }
                content
            }
            .frame(maxWidth: 740, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(colors.background)
    }
}

private struct NovenaEmptyPanel<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.card, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct NovenaLibraryCard: View {
    let item: NovenaCatalogItem
    let progress: NovenaProgress
    let emphasized: Bool
    var onPress: () -> Void

    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var completeDays: Set<Int> { Set(progress.completedDays) }

    var body: some View {
        Button(action: onPress) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 16) {
                    ContentArtwork(name: artworkName(item.id))
                        .scaledToFill()
                        .frame(width: 76, height: 92)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(JohnTypography.sans(20, weight: .medium))
                            .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Medium", size: 20, targetLineHeight: 32))
                            .foregroundStyle(colors.text)
                        Text(item.subtitle)
                            .font(JohnTypography.sans(14))
                            .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 14, targetLineHeight: 21))
                            .foregroundStyle(colors.textDim)
                        Text("Patronage · \(item.patronage)")
                            .font(JohnTypography.sans(12))
                            .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 12, targetLineHeight: 18))
                            .foregroundStyle(colors.textDim)
                            .padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                    RowChevron(color: colors.tint)
                        .padding(.top, 2)
                }
                HStack(spacing: 8) {
                    ForEach(1...9, id: \.self) { day in
                        Circle()
                            .fill(completeDays.contains(day) ? colors.tint : colors.background)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(completeDays.contains(day) ? colors.tint : colors.border, lineWidth: 1))
                    }
                }
                HStack(spacing: 12) {
                    Text(progress.completedDays.isEmpty ? "Ready to begin" : "\(progress.completedDays.count) of 9 prayed")
                        .font(JohnTypography.sans(12, weight: .semibold))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-SemiBold", size: 12, targetLineHeight: 18))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(colors.tint)
                    Spacer(minLength: 0)
                    if let feastDay = item.feastDay {
                        Text("Feast \(feastDay)")
                            .font(JohnTypography.sans(12))
                            .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 12, targetLineHeight: 18))
                            .foregroundStyle(colors.textDim)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 176, alignment: .leading)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(colors.border, lineWidth: 1)
            }
            .overlay(alignment: .top) {
                if emphasized {
                    Rectangle().fill(colors.tint).frame(height: 1)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
        .buttonStyle(NovenaCardButtonStyle(colors: colors))
        .accessibilityLabel("\(item.title). \(item.subtitle). \(progress.completedDays.count) of 9 days prayed.")
    }

    private func artworkName(_ id: String) -> String {
        let saints: Set<String> = ["st-padre-pio", "st-jude", "st-peregrine", "st-joseph", "st-therese",
            "st-anthony", "st-anne", "st-monica", "st-benedict", "st-francis-assisi"]
        if saints.contains(id) { return id }
        if id == "holy-spirit" { return "glorious-3" }
        if id == "assumption" { return "glorious-4" }
        if ["sacred-heart", "divine-mercy", "christ-the-king"].contains(id) { return "glorious-1" }
        if id.contains("lady") || ["miraculous-medal", "immaculate-conception"].contains(id) { return "mary" }
        return "prayer"
    }
}

private struct NovenaCardButtonStyle: ButtonStyle {
    let colors: JohnColors
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? colors.background : colors.card,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(colors.border, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}
