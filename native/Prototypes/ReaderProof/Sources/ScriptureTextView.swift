import SwiftUI
import UIKit

enum ReaderProofTheme {
  static let background = Color(hex: 0xF6F2EA)
  static let card = Color(hex: 0xFFFCF6)
  static let border = Color(hex: 0xC6BAA9)
  static let text = Color(hex: 0x191015)
  static let tint = Color(hex: 0x745439)

  static func highlight(_ color: ReaderHighlight, dark: Bool) -> UIColor {
    let rgb: (CGFloat, CGFloat, CGFloat) = switch color {
    case .gold: (244, 216, 154)
    case .sage: (200, 214, 192)
    case .rose: (230, 197, 200)
    case .blue: (198, 213, 230)
    }
    return UIColor(
      red: rgb.0 / 255,
      green: rgb.1 / 255,
      blue: rgb.2 / 255,
      alpha: dark ? 0.24 : 1
    )
  }
}

enum ReaderHighlight: String, CaseIterable, Sendable {
  case gold, sage, rose, blue
}

struct ReaderProofStyle: Equatable, Sendable {
  var fontSize: CGFloat = 18
  var lineHeight: CGFloat = 30
  var dark = false
  var widthScale: CGFloat = 1
}

struct VerseTextView: UIViewRepresentable {
  let chapter: Chapter
  let bookName: String
  let layout: ChapterLayout
  let style: ReaderProofStyle
  let selection: ClosedRange<Int>?
  let savedHighlights: [Int: ReaderHighlight]
  let contextRequest: (verse: Int, nonce: Int)?
  let onTapVerse: (Int) -> Void

  func makeUIView(context: Context) -> ReaderUIKitTextView {
    let view = ReaderUIKitTextView()
    view.isAccessibilityElement = false
    view.onTapVerse = onTapVerse
    view.isScrollEnabled = false
    view.isEditable = false
    view.isSelectable = false
    view.backgroundColor = .clear
    view.textContainerInset = .zero
    view.textContainer.lineFragmentPadding = 0
    view.textContainer.widthTracksTextView = true
    view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    view.adjustsFontForContentSizeCategory = false
    view.smartQuotesType = .no
    view.smartDashesType = .no
    view.smartInsertDeleteType = .no
    view.delaysContentTouches = false
    view.accessibilityIdentifier = "reader-scripture-text"
    let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didTap(_:)))
    tap.cancelsTouchesInView = false
    view.addGestureRecognizer(tap)
    context.coordinator.view = view
    return view
  }

  func updateUIView(_ view: ReaderUIKitTextView, context: Context) {
    context.coordinator.parent = self
    view.onTapVerse = onTapVerse
    view.verseLabels = chapter.verses.map(\.n)
    view.verseDescriptions = chapter.verses.map(\.t)
    let requestChanged = contextRequest?.nonce != context.coordinator.lastContextNonce
    let anchorIndex = selection?.lowerBound ?? contextRequest?.verse
    let oldAnchorScreenY = context.coordinator.lastStyle != nil && context.coordinator.lastStyle != style
      ? anchorIndex.flatMap(view.screenY(forVerse:))
      : nil
    let result = makeAttributedText()
    view.verseRanges = result.verseRanges
    view.headingRanges = result.headingRanges
    view.activeSelection = selection
    view.attributedText = result.value
    view.invalidateIntrinsicContentSize()
    view.setNeedsLayout()
    view.layoutIfNeeded()
    context.coordinator.lastStyle = style
    if let request = contextRequest { context.coordinator.lastContextNonce = request.nonce }
    if requestChanged, let request = contextRequest {
      DispatchQueue.main.async { view.scrollToVerse(request.verse) }
    } else if let oldAnchorScreenY, let anchorIndex {
      DispatchQueue.main.async { view.restoreVerse(anchorIndex, screenY: oldAnchorScreenY) }
    }
  }

  func sizeThatFits(_ proposal: ProposedViewSize, uiView: ReaderUIKitTextView, context: Context) -> CGSize? {
    guard let width = proposal.width, width > 0 else { return nil }
    let measured = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    return CGSize(width: width, height: measured.height)
  }

  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

  final class Coordinator: NSObject {
    var parent: VerseTextView
    weak var view: ReaderUIKitTextView?
    var lastStyle: ReaderProofStyle?
    var lastContextNonce: Int?

    init(parent: VerseTextView) { self.parent = parent }

    @objc func didTap(_ recognizer: UITapGestureRecognizer) {
      guard let view, recognizer.state == .ended else { return }
      let point = recognizer.location(in: view)
      guard let index = view.verseIndex(at: point) else { return }
      parent.onTapVerse(index)
    }
  }

  private func makeAttributedText() -> (value: NSAttributedString, verseRanges: [Int: NSRange], headingRanges: [(String, NSRange)]) {
    let full = NSMutableAttributedString(string: "")
    var verseRanges: [Int: NSRange] = [:]
    var headingRanges: [(String, NSRange)] = []
    var previousKind: String?
    var previousWasHeading = false
    let scriptureFont = UIFont(name: "Georgia", size: style.fontSize) ?? .systemFont(ofSize: style.fontSize)
    let bodyColor = style.dark ? UIColor(white: 0.93, alpha: 1) : UIColor(red: 25.0 / 255.0, green: 16.0 / 255.0, blue: 21.0 / 255.0, alpha: 1)
    let verseColor = style.dark ? UIColor(red: 0.77, green: 0.68, blue: 0.56, alpha: 1) : UIColor(red: 116.0 / 255.0, green: 84.0 / 255.0, blue: 57.0 / 255.0, alpha: 1)
    let paragraphGap = max(1, style.lineHeight * 0.5)
    let indent = (style.fontSize * 1.25).rounded()

    for (blockIndex, block) in layout.blocks.enumerated() {
      switch block {
      case let .heading(kind, text, _):
        if full.length > 0, !previousWasHeading { full.append(NSAttributedString(string: "\n")) }
        let headingStart = full.length
        let isPsalmTitle = kind == "d"
        let headingFont: UIFont
        if isPsalmTitle {
          headingFont = UIFont(name: "Georgia-Italic", size: (style.fontSize * 0.85).rounded()) ?? .italicSystemFont(ofSize: (style.fontSize * 0.85).rounded())
        } else if kind == "sp" {
          headingFont = .systemFont(ofSize: 12, weight: .medium)
        } else {
          headingFont = .systemFont(ofSize: style.fontSize, weight: .semibold)
        }
        let content = NSMutableAttributedString(string: text, attributes: [
          .font: headingFont,
          .foregroundColor: isPsalmTitle ? verseColor : bodyColor,
          .headingKind: kind,
        ])
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = self.style.lineHeight * (isPsalmTitle ? 0.85 : 1)
        style.maximumLineHeight = self.style.lineHeight * (isPsalmTitle ? 0.85 : 1)
        style.paragraphSpacing = paragraphGap * 0.35
        content.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: content.length))
        full.append(content)
        headingRanges.append((kind, NSRange(location: headingStart, length: content.length)))
        full.append(NSAttributedString(string: "\n"))
        previousWasHeading = true
        if !kind.isEmpty { previousKind = nil }

      case let .text(kind, stanzaBreak, segments):
        if blockIndex > 0 && !previousWasHeading {
          let lineKinds: Set<String> = ["q1", "q2", "q3", "li"]
          let followsLine = lineKinds.contains(kind) && (previousKind.map(lineKinds.contains) ?? false)
          let gap = previousWasHeading ? 0 : (followsLine && !stanzaBreak ? 0 : paragraphGap)
          full.append(NSAttributedString(string: gap > 0 ? "\n\n" : "\n"))
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = style.lineHeight
        paragraph.maximumLineHeight = style.lineHeight
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.paragraphSpacing = 0
        let blockIndent: CGFloat = switch kind {
        case "q2", "li", "pi", "mi": indent
        case "q3": indent * 2
        default: 0
        }
        paragraph.firstLineHeadIndent = blockIndent
        paragraph.headIndent = blockIndent
        if kind == "pc" { paragraph.alignment = .center }

        for (segmentIndex, segment) in segments.enumerated() {
          if segmentIndex > 0 { full.append(NSAttributedString(string: " ")) }
          let segmentStart = full.length
          if let label = segment.label {
            let labelText = label + " "
            let labelRange = NSRange(location: full.length, length: (labelText as NSString).length)
            full.append(NSAttributedString(string: labelText, attributes: [
              .font: UIFont.systemFont(ofSize: (style.fontSize * 0.67).rounded(), weight: .medium),
              .foregroundColor: verseColor,
              .verseIndex: NSNumber(value: segment.verseIndex),
              .paragraphStyle: paragraph,
            ]))
            _ = labelRange
          }
          full.append(NSAttributedString(string: segment.text, attributes: [
            .font: scriptureFont,
            .foregroundColor: bodyColor,
            .verseIndex: NSNumber(value: segment.verseIndex),
            .paragraphStyle: paragraph,
          ]))
          let segmentRange = NSRange(location: segmentStart, length: full.length - segmentStart)
          if let existing = verseRanges[segment.verseIndex] {
            verseRanges[segment.verseIndex] = NSRange(location: existing.location, length: NSMaxRange(segmentRange) - existing.location)
          } else {
            verseRanges[segment.verseIndex] = segmentRange
          }
          if selection?.contains(segment.verseIndex) == true {
            full.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: segmentRange)
            full.addAttribute(.underlineColor, value: verseColor, range: segmentRange)
          }
          if let color = savedHighlights[segment.verseIndex] {
            full.addAttribute(.backgroundColor, value: ReaderProofTheme.highlight(color, dark: style.dark), range: segmentRange)
          }
        }
        previousKind = kind
        previousWasHeading = false
      }
    }
    return (full, verseRanges, headingRanges)
  }
}

private extension NSAttributedString.Key {
  static let verseIndex = NSAttributedString.Key("reader.verseIndex")
  static let headingKind = NSAttributedString.Key("reader.headingKind")
}

final class ReaderUIKitTextView: UITextView {
  var onTapVerse: ((Int) -> Void)?
  var verseRanges: [Int: NSRange] = [:] { didSet { setNeedsLayout() } }
  var headingRanges: [(String, NSRange)] = [] { didSet { setNeedsLayout() } }
  var activeSelection: ClosedRange<Int>? { didSet { setNeedsLayout() } }
  var verseLabels: [String] = [] { didSet { setNeedsLayout() } }
  var verseDescriptions: [String] = [] { didSet { setNeedsLayout() } }
  private var readerElements: [UIAccessibilityElement] = []

  override func layoutSubviews() {
    super.layoutSubviews()
    buildAccessibilityElements()
  }

  func verseIndex(at point: CGPoint) -> Int? {
    guard textStorage.length > 0 else { return nil }
    let containerPoint = CGPoint(x: point.x - textContainerInset.left, y: point.y - textContainerInset.top)
    let glyph = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
    guard glyph < layoutManager.numberOfGlyphs else { return nil }
    let character = layoutManager.characterIndexForGlyph(at: glyph)
    guard character < textStorage.length,
          let value = textStorage.attribute(.verseIndex, at: character, effectiveRange: nil) as? NSNumber else { return nil }
    return value.intValue
  }

  private func buildAccessibilityElements() {
    var elements: [UIAccessibilityElement] = []
    var ordered: [(location: Int, element: UIAccessibilityElement)] = []
    for (index, range) in verseRanges.sorted(by: { $0.value.location < $1.value.location }) where NSMaxRange(range) <= textStorage.length {
      let verse = (textStorage.string as NSString).substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
      let element = ReaderVerseAccessibilityElement(accessibilityContainer: self)
      let label = verseLabels.indices.contains(index) ? verseLabels[index] : String(index + 1)
      let description = verseDescriptions.indices.contains(index) ? verseDescriptions[index] : verse
      element.accessibilityIdentifier = "reader-verse-\(label)"
      element.accessibilityLabel = "Verse \(label). \(description)"
      element.accessibilityTraits = .button
      if let activeSelection, activeSelection.contains(index) { element.accessibilityTraits.insert(.selected) }
      element.accessibilityFrameInContainerSpace = rect(for: range)
      element.activate = { [weak self] in self?.onTapVerse?(index); return true }
      ordered.append((range.location, element))
    }
    for (kind, range) in headingRanges {
      let element = UIAccessibilityElement(accessibilityContainer: self)
      element.accessibilityIdentifier = "reader-heading-\(kind)"
      element.accessibilityLabel = (textStorage.string as NSString).substring(with: range)
      element.accessibilityTraits = .header
      element.accessibilityFrameInContainerSpace = rect(for: range)
      ordered.append((range.location, element))
    }
    elements = ordered.sorted { $0.location < $1.location }.map(\.element)
    readerElements = elements
    accessibilityElements = elements
  }

  private func rect(for characterRange: NSRange) -> CGRect {
    guard characterRange.length > 0, characterRange.location < textStorage.length else { return .zero }
    let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
    var union = CGRect.null
    layoutManager.enumerateEnclosingRects(
      forGlyphRange: glyphRange,
      withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
      in: textContainer
    ) { rect, _ in union = union.union(rect) }
    guard !union.isNull else { return .zero }
    return union.offsetBy(dx: textContainerInset.left, dy: textContainerInset.top)
  }

  func screenY(forVerse index: Int) -> CGFloat? {
    guard let range = verseRanges[index], let scroll = enclosingScrollView else { return nil }
    return rect(for: range).minY - scroll.contentOffset.y
  }

  func restoreVerse(_ index: Int, screenY: CGFloat) {
    guard let range = verseRanges[index], let scroll = enclosingScrollView else { return }
    var offset = scroll.contentOffset
    offset.y = max(-scroll.adjustedContentInset.top, rect(for: range).minY - screenY)
    scroll.setContentOffset(offset, animated: false)
  }

  func scrollToVerse(_ index: Int) {
    guard let range = verseRanges[index], let scroll = enclosingScrollView else { return }
    var offset = scroll.contentOffset
    offset.y = max(-scroll.adjustedContentInset.top, rect(for: range).minY - 24)
    scroll.setContentOffset(offset, animated: true)
  }

  private var enclosingScrollView: UIScrollView? {
    var parent = superview
    while let current = parent {
      if let scroll = current as? UIScrollView { return scroll }
      parent = current.superview
    }
    return nil
  }
}

private final class ReaderVerseAccessibilityElement: UIAccessibilityElement {
  var activate: (() -> Bool)?
  override func accessibilityActivate() -> Bool { activate?() ?? false }
}

private extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xff) / 255,
      green: Double((hex >> 8) & 0xff) / 255,
      blue: Double(hex & 0xff) / 255,
      opacity: 1
    )
  }
}
