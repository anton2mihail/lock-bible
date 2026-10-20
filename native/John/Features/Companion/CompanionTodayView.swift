import SwiftUI
import JohnCore

struct CompanionTodayView: View {
    let onNavigate: (CompanionRoute) -> Void
    let onOpenVerseMoment: (RotatingVerse) -> Void
    let clock: () -> Date
    let fixedTimeZone: TimeZone?

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var snapshot: CompanionTodaySnapshot?
    @State private var message: String?
    @State private var now: Date

    init(clock: @escaping () -> Date = Date.init, fixedTimeZone: TimeZone? = nil,
         onNavigate: @escaping (CompanionRoute) -> Void,
         onOpenVerseMoment: @escaping (RotatingVerse) -> Void) {
        self.clock = clock
        self.fixedTimeZone = fixedTimeZone
        self.onNavigate = onNavigate
        self.onOpenVerseMoment = onOpenVerseMoment
        _now = State(initialValue: clock())
    }

    private var timeZone: TimeZone { fixedTimeZone ?? TimeZone.current }
    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var dateKey: String { CompanionCalendar.dateKey(now, timeZone: timeZone) }
    private var prayer: (id: String, title: String, subtitle: String) {
        TodaySelectors.prayer(date: now, timeZone: timeZone)
    }

    var body: some View {
        ContentPage(title: "A little closer to God.",
                    eyebrow: "JOHN 1:1  /  \(formattedDate(now, "EEEE, MMMM d"))",
                    subtitle: "Scripture for your day. Space for your soul.",
                    meshBackground: true) {
            // Keep the launch smoke-test anchor on the source page title.
            if let snapshot {
                ContentArtCard(artwork: artworkName(snapshot.season),
                               title: TodaySelectors.title(readings: snapshot.readings,
                                                           celebration: snapshot.celebration,
                                                           season: snapshot.season),
                               subtitle: "\(CompanionCalendar.seasonNames[snapshot.season] ?? snapshot.season) · Today’s readings") {
                    onNavigate(.daily(dateKey: dateKey))
                }
                .todayZoomSource(.daily(dateKey: dateKey), cornerRadius: 18)
                ContentMutedText(text: CompanionCalendar.label)
                ContentActionRow(title: "Saints & feast days",
                                 subtitle: "Vatican News · Byzantine Catholic · Lives of the saints") {
                    onNavigate(.saints)
                }
                .accessibilityIdentifier("today-saints")

                MySaintsTodaySection(onNavigate: onNavigate)

                ReadingTodayCard(now: now, timeZone: timeZone)

                VStack(alignment: .leading, spacing: 16) {
                    ContentSectionTitle(title: "Make room for prayer")
                    ContentActionRow(title: "Pray the Rosary", subtitle: mysteryTitle(snapshot.rosarySet),
                                     imageName: "mary") {
                        onNavigate(.rosaryGuide(set: snapshot.rosarySet))
                    }
                    .todayZoomSource(.rosaryGuide(set: snapshot.rosarySet))
                    ContentActionRow(title: prayer.title, subtitle: prayer.subtitle, imageName: "prayer") {
                        onNavigate(.prayer(id: prayer.id))
                    }
                    ForEach(snapshot.ongoingNovenas, id: \.novena.id) { item in
                        ContentActionRow(title: item.novena.title,
                                         subtitle: "Continue with day \(item.firstIncompleteDay)") {
                            onNavigate(.novena(id: item.novena.id))
                        }
                    }
                }

                if let verse = runtime.today.verse {
                    ContentPanel {
                        Text("A WORD TO CARRY WITH YOU")
                            .font(JohnTypography.sans(11, weight: .medium))
                            .tracking(2)
                            .foregroundStyle(colors.tint)
                        Text(verse.text)
                            .font(JohnTypography.serif(24))
                            .lineSpacing(ContentTypography.additionalSpacing(fontName: "Lora-Regular", size: 24, targetLineHeight: 36))
                            .foregroundStyle(colors.text)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("today-verse-card")
                        ContentMutedText(text: "\(verse.reference) · \(verseAbbreviation)")
                        ContentEmphasisButton(title: "Pray with this passage") {
                            openLectio(verse)
                        }
                        ContentActionRow(title: "Verse & lock screen widget",
                                         subtitle: "Read in context, share, or set up your widget") {
                            onOpenVerseMoment(verse)
                        }
                    }
                }

                ContentArtCard(artwork: "scripture", title: "Come ready for Sunday",
                               subtitle: "\(formattedDate(CompanionCalendar.upcomingSunday(now, timeZone: timeZone), "MMMM d")) · Read, reflect, return") {
                    onNavigate(.sunday)
                }
                .todayZoomSource(.sunday, cornerRadius: 18)
                VStack(alignment: .leading, spacing: 0) {
                    ContentActionRow(title: "Explore the Catholic faith",
                                     subtitle: "Scripture alongside the Catechism") {
                        onNavigate(.learn)
                    }
                    ContentActionRow(title: "Prepare for Confession",
                                     subtitle: "The Ten Commandments and the Catechism on Penance") {
                        onNavigate(.confession)
                    }
                }
                ContentMutedText(text: "Your Bible, prayers, and reflections stay close. No account needed.")
            } else if let message {
                ContentMutedText(text: message)
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            }
        }
        .task {
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                await refresh()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refresh() }
        }
        .onChange(of: preferences.translation) { _, _ in Task { await refresh() } }
        .onChange(of: preferences.scope) { _, _ in Task { await refresh() } }
        .onChange(of: preferences.intervalMinutes) { _, _ in Task { await refresh() } }
        .onChange(of: runtime.committedNativeState?.novenaProgress) { _, _ in Task { await refresh() } }
    }

    @MainActor private func refresh() async {
        now = clock()
        await runtime.today.refresh(translation: preferences.translation,
                                    scope: preferences.scope,
                                    intervalMinutes: preferences.intervalMinutes,
                                    at: now,
                                    timeZone: timeZone)
        guard let repository = runtime.companionRepository else {
            message = "Today’s local calendar could not be opened."
            return
        }
        do {
            async let readings = repository.readings()
            async let celebrations = repository.celebrations()
            async let catalog = repository.devotionalCatalog()
            let readingCalendar = try await readings
            let celebrationCalendar = try await celebrations
            let devotionalCatalog = try await catalog
            let progress = runtime.committedNativeState?.novenaProgress ?? [:]
            snapshot = CompanionTodaySnapshot(
                readings: CompanionCalendar.readings(for: now, from: readingCalendar, timeZone: timeZone),
                celebration: CompanionCalendar.celebration(for: now, from: celebrationCalendar, timeZone: timeZone),
                season: CompanionCalendar.season(now, timeZone: timeZone),
                rosarySet: TodaySelectors.rosaryWeekdaySet(date: now, timeZone: timeZone),
                ongoingNovenas: TodaySelectors.ongoingNovenas(catalog: devotionalCatalog, progressByID: progress)
            )
            message = nil
        } catch {
            snapshot = nil
            message = "Today’s local calendar could not be opened."
        }
    }

    private func formattedDate(_ date: Date, _ format: String) -> String {
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

    private func mysteryTitle(_ set: String) -> String {
        switch set {
        case "glorious": "The Glorious Mysteries"
        case "sorrowful": "The Sorrowful Mysteries"
        case "luminous": "The Luminous Mysteries"
        default: "The Joyful Mysteries"
        }
    }

    private var verseAbbreviation: String {
        switch preferences.translation {
        case .webCE: "WEB-CE"
        case .douayRheims: "DRB"
        case .vulgate: "VUL"
        }
    }

    @MainActor private func openLectio(_ verse: RotatingVerse) {
        guard let translation = TranslationID(rawValue: preferences.translation.rawValue) else { return }
        Task { @MainActor in
            if let passage = await runtime.passage(translation: translation, bookCode: verse.bookCode,
                                                  chapter: verse.chapter, startVerse: verse.verseLabel,
                                                  endVerse: verse.verseLabel) {
                onNavigate(.lectio(passage))
            }
        }
    }
}

private struct CompanionTodaySnapshot {
    let readings: CalendarReadingsEntry?
    let celebration: CalendarCelebration?
    let season: String
    let rosarySet: String
    let ongoingNovenas: [TodayNovena]
}

struct ContentEmphasisButton: View {
    let title: String
    var action: () -> Void
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(JohnTypography.sans(16, weight: .medium))
                .foregroundStyle(colors.card)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(colors.text, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(ContentReversedButtonStyle(colors: colors))
    }
}

private struct ContentReversedButtonStyle: ButtonStyle {
    let colors: JohnColors
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? colors.textDim : colors.text,
                                       in: RoundedRectangle(cornerRadius: 4))
    }
}
