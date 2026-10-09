import SwiftUI
import UIKit
import JohnCore

@MainActor final class ReaderTextGeometryProbe {
    weak var view: ReaderTextKitView?

    struct Measurement {
        let text: CGRect
        let scroll: CGRect
        let contentSize: CGSize
        let contentOffsetY: CGFloat
        let visibleViewport: CGRect
        let visibleViewportInText: CGRect
    }

    func measure() -> Measurement? {
        guard let view, let window = view.window else { return nil }
        var ancestor: UIView? = view.superview
        while let current = ancestor, !(current is UIScrollView) { ancestor = current.superview }
        guard let scrollView = ancestor as? UIScrollView else { return nil }
        let textRect = view.convert(view.bounds, to: window)
        let scrollRect = scrollView.convert(scrollView.bounds, to: window)
        let visibleRect = scrollRect.intersection(window.safeAreaLayoutGuide.layoutFrame)
        guard !visibleRect.isNull, visibleRect.width > 0, visibleRect.height > 0 else { return nil }
        return Measurement(text: textRect,
                           scroll: scrollRect,
                           contentSize: scrollView.contentSize,
                           contentOffsetY: scrollView.contentOffset.y,
                           visibleViewport: visibleRect,
                           visibleViewportInText: view.convert(visibleRect, from: window))
    }

    func scrollTargetY(forLocalY localY: CGFloat, margin: CGFloat) -> CGFloat? {
        guard let measurement = measure(), localY.isFinite else { return nil }
        let target = max(0, measurement.contentOffsetY + measurement.text.minY - measurement.visibleViewport.minY + localY - margin)
        #if DEBUG
        NSLog("L08_RESTORE_TARGET offset=%.1f textY=%.1f viewportY=%.1f localY=%.1f margin=%.1f target=%.1f contentH=%.1f viewportH=%.1f",
              measurement.contentOffsetY, measurement.text.minY, measurement.visibleViewport.minY,
              localY, margin, target, measurement.contentSize.height, measurement.visibleViewport.height)
        #endif
        return target
    }
}

struct ReaderAnchorCaptureRequest: Equatable {
    let id: UUID
    let localY: CGFloat
    let bookCode: String
    let chapter: Int
    let scrollY: Double
    let chapterRequestID: UUID
}

struct ReaderAnchorRestoreRequest: Equatable {
    let id: UUID
    let anchor: ReaderAnchor
    let chapterRequestID: UUID
}

struct ReaderRenderSignature: Equatable {
    let textSize: ReaderTextSize
    let lineSpacing: ReaderLineSpacing
    let typeface: ReaderTypeface
    let layout: ReaderLayout
    let dynamicTypeScale: CGFloat
    let width: CGFloat
    let chapterRequestID: UUID?
}

struct ScriptureTextView: UIViewRepresentable {
    let chapter: BibleChapter
    let layout: ChapterLayout
    let textSize: ReaderTextSize
    let lineSpacing: ReaderLineSpacing
    let typeface: ReaderTypeface
    let readerLayout: ReaderLayout
    let dynamicTypeScale: CGFloat
    let selectedRange: ClosedRange<Int>?
    let contextRange: ClosedRange<Int>?
    let contextVerseIndex: Int?
    let highlights: [Int: HighlightColor]
    let anchorCaptureRequest: ReaderAnchorCaptureRequest?
    let anchorRestoreRequest: ReaderAnchorRestoreRequest?
    let chapterRequestID: UUID?
    let geometryProbe: ReaderTextGeometryProbe
    let isDark: Bool
    let onTapVerse: (Int) -> Void
    /// Runs first on each tap on the chapter text, also between verses. True takes the tap: no verse selection.
    let onTapChapter: () -> Bool
    /// Returns true when the context verse scroll is done (now or before). False means "not ready, try again".
    let onContextVerseY: (CGFloat, UUID?) -> Bool
    let onVisibleAnchor: (ReaderAnchorCaptureRequest, ReaderAnchor?) -> Void
    let onAnchorRestoreY: (ReaderAnchorRestoreRequest, CGFloat?) -> Void

    func makeUIView(context: Context) -> ReaderTextKitView {
        let view = ReaderTextKitView()
        geometryProbe.view = view
        view.onTapVerse = onTapVerse
        view.chapter = chapter
        view.verseLabels = chapter.verses.map(\.label)
        view.verseDescriptions = chapter.verses.map(\.text)
        view.contextVerseIndex = contextVerseIndex
        view.onContextVerseY = context.coordinator.contextVerseY
        view.readerLayout = readerLayout
        view.contextRange = contextRange
        view.savedHighlights = highlights.mapValues(highlightColor)
        view.highlightNames = highlights.mapValues { "\($0.rawValue.capitalized) highlight" }
        view.selectionTint = UIColor(isDark ? JohnColors.dark.tint : JohnColors.light.tint)
        view.accessibilityIdentifier = "reader-scripture-text"
        view.backgroundColor = .clear
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didTap(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: ReaderTextKitView, context: Context) {
        context.coordinator.parent = self
        geometryProbe.view = view
        let signature = ReaderRenderSignature(textSize: textSize, lineSpacing: lineSpacing,
                                              typeface: typeface, layout: readerLayout,
                                              dynamicTypeScale: dynamicTypeScale,
                                              width: view.textContainer.size.width,
                                              chapterRequestID: chapterRequestID)
        let currentViewportY = geometryProbe.measure()?.visibleViewportInText.minY
        let reflowAnchor: ReaderAnchor?
        // The first real width (from 0) is the initial layout, not a reflow. A reflow anchor taken then is the
        // chapter top, and its restore can undo a context verse scroll that lands in the same pass.
        if anchorRestoreRequest == nil,
           let previous = context.coordinator.renderSignature, previous != signature,
           previous.width > 0,
           previous.chapterRequestID == signature.chapterRequestID,
           let currentViewportY, currentViewportY.isFinite {
            reflowAnchor = view.visibleAnchor(atY: currentViewportY)
        } else {
            reflowAnchor = nil
        }
        view.onTapVerse = onTapVerse
        view.chapter = chapter
        view.chapterRequestID = chapterRequestID
        view.verseLabels = chapter.verses.map(\.label)
        view.verseDescriptions = chapter.verses.map(\.text)
        view.contextVerseIndex = contextVerseIndex
        view.onContextVerseY = context.coordinator.contextVerseY
        view.readerLayout = readerLayout
        view.contextRange = contextRange
        view.savedHighlights = highlights.mapValues(highlightColor)
        view.highlightNames = highlights.mapValues { "\($0.rawValue.capitalized) highlight" }
        view.selectionTint = UIColor(isDark ? JohnColors.dark.tint : JohnColors.light.tint)
        view.resetVerseRowMinimumAdjustments()
        let result = makeAttributedText()
        view.verseRanges = result.verseRanges
        view.verseBodyRanges = result.verseBodyRanges
        view.headingRanges = result.headingRanges
        view.activeSelection = selectedRange
        view.attributedText = result.text
        view.invalidateIntrinsicContentSize()
        view.setNeedsLayout()
        view.layoutManager.ensureLayout(for: view.textContainer)
        view.applyVerseRowMinimums()
        view.layoutManager.ensureLayout(for: view.textContainer)

        if let anchor = reflowAnchor, let y = view.documentY(for: anchor) {
            if let chapterRequestID {
                let request = ReaderAnchorRestoreRequest(id: UUID(), anchor: anchor, chapterRequestID: chapterRequestID)
                context.coordinator.scheduleRestore(request, y: y, isReflow: true)
            }
        }
        context.coordinator.renderSignature = signature

        if let request = anchorCaptureRequest, context.coordinator.lastCaptureID != request.id {
            context.coordinator.lastCaptureID = request.id
            let anchor = view.visibleAnchor(atY: request.localY)
            DispatchQueue.main.async { self.onVisibleAnchor(request, anchor) }
        }
        if let request = anchorRestoreRequest, context.coordinator.lastRestoreID != request.id {
            let y = view.documentY(for: request.anchor)
            context.coordinator.scheduleRestore(request, y: y)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ReaderTextKitView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let previousWidth = uiView.textContainer.size.width
        let widthChanged = previousWidth > 0 && abs(previousWidth - width) > 0.5
        let viewportY = context.coordinator.parent.geometryProbe.measure()?.visibleViewportInText.minY
        let reflowAnchor = widthChanged && context.coordinator.parent.anchorRestoreRequest == nil
            ? viewportY.flatMap { $0.isFinite ? uiView.visibleAnchor(atY: $0) : nil }
            : nil
        uiView.textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        uiView.layoutManager.ensureLayout(for: uiView.textContainer)
        uiView.applyVerseRowMinimums()
        uiView.layoutManager.ensureLayout(for: uiView.textContainer)
        let height = uiView.layoutManager.usedRect(for: uiView.textContainer).height
        if let reflowAnchor, let chapterRequestID = uiView.chapterRequestID,
           let y = uiView.documentY(for: reflowAnchor) {
            let request = ReaderAnchorRestoreRequest(id: UUID(), anchor: reflowAnchor, chapterRequestID: chapterRequestID)
            context.coordinator.scheduleRestore(request, y: y, isReflow: true)
        }
        return CGSize(width: width, height: ceil(height))
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor final class Coordinator: NSObject {
        var parent: ScriptureTextView
        weak var view: ReaderTextKitView?
        var renderSignature: ReaderRenderSignature?
        var lastCaptureID: UUID?
        var lastRestoreID: UUID?
        var scheduledRestoreID: UUID?
        private var scheduledRestoreIsReflow = false
        init(parent: ScriptureTextView) { self.parent = parent }

        /// A context verse scroll (URL verse, saved passage, Read in context) wins over a reflow restore that is
        /// still waiting for a stable layout: that anchor was read before the context scroll. A saved-location
        /// restore (`anchorRestoreRequest`) is not a reflow and stays scheduled.
        func contextVerseY(_ y: CGFloat, chapterRequestID: UUID?) -> Bool {
            guard parent.onContextVerseY(y, chapterRequestID) else { return false }
            if scheduledRestoreIsReflow {
                scheduledRestoreID = nil
                scheduledRestoreIsReflow = false
            }
            return true
        }

        func scheduleRestore(_ request: ReaderAnchorRestoreRequest, y: CGFloat?, isReflow: Bool = false) {
            guard lastRestoreID != request.id, scheduledRestoreID != request.id else { return }
            scheduledRestoreID = request.id
            scheduledRestoreIsReflow = isReflow
            Task { @MainActor [weak self] in
                guard let self else { return }
                var priorContentSize: CGSize?
                var stableLayoutSamples = 0
                for _ in 0..<40 {
                    try? await Task.sleep(for: .milliseconds(50))
                    guard parent.chapterRequestID == request.chapterRequestID else {
                        if scheduledRestoreID == request.id { scheduledRestoreID = nil }
                        return
                    }
                    guard scheduledRestoreID == request.id,
                          let view,
                          let measurement = parent.geometryProbe.measure(),
                          measurement.text.width > 0,
                          measurement.visibleViewport.height > 0,
                          parent.chapterRequestID == request.chapterRequestID else { continue }
                    view.layoutManager.ensureLayout(for: view.textContainer)
                    let laidOutHeight = ceil(view.layoutManager.usedRect(for: view.textContainer).height)
                    let textLayoutReady = laidOutHeight > 0
                        && abs(measurement.text.height - laidOutHeight) <= 2
                    let contentContainsText = measurement.contentSize.height >= laidOutHeight + 80
                    if textLayoutReady && contentContainsText {
                        if let priorContentSize,
                           abs(priorContentSize.height - measurement.contentSize.height) <= 1,
                           abs(priorContentSize.width - measurement.contentSize.width) <= 1 {
                            stableLayoutSamples += 1
                        } else {
                            stableLayoutSamples = 0
                        }
                        priorContentSize = measurement.contentSize
                    } else {
                        stableLayoutSamples = 0
                        priorContentSize = nil
                    }
                    guard stableLayoutSamples >= 2 else { continue }
                    let readyY = view.documentY(for: request.anchor)
                    guard scheduledRestoreID == request.id else { return }
                    lastRestoreID = request.id
                    scheduledRestoreID = nil
                    #if DEBUG
                    NSLog("L08_RESTORE_READY request=%@ anchor=%@:%d textH=%.1f layoutH=%.1f contentH=%.1f viewportH=%.1f oldY=%@ readyY=%@",
                          request.id.uuidString, request.anchor.verseLabel.rawValue,
                          request.anchor.utf16Offset, measurement.text.height, laidOutHeight,
                          measurement.contentSize.height, measurement.scroll.height,
                          y.map { String(format: "%.1f", $0) } ?? "none",
                          readyY.map { String(format: "%.1f", $0) } ?? "none")
                    #endif
                    parent.onAnchorRestoreY(request, readyY)
                    return
                }
                if scheduledRestoreID == request.id { scheduledRestoreID = nil }
            }
        }

        @objc func didTap(_ recognizer: UITapGestureRecognizer) {
            guard let view, recognizer.state == .ended else { return }
            if parent.onTapChapter() { return }
            let location = recognizer.location(in: view)
            guard let index = view.verseIndex(at: location) else {
                #if DEBUG
                NSLog("John verse tap rejected x=%.1f y=%.1f", location.x, location.y)
                #endif
                return
            }
            #if DEBUG
            NSLog("John verse tap accepted index=%ld x=%.1f y=%.1f", index, location.x, location.y)
            #endif
            parent.onTapVerse(index)
        }
    }

    private func makeAttributedText() -> (text: NSAttributedString, verseRanges: [Int: [NSRange]], verseBodyRanges: [Int: [NSRange]], headingRanges: [(String, NSRange)]) {
        let output = NSMutableAttributedString()
        var verses: [Int: [NSRange]] = [:]
        var verseBodyRanges: [Int: [NSRange]] = [:]
        var headings: [(String, NSRange)] = []
        var previousBodyVerseIndex: Int?
        var previousKind: String?
        var previousWasHeading = false
        let baseFontSize: CGFloat = switch textSize {
        case .small: 16
        case .medium: 18
        case .large: 21
        case .extraLarge: 24
        }
        let lineMultiplier: CGFloat = switch lineSpacing {
        case .compact: 1.45
        case .comfortable: 1.67
        case .relaxed: 1.9
        }
        let fontSize = baseFontSize * dynamicTypeScale
        let lineHeight = (baseFontSize * lineMultiplier).rounded() * dynamicTypeScale
        let paragraphGap = (lineHeight * 0.5).rounded()
        let bodyColor = UIColor(isDark ? JohnColors.dark.text : JohnColors.light.text)
        let tintColor = UIColor(isDark ? JohnColors.dark.tint : JohnColors.light.tint)
        let scriptureFont = UIFont(name: typeface == .serif ? "Georgia" : "SpaceGrotesk-Regular", size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize)
        let indent = (fontSize * 1.25).rounded()
        let lineKinds: Set<String> = ["q1", "q2", "q3", "li"]

        let currentBlocks = blocksForCurrentLayout()
        for (blockIndex, block) in currentBlocks.enumerated() {
            switch block {
            case let .heading(kind, text, _):
                if output.length > 0 && (output.string as NSString).substring(from: output.length - 1) != "\n" {
                    output.append(NSAttributedString(string: "\n"))
                }
                let start = output.length
                let isPsalmTitle = kind == "d"
                let isSpeaker = kind == "sp"
                let isMajor = kind == "ms"
                let headingBaseSize: CGFloat = isPsalmTitle ? (baseFontSize * 0.85).rounded() : (isSpeaker ? 14 : (isMajor ? 12 : 16))
                let headingSize = headingBaseSize * dynamicTypeScale
                let headingBaseLineHeight: CGFloat = isPsalmTitle
                    ? (lineHeight / dynamicTypeScale * 0.85).rounded()
                    : (isSpeaker ? 21 : (isMajor ? 18 : 24))
                let headingFont: UIFont
                if isPsalmTitle {
                    headingFont = typeface == .serif
                        ? (UIFont(name: "Georgia-Italic", size: headingSize) ?? UIFont.italicSystemFont(ofSize: headingSize))
                        : italicSpaceGrotesk(size: headingSize)
                } else if isSpeaker {
                    headingFont = italicSpaceGrotesk(size: headingSize)
                } else if isMajor {
                    headingFont = UIFont(name: "SpaceGrotesk-SemiBold", size: headingSize) ?? UIFont.systemFont(ofSize: headingSize, weight: .semibold)
                } else {
                    headingFont = UIFont(name: "SpaceGrotesk-SemiBold", size: headingSize) ?? UIFont.systemFont(ofSize: headingSize, weight: .semibold)
                }
                let paragraph = NSMutableParagraphStyle()
                paragraph.minimumLineHeight = headingBaseLineHeight * dynamicTypeScale
                paragraph.maximumLineHeight = paragraph.minimumLineHeight
                paragraph.paragraphSpacingBefore = output.length == 0 ? 0 : (isSpeaker ? 12 : (isPsalmTitle ? 0 : 24))
                paragraph.paragraphSpacing = isPsalmTitle || isMajor || kind == "s" ? 8 : 0
                let headingText = isMajor ? text.uppercased() : text
                var headingAttributes: [NSAttributedString.Key: Any] = [
                    .font: headingFont,
                    .foregroundColor: isPsalmTitle ? UIColor(isDark ? JohnColors.dark.textDim : JohnColors.light.textDim) : (isSpeaker || isMajor ? tintColor : bodyColor),
                    .paragraphStyle: paragraph,
                ]
                if isMajor { headingAttributes[.kern] = 1.5 }
                output.append(NSAttributedString(string: headingText, attributes: headingAttributes))
                headings.append((kind, NSRange(location: start, length: output.length - start)))
                output.append(NSAttributedString(string: "\n"))
                previousWasHeading = true
                previousKind = nil
                previousBodyVerseIndex = nil

            case let .text(kind, stanzaBreak, segments):
                if output.length > 0 && (output.string as NSString).substring(from: output.length - 1) != "\n" {
                    if let previousBodyVerseIndex, segments.first?.verseIndex == previousBodyVerseIndex {
                        let separator = NSRange(location: output.length, length: 1)
                        output.append(NSAttributedString(string: "\n", attributes: [
                            .verseIndex: NSNumber(value: previousBodyVerseIndex), .verseBody: true,
                        ]))
                        verseBodyRanges[previousBodyVerseIndex, default: []].append(separator)
                        verses[previousBodyVerseIndex, default: []].append(separator)
                    } else {
                        output.append(NSAttributedString(string: "\n"))
                    }
                }
                let followsLine = lineKinds.contains(kind) && (previousKind.map(lineKinds.contains) ?? false)
                let sourceGap: CGFloat = previousKind == nil || previousWasHeading || (followsLine && !stanzaBreak) ? 0 : paragraphGap
                let verseIndex = segments.first?.verseIndex
                let startsVerseRow = readerLayout == .verses && verseIndex != previousBodyVerseIndex
                let opensParagraph: Bool = {
                    guard readerLayout == .verses, layout.structured, let verseIndex,
                          verseIndex > 0, layout.verses.indices.contains(verseIndex) else { return false }
                    let verseLayout = layout.verses[verseIndex]
                    guard verseLayout.startsBlock, verseLayout.headings.isEmpty,
                          let firstLine = verseLayout.lines.first,
                          case let .text(firstKind, firstStanzaBreak, _) = firstLine else { return false }
                    return !lineKinds.contains(firstKind) || firstStanzaBreak
                }()
                let continuesVerseRow: Bool = {
                    guard readerLayout == .verses, let verseIndex,
                          currentBlocks.indices.contains(blockIndex + 1),
                          case let .text(_, _, nextSegments) = currentBlocks[blockIndex + 1] else { return false }
                    return nextSegments.first?.verseIndex == verseIndex
                }()
                let gap: CGFloat = readerLayout == .verses
                    ? (startsVerseRow
                        ? 4 + (opensParagraph ? 12 : 0)
                        : (stanzaBreak ? 12 : 0))
                    : sourceGap
                let paragraph = NSMutableParagraphStyle()
                paragraph.minimumLineHeight = lineHeight
                paragraph.maximumLineHeight = lineHeight
                paragraph.lineBreakMode = .byWordWrapping
                paragraph.paragraphSpacingBefore = gap
                paragraph.paragraphSpacing = readerLayout == .verses
                    ? (continuesVerseRow ? 0 : 4)
                    : 0
                let blockIndent: CGFloat = switch kind {
                case "q2", "li", "pi", "mi": indent
                case "q3": indent * 2
                default: 0
                }
                let rowInset: CGFloat = readerLayout == .verses ? 8 : 0
                paragraph.firstLineHeadIndent = blockIndent + rowInset
                paragraph.headIndent = blockIndent + rowInset
                paragraph.tailIndent = -rowInset
                if kind == "pc" { paragraph.alignment = .center }

                var previousSegmentVerseIndex: Int?
                for (segmentIndex, segment) in segments.enumerated() {
                    if segmentIndex > 0 {
                        if previousSegmentVerseIndex == segment.verseIndex {
                            let separator = NSRange(location: output.length, length: 1)
                            output.append(NSAttributedString(string: " ", attributes: [
                                .verseIndex: NSNumber(value: segment.verseIndex), .verseBody: true,
                                .paragraphStyle: paragraph,
                            ]))
                            verseBodyRanges[segment.verseIndex, default: []].append(separator)
                            verses[segment.verseIndex, default: []].append(separator)
                        } else {
                            output.append(NSAttributedString(string: " "))
                        }
                    }
                    let start = output.length
                    if let label = segment.label {
                        let labelSize = 14 * dynamicTypeScale
                        let labelFont = UIFont(name: "SpaceGrotesk-Medium", size: labelSize)
                            ?? UIFont.systemFont(ofSize: labelSize, weight: .medium)
                        output.append(NSAttributedString(string: label + "\u{00A0}", attributes: [
                            .font: labelFont,
                            .foregroundColor: tintColor,
                            .verseIndex: NSNumber(value: segment.verseIndex),
                            .paragraphStyle: paragraph,
                        ]))
                    }
                    let bodyStart = output.length
                    output.append(NSAttributedString(string: segment.text, attributes: [
                        .font: scriptureFont,
                        .foregroundColor: bodyColor,
                        .verseIndex: NSNumber(value: segment.verseIndex),
                        .verseBody: true,
                        .paragraphStyle: paragraph,
                    ]))
                    let bodyRange = NSRange(location: bodyStart, length: output.length - bodyStart)
                    verseBodyRanges[segment.verseIndex, default: []].append(bodyRange)
                    let range = NSRange(location: start, length: output.length - start)
                    verses[segment.verseIndex, default: []].append(range)
                    if readerLayout == .paragraphs, selectedRange?.contains(segment.verseIndex) == true {
                        output.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                        output.addAttribute(.underlineColor, value: tintColor, range: range)
                    }
                    if readerLayout == .paragraphs, let color = highlights[segment.verseIndex] {
                        output.addAttribute(.backgroundColor, value: highlightColor(color), range: range)
                    }
                    if readerLayout == .paragraphs, highlights[segment.verseIndex] == nil,
                       contextRange?.contains(segment.verseIndex) == true {
                        output.addAttribute(.backgroundColor, value: tintColor.withAlphaComponent(isDark ? 0.2 : 0.12), range: range)
                    }
                    previousSegmentVerseIndex = segment.verseIndex
                }
                output.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: paragraph]))
                previousKind = kind
                previousWasHeading = false
                previousBodyVerseIndex = segments.last?.verseIndex
            }
        }
        return (output, verses, verseBodyRanges, headings)
    }

    private func blocksForCurrentLayout() -> [ChapterLayoutBlock] {
        guard readerLayout == .verses else { return layout.blocks }
        var blocks: [ChapterLayoutBlock] = []
        for (verseIndex, verseLayout) in layout.verses.enumerated() {
            for (kind, text) in verseLayout.headings {
                blocks.append(.heading(kind: kind, text: text, verseIndex: verseIndex))
            }
            var hasVerseLabel = false
            for line in verseLayout.lines {
                switch line {
                case let .heading(kind, text):
                    blocks.append(.heading(kind: kind, text: text, verseIndex: verseIndex))
                case let .text(kind, stanzaBreak, text):
                    blocks.append(.text(kind: kind, stanzaBreak: stanzaBreak, segments: [
                        ChapterLayoutSegment(verseIndex: verseIndex,
                                             label: hasVerseLabel ? nil : chapter.verses[verseIndex].label,
                                             text: text)
                    ]))
                    hasVerseLabel = true
                }
            }
        }
        return blocks
    }

    private func highlightColor(_ color: HighlightColor) -> UIColor {
        let values: (CGFloat, CGFloat, CGFloat) = switch color {
        case .gold: (244, 216, 154)
        case .sage: (200, 214, 192)
        case .rose: (230, 197, 200)
        case .blue: (198, 213, 230)
        }
        return UIColor(red: values.0 / 255, green: values.1 / 255, blue: values.2 / 255, alpha: isDark ? 0.24 : 1)
    }

    private func italicSpaceGrotesk(size: CGFloat) -> UIFont {
        let base = UIFont(name: "SpaceGrotesk-Regular", size: size) ?? UIFont.systemFont(ofSize: size)
        let descriptor = base.fontDescriptor.withSymbolicTraits(.traitItalic) ?? base.fontDescriptor
        return UIFont(descriptor: descriptor, size: size)
    }
}

@MainActor final class ReaderTextKitView: UIView {
    var onTapVerse: ((Int) -> Void)?
    var chapter: BibleChapter?
    var verseRanges: [Int: [NSRange]] = [:] { didSet { setNeedsLayout() } }
    var verseBodyRanges: [Int: [NSRange]] = [:] { didSet { setNeedsLayout() } }
    var chapterRequestID: UUID? {
        didSet { if oldValue != chapterRequestID { lastContextVerseIndex = nil } }
    }
    var headingRanges: [(String, NSRange)] = [] { didSet { setNeedsLayout() } }
    var activeSelection: ClosedRange<Int>? { didSet { setNeedsLayout() } }
    /// Each update sets the same value again, so only a new value (or a new chapter request) starts a new context scroll.
    var contextVerseIndex: Int? {
        didSet {
            if oldValue != contextVerseIndex { lastContextVerseIndex = nil }
            setNeedsLayout()
        }
    }
    var onContextVerseY: ((CGFloat, UUID?) -> Bool)?
    private var lastContextVerseIndex: Int?
    var readerLayout: ReaderLayout = .paragraphs { didSet { setNeedsDisplay() } }
    var contextRange: ClosedRange<Int>? { didSet { setNeedsDisplay() } }
    var savedHighlights: [Int: UIColor] = [:] { didSet { setNeedsDisplay() } }
    /// Spoken name of each saved highlight, by verse index. VoiceOver reads it as the verse value.
    var highlightNames: [Int: String] = [:] { didSet { setNeedsLayout() } }
    var selectionTint: UIColor = .label { didSet { setNeedsDisplay() } }
    var verseLabels: [String] = [] { didSet { setNeedsLayout() } }
    var verseDescriptions: [String] = [] { didSet { setNeedsLayout() } }
    private var verseRowMinimumAdjustments: [Int: (top: CGFloat, bottom: CGFloat)] = [:]
    let textView: UITextView
    var textContainer: NSTextContainer { textView.textContainer }
    var layoutManager: NSLayoutManager { textView.layoutManager }
    var textStorage: NSTextStorage { textView.textStorage }
    var attributedText: NSAttributedString {
        get { textView.attributedText }
        set { textView.attributedText = newValue }
    }

    func resetVerseRowMinimumAdjustments() {
        guard !verseRowMinimumAdjustments.isEmpty else { return }
        textStorage.beginEditing()
        for (index, adjustment) in verseRowMinimumAdjustments {
            guard let ranges = verseBodyRanges[index], let first = ranges.first, let last = ranges.last else { continue }
            adjustParagraphSpacing(at: first.location, before: -adjustment.top, after: 0)
            adjustParagraphSpacing(at: last.location, before: 0, after: -adjustment.bottom)
        }
        textStorage.endEditing()
        verseRowMinimumAdjustments.removeAll()
    }

    func applyVerseRowMinimums() {
        resetVerseRowMinimumAdjustments()
        guard readerLayout == .verses else { return }
        layoutManager.ensureLayout(for: textContainer)
        var adjustments: [Int: (top: CGFloat, bottom: CGFloat)] = [:]
        textStorage.beginEditing()
        for index in verseRanges.keys.sorted() {
            guard let visibleRanges = verseRanges[index],
                  let bodyRanges = verseBodyRanges[index],
                  let first = bodyRanges.first, let last = bodyRanges.last else { continue }
            let union = visibleRanges.map(rect(for:)).reduce(CGRect.null) { $0.union($1) }
            guard !union.isNull, union.height.isFinite else { continue }
            let deficit = max(0, 44 - (union.height + 8))
            guard deficit > 0.5 else { continue }
            let top = deficit / 2
            let bottom = deficit - top
            adjustParagraphSpacing(at: first.location, before: top, after: 0)
            adjustParagraphSpacing(at: last.location, before: 0, after: bottom)
            adjustments[index] = (top, bottom)
        }
        textStorage.endEditing()
        verseRowMinimumAdjustments = adjustments
        layoutManager.ensureLayout(for: textContainer)
    }

    private func adjustParagraphSpacing(at characterIndex: Int, before: CGFloat, after: CGFloat) {
        guard characterIndex >= 0, characterIndex < textStorage.length else { return }
        let paragraphRange = (textStorage.string as NSString).paragraphRange(
            for: NSRange(location: characterIndex, length: 0))
        guard paragraphRange.length > 0,
              let existing = textStorage.attribute(.paragraphStyle, at: characterIndex, effectiveRange: nil) as? NSParagraphStyle,
              let paragraph = existing.mutableCopy() as? NSMutableParagraphStyle else { return }
        paragraph.paragraphSpacingBefore = max(0, paragraph.paragraphSpacingBefore + before)
        paragraph.paragraphSpacing = max(0, paragraph.paragraphSpacing + after)
        textStorage.addAttribute(.paragraphStyle, value: paragraph, range: paragraphRange)
    }

    override init(frame: CGRect) {
        let storage = NSTextStorage()
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: .zero)
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        textView = UITextView(frame: .zero, textContainer: container)
        super.init(frame: frame)
        isAccessibilityElement = false
        backgroundColor = .clear
        textView.isAccessibilityElement = false
        textView.accessibilityElementsHidden = true
        accessibilityCustomRotors = [
            makeRotor(systemType: .heading) { $0.accessibilityTraits.contains(.header) },
            makeRotor(name: "Highlights") { ($0 as? ReaderVerseAccessibilityElement)?.accessibilityValue != nil },
        ]
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.adjustsFontForContentSizeCategory = false
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        addSubview(textView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds
        layoutManager.ensureLayout(for: textContainer)
        if let contextVerseIndex, lastContextVerseIndex != contextVerseIndex,
           let range = verseRanges[contextVerseIndex]?.first {
            let frame = rect(for: range)
            if !frame.isNull, frame.height > 0,
               onContextVerseY?(frame.minY, chapterRequestID) == true {
                lastContextVerseIndex = contextVerseIndex
            }
        }
        buildAccessibilityElements()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard readerLayout == .verses else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }
        for index in verseRanges.keys.sorted() {
            guard let ranges = verseRanges[index] else { continue }
            let union = ranges.map(rect(for:)).reduce(CGRect.null) { $0.union($1) }
            guard !union.isNull, union.height > 0 else { continue }
            let height = max(44, union.height + 8)
            let row = CGRect(x: 8, y: union.midY - height / 2,
                             width: max(0, bounds.width - 16), height: height).integral
            let fill = savedHighlights[index] ?? (contextRange?.contains(index) == true
                ? selectionTint.withAlphaComponent(0.12) : nil)
            if let fill {
                fill.setFill()
                UIBezierPath(roundedRect: row, cornerRadius: 8).fill()
            }
            if activeSelection?.contains(index) == true {
                context.saveGState()
                selectionTint.setStroke()
                let outline = UIBezierPath(roundedRect: row.insetBy(dx: 0.75, dy: 0.75), cornerRadius: 8)
                outline.lineWidth = 1.5
                outline.stroke()
                context.restoreGState()
            }
        }
    }

    func verseIndex(at point: CGPoint) -> Int? {
        guard textStorage.length > 0 else { return nil }
        let local = CGPoint(x: point.x - textView.textContainerInset.left, y: point.y - textView.textContainerInset.top)
        let glyph = layoutManager.glyphIndex(for: local, in: textContainer)
        guard glyph < layoutManager.numberOfGlyphs else { return nil }
        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer)
        guard glyphRect.insetBy(dx: -1, dy: -1).contains(local) else { return nil }
        let character = layoutManager.characterIndexForGlyph(at: glyph)
        guard character < textStorage.length,
              let value = textStorage.attribute(.verseIndex, at: character, effectiveRange: nil) as? NSNumber else { return nil }
        return value.intValue
    }

    func visibleAnchor(atY requestedY: CGFloat) -> ReaderAnchor? {
        guard let chapter, textStorage.length > 0 else { return nil }
        layoutManager.ensureLayout(for: textContainer)
        let y = max(0, requestedY)
        var candidates: [(verseIndex: Int, range: NSRange, rect: CGRect)] = []
        for verseIndex in verseBodyRanges.keys.sorted() {
            let ranges = verseBodyRanges[verseIndex] ?? []
            for range in ranges where range.length > 0 {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                guard glyphRange.length > 0 else { continue }
                layoutManager.enumerateEnclosingRects(forGlyphRange: glyphRange,
                    withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: textContainer) { rect, _ in
                        let local = rect.offsetBy(dx: self.textView.textContainerInset.left, dy: self.textView.textContainerInset.top)
                        guard local.maxY >= y else { return }
                        candidates.append((verseIndex, range, local))
                    }
            }
        }
        let best = candidates.sorted {
            if abs($0.rect.minY - $1.rect.minY) > 0.5 { return $0.rect.minY < $1.rect.minY }
            if abs($0.rect.minX - $1.rect.minX) > 0.5 { return $0.rect.minX < $1.rect.minX }
            if $0.range.location != $1.range.location { return $0.range.location < $1.range.location }
            return $0.verseIndex < $1.verseIndex
        }.first
        guard let best, chapter.verses.indices.contains(best.verseIndex),
              let label = VerseLabel(rawValue: chapter.verses[best.verseIndex].label) else { return nil }
        let point = CGPoint(x: max(best.rect.minX + 1, 1),
                            y: min(max(y, best.rect.minY + 1), best.rect.maxY - 1))
        let glyph = layoutManager.glyphIndex(for: CGPoint(x: point.x - textView.textContainerInset.left,
                                                          y: point.y - textView.textContainerInset.top),
                                             in: textContainer)
        let character = min(max(layoutManager.characterIndexForGlyph(at: glyph), best.range.location),
                            NSMaxRange(best.range) - 1)
        let ordered = (verseBodyRanges[best.verseIndex] ?? []).sorted { $0.location < $1.location }
        var offset = 0
        for range in ordered {
            if character < range.location { break }
            offset += min(range.length, max(0, character - range.location))
            if NSLocationInRange(character, range) { break }
        }
        return try? ReaderAnchor(verseLabel: label, utf16Offset: offset)
    }

    func documentY(for anchor: ReaderAnchor) -> CGFloat? {
        guard let chapter,
              let verseIndex = chapter.verses.firstIndex(where: { $0.label == anchor.verseLabel.rawValue }),
              let ranges = verseBodyRanges[verseIndex], !ranges.isEmpty else { return nil }
        layoutManager.ensureLayout(for: textContainer)
        var remaining = anchor.utf16Offset
        let ordered = ranges.sorted { $0.location < $1.location }
        for (index, range) in ordered.enumerated() {
            if remaining < range.length || index == ordered.count - 1 {
                let character = range.location + min(remaining, max(0, range.length - 1))
                let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: character, length: 1), actualCharacterRange: nil)
                guard glyphRange.length > 0 else { return nil }
                let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphRange.location, length: 1), in: textContainer)
                return rect.minY + textView.textContainerInset.top
            }
            remaining -= range.length
        }
        return nil
    }

    private func makeRotor(name: String, include: @escaping (UIAccessibilityElement) -> Bool) -> UIAccessibilityCustomRotor {
        UIAccessibilityCustomRotor(name: name) { [weak self] predicate in
            self?.rotorResult(for: predicate, include: include)
        }
    }

    private func makeRotor(systemType: UIAccessibilityCustomRotor.SystemRotorType,
                           include: @escaping (UIAccessibilityElement) -> Bool) -> UIAccessibilityCustomRotor {
        UIAccessibilityCustomRotor(systemType: systemType) { [weak self] predicate in
            self?.rotorResult(for: predicate, include: include)
        }
    }

    /// Finds the next or previous element in reading order that the rotor includes.
    private func rotorResult(for predicate: UIAccessibilityCustomRotorSearchPredicate,
                             include: (UIAccessibilityElement) -> Bool) -> UIAccessibilityCustomRotorItemResult? {
        let elements = (accessibilityElements ?? []).compactMap { $0 as? UIAccessibilityElement }
        let current = predicate.currentItem.targetElement as? UIAccessibilityElement
        let currentIndex = current.flatMap { current in elements.firstIndex { $0 === current } }
        let forward = predicate.searchDirection == .next
        let candidates: [UIAccessibilityElement]
        if let currentIndex {
            candidates = forward ? Array(elements[(currentIndex + 1)...]) : Array(elements[..<currentIndex].reversed())
        } else {
            candidates = forward ? elements : elements.reversed()
        }
        guard let target = candidates.first(where: include) else { return nil }
        return UIAccessibilityCustomRotorItemResult(targetElement: target, targetRange: nil)
    }

    private func buildAccessibilityElements() {
        var ordered: [(Int, UIAccessibilityElement)] = []
        guard let chapter else { accessibilityElements = []; return }
        for (index, ranges) in verseRanges {
            let rects = ranges.map(rect(for:))
            let union = rects.reduce(CGRect.null) { $0.union($1) }
            guard !union.isNull, chapter.verses.indices.contains(index) else { continue }
            let element = ReaderVerseAccessibilityElement(accessibilityContainer: self)
            let verse = chapter.verses[index]
            element.accessibilityIdentifier = "reader-verse-\(verse.label)"
            element.accessibilityLabel = "Verse \(verse.label). \(verse.text)"
            element.accessibilityTraits = .button
            element.accessibilityValue = highlightNames[index]
            if activeSelection?.contains(index) == true { element.accessibilityTraits.insert(.selected) }
            element.accessibilityFrameInContainerSpace = union
            element.activate = { [weak self] in self?.onTapVerse?(index); return true }
            ordered.append((ranges.map(\.location).min() ?? 0, element))
        }
        for (kind, range) in headingRanges {
            let element = UIAccessibilityElement(accessibilityContainer: self)
            element.accessibilityIdentifier = "reader-heading-\(kind)"
            element.accessibilityLabel = (textStorage.string as NSString).substring(with: range)
            element.accessibilityTraits = .header
            element.accessibilityFrameInContainerSpace = rect(for: range)
            ordered.append((range.location, element))
        }
        accessibilityElements = ordered.sorted { $0.0 < $1.0 }.map(\.1)
    }

    private func rect(for range: NSRange) -> CGRect {
        guard range.length > 0, range.location < textStorage.length else { return .zero }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var union = CGRect.null
        layoutManager.enumerateEnclosingRects(forGlyphRange: glyphRange,
                                              withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                              in: textContainer) { rect, _ in union = union.union(rect) }
        return union.isNull ? .zero : union.offsetBy(dx: textView.textContainerInset.left, dy: textView.textContainerInset.top)
    }
}

private final class ReaderVerseAccessibilityElement: UIAccessibilityElement {
    var activate: (() -> Bool)?
    override func accessibilityActivate() -> Bool { activate?() ?? false }
}

private extension NSAttributedString.Key {
    static let verseIndex = NSAttributedString.Key("reader.verseIndex")
    static let verseBody = NSAttributedString.Key("reader.verseBody")
}
