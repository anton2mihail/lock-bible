import SwiftUI
import UIKit

struct PageSlice: Identifiable, Sendable {
  let index: Int
  let startUTF16: Int
  let endUTF16: Int
  let text: String
  var id: Int { index }
}

enum WorksPaginationEngine {
  static func pages(paragraphs: [String], width: CGFloat, height: CGFloat, fontSize: CGFloat, lineHeight: CGFloat) -> [PageSlice] {
    guard width > 0, height > 0 else { return [] }
    let source = paragraphs.joined(separator: "\n")
    guard !source.isEmpty else { return [] }
    let font = UIFont(name: "Georgia", size: fontSize) ?? .systemFont(ofSize: fontSize)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.minimumLineHeight = lineHeight
    paragraphStyle.maximumLineHeight = lineHeight
    paragraphStyle.lineBreakMode = .byWordWrapping
    paragraphStyle.paragraphSpacing = lineHeight * 0.5
    let attributed = NSAttributedString(string: source, attributes: [.font: font, .paragraphStyle: paragraphStyle])
    let storage = NSTextStorage(attributedString: attributed)
    let manager = NSLayoutManager()
    let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
    container.lineFragmentPadding = 0
    container.maximumNumberOfLines = 0
    container.lineBreakMode = .byWordWrapping
    manager.addTextContainer(container)
    storage.addLayoutManager(manager)
    let allGlyphs = NSRange(location: 0, length: manager.numberOfGlyphs)
    manager.ensureLayout(forGlyphRange: allGlyphs)

    var glyphBounds: [(start: Int, end: Int, minY: CGFloat, maxY: CGFloat)] = []
    manager.enumerateLineFragments(forGlyphRange: allGlyphs) { _, usedRect, _, glyphRange, _ in
      glyphBounds.append((glyphRange.location, NSMaxRange(glyphRange), usedRect.minY, usedRect.maxY))
    }
    guard !glyphBounds.isEmpty else { return [] }

    var ranges: [NSRange] = []
    var pageStartGlyph = 0
    var pageTop = glyphBounds[0].minY
    for line in glyphBounds {
      if line.maxY > pageTop + height, line.start > pageStartGlyph {
        ranges.append(NSRange(location: pageStartGlyph, length: line.start - pageStartGlyph))
        pageStartGlyph = line.start
        pageTop = line.minY
      }
    }
    let glyphCount = manager.numberOfGlyphs
    if glyphCount > pageStartGlyph {
      ranges.append(NSRange(location: pageStartGlyph, length: glyphCount - pageStartGlyph))
    }

    return ranges.enumerated().compactMap { page, glyphRange in
      let characters = manager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
      guard characters.length > 0 else { return nil }
      let text = (source as NSString).substring(with: characters)
      return PageSlice(
        index: page,
        startUTF16: characters.location,
        endUTF16: NSMaxRange(characters),
        text: text
      )
    }
  }
}

struct WorksPaginationView: View {
  @State private var section: WorksSection?
  @State private var errorMessage = "Loading one real Works section…"
  @State private var pages: [PageSlice] = []
  @State private var pageIndex = 0
  @State private var fontSize: CGFloat = 17
  @State private var lineHeight: CGFloat = 29
  @State private var widthScale: CGFloat = 1
  @State private var layoutMilliseconds = 0.0
  @State private var pageTextIsContinuous = true
  @State private var anchorUTF16 = 0

  var body: some View {
    VStack(spacing: 8) {
      controls
      if let section {
        Text(section.title)
          .font(.system(size: 14, weight: .semibold))
          .lineLimit(2)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 16)
        Text("\(section.sectionTitle) · section \(section.sectionIndex) · \(section.paragraphs.count) paragraphs · \(section.paragraphs.joined(separator: " ").split(whereSeparator: \.isWhitespace).count) words")
          .font(.system(size: 11))
          .multilineTextAlignment(.center)
        GeometryReader { geometry in
          let width = max(180, (geometry.size.width - 28) * widthScale)
          let height = max(200, geometry.size.height - 62)
          VStack(spacing: 4) {
            if pages.indices.contains(pageIndex) {
              StaticProseTextView(text: pages[pageIndex].text, fontSize: fontSize, lineHeight: lineHeight)
                .frame(width: width, height: height, alignment: .topLeading)
                .padding(10)
                .background(ReaderProofTheme.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(ReaderProofTheme.border, lineWidth: 1))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("works-page-text")
              HStack {
                Button("Previous") { turnPage(-1) }
                  .disabled(pageIndex == 0)
                  .accessibilityIdentifier("works-page-previous")
                Spacer()
                Text("Page \(pageIndex + 1) of \(pages.count)")
                  .font(.system(size: 12, weight: .medium))
                  .accessibilityIdentifier("works-page-number")
                Spacer()
                Button("Next") { turnPage(1) }
                  .disabled(pageIndex >= pages.count - 1)
                  .accessibilityIdentifier("works-page-next")
              }
              .buttonStyle(.bordered)
              .padding(.horizontal, 12)
            } else {
              Text(errorMessage).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
          }
          .onAppear { rebuild(width: width, height: height) }
          .onChange(of: geometry.size) { _, _ in rebuild(width: width, height: height) }
          .onChange(of: fontSize) { _, _ in rebuild(width: width, height: height) }
          .onChange(of: widthScale) { _, _ in rebuild(width: width, height: height) }
        }
        .padding(.horizontal, 6)
        Text("Layout \(String(format: "%.2f", layoutMilliseconds)) ms · page continuity \(pageTextIsContinuous ? "passed" : "failed") · UTF-16 anchor \(anchorUTF16)")
          .font(.system(size: 10, design: .monospaced))
          .accessibilityIdentifier("works-layout-diagnostic")
      } else {
        ProgressView(errorMessage).frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .padding(.top, 10)
    .task {
      do { section = try SampleLoader.worksSection() }
      catch { errorMessage = "Could not load Works section: \(error.localizedDescription)" }
    }
  }

  private var controls: some View {
    VStack(spacing: 4) {
      HStack(spacing: 10) {
        Button("Text −") { fontSize = max(15, fontSize - 1); lineHeight = (fontSize * 1.67).rounded() }
          .accessibilityIdentifier("works-text-smaller")
        Text("\(Int(fontSize)) pt · Georgia")
          .font(.system(size: 11, weight: .medium))
        Button("Text +") { fontSize = min(22, fontSize + 1); lineHeight = (fontSize * 1.67).rounded() }
          .accessibilityIdentifier("works-text-larger")
        Slider(value: $widthScale, in: 0.68...1, step: 0.04)
          .frame(maxWidth: 130)
          .accessibilityLabel("Works page width")
      }
      Text("One source Works section. The page splitter uses TextKit line ranges and may end inside a paragraph.")
        .font(.system(size: 10))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
    }
    .buttonStyle(.bordered)
    .tint(ReaderProofTheme.tint)
  }

  private func rebuild(width: CGFloat, height: CGFloat) {
    guard let section else { return }
    let started = CFAbsoluteTimeGetCurrent()
    let oldAnchor = pages.indices.contains(pageIndex) ? pages[pageIndex].startUTF16 : anchorUTF16
    let newPages = WorksPaginationEngine.pages(
      paragraphs: section.paragraphs,
      width: width,
      height: height,
      fontSize: fontSize,
      lineHeight: lineHeight
    )
    let source = section.paragraphs.joined(separator: "\n")
    pageTextIsContinuous = newPages.map(\.text).joined() == source
    pages = newPages
    pageIndex = newPages.firstIndex(where: { oldAnchor >= $0.startUTF16 && oldAnchor < $0.endUTF16 }) ?? 0
    anchorUTF16 = newPages.indices.contains(pageIndex) ? newPages[pageIndex].startUTF16 : 0
    layoutMilliseconds = (CFAbsoluteTimeGetCurrent() - started) * 1000
  }

  private func turnPage(_ delta: Int) {
    let next = min(max(pageIndex + delta, 0), max(pages.count - 1, 0))
    pageIndex = next
    if pages.indices.contains(next) { anchorUTF16 = pages[next].startUTF16 }
  }
}

private struct StaticProseTextView: UIViewRepresentable {
  let text: String
  let fontSize: CGFloat
  let lineHeight: CGFloat

  func makeUIView(context: Context) -> UITextView {
    let view = UITextView()
    view.isEditable = false
    view.isSelectable = false
    view.isScrollEnabled = false
    view.backgroundColor = .clear
    view.textContainerInset = .zero
    view.textContainer.lineFragmentPadding = 0
    view.textContainer.widthTracksTextView = true
    view.textContainer.maximumNumberOfLines = 0
    view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    view.clipsToBounds = true
    view.accessibilityIdentifier = "works-page-text"
    return view
  }

  func updateUIView(_ view: UITextView, context: Context) {
    let style = NSMutableParagraphStyle()
    style.minimumLineHeight = lineHeight
    style.maximumLineHeight = lineHeight
    style.lineBreakMode = .byWordWrapping
    style.paragraphSpacing = lineHeight * 0.5
    let font = UIFont(name: "Georgia", size: fontSize) ?? .systemFont(ofSize: fontSize)
    view.attributedText = NSAttributedString(string: text, attributes: [
      .font: font,
      .foregroundColor: UIColor(red: 25.0 / 255.0, green: 16.0 / 255.0, blue: 21.0 / 255.0, alpha: 1),
      .paragraphStyle: style,
    ])
  }

  func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
    guard let width = proposal.width, let height = proposal.height else { return nil }
    _ = uiView.sizeThatFits(CGSize(width: width, height: height))
    return CGSize(width: width, height: height)
  }
}
