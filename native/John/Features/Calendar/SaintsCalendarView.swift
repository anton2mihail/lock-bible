import SwiftUI
import JohnCore

struct SaintsCalendarView: View {
    @Environment(JohnRuntime.self) private var runtime
    @State private var day = Date()
    @State private var query = ""
    @State private var tradition = "vatican"
    @State private var catalogs: [SaintsCalendar] = []
    @State private var failed = false

    private var catalog: SaintsCalendar? { catalogs.first { $0.tradition == tradition } }
    private var results: [SaintCommemoration] {
        guard let catalog else { return [] }
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return search.isEmpty
            ? catalog.entries(on: day, timeZone: runtime.featureTimeZone)
            : catalog.entries.filter { $0.name.localizedStandardContains(search) }
    }

    var body: some View {
        ContentPage(title: "Saints & feast days", eyebrow: "The communion of saints",
                    subtitle: "Discover the witnesses of faith, day by day.") {
            Picker("Calendar", selection: $tradition) {
                Text("Vatican News").tag("vatican")
                Text("Byzantine Catholic").tag("byzantine")
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("saints-calendar-choice")
            ContentInputField(placeholder: "Find a saint across the year", text: $query,
                              accessibilityLabel: "Find a saint")
            DatePicker("Commemoration date", selection: $day, displayedComponents: .date)
                .environment(\.calendar, CompanionCalendar.gregorianCalendar(timeZone: runtime.featureTimeZone))
                .environment(\.timeZone, runtime.featureTimeZone)
                .accessibilityIdentifier("saints-date")
            if let catalog {
                ContentMutedText(text: catalog.coverage)
                if results.isEmpty {
                    ContentMutedText(text: query.isEmpty
                        ? "This source has no entry for this date."
                        : "No saints match this name. Try another name.")
                }
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(results) { saint in
                        SaintLifeCard(saint: saint, sourceName: catalog.sourceName, showDate: true)
                    }
                }
                ContentMutedText(text: "Source checked \(catalog.retrievedOn). Accounts use short excerpts or English summaries. Summaries are not official translations. Open the source for the full account.")
            } else if failed {
                ContentMutedText(text: "The saints calendar could not be loaded.")
                ContentButton(title: "Try again") { Task { await load() } }
            } else {
                ProgressView()
            }
        }
        .task {
            day = runtime.featureNow()
            await load()
        }
    }

    private func load() async {
        failed = false
        do {
            guard let repository = runtime.companionRepository else {
                throw CoreError.missingResource("saints calendars")
            }
            catalogs = try await repository.saintsCalendars()
        } catch { failed = true }
    }
}

struct SaintsDaySection: View {
    let day: Date
    let timeZone: TimeZone
    let onBrowse: () -> Void
    @Environment(JohnRuntime.self) private var runtime
    @State private var catalogs: [SaintsCalendar] = []
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ContentSectionTitle(title: "Saints remembered today",
                                detail: "Annual commemorations from Vatican News and the Ruthenian Byzantine Catholic calendar.")
            ForEach(catalogs, id: \.tradition) { catalog in
                ContentSectionTitle(title: catalog.title)
                let entries = catalog.entries(on: day, timeZone: timeZone)
                if entries.isEmpty {
                    ContentMutedText(text: "This source has no entry for this date.")
                }
                ForEach(entries) { saint in
                    SaintLifeCard(saint: saint, sourceName: catalog.sourceName, showDate: false)
                }
            }
            if failed { ContentMutedText(text: "The saints calendar could not be loaded. Open the calendar to try again.") }
            ContentActionRow(title: "Browse saints & feast days", subtitle: "Choose a date or search by name", onPress: onBrowse)
        }
        .task {
            do {
                guard let repository = runtime.companionRepository else {
                    throw CoreError.missingResource("saints calendars")
                }
                catalogs = try await repository.saintsCalendars()
            } catch { failed = true }
        }
    }
}

private struct SaintLifeCard: View {
    let saint: SaintCommemoration
    let sourceName: String
    let showDate: Bool
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @State private var personalID: String?
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    private var dateLabel: String {
        let date = CompanionCalendar.parseDate("2024-\(saint.monthDay)", fallback: Date(), timeZone: .gmt)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .gmt
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: date)
    }

    var body: some View {
        ContentPanel {
            if showDate { ContentMutedText(text: dateLabel) }
            Text(saint.name)
                .font(JohnTypography.serif(24)).foregroundStyle(colors.text)
                .fixedSize(horizontal: false, vertical: true)
            if let summary = saint.summary, !summary.isEmpty {
                Text(summary)
                    .font(JohnTypography.sans(16)).foregroundStyle(colors.text)
                    .textSelection(.enabled)
                ContentMutedText(text: summaryLabel)
            } else if !saint.excerpt.isEmpty {
                Text("“\(saint.excerpt)”")
                    .font(JohnTypography.sans(16)).foregroundStyle(colors.text)
                    .textSelection(.enabled)
            } else {
                ContentMutedText(text: "The source lists this commemoration without a short life account.")
            }
            if let personalID {
                ContentButton(title: "Open personal saint page") { router.push(.companion(.saint(id: personalID))) }
            }
            if let note = saint.observanceNote { ContentMutedText(text: note) }
            if let url = URL(string: saint.sourceURL) {
                Link("Read at \(url.host == "www.vatican.va" ? "The Holy See" : sourceName) ↗", destination: url)
                    .font(JohnTypography.sans(14, weight: .medium))
                    .foregroundStyle(colors.tint)
                    .frame(minHeight: 44, alignment: .leading)
            }
            if saint.sourceURL != saint.calendarURL, let url = URL(string: saint.calendarURL) {
                Link("View calendar entry ↗", destination: url)
                    .font(JohnTypography.sans(14)).foregroundStyle(colors.tint)
                    .frame(minHeight: 44, alignment: .leading)
            }
        }.task(id: saint.id) {
            personalID = (try? await runtime.companionRepository?.personalSaints())?.first { profile in
                profile.commemorations.contains { $0.entryID == saint.id }
            }?.id
        }
    }

    private var summaryLabel: String {
        switch saint.sourceLanguage {
        case "it": "English summary · Italian Vatican source"
        case "de": "English summary · German Vatican source"
        default: "English summary · English Vatican source"
        }
    }
}
