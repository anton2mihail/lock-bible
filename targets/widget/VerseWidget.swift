import SwiftUI
import WidgetKit

// MARK: - Model

struct Verse: Decodable, Hashable {
  let ref: String
  let text: String
  let group: String

  enum CodingKeys: String, CodingKey { case ref, text, group }

  init(ref: String, text: String, group: String = "full") {
    self.ref = ref
    self.text = text
    self.group = group
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    ref = try c.decode(String.self, forKey: .ref)
    text = try c.decode(String.self, forKey: .text)
    group = (try? c.decode(String.self, forKey: .group)) ?? "full"
  }
}

private struct VersePayload: Decodable {
  let verses: [Verse]
}

struct VerseEntry: TimelineEntry {
  let date: Date
  let verse: Verse
  let abbreviation: String
}

// MARK: - Shared data + deterministic selection
//
// This mirrors src/services/bible/verseOfDay.ts EXACTLY so the lock screen and
// the app always show the same verse. The app and widget independently compute
// the same index from the device clock — no background refresh required.

enum VerseStore {
  static let appGroup = "group.com.nrsv.verse"
  static let defaultIntervalMinutes = 1440
  static let defaultAbbreviation = "WEB-CE"
  static let defaultScope = "full"

  private static var defaults: UserDefaults? {
    UserDefaults(suiteName: appGroup)
  }

  /// Full pool: the app-provided (possibly OTA-updated) list if present,
  /// otherwise the copy bundled into this widget target.
  static func allVerses() -> [Verse] {
    if let json = defaults?.string(forKey: "verses"),
       let data = json.data(using: .utf8),
       let parsed = try? JSONDecoder().decode([Verse].self, from: data),
       !parsed.isEmpty {
      return parsed
    }
    return bundledVerses()
  }

  static func bundledVerses() -> [Verse] {
    guard let url = Bundle.main.url(forResource: "widgetVerses", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let payload = try? JSONDecoder().decode(VersePayload.self, from: data)
    else {
      return [Verse(ref: "John 3:16", text: "For God so loved the world…")]
    }
    return payload.verses
  }

  static func scope() -> String {
    defaults?.string(forKey: "scope") ?? defaultScope
  }

  /// Whether a verse's book group belongs to the selected scope. As in the JS
  /// side, the Old Testament scope includes the deuterocanon.
  static func matches(_ group: String, _ scope: String) -> Bool {
    switch scope {
    case "nt": return group == "nt"
    case "ot": return group == "ot" || group == "deutero"
    default: return true
    }
  }

  /// The pool after applying the user's testament scope (never empty).
  static func verses() -> [Verse] {
    let all = allVerses()
    let s = scope()
    if s == "full" { return all }
    let filtered = all.filter { matches($0.group, s) }
    return filtered.isEmpty ? all : filtered
  }

  static func intervalMinutes() -> Int {
    let value = defaults?.integer(forKey: "intervalMinutes") ?? 0
    return value > 0 ? value : defaultIntervalMinutes
  }

  static func abbreviation() -> String {
    defaults?.string(forKey: "abbreviation") ?? defaultAbbreviation
  }

  // --- Deterministic math (mirror of verseOfDay.ts), cadence in MINUTES ---

  /// Whole minutes since the epoch in the device's local timezone.
  static func localMinutesSinceEpoch(_ date: Date) -> Int {
    let offset = TimeZone.current.secondsFromGMT(for: date)
    let localSeconds = date.timeIntervalSince1970 + Double(offset)
    return Int(floor(localSeconds / 60.0))
  }

  static func rotationSlot(_ date: Date, _ interval: Int) -> Int {
    Int(floor(Double(localMinutesSinceEpoch(date)) / Double(interval)))
  }

  static func index(for date: Date, count: Int, interval: Int) -> Int {
    guard count > 0 else { return 0 }
    let slot = rotationSlot(date, interval)
    return ((slot % count) + count) % count
  }

  /// Absolute instant at which the given rotation slot begins.
  static func slotStart(_ slot: Int, _ interval: Int, reference: Date) -> Date {
    let offset = TimeZone.current.secondsFromGMT(for: reference)
    let localSeconds = Double(slot * interval * 60)
    return Date(timeIntervalSince1970: localSeconds - Double(offset))
  }

  static func entry(for date: Date) -> VerseEntry {
    let pool = verses()
    let interval = intervalMinutes()
    let idx = index(for: date, count: pool.count, interval: interval)
    let verse = pool.isEmpty ? Verse(ref: "", text: "") : pool[idx]
    return VerseEntry(date: date, verse: verse, abbreviation: abbreviation())
  }

  /// A timeline of upcoming verse changes. One entry per rotation boundary, so
  /// WidgetKit swaps verses on schedule with no extra reloads.
  static func timeline(from now: Date) -> [VerseEntry] {
    let pool = verses()
    let interval = intervalMinutes()
    guard !pool.isEmpty else { return [entry(for: now)] }

    let abbr = abbreviation()
    let currentSlot = rotationSlot(now, interval)
    let maxEntries = min(pool.count, 48)

    var entries: [VerseEntry] = [entry(for: now)]
    for step in 1..<maxEntries {
      let slot = currentSlot + step
      let date = slotStart(slot, interval, reference: now)
      let idx = ((slot % pool.count) + pool.count) % pool.count
      entries.append(VerseEntry(date: date, verse: pool[idx], abbreviation: abbr))
    }
    return entries
  }

  /// The instant the current verse will next change.
  static func nextChange(from date: Date) -> Date {
    let interval = intervalMinutes()
    return slotStart(rotationSlot(date, interval) + 1, interval, reference: date)
  }

  /// Pre-supplied countdown entries — one per upcoming boundary — so the timer
  /// widget never reloads per tick (the countdown text animates on its own).
  /// This keeps even a 10-minute cadence well within WidgetKit's refresh budget.
  static func timerTimeline(from now: Date) -> [TimerEntry] {
    let pool = verses()
    let interval = intervalMinutes()
    let count = pool.count
    let currentSlot = rotationSlot(now, interval)
    let maxEntries = max(1, min(count == 0 ? 1 : count, 48))

    var entries: [TimerEntry] = []
    for step in 0..<maxEntries {
      let slot = currentSlot + step
      let start = slotStart(slot, interval, reference: now)
      let end = slotStart(slot + 1, interval, reference: now)
      let nextRef = count == 0 ? "" : pool[(((slot + 1) % count) + count) % count].ref
      entries.append(TimerEntry(date: start, nextChange: end, nextRef: nextRef))
    }
    return entries
  }

  static func timerEntry(for date: Date) -> TimerEntry {
    timerTimeline(from: date).first
      ?? TimerEntry(date: date, nextChange: nextChange(from: date), nextRef: "")
  }
}

struct TimerEntry: TimelineEntry {
  let date: Date
  let nextChange: Date
  let nextRef: String
}

// MARK: - Timeline provider

struct VerseProvider: TimelineProvider {
  func placeholder(in context: Context) -> VerseEntry {
    VerseStore.entry(for: Date())
  }

  func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> Void) {
    completion(VerseStore.entry(for: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
    completion(Timeline(entries: VerseStore.timeline(from: Date()), policy: .atEnd))
  }
}

// MARK: - Views

struct VerseWidgetEntryView: View {
  @Environment(\.widgetFamily) private var family
  var entry: VerseEntry

  var body: some View {
    switch family {
    case .accessoryInline:
      // A single short line beside the clock — show the reference only.
      Text(entry.verse.ref)

    case .accessoryCircular:
      Text(entry.verse.ref)
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .minimumScaleFactor(0.5)
        .multilineTextAlignment(.center)

    case .accessoryRectangular:
      // The verse home: up to 3 auto-shrinking lines so it never gets cut off.
      // Heavier rounded weight reads far better against a busy lock screen.
      VStack(alignment: .leading, spacing: 2) {
        Text(entry.verse.text)
          .font(.system(size: 14, weight: .semibold, design: .rounded))
          .minimumScaleFactor(0.5)
          .lineLimit(3)
        Text(entry.verse.ref)
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .widgetAccentable()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

    default:
      // Home-screen system widgets.
      systemView
    }
  }

  private var systemView: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("“\(entry.verse.text)”")
        .font(.system(size: 17, weight: .medium, design: .serif))
        .minimumScaleFactor(0.5)
        .lineLimit(8)
      Spacer(minLength: 0)
      HStack {
        Text(entry.verse.ref)
          .font(.system(size: 13, weight: .bold, design: .rounded))
        Spacer()
        Text(entry.abbreviation)
          .font(.system(size: 10, weight: .regular))
          .foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

// MARK: - Background
//
// iOS 17 requires every widget to declare a containerBackground. Lock-screen
// accessory widgets must stay transparent (the system tints them), while
// home-screen system widgets get a solid surface.

struct WidgetContainerBackground: ViewModifier {
  @Environment(\.widgetFamily) private var family

  func body(content: Content) -> some View {
    if #available(iOS 17.0, *) {
      content.containerBackground(for: .widget) {
        switch family {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge:
          Rectangle().fill(.background)
        default:
          Color.clear
        }
      }
    } else {
      content
    }
  }
}

// MARK: - Widget

struct VerseWidget: Widget {
  let kind = "VerseWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: VerseProvider()) { entry in
      VerseWidgetEntryView(entry: entry)
        .modifier(WidgetContainerBackground())
    }
    .configurationDisplayName("Daily Verse")
    .description("A rotating Scripture verse, refreshed throughout the day.")
    .supportedFamilies([
      .accessoryRectangular,
      .accessoryInline,
      .accessoryCircular,
      .systemSmall,
      .systemMedium,
    ])
  }
}

// MARK: - Countdown widget
//
// Shows a live timer to the next verse change. WidgetKit's `Text(_:style:.timer)`
// and `ProgressView(timerInterval:)` tick on their own — no timeline reloads and
// no refresh-budget cost. We only reload once, when the verse actually changes.

struct VerseTimerProvider: TimelineProvider {
  func placeholder(in context: Context) -> TimerEntry {
    VerseStore.timerEntry(for: Date())
  }

  func getSnapshot(in context: Context, completion: @escaping (TimerEntry) -> Void) {
    completion(VerseStore.timerEntry(for: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TimerEntry>) -> Void) {
    let entries = VerseStore.timerTimeline(from: Date())
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

struct VerseTimerEntryView: View {
  @Environment(\.widgetFamily) private var family
  var entry: TimerEntry

  private var range: ClosedRange<Date> {
    // Guard against a non-ascending range at the exact tick of change.
    let end = max(entry.nextChange, entry.date.addingTimeInterval(1))
    return entry.date...end
  }

  var body: some View {
    switch family {
    case .accessoryInline:
      Text("New verse in \(entry.nextChange, style: .timer)")

    case .accessoryCircular:
      ProgressView(timerInterval: range, countsDown: true) {
        EmptyView()
      } currentValueLabel: {
        Text(entry.nextChange, style: .timer)
          .font(.system(size: 11, weight: .bold, design: .rounded))
          .minimumScaleFactor(0.4)
          .multilineTextAlignment(.center)
      }
      .progressViewStyle(.circular)

    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 1) {
        Text("NEXT VERSE IN")
          .font(.system(size: 10, weight: .semibold, design: .rounded))
          .foregroundStyle(.secondary)
        Text(entry.nextChange, style: .timer)
          .font(.system(size: 24, weight: .bold, design: .rounded))
          .monospacedDigit()
          .minimumScaleFactor(0.5)
        if !entry.nextRef.isEmpty {
          Text("up next · \(entry.nextRef)")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .widgetAccentable()
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

    default:
      VStack(spacing: 6) {
        Text("Next verse in")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(.secondary)
        Text(entry.nextChange, style: .timer)
          .font(.system(size: 34, weight: .bold, design: .rounded))
          .monospacedDigit()
          .minimumScaleFactor(0.5)
          .lineLimit(1)
        if !entry.nextRef.isEmpty {
          Text("up next · \(entry.nextRef)")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

struct VerseTimerWidget: Widget {
  let kind = "VerseTimerWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: VerseTimerProvider()) { entry in
      VerseTimerEntryView(entry: entry)
        .modifier(WidgetContainerBackground())
    }
    .configurationDisplayName("Verse Countdown")
    .description("A live timer counting down to the next verse.")
    .supportedFamilies([
      .accessoryRectangular,
      .accessoryInline,
      .accessoryCircular,
      .systemSmall,
    ])
  }
}

@main
struct VerseWidgetBundle: WidgetBundle {
  var body: some Widget {
    VerseWidget()
    VerseTimerWidget()
  }
}
