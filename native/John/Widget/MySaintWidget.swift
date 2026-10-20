import CoreText
import AppIntents
import SwiftUI
import WidgetKit
import JohnCore

private enum SaintWidgetData {
    static var group: String { Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? "group.com.nrsv.verse" }
    static var defaults: UserDefaults? { UserDefaults(suiteName: group) }
    static func registerFonts() {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return }
        for font in ["Lora_400Regular.ttf", "SpaceGrotesk_400Regular.ttf", "SpaceGrotesk_700Bold.ttf"] {
            CTFontManagerRegisterFontsForURL(root.appendingPathComponent(font) as CFURL, .process, nil)
        }
    }
    static var catalog: [SaintWidgetContent] {
        guard let data = defaults?.data(forKey: "saintWidgetCatalog") else { return [] }
        return (try? JSONDecoder().decode([SaintWidgetContent].self, from: data)) ?? []
    }
    static func image(_ name: String?) -> UIImage? {
        guard let name, let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return nil }
        return UIImage(contentsOfFile: root.appendingPathComponent("\(name).jpg").path)
    }
}

struct WidgetSaint: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Saint")
    static let defaultQuery = WidgetSaintQuery()
    let id: String
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}
struct WidgetSaintQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetSaint] {
        SaintWidgetData.catalog.filter { identifiers.contains($0.id) }.map { WidgetSaint(id: $0.id, name: $0.name) }
    }
    func suggestedEntities() async throws -> [WidgetSaint] {
        SaintWidgetData.catalog.map { WidgetSaint(id: $0.id, name: $0.name) }
    }
}
enum SaintWidgetDisplay: String, AppEnum {
    case appDefault, text, quiet
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Display")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .appDefault: "Use app setting",
        .text: "Prayer or life account",
        .quiet: "Artwork and name only"
    ]
}
struct MySaintIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "My Saint"
    static let description = IntentDescription("Keep a chosen saint close. Personal notes never appear here.")
    @Parameter(title: "Saint") var saint: WidgetSaint?
    @Parameter(title: "Display", default: .appDefault) var display: SaintWidgetDisplay
}
struct MySaintEntry: TimelineEntry {
    let date: Date
    let content: SaintWidgetContent?
    let quiet: Bool
}
struct MySaintProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MySaintEntry { MySaintEntry(date: .now, content: nil, quiet: true) }
    func snapshot(for configuration: MySaintIntent, in context: Context) async -> MySaintEntry { entry(configuration, date: .now) }
    func timeline(for configuration: MySaintIntent, in context: Context) async -> Timeline<MySaintEntry> {
        let now = Date()
        let days = (0...7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: now)) }
        return Timeline(entries: days.map { entry(configuration, date: $0) }, policy: .atEnd)
    }
    private func entry(_ configuration: MySaintIntent, date: Date) -> MySaintEntry {
        SaintWidgetData.registerFonts()
        let selected = configuration.saint?.id ?? SaintWidgetData.defaults?.string(forKey: "saintWidgetSelected")
        let quiet: Bool
        switch configuration.display {
        case .appDefault: quiet = SaintWidgetData.defaults?.bool(forKey: "saintWidgetQuiet") ?? false
        case .text: quiet = false
        case .quiet: quiet = true
        }
        return MySaintEntry(date: date, content: SaintWidgetData.catalog.first { $0.id == selected },
            quiet: quiet)
    }
}
struct MySaintWidgetView: View {
    let entry: MySaintEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var scheme
    private var color: Color { scheme == .dark ? Color(red: 0.96, green: 0.95, blue: 0.94) : Color(red: 0.10, green: 0.06, blue: 0.08) }
    private var feast: Bool { entry.content.map { String(CompanionCalendar.dateKey(entry.date, timeZone: .current).suffix(5)) == $0.monthDay } ?? false }
    var body: some View {
        content
            .widgetURL(URL(string: entry.content.map { "nrsv://saint?id=\($0.id)" } ?? "nrsv://saint"))
            .containerBackground(for: .widget) {
                if family == .accessoryRectangular { Color.clear }
                else if family == .systemSmall, let image = SaintWidgetData.image(entry.content?.artwork), renderingMode == .fullColor {
                    GeometryReader { geometry in
                        Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                    }
                } else { scheme == .dark ? Color(red: 0.145, green: 0.114, blue: 0.137) : Color(red: 1, green: 0.988, blue: 0.965) }
            }
    }
    @ViewBuilder private var content: some View {
        if let saint = entry.content {
            if family == .accessoryRectangular {
                VStack(alignment: .leading, spacing: 2) {
                    Text(saint.name).font(.headline).widgetAccentable()
                    Text(feast ? "Remembered today" : "Open prayers and life").font(.caption)
                }.frame(maxWidth: .infinity, alignment: .leading)
            } else if family == .systemSmall {
                VStack(alignment: .leading, spacing: 6) {
                    Spacer(minLength: 0)
                    Text(saint.name).font(.custom("Lora-Regular", size: 21)).lineLimit(3).widgetAccentable()
                    if feast { Text("Remembered today").font(.caption2) }
                    else if !entry.quiet { Text("Open prayers and life").font(.caption2) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(SaintWidgetData.image(saint.artwork) != nil && renderingMode == .fullColor ? .white : color)
            } else {
                HStack(spacing: 14) {
                    if let image = SaintWidgetData.image(saint.artwork), renderingMode == .fullColor {
                        Image(uiImage: image).resizable().scaledToFill().frame(width: 92).clipped().clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(saint.name).font(.custom("Lora-Regular", size: 22)).lineLimit(2).widgetAccentable()
                        if !entry.quiet { Text(saint.text).font(.custom("Lora-Regular", size: 14)).lineLimit(4) }
                        Spacer(minLength: 0)
                        Text(feast ? "Remembered today" : entry.quiet ? saint.calendarName : saint.source).font(.custom("SpaceGrotesk-Regular", size: 11)).lineLimit(2)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.foregroundStyle(color)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("My Saints").font(.headline).widgetAccentable()
                Text("Choose a saint in John 1:1").font(.subheadline)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
struct MySaintWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "MySaintWidget", intent: MySaintIntent.self, provider: MySaintProvider()) { MySaintWidgetView(entry: $0) }
            .configurationDisplayName("My Saint")
            .description("Return to a chosen saint through prayer and their life.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
