import WidgetKit
import SwiftUI
import JohnCore

private struct VerseEntry: TimelineEntry, Sendable {
    let date: Date
    let verse: RotatingVerse?
}

private struct VerseProvider: TimelineProvider, Sendable {
    func placeholder(in context: Context) -> VerseEntry { VerseEntry(date: .now, verse: nil) }
    func getSnapshot(in context: Context, completion: @escaping @Sendable (VerseEntry) -> Void) {
        Task { completion(await loadEntry()) }
    }
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<VerseEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            let next = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date.addingTimeInterval(1800)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
    private func loadEntry() async -> VerseEntry {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("Widget", isDirectory: true) else { return VerseEntry(date: .now, verse: nil) }
        let roots = ResourceRoots(app: root, widget: root)
        let repository = IndexedRotationRepository(roots: roots, resourceRoot: .widget)
        let time = Date.now
        do {
            let count = try await repository.poolCount(translation: .webCE, scope: .full)
            let slot = try RotationMath.slot(at: time, utcOffsetSeconds: TimeZone.current.secondsFromGMT(for: time), intervalMinutes: 30)
            let index = try RotationMath.index(for: slot, count: count)
            return VerseEntry(date: time, verse: try await repository.verse(translation: .webCE, scope: .full, at: index))
        } catch { return VerseEntry(date: time, verse: nil) }
    }
}

private struct VerseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VerseEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A WORD TO CARRY WITH YOU").font(.caption2.weight(.medium)).tracking(1.4)
            if let verse = entry.verse {
                Text(verse.text).font(.system(size: family == .systemSmall ? 15 : 18, weight: .regular, design: .serif)).lineLimit(family == .systemSmall ? 4 : 5)
                Text(verse.reference).font(.caption)
            } else {
                Text("Open John 1:1 to begin.").font(.system(.body, design: .serif))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(Color(red: 0.965, green: 0.949, blue: 0.918), for: .widget)
        .widgetURL(URL(string: "nrsv://read?book=JHN&chapter=1&verse=1"))
    }
}

private struct VerseWidget: Widget {
    let kind = "VerseWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseProvider()) { VerseWidgetView(entry: $0) }
            .configurationDisplayName("Daily Verse")
            .description("A rotating Scripture verse, refreshed throughout the day.")
            .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular, .systemSmall, .systemMedium])
    }
}

private struct VerseTimerWidget: Widget {
    let kind = "VerseTimerWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseProvider()) { VerseWidgetView(entry: $0) }
            .configurationDisplayName("Verse Countdown")
            .description("A live timer counting down to the next verse.")
            .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular, .systemSmall])
    }
}

private struct DailyReadingWidget: Widget {
    let kind = "DailyReadingWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseProvider()) { VerseWidgetView(entry: $0) }
            .configurationDisplayName("Daily Reading")
            .description("Today’s Gospel preview, changing each day. United States Catholic calendar; tap for all readings.")
            .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemSmall, .systemMedium])
    }
}

@main struct JohnWidgetBundle: WidgetBundle {
    var body: some Widget { VerseWidget(); DailyReadingWidget(); VerseTimerWidget() }
}
