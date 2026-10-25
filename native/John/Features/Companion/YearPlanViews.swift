import SwiftUI
import JohnCore

/// "A Year with the Fathers" (2.3.0). One reading a day from the library through 2027. The plan is offered for the
/// new year but never called a resolution: the words "resolution", "goal", "challenge", "habit" and "streak" do not
/// appear here (failure Y8). All content shows in its final state, with no entrance animation.
enum YearPlanText {
    static let name = "A Year with the Fathers"
    static let invitation = "Begin the year with the Fathers. One reading a day, from 1 January."
    static let about = "365 days, one reading a day, 5 to 10 minutes. The Fathers of the Church, in order through the year: in Lent, the Fathers on Lent; in Holy Week, on the Passion. Begin on 1 January, or join on any day."
    static let lockedNotice = "Days 1 to 7 are free. Continue the year with the Fathers library: Day 8 and every day after it."
    static let finished = "Day 365. You read a year with the Fathers."

    static func missed(_ firstMissed: Int) -> String {
        "You missed a few days. Read today’s reading, or catch up from Day \(firstMissed)."
    }

    static func date(_ key: String) -> String {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return key }
        let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September",
                      "October", "November", "December"]
        return "\(parts[2]) \(months[max(0, min(parts[1] - 1, 11))])"
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
    /// Noon on a `yyyy-MM-dd` day, so the day count never falls across midnight.
    static func date(_ key: String, _ zone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return Date() }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12)) ?? Date()
    }

    var missed: [Int] {
        guard let currentDay, let startKey else { return [] }
        let joinedAt = joinedKey.map { YearPlanSchedule.dayNumber(startKey: startKey, today: Self.date($0, timeZone), timeZone: timeZone) } ?? 1
        return YearPlanSchedule.missedDays(read: read, today: currentDay, joinedAt: joinedAt)
    }
}

/// The Today card. Before 1 January it invites; once started it names today's reading.
struct YearPlanTodayCard: View {
    let now: Date
    let timeZone: TimeZone
    let onNavigate: (CompanionRoute) -> Void

    @Environment(JohnRuntime.self) private var runtime
    @State private var status: YearPlanStatus?

    var body: some View {
        Group {
            if let status, let content = content(status) {
                ContentActionRow(title: content.title, subtitle: content.subtitle, imageName: "scripture") {
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

    private func content(_ status: YearPlanStatus) -> (title: String, subtitle: String, route: CompanionRoute)? {
        if let current = status.currentDay {
            if current < 1 {
                return (YearPlanText.name, "Begins on \(YearPlanText.date(status.startKey ?? YearPlanSchedule.yearStartKey)). One reading a day.", .yearPlan)
            }
            guard let day = status.plan.day(current) else { return nil }
            let done = status.read.contains(current) ? " · Read" : ""
            return ("Day \(current) · \(day.author)", "\(day.title) · \(day.minutes) min\(done)", .yearDay(current))
        }
        if status.beforeYear { return (YearPlanText.name, YearPlanText.invitation, .yearPlan) }
        guard let join = status.joinDay, let day = status.plan.day(join) else { return nil }
        return (YearPlanText.name, "Day \(join) today: \(day.author), \(day.title)", .yearPlan)
    }
}

@MainActor func loadYearPlanStatus(runtime: JohnRuntime, now: Date, timeZone: TimeZone) async -> YearPlanStatus? {
    guard let plan = runtime.yearPlan() else { return nil }
    let data = await runtime.readingProgress()
    return YearPlanStatus(plan: plan, startKey: data.yearStartKey, joinedKey: data.yearJoinedKey, read: data.yearDaysRead,
                          reminder: data.yearReminder ?? ReadingReminderSettings(), now: now, timeZone: timeZone)
}

/// The start screen and, once started, the plan: today's reading, catch-up, the reminder, and every day by month.
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
    @State private var openMonth: Int?

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
            if openMonth == nil, let status { openMonth = month(of: max(1, min(status.currentDay ?? status.joinDay ?? 1, 365)), in: status.plan) }
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
        if status.beforeYear {
            ContentEmphasisButton(title: "Remind me on 1 January") {
                Task {
                    await runtime.startYearPlan(startKey: YearPlanSchedule.yearStartKey)
                    await saveReminder(ReadingReminderSettings(enabled: true, hour: status.reminder.hour, minute: status.reminder.minute))
                }
            }
            .accessibilityIdentifier("year-remind-january")
            ContentActionRow(title: "Begin now", subtitle: firstDaySubtitle(status)) {
                Task { await runtime.startYearPlan(startKey: YearPlanSchedule.startKey(.beginAtDayOne, today: clock(), timeZone: timeZone)) }
            }
            .accessibilityIdentifier("year-begin-now")
        } else {
            let options: [YearPlanSchedule.Start] = YearPlanSchedule.suggestedStart(clock(), timeZone: timeZone) == .joinToday
                ? [.joinToday, .beginAtDayOne] : [.beginAtDayOne, .joinToday]
            ForEach(options, id: \.rawValue) { option in
                startRow(option, status)
            }
        }
        if let message { ContentMutedText(text: message) }
        ContentMutedText(text: "Every reading is the Fathers’ own words, from the library in John 1:1. Days 1 to 7 are free.")
    }

    @ViewBuilder private func startRow(_ option: YearPlanSchedule.Start, _ status: YearPlanStatus) -> some View {
        switch option {
        case .joinToday:
            if let join = status.joinDay, let day = status.plan.day(join) {
                ContentActionRow(title: "Join today", subtitle: "Day \(join): \(day.author), \(day.title). The seasons match the Church’s year.") {
                    Task { await runtime.startYearPlan(startKey: YearPlanSchedule.startKey(.joinToday, today: clock(), timeZone: timeZone)) }
                }
                .accessibilityIdentifier("year-join-today")
            }
        case .beginAtDayOne:
            ContentActionRow(title: "Begin at Day 1", subtitle: firstDaySubtitle(status)) {
                Task { await runtime.startYearPlan(startKey: YearPlanSchedule.startKey(.beginAtDayOne, today: clock(), timeZone: timeZone)) }
            }
            .accessibilityIdentifier("year-begin-day-one")
        }
    }

    private func firstDaySubtitle(_ status: YearPlanStatus) -> String {
        guard let day = status.plan.day(1) else { return "Day 1 today" }
        return "Day 1 today: \(day.author), \(day.title)"
    }

    // MARK: Plan

    @ViewBuilder private func planContent(_ status: YearPlanStatus) -> some View {
        let current = status.currentDay ?? 1
        if current > YearPlanSchedule.dayCount {
            ContentPanel { Text(YearPlanText.finished).font(JohnTypography.serif(20)).foregroundStyle(colors.text) }
        } else if current < 1, let first = status.plan.day(1) {
            ContentPanel {
                eyebrowText("DAY 1 · \(YearPlanText.date(status.startKey ?? "").uppercased())")
                Text("\(first.author), \(first.title)").font(JohnTypography.serif(20)).foregroundStyle(colors.text)
                    .fixedSize(horizontal: false, vertical: true)
                ContentMutedText(text: "You can read it now, or wait for the day.")
                ContentActionRow(title: "Read Day 1", subtitle: "\(first.minutes) min") { router.push(.companion(.yearDay(1))) }
            }
        } else if let day = status.plan.day(current) {
            ContentPanel {
                // The feast belongs to the 2027 date; show it only when today is that date.
                let feast = day.date == CompanionCalendar.dateKey(status.now, timeZone: status.timeZone) ? day.feast : nil
                eyebrowText(["TODAY", feast?.uppercased()].compactMap { $0 }.joined(separator: " · "))
                Text(day.author).font(JohnTypography.sans(15, weight: .medium)).foregroundStyle(colors.textDim)
                Text(day.title).font(JohnTypography.serif(22)).foregroundStyle(colors.text)
                    .fixedSize(horizontal: false, vertical: true)
                ContentMutedText(text: "\(day.minutes) min" + (status.read.contains(current) ? " · Read" : ""))
                ContentEmphasisButton(title: status.read.contains(current) ? "Read it again" : "Read today’s reading") {
                    router.push(.companion(.yearDay(current)))
                }
                .accessibilityIdentifier("year-read-today")
            }
            if let first = status.missed.first, status.missed.count > 0 {
                ContentActionRow(title: YearPlanText.missed(first), subtitle: "\(status.missed.count) day\(status.missed.count == 1 ? "" : "s") to catch up") {
                    router.push(.companion(.yearDay(first)))
                }
                .accessibilityIdentifier("year-catch-up")
            }
        }
        if !runtime.fathers.isUnlocked { ContentMutedText(text: YearPlanText.lockedNotice) }
        reminderPanel(status)
        ContentSectionTitle(title: "The year", detail: "\(status.read.count) of 365 read")
        ForEach(1...12, id: \.self) { month in
            monthSection(month, status)
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

    private func eyebrowText(_ text: String) -> some View {
        Text(text).font(JohnTypography.sans(11, weight: .medium)).tracking(2).foregroundStyle(colors.tint)
    }

    @ViewBuilder private func reminderPanel(_ status: YearPlanStatus) -> some View {
        ContentPanel {
            Toggle(isOn: Binding(get: { status.reminder.enabled },
                                 set: { enabled in Task { await saveReminder(ReadingReminderSettings(enabled: enabled, hour: status.reminder.hour, minute: status.reminder.minute)) } })) {
                Text("Daily reminder").font(JohnTypography.sans(16)).foregroundStyle(colors.text)
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
                ContentMutedText(text: "Each reminder names that day’s reading.")
            }
            if let message { ContentMutedText(text: message) }
        }
    }

    @ViewBuilder private func monthSection(_ month: Int, _ status: YearPlanStatus) -> some View {
        let days = status.plan.days.filter { Int($0.date.dropFirst(5).prefix(2)) == month }
        let read = days.filter { status.read.contains($0.day) }.count
        VStack(alignment: .leading, spacing: 0) {
            Button {
                openMonth = openMonth == month ? nil : month
            } label: {
                HStack {
                    Text(monthName(month)).font(JohnTypography.sans(17, weight: .semibold)).foregroundStyle(colors.text)
                    Spacer()
                    Text("\(read) of \(days.count)").font(JohnTypography.sans(13)).foregroundStyle(colors.textDim)
                    Image(systemName: openMonth == month ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(colors.textDim)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("year-month-\(month)")
            if openMonth == month {
                ForEach(days) { day in dayRow(day, status) }
            }
            Divider().overlay(colors.separator)
        }
    }

    private func dayRow(_ day: YearPlan.Day, _ status: YearPlanStatus) -> some View {
        Button { router.push(.companion(.yearDay(day.day))) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: status.read.contains(day.day) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(status.read.contains(day.day) ? colors.tint : colors.textDim)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day \(day.day) · \(YearPlanText.date(day.date))" + (day.feast.map { " · \($0)" } ?? ""))
                        .font(JohnTypography.sans(12)).foregroundStyle(day.day == status.currentDay ? colors.tint : colors.textDim)
                    Text("\(day.author), \(day.title)").font(JohnTypography.sans(15)).foregroundStyle(colors.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Day \(day.day), \(day.author), \(day.title)\(status.read.contains(day.day) ? ", read" : "")")
        .accessibilityIdentifier("year-day-\(day.day)")
    }

    private func month(of day: Int, in plan: YearPlan) -> Int? {
        plan.day(day).flatMap { Int($0.date.dropFirst(5).prefix(2)) }
    }

    private func monthName(_ month: Int) -> String {
        ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
         "November", "December"][month - 1]
    }

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

    private func saveReminder(_ value: ReadingReminderSettings) async {
        saving = true
        message = nil
        do { _ = try await runtime.saveYearReminder(value) }
        catch { message = error.localizedDescription }
        saving = false
    }
}

/// One day's reading: the paragraphs of the day from the library, then "Mark as read". Day 8 and later show the
/// library purchase page for a person without the library (failure Y4).
struct YearDayView: View {
    let day: Int
    let clock: () -> Date
    let timeZone: TimeZone

    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var blocks: [YearReadingBlock] = []
    @State private var attribution: String?
    @State private var read = false
    @State private var failed = false

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var entry: YearPlan.Day? { runtime.yearPlan()?.day(day) }
    private var locked: Bool {
        YearPlanSchedule.isLocked(day: day, freeDays: runtime.yearPlan()?.freeDays ?? 7, libraryUnlocked: runtime.fathers.isUnlocked)
    }

    var body: some View {
        ContentPage(title: entry?.title ?? YearPlanText.name, eyebrow: eyebrow, subtitle: entry.map { "\($0.author) · \($0.minutes) min" }) {
            if locked {
                FathersUnlockPanel(sampleNotice: YearPlanText.lockedNotice)
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
                    ContentEmphasisButton(title: read ? "Read · Mark as not read" : "Mark as read") {
                        read.toggle()
                        let value = read
                        Task { await runtime.setYearDayRead(value, day: day) }
                    }
                    .accessibilityIdentifier("year-mark-read")
                }
                if let attribution { ContentMutedText(text: attribution) }
            }
            if let first = entry?.readings.first {
                ContentActionRow(title: "Open in the library", subtitle: entry?.work) {
                    router.push(.workReader(workID: first.workId, section: first.section))
                }
                .accessibilityIdentifier("year-open-library")
            }
            if day < YearPlanSchedule.dayCount, let next = runtime.yearPlan()?.day(day + 1) {
                ContentActionRow(title: "Next: Day \(next.day)", subtitle: "\(next.author), \(next.title)") {
                    router.push(.companion(.yearDay(next.day)))
                }
                .accessibilityIdentifier("year-next-day")
            }
        }
        .task(id: "\(day)|\(runtime.fathers.isUnlocked)") { await load() }
    }

    private var eyebrow: String {
        guard let entry else { return "DAY \(day)" }
        return (["DAY \(day)", YearPlanText.date(entry.date).uppercased(), entry.feast?.uppercased()].compactMap { $0 })
            .joined(separator: " · ")
    }

    private var readingFont: Font {
        let reading = preferences.reading
        let size: CGFloat = switch reading.textSize { case .small: 16; case .medium: 18; case .large: 21; case .extraLarge: 24 }
        return reading.typeface == .serif ? .custom("Georgia", size: size, relativeTo: .body) : JohnTypography.sans(size)
    }

    private func load() async {
        read = await runtime.readingProgress().yearDaysRead.contains(day)
        guard let entry, !locked else { return }
        var result: [YearReadingBlock] = []
        do {
            for reading in entry.readings {
                let section = try await runtime.workSection(workID: reading.workId, index: reading.section)
                let upper = min(reading.toParagraph, section.paragraphs.count - 1)
                guard reading.fromParagraph <= upper else { continue }
                if reading.fromParagraph == 0 { result.append(.init(id: result.count, kind: .heading, text: section.title)) }
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

    /// A short line without closing punctuation is a heading ("Chapter IV.—Various Precepts" is not, so it reads as text).
    static func isHeading(_ text: String) -> Bool {
        let words = text.split(whereSeparator: \.isWhitespace).count
        guard words <= 14, let last = text.last else { return false }
        if text.hasPrefix("Chapter") || text.hasPrefix("Book") || text.hasPrefix("Lecture") { return true }
        return !".!?:;”\"’)".contains(last)
    }
}
