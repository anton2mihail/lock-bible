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
                .font(JohnTypography.serif(20))
                .lineSpacing(ContentTypography.additionalSpacing(fontName: "Lora-Regular", size: 20, targetLineHeight: 32))
                .foregroundStyle(colors.text)
                .textSelection(.enabled)
            ContentMutedText(text: step.source)

            if index == 0 {
                ContentPanel {
                    ContentSectionTitle(title: "An examination of conscience")
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
            ContentMutedText(text: "Texts are quoted from the Catechism of the Catholic Church and from Scripture (WEB-CE). Your priest can help with questions about your circumstances.")
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
        ConfessionStep(title: "Prepare",
                       body: "“The reception of this sacrament ought to be prepared for by an examination of conscience made in the light of the Word of God.”",
                       source: "Catechism of the Catholic Church, §1454"),
        ConfessionStep(title: "The sacrament of Penance",
                       body: "“Those who approach the sacrament of Penance obtain pardon from God’s mercy for the offense committed against him, and are, at the same time, reconciled with the Church which they have wounded by their sins and which by charity, by example, and by prayer labors for their conversion.”",
                       source: "Catechism of the Catholic Church, §1422"),
        ConfessionStep(title: "Confess your sins",
                       body: "Confession to a priest is an essential part of the sacrament of Penance: “All mortal sins of which penitents after a diligent self-examination are conscious must be recounted by them in confession, even if they are most secret and have been committed against the last two precepts of the Decalogue; for these sins sometimes wound the soul more grievously and are more dangerous than those which are committed openly.”",
                       source: "Catechism of the Catholic Church, §1456"),
        ConfessionStep(title: "Contrition",
                       body: "Among the penitent’s acts contrition occupies first place. Contrition is “sorrow of the soul and detestation for the sin committed, together with the resolution not to sin again.”",
                       source: "Catechism of the Catholic Church, §1451"),
        ConfessionStep(title: "Absolution",
                       body: "God, the Father of mercies,\nthrough the death and the resurrection of his Son\nhas reconciled the world to himself\nand sent the Holy Spirit among us\nfor the forgiveness of sins;\nthrough the ministry of the Church\nmay God give you pardon and peace,\nand I absolve you from your sins in the name of the Father, and of the Son and of the Holy Spirit.",
                       source: "The formula of absolution, quoted in the Catechism of the Catholic Church, §1449"),
    ]

    private static let examination = [
        ExaminationSection(title: "The Ten Commandments",
                           scripture: "A traditional catechetical formula · Catechism of the Catholic Church", questions: [
            "I am the LORD your God: you shall not have strange Gods before me.",
            "You shall not take the name of the LORD your God in vain.",
            "Remember to keep holy the LORD’S Day.",
            "Honor your father and your mother.",
            "You shall not kill.",
            "You shall not commit adultery.",
            "You shall not steal.",
            "You shall not bear false witness against your neighbor.",
            "You shall not covet your neighbor’s wife.",
            "You shall not covet your neighbor’s goods.",
        ]),
        ExaminationSection(title: "The great commandments", scripture: "Matthew 22:37, 39 · WEB-CE", questions: [
            "You shall love the Lord your God with all your heart, with all your soul, and with all your mind.",
            "You shall love your neighbor as yourself.",
        ]),
        ExaminationSection(title: "The Beatitudes", scripture: "Matthew 5:3–10 · WEB-CE", questions: [
            "Blessed are the poor in spirit, for theirs is the Kingdom of Heaven.",
            "Blessed are those who mourn, for they shall be comforted.",
            "Blessed are the gentle, for they shall inherit the earth.",
            "Blessed are those who hunger and thirst for righteousness, for they shall be filled.",
            "Blessed are the merciful, for they shall obtain mercy.",
            "Blessed are the pure in heart, for they shall see God.",
            "Blessed are the peacemakers, for they shall be called children of God.",
            "Blessed are those who have been persecuted for righteousness’ sake, for theirs is the Kingdom of Heaven.",
        ]),
    ]
}

private struct ConfessionStep {
    let title: String
    let body: String
    let source: String
}

private struct ExaminationSection: Identifiable {
    let title: String
    let scripture: String
    let questions: [String]
    var id: String { title }
}
