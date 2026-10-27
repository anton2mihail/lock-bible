import SwiftUI
import JohnCore

/// Lent, Holy Week and the Stations of the Cross (2.3.0). Every prayer is quoted from `Catalogs/lent.json`
/// with its book and page; the app adds only titles and the names of the sources.
enum LentText {
    static let fastingURL = URL(string: "https://www.usccb.org/prayer-and-worship/liturgical-year-and-calendar/lent/catholic-information-on-lenten-fast-and-abstinence")!
    static let missalShort = "The Missal (1926 printing; Imprimatur Westminster, 1921)"
    static let manualShort = "A Manual of Prayers (Baltimore, 1889)"
    static let massEveryDayShort = "The Roman Missal (New York, 1916; Imprimatur Farley)"
    /// Leo's sermons in the order the library has them, with their own titles.
    static let leoTitles = ["On Lent, I", "On Lent, II", "On Lent, IV", "On Lent, VIII", "On Lent, XI", "On the Transfiguration",
                            "On the Passion, III", "On the Passion, IV", "On the Passion, VII", "On the Passion, VIII",
                            "On the Passion, XI", "On the Passion, XII", "On the Passion, XVI", "On the Passion, XVII"]
    static let psalmTitles: [Int: String] = [6: "Domine, ne in furore", 31: "Beati quorum", 37: "Domine, ne in furore (II)",
                                             50: "Miserere", 101: "Domine, exaudi", 129: "De profundis", 142: "Domine, exaudi (II)"]

    static func pages(_ pages: [Int]) -> String {
        guard let first = pages.min(), let last = pages.max() else { return "" }
        return first == last ? "p. \(first)" : "pp. \(first)–\(last)"
    }
}

/// The Today row from Ash Wednesday to Easter Sunday. Fridays of Lent open the Stations; Holy Week opens its page.
struct LentTodayRow: View {
    let now: Date
    let timeZone: TimeZone
    let onNavigate: (CompanionRoute) -> Void

    @Environment(JohnRuntime.self) private var runtime

    var body: some View {
        if runtime.lentContent() != nil, let day = LentCalendar.day(on: now, timeZone: timeZone) {
            if day.isHolyWeek {
                ContentActionRow(title: "Holy Week · \(day.dayTitle ?? "")",
                                 subtitle: day.isEasterSunday ? "Victimae paschali and the Collect of Easter" : "The day’s readings, the Fathers and the Missal’s prayers",
                                 imageName: day.isEasterSunday ? "glorious-1" : "sorrowful-5") { onNavigate(.holyWeek) }
                    .accessibilityIdentifier("today-holy-week")
            } else if day.isFriday {
                ContentActionRow(title: "Friday: the Stations of the Cross",
                                 subtitle: "\(day.weekLabel) · St Alphonsus Liguori",
                                 imageName: "stations-01") { onNavigate(.stations) }
                    .accessibilityIdentifier("today-lent")
            } else {
                ContentActionRow(title: day.offset == 0 ? "Ash Wednesday: Lent with the Fathers" : "Lent with the Fathers",
                                 subtitle: "\(day.weekLabel) · The Gospel, the Fathers and the Collect",
                                 imageName: "sorrowful-1") { onNavigate(.lent) }
                    .accessibilityIdentifier("today-lent")
            }
        }
    }
}

/// A quoted text: an eyebrow, the paragraphs, and its book and page.
private struct LentTextPanel: View {
    let eyebrow: String
    var heading: String?
    let paragraphs: [String]
    var rubrics: [String] = []
    let source: String
    /// More paragraphs than this show "Read all" first.
    var collapseAfter = Int.max

    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var expanded = false
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        let collapsed = !expanded && paragraphs.count > collapseAfter
        ContentPanel {
            Text(eyebrow.uppercased())
                .font(JohnTypography.sans(11, weight: .medium)).tracking(2).foregroundStyle(colors.tint)
            if let heading {
                Text(heading)
                    .font(JohnTypography.sans(15, weight: .medium)).foregroundStyle(colors.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(rubrics.enumerated()), id: \.offset) { _, rubric in
                Text(rubric)
                    .font(JohnTypography.serif(15)).italic().foregroundStyle(colors.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array((collapsed ? Array(paragraphs.prefix(collapseAfter)) : paragraphs).enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(JohnTypography.serif(19))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "Lora-Regular", size: 19, targetLineHeight: 29))
                    .foregroundStyle(colors.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            if collapsed {
                Button("Read all") { expanded = true }
                    .font(JohnTypography.sans(15, weight: .medium))
                    .foregroundStyle(colors.tint)
                    .frame(minHeight: 44)
            }
            ContentMutedText(text: source)
        }
    }
}

/// The Lent page (`nrsv://lent`): the week, today's Gospel with the Fathers, the Collect, St Leo on Lent,
/// the Seven Penitential Psalms and the Stations.
struct LentView: View {
    let clock: () -> Date
    let timeZone: TimeZone

    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    @State private var readings: CalendarReadingsEntry?

    private var now: Date { clock() }

    var body: some View {
        let day = LentCalendar.day(on: now, timeZone: timeZone)
        let lent = runtime.lentContent()
        ContentPage(title: "Lent",
                    eyebrow: (day?.dayTitle ?? day?.weekLabel)?.uppercased() ?? "THE SEASON OF LENT",
                    subtitle: "Ash Wednesday to Holy Saturday") {
            if day != nil {
                ContentArtCard(artwork: "sorrowful-1", title: "Today’s readings",
                               subtitle: readings?.title ?? "The Mass readings of the day") {
                    router.push(.companion(.daily(dateKey: CompanionCalendar.dateKey(now, timeZone: timeZone))))
                }
                .accessibilityIdentifier("lent-readings")
                GospelFathersPanel(readings: readings, eyebrow: "TODAY’S GOSPEL, WITH THE FATHERS")
            } else if let ash = LentCalendar.ashWednesday(year: nextLentYear, timeZone: timeZone) {
                ContentMutedText(text: "Lent begins on Ash Wednesday, \(ash.formatted(Date.FormatStyle(date: .long, time: .omitted, locale: Locale(identifier: "en_GB"), timeZone: timeZone))).")
            }
            if let day, let lent, let collect = lent.collect(for: day) {
                LentTextPanel(eyebrow: "The Collect of the day", heading: collect.title, paragraphs: [collect.text],
                              source: "\(collect.book == "massEveryDay" ? LentText.massEveryDayShort : LentText.missalShort), p. \(collect.page)")
                    .accessibilityIdentifier("lent-collect")
            }
            if day?.isHolyWeek == true {
                ContentActionRow(title: "Holy Week", subtitle: "Palm Sunday to Easter Sunday: the Missal’s prayers for each day",
                                 imageName: "sorrowful-5") { router.push(.companion(.holyWeek)) }
            }
            ContentSectionTitle(title: day?.isPassiontide == true ? "St Leo the Great on the Passion" : "St Leo the Great on Lent",
                                detail: "Fourteen sermons from the library, free to read from Ash Wednesday to Easter Sunday.")
            ForEach(leoOrder(day), id: \.self) { index in
                ContentActionRow(title: LentText.leoTitles[index - LentCalendar.leoSections.lowerBound],
                                 subtitle: "St Leo the Great · Sermons", icon: "book-open") {
                    router.push(.workReader(workID: LentCalendar.leoWorkID, section: index))
                }
                .accessibilityIdentifier("lent-leo-\(index)")
            }
            ContentSectionTitle(title: "The Seven Penitential Psalms", detail: "Douay-Rheims, with the Vulgate’s numbering.")
            ForEach(lent?.penitentialPsalms ?? [6, 31, 37, 50, 101, 129, 142], id: \.self) { psalm in
                ContentActionRow(title: "Psalm \(psalm)", subtitle: LentText.psalmTitles[psalm], icon: "book-open") {
                    router.pushChapter(bookCode: "PSA", chapter: psalm, translation: .douayRheims)
                }
                .accessibilityIdentifier("lent-psalm-\(psalm)")
            }
            ContentSectionTitle(title: "Prayer")
            ContentActionRow(title: "The Stations of the Cross", subtitle: "St Alphonsus Liguori · Fourteen stations",
                             imageName: "stations-01") { router.push(.companion(.stations)) }
                .accessibilityIdentifier("lent-stations")
            ContentActionRow(title: "Fasting and abstinence", subtitle: "The rules of the United States bishops (USCCB)",
                             icon: "arrow-up-right") { openURL(LentText.fastingURL) }
        }
        .task {
            if let calendar = try? await runtime.companionRepository?.readings() {
                readings = CompanionCalendar.readings(for: now, from: calendar, timeZone: timeZone)
            }
        }
    }

    /// The year of the next Ash Wednesday, for the line shown outside Lent.
    private var nextLentYear: Int {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        let year = calendar.component(.year, from: now)
        guard let ash = LentCalendar.ashWednesday(year: year, timeZone: timeZone) else { return year }
        return now < ash ? year : year + 1
    }

    /// In Passiontide the sermons on the Passion come first.
    private func leoOrder(_ day: LentCalendar.Day?) -> [Int] {
        let all = Array(LentCalendar.leoSections)
        guard day?.isPassiontide == true || day?.isHolyWeek == true else { return all }
        return Array(all[6...]) + Array(all[..<6])
    }
}

/// The Holy Week page (`nrsv://holyweek`): today's day first, then the other days, each with the Missal's texts.
struct HolyWeekView: View {
    let clock: () -> Date
    let timeZone: TimeZone

    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @State private var readings: CalendarReadingsEntry?

    private var now: Date { clock() }

    var body: some View {
        let today = LentCalendar.day(on: now, timeZone: timeZone).flatMap { $0.isHolyWeek ? $0 : nil }
        let days = runtime.lentContent()?.holyWeek ?? []
        let ordered = today.map { day in days.filter { $0.key == day.key } + days.filter { $0.key != day.key } } ?? days
        ContentPage(title: "Holy Week", eyebrow: today?.dayTitle?.uppercased() ?? "PALM SUNDAY TO EASTER SUNDAY",
                    subtitle: "The prayers of the Roman Missal for each day") {
            if today != nil {
                ContentArtCard(artwork: today?.isEasterSunday == true ? "glorious-1" : "sorrowful-5", title: "Today’s readings",
                               subtitle: readings?.title ?? "The Mass readings of the day") {
                    router.push(.companion(.daily(dateKey: CompanionCalendar.dateKey(now, timeZone: timeZone))))
                }
                GospelFathersPanel(readings: readings, eyebrow: "TODAY’S GOSPEL, WITH THE FATHERS")
            }
            ForEach(ordered) { day in
                ContentSectionTitle(title: day.key == today?.key ? "Today: \(day.title)" : day.title)
                    .accessibilityIdentifier("holy-week-\(day.key)")
                if day.key == "good-fri" {
                    ContentActionRow(title: "The Stations of the Cross", subtitle: "St Alphonsus Liguori",
                                     imageName: "stations-12") { router.push(.companion(.stations)) }
                }
                ForEach(day.sections) { section in
                    LentTextPanel(eyebrow: section.title, paragraphs: section.paragraphs, rubrics: section.rubrics ?? [],
                                  source: "\(LentText.missalShort), \(LentText.pages(section.pages))",
                                  collapseAfter: 3)
                        .accessibilityIdentifier("holy-week-\(day.key)-\(section.id)")
                }
            }
            ContentMutedText(text: "From the Roman Missal in its 1926 English printing. These are prayers of the day, not a guide to the rite as it is celebrated now.")
        }
        .task {
            if let calendar = try? await runtime.companionRepository?.readings() {
                readings = CompanionCalendar.readings(for: now, from: calendar, timeZone: timeZone)
            }
        }
    }
}

/// The Stations of the Cross (`nrsv://stations`): the opening prayer, then one page for each station, then the closing.
struct StationsView: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var page = 0

    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        if let stations = runtime.lentContent()?.stations {
            let count = stations.stations.count + (stations.closing == nil ? 1 : 2)
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(0..<count, id: \.self) { index in
                        ScrollView { pageView(index, stations).frame(maxWidth: 620).padding(.horizontal, 20).padding(.vertical, 16).frame(maxWidth: .infinity) }
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                HStack {
                    Button { page = max(0, page - 1) } label: {
                        FeatherIcon(name: "chevron-left", size: 22, color: page == 0 ? colors.border : colors.tint).frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(page == 0)
                    .accessibilityLabel("Previous")
                    Spacer()
                    Text(label(page, stations))
                        .font(JohnTypography.sans(13)).foregroundStyle(colors.textDim)
                    Spacer()
                    Button { page = min(count - 1, page + 1) } label: {
                        FeatherIcon(name: "chevron-right", size: 22, color: page == count - 1 ? colors.border : colors.tint).frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(page == count - 1)
                    .accessibilityLabel("Next")
                }
                .padding(.horizontal, 16)
                .accessibilityIdentifier("stations-controls")
            }
            .background(colors.background)
            .navigationTitle("Stations of the Cross")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("The Stations are not available", systemImage: "cross")
        }
    }

    private func label(_ index: Int, _ stations: LentContent.Stations) -> String {
        if index == 0 { return "Opening prayer" }
        if index <= stations.stations.count { return "Station \(index) of \(stations.stations.count)" }
        return "Closing prayer"
    }

    @ViewBuilder
    private func pageView(_ index: Int, _ stations: LentContent.Stations) -> some View {
        if index == 0 {
            part(stations.opening)
        } else if index <= stations.stations.count {
            station(stations.stations[index - 1])
        } else if let closing = stations.closing {
            part(closing)
        }
    }

    private func part(_ part: LentContent.Part) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(part.title).font(JohnTypography.serif(28)).foregroundStyle(colors.text)
            ForEach(Array(part.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                bodyText(paragraph)
            }
            ContentMutedText(text: "St Alphonsus Liguori · \(LentText.manualShort), \(LentText.pages(part.pages))")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func station(_ station: LentContent.Station) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ContentArtwork(name: station.painting)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            if let credit = runtime.warmArtCredits[station.painting] {
                ContentMutedText(text: credit)
            }
            Text("STATION \(station.number)")
                .font(JohnTypography.sans(11, weight: .medium)).tracking(2).foregroundStyle(colors.tint)
            Text(station.title).font(JohnTypography.serif(26)).foregroundStyle(colors.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 6) {
                versicle("V.", station.versicle)
                versicle("R.", station.response)
            }
            bodyText(station.meditation)
            bodyText(station.prayer)
            Text(station.after).font(JohnTypography.serif(17)).italic().foregroundStyle(colors.textDim)
                .fixedSize(horizontal: false, vertical: true)
            Text(station.verse.joined(separator: "\n"))
                .font(JohnTypography.serif(17))
                .foregroundStyle(colors.text)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
            ContentMutedText(text: "St Alphonsus Liguori · \(LentText.manualShort), \(LentText.pages(station.pages))")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("station-\(station.number)")
    }

    private func versicle(_ mark: String, _ text: String) -> some View {
        (Text(mark + " ").foregroundStyle(colors.tint) + Text(text).foregroundStyle(colors.text))
            .font(JohnTypography.serif(18))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(JohnTypography.serif(19))
            .lineSpacing(ContentTypography.additionalSpacing(fontName: "Lora-Regular", size: 19, targetLineHeight: 29))
            .foregroundStyle(colors.text)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}
