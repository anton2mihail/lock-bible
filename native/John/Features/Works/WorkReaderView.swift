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
    /// The section the purchase gate stopped, if any. The reader shows the unlock panel in its place.
    @State private var lockedIndex: Int?
    @State private var contentsPresented = false
    @ScaledMetric(relativeTo: .body) private var contentsNumberWidth: CGFloat = 32
    @State private var loadGeneration = 0
    @State private var positionGeneration = 0
    @State private var saveNotice: String?
    @State private var storedAnchor: WorksAnchor?
    @State private var positionWriteTask: Task<Void, Never>?
    // Paginated sections near the current one, so a swipe past the last page
    // turns straight into the next section, as in Apple Books.
    @State private var sectionCache: [Int: PaginatedWorkSection] = [:]
    @State private var sectionCacheKey = ""
    @State private var bookRevision = 0
    @State private var prefetchTask: Task<Void, Never>?

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var currentTitle: String { section?.title ?? work?.title ?? "Reading" }
    private var sectionCount: Int { work?.sectionCount ?? summaries.count }
    private var currentNoun: String { WorksSourceText.sectionNoun(work?.kind ?? "commentary") }
    private var isFirst: Bool { currentSectionIndex <= 0 }
    private var isLast: Bool { currentSectionIndex >= max(0, sectionCount - 1) }
    private var currentSectionIndex: Int { section?.index ?? lockedIndex ?? requestedSection ?? 0 }
    private var pageCount: Int { pages.count }
    private var currentPageAnchor: WorksAnchor? { pages.indices.contains(pageIndex) ? pages[pageIndex].anchor : nil }
    private var reading: ReadingPreferences { preferences.reading }
    private let pageInset: CGFloat = 24
    private var needsExpandedWorkTitle: Bool {
        currentTitle.count > 24 || (work?.title.count ?? 0) > 24
    }

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

    private var workTitleHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(currentTitle)
                .font(JohnTypography.sans(14, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if currentTitle != work?.title {
                Text(work?.title ?? "")
                    .font(JohnTypography.sans(12))
                    .foregroundStyle(colors.textDim)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .dynamicTypeSize(.xSmall ... .xLarge)
    }

    private var reader: some View {
        VStack(spacing: 8) {
            if needsExpandedWorkTitle {
                workTitleHeader
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, pageInset)
            }
            if let section {
                // The book spans the full width so a page slides edge to edge.
                // Each page keeps the reading margin inside itself.
                GeometryReader { proxy in
                    Group {
                        if pages.isEmpty {
                            ProgressView().tint(colors.tint)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            WorkPageBook(current: WorkPageID(section: section.index,
                                                             page: min(max(0, pageIndex), pages.count - 1)),
                                         revision: bookRevision,
                                         horizontalInset: pageInset,
                                         background: UIColor(colors.background),
                                         text: pageText,
                                         pageCount: pageCount(forSection:),
                                         onSettle: settlePage)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .accessibilityIdentifier("works-prose")
                                .onAppear {
                                    persistPosition(section: section.index, page: pageIndex,
                                                    anchor: anchor ?? storedAnchor ?? currentPageAnchor)
                                }
                        }
                    }
                    .onAppear { updateViewport(proxy.size) }
                    .onChange(of: proxy.size) { _, size in updateViewport(size) }
                }
                .id("\(workID ?? ""):\(reading.textSize.rawValue):\(reading.typeface.rawValue):\(reading.lineSpacing.rawValue):\(dynamicTypeSize)")
            } else if lockedIndex != nil {
                ScrollView {
                    FathersUnlockPanel(sampleNotice: "You have read the free part of \(work?.title ?? "this work").")
                        .frame(maxWidth: 620, alignment: .leading)
                        .padding(.horizontal, pageInset)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 12) {
                    if loading { ProgressView().tint(colors.tint) }
                    else { Text(failed ? "That section could not be opened" : "No section is available").font(JohnTypography.sans(14)).foregroundStyle(colors.textDim) }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Group {
                if let saveNotice { Text(saveNotice).font(JohnTypography.sans(12)).foregroundStyle(colors.textDim).contentAnnouncement(saveNotice) }
                footer
                    .dynamicTypeSize(.xSmall ... .xLarge)
                if let collection {
                    Text(collection.translation)
                        .font(JohnTypography.sans(12)).foregroundStyle(colors.textDim)
                        .dynamicTypeSize(.xSmall ... .xLarge)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(collection.translation)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, pageInset)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(colors.background)
        .task(id: layoutKey) { await buildPages() }
        .onChange(of: reading) { _, _ in preserveAnchorAndRebuild() }
        .onChange(of: dynamicTypeSize) { _, _ in preserveAnchorAndRebuild() }
        .onChange(of: colorScheme) { _, _ in preserveAnchorAndRebuild() }
        .onDisappear { prefetchTask?.cancel() }
        .onChange(of: runtime.fathers.isUnlocked) { _, unlocked in
            guard unlocked, let lockedIndex else { return }
            Task { await loadSection(index: lockedIndex, explicit: true) }
        }
        .toolbar {
            if !needsExpandedWorkTitle {
                ToolbarItem(placement: .principal) {
                    workTitleHeader
                        .frame(maxWidth: .infinity, maxHeight: 44)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button { changeSection(currentSectionIndex - 1) } label: {
                Text("‹").font(JohnTypography.sans(24)).foregroundStyle(isFirst ? colors.border : colors.tint).frame(minWidth: 44, minHeight: 44)
            }
            .disabled(isFirst)
            .accessibilityLabel("Previous \(currentNoun)")
            Spacer()
            VStack(spacing: 0) {
                Button { contentsPresented = true } label: {
                    Text("\(currentSectionIndex + 1) of \(sectionCount)")
                        .font(JohnTypography.sans(12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(sectionCount < 2 ? colors.textDim : colors.tint)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                }
                .disabled(sectionCount < 2)
                .accessibilityLabel("Contents, \(currentNoun) \(currentSectionIndex + 1) of \(sectionCount)")
                Text(lockedIndex != nil ? "In the full library" : (pageCount > 0 ? "Page \(pageIndex + 1) of \(pageCount)" : "Loading pages"))
                    .font(JohnTypography.sans(10, weight: .medium).monospacedDigit())
                    .foregroundStyle(colors.textDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .numericChange(pageIndex)
                    .accessibilityIdentifier("works-page-count")
            }
            .frame(minHeight: 44)
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
                            .frame(minWidth: contentsNumberWidth, alignment: .trailing)
                        Text(item.title).font(JohnTypography.sans(16, weight: item.index == currentSectionIndex ? .semibold : .regular)).foregroundStyle(colors.text)
                        Spacer(minLength: 0)
                    }.frame(minHeight: 56, alignment: .leading)
                }
                .id(item.index)
                .listRowBackground(colors.background)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onAppear { proxy.scrollTo(currentSectionIndex, anchor: .center) }
          }
            .navigationTitle(work?.title ?? "Contents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { contentsPresented = false } } }
            .background(colors.background)
        }
    }

    private var layoutKey: String {
        "\(workID ?? "")|\(reading.textSize.rawValue)|\(reading.typeface.rawValue)|\(reading.lineSpacing.rawValue)|\(dynamicTypeSize)"
    }

    /// Everything that changes where page breaks fall. Cached pages are only
    /// valid for the key they were built with.
    private var paginationKey: String {
        "\(workID ?? "")|\(lastViewport.width)x\(lastViewport.height)|\(reading.textSize.rawValue)|\(reading.typeface.rawValue)|\(reading.lineSpacing.rawValue)|\(dynamicTypeSize)|\(colorScheme)"
    }

    @MainActor private func loadWork() async {
        guard let workID else { return }
        loadGeneration &+= 1
        positionGeneration &+= 1
        let generation = loadGeneration
        catalog = nil; work = nil; collection = nil; section = nil; summaries = []; pages = []; anchor = nil; storedAnchor = nil; loading = true; failed = false; lockedIndex = nil
        prefetchTask?.cancel(); sectionCache = [:]; sectionCacheKey = ""
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
        section = nil; pages = []; pageIndex = 0; loading = true; failed = false; saveNotice = nil; lockedIndex = nil
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
        } catch let locked as FathersLibraryLockedError {
            guard generation == loadGeneration else { return }
            loading = false; lockedIndex = locked.index
        } catch {
            guard generation == loadGeneration else { return }
            loading = false; failed = true
        }
    }

    @MainActor private func buildPages() async {
        guard let section else { return }
        // The actual viewport is measured by the GeometryReader. Keep a safe
        // provisional page until SwiftUI reports its current size.
        guard lastViewport.width > pageInset * 2, lastViewport.height > 0 else { return }
        let key = paginationKey
        if key != sectionCacheKey {
            prefetchTask?.cancel()
            sectionCache = [:]
            sectionCacheKey = key
        }
        pages = paginate(section)
        sectionCache[section.index] = PaginatedWorkSection(section: section, pages: pages)
        let preferredAnchor = anchor ?? storedAnchor
        let restoreAnchor = preferredAnchor?.sectionIndex == section.index ? preferredAnchor : nil
        if let restoreAnchor {
            let matchingPage = pages.lastIndex { page in
                guard let anchor = page.anchor else { return false }
                return anchor.paragraphIndex < restoreAnchor.paragraphIndex
                    || (anchor.paragraphIndex == restoreAnchor.paragraphIndex && anchor.utf16Offset <= restoreAnchor.utf16Offset)
            }
            if let matchingPage { pageIndex = matchingPage }
        }
        pageIndex = min(max(pageIndex, 0), max(pages.count - 1, 0))
        storedAnchor = nil
        // Keep the semantic position across layout changes. Page starts change
        // when the viewport changes, but the saved paragraph and text offset do not.
        anchor = restoreAnchor ?? currentPageAnchor
        bookRevision &+= 1
        schedulePrefetch()
    }

    @MainActor private func paginate(_ section: WorkSection) -> [WorkPageSlice] {
        let font = fontForReader()
        let lineHeight = lineHeightForReader(font.pointSize)
        let result = WorkTextPaginator.paginate(paragraphs: section.paragraphs,
                                                width: lastViewport.width - pageInset * 2,
                                                height: max(lastViewport.height, lineHeight),
                                                font: font, lineHeight: lineHeight,
                                                paragraphGap: 14, sectionIndex: section.index,
                                                foregroundColor: UIColor(colors.text))
        return result.isEmpty ? [WorkPageSlice(text: NSAttributedString(string: ""), anchor: try? WorksAnchor(sectionIndex: section.index, paragraphIndex: 0, utf16Offset: 0))] : result
    }

    /// Loads and paginates the sections on each side of the current one, so the
    /// page turn across a section boundary is ready before the reader gets there.
    @MainActor private func schedulePrefetch() {
        prefetchTask?.cancel()
        guard let workID, let work, let section else { return }
        let key = sectionCacheKey
        let center = section.index
        sectionCache = sectionCache.filter { abs($0.key - center) <= 1 }
        let wanted = [center + 1, center - 1].filter { $0 >= 0 && $0 < work.sectionCount }
        prefetchTask = Task { @MainActor in
            for index in wanted where sectionCache[index] == nil {
                guard let loaded = try? await runtime.workSection(workID: workID, index: index),
                      !Task.isCancelled, key == sectionCacheKey, workID == self.workID else { return }
                sectionCache[index] = PaginatedWorkSection(section: loaded, pages: paginate(loaded))
                bookRevision &+= 1
            }
        }
    }

    private func pageText(_ id: WorkPageID) -> NSAttributedString? {
        guard let pages = sectionCache[id.section]?.pages, pages.indices.contains(id.page) else { return nil }
        return pages[id.page].text
    }

    private func pageCount(forSection index: Int) -> Int? {
        sectionCache[index]?.pages.count
    }

    /// Called when a page turn finishes. A turn may cross into the next or the
    /// previous section; that section is already paginated in the cache.
    @MainActor private func settlePage(_ id: WorkPageID) {
        guard let current = section else { return }
        if id.section == current.index {
            changePage(id.page)
        } else if let entry = sectionCache[id.section], entry.pages.indices.contains(id.page) {
            adopt(entry, page: id.page)
        }
    }

    @MainActor private func adopt(_ entry: PaginatedWorkSection, page: Int) {
        loadGeneration &+= 1
        positionGeneration &+= 1
        section = entry.section
        pages = entry.pages
        pageIndex = page
        storedAnchor = nil
        anchor = entry.pages[page].anchor
        loading = false; failed = false; saveNotice = nil
        persistPosition(section: entry.section.index, page: page, anchor: anchor)
        schedulePrefetch()
    }

    @MainActor private func preserveAnchorAndRebuild() {
        anchor = anchor ?? storedAnchor ?? currentPageAnchor
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
        if let entry = sectionCache[index], !entry.pages.isEmpty, sectionCacheKey == paginationKey {
            adopt(entry, page: 0)
            return
        }
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

private struct PaginatedWorkSection {
    let section: WorkSection
    let pages: [WorkPageSlice]
}

private struct WorkPageID: Hashable {
    let section: Int
    let page: Int
}

/// A horizontal page book that works like Apple Books: the page follows the
/// finger, a tap on the left or right side turns the page, and a turn past the
/// last page of a section goes on into the next section.
private struct WorkPageBook: UIViewControllerRepresentable {
    let current: WorkPageID
    /// Changes when page text or the cached neighbor sections change.
    let revision: Int
    let horizontalInset: CGFloat
    let background: UIColor
    let text: (WorkPageID) -> NSAttributedString?
    let pageCount: (Int) -> Int?
    let onSettle: (WorkPageID) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal,
                                              options: [.interPageSpacing: 0])
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.view.backgroundColor = background
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        controller.view.addGestureRecognizer(tap)
        context.coordinator.controller = controller
        context.coordinator.show(current, revision: revision)
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        controller.view.backgroundColor = background
        // A finger is on the page. didFinishAnimating catches up afterwards.
        guard !coordinator.isTransitioning else { return }
        if coordinator.displayed != current || coordinator.revision != revision {
            coordinator.show(current, revision: revision)
        }
    }

    @MainActor final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate {
        var parent: WorkPageBook
        weak var controller: UIPageViewController?
        var displayed: WorkPageID?
        var revision = -1
        var isTransitioning = false
        private var touchBeganWithSelection = false

        init(parent: WorkPageBook) { self.parent = parent }

        func show(_ id: WorkPageID, revision: Int) {
            guard let controller, let page = makePage(id) else { return }
            self.revision = revision
            displayed = id
            controller.setViewControllers([page], direction: .forward, animated: false)
        }

        func neighbor(of id: WorkPageID, forward: Bool) -> WorkPageID? {
            if forward {
                if let count = parent.pageCount(id.section), id.page + 1 < count {
                    return WorkPageID(section: id.section, page: id.page + 1)
                }
                if let count = parent.pageCount(id.section + 1), count > 0 {
                    return WorkPageID(section: id.section + 1, page: 0)
                }
            } else {
                if id.page > 0 { return WorkPageID(section: id.section, page: id.page - 1) }
                if let count = parent.pageCount(id.section - 1), count > 0 {
                    return WorkPageID(section: id.section - 1, page: count - 1)
                }
            }
            return nil
        }

        private func makePage(_ id: WorkPageID) -> WorkPageController? {
            guard let text = parent.text(id) else { return nil }
            let page = WorkPageController(id: id, text: text, inset: parent.horizontalInset, background: parent.background)
            page.onAccessibilityScroll = { [weak self] forward in self?.turn(forward: forward) ?? false }
            return page
        }

        /// Turns one page for a tap or a VoiceOver three-finger swipe.
        @discardableResult func turn(forward: Bool) -> Bool {
            guard let controller, !isTransitioning, let displayed,
                  let target = neighbor(of: displayed, forward: forward), let page = makePage(target) else { return false }
            isTransitioning = true
            let direction: UIPageViewController.NavigationDirection = forward ? .forward : .reverse
            let animated = !UIAccessibility.isReduceMotionEnabled
            controller.setViewControllers([page], direction: direction, animated: animated) { [weak self] finished in
                guard let self else { return }
                if animated, finished {
                    // UIPageViewController keeps stale neighbors after an animated
                    // programmatic turn. A second, silent set refreshes them.
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.displayed == target, !self.isTransitioning else { return }
                        self.controller?.setViewControllers([page], direction: direction, animated: false)
                    }
                }
                self.finish(at: target)
            }
            return true
        }

        private func finish(at id: WorkPageID) {
            isTransitioning = false
            displayed = id
            parent.onSettle(id)
            if let count = parent.pageCount(id.section) {
                UIAccessibility.post(notification: .pageScrolled, argument: "Page \(id.page + 1) of \(count)")
            }
        }

        // MARK: Data source

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let page = viewController as? WorkPageController,
                  let target = neighbor(of: page.id, forward: false) else { return nil }
            return makePage(target)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let page = viewController as? WorkPageController,
                  let target = neighbor(of: page.id, forward: true) else { return nil }
            return makePage(target)
        }

        // MARK: Delegate

        func pageViewController(_ pageViewController: UIPageViewController,
                                willTransitionTo pendingViewControllers: [UIViewController]) {
            isTransitioning = true
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed, let page = pageViewController.viewControllers?.first as? WorkPageController {
                finish(at: page.id)
                return
            }
            isTransitioning = false
            // The turn was cancelled. Apply any update that arrived during the drag.
            if displayed != parent.current || revision != parent.revision {
                show(parent.current, revision: parent.revision)
            }
        }

        // MARK: Tap zones

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            touchBeganWithSelection = (controller?.viewControllers?.first as? WorkPageController)?.hasSelection ?? false
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let view = recognizer.view else { return }
            // The first tap after a text selection only clears the selection.
            guard !touchBeganWithSelection else { return }
            let x = recognizer.location(in: view).x
            let width = view.bounds.width
            if x < width * 0.3 { turn(forward: false) }
            else if x > width * 0.7 { turn(forward: true) }
        }
    }
}

private final class WorkPageController: UIViewController {
    let id: WorkPageID
    var onAccessibilityScroll: ((Bool) -> Bool)?
    private let text: NSAttributedString
    private let inset: CGFloat
    private let background: UIColor
    private let textView = UITextView()

    init(id: WorkPageID, text: NSAttributedString, inset: CGFloat, background: UIColor) {
        self.id = id
        self.text = text
        self.inset = inset
        self.background = background
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    var hasSelection: Bool { textView.selectedRange.length > 0 }

    override func loadView() {
        let root = WorkPageRootView()
        root.onAccessibilityScroll = { [weak self] forward in self?.onAccessibilityScroll?(forward) ?? false }
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = background
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.attributedText = text
        textView.accessibilityIdentifier = "works-prose-text"
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: inset),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -inset),
        ])
    }
}

/// Answers the VoiceOver three-finger swipe with a page turn.
private final class WorkPageRootView: UIView {
    var onAccessibilityScroll: ((Bool) -> Bool)?

    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        switch direction {
        case .left, .next: onAccessibilityScroll?(true) ?? false
        case .right, .previous: onAccessibilityScroll?(false) ?? false
        default: false
        }
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
