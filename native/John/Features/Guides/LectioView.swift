import SwiftUI
import JohnCore

struct LectioView: View {
    let initialPassage: PassageSelection?
    let onClose: () -> Void
    let onOpenReader: (PassageSelection) -> Void
    let onOpenBible: () -> Void
    let clock: () -> Date

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var passage: PassageSelection?
    @State private var translationAttribution = ""
    @State private var loadFailed = false
    @State private var stepIndex = 0
    @State private var deadline: Date?
    @State private var seconds = 0
    @State private var timerFinishCount = 0

    init(initialPassage: PassageSelection? = nil, clock: @escaping () -> Date = Date.init,
         onClose: @escaping () -> Void, onOpenReader: @escaping (PassageSelection) -> Void,
         onOpenBible: @escaping () -> Void) {
        self.initialPassage = initialPassage
        self.clock = clock
        self.onClose = onClose
        self.onOpenReader = onOpenReader
        self.onOpenBible = onOpenBible
        _passage = State(initialValue: initialPassage)
    }

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var step: LectioStep { Self.steps[stepIndex] }

    var body: some View {
        Group {
            if let passage {
                guide(passage)
            } else {
                ContentPage(title: "Pray with Scripture", eyebrow: nil, subtitle: nil) {
                    ContentMutedText(text: loadFailed
                        ? "Choose a passage in the Bible reader, then select Pray."
                        : "Loading a passage for prayer…")
                    ContentButton(title: "Open the Bible", action: onOpenBible)
                }
            }
        }
        .task(id: initialPassage?.id.legacyKey ?? "current") { await loadPassageIfNeeded() }
        .task(id: deadline) { await runTimer() }
        .sensoryFeedback(.success, trigger: timerFinishCount)
        .onChange(of: deadline) { _, _ in syncLiveActivity() }
        .onChange(of: stepIndex) { _, _ in syncLiveActivity() }
        .background {
            Color.clear.frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("liveActivityState")
                .accessibilityLabel(PrayerActivityController.shared.status.rawValue)
        }
        .onChange(of: deadline != nil) { _, _ in updateIdleTimer() }
        .onChange(of: scenePhase) { _, _ in updateIdleTimer() }
        .onDisappear {
            deadline = nil
            PrayerActivityController.shared.end()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    /// The Live Activity runs during the quiet minute. It ends when the timer ends, finishes, or the user leaves.
    private func syncLiveActivity() {
        guard let deadline, passage != nil else {
            PrayerActivityController.shared.end()
            return
        }
        PrayerActivityController.shared.startOrUpdate(
            kind: .lectio, title: "Lectio divina",
            state: .init(stepTitle: step.title, stepIndex: stepIndex, stepCount: Self.steps.count, endDate: deadline))
    }

    /// The screen must not lock during the silent minute. Every other state restores the system default.
    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = deadline != nil && scenePhase == .active
    }

    private func guide(_ selection: PassageSelection) -> some View {
        ContentPage(title: step.title, eyebrow: "Lectio divina / \(stepIndex + 1) of \(Self.steps.count)",
                    subtitle: passageReference(selection)) {
            ContentPanel {
                Text(step.name)
                    .font(JohnTypography.sans(11))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 11, targetLineHeight: 18))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(colors.tint)
                Text(step.prompt)
                    .font(JohnTypography.sans(17))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 17, targetLineHeight: 28))
                    .foregroundStyle(colors.text)
                ContentMutedText(text: "Pope Benedict XVI, Verbum Domini, 87")
            }

            if stepIndex == 3 {
                ContentPanel {
                    Text(deadline != nil ? "\(seconds)s of quiet" : (seconds == 0 ? "A moment of stillness" : "Rest here for a while"))
                        .font(JohnTypography.serif(24))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "Lora-Regular", size: 24, targetLineHeight: 36))
                        .foregroundStyle(colors.text)
                        .numericChange(seconds, countsDown: true)
                    ContentButton(title: deadline != nil ? "End the timer" : "Begin one quiet minute") {
                        if deadline != nil {
                            deadline = nil
                            seconds = 0
                        } else {
                            seconds = 60
                            deadline = clock().addingTimeInterval(60)
                        }
                    }
                    ContentMutedText(text: "No sound or vibration. Continue whenever you are ready.")
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(selection.scriptureText)
                    .font(JohnTypography.serif(24))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "Lora-Regular", size: 24, targetLineHeight: 36))
                    .foregroundStyle(colors.text)
                    .textSelection(.enabled)
                ContentMutedText(text: "\(passageReference(selection)) · \(translationLabel(selection.translationID))")
            }

            VStack(spacing: 16) {
                ContentEmphasisButton(title: stepIndex == Self.steps.count - 1 ? "Finish prayer" : "Continue") {
                    deadline = nil
                    if stepIndex == Self.steps.count - 1 {
                        onClose()
                    } else {
                        stepIndex += 1
                    }
                }
                if stepIndex > 0 {
                    ContentButton(title: "Previous step") {
                        deadline = nil
                        stepIndex -= 1
                    }
                }
            }
            ContentMutedText(text: translationAttribution)
        }
        .id(stepIndex)
    }

    @MainActor private func loadPassageIfNeeded() async {
        if let initialPassage {
            passage = initialPassage
            translationAttribution = await runtime.translationAttribution(initialPassage.translationID)
            loadFailed = false
            return
        }
        guard let verse = runtime.today.verse,
              let translation = TranslationID(rawValue: preferences.translation.rawValue),
              let value = await runtime.passage(translation: translation, bookCode: verse.bookCode,
                                                chapter: verse.chapter, startVerse: verse.verseLabel,
                                                endVerse: verse.verseLabel) else {
            loadFailed = true
            return
        }
        guard !Task.isCancelled else { return }
        passage = value
        translationAttribution = await runtime.translationAttribution(value.translationID)
        guard !Task.isCancelled else { return }
        loadFailed = false
    }

    @MainActor private func runTimer() async {
        guard let deadline else { return }
        while !Task.isCancelled {
            let remaining = max(0, Int(ceil(deadline.timeIntervalSince(clock()))))
            seconds = remaining
            if remaining == 0 {
                self.deadline = nil
                timerFinishCount += 1
                return
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    private func passageReference(_ value: PassageSelection) -> String {
        let first = value.startVerse.rawValue
        let last = value.endVerse.rawValue
        return first == last ? "\(value.bookName) \(value.chapter):\(first)" : "\(value.bookName) \(value.chapter):\(first)–\(last)"
    }

    private func translationLabel(_ translation: TranslationID) -> String {
        switch translation {
        case .webCE: "WEB-CE"
        case .douayRheims: "DRB"
        case .vulgate: "VUL"
        }
    }

    private static let steps = [
        LectioStep(title: "Read slowly", name: "Lectio", prompt: "It opens with the reading (lectio) of a text, which leads to a desire to understand its true content: what does the biblical text say in itself? Without this, there is always a risk that the text will become a pretext for never moving beyond our own ideas."),
        LectioStep(title: "Stay with a word", name: "Meditatio", prompt: "Next comes meditation (meditatio), which asks: what does the biblical text say to us? Here, each person, individually but also as a member of the community, must let himself or herself be moved and challenged."),
        LectioStep(title: "Speak to God", name: "Oratio", prompt: "Following this comes prayer (oratio), which asks the question: what do we say to the Lord in response to his word? Prayer, as petition, intercession, thanksgiving and praise, is the primary way by which the word transforms us."),
        LectioStep(title: "Rest in his presence", name: "Contemplatio", prompt: "Finally, lectio divina concludes with contemplation (contemplatio), during which we take up, as a gift from God, his own way of seeing and judging reality, and ask ourselves what conversion of mind, heart and life is the Lord asking of us?"),
        LectioStep(title: "Carry it into your day", name: "Actio", prompt: "We do well also to remember that the process of lectio divina is not concluded until it arrives at action (actio), which moves the believer to make his or her life a gift for others in charity."),
    ]
}

private struct LectioStep {
    let title: String
    let name: String
    let prompt: String
}
