import SwiftUI
import JohnCore

struct RosaryGuideView: View {
    let requestedSet: String?
    let clock: () -> Date
    let timeZone: TimeZone
    let onClose: () -> Void

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @State private var guide: RosaryGuideSession?
    @State private var credits: [String: String] = [:]
    @State private var loadFailed = false
    @State private var stepIndex = 0
    @State private var repetitionIndex = 0
    @State private var complete = false

    init(requestedSet: String? = nil, clock: @escaping () -> Date = Date.init,
         timeZone: TimeZone = .autoupdatingCurrent, onClose: @escaping () -> Void) {
        self.requestedSet = requestedSet
        self.clock = clock
        self.timeZone = timeZone
        self.onClose = onClose
    }

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var session: RosaryGuideSession? { guide }
    private var steps: [RosaryGuideStep] { session?.steps ?? [] }
    private var step: RosaryGuideStep? { steps.indices.contains(stepIndex) ? steps[stepIndex] : nil }
    private var groupLabels: [String] { session?.groupLabels ?? [] }
    private var totalActions: Int { steps.reduce(0) { $0 + $1.repetitions } }
    private var completedBefore: Int { steps.prefix(stepIndex).reduce(0) { $0 + $1.repetitions } }
    private var completedActions: Int { complete ? totalActions : completedBefore + repetitionIndex }
    private var progressValue: Int { totalActions > 0 ? Int((Double(completedActions) / Double(totalActions) * 100).rounded()) : 0 }
    private var showBeadLabels: Bool { groupLabels.count <= 5 }

    var body: some View {
        Group {
            if complete, let session {
                completion(session)
            } else if let session, let step {
                guide(session, step)
            } else {
                emptyState
            }
        }
        .task(id: requestedSet ?? "suggested") { await loadSession() }
        // One light tap for each bead the user completes. A step back also taps.
        .sensoryFeedback(.impact(weight: .light), trigger: completedActions)
    }

    private var emptyState: some View {
        RosaryGuidePage {
            if loadFailed {
                ContentUnavailableView {
                    Label("Guide unavailable", systemImage: "circle.dotted")
                } description: {
                    Text("This Rosary guide is not available right now.")
                }
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            }
        }
    }

    private func guide(_ session: RosaryGuideSession, _ step: RosaryGuideStep) -> some View {
        let currentGroup = step.mysteryIndex.flatMap { groupLabels.indices.contains($0) ? groupLabels[$0] : nil }
        let image = step.prayer == nil ? artName(sessionID: session.id, index: step.mysteryIndex) : nil
        let creditKey = creditName(sessionID: session.id, index: step.mysteryIndex)
        let credit = creditKey.flatMap { credits[$0] }
        let currentRepetition = repetitionIndex + 1
        let buttonTitle = nextButtonTitle(session: session, step: step)

        return RosaryGuidePage {
            HStack(spacing: 12) {
                VStack(alignment: .center, spacing: 2) {
                    Text(session.shortTitle)
                        .font(JohnTypography.sans(14, weight: .semibold))
                        .foregroundStyle(colors.text)
                        .lineLimit(1)
                    Text(step.eyebrow)
                        .font(JohnTypography.sans(12))
                        .foregroundStyle(colors.textDim)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                Text("\(progressValue)%")
                    .font(JohnTypography.sans(14, weight: .semibold))
                    .foregroundStyle(colors.tint)
                    .numericChange(progressValue)
            }
            .frame(minHeight: 48)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(colors.separator)
                    Capsule().fill(colors.tint).frame(width: proxy.size.width * CGFloat(progressValue) / 100)
                }
            }
            .frame(height: 4)
            .accessibilityElement()
            .accessibilityLabel("Progress")
            .accessibilityValue("\(progressValue) percent")

            HStack(alignment: .top, spacing: 8) {
                ForEach(Array(groupLabels.enumerated()), id: \.offset) { index, label in
                    let active = step.mysteryIndex == index
                    let prayed = step.mysteryIndex.map { index < $0 } ?? false
                    VStack(spacing: 6) {
                        Text(prayed ? "✓" : String(index + 1))
                            .font(JohnTypography.sans(12, weight: .semibold))
                            .foregroundStyle((active || prayed) ? colors.background : colors.textDim)
                            .minimumScaleFactor(0.8)
                            .frame(width: 34, height: 34)
                            .background((active || prayed) ? colors.tint : colors.card, in: Circle())
                            .overlay(Circle().stroke(colors.border, lineWidth: 1 / displayScale))
                        if showBeadLabels {
                            Text(label.replacingOccurrences(of: #"^The "#, with: "", options: .regularExpression))
                                .font(JohnTypography.sans(12))
                                .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 12, targetLineHeight: 14))
                                .foregroundStyle(active ? colors.tint : colors.textDim)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(session.id == "seven-sorrows" ? "The seven sorrows" : "Rosary decades")

            if let image {
                VStack(spacing: 8) {
                ContentArtwork(name: image)
                    .scaledToFill()
                    .aspectRatio(1.7, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityLabel(currentGroup ?? "Rosary mystery")
                if let credit {
                    Text(credit)
                        .font(JohnTypography.sans(12))
                        .foregroundStyle(colors.textDim)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                }
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                Text(step.eyebrow.uppercased())
                    .font(JohnTypography.sans(12, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(colors.tint)
                Text(step.title)
                    .font(JohnTypography.sans(36, weight: .bold))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Bold", size: 36, targetLineHeight: 44))
                    .foregroundStyle(colors.text)
                    .accessibilityAddTraits(.isHeader)
                    .textSelection(.enabled)
                if step.repetitions > 1 {
                    Text("\(currentRepetition) / \(step.repetitions)")
                        .font(JohnTypography.sans(14, weight: .semibold).monospacedDigit())
                        .foregroundStyle(colors.textDim)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(colors.background, in: Capsule())
                        .accessibilityLabel("Repetition \(currentRepetition) of \(step.repetitions)")
                }
                if let instruction = step.instruction {
                    Text(instruction)
                        .font(JohnTypography.sans(16))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 16, targetLineHeight: 24))
                        .foregroundStyle(colors.tint)
                        .textSelection(.enabled)
                }
                if let prayer = step.prayer {
                    Text(prayer.text)
                        .font(JohnTypography.sans(20))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 20, targetLineHeight: 34))
                        .foregroundStyle(colors.text)
                        .textSelection(.enabled)
                }
                if let meditation = step.meditation {
                    Text(meditation)
                        .font(JohnTypography.sans(18))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 18, targetLineHeight: 30))
                        .foregroundStyle(colors.text)
                        .textSelection(.enabled)
                }
                if step.prayer == nil, step.meditation == nil, currentGroup != nil {
                    Text("Pause and bring this mystery before God.")
                        .font(JohnTypography.sans(16))
                        .foregroundStyle(colors.text)
                        .textSelection(.enabled)
                        .padding(.leading, 16)
                        .overlay(alignment: .leading) { Rectangle().fill(colors.tint).frame(width: 3) }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 360, alignment: .leading)
            .background(colors.card, in: RoundedRectangle(cornerRadius: 24))

            VStack(spacing: 12) {
                ContentEmphasisButton(title: buttonTitle) { goForward(step) }
                if stepIndex > 0 || repetitionIndex > 0 {
                    Button(action: goBack) {
                        Text("Previous")
                            .font(JohnTypography.sans(14, weight: .semibold))
                            .foregroundStyle(colors.tint)
                            .frame(minHeight: 44)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func completion(_ session: RosaryGuideSession) -> some View {
        RosaryGuidePage {
            Spacer(minLength: 0)
            Text("✢")
                .font(JohnTypography.sans(36))
                .foregroundStyle(colors.tint)
                .frame(width: 96, height: 96)
                .background(colors.card, in: Circle())
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                Text("ROSARY COMPLETE")
                    .font(JohnTypography.sans(12, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(colors.tint)
                Text(session.title)
                    .font(JohnTypography.sans(36, weight: .bold))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Bold", size: 36, targetLineHeight: 44))
                    .foregroundStyle(colors.text)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                Text(session.id == "seven-sorrows"
                    ? "May Our Lady of Sorrows keep you close to her Son through the day."
                    : "May the mysteries you contemplated remain with you through the day.")
                    .font(JohnTypography.sans(16))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 16, targetLineHeight: 24))
                    .foregroundStyle(colors.textDim)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
            ContentEmphasisButton(title: "Return to Rosary", action: onClose)
            ContentButton(title: "Pray again") {
                stepIndex = 0
                repetitionIndex = 0
                complete = false
            }
            Spacer(minLength: 0)
        }
    }

    @MainActor private func loadSession() async {
        guard let repository = runtime.companionRepository else { loadFailed = true; return }
        do {
            let catalog = try await repository.devotionalCatalog()
            let data = try JSONEncoder().encode(catalog.rosary)
            let decoded = try JSONDecoder().decode(RosarySourceCatalog.self, from: data)
            let requested = requestedSet ?? TodaySelectors.rosaryWeekdaySet(date: clock(), timeZone: timeZone)
            guard let value = decoded.sessions.first(where: { $0.id == requested })
                    ?? decoded.sessions.first(where: { $0.id == TodaySelectors.rosaryWeekdaySet(date: clock(), timeZone: timeZone) }) else {
                loadFailed = true
                return
            }
            guard !Task.isCancelled else { return }
            guide = value
            credits = loadCredits()
            stepIndex = 0; repetitionIndex = 0; complete = false
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    private func goForward(_ current: RosaryGuideStep) {
        if repetitionIndex + 1 < current.repetitions {
            repetitionIndex += 1
        } else if stepIndex + 1 >= steps.count {
            complete = true
        } else {
            stepIndex += 1
            repetitionIndex = 0
        }
    }

    private func goBack() {
        if complete { complete = false; return }
        if repetitionIndex > 0 { repetitionIndex -= 1; return }
        if stepIndex > 0 {
            stepIndex -= 1
            repetitionIndex = steps[stepIndex].repetitions - 1
        }
    }

    private func nextButtonTitle(session: RosaryGuideSession, step: RosaryGuideStep) -> String {
        if stepIndex == steps.count - 1 { return "Complete the Rosary" }
        if step.repetitions > 1 { return "Complete \(step.title) \(repetitionIndex + 1) of \(step.repetitions)" }
        if step.prayer != nil { return "Complete \(step.title)" }
        return session.id == "seven-sorrows" ? "Begin this sorrow" : "Begin this decade"
    }

    private func artName(sessionID: String, index: Int?) -> String? {
        guard let index, groupLabels.indices.contains(index) else { return nil }
        return "\(sessionID == "seven-sorrows" ? "sorrows" : sessionID)-\(index + 1)"
    }

    private func creditName(sessionID: String, index: Int?) -> String? {
        guard let index, groupLabels.indices.contains(index) else { return nil }
        return "\(sessionID == "seven-sorrows" ? "sorrows" : sessionID)-\(index + 1)"
    }

    private func loadCredits() -> [String: String] {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("App/Artwork/credits.json"),
              let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return value
    }
}

private struct RosaryGuidePage<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) { content }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 48)
        }
        .background(colors.background)
    }
}

private struct RosarySourceCatalog: Decodable {
    let sessions: [RosaryGuideSession]
}

private struct RosaryGuideSession: Decodable {
    let id: String
    let title: String
    let shortTitle: String
    let groupLabels: [String]
    let steps: [RosaryGuideStep]
}

private struct RosaryGuideStep: Decodable {
    let id: String
    let eyebrow: String
    let title: String
    let instruction: String?
    let prayer: RosaryGuidePrayer?
    let meditation: String?
    let repetitions: Int
    let mysteryIndex: Int?
}

private struct RosaryGuidePrayer: Decodable {
    let id: String
    let title: String
    let text: String
}
