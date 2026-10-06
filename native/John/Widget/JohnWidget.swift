import Foundation
import SwiftUI
import WidgetKit
import JohnCore

private enum WidgetSharedState {
    static let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? "group.com.nrsv.verse"
    static let defaultIntervalMinutes = 1_440
    static let defaultTranslation: TranslationID = .webCE
    static let defaultScope: RotationScope = .full

    static func values() -> (interval: Int, translation: TranslationID, scope: RotationScope, abbreviation: String, attribution: String) {
        let defaults = UserDefaults(suiteName: appGroup)
        let rawTranslation = defaults?.string(forKey: "translationId") ?? defaultTranslation.rawValue
        let translation = TranslationID(rawValue: rawTranslation) ?? defaultTranslation
        let rawScope = defaults?.string(forKey: "scope") ?? defaultScope.rawValue
        let scope = RotationScope(rawValue: rawScope) ?? defaultScope
        let interval = defaults?.integer(forKey: "intervalMinutes") ?? 0
        let abbreviation = defaults?.string(forKey: "abbreviation") ?? abbreviation(for: translation)
        let attribution = defaults?.string(forKey: "attribution") ?? ""
        return (interval > 0 ? interval : defaultIntervalMinutes, translation, scope, abbreviation, attribution)
    }

    static func abbreviation(for translation: TranslationID) -> String {
        switch translation {
        case .webCE: "WEB-CE"
        case .douayRheims: "DRB"
        case .vulgate: "VUL"
        }
    }

    #if DEBUG
    /// Step 7 probe. It records what the extension can reach: the group container, the shared defaults, and a file write.
    /// It reads the group only from Info.plist. With no group it records `"appGroup": "missing"` in the log and writes nothing.
    static func recordProbe(kind: String) {
        let time = ISO8601DateFormatter().string(from: Date())
        guard let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String, !group.isEmpty else {
            NSLog("John widget probe kind=%@ time=%@ appGroup=missing", kind, time)
            return
        }
        let defaults = UserDefaults(suiteName: group)
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        var record: [String: String] = [
            "kind": kind, "time": time, "appGroup": group,
            "defaultsAvailable": defaults == nil ? "false" : "true",
            "containerPath": container?.path ?? "nil",
            "translationId": defaults?.string(forKey: "translationId") ?? "nil",
            "scope": defaults?.string(forKey: "scope") ?? "nil",
            "intervalMinutes": String(defaults?.integer(forKey: "intervalMinutes") ?? -1),
            "processID": String(ProcessInfo.processInfo.processIdentifier),
            "fileWrite": "no container",
        ]
        if let container {
            record["fileWrite"] = "ok"
            do {
                let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
                try data.write(to: container.appendingPathComponent("l29-widget-probe.json"), options: .atomic)
            } catch {
                record["fileWrite"] = "failed: \(error)"
            }
        }
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            defaults?.set(text, forKey: "l29.widgetProbe")
        }
    }
    #endif
}

private struct VerseEntry: TimelineEntry, Sendable {
    let date: Date
    let verse: RotatingVerse?
    let abbreviation: String
    let attribution: String
}

private struct TimerEntry: TimelineEntry, Sendable {
    let date: Date
    let nextChange: Date
    let nextReference: String
}

private struct DailyReading: Decodable, Sendable {
    let title: String
    let reference: String
    let excerpt: String
}

private struct DailyEntry: TimelineEntry, Sendable {
    let date: Date
    let reading: DailyReading
}

private enum WidgetData {
    static func repositories() -> (ResourceRoots, IndexedRotationRepository)? {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("Widget", isDirectory: true) else { return nil }
        let roots = ResourceRoots(app: root, widget: root)
        return (roots, IndexedRotationRepository(roots: roots, resourceRoot: .widget))
    }

    static func verse(at date: Date) async -> VerseEntry {
        let state = WidgetSharedState.values()
        guard let (_, repository) = repositories() else {
            return VerseEntry(date: date, verse: nil, abbreviation: state.abbreviation, attribution: state.attribution)
        }
        do {
            let count = try await repository.poolCount(translation: state.translation, scope: state.scope)
            let offset = TimeZone.current.secondsFromGMT(for: date)
            let slot = try RotationMath.slot(at: date, utcOffsetSeconds: offset, intervalMinutes: state.interval)
            let index = try RotationMath.index(for: slot, count: count)
            let verse = try await repository.verse(translation: state.translation, scope: state.scope, at: index)
            return VerseEntry(date: date, verse: verse, abbreviation: state.abbreviation, attribution: state.attribution)
        } catch {
            return VerseEntry(date: date, verse: nil, abbreviation: state.abbreviation, attribution: state.attribution)
        }
    }

    static func verseTimeline(from now: Date) async -> [VerseEntry] {
        let state = WidgetSharedState.values()
        guard let (_, repository) = repositories(),
              let count = try? await repository.poolCount(translation: state.translation, scope: state.scope), count > 0 else {
            return [await verse(at: now)]
        }
        let offset = TimeZone.current.secondsFromGMT(for: now)
        guard let currentSlot = try? RotationMath.slot(at: now, utcOffsetSeconds: offset, intervalMinutes: state.interval) else {
            return [await verse(at: now)]
        }
        let entryCount = min(count, 48)
        var entries: [VerseEntry] = []
        entries.reserveCapacity(entryCount)
        for step in 0..<entryCount {
            let slot = currentSlot + Int64(step)
            guard let index = try? RotationMath.index(for: slot, count: count),
                  let verse = try? await repository.verse(translation: state.translation, scope: state.scope, at: index) else { continue }
            let date: Date
            if step == 0 {
                date = now
            } else {
                let boundaryOffset = TimeZone.current.secondsFromGMT(for: now)
                let base = Double(slot) * Double(state.interval) * 60 - Double(boundaryOffset)
                date = Date(timeIntervalSince1970: base)
            }
            entries.append(VerseEntry(date: date, verse: verse, abbreviation: state.abbreviation, attribution: state.attribution))
        }
        return entries.isEmpty ? [await verse(at: now)] : entries
    }

    static func timerTimeline(from now: Date) async -> [TimerEntry] {
        let state = WidgetSharedState.values()
        guard let (_, repository) = repositories(),
              let count = try? await repository.poolCount(translation: state.translation, scope: state.scope) else {
            return [TimerEntry(date: now, nextChange: now.addingTimeInterval(60), nextReference: "")]
        }
        let offset = TimeZone.current.secondsFromGMT(for: now)
        guard let currentSlot = try? RotationMath.slot(at: now, utcOffsetSeconds: offset, intervalMinutes: state.interval) else {
            return [TimerEntry(date: now, nextChange: now.addingTimeInterval(60), nextReference: "")]
        }
        let entryCount = max(1, min(count, 48))
        var entries: [TimerEntry] = []
        entries.reserveCapacity(entryCount)
        for step in 0..<entryCount {
            let slot = currentSlot + Int64(step)
            let slotSeconds = Double(state.interval) * 60
            let start = Date(timeIntervalSince1970: Double(slot) * slotSeconds - Double(offset))
            let end = Date(timeIntervalSince1970: Double(slot + 1) * slotSeconds - Double(offset))
            let nextIndex = try? RotationMath.index(for: slot + 1, count: count)
            let reference = if let nextIndex, let verse = try? await repository.verse(translation: state.translation, scope: state.scope, at: nextIndex) { verse.reference } else { "" }
            entries.append(TimerEntry(date: start, nextChange: end, nextReference: reference))
        }
        return entries
    }

    static func dailyTimeline(from now: Date) -> [DailyEntry] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        var years: [String: [String: DailyReading]] = [:]
        return (0...7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { return nil }
            let key = dateKey(date)
            let year = String(key.prefix(4))
            if years[year] == nil { years[year] = loadDaily(year: year) }
            let reading = years[year]?[key] ?? DailyReading(title: "Today’s readings", reference: "", excerpt: "")
            return DailyEntry(date: offset == 0 ? now : date, reading: reading)
        }
    }

    static func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func loadDaily(year: String) -> [String: DailyReading] {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("Widget", isDirectory: true),
              let data = try? Data(contentsOf: root.appendingPathComponent("daily-readings-\(year).json")),
              let readings = try? JSONDecoder().decode([String: DailyReading].self, from: data) else { return [:] }
        return readings
    }
}

private struct VerseProvider: TimelineProvider, Sendable {
    func placeholder(in context: Context) -> VerseEntry {
        VerseEntry(date: .now, verse: nil, abbreviation: "WEB-CE", attribution: "")
    }
    func getSnapshot(in context: Context, completion: @escaping @Sendable (VerseEntry) -> Void) {
        #if DEBUG
        WidgetSharedState.recordProbe(kind: "verse.snapshot")
        #endif
        Task { completion(await WidgetData.verse(at: .now)) }
    }
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<VerseEntry>) -> Void) {
        #if DEBUG
        WidgetSharedState.recordProbe(kind: "verse.timeline")
        #endif
        Task { completion(Timeline(entries: await WidgetData.verseTimeline(from: .now), policy: .atEnd)) }
    }
}

private struct TimerProvider: TimelineProvider, Sendable {
    func placeholder(in context: Context) -> TimerEntry { TimerEntry(date: .now, nextChange: .now.addingTimeInterval(60), nextReference: "") }
    func getSnapshot(in context: Context, completion: @escaping @Sendable (TimerEntry) -> Void) {
        #if DEBUG
        WidgetSharedState.recordProbe(kind: "timer.snapshot")
        #endif
        let fallback = placeholder(in: context)
        Task { completion((await WidgetData.timerTimeline(from: .now)).first ?? fallback) }
    }
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<TimerEntry>) -> Void) {
        #if DEBUG
        WidgetSharedState.recordProbe(kind: "timer.timeline")
        #endif
        Task { completion(Timeline(entries: await WidgetData.timerTimeline(from: .now), policy: .atEnd)) }
    }
}

private struct DailyProvider: TimelineProvider, Sendable {
    func placeholder(in context: Context) -> DailyEntry {
        DailyEntry(date: .now, reading: DailyReading(title: "Today’s Gospel", reference: "John 1:1–18", excerpt: "In the beginning was the Word, and the Word was with God, and the Word was God."))
    }
    func getSnapshot(in context: Context, completion: @escaping @Sendable (DailyEntry) -> Void) {
        #if DEBUG
        WidgetSharedState.recordProbe(kind: "daily.snapshot")
        #endif
        completion(WidgetData.dailyTimeline(from: .now).first ?? placeholder(in: context))
    }
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<DailyEntry>) -> Void) {
        #if DEBUG
        WidgetSharedState.recordProbe(kind: "daily.timeline")
        #endif
        let entries = WidgetData.dailyTimeline(from: .now)
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

private struct VerseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VerseEntry
    var body: some View {
        Group {
            if family == .accessoryInline {
                Text(entry.verse?.reference ?? "John 1:1")
            } else if family == .accessoryCircular {
                Text(entry.verse?.reference ?? "John 1:1").font(.system(size: 12, weight: .bold, design: .rounded)).minimumScaleFactor(0.5).multilineTextAlignment(.center)
            } else if family == .accessoryRectangular {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.verse?.text ?? "Open John 1:1 to begin.").font(.system(size: 14, weight: .semibold, design: .rounded)).lineLimit(3).minimumScaleFactor(0.5)
                    Text(entry.verse?.reference ?? "John 1:1").font(.system(size: 12, weight: .bold, design: .rounded)).widgetAccentable()
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("“\(entry.verse?.text ?? "Open John 1:1 to begin.")”").font(.system(size: 17, weight: .medium, design: .serif)).lineLimit(8).minimumScaleFactor(0.5)
                    Spacer(minLength: 0)
                    HStack {
                        Text(entry.verse?.reference ?? "John 1:1").font(.system(size: 13, weight: .bold, design: .rounded))
                        Spacer()
                        Text(entry.abbreviation).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }.padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .modifier(WidgetContainerBackground())
        .widgetURL(verseURL(entry))
    }
    private func verseURL(_ entry: VerseEntry) -> URL? {
        guard let verse = entry.verse else { return URL(string: "nrsv://read?book=JHN&chapter=1&verse=1&contextRequest=\(Int(entry.date.timeIntervalSince1970))") }
        var components = URLComponents()
        components.scheme = "nrsv"; components.host = "read"
        components.queryItems = [URLQueryItem(name: "book", value: verse.bookCode), URLQueryItem(name: "chapter", value: String(verse.chapter)), URLQueryItem(name: "verse", value: verse.verseLabel), URLQueryItem(name: "contextRequest", value: String(Int(entry.date.timeIntervalSince1970)))]
        return components.url
    }
}

private struct TimerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimerEntry
    private var range: ClosedRange<Date> { entry.date...max(entry.nextChange, entry.date.addingTimeInterval(1)) }
    var body: some View {
        Group {
            switch family {
            case .accessoryInline: Text("New verse in \(entry.nextChange, style: .timer)")
            case .accessoryCircular:
                ProgressView(timerInterval: range, countsDown: true) { EmptyView() } currentValueLabel: { Text(entry.nextChange, style: .timer).font(.system(size: 11, weight: .bold, design: .rounded)).minimumScaleFactor(0.4).multilineTextAlignment(.center) }.progressViewStyle(.circular)
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    Text("NEXT VERSE IN").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                    Text(entry.nextChange, style: .timer).font(.system(size: 24, weight: .bold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.5)
                    if !entry.nextReference.isEmpty { Text("up next · \(entry.nextReference)").font(.system(size: 11, weight: .semibold, design: .rounded)).widgetAccentable().lineLimit(1) }
                }
            default:
                VStack(spacing: 6) {
                    Text("Next verse in").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    Text(entry.nextChange, style: .timer).font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                    if !entry.nextReference.isEmpty { Text("up next · \(entry.nextReference)").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.secondary).lineLimit(1) }
                }.padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(WidgetContainerBackground())
    }
}

private struct DailyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyEntry
    var body: some View {
        Group {
            if family == .accessoryInline {
                Text(entry.reading.reference.isEmpty ? entry.reading.title : "Gospel · \(entry.reading.reference)")
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.reading.reference.isEmpty ? "DAILY READINGS" : "TODAY’S GOSPEL · WEB-CE").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                    Text(entry.reading.reference.isEmpty ? entry.reading.title : entry.reading.reference).font(.system(size: 13, weight: .semibold, design: .serif)).lineLimit(1).minimumScaleFactor(0.7).widgetAccentable()
                    Text(entry.reading.excerpt.isEmpty ? "Tap to open today’s readings" : entry.reading.excerpt).font(.system(size: family == .accessoryRectangular ? 11 : 15, design: .serif)).lineLimit(family == .accessoryRectangular ? 2 : 5)
                    if family == .systemSmall || family == .systemMedium { Text(entry.reading.title).font(.caption2).foregroundStyle(.secondary).lineLimit(2) }
                }.padding(family == .accessoryRectangular ? 0 : 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .modifier(WidgetContainerBackground())
        .widgetURL(URL(string: "nrsv://daily?date=\(WidgetData.dateKey(entry.date))"))
    }
}

private struct WidgetContainerBackground: ViewModifier {
    @Environment(\.widgetFamily) private var family
    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content.containerBackground(for: .widget) {
                switch family {
                case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge: Rectangle().fill(.background)
                default: Color.clear
                }
            }
        } else { content }
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

private struct DailyReadingWidget: Widget {
    let kind = "DailyReadingWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyProvider()) { DailyWidgetView(entry: $0) }
            .configurationDisplayName("Daily Reading")
            .description("Today’s Gospel preview, changing each day. United States Catholic calendar; tap for all readings.")
            .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemSmall, .systemMedium])
    }
}

private struct VerseTimerWidget: Widget {
    let kind = "VerseTimerWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimerProvider()) { TimerWidgetView(entry: $0) }
            .configurationDisplayName("Verse Countdown")
            .description("A live timer counting down to the next verse.")
            .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular, .systemSmall])
    }
}

@main struct JohnWidgetBundle: WidgetBundle {
    var body: some Widget { VerseWidget(); DailyReadingWidget(); VerseTimerWidget() }
}
