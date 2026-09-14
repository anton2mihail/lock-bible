import SwiftUI
import WidgetKit

// MARK: - Model

struct Verse: Decodable, Hashable {
  let ref: String
  let book: String
  let chapter: Int
  let verse: String
  let text: String
  let group: String

  init(
    ref: String,
    book: String = "JHN",
    chapter: Int = 3,
    verse: String = "16",
    text: String,
    group: String = "full"
  ) {
    self.ref = ref
    self.book = book
    self.chapter = chapter
    self.verse = verse
    self.text = text
    self.group = group
  }

  init(from decoder: Decoder) throws {
    var values = try decoder.unkeyedContainer()
    ref = try values.decode(String.self)
    book = try values.decode(String.self)
    chapter = try values.decode(Int.self)
    verse = try values.decode(String.self)
    text = try values.decode(String.self)
    group = "full"
  }
}

struct VerseEntry: TimelineEntry {
  let date: Date
  let verse: Verse
  let abbreviation: String
}

// MARK: - Memory-efficient bundled corpus
//
// WidgetKit extensions have a tight memory budget. Build 7 decoded one 8 MB
// JSON array into 38,029 Swift objects for every provider, which could terminate
// the extension before it rendered. These resources are memory-mapped and
// indexed, so a timeline decodes only the verses it will actually display.

fileprivate struct WidgetCorpus {
  static let fallback = Verse(ref: "John 3:16", text: "For God so loved the world…")

  private let records: Data?
  private let offsets: Data?
  private let oldTestamentRows: Data?
  private let newTestamentRows: Data?

  init(prefix: String) {
    records = Self.load(prefix, "dat", mapped: true)
    offsets = Self.load(prefix, "offsets")
    oldTestamentRows = Self.load(prefix, "ot")
    newTestamentRows = Self.load(prefix, "nt")
  }

  private static func load(_ name: String, _ ext: String, mapped: Bool = false) -> Data? {
    guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
    return try? Data(contentsOf: url, options: mapped ? .mappedIfSafe : [])
  }

  private static func uint32(_ data: Data?, at index: Int) -> Int? {
    guard let data else { return nil }
    let start = index * 4
    guard start >= 0, start + 3 < data.count else { return nil }
    return Int(data[start])
      | (Int(data[start + 1]) << 8)
      | (Int(data[start + 2]) << 16)
      | (Int(data[start + 3]) << 24)
  }

  func supports(_ scope: String) -> Bool {
    switch scope {
    case "ot": return (oldTestamentRows?.count ?? 0) >= 4
    case "nt": return (newTestamentRows?.count ?? 0) >= 4
    default: return (offsets?.count ?? 0) >= 8
    }
  }

  func count(for scope: String) -> Int {
    switch scope {
    case "ot": return (oldTestamentRows?.count ?? 0) / 4
    case "nt": return (newTestamentRows?.count ?? 0) / 4
    default: return max(0, (offsets?.count ?? 0) / 4 - 1)
    }
  }

  private func globalIndex(for scopedIndex: Int, scope: String) -> Int? {
    switch scope {
    case "ot": return Self.uint32(oldTestamentRows, at: scopedIndex)
    case "nt": return Self.uint32(newTestamentRows, at: scopedIndex)
    default: return scopedIndex
    }
  }

  func verse(at scopedIndex: Int, scope: String) -> Verse? {
    guard let records,
          let globalIndex = globalIndex(for: scopedIndex, scope: scope),
          let start = Self.uint32(offsets, at: globalIndex),
          let end = Self.uint32(offsets, at: globalIndex + 1),
          start >= 0,
          end > start,
          end <= records.count
    else { return nil }

    return try? JSONDecoder().decode(Verse.self, from: records.subdata(in: start..<end))
  }
}

private enum WidgetCorpora {
  static let webCe = WidgetCorpus(prefix: "web-ce")
  static let douayRheims = WidgetCorpus(prefix: "douay-rheims")
  static let vulgate = WidgetCorpus(prefix: "vulgate")

  static func corpus(for translationId: String) -> WidgetCorpus {
    switch translationId {
    case "douay-rheims": return douayRheims
    case "vulgate": return vulgate
    default: return webCe
    }
  }
}

// MARK: - Shared data + deterministic selection
//
// This mirrors src/services/bible/verseOfDay.ts EXACTLY so the lock screen and
// the app always show the same verse. The app and widget independently compute
// the same index from the device clock — no background refresh required.

enum VerseStore {
  static let appGroup = "group.com.nrsv.verse"
  static let defaultIntervalMinutes = 1440
  static let defaultTranslationId = "web-ce"
  static let defaultAbbreviation = "WEB-CE"
  static let defaultScope = "full"

  private static var defaults: UserDefaults? {
    UserDefaults(suiteName: appGroup)
  }

  static func scope() -> String {
    defaults?.string(forKey: "scope") ?? defaultScope
  }

  static func translationId() -> String {
    defaults?.string(forKey: "translationId") ?? defaultTranslationId
  }

  private static func corpus() -> WidgetCorpus {
    WidgetCorpora.corpus(for: translationId())
  }

  /// Fall back to the full corpus if an old or malformed installation is
  /// missing a scoped index. A verse always renders even when resources fail.
  static func effectiveScope() -> String {
    let requested = scope()
    return corpus().supports(requested) ? requested : defaultScope
  }

  static func corpusCount(scope: String) -> Int {
    corpus().count(for: scope)
  }

  static func verse(at index: Int, scope: String) -> Verse {
    corpus().verse(at: index, scope: scope) ?? WidgetCorpus.fallback
  }

  static func intervalMinutes() -> Int {
    let value = defaults?.integer(forKey: "intervalMinutes") ?? 0
    return value > 0 ? value : defaultIntervalMinutes
  }

  static func abbreviation() -> String {
    defaults?.string(forKey: "abbreviation") ?? defaultAbbreviation
  }

  /// Opens the exact bundled passage in the app. Only public Scripture
  /// coordinates are included; no user preference or reading data leaves the device.
  static func contextURL(for verse: Verse, at date: Date) -> URL? {
    guard !verse.book.isEmpty, verse.chapter > 0, !verse.verse.isEmpty else { return nil }
    var components = URLComponents()
    components.scheme = "nrsv"
    components.host = "read"
    components.queryItems = [
      URLQueryItem(name: "book", value: verse.book),
      URLQueryItem(name: "chapter", value: String(verse.chapter)),
      URLQueryItem(name: "verse", value: verse.verse),
      URLQueryItem(name: "contextRequest", value: String(Int(date.timeIntervalSince1970))),
    ]
    return components.url
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

  static let shuffleStride = 104_729
  static let shuffleOffset = 1_729

  static func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
    var x = abs(a)
    var y = abs(b)
    while y != 0 {
      let remainder = x % y
      x = y
      y = remainder
    }
    return x
  }

  static func permutationStride(for count: Int) -> Int {
    var stride = shuffleStride
    while greatestCommonDivisor(stride, count) != 1 { stride += 2 }
    return stride
  }

  static func index(forSlot slot: Int, count: Int) -> Int {
    guard count > 0 else { return 0 }
    let index = (slot * permutationStride(for: count) + shuffleOffset) % count
    return (index + count) % count
  }

  static func index(for date: Date, count: Int, interval: Int) -> Int {
    index(forSlot: rotationSlot(date, interval), count: count)
  }

  /// Absolute instant at which the given rotation slot begins.
  static func slotStart(_ slot: Int, _ interval: Int, reference: Date) -> Date {
    let offset = TimeZone.current.secondsFromGMT(for: reference)
    let localSeconds = Double(slot * interval * 60)
    return Date(timeIntervalSince1970: localSeconds - Double(offset))
  }

  static func entry(for date: Date) -> VerseEntry {
    let scope = effectiveScope()
    let count = corpusCount(scope: scope)
    let interval = intervalMinutes()
    let idx = index(for: date, count: count, interval: interval)
    let verse = verse(at: idx, scope: scope)
    return VerseEntry(date: date, verse: verse, abbreviation: abbreviation())
  }

  /// A timeline of upcoming verse changes. One entry per rotation boundary, so
  /// WidgetKit swaps verses on schedule with no extra reloads.
  static func timeline(from now: Date) -> [VerseEntry] {
    let scope = effectiveScope()
    let count = corpusCount(scope: scope)
    let interval = intervalMinutes()
    guard count > 0 else { return [entry(for: now)] }

    let abbr = abbreviation()
    let currentSlot = rotationSlot(now, interval)
    let maxEntries = min(count, 48)

    let currentIndex = index(forSlot: currentSlot, count: count)
    var entries: [VerseEntry] = [
      VerseEntry(date: now, verse: verse(at: currentIndex, scope: scope), abbreviation: abbr)
    ]
    for step in 1..<maxEntries {
      let slot = currentSlot + step
      let date = slotStart(slot, interval, reference: now)
      let idx = index(forSlot: slot, count: count)
      entries.append(VerseEntry(date: date, verse: verse(at: idx, scope: scope), abbreviation: abbr))
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
    let scope = effectiveScope()
    let interval = intervalMinutes()
    let count = corpusCount(scope: scope)
    let currentSlot = rotationSlot(now, interval)
    let maxEntries = max(1, min(count == 0 ? 1 : count, 48))

    var entries: [TimerEntry] = []
    for step in 0..<maxEntries {
      let slot = currentSlot + step
      let start = slotStart(slot, interval, reference: now)
      let end = slotStart(slot + 1, interval, reference: now)
      let nextRef = count == 0
        ? ""
        : verse(at: index(forSlot: slot + 1, count: count), scope: scope).ref
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
        .widgetURL(VerseStore.contextURL(for: entry.verse, at: entry.date))
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
    DailyReadingWidget()
    VerseTimerWidget()
  }
}
