import SwiftUI
import JohnCore

/// The result of the Today lookup for "The Fathers on today's Gospel" (2.2.0).
struct GospelFathersCard: Equatable {
    let reference: String
    let entry: CommentaryEntry
    /// One comment from the Catena Aurea; nil for chapter-level commentary (other Fathers on Luke and John).
    let excerpt: GospelFathers.Excerpt?
    /// The collection's author, for chapter-level entries ("St John Chrysostom").
    let author: String
}

/// "The Fathers on today's Gospel": one comment from the Catena Aurea, or the Father who preached on the chapter.
/// The button opens the section in the library (first section free, the rest with the Fathers purchase).
struct GospelFathersPanel: View {
    let readings: CalendarReadingsEntry?
    var eyebrow = "THE FATHERS ON TODAY’S GOSPEL"

    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var card: GospelFathersCard?

    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        Group {
            if let card {
                ContentPanel {
                    Text(eyebrow)
                        .font(JohnTypography.sans(11, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(colors.tint)
                    if let excerpt = card.excerpt {
                        Text("“\(excerpt.text)”")
                            .font(JohnTypography.serif(20))
                            .lineSpacing(ContentTypography.additionalSpacing(fontName: "Lora-Regular", size: 20, targetLineHeight: 30))
                            .foregroundStyle(colors.text)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("today-fathers-excerpt")
                        ContentMutedText(text: "\(excerpt.father) · Catena Aurea, \(card.entry.sectionTitle)")
                    } else {
                        Text("\(card.author) on today’s Gospel")
                            .font(JohnTypography.serif(20))
                            .foregroundStyle(colors.text)
                            .fixedSize(horizontal: false, vertical: true)
                        ContentMutedText(text: "\(card.entry.workTitle) · \(card.entry.sectionTitle)")
                    }
                    ContentActionRow(title: "Read the Fathers on this Gospel", subtitle: card.reference) {
                        router.push(.workReader(workID: card.entry.workID, section: card.entry.sectionIndex))
                    }
                    .accessibilityIdentifier("today-fathers-open")
                }
            } else {
                // An empty Group would never start the task below.
                Color.clear.frame(height: 0).accessibilityHidden(true)
            }
        }
        .task(id: readings) {
            card = await runtime.gospelFathers(for: readings)
        }
    }
}

/// The Advent card on Today, from the first Sunday of Advent to 24 December. From 17 December it shows that
/// evening's O Antiphon.
struct AdventTodayCard: View {
    let now: Date
    let timeZone: TimeZone
    let onOpen: () -> Void

    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        if let week = AdventCalendar.week(on: now, timeZone: timeZone) {
            let antiphon = AdventCalendar.antiphon(on: now, timeZone: timeZone)
            ContentActionRow(title: antiphon.map { "\($0.title): tonight’s O Antiphon" } ?? "Advent with the Fathers",
                             subtitle: "\(ordinal(week)) week of Advent · The Gospel, the Fathers and the O Antiphons",
                             imageName: "joyful-1", onPress: onOpen)
                .accessibilityIdentifier("today-advent")
        }
    }

    private func ordinal(_ n: Int) -> String { ["First", "Second", "Third", "Fourth"][max(0, min(n - 1, 3))] }
}

/// The Advent page (`nrsv://advent`, and the Today card): the week, today's Gospel with the Fathers,
/// Rorate caeli and the O Antiphons.
struct AdventView: View {
    let clock: () -> Date
    let timeZone: TimeZone

    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var readings: CalendarReadingsEntry?
    @State private var rorate: String?

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var now: Date { clock() }

    var body: some View {
        let week = AdventCalendar.week(on: now, timeZone: timeZone)
        let today = AdventCalendar.antiphon(on: now, timeZone: timeZone)
        ContentPage(title: "Advent",
                    eyebrow: week.map { "WEEK \($0) OF ADVENT" } ?? "THE SEASON OF ADVENT",
                    subtitle: "Make ready the way of the Lord.") {
            ContentArtCard(artwork: "advent", title: "Today’s readings",
                           subtitle: readings?.title ?? "The Mass readings of the day") {
                router.push(.companion(.daily(dateKey: CompanionCalendar.dateKey(now, timeZone: timeZone))))
            }
            .accessibilityIdentifier("advent-readings")
            GospelFathersPanel(readings: readings, eyebrow: "TODAY’S GOSPEL, WITH THE FATHERS")
            ContentPanel {
                Text("RORATE CAELI")
                    .font(JohnTypography.sans(11, weight: .medium)).tracking(2).foregroundStyle(colors.tint)
                Text(rorate ?? "Drop down dew, ye heavens, from above, and let the clouds rain the just: let the earth be opened, and bud forth a saviour.")
                    .font(JohnTypography.serif(20))
                    .foregroundStyle(colors.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                ContentMutedText(text: "Isaiah 45:8 · Douay-Rheims")
            }
            ContentSectionTitle(title: "The O Antiphons")
            ContentMutedText(text: "Sung at Vespers on the seven evenings before Christmas Eve, from 17 December.")
            ForEach(AdventCalendar.antiphons, id: \.day) { antiphon in
                ContentPanel {
                    HStack(alignment: .firstTextBaseline) {
                        Text(antiphon.title)
                            .font(JohnTypography.sans(17, weight: .semibold))
                            .foregroundStyle(antiphon.day == today?.day ? colors.tint : colors.text)
                        Spacer(minLength: 8)
                        Text("\(antiphon.day) December" + (antiphon.day == today?.day ? " · Tonight" : ""))
                            .font(JohnTypography.sans(12))
                            .foregroundStyle(colors.textDim)
                    }
                    Text(antiphon.english)
                        .font(JohnTypography.serif(18))
                        .foregroundStyle(colors.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    Text(antiphon.latin)
                        .font(JohnTypography.serif(15))
                        .italic()
                        .foregroundStyle(colors.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .accessibilityIdentifier("advent-antiphon-\(antiphon.day)")
            }
            ContentMutedText(text: "The antiphons in Latin and English are from \(AdventCalendar.source). Public domain.")
        }
        .task {
            if let calendar = try? await runtime.companionRepository?.readings() {
                readings = CompanionCalendar.readings(for: now, from: calendar, timeZone: timeZone)
            }
            if let passage = await runtime.passage(translation: .douayRheims, bookCode: "ISA", chapter: 45, startVerse: "8", endVerse: "8") {
                rorate = passage.verses.first?.text
            }
        }
    }
}
