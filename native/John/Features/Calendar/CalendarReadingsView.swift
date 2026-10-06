import SwiftUI
import UIKit
import JohnCore

struct CalendarReadingsView: View {
    let sunday: Bool
    let initialDateKey: String?
    let onNavigate: (CompanionRoute) -> Void
    let onClose: () -> Void
    let clock: () -> Date
    let timeZone: TimeZone

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @State private var day: Date
    @State private var readingsCalendar: ReadingsCalendar?
    @State private var celebrationsCalendar: CelebrationsCalendar?
    @State private var loadFailed = false
    @State private var before = ""
    @State private var after = ""
    @State private var feedback = ""
    @State private var saving = false

    init(sunday: Bool, initialDateKey: String? = nil,
         timeZone: TimeZone = .autoupdatingCurrent, clock: @escaping () -> Date = Date.init,
         onNavigate: @escaping (CompanionRoute) -> Void, onClose: @escaping () -> Void) {
        self.sunday = sunday
        self.initialDateKey = initialDateKey
        self.timeZone = timeZone
        self.clock = clock
        self.onNavigate = onNavigate
        self.onClose = onClose
        let current = clock()
        let fallback = sunday ? CompanionCalendar.upcomingSunday(current, timeZone: timeZone) : current
        _day = State(initialValue: CompanionCalendar.parseDate(initialDateKey, fallback: fallback, timeZone: timeZone))
    }

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var key: String { CompanionCalendar.dateKey(day, timeZone: timeZone) }
    private var readingEntry: CalendarReadingsEntry? {
        guard let readingsCalendar else { return nil }
        return CompanionCalendar.readings(for: day, from: readingsCalendar, timeZone: timeZone)
    }
    private var celebration: CalendarCelebration? {
        guard let celebrationsCalendar else { return nil }
        return CompanionCalendar.celebration(for: day, from: celebrationsCalendar, timeZone: timeZone)
    }
    private var season: String { CompanionCalendar.season(day, timeZone: timeZone) }
    private var title: String {
        TodaySelectors.title(readings: readingEntry, celebration: celebration, season: season)
    }

    var body: some View {
        ContentPage(title: sunday ? "Come ready for Sunday" : "Today’s readings",
                    eyebrow: "\(CompanionCalendar.label) / \(CompanionCalendar.seasonNames[season] ?? season)",
                    subtitle: nil, onClose: onClose) {
            HStack(spacing: 12) {
                ContentButton(title: "Previous", expandsToFill: false) { move(sunday ? -7 : -1) }
                Spacer(minLength: 0)
                Text(formattedDate(day, format: "MMM d, yyyy"))
                    .font(JohnTypography.sans(16, weight: .medium))
                    .foregroundStyle(colors.text)
                Spacer(minLength: 0)
                ContentButton(title: "Next", expandsToFill: false) { move(sunday ? 7 : 1) }
            }

            ContentArtCard(artwork: artworkName(season), title: title,
                           subtitle: formattedDate(day, format: "EEEE, MMMM d")) {
                openOfficialReadings()
            }
            ContentMutedText(text: "USCCB reading selections. Transferred feasts and optional celebrations may differ at your parish.")

            ContentPanel {
                ContentSectionTitle(title: "Listen to the Word",
                    detail: "Open each reading in its biblical context. Scripture uses the offline WEB-CE edition; wording and verse divisions may differ from those proclaimed at Mass.")
                if let readingEntry {
                    ForEach(Array(readingEntry.readings.enumerated()), id: \.offset) { _, reading in
                        ContentActionRow(title: reading.reference, subtitle: reading.label) {
                            onNavigate(.citationContext(reference: reading.reference))
                        }
                    }
                } else if loadFailed {
                    ContentMutedText(text: "The readings are not available right now.")
                } else {
                    ContentMutedText(text: "Reading references for this date aren’t in your offline library. Open the official readings when you’re connected.")
                }
                ContentButton(title: "Official readings ↗") { openOfficialReadings() }
            }

            if sunday {
                ContentPanel {
                    ContentSectionTitle(title: "Read them together")
                    Text(connection(for: readingEntry?.readings.first(where: { $0.label == "Gospel" })?.reference ?? ""))
                        .font(JohnTypography.sans(17))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 17, targetLineHeight: 28))
                        .foregroundStyle(colors.text)
                    ContentMutedText(text: "A reading guide from John 1:1")
                }
                reflectionPanel
            }

            if !feedback.isEmpty {
                Text(feedback)
                    .font(JohnTypography.sans(16))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 16, targetLineHeight: 24))
                    .foregroundStyle(colors.textDim)
                    .contentAnnouncement(feedback)
            }
        }
        .id(key)
        .task(id: key) { await loadCalendarsAndReflection() }
        .task(id: "\(sunday)|\(initialDateKey ?? "")") { resetInitialDate() }
    }

    private var reflectionPanel: some View {
        ContentPanel {
            ContentSectionTitle(title: "Before Mass", detail: "What word, question, or intention will you bring with you?")
            ContentInputField(placeholder: "Something I want to carry into Mass…", text: $before,
                              accessibilityLabel: "Before Mass reflection", multiline: true)
                .onChange(of: before) { _, _ in feedback = "" }
            ContentSectionTitle(title: "After Mass", detail: "Return to the same Sunday to remember what you heard and how you want to respond.")
            ContentInputField(placeholder: "A word to remember. A step to take…", text: $after,
                              accessibilityLabel: "After Mass reflection", multiline: true)
                .onChange(of: after) { _, _ in feedback = "" }
            ContentEmphasisButton(title: saving ? "Saving…" : "Save reflection") { saveReflection() }
                .disabled(saving)
            ContentMutedText(text: "Saved only when you choose. Reflections are kept on this device.")
        }
    }

    @MainActor private func loadCalendarsAndReflection() async {
        feedback = ""
        before = runtime.committedNativeState?.reflections[key]?.before ?? ""
        after = runtime.committedNativeState?.reflections[key]?.after ?? ""
        guard let repository = runtime.companionRepository else {
            loadFailed = true
            return
        }
        do {
            async let readings = repository.readings()
            async let celebrations = repository.celebrations()
            readingsCalendar = try await readings
            celebrationsCalendar = try await celebrations
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    @MainActor private func saveReflection() {
        guard !saving else { return }
        let savedKey = key
        let savedBefore = before
        let savedAfter = after
        saving = true
        feedback = ""
        Task { @MainActor in
            let saved = await runtime.applyWithResult(
                .setReflection(date: savedKey, value: SundayReflection(before: savedBefore, after: savedAfter))
            )
            if key == savedKey, before == savedBefore, after == savedAfter {
                feedback = saved ? "Reflection saved on this device." : "Could not save. Please try again."
            }
            saving = false
        }
    }

    private func resetInitialDate() {
        let fallback = clock()
        let parseFallback = sunday ? CompanionCalendar.upcomingSunday(fallback, timeZone: timeZone) : fallback
        day = CompanionCalendar.parseDate(initialDateKey, fallback: parseFallback, timeZone: timeZone)
    }

    private func move(_ amount: Int) {
        day = CompanionCalendar.addDays(day, amount, timeZone: timeZone)
        feedback = ""
    }

    private func openOfficialReadings() {
        guard let url = URL(string: CompanionCalendar.readingsURL(day, timeZone: timeZone)) else { return }
        openURL(url) { accepted in
            if !accepted { feedback = "The readings website could not be opened. Please try again when connected." }
        }
    }

    private func formattedDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = CompanionCalendar.gregorianCalendar(timeZone: timeZone)
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    private func artworkName(_ season: String) -> String {
        switch season {
        case "advent": "advent"
        case "christmas": "joyful-3"
        case "lent": "sorrowful-1"
        case "triduum": "sorrowful-5"
        case "easter": "glorious-1"
        default: "scripture"
        }
    }

    private func connection(for gospel: String) -> String {
        if gospel.range(of: #"Matthew 18:21"#, options: .regularExpression) != nil {
            return "Sirach asks us to set anger aside, and Jesus’ parable presses the question further: can we receive mercy while refusing it to another? Paul reminds us that we belong to the Lord. Read with this question in mind: where is God inviting me to let mercy shape a relationship?"
        }
        if gospel.range(of: #"Luke 15:"#, options: .regularExpression) != nil {
            return "Watch who is lost, who searches, and who rejoices in this Gospel. Then return to the first reading and the psalm: what do they reveal about God’s patience and mercy? Let your prayer include someone who longs for a welcome home."
        }
        if gospel.range(of: #"John 6:"#, options: .regularExpression) != nil {
            return "Listen for what Jesus says about hunger, life, and the gift of himself. Read the first reading beside the Gospel and notice images of food or God’s provision. Bring your own hunger to Christ as you prepare for the Eucharist."
        }
        return "Begin with the Gospel: what does Jesus reveal about God, and what response does he invite? Read the first reading alongside it and look for a shared image, promise, or question. Let the psalm become your reply in prayer. Then notice how the second reading speaks to the way a Christian community lives. You do not need to force every reading into a single theme."
    }
}

struct ContentArtCard: View {
    let artwork: String
    let title: String
    let subtitle: String
    var action: () -> Void
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ContentArtwork(name: artwork)
                    .aspectRatio(2, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(JohnTypography.serif(23))
                            .lineSpacing(ContentTypography.additionalSpacing(fontName: "Lora-Regular", size: 23, targetLineHeight: 31))
                            .foregroundStyle(colors.text)
                        Text(subtitle)
                            .font(JohnTypography.sans(14))
                            .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 14, targetLineHeight: 21))
                            .foregroundStyle(colors.textDim)
                    }
                    Spacer(minLength: 0)
                    FeatherIcon(name: "arrow-up-right", size: 21, color: colors.tint)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.card)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(ContentArtCardButtonStyle())
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

private struct ContentArtCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct ContentArtwork: View {
    let name: String
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        if let root = Bundle.main.resourceURL?.appendingPathComponent("App/Artwork/\(name).jpg"),
           let image = UIImage(contentsOfFile: root.path) {
            Image(uiImage: image).resizable()
        } else {
            Rectangle().fill(preferences.colors(for: colorScheme).card)
        }
    }
}

struct ContentInputField: View {
    let placeholder: String
    @Binding var text: String
    let accessibilityLabel: String
    var multiline = false
    var inputAppearance: ContentInputAppearance = .standard
    var disablesCorrection = false
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        Group {
            if multiline {
                TextEditor(text: $text)
                    .autocorrectionDisabled(disablesCorrection)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(JohnTypography.sans(16))
                                .foregroundStyle(colors.textDim)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
            } else {
                TextField(placeholder, text: $text)
                    .autocorrectionDisabled(disablesCorrection)
                    .frame(minHeight: 24)
            }
        }
        .font(JohnTypography.sans(16))
        .foregroundStyle(colors.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: inputAppearance == .novenaSearch ? 52 : (multiline ? 156 : 40))
        .background(inputAppearance == .novenaSearch ? colors.card : colors.background,
                    in: RoundedRectangle(cornerRadius: inputAppearance == .novenaSearch ? 14 : (inputAppearance == .novenaIntention ? 10 : 4)))
        .overlay(RoundedRectangle(cornerRadius: inputAppearance == .novenaSearch ? 14 : (inputAppearance == .novenaIntention ? 10 : 4))
            .stroke(colors.border, lineWidth: 1))
        .accessibilityLabel(accessibilityLabel)
    }
}

enum ContentInputAppearance: Equatable {
    case standard
    case novenaSearch
    case novenaIntention
}
