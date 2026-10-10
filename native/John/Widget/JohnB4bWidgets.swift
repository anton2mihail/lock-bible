import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: Reading progress widget (E12)

struct ReadingProgressEntry: TimelineEntry, Sendable {
    let date: Date
    let read: Int
    let total: Int
    let pending: Int
    let today: [Int]

    var done: Int { min(total, read + pending) }
    var fraction: Double { total > 0 ? Double(done) / Double(total) : 0 }
    /// Chapters for today that the user did not mark yet.
    var todayOpen: Bool { !today.isEmpty && pending == 0 }
}

struct ReadingProgressProvider: TimelineProvider, Sendable {
    func placeholder(in context: Context) -> ReadingProgressEntry {
        ReadingProgressEntry(date: .now, read: 7, total: 21, pending: 0, today: [8])
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (ReadingProgressEntry) -> Void) {
        completion(Self.entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ReadingProgressEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 1),
                                                 matchingPolicy: .nextTime) ?? now.addingTimeInterval(3_600)
        completion(Timeline(entries: [Self.entry(at: now)], policy: .after(midnight)))
    }

    static func entry(at date: Date) -> ReadingProgressEntry {
        let defaults = WidgetHandoff.defaults
        let total = defaults?.integer(forKey: WidgetHandoff.totalKey) ?? 0
        return ReadingProgressEntry(
            date: date,
            read: defaults?.integer(forKey: WidgetHandoff.readKey) ?? 0,
            total: total > 0 ? total : 21,
            pending: (defaults?.array(forKey: WidgetHandoff.pendingDoneKey) as? [Int] ?? []).count,
            today: defaults?.array(forKey: WidgetHandoff.todayKey) as? [Int] ?? [])
    }
}

struct ReadingProgressView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ReadingProgressEntry

    var body: some View {
        content
            .widgetURL(URL(string: "nrsv://read?book=JHN"))
            .containerBackground(for: .widget) {
                switch family {
                case .systemSmall, .systemMedium: Rectangle().fill(.background)
                default: Color.clear
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.fraction) {
                Text("John")
            } currentValueLabel: {
                Text("\(entry.done)")
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryInline:
            Text("John \(entry.done) of \(entry.total) chapters read")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("John reading").font(.headline).widgetAccentable()
                Text("\(entry.done) of \(entry.total) chapters")
                ProgressView(value: entry.fraction)
            }
        case .systemMedium:
            HStack(spacing: 16) {
                ring(lineWidth: 10).frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 8) {
                    Text("John reading").font(.headline)
                    Text("\(entry.done) of \(entry.total) chapters read").font(.subheadline)
                    markButton
                }
                Spacer(minLength: 0)
            }
        default:
            // The small layout is the StandBy layout. It uses large numbers and a high contrast ring.
            VStack(spacing: 6) {
                ring(lineWidth: 9)
                    .overlay {
                        VStack(spacing: 0) {
                            Text("\(entry.done)").font(.system(size: 34, weight: .semibold, design: .rounded))
                            Text("of \(entry.total)").font(.caption2)
                        }
                    }
                markButton
            }
        }
    }

    private func ring(lineWidth: CGFloat) -> some View {
        ZStack {
            Circle().stroke(.secondary.opacity(0.3), lineWidth: lineWidth)
            Circle().trim(from: 0, to: entry.fraction)
                .stroke(.tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
        }
    }

    @ViewBuilder private var markButton: some View {
        if entry.todayOpen {
            Button(intent: MarkTodayReadIntent()) {
                Label("Mark done", systemImage: "checkmark.circle")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
        } else {
            Label(entry.today.isEmpty ? "All read" : "Done today", systemImage: "checkmark.seal")
                .font(.caption.weight(.semibold))
        }
    }
}

struct ReadingProgressWidget: Widget {
    let kind = WidgetHandoff.progressWidgetKind
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadingProgressProvider()) { ReadingProgressView(entry: $0) }
            .configurationDisplayName("Reading Progress")
            .description("Your progress through the Gospel of John. Mark today’s reading done.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .systemSmall, .systemMedium])
    }
}

// MARK: Control Center controls (E12)

struct OpenRosaryControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "OpenRosaryControl") {
            ControlWidgetButton(action: OpenRosaryControlIntent()) {
                Label("Rosary", systemImage: "circle.dotted")
            }
        }
        .displayName("Open the Rosary")
        .description("Opens the Rosary guide.")
    }
}

struct StartLectioControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "StartLectioControl") {
            ControlWidgetButton(action: StartLectioControlIntent()) {
                Label("Lectio", systemImage: "timer")
            }
        }
        .displayName("Start a Lectio timer")
        .description("Opens Lectio divina for a quiet minute.")
    }
}

// MARK: Live Activity (E13)

struct PrayerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerActivityAttributes.self) { context in
            PrayerLockScreenView(attributes: context.attributes, state: context.state)
                .padding()
                .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: symbol(context.attributes.kind)).font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PrayerProgressText(state: context.state).font(.title3.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.stepTitle).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.title).font(.caption).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: symbol(context.attributes.kind))
            } compactTrailing: {
                PrayerProgressText(state: context.state).monospacedDigit().frame(maxWidth: 48)
            } minimal: {
                Image(systemName: symbol(context.attributes.kind))
            }
        }
    }

    private func symbol(_ kind: PrayerActivityAttributes.Kind) -> String {
        kind == .rosary ? "circle.dotted" : "timer"
    }
}

/// The time left for Lectio, or the step count for the Rosary.
private struct PrayerProgressText: View {
    let state: PrayerActivityAttributes.ContentState
    var body: some View {
        if let end = state.endDate, end > Date() {
            Text(timerInterval: Date()...end, countsDown: true)
        } else {
            Text("\(state.stepIndex + 1)/\(state.stepCount)")
        }
    }
}

private struct PrayerLockScreenView: View {
    let attributes: PrayerActivityAttributes
    let state: PrayerActivityAttributes.ContentState
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: attributes.kind == .rosary ? "circle.dotted" : "timer").font(.title)
            VStack(alignment: .leading, spacing: 2) {
                Text(attributes.title).font(.caption).foregroundStyle(.secondary)
                Text(state.stepTitle).font(.headline).lineLimit(2)
            }
            Spacer(minLength: 0)
            PrayerProgressText(state: state).font(.title2.monospacedDigit())
        }
    }
}
