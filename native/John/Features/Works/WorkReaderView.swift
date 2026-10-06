import SwiftUI
import UIKit
import JohnCore

struct WorkReaderView: View {
    let workID: String?
    let requestedSection: Int?
    let onOpenChapterCommentary: (String, Int, String) -> Void

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var catalog: WorkCatalog?
    @State private var work: WorkMetadata?
    @State private var collection: WorkCollection?
    @State private var section: WorkSection?
    @State private var summaries: [WorkSectionSummary] = []
    @State private var pageIndex = 0
    @State private var pages: [WorkPageSlice] = []
    @State private var anchor: WorksAnchor?
    @State private var loading = true
    @State private var failed = false
    @State private var contentsPresented = false
    @State private var loadGeneration = 0
    @State private var positionGeneration = 0
    @State private var saveNotice: String?
    @State private var storedAnchor: WorksAnchor?
    @State private var positionWriteTask: Task<Void, Never>?

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var currentTitle: String { section?.title ?? work?.title ?? "Reading" }
    private var sectionCount: Int { work?.sectionCount ?? summaries.count }
    private var currentNoun: String { WorksSourceText.sectionNoun(work?.kind ?? "commentary") }
    private var isFirst: Bool { currentSectionIndex <= 0 }
    private var isLast: Bool { currentSectionIndex >= max(0, sectionCount - 1) }
    private var currentSectionIndex: Int { section?.index ?? requestedSection ?? 0 }
    private var pageCount: Int { pages.count }
    private var currentPageAnchor: WorksAnchor? { pages.indices.contains(pageIndex) ? pages[pageIndex].anchor : nil }
    private var reading: ReadingPreferences { preferences.reading }

    var body: some View {
        Group {
            if workID == nil || (catalog != nil && work == nil) {
                missingView
            } else {
                reader
            }
        }
        .task(id: taskIdentity) { await loadWork() }
        .sheet(isPresented: $contentsPresented) { contentsSheet }
        .onDisappear { loadGeneration &+= 1 }
    }

    private var taskIdentity: String { "\(workID ?? "missing-work")|\(requestedSection.map(String.init) ?? "resume")" }

    private var missingView: some View {
        ContentUnavailableView {
            Label("That work isn’t available", systemImage: "book.closed")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background)
    }

    private var reader: some View {
        VStack(spacing: 8) {
            topBar
            if let section {
                GeometryReader { proxy in
                    Group {
                        if pages.isEmpty {
                            ProgressView().tint(colors.tint)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            WorkPageTextView(page: pages[min(max(0, pageIndex), pages.count - 1)].text)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .contentShape(Rectangle())
                                .gesture(DragGesture(minimumDistance: 28).onEnded { value in
                                    if value.translation.width < -32 { changePage(pageIndex + 1) }
                                    else if value.translation.width > 32 { changePage(pageIndex - 1) }
                                })
                                .accessibilityIdentifier("works-prose")
                                .onAppear { persistPosition(section: section.index, page: pageIndex, anchor: currentPageAnchor) }
                        }
                    }
                    .onAppear { updateViewport(proxy.size) }
                    .onChange(of: proxy.size) { _, size in updateViewport(size) }
                }
                .id("\(workID ?? ""):\(section.index):\(reading.textSize.rawValue):\(reading.typeface.rawValue):\(reading.lineSpacing.rawValue):\(dynamicTypeSize)")
            } else {
                VStack(spacing: 12) {
                    if loading { ProgressView().tint(colors.tint) }
                    else { Text(failed ? "That section could not be opened" : "No section is available").font(JohnTypography.sans(14)).foregroundStyle(colors.textDim) }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let saveNotice { Text(saveNotice).font(JohnTypography.sans(12)).foregroundStyle(colors.textDim).contentAnnouncement(saveNotice) }
            footer
            if let collection {
                Text(collection.translation)
                    .font(JohnTypography.sans(12)).foregroundStyle(colors.textDim)
                    .frame(maxWidth: .infinity).padding(.top, 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(colors.background)
        .task(id: layoutKey) { await buildPages() }
        .onChange(of: reading) { _, _ in preserveAnchorAndRebuild() }
        .onChange(of: dynamicTypeSize) { _, _ in preserveAnchorAndRebuild() }
        .onChange(of: colorScheme) { _, _ in preserveAnchorAndRebuild() }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(currentTitle).font(JohnTypography.sans(14, weight: .semibold)).lineLimit(1)
                if currentTitle != work?.title { Text(work?.title ?? "").font(JohnTypography.sans(12)).foregroundStyle(colors.textDim).lineLimit(1) }
            }
            .frame(maxWidth: .infinity)
            Text(pageCount > 0 ? "\(pageIndex + 1)/\(pageCount)" : "…")
                .font(JohnTypography.sans(12, weight: .semibold).monospacedDigit())
                .foregroundStyle(colors.tint)
                .accessibilityLabel(pageCount > 0 ? "Page \(pageIndex + 1) of \(pageCount)" : "Loading pages")
        }
        .frame(minHeight: 44)
    }

    private var footer: some View {
        HStack {
            Button { changeSection(currentSectionIndex - 1) } label: {
                Text("‹").font(JohnTypography.sans(24)).foregroundStyle(isFirst ? colors.border : colors.tint).frame(minWidth: 44, minHeight: 44)
            }
            .disabled(isFirst)
            .accessibilityLabel("Previous \(currentNoun)")
            Spacer()
            Button { contentsPresented = true } label: {
                Text("\(currentSectionIndex + 1) of \(sectionCount)")
                    .font(JohnTypography.sans(12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(sectionCount < 2 ? colors.textDim : colors.tint)
                    .frame(minHeight: 44).padding(.horizontal, 12)
            }
            .disabled(sectionCount < 2)
            .accessibilityLabel("Contents, \(currentNoun) \(currentSectionIndex + 1) of \(sectionCount)")
            Spacer()
            Button { changeSection(currentSectionIndex + 1) } label: {
                Text("›").font(JohnTypography.sans(24)).foregroundStyle(isLast ? colors.border : colors.tint).frame(minWidth: 44, minHeight: 44)
            }
            .disabled(isLast)
            .accessibilityLabel("Next \(currentNoun)")
        }
        .overlay(alignment: .top) { Rectangle().fill(colors.separator).frame(height: 1 / displayScale) }
    }

    private var contentsSheet: some View {
        NavigationStack {
          ScrollViewReader { proxy in
            List(summaries, id: \.index) { item in
                Button {
                    contentsPresented = false
                    changeSection(item.index, explicit: true)
                } label: {
                    HStack(spacing: 12) {
                        Text("\(item.index + 1).").font(JohnTypography.sans(12)).foregroundStyle(colors.textDim).monospacedDigit()
                        Text(item.title).font(JohnTypography.sans(16, weight: item.index == currentSectionIndex ? .semibold : .regular)).foregroundStyle(colors.text)
                        Spacer(minLength: 0)
                    }.frame(minHeight: 56, alignment: .leading)
                }
                .id(item.index)
                .listRowBackground(colors.background)
            }
            .onAppear { proxy.scrollTo(currentSectionIndex, anchor: .center) }
          }
            .navigationTitle(work?.title ?? "Contents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { contentsPresented = false } } }
            .background(colors.background)
        }
    }

    private var layoutKey: String {
        "\(workID ?? "")|\(section?.index ?? -1)|\(reading.textSize.rawValue)|\(reading.typeface.rawValue)|\(reading.lineSpacing.rawValue)|\(dynamicTypeSize)"
    }

    @MainActor private func loadWork() async {
        guard let workID else { return }
        loadGeneration &+= 1
        positionGeneration &+= 1
        let generation = loadGeneration
        catalog = nil; work = nil; collection = nil; section = nil; summaries = []; pages = []; anchor = nil; storedAnchor = nil; loading = true; failed = false
        guard let loadedCatalog = await runtime.worksCatalog(), generation == loadGeneration else {
            if generation == loadGeneration { loading = false; failed = true }
            return
        }
        guard let loadedWork = loadedCatalog.works.first(where: { $0.id == workID }) else {
            catalog = loadedCatalog; loading = false; return
        }
        catalog = loadedCatalog
        work = loadedWork
        collection = loadedCatalog.collections.first(where: { $0.id == loadedWork.collectionID })
        do {
            let loadedSummaries = try await runtime.workSectionSummaries(workID: workID)
            guard generation == loadGeneration, !Task.isCancelled else { return }
            summaries = loadedSummaries
            let stored = runtime.committedNativeState?.worksPositions[workID]
            let start = requestedSection ?? WorksSourceText.positionIndex(stored, key: "sectionIndex")
            await loadSection(index: min(max(start, 0), max(loadedWork.sectionCount - 1, 0)), explicit: requestedSection != nil)
        } catch {
            guard generation == loadGeneration else { return }
            loading = false; failed = true
        }
    }

    @MainActor private func loadSection(index: Int, explicit: Bool) async {
        guard let workID, let work else { return }
        loadGeneration &+= 1
        positionGeneration &+= 1
        let generation = loadGeneration
        section = nil; pages = []; pageIndex = 0; loading = true; failed = false; saveNotice = nil
        anchor = nil
        storedAnchor = nil
        do {
            let loaded = try await runtime.workSection(workID: workID, index: index)
            guard generation == loadGeneration, !Task.isCancelled else { return }
            section = loaded
            loading = false
            if !explicit, requestedSection == nil,
               let stored = runtime.committedNativeState?.worksPositions[workID] {
                pageIndex = WorksSourceText.positionIndex(stored, key: "pageIndex")
                storedAnchor = readAnchor(stored)
            } else {
                storedAnchor = nil
            }
            await buildPages()
        } catch {
            guard generation == loadGeneration else { return }
            loading = false; failed = true
        }
    }

    @MainActor private func buildPages() async {
        guard let section else { return }
        // The actual viewport is measured by WorkPageTextView. Keep a safe
        // provisional page until SwiftUI reports its current size.
        guard lastViewport.width > 0, lastViewport.height > 0 else { return }
        let font = fontForReader()
        let lineHeight = lineHeightForReader(font.pointSize)
        let result = WorkTextPaginator.paginate(paragraphs: section.paragraphs,
                                                width: lastViewport.width,
                                                height: max(lastViewport.height, lineHeight),
                                                font: font, lineHeight: lineHeight,
                                                paragraphGap: 14, sectionIndex: section.index,
                                                foregroundColor: UIColor(colors.text))
        pages = result.isEmpty ? [WorkPageSlice(text: NSAttributedString(string: ""), anchor: try? WorksAnchor(sectionIndex: section.index, paragraphIndex: 0, utf16Offset: 0))].compactMap { $0 } : result
        if let preferredAnchor = anchor ?? storedAnchor, preferredAnchor.sectionIndex == section.index {
            let matchingPage = pages.lastIndex { page in
                guard let anchor = page.anchor else { return false }
                return anchor.paragraphIndex < preferredAnchor.paragraphIndex
                    || (anchor.paragraphIndex == preferredAnchor.paragraphIndex && anchor.utf16Offset <= preferredAnchor.utf16Offset)
            }
            if let matchingPage { pageIndex = matchingPage }
        }
        pageIndex = min(max(pageIndex, 0), max(pages.count - 1, 0))
        storedAnchor = nil
        anchor = currentPageAnchor
    }

    @MainActor private func preserveAnchorAndRebuild() {
        anchor = currentPageAnchor ?? anchor ?? storedAnchor
        Task { await buildPages() }
    }

    @State private var lastViewport = CGSize.zero

    @MainActor private func updateViewport(_ size: CGSize) {
        guard size.width > 0, size.height > 0, size != lastViewport else { return }
        lastViewport = size
        Task { await buildPages() }
    }

    private func readAnchor(_ position: WorkReadingPosition) -> WorksAnchor? {
        guard case let .object(fields)? = position.fields["anchor"],
              case let .number(sectionIndex)? = fields["sectionIndex"],
              case let .number(paragraphIndex)? = fields["paragraphIndex"],
              case let .number(offset)? = fields["utf16Offset"],
              sectionIndex >= 0, paragraphIndex >= 0, offset >= 0,
              sectionIndex < Double(Int.max), paragraphIndex < Double(Int.max), offset < Double(Int.max) else { return nil }
        return try? WorksAnchor(sectionIndex: Int(sectionIndex), paragraphIndex: Int(paragraphIndex), utf16Offset: Int(offset))
    }

    @MainActor private func fontForReader() -> UIFont {
        let size: CGFloat = switch reading.textSize { case .small: 16; case .medium: 18; case .large: 21; case .extraLarge: 24 }
        let fontName = reading.typeface == .serif ? "Georgia" : "SpaceGrotesk-Regular"
        let base = UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size)
        let category: UIContentSizeCategory = switch dynamicTypeSize {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: base, compatibleWith: UITraitCollection(preferredContentSizeCategory: category))
    }

    private func lineHeightForReader(_ size: CGFloat) -> CGFloat {
        let multiplier: CGFloat = switch reading.lineSpacing { case .compact: 1.45; case .comfortable: 1.67; case .relaxed: 1.9 }
        return (size * multiplier).rounded()
    }

    @MainActor private func changeSection(_ index: Int, explicit: Bool = true) {
        guard let work, index >= 0, index < work.sectionCount else { return }
        anchor = nil
        storedAnchor = nil
        Task { await loadSection(index: index, explicit: explicit) }
    }

    @MainActor private func changePage(_ value: Int) {
        guard value >= 0, value < pages.count, let section else { return }
        pageIndex = value
        anchor = pages[value].anchor
        persistPosition(section: section.index, page: value, anchor: anchor)
    }

    @MainActor private func persistPosition(section: Int, page: Int, anchor: WorksAnchor?) {
        guard let workID else { return }
        let generation = positionGeneration
        let feedbackGeneration = loadGeneration
        let timestamp = Date().timeIntervalSince1970 * 1_000
        let previous = positionWriteTask
        positionWriteTask = Task { @MainActor in
            if let previous { await previous.value }
            guard generation == positionGeneration, workID == self.workID else { return }
            var latestFields = runtime.committedNativeState?.worksPositions[workID]?.fields ?? [:]
            latestFields.merge([
                "workId": .string(workID),
                "sectionIndex": .number(Double(section)),
                "pageIndex": .number(Double(page)),
                "updatedAt": .number(timestamp),
            ], uniquingKeysWith: { _, new in new })
            if let anchor {
                latestFields["anchor"] = .object([
                    "sectionIndex": .number(Double(anchor.sectionIndex)),
                    "paragraphIndex": .number(Double(anchor.paragraphIndex)),
                    "utf16Offset": .number(Double(anchor.utf16Offset)),
                ])
            } else {
                latestFields.removeValue(forKey: "anchor")
            }
            let latest = WorkReadingPosition(fields: latestFields)
            let success = await runtime.applyWithResult(.setWorksPosition(workID: workID, value: latest))
            guard generation == positionGeneration, feedbackGeneration == loadGeneration,
                  workID == self.workID else { return }
            saveNotice = success ? nil : "Your reading position could not be saved."
        }
    }
}

private struct WorkPageSlice {
    let text: NSAttributedString
    let anchor: WorksAnchor?
}

private struct WorkPageTextView: UIViewRepresentable {
    let page: NSAttributedString
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.textContainer.widthTracksTextView = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.accessibilityIdentifier = "works-prose-text"
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        view.attributedText = page
        let width = view.bounds.width
        if width.isFinite, width > 0 {
            view.textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
            view.layoutManager.ensureLayout(for: view.textContainer)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        uiView.textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        uiView.layoutManager.ensureLayout(for: uiView.textContainer)
        let measured = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: proposal.height ?? measured.height)
    }
}

private enum WorkTextPaginator {
    @MainActor static func paginate(paragraphs: [String], width: CGFloat, height: CGFloat,
                                    font: UIFont, lineHeight: CGFloat, paragraphGap: CGFloat,
                                    sectionIndex: Int, foregroundColor: UIColor) -> [WorkPageSlice] {
        guard width > 0, height > 0, !paragraphs.isEmpty else { return [] }
        let fullText = NSMutableAttributedString(string: "")
        var paragraphStarts: [Int] = []
        for (index, text) in paragraphs.enumerated() {
            paragraphStarts.append(fullText.length)
            let style = NSMutableParagraphStyle()
            style.minimumLineHeight = lineHeight
            style.maximumLineHeight = lineHeight
            style.paragraphSpacing = index < paragraphs.count - 1 ? paragraphGap : 0
            style.lineBreakMode = .byWordWrapping
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: style,
                .foregroundColor: foregroundColor,
            ]
            fullText.append(NSAttributedString(string: text, attributes: attributes))
            if index < paragraphs.count - 1 { fullText.append(NSAttributedString(string: "\n", attributes: attributes)) }
        }
        guard fullText.length > 0 else { return [] }
        let storage = NSTextStorage(attributedString: fullText)
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        let glyphRange = manager.glyphRange(for: container)
        var ranges: [Int: NSRange] = [:]
        var page = 0
        var pageTop: CGFloat = 0
        var pageHasLine = false
        manager.enumerateLineFragments(forGlyphRange: glyphRange) { rect, _, _, lineGlyphs, _ in
            guard lineGlyphs.length > 0 else { return }
            if pageHasLine && rect.maxY > pageTop + height {
                page += 1
                pageTop = rect.minY
                pageHasLine = false
            }
            let chars = manager.characterRange(forGlyphRange: lineGlyphs, actualGlyphRange: nil)
            if let prior = ranges[page] {
                ranges[page] = NSRange(location: prior.location, length: max(NSMaxRange(prior), NSMaxRange(chars)) - prior.location)
            } else { ranges[page] = chars }
            pageHasLine = true
        }
        return ranges.keys.sorted().compactMap { page in
            guard let range = ranges[page], range.length > 0 else { return nil }
            let anchor = makeAnchor(globalOffset: range.location, paragraphStarts: paragraphStarts,
                                    paragraphs: paragraphs, sectionIndex: sectionIndex)
            return WorkPageSlice(text: fullText.attributedSubstring(from: range), anchor: anchor)
        }
    }

    private static func makeAnchor(globalOffset: Int, paragraphStarts: [Int], paragraphs: [String], sectionIndex: Int) -> WorksAnchor? {
        let paragraph = paragraphStarts.lastIndex(where: { $0 <= globalOffset }) ?? 0
        let local = max(0, globalOffset - paragraphStarts[paragraph])
        return try? WorksAnchor(sectionIndex: sectionIndex, paragraphIndex: paragraph,
                                utf16Offset: min(local, paragraphs[paragraph].utf16.count))
    }
}
