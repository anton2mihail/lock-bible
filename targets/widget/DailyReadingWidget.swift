import SwiftUI
import WidgetKit

struct DailyReading: Decodable {
  let title: String
  let reference: String
  let excerpt: String
}

struct DailyReadingEntry: TimelineEntry {
  let date: Date
  let reading: DailyReading
}

enum DailyReadingStore {
  static func key(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  static func load(year: String) -> [String: DailyReading] {
    guard let url = Bundle.main.url(forResource: "daily-readings-\(year)", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let days = try? JSONDecoder().decode([String: DailyReading].self, from: data)
    else { return [:] }
    return days
  }

  static func timeline(from now: Date) -> [DailyReadingEntry] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    var years: [String: [String: DailyReading]] = [:]
    return (0...7).compactMap { offset in
      guard let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { return nil }
      let day = key(date)
      let year = String(day.prefix(4))
      if years[year] == nil { years[year] = load(year: year) }
      let reading = years[year]?[day] ?? DailyReading(title: "Today’s readings", reference: "", excerpt: "")
      return DailyReadingEntry(date: offset == 0 ? now : date, reading: reading)
    }
  }

  static func url(for date: Date) -> URL? {
    var url = URLComponents()
    url.scheme = "nrsv"
    url.host = "daily"
    url.queryItems = [URLQueryItem(name: "date", value: key(date))]
    return url.url
  }
}

struct DailyReadingProvider: TimelineProvider {
  func placeholder(in context: Context) -> DailyReadingEntry {
    DailyReadingEntry(date: Date(), reading: DailyReading(title: "Today’s Gospel", reference: "John 1:1–18", excerpt: "In the beginning was the Word, and the Word was with God, and the Word was God."))
  }
  func getSnapshot(in context: Context, completion: @escaping (DailyReadingEntry) -> Void) {
    completion(DailyReadingStore.timeline(from: Date()).first ?? placeholder(in: context))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<DailyReadingEntry>) -> Void) {
    completion(Timeline(entries: DailyReadingStore.timeline(from: Date()), policy: .atEnd))
  }
}

struct DailyReadingView: View {
  @Environment(\.widgetFamily) private var family
  let entry: DailyReadingEntry
  var body: some View {
    if family == .accessoryInline {
      Text(entry.reading.reference.isEmpty ? entry.reading.title : "Gospel · \(entry.reading.reference)")
    } else {
      VStack(alignment: .leading, spacing: 3) {
        Text(entry.reading.reference.isEmpty ? "DAILY READINGS" : "TODAY’S GOSPEL · WEB-CE")
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(.secondary)
        Text(entry.reading.reference.isEmpty ? entry.reading.title : entry.reading.reference)
          .font(.system(size: 13, weight: .semibold, design: .serif))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .widgetAccentable()
        Text(entry.reading.excerpt.isEmpty ? "Tap to open today’s readings" : entry.reading.excerpt)
          .font(.system(size: family == .accessoryRectangular ? 11 : 15, design: .serif))
          .lineLimit(family == .accessoryRectangular ? 2 : 5)
        if family == .systemSmall || family == .systemMedium {
          Text(entry.reading.title).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
      }
      .padding(family == .accessoryRectangular ? 0 : 14)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
  }
}

struct DailyReadingWidget: Widget {
  let kind = "DailyReadingWidget"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: DailyReadingProvider()) { entry in
      DailyReadingView(entry: entry)
        .modifier(WidgetContainerBackground())
        .widgetURL(DailyReadingStore.url(for: entry.date))
    }
    .configurationDisplayName("Daily Reading")
    .description("Today’s Gospel preview, changing each day. United States Catholic calendar; tap for all readings.")
    .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemSmall, .systemMedium])
  }
}
