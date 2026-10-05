import Foundation

struct LayoutSegment: Sendable {
  let verseIndex: Int
  let label: String?
  let text: String
}

enum ChapterBlock: Sendable {
  case heading(kind: String, text: String, verseIndex: Int)
  case text(kind: String, stanzaBreak: Bool, segments: [LayoutSegment])
}

enum VerseLine: Sendable {
  case heading(kind: String, text: String)
  case text(kind: String, stanzaBreak: Bool, text: String)
}

struct VerseLayout: Sendable {
  let headings: [(String, String)]
  let startsBlock: Bool
  let lines: [VerseLine]
}

struct VerseTapState: Equatable, Sendable {
  var range: ClosedRange<Int>?

  mutating func tap(_ index: Int) {
    guard let current = range else {
      range = index...index
      return
    }
    if current.lowerBound == index && current.upperBound == index {
      range = nil
      return
    }
    range = min(current.lowerBound, index)...max(current.lowerBound, index)
  }
}

struct ChapterLayout: Sendable {
  let structured: Bool
  let blocks: [ChapterBlock]
  let verses: [VerseLayout]

  static func build(_ chapter: Chapter) -> ChapterLayout {
    let structured = chapter.verses.contains { !$0.br.isEmpty }
    var blocks: [ChapterBlock] = []
    var verseLayouts: [VerseLayout] = []
    var currentBlock: Int?
    var lastKind = "p"

    func openBlock(_ kind: String, stanzaBreak: Bool) -> Int {
      blocks.append(.text(kind: kind, stanzaBreak: stanzaBreak, segments: []))
      currentBlock = blocks.count - 1
      lastKind = kind
      return blocks.count - 1
    }

    func place(_ verseIndex: Int, label: inout String?, text: String, lines: inout [VerseLine]) {
      guard !text.isEmpty else { return }
      let blockIndex = currentBlock ?? openBlock(lastKind, stanzaBreak: false)
      guard case let .text(kind, stanzaBreak, segments) = blocks[blockIndex] else { return }
      var updatedSegments = segments
      updatedSegments.append(LayoutSegment(verseIndex: verseIndex, label: label, text: text))
      blocks[blockIndex] = .text(
        kind: kind,
        stanzaBreak: stanzaBreak,
        segments: updatedSegments
      )
      lines.append(.text(kind: kind, stanzaBreak: stanzaBreak && updatedSegments.count == 1, text: text))
      label = nil
    }

    for (verseIndex, verse) in chapter.verses.enumerated() {
      var headings: [(String, String)] = []
      var events: [Event] = []
      for heading in verse.hd {
        if let offset = heading.offset, offset > 0 {
          events.append(.heading(offset: offset, kind: heading.kind, text: heading.text))
        } else {
          headings.append((heading.kind, heading.text))
        }
      }
      for (kind, text) in headings {
        currentBlock = nil
        blocks.append(.heading(kind: kind, text: text, verseIndex: verseIndex))
      }

      let starts = structured
        ? groupedStarts(verse.br)
        : [Start(offset: 0, kind: "p", stanzaBreak: false)]
      events.append(contentsOf: starts.map(Event.start))
      events.sort {
        if $0.offset == $1.offset { return $0.rank < $1.rank }
        return $0.offset < $1.offset
      }

      var lines: [VerseLine] = []
      var label: String? = verse.n
      let textLength = (verse.t as NSString).length
      let firstOffset = min(events.first?.offset ?? textLength, textLength)
      if firstOffset > 0 {
        place(verseIndex, label: &label, text: substring(verse.t, 0, firstOffset).trimmingCharacters(in: .whitespacesAndNewlines), lines: &lines)
      }

      for (eventIndex, event) in events.enumerated() {
        let start = min(event.offset, textLength)
        let end = min(events.dropFirst(eventIndex + 1).first?.offset ?? textLength, textLength)
        let text = substring(verse.t, start, max(start, end)).trimmingCharacters(in: .whitespacesAndNewlines)
        switch event {
        case let .heading(_, kind, headingText):
          currentBlock = nil
          blocks.append(.heading(kind: kind, text: headingText, verseIndex: verseIndex))
          lines.append(.heading(kind: kind, text: headingText))
          if !text.isEmpty {
            _ = openBlock(lastKind, stanzaBreak: false)
            place(verseIndex, label: &label, text: text, lines: &lines)
          }
        case let .start(value):
          let kind = value.kind ?? currentKind(blocks: blocks, index: currentBlock) ?? lastKind
          _ = openBlock(kind, stanzaBreak: value.stanzaBreak)
          place(verseIndex, label: &label, text: text, lines: &lines)
        }
      }
      verseLayouts.append(
        VerseLayout(
          headings: headings,
          startsBlock: starts.first?.offset == 0,
          lines: lines
        )
      )
    }

    let nonEmptyBlocks = blocks.filter {
      if case let .text(_, _, segments) = $0 { return !segments.isEmpty }
      return true
    }
    return ChapterLayout(structured: structured, blocks: nonEmptyBlocks, verses: verseLayouts)
  }

  private static func groupedStarts(_ breaks: [SourceBreak]) -> [Start] {
    var result: [Start] = []
    for value in breaks {
      if result.last?.offset != value.offset {
        result.append(Start(offset: value.offset, kind: nil, stanzaBreak: false))
      }
      guard !result.isEmpty else { continue }
      if value.kind == "b" {
        result[result.count - 1].stanzaBreak = true
      } else {
        result[result.count - 1].kind = value.kind
      }
    }
    return result
  }

  private static func currentKind(blocks: [ChapterBlock], index: Int?) -> String? {
    guard let index, case let .text(kind, _, _) = blocks[index] else { return nil }
    return kind
  }

  private static func substring(_ value: String, _ start: Int, _ end: Int) -> String {
    let source = value as NSString
    guard start >= 0, end <= source.length, start <= end else { return "" }
    return source.substring(with: NSRange(location: start, length: end - start))
  }

  private struct Start {
    let offset: Int
    var kind: String?
    var stanzaBreak: Bool
  }

  private enum Event {
    case heading(offset: Int, kind: String, text: String)
    case start(Start)

    var offset: Int {
      switch self {
      case let .heading(offset, _, _): offset
      case let .start(value): value.offset
      }
    }

    var rank: Int {
      switch self {
      case .heading: 0
      case .start: 1
      }
    }
  }
}
