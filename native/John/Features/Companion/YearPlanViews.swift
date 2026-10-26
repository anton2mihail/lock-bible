import SwiftUI
import UIKit
import JohnCore

/// "A Year with the Fathers" (2.3.0). One reading a day from the library through 2027. The plan is offered for the
/// new year but never called a resolution: the words "resolution", "goal", "challenge", "habit" and "streak" do not
/// appear here (failure Y8), and missed days are "open", never owed. All content shows in its final state, with no
/// entrance animation. Design: the "A Year with the Fathers: design polish" canvas (26 Oct 2026).
enum YearPlanText {
    static let name = "A Year with the Fathers"
    static let about = "One reading a day from the Fathers of the Church, 5 to 10 minutes. The readings follow the Church’s year."
    static let beforeYear = "Begins 1 January. One reading a day from the Fathers of the Church."
    static let footnote = "Every word is the Fathers’ own, from the library in John 1:1. Days 1 to 7 are free."
    static let lockedNotice = "Days 1 to 7 are free. Day 8 and every day after it come from the Fathers library."
    static let unlockNotice = "The first seven days are free. Day 8 and every day after it come from the Fathers library: 275 works, offline, yours to keep."
    static let finished = "Day 365. You read a year with the Fathers."
    static let throughTheYear: [(String, String)] = [
        ("January", "St Athanasius, On the Incarnation"),
        ("Lent", "St Leo on Lent; St Cyril to those preparing for Baptism"),
        ("Holy Week", "St Leo on the Passion, each day"),
        ("Summer", "St Augustine, Confessions"),
        ("Advent", "The Catena Aurea on Luke 1"),
    ]

    private static let months = ["January", "February", "March", "April", "May", "June", "July", "August",
                                 "September", "October", "November", "December"]
    static func monthName(_ month: Int) -> String { months[max(0, min(month - 1, 11))] }

    /// "5 February" for a `yyyy-MM-dd` key.
    static func date(_ key: String) -> String {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return key }
        return "\(parts[2]) \(monthName(parts[1]))"
    }

    /// "St Leo the Great, On Lent, I"; "The Didache, chapters I–VI" when the title is only the chapters.
    static func reading(_ day: YearPlan.Day) -> String {
        let title = day.title.hasPrefix("Chapter") ? day.title.prefix(1).lowercased() + day.title.dropFirst() : day.title
        return "\(day.author), \(title)"
    }

    /// "Three earlier days are open": missed days are offered, never counted against the reader.
    static func openDays(_ days: [Int]) -> (title: String, subtitle: String) {
        let words = ["One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"]
        let count = days.count <= 9 ? words[days.count - 1] : "\(days.count)"
        let title = days.count == 1 ? "One earlier day is open" : "\(count) earlier days are open"
        let shown = days.prefix(3).map(String.init)
        let list: String
        switch shown.count {
        case 1: list = "Day \(shown[0])"
        case 2: list = "Days \(shown[0]) and \(shown[1])"
        default: list = "Days \(shown[0]), \(shown[1]) and \(shown[2])"
        }
        let more = days.count > 3 ? " and \(days.count - 3) more" : ""
        return (title, "\(list)\(more), whenever you wish")
    }

    /// The season's painting, as on Today: Christmas, the Sorrowful Mysteries in Lent and Holy Week, and so on.
    static func artwork(season: String) -> String {
        switch season {
        case "christmas": "joyful-3"
        case "lent": "sorrowful-1"
        case "holy-week": "sorrowful-5"
        case "easter": "glorious-1"
        case "advent": "advent"
        default: "scripture"
        }
    }
}

/// Where the person is today, from the plan file and the reading progress file.
struct YearPlanStatus: Equatable {
    let plan: YearPlan
    let startKey: String?
    let joinedKey: String?
    let read: Set<Int>
    let reminder: ReadingReminderSettings
    let now: Date
    let timeZone: TimeZone

    var started: Bool { startKey != nil }
    var beforeYear: Bool { YearPlanSchedule.isBeforeYear(now, timeZone: timeZone) }
    /// Today's day in the person's plan (may be 0 or less before their start, and more than 365 after the end).
    var currentDay: Int? { startKey.map { YearPlanSchedule.dayNumber(startKey: $0, today: now, timeZone: timeZone) } }
    var joinDay: Int? { YearPlanSchedule.dayOfYear(now, timeZone: timeZone) }
    var missed: [Int] {
        guard let currentDay, let startKey else { return [] }
        let joinedAt = joinedKey.map { YearPlanSchedule.dayNumber(startKey: startKey, today: Self.noon($0, timeZone), timeZone: timeZone) } ?? 1
        return YearPlanSchedule.missedDays(read: read, today: currentDay, joinedAt: joinedAt)
    }

    /// The person's own date for a plan day: the 2027 date for "Join today", later for "Begin at Day 1".
    func personalKey(_ day: Int) -> String? {
        guard let startKey else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let date = calendar.date(byAdding: .day, value: day - 1, to: Self.noon(startKey, timeZone)) else { return nil }
        return ReadingProgressMath.dayKey(date, timeZone: timeZone)
    }

    /// The feast belongs to the 2027 date: shown only where the person's day falls on it.
    func feast(_ day: YearPlan.Day) -> String? {
        personalKey(day.day) == day.date ? day.feast : nil
    }

    /// Noon on a `yyyy-MM-dd` day, so the day count never falls across midnight.
    static func noon(_ key: String, _ zone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return Date() }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12)) ?? Date()
    }
}

@MainActor func loadYearPlanStatus(runtime: JohnRuntime, now: Date, timeZone: TimeZone) async -> YearPlanStatus? {
    guard let plan = runtime.yearPlan() else { return nil }
    let data = await runtime.readingProgress()
    return YearPlanStatus(plan: plan, startKey: data.yearStartKey, joinedKey: data.yearJoinedKey, read: data.yearDaysRead,
                          reminder: data.yearReminder ?? ReadingReminderSettings(), now: now, timeZone: timeZone)
}

/// A bundled painting (`App/Artwork/<name>.jpg`), shown at its final state.
private struct YearArtwork: View {
    let name: String
    var body: some View {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("App/Artwork/\(name).jpg"),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Color.clear
        }
    }
}

/// The Today card. Before 1 January it invites; once started it names the day and today's reading.
struct YearPlanTodayCard: View {
    let now: Date
    let timeZone: TimeZone
    let onNavigate: (CompanionRoute) -> Void

    @Environment(JohnRuntime.self) private var runtime
    @State private var status: YearPlanStatus?

    var body: some View {
        Group {
            if let status, let content = content(status) {
                ContentActionRow(title: content.title, subtitle: content.subtitle, imageName: content.artwork) {
                    onNavigate(content.route)
                }
                .accessibilityIdentifier("today-year-plan")
            } else {
                Color.clear.frame(height: 0).accessibilityHidden(true)
            }
        }
        .task(id: "\(runtime.progressRevision)|\(CompanionCalendar.dateKey(now, timeZone: timeZone))") {
            status = await loadYearPlanStatus(runtime: runtime, now: now, timeZone: timeZone)
        }
    }

    private func content(_ status: YearPlanStatus) -> (title: String, subtitle: String, artwork: String, route: CompanionRoute)? {
        let christmas = YearPlanText.artwork(season: "christmas")
        if let current = status.currentDay {
            if current < 1 {
                let begins = YearPlanText.date(status.startKey ?? YearPlanSchedule.yearStartKey)
                let subtitle = status.reminder.enabled ? "Begins \(begins). Your reminder is set." : "Begins \(begins). One reading a day."
                return (YearPlanText.name, subtitle, christmas, .yearPlan)
            }
            guard let day = status.plan.day(current) else { return nil }
            let art = YearPlanText.artwork(season: day.season)
            if status.read.contains(current) {
                let tomorrow = status.plan.day(current + 1).map { "Tomorrow: \(YearPlanText.reading($0))" } ?? YearPlanText.finished
                return ("Day \(current) · Read", tomorrow, art, .yearPlan)
            }
            let heading = status.feast(day).map { "Day \(current) · \($0)" } ?? "Day \(current) · \(YearPlanText.name)"
            return (heading, "\(YearPlanText.reading(day)) · \(day.minutes) min", art, .yearDay(current))
        }
        if status.beforeYear { return (YearPlanText.name, YearPlanText.beforeYear, christmas, .yearPlan) }
        guard let join = status.joinDay, let day = status.plan.day(join) else { return nil }
        return (YearPlanText.name, "Day \(join) today: \(YearPlanText.reading(day))", YearPlanText.artwork(season: day.season), .yearPlan)
    }
}

/// The start screen and, once started, the plan: today's reading, open earlier days, the reminder, and the year.
struct YearPlanView: View {
    let clock: () -> Date
    let timeZone: TimeZone

    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var status: YearPlanStatus?
    @State private var message: String?
    @State private var saving = false
    @State private var confirmRestart = false
    @State private var openMonth: String?

    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        ContentPage(title: YearPlanText.name, eyebrow: eyebrow, subtitle: status?.started == true ? nil : YearPlanText.about) {
            if let status {
                if status.started { planContent(status) } else { startContent(status) }
            } else {
                ContentMutedText(text: "The plan could not be opened on this device.")
            }
        }
        .task(id: runtime.progressRevision) {
            status = await loadYearPlanStatus(runtime: runtime, now: clock(), timeZone: timeZone)
            if openMonth == nil, let status, let current = status.currentDay {
                openMonth = status.personalKey(max(1, min(current, YearPlanSchedule.dayCount))).map { String($0.prefix(7)) }
            }
        }
    }

    private var eyebrow: String {
        guard let status else { return "2027" }
        if let current = status.currentDay {
            if current < 1 { return "BEGINS \(YearPlanText.date(status.startKey ?? "").uppercased())" }
            if current > YearPlanSchedule.dayCount { return "365 DAYS" }
            return "DAY \(current) OF 365"
        }
        return status.beforeYear ? "BEGINS 1 JANUARY 2027" : "2027"
    }

    // MARK: Start

    @ViewBuilder private func startContent(_ status: YearPlanStatus) -> some View {
        ContentPanel {
            eyebrowText("THROUGH THE YEAR")
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                ForEach(YearPlanText.throughTheYear, id: \.0) { item in
                    GridRow {
                        Text(item.0).font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
                        Text(item.1).font(JohnTypography.sans(14)).foregroundStyle(colors.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        if status.beforeYear {
            VStack(spacing: 10) {
                ContentEmphasisButton(title: "Remind me on 1 January") {
                    Task {
                        await runtime.startYearPlan(startKey: YearPlanSchedule.yearStartKey)
                        await saveReminder(ReadingReminderSettings(enabled: true, hour: status.reminder.hour, minute: status.reminder.minute))
                    }
                }
                .accessibilityIdentifier("year-remind-january")
                ContentMutedText(text: "Each day at \(timeText(status.reminder)). You can change the time later.")
                    .multilineTextAlignment(.center)
            }
            ContentActionRow(title: "Begin now", subtitle: firstDaySubtitle(status)) {
                Task { await runtime.startYearPlan(startKey: YearPlanSchedule.startKey(.beginAtDayOne, today: clock(), timeZone: timeZone)) }
            }
            .accessibilityIdentifier("year-begin-now")
        } else {
            let suggested = YearPlanSchedule.suggestedStart(clock(), timeZone: timeZone)
            startOption(suggested, status, emphasized: true)
            startOption(suggested == .joinToday ? .beginAtDayOne : .joinToday, status, emphasized: false)
        }
        if let message { ContentMutedText(text: message) }
        ContentMutedText(text: YearPlanText.footnote)
    }

    @ViewBuilder private func startOption(_ option: YearPlanSchedule.Start, _ status: YearPlanStatus, emphasized: Bool) -> some View {
        let start: () -> Void = {
            Task { await runtime.startYearPlan(startKey: YearPlanSchedule.startKey(option, today: clock(), timeZone: timeZone)) }
        }
        switch option {
        case .joinToday:
            if let join = status.joinDay, let day = status.plan.day(join) {
                let detail = "Day \(join): \(YearPlanText.reading(day)). The seasons match the Church’s year."
                if emphasized {
                    VStack(spacing: 10) {
                        ContentEmphasisButton(title: "Join today", action: start).accessibilityIdentifier("year-join-today")
                        ContentMutedText(text: detail).multilineTextAlignment(.center)
                    }
                } else {
                    ContentActionRow(title: "Join today", subtitle: detail, onPress: start).accessibilityIdentifier("year-join-today")
                }
            }
        case .beginAtDayOne:
            if emphasized {
                VStack(spacing: 10) {
                    ContentEmphasisButton(title: "Begin at Day 1", action: start).accessibilityIdentifier("year-begin-day-one")
                    ContentMutedText(text: firstDaySubtitle(status)).multilineTextAlignment(.center)
                }
            } else {
                ContentActionRow(title: "Begin at Day 1", subtitle: firstDaySubtitle(status), onPress: start)
                    .accessibilityIdentifier("year-begin-day-one")
            }
        }
    }

    private func firstDaySubtitle(_ status: YearPlanStatus) -> String {
        guard let day = status.plan.day(1) else { return "Day 1 today" }
        return "Day 1 today: \(YearPlanText.reading(day))"
    }

    // MARK: Plan

    @ViewBuilder private func planContent(_ status: YearPlanStatus) -> some View {
        let current = status.currentDay ?? 1
        if current > YearPlanSchedule.dayCount {
            ContentPanel { Text(YearPlanText.finished).font(JohnTypography.serif(20)).foregroundStyle(colors.text) }
        } else if current < 1, let first = status.plan.day(1) {
            todayPanel(first, eyebrow: "DAY 1 · \(YearPlanText.date(status.startKey ?? "").uppercased())",
                       detail: "\(first.minutes) min · You can read it now, or wait for the day.",
                       button: "Read Day 1")
        } else if let day = status.plan.day(current) {
            todayPanel(day, eyebrow: (["TODAY", status.feast(day)?.uppercased()].compactMap { $0 }).joined(separator: " · "),
                       detail: "\(day.minutes) min" + (status.read.contains(current) ? " · Read" : ""),
                       button: status.read.contains(current) ? "Read again" : "Read today’s reading")
            if let first = status.missed.first {
                let open = YearPlanText.openDays(status.missed)
                ContentActionRow(title: open.title, subtitle: open.subtitle) { router.push(.companion(.yearDay(first))) }
                    .accessibilityIdentifier("year-catch-up")
            }
        }
        if !runtime.fathers.isUnlocked, current >= 6 { ContentMutedText(text: YearPlanText.lockedNotice) }
        reminderPanel(status)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("The year").font(JohnTypography.sans(20, weight: .semibold)).foregroundStyle(colors.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(status.read.count) of 365 read").font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
            }
            // Static: it shows where the reader is, with no animation and no count of days in a row.
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(colors.separator)
                    Capsule().fill(colors.tint).frame(width: proxy.size.width * CGFloat(status.read.count) / 365)
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)
        }
        VStack(alignment: .leading, spacing: 0) {
            ForEach(months(status), id: \.key) { month in
                monthSection(month, status)
            }
        }
        Button { confirmRestart = true } label: {
            Text("Start the plan again").font(JohnTypography.sans(16)).foregroundStyle(colors.tint)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .accessibilityIdentifier("year-restart")
        .confirmationDialog("Start the plan again?", isPresented: $confirmRestart, titleVisibility: .visible) {
            Button("Start again") { Task { await runtime.startYearPlan(startKey: nil) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You choose again how to begin. The days you read stay marked.")
        }
    }

    private func todayPanel(_ day: YearPlan.Day, eyebrow: String, detail: String, button: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            YearArtwork(name: YearPlanText.artwork(season: day.season))
                .frame(height: 150).frame(maxWidth: .infinity).clipped()
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                eyebrowText(eyebrow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.author).font(JohnTypography.sans(15)).foregroundStyle(colors.textDim)
                    Text(day.title).font(JohnTypography.serif(24)).foregroundStyle(colors.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ContentMutedText(text: detail)
                ContentEmphasisButton(title: button) { router.push(.companion(.yearDay(day.day))) }
                    .accessibilityIdentifier("year-read-today")
                    .padding(.top, 4)
            }
            .padding(EdgeInsets(top: 18, leading: 20, bottom: 20, trailing: 20))
        }
        .background(colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(colors.separator, lineWidth: 1) }
    }

    private func eyebrowText(_ text: String) -> some View {
        Text(text).font(JohnTypography.sans(11, weight: .medium)).tracking(2).foregroundStyle(colors.tint)
    }

    @ViewBuilder private func reminderPanel(_ status: YearPlanStatus) -> some View {
        ContentPanel {
            Toggle(isOn: Binding(get: { status.reminder.enabled },
                                 set: { enabled in Task { await saveReminder(ReadingReminderSettings(enabled: enabled, hour: status.reminder.hour, minute: status.reminder.minute)) } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily reminder").font(JohnTypography.sans(16)).foregroundStyle(colors.text)
                    Text(status.reminder.enabled ? "\(timeText(status.reminder)) · names the day’s reading" : "Off")
                        .font(JohnTypography.sans(13)).foregroundStyle(colors.textDim)
                }
            }
            .tint(colors.tint).disabled(saving)
            .accessibilityIdentifier("year-reminder")
            if status.reminder.enabled {
                DatePicker("Reminder time", selection: Binding(get: { reminderDate(status.reminder) },
                                                               set: { date in Task { await saveReminder(reminderSettings(from: date)) } }),
                           displayedComponents: .hourAndMinute)
                    .font(JohnTypography.sans(16)).foregroundStyle(colors.text)
                    .disabled(saving)
                    .accessibilityIdentifier("year-reminder-time")
            }
            if let message { ContentMutedText(text: message) }
        }
    }

    // MARK: The year, by the person's own months

    private struct Month { let key: String; let title: String; let days: [YearPlan.Day] }

    private func months(_ status: YearPlanStatus) -> [Month] {
        var result: [Month] = []
        let firstYear = status.personalKey(1).map { String($0.prefix(4)) }
        for day in status.plan.days {
            guard let key = status.personalKey(day.day) else { continue }
            let monthKey = String(key.prefix(7))
            if result.last?.key != monthKey {
                let parts = monthKey.split(separator: "-").compactMap { Int($0) }
                let year = String(monthKey.prefix(4))
                let title = YearPlanText.monthName(parts.count == 2 ? parts[1] : 1) + (year == firstYear ? "" : " \(year)")
                result.append(Month(key: monthKey, title: title, days: []))
            }
            let last = result.removeLast()
            result.append(Month(key: last.key, title: last.title, days: last.days + [day]))
        }
        return result
    }

    @ViewBuilder private func monthSection(_ month: Month, _ status: YearPlanStatus) -> some View {
        let read = month.days.filter { status.read.contains($0.day) }.count
        VStack(alignment: .leading, spacing: 0) {
            Button {
                openMonth = openMonth == month.key ? nil : month.key
            } label: {
                HStack {
                    Text(month.title).font(JohnTypography.sans(17, weight: .semibold)).foregroundStyle(colors.text)
                    Spacer()
                    Text("\(read) of \(month.days.count)").font(JohnTypography.sans(13)).foregroundStyle(colors.textDim)
                    Image(systemName: openMonth == month.key ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(colors.textDim)
                }
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("year-month-\(month.key)")
            if openMonth == month.key {
                ForEach(month.days) { day in dayRow(day, status) }
                    .padding(.bottom, 2)
            }
            Divider().overlay(colors.separator)
        }
    }

    private func dayRow(_ day: YearPlan.Day, _ status: YearPlanStatus) -> some View {
        let isRead = status.read.contains(day.day)
        let isToday = day.day == status.currentDay
        let locked = YearPlanSchedule.isLocked(day: day.day, freeDays: status.plan.freeDays, libraryUnlocked: runtime.fathers.isUnlocked)
        let date = status.personalKey(day.day).map(YearPlanText.date) ?? ""
        let label = (isToday ? "Today · " : "") + "Day \(day.day) · " + (isToday ? (status.feast(day) ?? date) : date)
        let symbol = isRead ? "checkmark.circle" : (isToday ? "circle.fill" : (locked ? "lock" : "circle"))
        return Button { router.push(.companion(.yearDay(day.day))) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: isToday && !isRead ? 10 : 17))
                    .frame(width: 20)
                    .foregroundStyle(isRead || isToday ? colors.tint : colors.textDim)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(JohnTypography.sans(12, weight: isToday ? .medium : .regular))
                        .foregroundStyle(isToday ? colors.tint : colors.textDim)
                    Text(YearPlanText.reading(day)).font(JohnTypography.sans(15)).foregroundStyle(colors.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, isToday ? 10 : 0)
            .background(isToday ? colors.tint.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, isToday ? -10 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(isToday ? "Today, " : "")Day \(day.day), \(YearPlanText.reading(day))\(isRead ? ", read" : "")\(locked ? ", in the Fathers library" : "")")
        .accessibilityIdentifier("year-day-\(day.day)")
    }

    // MARK: Reminder

    /// The picker and the scheduler (`.autoupdatingCurrent`) use the same time zone.
    private var reminderCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }
    private func reminderDate(_ value: ReadingReminderSettings) -> Date {
        reminderCalendar.date(bySettingHour: value.hour, minute: value.minute, second: 0, of: Date()) ?? Date()
    }
    private func reminderSettings(from date: Date) -> ReadingReminderSettings {
        let c = reminderCalendar.dateComponents([.hour, .minute], from: date)
        return ReadingReminderSettings(enabled: true, hour: c.hour ?? 8, minute: c.minute ?? 0)
    }
    private func timeText(_ value: ReadingReminderSettings) -> String {
        reminderDate(value).formatted(date: .omitted, time: .shortened)
    }

    private func saveReminder(_ value: ReadingReminderSettings) async {
        saving = true
        message = nil
        do { _ = try await runtime.saveYearReminder(value) }
        catch { message = error.localizedDescription }
        saving = false
    }
}

/// One day's reading: the paragraphs of the day from the library, an end mark, then "Mark as read" and the next day.
/// Day 8 and later show the library purchase page for a person without the library (failure Y4).
struct YearDayView: View {
    let day: Int
    let clock: () -> Date
    let timeZone: TimeZone

    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var blocks: [YearReadingBlock] = []
    @State private var attribution: String?
    @State private var status: YearPlanStatus?
    @State private var failed = false

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var entry: YearPlan.Day? { runtime.yearPlan()?.day(day) }
    private var isRead: Bool { status?.read.contains(day) == true }
    private var isToday: Bool { status?.currentDay == day }
    private var locked: Bool {
        YearPlanSchedule.isLocked(day: day, freeDays: runtime.yearPlan()?.freeDays ?? 7, libraryUnlocked: runtime.fathers.isUnlocked)
    }

    var body: some View {
        ContentPage(title: entry?.title ?? YearPlanText.name, eyebrow: eyebrow, subtitle: entry.map { "\($0.author) · \($0.minutes) min" }) {
            if locked {
                FathersUnlockPanel(sampleNotice: YearPlanText.unlockNotice, title: "Continue the year")
            } else if failed {
                ContentMutedText(text: "This reading could not be opened. Try again, or open it in the library.")
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(blocks) { block in
                        switch block.kind {
                        case .heading:
                            Text(block.text).font(JohnTypography.sans(15, weight: .semibold)).foregroundStyle(colors.text)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                                .padding(.top, 6)
                        case .paragraph:
                            Text(block.text).font(readingFont).lineSpacing(6).foregroundStyle(colors.text)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                }
                .accessibilityIdentifier("year-day-text")
                if !blocks.isEmpty {
                    endMark
                    readControls
                }
            }
            if day < YearPlanSchedule.dayCount, let next = runtime.yearPlan()?.day(day + 1) {
                Button { router.push(.companion(.yearDay(next.day))) } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text((isToday ? "TOMORROW" : "NEXT") + " · DAY \(next.day)")
                                .font(JohnTypography.sans(12, weight: .medium)).tracking(1.4).foregroundStyle(colors.tint)
                            Text(YearPlanText.reading(next)).font(JohnTypography.sans(16, weight: .medium)).foregroundStyle(colors.text)
                                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                            Text("\(next.minutes) min").font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").foregroundStyle(colors.tint).accessibilityHidden(true)
                    }
                    .padding(.vertical, 14)
                    // A Divider in an overlay of a row turns vertical; a 1-point rule stays horizontal.
                    .overlay(alignment: .top) { Rectangle().fill(colors.separator).frame(height: 1) }
                    .overlay(alignment: .bottom) { Rectangle().fill(colors.separator).frame(height: 1) }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("year-next-day")
            }
            if let first = entry?.readings.first {
                Button { router.push(.workReader(workID: first.workId, section: first.section)) } label: {
                    Text("Open in the library").font(JohnTypography.sans(15)).foregroundStyle(colors.tint)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("year-open-library")
            }
            if let attribution, !locked { ContentMutedText(text: attribution) }
        }
        .task(id: "\(day)|\(runtime.fathers.isUnlocked)|\(runtime.progressRevision)") { await load() }
    }

    /// "DAY 41 · ASH WEDNESDAY" only when the person's day falls on the feast; else "DAY 41".
    private var eyebrow: String {
        guard let entry, let feast = status?.feast(entry) else { return "DAY \(day)" }
        return "DAY \(day) · \(feast.uppercased())"
    }

    private var readingFont: Font {
        let reading = preferences.reading
        let size: CGFloat = switch reading.textSize { case .small: 16; case .medium: 18; case .large: 21; case .extraLarge: 24 }
        return reading.typeface == .serif ? .custom("Georgia", size: size, relativeTo: .body) : JohnTypography.sans(size)
    }

    private var endMark: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                Rectangle().fill(colors.separator).frame(height: 1)
                Image(systemName: "cross").font(.system(size: 15, weight: .light)).foregroundStyle(colors.tint)
                Rectangle().fill(colors.separator).frame(height: 1)
            }
            .accessibilityHidden(true)
            Text(isToday ? "End of today’s reading" : "End of the reading")
                .font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
        }
        .padding(.top, 8)
    }

    @ViewBuilder private var readControls: some View {
        if isRead {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark").foregroundStyle(colors.tint).accessibilityHidden(true)
                    Text("Read").font(JohnTypography.sans(16, weight: .medium)).foregroundStyle(colors.text)
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(colors.card, in: RoundedRectangle(cornerRadius: 4))
                .overlay { RoundedRectangle(cornerRadius: 4).stroke(colors.border, lineWidth: 1) }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("year-read-state")
                Button("Mark as not read") { Task { await runtime.setYearDayRead(false, day: day) } }
                    .font(JohnTypography.sans(14)).foregroundStyle(colors.tint)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("year-mark-unread")
            }
        } else {
            ContentEmphasisButton(title: "Mark as read") { Task { await runtime.setYearDayRead(true, day: day) } }
                .accessibilityIdentifier("year-mark-read")
        }
    }

    private func load() async {
        status = await loadYearPlanStatus(runtime: runtime, now: clock(), timeZone: timeZone)
        guard let entry, !locked, blocks.isEmpty else { return }
        var result: [YearReadingBlock] = []
        do {
            for reading in entry.readings {
                let section = try await runtime.workSection(workID: reading.workId, index: reading.section)
                let upper = min(reading.toParagraph, section.paragraphs.count - 1)
                guard reading.fromParagraph <= upper else { continue }
                // One reading: the page title already names it, so the library's section title is not repeated.
                if reading.fromParagraph == 0, entry.readings.count > 1 {
                    result.append(.init(id: result.count, kind: .heading, text: section.title))
                }
                for text in section.paragraphs[reading.fromParagraph...upper] {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty || trimmed.allSatisfy({ "—–-".contains($0) }) { continue }
                    if trimmed == section.title.trimmingCharacters(in: .whitespacesAndNewlines) { continue }
                    result.append(.init(id: result.count, kind: YearReadingBlock.isHeading(trimmed) ? .heading : .paragraph, text: trimmed))
                }
            }
            blocks = result
            failed = result.isEmpty
        } catch {
            failed = true
        }
        if let catalog = await runtime.worksCatalog(),
           let collectionID = entry.readings.first.flatMap({ FathersLibraryAccess.collectionID(ofWork: $0.workId) }),
           let collection = catalog.collections.first(where: { $0.id == collectionID }) {
            attribution = collection.attribution
        }
    }
}

struct YearReadingBlock: Identifiable, Equatable {
    enum Kind { case heading, paragraph }
    let id: Int
    let kind: Kind
    let text: String

    /// A short line without closing punctuation is a heading, and so are "Chapter …" lines and the editor's numbered
    /// summaries in St Leo ("I. The benefits of abstinence …").
    static func isHeading(_ text: String) -> Bool {
        let words = text.split(whereSeparator: \.isWhitespace).count
        if words <= 25, text.range(of: #"^[IVXLC]+\.\s"#, options: .regularExpression) != nil { return true }
        guard words <= 14, let last = text.last else { return false }
        if text.hasPrefix("Chapter") || text.hasPrefix("Book") || text.hasPrefix("Lecture") { return true }
        return !".!?:;”\"’)".contains(last)
    }
}
