import SwiftUI

private enum ProofArea: String, CaseIterable, Identifiable {
  case reader = "Reader"
  case works = "Works"
  case shell = "Shell"
  var id: String { rawValue }
}

private enum ScriptureSample: String, CaseIterable, Identifiable {
  case john = "WEB John 1"
  case psalm = "Psalm 23"
  case song = "Song 1"
  case vulgate = "Vulgate John 1"
  case douay = "Douay John 1"
  case unicode = "UTF-16 fixture"

  var id: String { rawValue }
  var resource: String {
    switch self {
    case .john: "john-web"
    case .psalm: "psalm-23-web"
    case .song: "song-1-web"
    case .vulgate: "john-vulgate"
    case .douay: "john-douay"
    case .unicode: ""
    }
  }
}

struct ContentView: View {
  @State private var area: ProofArea = .reader
  @State private var sample: ScriptureSample = .john
  @State private var sourceChapter: SourceChapter?
  @State private var loadMessage = "Loading real source chapters…"
  @State private var verseState = VerseTapState()
  @State private var tapTrace = ""
  @State private var savedHighlights: [Int: ReaderHighlight] = [0: .gold, 1: .sage, 2: .rose, 3: .blue]
  @State private var fontSize: CGFloat = 18
  @State private var dark = false
  @State private var widthScale: CGFloat = 1
  @State private var verseByVerse = false
  @State private var contextRequest: (verse: Int, nonce: Int)?

  private var chapterLayout: ChapterLayout? {
    sourceChapter.map { ChapterLayout.build($0.chapter) }
  }

  private var lineHeight: CGFloat { (fontSize * 1.67).rounded() }

  var body: some View {
    VStack(spacing: 0) {
      Picker("Proof area", selection: $area) {
        ForEach(ProofArea.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented)
      .padding(.horizontal, 14)
      .padding(.top, 8)
      .accessibilityIdentifier("proof-area-picker")

      Group {
        switch area {
        case .reader: readerArea
        case .works: WorksPaginationView()
        case .shell: ShellComparisonView()
        }
      }
    }
    .background(dark ? Color(red: 0.09, green: 0.08, blue: 0.09) : ReaderProofTheme.background)
    .foregroundStyle(dark ? Color.white : ReaderProofTheme.text)
    .preferredColorScheme(dark ? .dark : .light)
    .task { loadSample(sample) }
    .onChange(of: sample) { _, value in loadSample(value) }
  }

  private var readerArea: some View {
    VStack(spacing: 8) {
      controls
      if let sourceChapter, let chapterLayout {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text("\(sourceChapter.bookName) \(sourceChapter.chapter.c)")
            .font(.system(size: 24, weight: .bold))
            .accessibilityAddTraits(.isHeader)
          Text(sourceChapter.edition)
            .font(.caption)
            .foregroundStyle(ReaderProofTheme.tint)
          Spacer()
        }
        .padding(.horizontal, 18)

        Text(selectionDiagnostic(sourceChapter))
          .font(.system(size: 11, design: .monospaced))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 18)
          .accessibilityIdentifier("selected-verse-ids")

        GeometryReader { geometry in
          ScrollView {
            Group {
              if verseByVerse {
                VerseByVerseProof(
                  chapter: sourceChapter.chapter,
                  layout: chapterLayout,
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                  selection: verseState.range,
                  highlights: savedHighlights,
                  dark: dark,
                  onTap: tapVerse
                )
              } else {
                VerseTextView(
                  chapter: sourceChapter.chapter,
                  bookName: sourceChapter.bookName,
                  layout: chapterLayout,
                  style: ReaderProofStyle(fontSize: fontSize, lineHeight: lineHeight, dark: dark, widthScale: widthScale),
                  selection: verseState.range,
                  savedHighlights: savedHighlights,
                  contextRequest: contextRequest,
                  onTapVerse: tapVerse
                )
                .frame(width: max(220, (geometry.size.width - 36) * widthScale))
              }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 18)
            .padding(.bottom, 36)
          }
          .accessibilityIdentifier("scripture-scroll-view")
        }
      } else {
        ProgressView(loadMessage).frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .padding(.top, 10)
  }

  private var controls: some View {
    VStack(spacing: 8) {
      HStack(spacing: 8) {
        Menu {
          ForEach(ScriptureSample.allCases) { value in
            Button(value.rawValue) { sample = value }
          }
        } label: {
          Label(sample.rawValue, systemImage: "book.closed")
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(ReaderProofTheme.card, in: RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityIdentifier("sample-picker")

        Button(verseByVerse ? "Paragraphs" : "Verse view") { verseByVerse.toggle() }
          .font(.system(size: 12, weight: .semibold))
          .buttonStyle(.bordered)
          .accessibilityIdentifier("layout-toggle")

        Button(dark ? "Light" : "Dark") { dark.toggle() }
          .font(.system(size: 12, weight: .semibold))
          .buttonStyle(.bordered)
          .accessibilityIdentifier("appearance-toggle")
      }

      HStack(spacing: 10) {
        Text("Aa")
          .font(.system(size: 14, weight: .semibold))
        Button("−") { setFontSize(max(16, fontSize - 3)) }
          .accessibilityLabel("Decrease reader text size")
        Text(fontSizeLabel)
          .font(.system(size: 12, weight: .medium))
          .frame(minWidth: 48)
          .accessibilityIdentifier("reader-text-size")
        Button("+") { setFontSize(min(24, fontSize + 3)) }
          .accessibilityLabel("Increase reader text size")
        Slider(value: $widthScale, in: 0.72...1, step: 0.04)
          .frame(maxWidth: 110)
          .accessibilityLabel("Reader column width")
        Button("Restore verse 1") { repeatContextRequest() }
          .font(.system(size: 11, weight: .medium))
          .accessibilityIdentifier("restore-verse-anchor")
        Button("Clear") { verseState.range = nil; tapTrace = "" }
          .font(.system(size: 11, weight: .medium))
          .accessibilityIdentifier("clear-verse-selection")
      }
      .buttonStyle(.borderless)
      .tint(ReaderProofTheme.tint)
      .padding(.horizontal, 14)
      .frame(maxWidth: .infinity)

      HStack(spacing: 6) {
        Text("Saved fills")
          .font(.system(size: 11, weight: .medium))
        ForEach(ReaderHighlight.allCases, id: \.rawValue) { highlight in
          HStack(spacing: 4) {
            Circle().fill(swiftUIColor(highlight)).frame(width: 11, height: 11)
            Text(highlight.rawValue).font(.system(size: 10))
          }
          .padding(.horizontal, 5)
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 16)

      HStack(spacing: 8) {
        Text("Tap index")
          .font(.system(size: 10, weight: .medium))
        ForEach([10, 12, 8], id: \.self) { index in
          Button(String(index)) { tapVerse(index) }
            .font(.system(size: 10, weight: .semibold))
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .accessibilityIdentifier("tap-verse-index-\(index)")
        }
      }
      .padding(.horizontal, 16)
    }
    .padding(.bottom, 4)
  }

  private var fontSizeLabel: String {
    switch fontSize {
    case ...16: "Small · 16"
    case ...18: "Medium · 18"
    case ...21: "Large · 21"
    default: "XL · 24"
    }
  }

  private func setFontSize(_ value: CGFloat) {
    fontSize = value
  }

  private func loadSample(_ value: ScriptureSample) {
    loadMessage = "Loading \(value.rawValue)…"
      do {
      sourceChapter = value == .unicode ? SampleLoader.unicodeChapter() : try SampleLoader.chapter(value.resource)
      verseState.range = nil
      tapTrace = ""
      savedHighlights = [0: .gold, 1: .sage, 2: .rose, 3: .blue]
      contextRequest = nil
    } catch {
      sourceChapter = nil
      loadMessage = "Could not load \(value.rawValue): \(error.localizedDescription)"
    }
  }

  private func tapVerse(_ index: Int) {
    let oldRange = rangeLabel(verseState.range)
    verseState.tap(index)
    tapTrace = "tap \(index): \(oldRange) → \(rangeLabel(verseState.range))"
  }

  private func repeatContextRequest() {
    let newNonce = (contextRequest?.nonce ?? 0) + 1
    contextRequest = (0, newNonce)
  }

  private func selectionDiagnostic(_ source: SourceChapter) -> String {
    guard let range = verseState.range else {
      return tapTrace.isEmpty ? "Selected IDs: none" : "Selected IDs: none · \(tapTrace)"
    }
    let labels = source.chapter.verses[range].map(\.n)
    return "Selected IDs: \(source.edition):\(source.bookCode):\(source.chapter.c):\(labels.joined(separator: ",")) · \(tapTrace)"
  }

  private func rangeLabel(_ range: ClosedRange<Int>?) -> String {
    guard let range else { return "nil" }
    return "[\(range.lowerBound),\(range.upperBound)]"
  }

  private func swiftUIColor(_ value: ReaderHighlight) -> Color {
    switch value {
    case .gold: Color(red: 244 / 255, green: 216 / 255, blue: 154 / 255)
    case .sage: Color(red: 200 / 255, green: 214 / 255, blue: 192 / 255)
    case .rose: Color(red: 230 / 255, green: 197 / 255, blue: 200 / 255)
    case .blue: Color(red: 198 / 255, green: 213 / 255, blue: 230 / 255)
    }
  }
}

private struct VerseByVerseProof: View {
  let chapter: Chapter
  let layout: ChapterLayout
  let fontSize: CGFloat
  let lineHeight: CGFloat
  let selection: ClosedRange<Int>?
  let highlights: [Int: ReaderHighlight]
  let dark: Bool
  let onTap: (Int) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(layout.verses.enumerated()), id: \.offset) { index, verse in
        if verse.startsBlock && index > 0 {
          Spacer().frame(height: lineHeight * 0.5)
        }
        ForEach(Array(verse.headings.enumerated()), id: \.offset) { _, heading in
          Text(heading.1)
            .font(heading.0 == "d" ? .system(size: fontSize * 0.85, weight: .regular, design: .serif).italic() : .system(size: 13, weight: .semibold))
            .accessibilityAddTraits(heading.0 == "d" ? [] : .isHeader)
        }
        Button {
          onTap(index)
        } label: {
          verseText(verse, index: index)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, verseIndent(verse))
            .padding(.vertical, 2)
            .background(highlightColor(index), in: RoundedRectangle(cornerRadius: 5))
            .overlay(alignment: .bottom) {
              if selection?.contains(index) == true {
                Rectangle().fill(ReaderProofTheme.tint).frame(height: 1)
              }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("reader-verse-\(chapter.verses[index].n)")
        .accessibilityLabel("Verse \(chapter.verses[index].n). \(chapter.verses[index].t)")
        .accessibilityValue(selection?.contains(index) == true ? "Selected" : "Not selected")
      }
    }
  }

  @ViewBuilder
  private func verseText(_ verse: VerseLayout, index: Int) -> some View {
    let label = chapter.verses[index].n
    let isSelected = selection?.contains(index) == true
    let color = highlightColor(index)
    VStack(alignment: .leading, spacing: 1) {
      ForEach(Array(verse.lines.enumerated()), id: \.offset) { lineIndex, line in
        switch line {
        case let .heading(kind, text):
          Text(text)
            .font(kind == "d" ? .system(size: fontSize * 0.85, design: .serif).italic() : .system(size: 12, weight: .medium))
        case let .text(kind, stanzaBreak, text):
          HStack(alignment: .firstTextBaseline, spacing: 3) {
            if lineIndex == 0 { Text(label).font(.system(size: fontSize * 0.67, weight: .medium)).foregroundStyle(ReaderProofTheme.tint) }
            Text(text).font(.custom("Georgia", size: fontSize)).foregroundStyle(dark ? Color.white : ReaderProofTheme.text)
          }
          .lineSpacing(max(0, lineHeight - fontSize))
          .padding(.top, stanzaBreak ? lineHeight * 0.5 : 0)
          .padding(.leading, kind == "q2" || kind == "li" || kind == "pi" || kind == "mi" ? fontSize * 1.25 : kind == "q3" ? fontSize * 2.5 : 0)
        }
      }
    }
    .background(color, in: RoundedRectangle(cornerRadius: 5))
    .overlay(alignment: .bottom) {
      if isSelected { Rectangle().fill(ReaderProofTheme.tint).frame(height: 1) }
    }
  }

  private func verseIndent(_ verse: VerseLayout) -> CGFloat { 0 }

  private func highlightColor(_ index: Int) -> Color {
    guard let value = highlights[index] else { return .clear }
    return swiftUIColor(value).opacity(dark ? 0.24 : 1)
  }

  private func swiftUIColor(_ value: ReaderHighlight) -> Color {
    switch value {
    case .gold: Color(red: 244 / 255, green: 216 / 255, blue: 154 / 255)
    case .sage: Color(red: 200 / 255, green: 214 / 255, blue: 192 / 255)
    case .rose: Color(red: 230 / 255, green: 197 / 255, blue: 200 / 255)
    case .blue: Color(red: 198 / 255, green: 213 / 255, blue: 230 / 255)
    }
  }
}
