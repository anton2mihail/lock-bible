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
        LectioStep(title: "Read slowly", name: "Lectio", prompt: "Read the passage once, then again. Notice a word or phrase that catches your attention. Let the words arrive without rushing to explain them."),
        LectioStep(title: "Stay with a word", name: "Meditatio", prompt: "Return to the word or phrase that stayed with you. What does it reveal about God? Where does it meet your life today? You do not need to find a perfect answer."),
        LectioStep(title: "Speak to God", name: "Oratio", prompt: "Respond in your own words. Offer gratitude, a question, an intention, or something difficult to say. Speak as honestly as you can."),
        LectioStep(title: "Rest in his presence", name: "Contemplatio", prompt: "Let the words settle. Stay quietly with God. When your attention wanders, gently return. You may use a minute of silence or remain here as long as you wish."),
        LectioStep(title: "Carry it into your day", name: "Live the Word", prompt: "Choose one small response: a kindness, a conversation, an apology, a moment of trust. Let this time of prayer continue in the way you live."),
    ]
}

private struct LectioStep {
    let title: String
    let name: String
    let prompt: String
}
