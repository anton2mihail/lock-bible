import SwiftUI

struct ConfessionView: View {
    let onClose: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var index = 0
    @State private var notes = ""
    @State private var notice = ""

    private var step: ConfessionStep { Self.steps[index] }
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        ContentPage(title: step.title,
                    eyebrow: "Prepare for Confession / \(index + 1) of \(Self.steps.count)",
                    subtitle: nil) {
            Text(step.body)
                .font(JohnTypography.sans(17))
                .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 17, targetLineHeight: 28))
                .foregroundStyle(colors.text)

            if index == 0 {
                ContentPanel {
                    ContentSectionTitle(title: "An examination of conscience",
                        detail: "Read slowly, in the light of God’s love. You can use these prompts without writing anything.")
                    ForEach(Self.examination, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(JohnTypography.sans(20, weight: .medium))
                                .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Medium", size: 20, targetLineHeight: 32))
                            ContentMutedText(text: section.scripture)
                            ForEach(section.questions, id: \.self) { question in
                                Text(question)
                                    .font(JohnTypography.sans(17))
                                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 17, targetLineHeight: 28))
                                    .foregroundStyle(colors.text)
                            }
                        }
                    }
                }
                Text("Private notes, if helpful")
                    .font(JohnTypography.sans(16, weight: .medium))
                    .foregroundStyle(colors.text)
                ContentInputField(placeholder: "These words will not be saved…", text: $notes,
                                  accessibilityLabel: "Temporary confession notes", multiline: true,
                                  disablesCorrection: true)
                ContentMutedText(text: "These notes are never saved by John 1:1. They are cleared when you leave this guide or put the app in the background.")
                if !notes.isEmpty {
                    ContentButton(title: "Clear notes now") { clearNotes() }
                }
            }

            if index == 2, !notes.isEmpty {
                ContentPanel {
                    ContentSectionTitle(title: "Your private notes")
                    Text(notes)
                        .font(JohnTypography.sans(16))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 16, targetLineHeight: 24))
                }
            }

            if index == 3 {
                ContentPanel {
                    ContentSectionTitle(title: "Act of Contrition")
                    Text(Self.actOfContrition)
                        .font(JohnTypography.serif(24))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "Lora-Regular", size: 24, targetLineHeight: 36))
                        .textSelection(.enabled)
                }
            }

            if !notice.isEmpty {
                Text(notice)
                    .font(JohnTypography.sans(16))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 16, targetLineHeight: 24))
                    .contentAnnouncement(notice)
            }

            ContentEmphasisButton(title: index == Self.steps.count - 1 ? "Finish & clear notes" : "Continue") {
                if index == Self.steps.count - 1 {
                    clearNotes()
                    onClose()
                } else {
                    index += 1
                }
            }
            if index > 0 {
                ContentButton(title: "Previous") { index -= 1 }
            }
            ContentMutedText(text: "Original preparation prompts, informed by the Ten Commandments, the Beatitudes, and USCCB guidance. Your priest can help with questions about your circumstances.")
            ContentButton(title: "USCCB preparation resources ↗") {
                clearNotes()
                guard let url = URL(string: Self.source) else { return }
                openURL(url) { accepted in
                    if !accepted {
                        notice = "The resources could not be opened. Please try again when connected."
                    }
                }
            }
        }
        .id(index)
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            clearNotes()
            notice = "Your private notes were cleared when you left the app."
        }
        .onDisappear { clearNotes() }
    }

    private func clearNotes() { notes = "" }

    private static let source = "https://www.usccb.org/prayer-and-worship/sacraments-and-sacramentals/penance/examinations-of-conscience"
    private static let actOfContrition = "O my God, I am heartily sorry for having offended Thee, and I detest all my sins because I dread the loss of heaven and the pains of hell, but most of all because they offend Thee, my God, who art all good and deserving of all my love. I firmly resolve, with the help of Thy grace, to confess my sins, to do penance, and to amend my life. Amen."

    private static let steps = [
        ConfessionStep(title: "Prepare", body: "Ask the Holy Spirit for honesty and trust. Reflect on your life since your last confession. These questions are a starting point; a priest can help you with anything you are unsure about."),
        ConfessionStep(title: "Begin with the priest", body: "Make the Sign of the Cross and say how long it has been since your last confession. If you are new or it has been a long time, say so. You can ask the priest to guide you."),
        ConfessionStep(title: "Confess your sins", body: "Name your sins simply and honestly. Confess all mortal sins you remember, including their kind and number as best you can. Listen to the priest’s counsel and receive the penance he gives you."),
        ConfessionStep(title: "Pray and receive absolution", body: "Express sorrow for your sins and your intention to turn away from them. Pray an Act of Contrition when invited. The priest gives absolution; respond Amen."),
        ConfessionStep(title: "Go in peace", body: "Thank God for his mercy. Complete your penance and take the next practical step toward reconciliation and a changed life."),
    ]

    private static let examination = [
        ExaminationSection(title: "Love of God", scripture: "Matthew 22:37–40", questions: [
            "Have I made space for prayer and worship, including Sunday Mass when I am able?",
            "Have I treated God’s name, sacred things, and other people’s faith with reverence?",
            "What has taken the place of God in my decisions?",
        ]),
        ExaminationSection(title: "Love of neighbor", scripture: "Matthew 25:35–40", questions: [
            "Have I harmed someone through anger, cruelty, gossip, or indifference?",
            "Have I been honest and fair in my work, promises, and use of money?",
            "Have I ignored someone’s need when I could reasonably help?",
        ]),
        ExaminationSection(title: "Love in daily life", scripture: "Matthew 5:1–12", questions: [
            "Have I honored the dignity of others in my relationships and sexual choices?",
            "Have I cared responsibly for the people entrusted to me?",
            "Where do I need to ask forgiveness, repair harm, or change a habit?",
        ]),
    ]
}

private struct ConfessionStep {
    let title: String
    let body: String
}

private struct ExaminationSection: Identifiable {
    let title: String
    let scripture: String
    let questions: [String]
    var id: String { title }
}
