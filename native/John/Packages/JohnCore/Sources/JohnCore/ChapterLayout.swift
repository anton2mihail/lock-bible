import Foundation

/// One part of a verse inside a flowing text block.
public struct ChapterLayoutSegment: Codable, Hashable, Sendable {
    public let verseIndex: Int
    public let label: String?
    public let text: String
    public init(verseIndex: Int, label: String?, text: String) {
        self.verseIndex = verseIndex; self.label = label; self.text = text
    }
}

/// A heading or a text block in source order.
public enum ChapterLayoutBlock: Codable, Hashable, Sendable {
    case heading(kind: String, text: String, verseIndex: Int)
    case text(kind: String, stanzaBreak: Bool, segments: [ChapterLayoutSegment])
}

public enum ChapterVerseLine: Codable, Hashable, Sendable {
    case heading(kind: String, text: String)
    case text(kind: String, stanzaBreak: Bool, text: String)
}

public struct ChapterVerseLayout: Hashable, Sendable {
    /// Headings that appear before this verse.
    public let headings: [(String, String)]
    public let startsBlock: Bool
    public let lines: [ChapterVerseLine]
    public init(headings: [(String, String)], startsBlock: Bool, lines: [ChapterVerseLine]) {
        self.headings = headings; self.startsBlock = startsBlock; self.lines = lines
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.headings.elementsEqual(rhs.headings, by: ==) && lhs.startsBlock == rhs.startsBlock && lhs.lines == rhs.lines
    }
    public func hash(into hasher: inout Hasher) {
        for heading in headings { hasher.combine(heading.0); hasher.combine(heading.1) }
        hasher.combine(startsBlock); hasher.combine(lines)
    }
}

/// Pure source layout for one chapter. Offsets use UTF-16, like the source JavaScript strings.
public struct ChapterLayout: Sendable {
    public let structured: Bool
    public let blocks: [ChapterLayoutBlock]
    /// This array follows `BibleChapter.verses` order.
    public let verses: [ChapterVerseLayout]

    public static func build(_ chapter: BibleChapter) throws -> ChapterLayout {
        let structured = chapter.verses.contains { !$0.breaks.isEmpty }
        var blocks: [ChapterLayoutBlock] = []
        var verseLayouts: [ChapterVerseLayout] = []
        var currentBlock: Int?
        var lastKind = "p"

        func openBlock(_ kind: String, stanzaBreak: Bool) -> Int {
            blocks.append(.text(kind: kind, stanzaBreak: stanzaBreak, segments: []))
            currentBlock = blocks.count - 1
            lastKind = kind
            return blocks.count - 1
        }

        func place(_ verseIndex: Int, label: inout String?, text: String, lines: inout [ChapterVerseLine]) {
            guard !text.isEmpty else { return }
            let blockIndex = currentBlock ?? openBlock(lastKind, stanzaBreak: false)
            guard case let .text(kind, stanzaBreak, segments) = blocks[blockIndex] else { return }
            var updated = segments
            updated.append(ChapterLayoutSegment(verseIndex: verseIndex, label: label, text: text))
            blocks[blockIndex] = .text(kind: kind, stanzaBreak: stanzaBreak, segments: updated)
            lines.append(.text(kind: kind, stanzaBreak: stanzaBreak && updated.count == 1, text: text))
            label = nil
        }

        for (verseIndex, verse) in chapter.verses.enumerated() {
            let source = verse.text as NSString
            let length = source.length
            guard verse.breaks.allSatisfy({ $0.offset >= 0 && $0.offset <= length }),
                  verse.headings.allSatisfy({ heading in
                      guard let offset = heading.offset else { return true }
                      return offset >= 0 && offset <= length
                  }) else {
                throw CoreError.invalidResource("chapter layout offset is outside verse text")
            }
            var preVerseHeadings: [(String, String)] = []
            var events: [Event] = []
            for heading in verse.headings {
                if let offset = heading.offset, offset > 0 {
                    events.append(.heading(offset: offset, kind: heading.kind, text: heading.text))
                } else {
                    preVerseHeadings.append((heading.kind, heading.text))
                }
            }
            for (kind, text) in preVerseHeadings {
                currentBlock = nil
                blocks.append(.heading(kind: kind, text: text, verseIndex: verseIndex))
            }

            let starts = structured ? groupedStarts(verse.breaks) : [Start(offset: 0, kind: "p", stanzaBreak: false)]
            events.append(contentsOf: starts.map(Event.start))
            events.sort { $0.offset == $1.offset ? $0.rank < $1.rank : $0.offset < $1.offset }

            var lines: [ChapterVerseLine] = []
            var label: String? = verse.label
            let firstOffset = min(events.first?.offset ?? length, length)
            if firstOffset > 0 {
                place(verseIndex, label: &label, text: source.substring(to: firstOffset).trimmingCharacters(in: .whitespacesAndNewlines), lines: &lines)
            }

            for (eventIndex, event) in events.enumerated() {
                let start = min(event.offset, length)
                let end = min(events.dropFirst(eventIndex + 1).first?.offset ?? length, length)
                let text = source.substring(with: NSRange(location: start, length: max(start, end) - start))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
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
            verseLayouts.append(ChapterVerseLayout(headings: preVerseHeadings, startsBlock: starts.first?.offset == 0, lines: lines))
        }

        let visibleBlocks = blocks.filter { block in
            if case let .text(_, _, segments) = block { return !segments.isEmpty }
            return true
        }
        return ChapterLayout(structured: structured, blocks: visibleBlocks, verses: verseLayouts)
    }

    private static func groupedStarts(_ breaks: [VerseBreak]) -> [Start] {
        var result: [Start] = []
        for value in breaks {
            if result.last?.offset != value.offset { result.append(Start(offset: value.offset, kind: nil, stanzaBreak: false)) }
            guard !result.isEmpty else { continue }
            if value.kind == "b" { result[result.count - 1].stanzaBreak = true }
            else { result[result.count - 1].kind = value.kind }
        }
        return result
    }

    private static func currentKind(blocks: [ChapterLayoutBlock], index: Int?) -> String? {
        guard let index, case let .text(kind, _, _) = blocks[index] else { return nil }
        return kind
    }

    private struct Start { let offset: Int; var kind: String?; var stanzaBreak: Bool }
    private enum Event {
        case heading(offset: Int, kind: String, text: String)
        case start(Start)
        var offset: Int { switch self { case let .heading(offset, _, _): offset; case let .start(value): value.offset } }
        var rank: Int { switch self { case .heading: 0; case .start: 1 } }
    }
}
