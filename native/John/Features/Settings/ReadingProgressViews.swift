import SwiftUI
import JohnCore

/// A progress ring. It draws at its final value on the first frame. It never animates by itself.
struct ProgressRing: View {
    let fraction: Double
    var size: CGFloat = 64
    var lineWidth: CGFloat = 7
    let colors: JohnColors

    var body: some View {
        ZStack {
            Circle().stroke(colors.border, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(1, max(0, fraction))))
                .stroke(colors.tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((fraction * 100).rounded()))%")
                .font(JohnTypography.sans(size * 0.22, weight: .medium))
                .foregroundStyle(colors.text)
                .minimumScaleFactor(0.6)
        }
        .frame(width: size, height: size)
        .transaction { $0.animation = nil }
        .accessibilityElement(children: .ignore)
    }
}

/// The counts that the progress views need, loaded from the saved file and the book list.
struct ReadingProgressSnapshot: Equatable {
    var data = ReadingProgressData()
    var counts: [String: Int] = [:]

    var totalChapters: Int { counts.values.reduce(0, +) }
    var overall: Double { ReadingProgressMath.fraction(read: data.totalRead(counts: counts), total: totalChapters) }
    func readCount(_ book: String) -> Int {
        guard let count = counts[book] else { return 0 }
        return data.readChapters(book).filter { (1...max(1, count)).contains($0) }.count
    }
    func fraction(_ book: String) -> Double { ReadingProgressMath.fraction(read: readCount(book), total: counts[book] ?? 0) }
}

@MainActor
func loadReadingProgress(runtime: JohnRuntime, translation: TranslationID) async -> ReadingProgressSnapshot {
    async let data = runtime.readingProgress()
    async let books = runtime.books(translation: translation)
    let loadedBooks = await books
    return ReadingProgressSnapshot(
        data: await data,
        counts: Dictionary(loadedBooks.map { ($0.code, $0.chapterCount) }, uniquingKeysWith: { first, _ in first }))
}

/// The Today card: rings and today's plan assignment.
struct ReadingTodayCard: View {
    let now: Date
    let timeZone: TimeZone

    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var snapshot = ReadingProgressSnapshot()
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    private var plan: ReadingPlan? { snapshot.data.planID.flatMap(ReadingPlan.plan(id:)) }
    private var showsRings: Bool { plan != nil || snapshot.data.totalRead(counts: snapshot.counts) > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ContentSectionTitle(title: "Your reading")
            if let plan, let startKey = snapshot.data.planStartKey {
                assignment(plan: plan, startKey: startKey)
            } else {
                ContentPanel {
                    Text("Read John a little each day")
                        .font(JohnTypography.sans(16, weight: .medium)).foregroundStyle(colors.text)
                    ForEach(ReadingPlan.all) { item in
                        Button { Task { await runtime.startReadingPlan(item.id, now: now, timeZone: timeZone) } } label: {
                            Text("Start: \(item.title)")
                                .font(JohnTypography.sans(15, weight: .medium))
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("today-plan-start-\(item.id)")
                    }
                }
            }
            // 2.1.1: a new reader sees no empty "0%" rings. They appear once a plan starts or a chapter is read.
            if showsRings {
            ContentPanel {
                HStack(spacing: 24) {
                    ringColumn(fraction: snapshot.overall, title: "All books",
                               detail: "\(snapshot.data.totalRead(counts: snapshot.counts)) of \(snapshot.totalChapters)",
                               id: "progress-ring-overall")
                    ringColumn(fraction: snapshot.fraction("JHN"), title: "John",
                               detail: "\(snapshot.readCount("JHN")) of \(snapshot.counts["JHN"] ?? 21)",
                               id: "progress-ring-john")
                    Spacer(minLength: 0)
                }
            }
            }
        }
        .task(id: runtime.progressRevision) {
            snapshot = await loadReadingProgress(runtime: runtime, translation: preferences.translation)
        }
    }

    @ViewBuilder private func assignment(plan: ReadingPlan, startKey: String) -> some View {
        let day = ReadingProgressMath.dayIndex(startKey: startKey, today: now, timeZone: timeZone)
        let chapters = plan.chapters(forDay: day)
        let finished = day >= plan.days
        let read = snapshot.data.readChapters(plan.bookCode)
        let done = !chapters.isEmpty && chapters.allSatisfy(read.contains)
        let label = chapters.count > 1 ? "\(plan.bookName) \(chapters.first ?? 1)–\(chapters.last ?? 1)"
                                       : "\(plan.bookName) \(chapters.first ?? 1)"
        ContentPanel {
            Text("\(plan.title.uppercased())  /  DAY \(min(day + 1, plan.days)) OF \(plan.days)")
                .font(JohnTypography.sans(11, weight: .medium)).tracking(2).foregroundStyle(colors.tint)
            Text(done ? "\(label) — read" : "Today: \(label)")
                .font(JohnTypography.title(24)).foregroundStyle(colors.text)
                .accessibilityIdentifier("today-plan-assignment")
            HStack {
                Button {
                    router.openReader(bookCode: plan.bookCode, chapter: chapters.first ?? 1, translation: preferences.translation)
                } label: {
                    Text(done ? "Read again" : "Read now").font(JohnTypography.sans(15, weight: .medium))
                        .frame(minHeight: 44).padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("today-plan-open")
                Button {
                    Task { await runtime.startReadingPlan(nil) }
                } label: {
                    Text(finished ? "Finish plan" : "Stop plan").font(JohnTypography.sans(15))
                        .frame(minHeight: 44).padding(.horizontal, 8)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("today-plan-stop")
            }
        }
    }

    private func ringColumn(fraction: Double, title: String, detail: String, id: String) -> some View {
        VStack(spacing: 6) {
            ProgressRing(fraction: fraction, colors: colors)
            Text(title).font(JohnTypography.sans(13, weight: .medium)).foregroundStyle(colors.text)
            Text(detail).font(JohnTypography.sans(12)).foregroundStyle(colors.textDim)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) reading progress")
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent, \(detail) chapters")
        .accessibilityIdentifier(id)
    }
}

/// The Settings section: reminder opt-in, plan, and reset.
struct ReadingProgressSettings: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var data = ReadingProgressData()
    @State private var message: String?
    @State private var saving = false
    @State private var saveTask: Task<Void, Never>?
    @State private var confirmReset = false
    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var reminder: ReadingReminderSettings { data.reminder ?? ReadingReminderSettings() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(get: { reminder.enabled },
                                 set: { save(ReadingReminderSettings(enabled: $0, hour: reminder.hour, minute: reminder.minute, timeSensitive: reminder.timeSensitive)) })) {
                Text("Daily reading reminder").font(JohnTypography.sans(16)).foregroundStyle(colors.text)
            }
            .tint(colors.tint).disabled(saving)
            .accessibilityIdentifier("settings-reading-reminder")
            if reminder.enabled {
                DatePicker("Reminder time", selection: Binding(get: { date(reminder) },
                                                               set: { save(settings(from: $0)) }),
                           displayedComponents: .hourAndMinute)
                    .font(JohnTypography.sans(16)).foregroundStyle(colors.text)
                    .disabled(saving)
                    .accessibilityIdentifier("settings-reading-reminder-time")
                Toggle(isOn: Binding(get: { reminder.timeSensitive == true },
                                     set: { save(ReadingReminderSettings(enabled: true, hour: reminder.hour, minute: reminder.minute, timeSensitive: $0)) })) {
                    Text("Time Sensitive").font(JohnTypography.sans(16)).foregroundStyle(colors.text)
                }
                .tint(colors.tint).disabled(saving)
                .accessibilityIdentifier("settings-reading-reminder-time-sensitive")
                Text("A Time Sensitive reminder can show while a Focus is on.")
                    .font(JohnTypography.sans(13)).foregroundStyle(colors.textDim)
            }
            if let message {
                Text(message).font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
            }
            Button(role: .destructive) { confirmReset = true } label: {
                Text("Reset reading progress").font(JohnTypography.sans(16))
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier("settings-reset-progress")
            .confirmationDialog("Reset reading progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { Task { await runtime.resetReadingProgress() } }
                    .accessibilityIdentifier("settings-reset-progress-confirm")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears chapters read and your plan. Your notes and saved items stay.")
            }
        }
        .task(id: runtime.progressRevision) { data = await runtime.readingProgress() }
    }

    /// The picker and the scheduler (`.autoupdatingCurrent`) use the same time zone.
    private var reminderCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }
    private func date(_ value: ReadingReminderSettings) -> Date {
        reminderCalendar.date(bySettingHour: value.hour, minute: value.minute, second: 0, of: Date()) ?? Date()
    }
    private func settings(from date: Date) -> ReadingReminderSettings {
        let c = reminderCalendar.dateComponents([.hour, .minute], from: date)
        return ReadingReminderSettings(enabled: true, hour: c.hour ?? 8, minute: c.minute ?? 0, timeSensitive: reminder.timeSensitive)
    }
    private func save(_ value: ReadingReminderSettings) {
        saveTask?.cancel()
        saving = true
        message = nil
        saveTask = Task {
            do { _ = try await runtime.saveReadingReminder(value) }
            catch { if !Task.isCancelled { message = error.localizedDescription } }
            guard !Task.isCancelled else { return }
            data = await runtime.readingProgress()
            saving = false
        }
    }
}

/// A static mesh gradient for Today (E28). Reduce Transparency or Increase Contrast gives a solid color.
struct TodayMeshBackground: View {
    let colors: JohnColors
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        if reduceTransparency || contrast == .increased {
            colors.background
        } else {
            let dark = colorScheme == .dark
            // The tint mixes in at a low strength, so body text keeps its contrast.
            let accent = colors.tint.opacity(dark ? 0.16 : 0.12)
            let base = colors.background
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.55, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ], colors: [
                accent, base, base,
                base, accent.opacity(0.6), base,
                base, base, accent,
            ])
            .background(base)
            .accessibilityHidden(true)
        }
    }
}
