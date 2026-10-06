import SwiftUI
import UIKit
import JohnCore

struct ScriptureTextView: UIViewRepresentable {
    let chapter: BibleChapter
    let layout: ChapterLayout
    let textSize: ReaderTextSize
    let lineSpacing: ReaderLineSpacing
    let typeface: ReaderTypeface
    let selectedRange: ClosedRange<Int>?
    let contextRange: ClosedRange<Int>?
    let highlights: [Int: HighlightColor]
    let isDark: Bool
    let onTapVerse: (Int) -> Void

    func makeUIView(context: Context) -> ReaderTextKitView {
        let view = ReaderTextKitView()
        view.onTapVerse = onTapVerse
        view.chapter = chapter
        view.verseLabels = chapter.verses.map(\.label)
        view.verseDescriptions = chapter.verses.map(\.text)
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
        view.onTapVerse = onTapVerse
        view.chapter = chapter
        view.verseLabels = chapter.verses.map(\.label)
        view.verseDescriptions = chapter.verses.map(\.text)
        let result = makeAttributedText()
        view.verseRanges = result.verseRanges
        view.headingRanges = result.headingRanges
        view.activeSelection = selectedRange
        view.attributedText = result.text
        view.invalidateIntrinsicContentSize()
        view.setNeedsLayout()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ReaderTextKitView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        uiView.textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        uiView.layoutManager.ensureLayout(for: uiView.textContainer)
        let height = uiView.layoutManager.usedRect(for: uiView.textContainer).height
        return CGSize(width: width, height: ceil(height))
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor final class Coordinator: NSObject {
        var parent: ScriptureTextView
        weak var view: ReaderTextKitView?
        init(parent: ScriptureTextView) { self.parent = parent }

        @objc func didTap(_ recognizer: UITapGestureRecognizer) {
            guard let view, recognizer.state == .ended,
                  let index = view.verseIndex(at: recognizer.location(in: view)) else { return }
            parent.onTapVerse(index)
        }
    }

    private func makeAttributedText() -> (text: NSAttributedString, verseRanges: [Int: [NSRange]], headingRanges: [(String, NSRange)]) {
        let output = NSMutableAttributedString()
        var verses: [Int: [NSRange]] = [:]
        var headings: [(String, NSRange)] = []
        var previousKind: String?
        var previousWasHeading = false
        let fontSize: CGFloat = switch textSize {
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
        let lineHeight = (fontSize * lineMultiplier).rounded()
        let paragraphGap = (lineHeight * 0.5).rounded()
        let bodyColor = UIColor(isDark ? JohnColors.dark.text : JohnColors.light.text)
        let tintColor = UIColor(isDark ? JohnColors.dark.tint : JohnColors.light.tint)
        let scriptureFont = UIFont(name: typeface == .serif ? "Georgia" : "SpaceGrotesk-Regular", size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize)
        let indent = (fontSize * 1.25).rounded()
        let lineKinds: Set<String> = ["q1", "q2", "q3", "li"]

        for block in layout.blocks {
            switch block {
            case let .heading(kind, text, _):
                if output.length > 0 && (output.string as NSString).substring(from: output.length - 1) != "\n" {
                    output.append(NSAttributedString(string: "\n"))
                }
                let start = output.length
                let isPsalmTitle = kind == "d"
                let isSpeaker = kind == "sp"
                let isMajor = kind == "ms"
                let headingSize: CGFloat = isPsalmTitle ? (fontSize * 0.85).rounded() : (isSpeaker ? 14 : (isMajor ? 12 : fontSize))
                let headingFont: UIFont
                if isPsalmTitle {
                    headingFont = UIFont(name: typeface == .serif ? "Georgia-Italic" : "SpaceGrotesk-Italic", size: headingSize)
                        ?? UIFont.italicSystemFont(ofSize: headingSize)
                } else if isSpeaker {
                    headingFont = UIFont(name: "SpaceGrotesk-Italic", size: headingSize) ?? UIFont.italicSystemFont(ofSize: headingSize)
                } else if isMajor {
                    headingFont = UIFont(name: "SpaceGrotesk-SemiBold", size: headingSize) ?? UIFont.systemFont(ofSize: headingSize, weight: .semibold)
                } else {
                    headingFont = UIFont(name: "SpaceGrotesk-SemiBold", size: headingSize) ?? UIFont.systemFont(ofSize: headingSize, weight: .semibold)
                }
                let paragraph = NSMutableParagraphStyle()
                paragraph.minimumLineHeight = isPsalmTitle ? lineHeight * 0.85 : lineHeight
                paragraph.maximumLineHeight = paragraph.minimumLineHeight
                paragraph.paragraphSpacingBefore = output.length == 0 ? 0 : (isSpeaker ? 8 : (isPsalmTitle ? 0 : 18))
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

            case let .text(kind, stanzaBreak, segments):
                if output.length > 0 && (output.string as NSString).substring(from: output.length - 1) != "\n" {
                    output.append(NSAttributedString(string: "\n"))
                }
                let followsLine = lineKinds.contains(kind) && (previousKind.map(lineKinds.contains) ?? false)
                let gap: CGFloat = previousKind == nil || previousWasHeading || (followsLine && !stanzaBreak) ? 0 : paragraphGap
                let paragraph = NSMutableParagraphStyle()
                paragraph.minimumLineHeight = lineHeight
                paragraph.maximumLineHeight = lineHeight
                paragraph.lineBreakMode = .byWordWrapping
                paragraph.paragraphSpacingBefore = gap
                let blockIndent: CGFloat = switch kind {
                case "q2", "li", "pi", "mi": indent
                case "q3": indent * 2
                default: 0
                }
                paragraph.firstLineHeadIndent = blockIndent
                paragraph.headIndent = blockIndent
                if kind == "pc" { paragraph.alignment = .center }

                for (segmentIndex, segment) in segments.enumerated() {
                    if segmentIndex > 0 { output.append(NSAttributedString(string: " ")) }
                    let start = output.length
                    if let label = segment.label {
                        let labelFont = UIFont(name: "SpaceGrotesk-Medium", size: 14)
                            ?? UIFont.systemFont(ofSize: 14, weight: .medium)
                        output.append(NSAttributedString(string: label + "\u{00A0}", attributes: [
                            .font: labelFont,
                            .foregroundColor: tintColor,
                            .verseIndex: NSNumber(value: segment.verseIndex),
                            .paragraphStyle: paragraph,
                        ]))
                    }
                    output.append(NSAttributedString(string: segment.text, attributes: [
                        .font: scriptureFont,
                        .foregroundColor: bodyColor,
                        .verseIndex: NSNumber(value: segment.verseIndex),
                        .paragraphStyle: paragraph,
                    ]))
                    let range = NSRange(location: start, length: output.length - start)
                    verses[segment.verseIndex, default: []].append(range)
                    if selectedRange?.contains(segment.verseIndex) == true {
                        output.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                        output.addAttribute(.underlineColor, value: tintColor, range: range)
                    }
                    if let color = highlights[segment.verseIndex] {
                        output.addAttribute(.backgroundColor, value: highlightColor(color), range: range)
                    }
                    if highlights[segment.verseIndex] == nil,
                       contextRange?.contains(segment.verseIndex) == true {
                        output.addAttribute(.backgroundColor, value: tintColor.withAlphaComponent(isDark ? 0.2 : 0.12), range: range)
                    }
                }
                output.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: paragraph]))
                previousKind = kind
                previousWasHeading = false
            }
        }
        return (output, verses, headings)
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
}

@MainActor final class ReaderTextKitView: UIView {
    var onTapVerse: ((Int) -> Void)?
    var chapter: BibleChapter?
    var verseRanges: [Int: [NSRange]] = [:] { didSet { setNeedsLayout() } }
    var headingRanges: [(String, NSRange)] = [] { didSet { setNeedsLayout() } }
    var activeSelection: ClosedRange<Int>? { didSet { setNeedsLayout() } }
    var verseLabels: [String] = [] { didSet { setNeedsLayout() } }
    var verseDescriptions: [String] = [] { didSet { setNeedsLayout() } }
    let textView: UITextView
    var textContainer: NSTextContainer { textView.textContainer }
    var layoutManager: NSLayoutManager { textView.layoutManager }
    var textStorage: NSTextStorage { textView.textStorage }
    var attributedText: NSAttributedString {
        get { textView.attributedText }
        set { textView.attributedText = newValue }
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
        buildAccessibilityElements()
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
}
