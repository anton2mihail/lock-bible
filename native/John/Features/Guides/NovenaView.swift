import SwiftUI
import JohnCore

struct NovenaView: View {
    let id: String

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.openURL) private var openURL
    @ScaledMetric(relativeTo: .caption) private var dayTextHeight = 21.0
    @State private var loadedCatalog: DevotionalCatalog?
    @State private var intentionDraft: String?
    @State private var loadMessage: String?
    @State private var saveMessage: String?
    @State private var intentionRevision = 0
    @State private var routeGeneration = 0
    @State private var saveQueue = NovenaProgressSaveQueue()
    @State private var confirmingReset = false
    @State private var dayCompleteCount = 0

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var catalog: DevotionalCatalog? { loadedCatalog ?? runtime.warmDevotionalCatalog }
    private var novena: NovenaCatalogItem? { catalog?.novenas.first { $0.id == id } }
    private var progress: NovenaProgress {
        let source = NovenaProgressSelectors.normalize(runtime.committedNativeState?.novenaProgress[id])
        guard let intentionDraft else { return source }
        return NovenaProgress(completedDays: source.completedDays, selectedDay: source.selectedDay,
                              intention: intentionDraft)
    }
    private var isComplete: Bool { progress.completedDays.count == 9 }
    private var selectedIsComplete: Bool { progress.completedDays.contains(progress.selectedDay) }
    private var daySize: CGFloat { max(34, ceil(dayTextHeight + 12)) }
    private var progressHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(isComplete ? "Novena complete" : "Day \(progress.selectedDay)")
                .font(JohnTypography.sans(20, weight: .medium))
                .foregroundStyle(colors.text)
            Spacer(minLength: 0)
            Text("\(progress.completedDays.count) of 9 prayed")
                .font(JohnTypography.sans(14))
                .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 14, targetLineHeight: 21))
                .foregroundStyle(colors.textDim)
                .numericChange(progress.completedDays.count)
        }
    }

    var body: some View {
        Group {
            if let loadMessage {
                ContentPage(title: "Novena", eyebrow: nil, subtitle: nil) {
                    ContentMutedText(text: loadMessage)
                }
            } else if let novena {
                detail(novena)
            } else if catalog != nil {
                ContentPage(title: "Novena not found", eyebrow: nil,
                            subtitle: "This prayer is not in your offline library.") {}
            } else {
                ContentPage(title: "Novena", eyebrow: nil, subtitle: nil) {
                    Color.clear.frame(maxWidth: .infinity).frame(height: 72)
                }
            }
        }
        .task(id: id) {
            routeGeneration &+= 1
            intentionDraft = nil
            loadMessage = nil
            saveMessage = nil
            await load(for: id)
        }
        .onDisappear { routeGeneration &+= 1 }
        .sensoryFeedback(.success, trigger: dayCompleteCount)
        .onChange(of: runtime.committedNativeState?.novenaProgress[id]) { _, value in
            if intentionDraft == nil { intentionDraft = value?.intention ?? "" }
        }
    }

    private func detail(_ item: NovenaCatalogItem) -> some View {
        NovenaDetailPage {
            ContentArtwork(name: artworkName(item.id))
                .scaledToFill()
                .aspectRatio(1.7, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("NOVENA · 9 DAYS")
                    .font(JohnTypography.sans(12, weight: .semibold))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-SemiBold", size: 12, targetLineHeight: 18))
                    .tracking(1.8)
                    .foregroundStyle(colors.tint)
                Text(item.title)
                    .font(JohnTypography.sans(36, weight: .bold))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Bold", size: 36, targetLineHeight: 44))
                    .foregroundStyle(colors.text)
                    .accessibilityAddTraits(.isHeader)
                Text(item.subtitle)
                    .font(JohnTypography.sans(16))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 16, targetLineHeight: 24))
                    .foregroundStyle(colors.textDim)
                if let traditionalStart = item.traditionalStart, let feastDay = item.feastDay {
                    ViewThatFits(in: .horizontal) {
                        dateLabels(traditionalStart, feastDay)
                        VStack(alignment: .leading, spacing: 8) { dateLabels(traditionalStart, feastDay) }
                    }
                    .padding(.top, 8)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("ABOUT THIS NOVENA")
                    .font(JohnTypography.sans(12, weight: .semibold))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-SemiBold", size: 12, targetLineHeight: 18))
                    .tracking(1.4)
                    .foregroundStyle(colors.tint)
                if !item.about.isEmpty {
                    Text(item.about)
                        .font(JohnTypography.sans(16))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 16, targetLineHeight: 23))
                        .foregroundStyle(colors.textDim)
                }
                Text("Patronage · \(item.patronage)")
                    .font(JohnTypography.sans(16, weight: .semibold))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-SemiBold", size: 16, targetLineHeight: 23))
                    .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .leading) { Rectangle().fill(colors.tint).frame(width: 3) }

            VStack(spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    progressHeader
                    VStack(alignment: .leading, spacing: 8) { progressHeader }
                }
                .padding(.horizontal, 16)
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(1...9, id: \.self) { day in
                            dayButton(day)
                            if day < 9 {
                                Rectangle()
                                    .fill(progress.completedDays.contains(day) ? colors.tint : colors.separator)
                                    .frame(width: 10, height: 1)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, ceil(daySize * 0.04))
                }
                .scrollIndicators(.hidden)
                .accessibilityLabel("Choose a novena day")
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(colors.border, lineWidth: 1 / displayScale))

            VStack(alignment: .leading, spacing: 8) {
                Text("Your intention")
                    .font(JohnTypography.sans(16, weight: .medium))
                    .foregroundStyle(colors.text)
                ContentMutedText(text: "Stored privately on this device.")
                ContentInputField(placeholder: "Your intention",
                                  text: intentionBinding,
                                  accessibilityLabel: "Your novena intention", multiline: true,
                                  inputAppearance: .novenaIntention)
            }
            .padding(16)
            .background(colors.card, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 24) {
                Text("Day \(progress.selectedDay) prayer")
                    .font(JohnTypography.sans(14, weight: .semibold))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-SemiBold", size: 14, targetLineHeight: 21))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(colors.tint)
                if let opening = item.opening {
                    Text(opening)
                        .font(JohnTypography.sans(20, weight: .semibold))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-SemiBold", size: 20, targetLineHeight: 32))
                        .foregroundStyle(colors.text)
                }
                HStack(spacing: 8) {
                    Rectangle().fill(colors.separator).frame(height: 1)
                    Text("✦").font(JohnTypography.sans(14)).foregroundStyle(colors.tint)
                    Rectangle().fill(colors.separator).frame(height: 1)
                }
                .accessibilityHidden(true)
                ForEach(Array(item.sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 8) {
                        if let title = section.title {
                            Text(title)
                                .font(JohnTypography.sans(20, weight: .medium))
                                .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Medium", size: 20, targetLineHeight: 32))
                                .foregroundStyle(colors.text)
                        }
                        ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                            Text(paragraph)
                                .font(JohnTypography.sans(18))
                                .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 18, targetLineHeight: 30))
                                .foregroundStyle(colors.text)
                        }
                        if let response = section.response {
                            Text(response)
                                .font(JohnTypography.sans(16, weight: .semibold))
                                .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-SemiBold", size: 16, targetLineHeight: 25))
                                .foregroundStyle(colors.tint)
                                .padding(.leading, 16)
                                .overlay(alignment: .leading) { Rectangle().fill(colors.tint).frame(width: 2) }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.card, in: RoundedRectangle(cornerRadius: 20))

            if !saveMessage.isNilOrEmpty {
                ContentMutedText(text: saveMessage ?? "")
                    .contentAnnouncement(saveMessage)
            }
            if isComplete {
                ContentButton(title: "Start the novena again") { confirmingReset = true }
                    .accessibilityHint("Clears all nine completed days and your intention")
                    .confirmationDialog("Reset this novena?", isPresented: $confirmingReset, titleVisibility: .visible) {
                        Button("Reset", role: .destructive) {
                            enqueueProgressChange({ _ in NovenaProgressSelectors.reset() }, clearIntentionOnSuccess: true)
                        }
                        Button("Cancel", role: .cancel) {}
                    }
            } else {
                ContentButton(title: selectedIsComplete ? "Day \(progress.selectedDay) complete" : "Mark day \(progress.selectedDay) complete") {
                    enqueueProgressChange({ NovenaProgressSelectors.completeSelectedDay($0) }, completesDay: true)
                }
                .disabled(selectedIsComplete)
            }
            Button {
                guard let url = URL(string: item.sourceUrl) else { return }
                openURL(url)
            } label: {
                Text("Devotion source · \(item.sourceName)")
                    .font(JohnTypography.sans(12))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 12, targetLineHeight: 18))
                    .foregroundStyle(colors.textDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private func dayButton(_ day: Int) -> some View {
        let selected = day == progress.selectedDay
        let complete = progress.completedDays.contains(day)
        return Button {
            enqueueProgressChange { value in
                (try? NovenaProgressSelectors.selectDay(day, in: value)) ?? value
            }
        } label: {
            Text(complete ? "✓" : String(day))
                .font(JohnTypography.sans(14, weight: .semibold))
                .foregroundStyle((selected || complete) ? colors.card : colors.textDim)
                .frame(width: daySize, height: daySize)
                .background(selected ? colors.text : (complete ? colors.tint : colors.background), in: Circle())
                .overlay(Circle().stroke(selected ? colors.text : (complete ? colors.tint : colors.border), lineWidth: 1))
                .scaleEffect(selected ? 1.08 : 1)
        }
        .buttonStyle(NovenaDayButtonStyle())
        .accessibilityLabel("Day \(day)\(complete ? ", complete" : "")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func dateLabels(_ start: String, _ feast: String) -> some View {
        HStack(spacing: 12) {
            Text("Begins \(start)")
            Circle().fill(colors.tint).frame(width: 3, height: 3)
            Text("Feast \(feast)")
        }
        .font(JohnTypography.sans(12))
        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Regular", size: 12, targetLineHeight: 18))
        .foregroundStyle(colors.textDim)
    }

    @MainActor private func load(for requestedID: String) async {
        guard let repository = runtime.companionRepository else {
            if catalog == nil { loadMessage = "This prayer is not available in your offline library." }
            return
        }
        do {
            let loaded = try await repository.devotionalCatalog()
            guard !Task.isCancelled, id == requestedID else { return }
            loadedCatalog = loaded
            intentionDraft = progress.intention
            loadMessage = nil
        } catch {
            guard !Task.isCancelled, id == requestedID else { return }
            if catalog == nil { loadMessage = "This prayer is not available in your offline library." }
        }
    }

    private var intentionBinding: Binding<String> {
        Binding(get: { intentionDraft ?? "" }, set: { value in
            intentionRevision &+= 1
            intentionDraft = value
            queueIntention(value)
        })
    }

    @MainActor private func queueIntention(_ value: String) {
        let revision = intentionRevision
        let generation = routeGeneration
        saveQueue.enqueue(id: id, runtime: runtime, change: { current in
            NovenaProgressSelectors.setIntention(value, in: current)
        }) { success, _ in
            guard routeGeneration == generation, intentionRevision == revision else { return }
            if !success { saveMessage = "Your intention could not be saved. Keep this screen open and try again." }
            else { saveMessage = nil }
        }
    }

    @MainActor private func enqueueProgressChange(_ change: @escaping (NovenaProgress) -> NovenaProgress,
                                                  clearIntentionOnSuccess: Bool = false,
                                                  completesDay: Bool = false) {
        let revision = intentionRevision
        let generation = routeGeneration
        saveQueue.enqueue(id: id, runtime: runtime, change: change) { success, _ in
            guard routeGeneration == generation else { return }
            if success {
                saveMessage = nil
                if completesDay { dayCompleteCount += 1 }
                if clearIntentionOnSuccess, intentionRevision == revision {
                    intentionRevision &+= 1
                    intentionDraft = ""
                }
            } else {
                saveMessage = "Your progress could not be saved. Please try again."
            }
        }
    }

    private func artworkName(_ id: String) -> String {
        if ["st-padre-pio", "st-jude", "st-peregrine", "st-joseph", "st-therese", "st-anthony", "st-anne", "st-rita", "st-monica", "st-michael", "st-benedict", "st-francis-assisi", "st-dymphna"].contains(id) {
            return id
        }
        if id == "holy-spirit" { return "glorious-3" }
        if id == "assumption" { return "glorious-4" }
        if ["sacred-heart", "divine-mercy", "christ-the-king"].contains(id) { return "glorious-1" }
        if id.contains("lady") || ["miraculous-medal", "immaculate-conception"].contains(id) { return "mary" }
        return "prayer"
    }
}

private struct NovenaDayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct NovenaDetailPage<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                content
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 48)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(colors.background)
    }
}

@MainActor
private final class NovenaProgressSaveQueue {
    private var tail: Task<Void, Never>?

    func enqueue(id: String, runtime: JohnRuntime,
                 change: @escaping (NovenaProgress) -> NovenaProgress,
                 completion: @escaping (Bool, NovenaProgress) -> Void) {
        let previous = tail
        tail = Task { @MainActor in
            await previous?.value
            let current = NovenaProgressSelectors.normalize(runtime.committedNativeState?.novenaProgress[id])
            let next = change(current)
            let saved = await runtime.applyWithResult(.setNovenaProgress(id: id, value: next))
            completion(saved, next)
        }
    }
}

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool { self?.isEmpty != false }
}
