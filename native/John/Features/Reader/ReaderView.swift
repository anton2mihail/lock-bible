import SwiftUI
import UIKit
import JohnCore
import TipKit

struct ReaderView: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var chapterCellSize: CGFloat = 52
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var readerScrollPosition = ScrollPosition(idType: String.self)
    @State private var textGeometryProbe = ReaderTextGeometryProbe()
    @State private var readerScrollOffset: CGFloat = 0
    @State private var scriptureOriginY: CGFloat = 0
    @State private var scriptureGlobalY: CGFloat = 0
    @State private var readerViewportTopY: CGFloat = 0
    @State private var readerTopClipInset: CGFloat = 0
    @State private var anchorCaptureRequest: ReaderAnchorCaptureRequest?
    @State private var programmaticRestoreID: UUID?
    @State private var programmaticRestoreChapterID: UUID?
    @State private var programmaticRestoreY: CGFloat?
    @State private var workCatalog: WorkCatalog?
    @State private var lastContextRequestID: UUID?
    @State private var selectedBookmarkState: Bool?
    @State private var selectionFeedback: String?
    @State private var feedbackHaptic = ReaderFeedbackHaptic()
    @State private var isSelectionMutationRunning = false
    @State private var selectionIdentity = UUID()

    private var model: ReaderScreenModel { runtime.readerScreen }
    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var systemTextScale: CGFloat {
        switch dynamicTypeSize {
        case .xSmall: 0.823
        case .small: 0.882
        case .medium: 0.941
        case .large: 1
        case .xLarge: 1.118
        case .xxLarge: 1.235
        case .xxxLarge: 1.353
        case .accessibility1: 1.786
        case .accessibility2: 2.143
        case .accessibility3: 2.643
        case .accessibility4: 3.143
        case .accessibility5: 3.571
        @unknown default: 1
        }
    }
    private var readerBaseFontSize: CGFloat {
        switch preferences.reading.textSize {
        case .small: 16
        case .medium: 18
        case .large: 21
        case .extraLarge: 24
        }
    }
    private var readerColumnWidth: CGFloat {
        (readerBaseFontSize * systemTextScale * 34 + 48).rounded()
    }

    private func isCurrentSelection(_ passage: PassageSelection, chapterRequestID: UUID,
                                    selectionID: UUID) -> Bool {
        model.activeChapterRequestID == chapterRequestID &&
        model.selectedPassage?.id == passage.id && selectionIdentity == selectionID
    }

    @MainActor private func loadBookmarkState(_ passage: PassageSelection, chapterRequestID: UUID,
                                              selectionID: UUID) async {
        do {
            let saved = try await runtime.isBookmarked(passage.id)
            guard isCurrentSelection(passage, chapterRequestID: chapterRequestID, selectionID: selectionID) else { return }
            selectedBookmarkState = saved
        } catch {
            guard isCurrentSelection(passage, chapterRequestID: chapterRequestID, selectionID: selectionID) else { return }
            selectedBookmarkState = nil
            selectionFeedback = "Bookmark could not be updated"
        }
    }

    @MainActor private func toggleSelectedBookmark() async {
        guard !isSelectionMutationRunning, let passage = model.selectedPassage,
              let chapterRequestID = model.activeChapterRequestID else { return }
        let selectionID = selectionIdentity
        isSelectionMutationRunning = true
        defer { isSelectionMutationRunning = false }
        do {
            let isSaved = try await runtime.toggleBookmark(passage)
            guard isCurrentSelection(passage, chapterRequestID: chapterRequestID, selectionID: selectionID) else { return }
            selectedBookmarkState = isSaved
            selectionFeedback = isSaved ? "Bookmark saved" : "Bookmark removed"
            UIAccessibility.post(notification: .announcement, argument: selectionFeedback)
            feedbackHaptic.fire(failed: false)
        } catch {
            guard isCurrentSelection(passage, chapterRequestID: chapterRequestID, selectionID: selectionID) else { return }
            selectionFeedback = "Bookmark could not be updated"
            UIAccessibility.post(notification: .announcement, argument: selectionFeedback)
            feedbackHaptic.fire(failed: true)
        }
    }

    @MainActor private func updateSelectedHighlight(_ color: HighlightColor?) async {
        guard !isSelectionMutationRunning, let passage = model.selectedPassage,
              let chapterRequestID = model.activeChapterRequestID else { return }
        let selectionID = selectionIdentity
        isSelectionMutationRunning = true
        defer { isSelectionMutationRunning = false }
        do {
            if let color { try await runtime.applyHighlight(passage, color: color) }
            else { try await runtime.clearHighlight(passage) }
            let sameChapter = model.activeChapterRequestID == chapterRequestID &&
                model.edition == passage.translationID &&
                model.book?.code == passage.bookCode.rawValue &&
                model.currentChapterNumber == passage.chapter
            if sameChapter {
                model.applyVisibleHighlight(color, to: passage)
            }
            guard isCurrentSelection(passage, chapterRequestID: chapterRequestID, selectionID: selectionID) else { return }
            selectionFeedback = color.map { "\($0.rawValue.capitalized) highlight applied" } ?? "Highlight removed"
            UIAccessibility.post(notification: .announcement, argument: selectionFeedback)
            feedbackHaptic.fire(failed: false)
        } catch {
            guard isCurrentSelection(passage, chapterRequestID: chapterRequestID, selectionID: selectionID) else { return }
            selectionFeedback = "Highlight could not be updated"
            UIAccessibility.post(notification: .announcement, argument: selectionFeedback)
            feedbackHaptic.fire(failed: true)
        }
    }

    /// Pinch changes the text size in the existing steps. The step is set when the pinch ends.
    /// The Reader keeps the top verse in place, because the text view restores its anchor on reflow.
    private var textSizePinch: some Gesture {
        MagnifyGesture()
            .onEnded { value in
                let current = preferences.reading.textSize
                let target = ReaderTextSize.pinchTarget(from: current, scale: value.magnification)
                guard target != current else { return }
                PinchTextSizeTip().invalidate(reason: .actionPerformed)
                Task { _ = await runtime.applyWithResult(.setReaderTextSize(target)) }
            }
    }

    @MainActor private func copySelectedPassage() async {
        guard let passage = model.selectedPassage,
              let chapterRequestID = model.activeChapterRequestID else { return }
        let selectionID = selectionIdentity
        let abbreviation = await runtime.translationAbbreviation(passage.translationID)
        guard isCurrentSelection(passage, chapterRequestID: chapterRequestID, selectionID: selectionID) else { return }
        UIPasteboard.general.string = "\(passage.scriptureText) — \(reference(for: passage)) (\(abbreviation))"
        selectionFeedback = "Passage copied"
        UIAccessibility.post(notification: .announcement, argument: selectionFeedback)
        feedbackHaptic.fire(failed: false)
    }

    private func reference(for passage: PassageSelection) -> String {
        let verses = passage.startVerse == passage.endVerse
            ? passage.startVerse.rawValue
            : "\(passage.startVerse.rawValue)–\(passage.endVerse.rawValue)"
        return "\(passage.bookName) \(passage.chapter):\(verses)"
    }

    var body: some View {
        Group {
            switch model.screen {
            case .books:
                bookList
            case .chapters:
                chapterGrid
            case .chapter:
                chapterReader
            }
        }
        .background(colors.background)
        .sensoryFeedback(trigger: feedbackHaptic) { _, event in event.feedback }
        .task(id: preferences.translation) {
            await model.loadBooks(translation: preferences.translation, using: runtime)
            if let catalog = await runtime.worksCatalog() { workCatalog = catalog }
            if let request = runtime.reader.openRequest { await model.receive(request, using: runtime) }
            else { model.restoreLocation(preferences.readerLocation) }
        }
        .onChange(of: preferences.readerLocation) { _, location in
            model.restoreLocation(location)
        }
        .onChange(of: runtime.reader.openRequest?.id) { _, _ in
            guard let request = runtime.reader.openRequest else { return }
            Task { await model.receive(request, using: runtime) }
        }
        .onChange(of: model.selectedRange) { _, _ in
            selectionIdentity = UUID()
            selectedBookmarkState = nil
            selectionFeedback = nil
            guard let passage = model.selectedPassage,
                  let chapterRequestID = model.activeChapterRequestID else { return }
            let identity = selectionIdentity
            Task { await loadBookmarkState(passage, chapterRequestID: chapterRequestID, selectionID: identity) }
        }
        .onAppear { model.prepareVisibleLocationRestore(preferences.readerLocation) }
        .onChange(of: model.chapterScrollResetID) { _, resetID in
            guard resetID != nil,
                  model.pendingRestoreScrollY == nil,
                  model.pendingRestoreAnchor == nil else { return }
            readerScrollPosition.scrollTo(y: 0)
        }
        .sheet(item: Binding(get: { router.sheet }, set: { router.sheet = $0 })) { sheet in
            switch sheet {
            case .readerAppearance:
                ReaderTextSettingsSheet { router.sheet = nil }
            case .goTo:
                // Go to as a sheet (audit B6): the chapter stays in context above it, and a swipe down closes it.
                GoToView(initialBookCode: model.book?.code, initialChapter: model.currentChapterNumber,
                         presentedAsSheet: true)
                    .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
            }
        }
    }

    private var windowSafeAreaBoundaryY: CGFloat {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).first(where: \.isKeyWindow) else { return -1 }
        return window.frame.minY + window.safeAreaInsets.top
    }

    private var windowSafeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.safeAreaInsets.top ?? -1
    }

    private func updateUIKitReaderGeometry() {
        guard let measurement = textGeometryProbe.measure() else { return }
        scriptureGlobalY = measurement.text.minY
        readerViewportTopY = measurement.visibleViewport.minY
        readerTopClipInset = max(0, measurement.visibleViewport.minY - measurement.scroll.minY)
        scriptureOriginY = measurement.text.minY - readerViewportTopY
        #if DEBUG
        NSLog("L08_UIKIT_GEOMETRY textY=%.1f textH=%.1f scrollY=%.1f scrollH=%.1f effectiveTop=%.1f localTop=%.1f clipTop=%.1f",
              measurement.text.minY, measurement.text.height,
              measurement.scroll.minY, measurement.scroll.height,
              readerViewportTopY, measurement.visibleViewportInText.minY, readerTopClipInset)
        #endif
    }

    /// Shows the chapter text down from the top safe area. Above that line (under the status bar) the text fades out
    /// in one fixed band at the bottom of the safe area instead of a hard cut through the glyphs (audit B5). The band
    /// is at most 12 pt and leaves at least 20 pt fully clear at the top, so no text shows behind the status bar
    /// glyphs on a short safe area either. iPhone 17 Pro (62 pt): clear 0–50 pt, fade 50–62 pt.
    /// iPhone SE 3 (20 pt): clear 0–20 pt, no fade. At the bottom the mask goes into the safe area, so the text
    /// scrolls under the floating glass tab bar and the selection panel.
    /// The anchor math does not use this mask: `ReaderTextGeometryProbe` measures the visible viewport from the
    /// window safe area. The mask converts the key-window safe-area boundary to its local coordinates because its
    /// geometry ignores the safe area. With Reduce Transparency on, it keeps the hard cut at that boundary.
    private var readerTopSafeAreaMask: some View {
        GeometryReader { proxy in
            let globalOriginY = proxy.frame(in: .global).minY
            let boundary = windowSafeAreaBoundaryY
            let top = boundary >= 0
                ? max(0, boundary - globalOriginY)
                : max(0, proxy.safeAreaInsets.top)
            let fadeBand = reduceTransparency ? 0 : min(12, max(0, top - 20))
            VStack(spacing: 0) {
                Color.clear.frame(height: top - fadeBand)
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: fadeBand)
                Rectangle().fill(Color.black)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    private var bookList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                bookListHeader

                if let lastRead = model.lastRead,
                   let descriptor = model.books.first(where: { $0.code == lastRead.bookCode }) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Continue reading")
                            .font(bookListFont(13, weight: .medium))
                            .foregroundStyle(colors.textDim)
                        Button {
                            let location = preferences.readerLocation
                            Task {
                                await model.openChapter(descriptor, number: lastRead.chapter,
                                                        scrollY: location?.bookCode.rawValue == descriptor.code && location?.chapter == lastRead.chapter ? location?.scrollY ?? 0 : 0,
                                                        anchor: location?.bookCode.rawValue == descriptor.code && location?.chapter == lastRead.chapter ? location?.anchor : nil,
                                                        using: runtime)
                            }
                        } label: {
                            HStack {
                                Text("\(descriptor.name) \(lastRead.chapter)")
                                    .font(.custom("Lora-Regular", size: 20, relativeTo: .body))
                                Spacer()
                                FeatherIcon(name: "chevron-right", color: colors.tint)
                            }
                            .foregroundStyle(colors.text)
                            .padding(16)
                            .background(colors.card, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Continue reading \(descriptor.name) chapter \(lastRead.chapter)")
                        .accessibilityIdentifier("reader-continue-reading")
                    }
                    .padding(.horizontal, 24)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("The Church Fathers")
                        .font(bookListFont(13, weight: .medium))
                        .foregroundStyle(colors.textDim)
                    Button { router.push(.works) } label: {
                        HStack {
                            Text(fathersCountLabel)
                                .font(bookListFont(15, weight: .medium))
                            Spacer()
                            FeatherIcon(name: "chevron-right", color: colors.tint)
                        }
                        .foregroundStyle(colors.text)
                        .padding(16)
                        .background(colors.card, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("The Fathers and Doctors. \(workCatalog?.works.count ?? 0) works, available offline.")
                    .accessibilityIdentifier("reader-works-link")
                }
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 24) {
                    ForEach(BookGroupOrder.allCases, id: \.self) { group in
                        let groupBooks = model.books.filter { $0.group == group.rawValue }
                        if !groupBooks.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(group.title)
                                    .font(bookListFont(13, weight: .medium))
                                    .foregroundStyle(colors.textDim)
                                    .padding(.bottom, 6)
                                ForEach(groupBooks, id: \.code) { book in
                                    Button { model.openBook(book) } label: {
                                        HStack {
                                            Text(book.name)
                                                .font(bookListFont(16))
                                                .foregroundStyle(colors.text)
                                            Spacer()
                                            FeatherIcon(name: "chevron-right", color: colors.textDim)
                                        }
                                        .frame(minHeight: 52)
                                        .overlay(alignment: .bottom) { Rectangle().fill(colors.separator).frame(height: 1) }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(book.name), \(book.chapterCount) chapters")
                                    .accessibilityIdentifier("reader-book-\(book.code)")
                                }
                            }
                        }
                    }
                    if let message = model.message { MutedText(text: message) }
                }
                .frame(maxWidth: 740, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: 788, alignment: .leading)
            .padding(.top, 24)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .contentMargins(.top, max(0, windowSafeAreaTop), for: .scrollContent)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("reader-book-list")
    }

    private var bookListHeader: some View {
        let title = Text("Read the Bible")
            .font(.custom("SpaceGrotesk-Bold", size: 36, relativeTo: .largeTitle))
            .tracking(-0.8)
            .foregroundStyle(colors.text)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("reader-book-list-title")
        let searchButton = Button("Search") { router.push(.search) }
            .font(bookListFont(14, weight: .medium))
            .foregroundStyle(colors.tint)
            .frame(minHeight: 44)
            .accessibilityIdentifier("reader-search-button")

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    title
                    searchButton
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        title.fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 0)
                        searchButton
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        title
                        searchButton
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func bookListFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .light: name = "SpaceGrotesk-Light"
        case .medium: name = "SpaceGrotesk-Medium"
        case .semibold: name = "SpaceGrotesk-SemiBold"
        case .bold: name = "SpaceGrotesk-Bold"
        default: name = "SpaceGrotesk-Regular"
        }
        return .custom(name, size: size, relativeTo: .body)
    }

    private var chapterGrid: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ReaderHeader(title: model.book?.name ?? "Read", backLabel: "Back to books",
                             onBack: model.goBack, onTitlePress: openGoTo, onSearch: openSearch,
                             onTextSettings: nil, colors: colors)
                if let book = model.book {
                    Text("Choose a chapter")
                        .font(JohnTypography.sans(14))
                        .foregroundStyle(colors.textDim)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: chapterCellSize, maximum: chapterCellSize), spacing: 12)], spacing: 12) {
                        ForEach(1...book.chapterCount, id: \.self) { number in
                            Button {
                                Task { await model.openChapter(book, number: number, using: runtime) }
                            } label: {
                                Text(String(number))
                                    .font(JohnTypography.sans(16, weight: .medium))
                                    .foregroundStyle(number == model.currentChapterNumber ? colors.background : colors.text)
                                    .frame(width: chapterCellSize, height: chapterCellSize)
                                    .background(number == model.currentChapterNumber ? colors.tint : colors.card, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(book.name) chapter \(number)")
                            .accessibilityIdentifier("reader-chapter-\(number)")
                            .accessibilityAddTraits(number == model.currentChapterNumber ? .isSelected : [])
                            .id("reader-chapter-\(number)")
                        }
                    }
                }
            }
            .frame(maxWidth: 740, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
        .contentMargins(.top, max(0, windowSafeAreaTop), for: .scrollContent)
        .accessibilityIdentifier("reader-chapter-grid-scroll")
        .task(id: model.currentChapterNumber) {
            guard let current = model.currentChapterNumber else { return }
            await Task.yield()
            withAnimation(.none) {
                proxy.scrollTo("reader-chapter-\(current)", anchor: UnitPoint(x: 0.5, y: 0.33))
            }
        }
        }
    }

    private var chapterReader: some View {
        Group {
            if let book = model.book, let number = model.chapterNumber {
                if let chapter = model.chapter, let layout = model.layout {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ReaderHeader(title: "\(book.name) \(number)", backLabel: "Back to \(book.name) chapters",
                                         onBack: model.goBack, onTitlePress: openGoTo, onSearch: openSearch,
                                         onTextSettings: {
                                             #if DEBUG
                                             NSLog("John Aa action received")
                                             #endif
                                             router.sheet = .readerAppearance
                                         }, requestID: readerAccessibilityValue, colors: colors)
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                            if !preferences.selectionHintDismissed {
                                Text("Tap a verse to select it. Tap another verse to select a range.")
                                    .font(JohnTypography.sans(12))
                                    .foregroundStyle(colors.textDim)
                                    .padding(.bottom, 8)
                                    .accessibilityIdentifier("reader-selection-hint")
                            }
                            ScriptureTextView(
                                chapter: chapter,
                                layout: layout,
                                textSize: preferences.reading.textSize,
                                lineSpacing: preferences.reading.lineSpacing,
                                typeface: preferences.reading.typeface,
                                readerLayout: voiceOverEnabled ? .verses : preferences.reading.layout,
                                dynamicTypeScale: systemTextScale,
                                selectedRange: model.selectedRange,
                                contextRange: model.contextRange,
                                contextVerseIndex: model.pendingContextIndex,
                                highlights: model.highlightColors,
                                anchorCaptureRequest: anchorCaptureRequest,
                                anchorRestoreRequest: model.pendingRestoreAnchor,
                                chapterRequestID: model.activeChapterRequestID,
                                geometryProbe: textGeometryProbe,
                                isDark: colorScheme == .dark,
                                onTapVerse: { index in
                                    // VoiceOver activation comes here directly, without `onTapChapter`.
                                    guard router.sheet == nil else { router.sheet = nil; return }
                                    model.selectVerse(index)
                                    guard !preferences.selectionHintDismissed else { return }
                                    Task { _ = await runtime.applyWithResult(.setSelectionHintDismissed(true)) }
                                },
                                onTapChapter: {
                                    // With the Aa sheet open (background interaction up to the medium detent), a tap
                                    // on the chapter closes the sheet and selects nothing, as the old app does
                                    // (TextSettingsSheet.tsx:55). Scrolling behind the sheet stays allowed. Without a
                                    // selection, the selection panel cannot try to show a second sheet (Share).
                                    guard router.sheet != nil else { return false }
                                    router.sheet = nil
                                    return true
                                },
                                onContextVerseY: { y, renderedRequestID in
                                    // A UIKit layout callback can arrive while a new Reader request is replacing
                                    // the old chapter. Attribute the scroll to the chapter that produced this layout.
                                    guard let renderedRequestID,
                                          model.activeChapterRequestID == renderedRequestID else { return false }
                                    guard model.pendingContextIndex != nil else { return true }
                                    guard lastContextRequestID != renderedRequestID else { return true }
                                    // Mark the request done only when the scroll target exists. Without a window or
                                    // scroll view yet, the next layout pass tries again.
                                    guard let target = textGeometryProbe.scrollTargetY(forLocalY: y, margin: 24) else { return false }
                                    lastContextRequestID = renderedRequestID
                                    readerScrollPosition.scrollTo(y: target)
                                    return true
                                },
                                onVisibleAnchor: { request, anchor in
                                    Task {
                                        guard anchorCaptureRequest?.id == request.id,
                                              model.activeChapterRequestID == request.chapterRequestID,
                                              model.pendingRestoreAnchor == nil,
                                              programmaticRestoreID == nil else { return }
                                        #if DEBUG
                                        NSLog("L08_ANCHOR_CALLBACK request=%@ localY=%.1f offset=%.1f anchor=%@",
                                              request.id.uuidString, request.localY, request.scrollY,
                                              anchor.map { "\($0.verseLabel.rawValue):\($0.utf16Offset)" } ?? "none")
                                        #endif
                                        guard model.pendingRestoreScrollY == nil,
                                              model.pendingRestoreAnchor == nil,
                                              programmaticRestoreID == nil,
                                              model.activeChapterRequestID == request.chapterRequestID else { return }
                                        #if DEBUG
                                        NSLog("L08_ANCHOR_CAPTURE request=%@ book=%@ chapter=%d scrollY=%.1f anchor=%@",
                                              request.id.uuidString, request.bookCode, request.chapter, request.scrollY,
                                              anchor.map { "\($0.verseLabel.rawValue):\($0.utf16Offset)" } ?? "none")
                                        #endif
                                        await model.saveScrollLocation(request.scrollY,
                                                                       bookCode: request.bookCode,
                                                                       chapter: request.chapter,
                                                                       requestID: request.chapterRequestID,
                                                                       anchor: anchor,
                                                                       using: runtime)
                                    }
                                },
                                onAnchorRestoreY: { request, y in
                                    guard model.activeChapterRequestID == request.chapterRequestID else { return }
                                    if let pending = model.pendingRestoreAnchor, pending.id != request.id { return }
                                    if let y {
                                        guard let target = textGeometryProbe.scrollTargetY(forLocalY: y, margin: 24) else { return }
                                        programmaticRestoreID = request.id
                                        programmaticRestoreChapterID = request.chapterRequestID
                                        programmaticRestoreY = target
                                        readerScrollPosition.scrollTo(y: target)
                                    } else if let fallback = model.pendingRestoreScrollY {
                                        programmaticRestoreID = request.id
                                        programmaticRestoreChapterID = request.chapterRequestID
                                        programmaticRestoreY = fallback
                                        readerScrollPosition.scrollTo(y: fallback)
                                    } else {
                                        model.clearPendingRestoreAnchor(request.id)
                                        programmaticRestoreID = nil
                                        programmaticRestoreChapterID = nil
                                        programmaticRestoreY = nil
                                    }
                                }
                            )
                            .padding(.top, 12)
                            if let range = model.selectedRange, chapter.verses.indices.contains(range.lowerBound), chapter.verses.indices.contains(range.upperBound) {
                                // Accessibility only (audit B4). The old app shows no such line, so the text is clear
                                // and takes no layout height (1 pt frame, -1 pt padding). VoiceOver reads it after the
                                // chapter text, and UI tests read the range from `reader-selection-summary`.
                                let summary = "Selected: verses \(chapter.verses[range.lowerBound].label)–\(chapter.verses[range.upperBound].label)"
                                Text(summary)
                                    .font(JohnTypography.sans(13, weight: .medium))
                                    .foregroundStyle(.clear)
                                    .frame(maxWidth: .infinity, minHeight: 1, maxHeight: 1, alignment: .topLeading)
                                    .padding(.bottom, -1)
                                    .allowsHitTesting(false)
                                    .accessibilityLabel(summary)
                                    .accessibilityIdentifier("reader-selection-summary")
                            }
                            chapterCommentary(book: book, chapter: number)
                            HStack(spacing: 12) {
                                if model.chapterNumber ?? 1 > 1 || model.adjacentBook(-1) != nil {
                                    let target = model.adjacentChapter(-1)
                                    Button { Task { await model.moveChapter(-1, using: runtime) } } label: {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Label("Previous", systemImage: "chevron.left").font(JohnTypography.sans(13, weight: .medium))
                                            Text(target.map { "\($0.book.name) \($0.chapter)" } ?? "")
                                                .font(JohnTypography.serif(15)).lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityLabel("Previous, \(target.map { "\($0.book.name) chapter \($0.chapter)" } ?? "")")
                                    .accessibilityIdentifier("reader-previous-chapter")
                                }
                                if model.chapterNumber ?? 1 < (model.book?.chapterCount ?? 1) || model.adjacentBook(1) != nil {
                                    let target = model.adjacentChapter(1)
                                    Button { Task { await model.moveChapter(1, using: runtime) } } label: {
                                        VStack(alignment: .trailing, spacing: 3) {
                                            Label("Next", systemImage: "chevron.right").font(JohnTypography.sans(13, weight: .medium))
                                            Text(target.map { "\($0.book.name) \($0.chapter)" } ?? "")
                                                .font(JohnTypography.serif(15)).lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .trailing)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityLabel("Next, \(target.map { "\($0.book.name) chapter \($0.chapter)" } ?? "")")
                                    .accessibilityIdentifier("reader-next-chapter")
                                }
                            }
                            StaticTipView(tip: PinchTextSizeTip(), identifier: "tip-pinch-text")
                            StaticTipView(tip: ShareVerseTip(), identifier: "tip-share-verse")
                            if !model.editionAttribution.isEmpty {
                                Text(model.editionAttribution)
                                    .font(JohnTypography.sans(11))
                                    .foregroundStyle(colors.textDim)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .accessibilityIdentifier("reader-edition-attribution")
                            }
                        }
                        .padding(.horizontal, 24)
                        .frame(maxWidth: readerColumnWidth, alignment: .leading)
                        .padding(.bottom, 44)
                        .frame(maxWidth: .infinity)
                    }
                    .mask(alignment: .top) { readerTopSafeAreaMask }
                    // A soft system edge effect at the top, never `.hard` on a reading screen (audit B5 and 1.5).
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    .coordinateSpace(name: "readerScroll")
                    .scrollPosition($readerScrollPosition)
                    .simultaneousGesture(textSizePinch)
                    .onAppear { JohnTips.noteUse() }
                    .accessibilityValue(String(format: "%.1f", windowSafeAreaTop))
                    .onAppear {
                        updateUIKitReaderGeometry()
                        // Backup for the request-ID reset. Skip when this chapter must restore a place or a verse.
                        guard model.pendingRestoreScrollY == nil,
                              model.pendingRestoreAnchor == nil,
                              model.pendingContextIndex == nil else { return }
                        readerScrollPosition.scrollTo(y: 0)
                    }
                    .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, value in
                        readerScrollOffset = value
                        updateUIKitReaderGeometry()
                        #if DEBUG
                        NSLog("L08_SCROLL_GEOMETRY offset=%.1f textOrigin=%.1f textGlobal=%.1f viewportEffective=%.1f safeTop=%.1f",
                              value, scriptureOriginY, scriptureGlobalY, readerViewportTopY,
                              windowSafeAreaTop)
                        #endif
                        if let target = programmaticRestoreY, abs(value - target) <= 2 {
                            finishProgrammaticRestore()
                        }
                    }
                    .onScrollPhaseChange { oldPhase, phase in
                        #if DEBUG
                        NSLog("L08_SCROLL_PHASE old=%@ new=%@ offset=%.1f textOrigin=%.1f",
                              String(describing: oldPhase), String(describing: phase),
                              readerScrollOffset, scriptureOriginY)
                        #endif
                        guard phase == .idle else { return }
                        #if DEBUG
                        NSLog("L08_ANCHOR_IDLE_STATE offset=%.1f textOrigin=%.1f pendingRaw=%@ pendingAnchor=%@ restore=%@ chapterRequest=%@",
                              readerScrollOffset, scriptureOriginY,
                              model.pendingRestoreScrollY.map { String(describing: $0) } ?? "none",
                              model.pendingRestoreAnchor?.id.uuidString ?? "none",
                              programmaticRestoreID?.uuidString ?? "none",
                              model.activeChapterRequestID?.uuidString ?? "none")
                        #endif
                        if programmaticRestoreID != nil {
                            finishProgrammaticRestore()
                            return
                        }
                        guard model.pendingRestoreScrollY == nil,
                              model.pendingRestoreAnchor == nil,
                              programmaticRestoreID == nil,
                              let measurement = textGeometryProbe.measure(),
                              measurement.visibleViewportInText.minY.isFinite,
                              let activeBook = model.book?.code,
                              let activeChapter = model.chapterNumber,
                              let requestID = model.activeChapterRequestID else { return }
                        anchorCaptureRequest = ReaderAnchorCaptureRequest(
                            id: UUID(), localY: measurement.visibleViewportInText.minY, bookCode: activeBook,
                            chapter: activeChapter, scrollY: Double(measurement.contentOffsetY), chapterRequestID: requestID
                        )
                        #if DEBUG
                        NSLog("L08_ANCHOR_IDLE book=%@ chapter=%d scrollY=%.1f textOrigin=%.1f localY=%.1f",
                              activeBook, activeChapter, measurement.contentOffsetY, scriptureOriginY,
                              measurement.visibleViewportInText.minY)
                        #endif
                    }
                    .task(id: model.pendingRestoreScrollY) {
                        guard let y = model.pendingRestoreScrollY, model.pendingRestoreAnchor == nil else { return }
                        guard let requestID = model.activeChapterRequestID else { return }
                        await Task.yield()
                        guard !Task.isCancelled,
                              model.activeChapterRequestID == requestID,
                              model.pendingRestoreScrollY == y,
                              model.pendingRestoreAnchor == nil else { return }
                        programmaticRestoreID = UUID()
                        programmaticRestoreChapterID = requestID
                        programmaticRestoreY = y
                        readerScrollPosition.scrollTo(y: y)
                    }
                    .accessibilityIdentifier("reader-chapter-scroll")
                    // The selection panel floats over the chapter (audit B3). As a bottom safe-area inset it sits above
                    // the tab bar (full or minimized), and the scroll view keeps its full height: Scripture scrolls under
                    // the glass, and the content inset still lets the chapter end scroll clear of the panel. The panel
                    // is outside the top mask, so the mask never clips it.
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                    if let passage = model.selectedPassage {
                        ReaderSelectionToolbar(
                            passage: passage,
                            displayReference: reference(for: passage),
                            bookmarkStateKnown: selectedBookmarkState != nil,
                            isBookmarked: selectedBookmarkState ?? false,
                            highlightColor: model.selectedHighlightColor,
                            hasAnyHighlight: model.selectedHasHighlight,
                            feedback: selectionFeedback,
                            isBusy: isSelectionMutationRunning,
                            onClose: model.clearSelection,
                            onBookmark: { Task { await toggleSelectedBookmark() } },
                            onHighlight: { color in
                                Task { await updateSelectedHighlight(model.selectedHighlightColor == color ? nil : color) }
                            },
                            onClearHighlight: { Task { await updateSelectedHighlight(nil) } },
                            onNote: { router.push(.noteEditor(passage)) },
                            onCopy: { Task { await copySelectedPassage() } },
                            onPray: { router.push(.companion(.lectio(passage))) },
                            onCard: { router.push(.companion(.scriptureCard(passage))) }
                        )
                        .frame(maxWidth: readerColumnWidth)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity)
                    }
                    }
                } else if model.isLoading {
                    ScrollView {
                        VStack(spacing: 20) {
                            ReaderHeader(title: "\(book.name) \(number)", backLabel: "Back to \(book.name) chapters",
                                         onBack: model.goBack, onTitlePress: openGoTo, onSearch: openSearch,
                                         onTextSettings: { router.sheet = .readerAppearance }, colors: colors)
                        .padding(.horizontal, 24)
                                .padding(.top, 10)
                            ProgressView()
                            Spacer(minLength: 200)
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            ReaderHeader(title: "\(book.name) \(number)", backLabel: "Back to \(book.name) chapters",
                                         onBack: model.goBack, onTitlePress: openGoTo, onSearch: openSearch,
                                         onTextSettings: { router.sheet = .readerAppearance }, colors: colors)
                        .padding(.horizontal, 24)
                                .padding(.top, 10)
                            ContentUnavailableView("Chapter unavailable", systemImage: "book", description: Text(model.message ?? "Try another chapter."))
                        }
                    }
                }
            }
        }
    }

    private func finishProgrammaticRestore() {
        guard let id = programmaticRestoreID else { return }
        if let chapterID = programmaticRestoreChapterID,
           model.activeChapterRequestID != chapterID {
            programmaticRestoreID = nil
            programmaticRestoreChapterID = nil
            programmaticRestoreY = nil
            return
        }
        model.clearPendingRestoreAnchor(id)
        model.clearPendingRestore()
        programmaticRestoreID = nil
        programmaticRestoreChapterID = nil
        programmaticRestoreY = nil
    }

    private func openGoTo() {
        router.sheet = .goTo
    }

    private func openSearch() { router.push(.search) }

    @ViewBuilder private func chapterCommentary(book: BibleBookDescriptor, chapter: Int) -> some View {
        let entries = workCatalog?.commentary[book.code]?[String(chapter)] ?? []
        if !entries.isEmpty {
            let collectionIDs = Set(entries.map(\.collectionID))
            let singleCollection = collectionIDs.count == 1
                ? workCatalog?.collections.first(where: { $0.id == collectionIDs.first })
                : nil
            VStack(alignment: .leading, spacing: 8) {
                Text(singleCollection.map { "\($0.author) on this chapter" } ?? "The Fathers on this chapter")
                    .font(JohnTypography.sans(16, weight: .semibold))
                    .foregroundStyle(colors.text)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    ForEach(Array(entries.prefix(3).enumerated()), id: \.element) { offset, entry in
                        let isLastShown = offset == min(entries.count, 3) - 1
                        let showsSeparator = !isLastShown || entries.count > 3
                        Button {
                            router.push(.workReader(workID: entry.workID, section: entry.sectionIndex))
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(collectionIDs.count > 1
                                         ? "\(entry.sectionTitle) · \(workCatalog?.collections.first(where: { $0.id == entry.collectionID })?.author ?? "")"
                                         : entry.sectionTitle)
                                        .font(JohnTypography.sans(15, weight: .medium))
                                        .foregroundStyle(colors.text)
                                    Text(entry.workTitle)
                                        .font(JohnTypography.sans(12))
                                        .foregroundStyle(colors.textDim)
                                }
                                Spacer(minLength: 0)
                                FeatherIcon(name: "chevron-right", color: colors.tint)
                            }
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                            .contentShape(Rectangle())
                            .overlay(alignment: .bottom) {
                                if showsSeparator {
                                    Rectangle().fill(colors.separator).frame(height: 1 / displayScale)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(entry.sectionTitle), \(entry.workTitle)")
                        .accessibilityIdentifier("reader-commentary-\(entry.workID)-\(entry.sectionIndex)")
                    }
                    if entries.count > 3 {
                        Button {
                            router.push(.worksChapterCommentary(bookCode: book.code, chapter: chapter, bookName: book.name))
                        } label: {
                            HStack {
                                Text("All \(entries.count) readings on this chapter")
                                Spacer()
                                FeatherIcon(name: "chevron-right", color: colors.tint)
                            }
                            .font(JohnTypography.sans(15, weight: .medium))
                            .foregroundStyle(colors.text)
                            .frame(maxWidth: .infinity, minHeight: 56)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("reader-commentary-all")
                    }
                }
                .padding(.horizontal, 12)
                .background(colors.card, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.top, 24)
        }
    }

    private var fathersCountLabel: String {
        guard let catalog = workCatalog else { return "26 authors · 271 works" }
        if catalog.collections.count == 1, let collection = catalog.collections.first {
            return "\(collection.author) · \(catalog.works.count) works"
        }
        return "\(catalog.collections.count) authors · \(catalog.works.count) works"
    }

    private var readerAccessibilityValue: String? {
        #if DEBUG
        let request = model.activeChapterRequestID?.uuidString ?? "none"
        guard let book = model.book?.code, let chapter = model.chapterNumber,
              let location = preferences.readerLocation,
              location.bookCode.rawValue == book, location.chapter == chapter,
              let anchor = location.anchor else {
            return "request=\(request);anchor=none"
        }
        return "request=\(request);anchor=\(anchor.verseLabel.rawValue):\(anchor.utf16Offset)"
        #else
        return nil
        #endif
    }
}

enum BookGroupOrder: String, CaseIterable {
    case ot, deutero, nt
    var title: String {
        switch self {
        case .ot: "Old Testament"
        case .deutero: "Deuterocanon"
        case .nt: "New Testament"
        }
    }
}

private struct ReaderHeader: View {
    let title: String
    let backLabel: String
    let onBack: () -> Void
    let onTitlePress: () -> Void
    let onSearch: () -> Void
    let onTextSettings: (() -> Void)?
    var requestID: String? = nil
    let colors: JohnColors
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center, spacing: 4) {
            Button(action: onBack) { backIcon }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(backLabel)
                .accessibilityIdentifier("reader-back")

            Button(action: onTitlePress) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(JohnTypography.sans(36, weight: .bold))
                        .tracking(-0.7)
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                    FeatherIcon(name: "chevron-down", color: colors.text)
                }
                .foregroundStyle(colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityIdentifier("reader-title")
            #if DEBUG
            .accessibilityValue(requestID ?? "")
            #endif

            if let onTextSettings {
                Button(action: onTextSettings) {
                    Text("Aa")
                        .font(JohnTypography.sans(18, weight: .semibold))
                        .foregroundStyle(colors.tint)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Text settings")
                .accessibilityIdentifier("reader-appearance-button")
            }

            Button(action: onSearch) {
                FeatherIcon(name: "search", color: colors.tint)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Search Scripture")
            .accessibilityIdentifier("reader-search-button")
        }
        .frame(minHeight: 44)
        .dynamicTypeSize(.xSmall ... .xLarge)
    }

    @ViewBuilder private var backIcon: some View {
        if let url = Bundle.main.url(forResource: "caretLeft@3x", withExtension: "png",
                                     subdirectory: "App/Artwork/icons"),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(colors.text)
                .frame(width: 24, height: 24)
                .frame(width: 44, height: 44, alignment: .leading)
        } else {
            FeatherIcon(name: "chevron-left", color: colors.text)
                .frame(width: 44, height: 44, alignment: .leading)
        }
    }
}

/// The Reader Aa sheet. It shows the same choice controls as Settings → Reading (`ReadingSettingsChoices`), as the old
/// app's `TextSettingsSheet.tsx` does. It has no Bible edition control, because the old Aa sheet had none. The edition
/// stays in Settings → Translation. At the medium detent the chapter stays visible and scrollable behind the sheet, so
/// each choice shows in the text at once. The sheet keeps the system (Liquid Glass) sheet background. With Reduce
/// Transparency on, the system makes that background solid.
private struct ReaderTextSettingsSheet: View {
    let onDone: () -> Void
    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var saveMessage: String?
    @State private var saveGeneration = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let saveMessage {
                        Text(saveMessage)
                            .font(JohnTypography.sans(14))
                            .foregroundStyle(preferences.colors(for: colorScheme).textDim)
                            .padding(.bottom, 8)
                            .contentAnnouncement(saveMessage)
                    }
                    ReadingSettingsChoices(save: save)
                }
                .padding(.horizontal, 16)
                .padding(.horizontal, 8)
                .padding(.bottom, 16)
                .frame(maxWidth: 600, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Text settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                        .accessibilityIdentifier("reader-appearance-close")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationContentInteraction(.scrolls)
    }

    private func save(_ mutation: NativeStateMutation) {
        saveGeneration += 1
        let generation = saveGeneration
        Task {
            let success = await runtime.applyWithResult(mutation)
            guard generation == saveGeneration else { return }
            saveMessage = success ? nil : "The setting could not be saved. Your previous choice is still active."
        }
    }
}

/// One haptic event for a finished Reader selection action. The counter makes two equal
/// outcomes in a row (for example two copies) fire twice.
private struct ReaderFeedbackHaptic: Equatable {
    private var count = 0
    private var failed = false

    mutating func fire(failed: Bool) {
        count += 1
        self.failed = failed
    }

    var feedback: SensoryFeedback? {
        guard count > 0 else { return nil }
        return failed ? .error : .success
    }
}

extension ReaderTextSize {
    static let pinchSteps: [ReaderTextSize] = [.small, .medium, .large, .extraLarge]

    /// Maps a pinch scale to a size step. Each 1.2x of scale moves one step. The result stays in range.
    static func pinchTarget(from current: ReaderTextSize, scale: CGFloat) -> ReaderTextSize {
        guard scale.isFinite, scale > 0, let index = pinchSteps.firstIndex(of: current) else { return current }
        let delta = Int((log(Double(scale)) / log(1.2)).rounded())
        return pinchSteps[min(max(index + delta, 0), pinchSteps.count - 1)]
    }
}
