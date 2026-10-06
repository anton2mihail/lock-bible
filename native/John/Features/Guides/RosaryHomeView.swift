import SwiftUI
import JohnCore

struct RosaryHomeView: View {
    let onClose: () -> Void
    let onOpenGuide: (String) -> Void
    let onOpenReminder: () -> Void
    let onOpenMedia: (String) -> Void
    let clock: () -> Date
    let timeZone: TimeZone

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @State private var catalog: RosaryHomeCatalog?
    @State private var loadFailed = false

    init(clock: @escaping () -> Date = Date.init,
         timeZone: TimeZone = .autoupdatingCurrent,
         onClose: @escaping () -> Void,
         onOpenGuide: @escaping (String) -> Void,
         onOpenReminder: @escaping () -> Void,
         onOpenMedia: @escaping (String) -> Void = { _ in }) {
        self.clock = clock
        self.timeZone = timeZone
        self.onClose = onClose
        self.onOpenGuide = onOpenGuide
        self.onOpenReminder = onOpenReminder
        self.onOpenMedia = onOpenMedia
    }

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var suggestedID: String { TodaySelectors.rosaryWeekdaySet(date: clock(), timeZone: timeZone) }
    private var suggestedSet: RosaryMysterySet? { catalog?.mysterySets.first { $0.id == suggestedID } }
    private var reminder: RosaryReminderSettings { runtime.committedNativeState?.rosaryReminder ?? RosaryReminderSettings() }
    private var reminderText: String { reminderSummary(reminder) }

    var body: some View {
        RosaryHomePage(onClose: onClose) {
            if let catalog, let suggestedSet {
                ContentArtwork(name: "mary")
                    .scaledToFill()
                    .aspectRatio(1.7, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("THE MOST HOLY ROSARY")
                        .font(JohnTypography.sans(12, weight: .semibold))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(colors.tint)
                    Text("Pray the Rosary")
                        .font(JohnTypography.sans(36, weight: .bold))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Bold", size: 36, targetLineHeight: 44))
                        .foregroundStyle(colors.text)
                        .accessibilityAddTraits(.isHeader)
                    Text("A quiet, step-by-step meditation on the life of Christ with Mary. The complete prayer guide works offline.")
                        .font(JohnTypography.sans(16))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 16, targetLineHeight: 24))
                        .foregroundStyle(colors.textDim)
                }

                featured(set: suggestedSet)

                Button(action: onOpenReminder) {
                    HStack(spacing: 16) {
                        Text("◷")
                            .font(JohnTypography.sans(20))
                            .foregroundStyle(colors.tint)
                            .frame(width: 48, height: 48)
                            .background(colors.background, in: RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rosary reminder")
                                .font(JohnTypography.sans(16, weight: .semibold))
                                .foregroundStyle(colors.text)
                            Text(reminderText)
                                .font(JohnTypography.sans(14))
                                .foregroundStyle(colors.textDim)
                            ContentMutedText(text: "Scheduled privately on this device")
                        }
                        Spacer(minLength: 0)
                        Text("›").font(JohnTypography.sans(24)).foregroundStyle(colors.tint)
                    }
                    .padding(16)
                    .frame(minHeight: 96)
                    .background(colors.card, in: RoundedRectangle(cornerRadius: 18))
                    .contentShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(RosaryHomePressStyle())
                .accessibilityLabel("Rosary reminder. \(reminderText)")

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        ContentSectionTitle(title: "Choose a mystery")
                        ContentMutedText(text: "Sundays vary by liturgical season")
                    }
                    ForEach(catalog.mysterySets, id: \.id) { set in
                        setCard(title: set.title, subtitle: set.customaryDays,
                                detail: set.description,
                                artwork: coverName(set.id)) {
                            onOpenGuide(set.id)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        ContentSectionTitle(title: "Our Lady of Sorrows")
                        ContentMutedText(text: "A second, older way of praying with Mary")
                    }
                    setCard(title: catalog.sevenSorrows.title,
                            subtitle: catalog.sevenSorrows.customaryDays,
                            detail: catalog.sevenSorrows.description,
                            artwork: "sorrows-6") {
                        onOpenGuide(catalog.sevenSorrows.id)
                    }
                    ContentMutedText(text: "Seven sorrows · one Our Father and seven Hail Marys each · about 15 minutes")
                }

                mediaSection(catalog: catalog, set: suggestedSet)
            } else if loadFailed {
                ContentMutedText(text: "The Rosary catalog is not available right now.")
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            }
        }
        .task { await loadCatalog() }
    }

    private func featured(set: RosaryMysterySet) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SUGGESTED TODAY")
                        .font(JohnTypography.sans(12, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(colors.tint)
                    Text(set.title)
                        .font(JohnTypography.sans(20, weight: .medium))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Medium", size: 20, targetLineHeight: 32))
                        .foregroundStyle(colors.text)
                    Text(set.customaryDays)
                        .font(JohnTypography.sans(14))
                        .foregroundStyle(colors.textDim)
                }
                Spacer(minLength: 0)
                Text("✢")
                    .font(JohnTypography.sans(24))
                    .foregroundStyle(colors.tint)
                    .frame(width: 52, height: 52)
                    .background(colors.background, in: Circle())
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(set.mysteries.enumerated()), id: \.offset) { index, mystery in
                    HStack(spacing: 12) {
                        Text(String(index + 1))
                            .font(JohnTypography.sans(12, weight: .semibold))
                            .foregroundStyle(colors.textDim)
                            .frame(width: 28, height: 28)
                            .overlay(Circle().stroke(colors.border, lineWidth: 1))
                        Text(mystery.title)
                            .font(JohnTypography.sans(14))
                            .foregroundStyle(colors.text)
                    }
                }
            }
            ContentEmphasisButton(title: "Begin today’s Rosary") { onOpenGuide(set.id) }
        }
        .padding(24)
        .background(colors.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(colors.border, lineWidth: 1))
    }

    private func setCard(title: String, subtitle: String, detail: String, artwork: String,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                ContentArtwork(name: artwork)
                    .scaledToFill()
                    .frame(width: 72, height: 84)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(JohnTypography.sans(16, weight: .semibold)).foregroundStyle(colors.text)
                    Text(subtitle).font(JohnTypography.sans(12, weight: .semibold)).foregroundStyle(colors.tint)
                    Text(detail).font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
                }
                Spacer(minLength: 0)
                Text("›").font(JohnTypography.sans(24)).foregroundStyle(colors.tint)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(colors.card, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(colors.border, lineWidth: 1))
        }
        .buttonStyle(RosaryHomePressStyle())
        .accessibilityLabel("\(title). \(subtitle). \(detail)")
    }

    private func mediaSection(catalog: RosaryHomeCatalog, set: RosaryMysterySet) -> some View {
        let episode = catalog.mediaEpisodes.first { $0.id == set.id }
        // No approved local media is in the source catalog. Use the official URL.
        let hasApprovedMedia = episode.map { !($0.videoUri ?? "").isEmpty || !($0.audioUri ?? "").isEmpty } ?? false
        let playerGate = _isDebugAssertConfiguration() || hasApprovedMedia
        return VStack(alignment: .leading, spacing: 16) {
            ContentSectionTitle(title: "The Rosary with Bishop Barron",
                                detail: "Watch the Rosary on Word on Fire’s official channels. An internet connection is needed.")
            Button {
                if playerGate, let episode {
                    onOpenMedia(episode.id)
                } else if let url = URL(string: episode?.officialUrl ?? "https://www.wordonfire.org/rosary/") {
                    openURL(url)
                }
            } label: {
                HStack(spacing: 16) {
                    Text("▶").font(JohnTypography.sans(16)).foregroundStyle(colors.card)
                        .frame(width: 46, height: 46).background(colors.tint, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(set.shortTitle) Mysteries")
                            .font(JohnTypography.sans(16, weight: .semibold)).foregroundStyle(colors.card)
                        Text(playerGate ? "Bishop Robert Barron · Word on Fire" : "Bishop Robert Barron · opens on YouTube")
                            .font(JohnTypography.sans(14)).foregroundStyle(colors.separator)
                    }
                    Spacer(minLength: 0)
                    Text("↗").font(JohnTypography.sans(24)).foregroundStyle(colors.tint)
                }
                .padding(16)
                .frame(minHeight: 88)
                .background(colors.text, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(RosaryHomePressStyle())
            if playerGate {
                ContentMutedText(text: "\(catalog.mediaEpisodes.count) episodes catalogued from the official series")
            } else {
                Link("More from the series at wordonfire.org ↗", destination: URL(string: "https://www.wordonfire.org/rosary/")!)
                    .font(JohnTypography.sans(12))
                    .foregroundStyle(colors.tint)
            }
        }
    }

    private func coverName(_ set: String) -> String {
        switch set {
        case "joyful": "joyful-3"
        case "sorrowful": "sorrowful-1"
        case "glorious": "glorious-1"
        default: "luminous-5"
        }
    }

    private func reminderSummary(_ value: RosaryReminderSettings) -> String {
        guard value.enabled else { return "No reminder set" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var parts = DateComponents(); parts.year = 2024; parts.month = 1; parts.day = 7
        parts.hour = value.hour; parts.minute = value.minute
        let formatter = DateFormatter(); formatter.locale = .current; formatter.timeZone = timeZone
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "j:mm", options: 0, locale: .current)
        let time = formatter.string(from: calendar.date(from: parts) ?? clock())
        guard value.frequency == "weekly" else { return "Every day at \(time)" }
        parts.day = 6 + value.weekday; parts.hour = 12
        let weekday = DateFormatter(); weekday.locale = .current; weekday.timeZone = timeZone; weekday.dateFormat = "EEEE"
        return "Every \(weekday.string(from: calendar.date(from: parts) ?? clock())) at \(time)"
    }

    @MainActor private func loadCatalog() async {
        guard let repository = runtime.companionRepository else { loadFailed = true; return }
        do {
            let catalog = try await repository.devotionalCatalog()
            self.catalog = try RosaryCatalogAdapter.decode(catalog.rosary)
        } catch { loadFailed = true }
    }
}

private struct RosaryHomePage<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder var content: Content
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button(action: onClose) {
                    HStack(spacing: 6) {
                        Text("‹").font(JohnTypography.sans(24))
                        Text("Prayer Library").font(JohnTypography.sans(16, weight: .semibold))
                    }.foregroundStyle(colors.tint).frame(minHeight: 40).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to prayer library")
                content
            }
            .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 48)
        }
        .background(colors.background)
    }
}

private struct RosaryHomePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}
