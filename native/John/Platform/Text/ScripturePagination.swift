import SwiftUI
import UIKit
import JohnCore

// The paged Reader. A chapter is laid out once in one tall TextKit column. Pages are horizontal bands of that layout,
// so justification, hyphenation, and indents are the same as in one continuous column, and a paragraph can go on
// across a page turn without a new first line. The page breaks keep headings with the text after them and do not
// leave the first or last line of a paragraph alone on a page.

/// One chapter in one edition.
struct ScriptureChapterKey: Hashable, Sendable {
    let translation: TranslationID
    let bookCode: String
    let chapter: Int
}

/// One page of one chapter.
struct ScripturePageID: Hashable, Sendable {
    let key: ScriptureChapterKey
    let page: Int
}

/// The reading values that change the page text.
struct ScripturePageStyle: Hashable, Sendable {
    let textSize: ReaderTextSize
    let lineSpacing: ReaderLineSpacing
    let typeface: ReaderTypeface
    let layout: ReaderLayout
    let dynamicTypeScale: CGFloat
    let isDark: Bool
    /// False for editions whose language the system hyphenation does not know (the Latin Vulgate).
    let hyphenates: Bool

    var fontSize: CGFloat {
        let base: CGFloat = switch textSize {
        case .small: 16
        case .medium: 18
        case .large: 21
        case .extraLarge: 24
        }
        return (base * dynamicTypeScale).rounded()
    }

    /// Book line heights. They are a little tighter than the scroll Reader, because justified text in a page
    /// column reads well with less space between lines.
    var lineHeight: CGFloat {
        let multiplier: CGFloat = switch lineSpacing {
        case .compact: 1.36
        case .comfortable: 1.5
        case .relaxed: 1.7
        }
        return (fontSize * multiplier).rounded()
    }

    /// Running head and footer size. They grow with Dynamic Type, but less than the text.
    var chromeFontSize: CGFloat { (11 * min(max(dynamicTypeScale, 0.9), 1.6)).rounded() }
}

/// Where the text, the running head, and the footer go on a page.
struct ScripturePageGeometry: Hashable, Sendable {
    let size: CGSize
    let columns: Int
    let columnWidth: CGFloat
    let columnGap: CGFloat
    let textLeft: CGFloat
    let textTop: CGFloat
    let textHeight: CGFloat
    let headerCenterY: CGFloat
    let footerCenterY: CGFloat
    let contentLeft: CGFloat
    let contentWidth: CGFloat

    func columnX(_ column: Int) -> CGFloat { textLeft + CGFloat(column) * (columnWidth + columnGap) }

    /// Book margins. A wide landscape page (iPad) shows two columns, as Apple Books does.
    static func make(size: CGSize, safeTop: CGFloat, safeBottom: CGFloat, safeLeft: CGFloat, safeRight: CGFloat,
                     style: ScripturePageStyle) -> ScripturePageGeometry {
        let fontSize = style.fontSize
        let chrome = style.chromeFontSize
        let available = max(0, size.width - safeLeft - safeRight)
        let margin = min(max((available * 0.08).rounded(), 26), 72)
        let measure = (fontSize * 36).rounded()
        let gap = (margin * 1.2).rounded()
        let twoColumns = size.width > size.height && available - margin * 2 >= fontSize * 40 + gap && available >= 900
        let columns = twoColumns ? 2 : 1
        let inner = available - margin * 2
        let columnWidth = max(80, min(twoColumns ? ((inner - gap) / 2).rounded(.down) : inner.rounded(.down), measure))
        let blockWidth = columnWidth * CGFloat(columns) + gap * CGFloat(columns - 1)
        let textLeft = (safeLeft + (available - blockWidth) / 2).rounded()
        let top = max(safeTop, 12)
        let bottom = max(safeBottom, 12)
        let headerCenterY = (top + 10 + chrome * 0.6).rounded()
        let textTop = (headerCenterY + chrome * 0.6 + 18 + chrome * 0.4).rounded()
        let footerCenterY = (size.height - bottom - 8 - chrome * 0.6).rounded()
        let textBottom = footerCenterY - chrome * 0.6 - 16
        let textHeight = max(style.lineHeight * 2, (textBottom - textTop).rounded(.down))
        return ScripturePageGeometry(size: size, columns: columns, columnWidth: columnWidth, columnGap: gap,
                                     textLeft: textLeft, textTop: textTop, textHeight: textHeight,
                                     headerCenterY: headerCenterY, footerCenterY: footerCenterY,
                                     contentLeft: textLeft, contentWidth: blockWidth)
    }
}

/// Everything that changes where page breaks fall. Pages are valid only for the key they were built with.
struct ScripturePaginationKey: Hashable, Sendable {
    let style: ScripturePageStyle
    let geometry: ScripturePageGeometry
}

/// What a page draws over its text: saved highlights, the selection, and the context or spoken verse.
struct ScripturePageDecorations: Equatable {
    var highlights: [Int: HighlightColor] = [:]
    var selection: ClosedRange<Int>?
    var context: ClosedRange<Int>?
}

/// One column of one page: a horizontal band of the chapter layout.
struct ScriptureColumnBand: Sendable {
    let glyphRange: NSRange
    let characterRange: NSRange
    let top: CGFloat
    let height: CGFloat
}

enum ScripturePageRole: Int, Sendable { case body, label, heading, title }

extension NSAttributedString.Key {
    static let scripturePageVerse = NSAttributedString.Key("reader.page.verseIndex")
    static let scripturePageRole = NSAttributedString.Key("reader.page.role")
}

/// One paginated chapter. The TextKit objects are built on a background task and then used only on the main thread.
final class ScriptureChapterPagination: @unchecked Sendable {
    let key: ScriptureChapterKey
    let paginationKey: ScripturePaginationKey
    let bookName: String
    let chapter: BibleChapter
    let storage: NSTextStorage
    let layoutManager: NSLayoutManager
    let container: NSTextContainer
    let bands: [ScriptureColumnBand]
    let verseRanges: [Int: [NSRange]]
    let verseBodyRanges: [Int: [NSRange]]
    let headingRanges: [(kind: String, range: NSRange)]
    let titleRanges: [(label: String, range: NSRange)]
    let bodyFont: UIFont
    let colors: ScripturePageColors

    var geometry: ScripturePageGeometry { paginationKey.geometry }
    var style: ScripturePageStyle { paginationKey.style }
    var pageCount: Int { max(1, (bands.count + geometry.columns - 1) / geometry.columns) }
    var title: String { "\(bookName) \(chapter.number)" }

    init(key: ScriptureChapterKey, paginationKey: ScripturePaginationKey, bookName: String, chapter: BibleChapter,
         storage: NSTextStorage, layoutManager: NSLayoutManager, container: NSTextContainer,
         bands: [ScriptureColumnBand], verseRanges: [Int: [NSRange]], verseBodyRanges: [Int: [NSRange]],
         headingRanges: [(kind: String, range: NSRange)], titleRanges: [(label: String, range: NSRange)],
         bodyFont: UIFont, colors: ScripturePageColors) {
        self.key = key; self.paginationKey = paginationKey; self.bookName = bookName; self.chapter = chapter
        self.storage = storage; self.layoutManager = layoutManager; self.container = container
        self.bands = bands; self.verseRanges = verseRanges; self.verseBodyRanges = verseBodyRanges
        self.headingRanges = headingRanges; self.titleRanges = titleRanges
        self.bodyFont = bodyFont; self.colors = colors
    }

    func bands(onPage page: Int) -> [ScriptureColumnBand] {
        let start = page * geometry.columns
        guard start < bands.count else { return [] }
        return Array(bands[start..<min(bands.count, start + geometry.columns)])
    }

    func characterRange(ofPage page: Int) -> NSRange {
        let pageBands = bands(onPage: page)
        guard let first = pageBands.first, let last = pageBands.last else { return NSRange(location: 0, length: 0) }
        return NSRange(location: first.characterRange.location,
                       length: NSMaxRange(last.characterRange) - first.characterRange.location)
    }

    func page(containingCharacter index: Int) -> Int {
        guard let band = bands.firstIndex(where: { NSMaxRange($0.characterRange) > index }) else { return pageCount - 1 }
        return min(band / geometry.columns, pageCount - 1)
    }

    /// The page that holds the first character of a verse.
    func page(forVerse index: Int) -> Int? {
        guard let first = verseRanges[index]?.map(\.location).min() else { return nil }
        return page(containingCharacter: first)
    }

    /// True when some part of the verse is on the page.
    func verse(_ index: Int, isOnPage page: Int) -> Bool {
        let range = characterRange(ofPage: page)
        return verseRanges[index]?.contains { NSIntersectionRange($0, range).length > 0 } ?? false
    }

    /// The verses that have text on the page, in order.
    func verses(onPage page: Int) -> [Int] {
        let range = characterRange(ofPage: page)
        return verseRanges.keys.sorted().filter { index in
            verseRanges[index]?.contains { NSIntersectionRange($0, range).length > 0 } ?? false
        }
    }

    /// The first Scripture character on a page as a verse anchor. It is the same kind of anchor that the scroll
    /// Reader saves, so a saved place survives a change of text size, rotation, and a change between Pages and Scroll.
    func anchor(forPage page: Int) -> ReaderAnchor? {
        let range = characterRange(ofPage: page)
        var best: (verse: Int, character: Int)?
        for (verse, ranges) in verseBodyRanges {
            for item in ranges {
                let overlap = NSIntersectionRange(item, range)
                guard overlap.length > 0 else { continue }
                if best == nil || overlap.location < best!.character { best = (verse, overlap.location) }
            }
        }
        if best == nil {
            // A page with only headings: use the next verse.
            for (verse, ranges) in verseBodyRanges {
                for item in ranges where item.location >= NSMaxRange(range) {
                    if best == nil || item.location < best!.character { best = (verse, item.location) }
                }
            }
        }
        guard let best, chapter.verses.indices.contains(best.verse),
              let label = VerseLabel(rawValue: chapter.verses[best.verse].label) else { return nil }
        var offset = 0
        for item in (verseBodyRanges[best.verse] ?? []).sorted(by: { $0.location < $1.location }) {
            if best.character < item.location { break }
            offset += min(item.length, best.character - item.location)
            if NSLocationInRange(best.character, item) { break }
        }
        return try? ReaderAnchor(verseLabel: label, utf16Offset: offset)
    }

    /// The page that holds a saved anchor, or nil when the verse is not in this chapter.
    func page(for anchor: ReaderAnchor) -> Int? {
        guard let verse = chapter.verses.firstIndex(where: { $0.label == anchor.verseLabel.rawValue }),
              let ranges = verseBodyRanges[verse], !ranges.isEmpty else { return nil }
        var remaining = anchor.utf16Offset
        let ordered = ranges.sorted { $0.location < $1.location }
        for (index, item) in ordered.enumerated() {
            if remaining < item.length || index == ordered.count - 1 {
                return page(containingCharacter: item.location + min(remaining, max(0, item.length - 1)))
            }
            remaining -= item.length
        }
        return nil
    }

    /// The top and the bottom of the text of some verses on a page, in page coordinates. Nil when none of the
    /// verses has text on the page.
    func verticalExtent(ofVerses verses: ClosedRange<Int>, onPage page: Int) -> ClosedRange<CGFloat>? {
        var top = CGFloat.greatestFiniteMagnitude
        var bottom = -CGFloat.greatestFiniteMagnitude
        for band in bands(onPage: page) where band.glyphRange.length > 0 {
            for verse in verses {
                for range in verseRanges[verse] ?? [] {
                    let overlap = NSIntersectionRange(range, band.characterRange)
                    guard overlap.length > 0 else { continue }
                    let glyphs = layoutManager.glyphRange(forCharacterRange: overlap, actualCharacterRange: nil)
                    layoutManager.enumerateLineFragments(forGlyphRange: glyphs) { rect, _, _, _, _ in
                        top = min(top, rect.minY - band.top)
                        bottom = max(bottom, rect.maxY - band.top)
                    }
                }
            }
        }
        guard top <= bottom else { return nil }
        return (geometry.textTop + top)...(geometry.textTop + bottom)
    }

    func verseIndex(atCharacter index: Int) -> Int? {
        guard index >= 0, index < storage.length else { return nil }
        return (storage.attribute(.scripturePageVerse, at: index, effectiveRange: nil) as? NSNumber)?.intValue
    }

    func role(atCharacter index: Int) -> ScripturePageRole {
        guard index >= 0, index < storage.length,
              let raw = storage.attribute(.scripturePageRole, at: index, effectiveRange: nil) as? NSNumber else { return .body }
        return ScripturePageRole(rawValue: raw.intValue) ?? .body
    }
}

/// UIKit colors for one appearance.
struct ScripturePageColors: @unchecked Sendable {
    let background: UIColor
    let text: UIColor
    let textDim: UIColor
    let tint: UIColor

    init(isDark: Bool) {
        let colors = isDark ? JohnColors.dark : JohnColors.light
        background = UIColor(colors.background)
        text = UIColor(colors.text)
        textDim = UIColor(colors.textDim)
        tint = UIColor(colors.tint)
    }

    func highlight(_ color: HighlightColor, isDark: Bool) -> UIColor {
        let values: (CGFloat, CGFloat, CGFloat) = switch color {
        case .gold: (244, 216, 154)
        case .sage: (200, 214, 192)
        case .rose: (230, 197, 200)
        case .blue: (198, 213, 230)
        }
        return UIColor(red: values.0 / 255, green: values.1 / 255, blue: values.2 / 255, alpha: isDark ? 0.3 : 1)
    }
}

enum ScripturePaginator {
    /// Builds and paginates one chapter. It does not touch UI state, so it can run on a background task.
    static func paginate(key: ScriptureChapterKey, bookName: String, chapter: BibleChapter, layout: ChapterLayout,
                         paginationKey: ScripturePaginationKey) -> ScriptureChapterPagination {
        #if DEBUG
        let started = CFAbsoluteTimeGetCurrent()
        #endif
        let style = paginationKey.style
        let geometry = paginationKey.geometry
        let colors = ScripturePageColors(isDark: style.isDark)
        let built = ScriptureBookTextBuilder(chapter: chapter, layout: layout, bookName: bookName,
                                             style: style, colors: colors).build()
        let storage = NSTextStorage(attributedString: built.text)
        let manager = NSLayoutManager()
        manager.allowsNonContiguousLayout = false
        let container = NSTextContainer(size: CGSize(width: geometry.columnWidth, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        let bands = breakIntoBands(manager: manager, storage: storage, container: container,
                                   height: geometry.textHeight)
        #if DEBUG
        NSLog("READER_PAGES paginate %@ %d chars=%d pages=%d columns=%d ms=%.1f", key.bookCode, key.chapter,
              storage.length, (bands.count + geometry.columns - 1) / max(1, geometry.columns), geometry.columns,
              (CFAbsoluteTimeGetCurrent() - started) * 1000)
        #endif
        return ScriptureChapterPagination(key: key, paginationKey: paginationKey, bookName: bookName,
                                          chapter: chapter, storage: storage, layoutManager: manager,
                                          container: container, bands: bands, verseRanges: built.verseRanges,
                                          verseBodyRanges: built.verseBodyRanges, headingRanges: built.headingRanges,
                                          titleRanges: built.titleRanges, bodyFont: built.bodyFont, colors: colors)
    }

    private struct Line {
        let glyphs: NSRange
        let characters: NSRange
        let top: CGFloat
        let bottom: CGFloat
        let role: ScripturePageRole
        let startsParagraph: Bool
        let endsParagraph: Bool
    }

    private static func breakIntoBands(manager: NSLayoutManager, storage: NSTextStorage, container: NSTextContainer,
                                       height: CGFloat) -> [ScriptureColumnBand] {
        let text = storage.string as NSString
        var lines: [Line] = []
        let all = manager.glyphRange(for: container)
        manager.enumerateLineFragments(forGlyphRange: all) { rect, used, _, glyphs, _ in
            let characters = manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            guard characters.length > 0 else { return }
            let first = characters.location
            let last = NSMaxRange(characters) - 1
            let role = (storage.attribute(.scripturePageRole, at: first, effectiveRange: nil) as? NSNumber)
                .flatMap { ScripturePageRole(rawValue: $0.intValue) } ?? .body
            let starts = first == 0 || text.character(at: first - 1) == 0x0A
            let ends = last >= text.length - 1 || text.character(at: last) == 0x0A
            lines.append(Line(glyphs: glyphs, characters: characters, top: rect.minY,
                              bottom: max(rect.minY + used.height, used.maxY), role: role,
                              startsParagraph: starts, endsParagraph: ends))
        }
        guard !lines.isEmpty else {
            return [ScriptureColumnBand(glyphRange: NSRange(location: 0, length: 0),
                                        characterRange: NSRange(location: 0, length: 0), top: 0, height: 0)]
        }
        var bands: [ScriptureColumnBand] = []
        var start = 0
        while start < lines.count {
            let top = lines[start].top
            var end = start
            while end < lines.count, lines[end].bottom - top <= height + 0.5 { end += 1 }
            if end == start { end = start + 1 }
            if end < lines.count {
                func keepWithNext() {
                    var changed = true
                    while changed {
                        changed = false
                        // A heading or the chapter title goes to the next page with the text after it.
                        if end - 1 > start, lines[end - 1].role == .heading || lines[end - 1].role == .title {
                            end -= 1; changed = true; continue
                        }
                        // A heading has at least two lines of text after it on its page.
                        if end - 2 > start, lines[end - 2].role == .heading || lines[end - 2].role == .title {
                            end -= 2; changed = true; continue
                        }
                        // The first line of a paragraph is not left alone at the bottom of a page (an orphan).
                        if end - 1 > start, lines[end - 1].startsParagraph, !lines[end - 1].endsParagraph {
                            end -= 1; changed = true; continue
                        }
                    }
                }
                keepWithNext()
                // The last line of a paragraph is not left alone at the top of the next page (a widow). The line
                // before it goes too. If that leaves an orphan or a heading at the bottom, they go as well.
                if end - 1 > start, end < lines.count, lines[end].endsParagraph, !lines[end].startsParagraph {
                    end -= 1
                    keepWithNext()
                }
            }
            let first = lines[start]
            let last = lines[end - 1]
            bands.append(ScriptureColumnBand(
                glyphRange: NSRange(location: first.glyphs.location, length: NSMaxRange(last.glyphs) - first.glyphs.location),
                characterRange: NSRange(location: first.characters.location,
                                        length: NSMaxRange(last.characters) - first.characters.location),
                top: top, height: last.bottom - top))
            start = end
        }
        return bands
    }
}

/// Builds the book text of one chapter: the chapter number, headings, and justified Scripture with small raised
/// verse numbers.
private struct ScriptureBookTextBuilder {
    let chapter: BibleChapter
    let layout: ChapterLayout
    let bookName: String
    let style: ScripturePageStyle
    let colors: ScripturePageColors

    struct Result {
        let text: NSAttributedString
        let verseRanges: [Int: [NSRange]]
        let verseBodyRanges: [Int: [NSRange]]
        let headingRanges: [(kind: String, range: NSRange)]
        let titleRanges: [(label: String, range: NSRange)]
        let bodyFont: UIFont
    }

    private static let lineKinds: Set<String> = ["q1", "q2", "q3", "q", "li", "li1", "li2"]

    private func font(_ name: String, _ size: CGFloat, fallbackWeight: UIFont.Weight = .regular) -> UIFont {
        UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: fallbackWeight)
    }

    private func italic(serif: Bool, size: CGFloat) -> UIFont {
        if serif, let georgia = UIFont(name: "Georgia-Italic", size: size) { return georgia }
        let base = font("SpaceGrotesk-Regular", size)
        let descriptor = base.fontDescriptor.withSymbolicTraits(.traitItalic) ?? base.fontDescriptor
        return UIFont(descriptor: descriptor, size: size)
    }

    func build() -> Result {
        let output = NSMutableAttributedString()
        var paragraphs: [(range: NSRange, style: NSMutableParagraphStyle)] = []
        var verses: [Int: [NSRange]] = [:]
        var bodies: [Int: [NSRange]] = [:]
        var headings: [(kind: String, range: NSRange)] = []
        var titles: [(label: String, range: NSRange)] = []

        let serif = style.typeface == .serif
        let fontSize = style.fontSize
        let lineHeight = style.lineHeight
        let bodyFont = serif ? font("Lora-Regular", fontSize) : font("SpaceGrotesk-Regular", fontSize)
        let labelSize = max(9, (fontSize * 0.6).rounded())
        let labelFont = serif ? font("Lora-Medium", labelSize, fallbackWeight: .medium)
            : font("SpaceGrotesk-Medium", labelSize, fallbackWeight: .medium)
        let indent = (fontSize * 1.3).rounded()
        let paragraphGap = (lineHeight * 0.5).rounded()

        var paragraphStart = 0
        var paragraphStyle = NSMutableParagraphStyle()
        func role(_ value: ScripturePageRole) -> NSNumber { NSNumber(value: value.rawValue) }
        /// Ends the open paragraph and sets the space after it, so no paragraph has space before it at a page top.
        func close(spacingAfterPrevious gap: CGFloat) {
            if let last = paragraphs.indices.last {
                paragraphs[last].style.paragraphSpacing = max(paragraphs[last].style.paragraphSpacing, gap)
            }
        }
        func begin(_ style: NSMutableParagraphStyle, gapBefore: CGFloat) {
            if output.length > 0 {
                output.append(NSAttributedString(string: "\n", attributes: [.font: bodyFont, .paragraphStyle: paragraphStyle]))
                paragraphs.append((NSRange(location: paragraphStart, length: output.length - paragraphStart), paragraphStyle))
                close(spacingAfterPrevious: gapBefore)
            }
            paragraphStart = output.length
            paragraphStyle = style
        }
        func lineStyle(_ height: CGFloat, alignment: NSTextAlignment) -> NSMutableParagraphStyle {
            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = height
            paragraph.maximumLineHeight = height
            paragraph.alignment = alignment
            paragraph.lineBreakMode = .byWordWrapping
            return paragraph
        }

        // The chapter opening, as in a printed book: the page starts lower (a chapter drop), then the book name in
        // small capitals and a large chapter number. The running head is not on this page, so the book name is on
        // the opening page of every chapter.
        let drop = (lineHeight * 1.5).rounded()
        let nameSize = max(11, (fontSize * 0.7).rounded())
        let nameParagraph = lineStyle((nameSize * 1.6).rounded() + drop, alignment: .center)
        begin(nameParagraph, gapBefore: 0)
        let nameStart = output.length
        output.append(NSAttributedString(string: bookName.uppercased(), attributes: [
            .font: font("SpaceGrotesk-Medium", nameSize, fallbackWeight: .medium), .kern: nameSize * 0.22,
            .foregroundColor: colors.textDim, .paragraphStyle: nameParagraph, .scripturePageRole: role(.title),
        ]))
        titles.append((bookName, NSRange(location: nameStart, length: output.length - nameStart)))
        let numeralSize = min(fontSize * 2.8, max(fontSize * 1.4, 72)).rounded()
        let numeralParagraph = lineStyle((numeralSize * 1.18).rounded(), alignment: .center)
        begin(numeralParagraph, gapBefore: (lineHeight * 0.2).rounded())
        let numeralStart = output.length
        output.append(NSAttributedString(string: String(chapter.number), attributes: [
            .font: serif ? font("Lora-Regular", numeralSize) : font("SpaceGrotesk-Light", numeralSize, fallbackWeight: .light),
            .foregroundColor: colors.tint, .paragraphStyle: numeralParagraph, .scripturePageRole: role(.title),
        ]))
        titles.append(("Chapter \(chapter.number)", NSRange(location: numeralStart, length: output.length - numeralStart)))
        let afterTitleGap = (lineHeight * 0.85).rounded()

        enum Previous { case title, heading, prose, poetry }
        var previous = Previous.title
        var previousBodyVerse: Int?
        let blocks = ScriptureBlocks.blocks(layout: layout, chapter: chapter, readerLayout: style.layout)
        for (blockIndex, block) in blocks.enumerated() {
            switch block {
            case let .heading(kind, text, _):
                let isPsalmTitle = kind == "d"
                let isSpeaker = kind == "sp"
                let isMajor = kind == "ms" || kind == "mr"
                let size: CGFloat = isPsalmTitle ? (fontSize * 0.88).rounded()
                    : (isMajor ? max(11, (fontSize * 0.7).rounded()) : max(12, (fontSize * 0.8).rounded()))
                let headingFont: UIFont = isPsalmTitle ? italic(serif: serif, size: size)
                    : (isSpeaker ? italic(serif: false, size: size)
                       : font("SpaceGrotesk-SemiBold", size, fallbackWeight: .semibold))
                let paragraph = lineStyle((size * (isPsalmTitle ? 1.4 : 1.45)).rounded(),
                                          alignment: isMajor ? .center : .natural)
                paragraph.hyphenationFactor = 0
                let gap: CGFloat = switch previous {
                case .title: afterTitleGap
                case .heading: (lineHeight * 0.2).rounded()
                default: isSpeaker ? (lineHeight * 0.4).rounded() : (lineHeight * 0.95).rounded()
                }
                begin(paragraph, gapBefore: gap)
                let start = output.length
                var attributes: [NSAttributedString.Key: Any] = [
                    .font: headingFont, .paragraphStyle: paragraph, .scripturePageRole: role(.heading),
                    .foregroundColor: isPsalmTitle ? colors.textDim : (isSpeaker || isMajor ? colors.tint : colors.text),
                ]
                if isMajor { attributes[.kern] = size * 0.16 }
                if !isPsalmTitle && !isSpeaker && !isMajor { attributes[.kern] = size * 0.02 }
                output.append(NSAttributedString(string: isMajor ? text.uppercased() : text, attributes: attributes))
                headings.append((kind, NSRange(location: start, length: output.length - start)))
                paragraph.paragraphSpacing = (lineHeight * 0.3).rounded()
                previous = .heading
                previousBodyVerse = nil

            case let .text(kind, stanzaBreak, segments):
                let isLine = Self.lineKinds.contains(kind)
                let firstVerse = segments.first?.verseIndex
                let continuesVerse = firstVerse != nil && firstVerse == previousBodyVerse
                let alignment: NSTextAlignment = kind == "pc" ? .center : (isLine ? .natural : .justified)
                let paragraph = lineStyle(lineHeight, alignment: alignment)
                paragraph.hyphenationFactor = style.hyphenates && !isLine ? 1 : 0
                let level: CGFloat = switch kind {
                case "q2", "li2", "pi", "mi": indent
                case "q3": indent * 2
                default: 0
                }
                if isLine {
                    // Poetry: a wrapped line hangs under the first one, as in a printed psalter.
                    paragraph.firstLineHeadIndent = level
                    paragraph.headIndent = level + indent
                } else {
                    let indentsFirstLine = style.layout == .paragraphs && previous == .prose && kind == "p"
                    paragraph.firstLineHeadIndent = level + (indentsFirstLine ? indent : 0)
                    paragraph.headIndent = level
                }
                let gap: CGFloat
                if style.layout == .verses {
                    gap = previous == .title ? afterTitleGap
                        : (previous == .heading ? 0
                           : (continuesVerse ? (stanzaBreak ? (lineHeight * 0.3).rounded() : 0) : (lineHeight * 0.3).rounded()))
                } else {
                    switch previous {
                    case .title: gap = afterTitleGap
                    case .heading: gap = 0
                    case .prose: gap = isLine ? paragraphGap : 0
                    case .poetry: gap = isLine ? (stanzaBreak ? paragraphGap : 0) : paragraphGap
                    }
                }
                // A verse that goes on into this block keeps its line break inside the verse text, as the scroll
                // Reader does, so verse anchors count the same characters.
                if continuesVerse, let verse = firstVerse, output.length > 0 {
                    output.append(NSAttributedString(string: "\n", attributes: [
                        .font: bodyFont, .paragraphStyle: paragraphStyle,
                        .scripturePageVerse: NSNumber(value: verse),
                    ]))
                    let separator = NSRange(location: output.length - 1, length: 1)
                    bodies[verse, default: []].append(separator)
                    verses[verse, default: []].append(separator)
                    paragraphs.append((NSRange(location: paragraphStart, length: output.length - paragraphStart), paragraphStyle))
                    close(spacingAfterPrevious: gap)
                    paragraphStart = output.length
                    paragraphStyle = paragraph
                } else {
                    begin(paragraph, gapBefore: gap)
                }
                var previousSegmentVerse: Int?
                for (segmentIndex, segment) in segments.enumerated() {
                    if segmentIndex > 0 {
                        let sameVerse = previousSegmentVerse == segment.verseIndex
                        var attributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .paragraphStyle: paragraph,
                                                                         .foregroundColor: colors.text]
                        if sameVerse { attributes[.scripturePageVerse] = NSNumber(value: segment.verseIndex) }
                        output.append(NSAttributedString(string: " ", attributes: attributes))
                        if sameVerse {
                            let separator = NSRange(location: output.length - 1, length: 1)
                            bodies[segment.verseIndex, default: []].append(separator)
                            verses[segment.verseIndex, default: []].append(separator)
                        }
                    }
                    let start = output.length
                    if let label = segment.label {
                        output.append(NSAttributedString(string: label, attributes: [
                            .font: labelFont, .foregroundColor: colors.tint,
                            .baselineOffset: (fontSize * 0.34).rounded(),
                            .paragraphStyle: paragraph, .scripturePageRole: role(.label),
                            .scripturePageVerse: NSNumber(value: segment.verseIndex),
                        ]))
                        output.append(NSAttributedString(string: "\u{00A0}", attributes: [
                            .font: labelFont, .paragraphStyle: paragraph, .scripturePageRole: role(.label),
                            .scripturePageVerse: NSNumber(value: segment.verseIndex),
                        ]))
                    }
                    let bodyStart = output.length
                    output.append(NSAttributedString(string: segment.text, attributes: [
                        .font: bodyFont, .foregroundColor: colors.text, .paragraphStyle: paragraph,
                        .scripturePageVerse: NSNumber(value: segment.verseIndex),
                    ]))
                    bodies[segment.verseIndex, default: []].append(NSRange(location: bodyStart, length: output.length - bodyStart))
                    verses[segment.verseIndex, default: []].append(NSRange(location: start, length: output.length - start))
                    previousSegmentVerse = segment.verseIndex
                }
                previous = isLine ? .poetry : .prose
                previousBodyVerse = segments.last?.verseIndex
                _ = blockIndex
            }
        }
        if output.length > paragraphStart {
            paragraphs.append((NSRange(location: paragraphStart, length: output.length - paragraphStart), paragraphStyle))
        }
        // The paragraph styles change after their text is added (space after a paragraph is known only at the next
        // block), so the final styles go on at the end.
        for paragraph in paragraphs where paragraph.range.length > 0 {
            if let copy = paragraph.style.copy() as? NSParagraphStyle {
                output.addAttribute(.paragraphStyle, value: copy, range: paragraph.range)
            }
        }
        return Result(text: output, verseRanges: verses, verseBodyRanges: bodies, headingRanges: headings,
                      titleRanges: titles, bodyFont: bodyFont)
    }
}

// MARK: - Page view

/// Draws one page: the running head, one or two text columns with their highlights, and the footer.
final class ScripturePageView: UIView {
    let pagination: ScriptureChapterPagination
    let page: Int
    var decorations: ScripturePageDecorations {
        didSet {
            guard decorations != oldValue else { return }
            setNeedsDisplay()
            accessibilityCache = nil
        }
    }
    var onActivateVerse: ((Int) -> Void)?
    private let header = UILabel()
    private let footer = UILabel()
    private let remaining = UILabel()
    private var accessibilityCache: [UIAccessibilityElement]?

    init(pagination: ScriptureChapterPagination, page: Int, decorations: ScripturePageDecorations) {
        self.pagination = pagination
        self.page = page
        self.decorations = decorations
        super.init(frame: CGRect(origin: .zero, size: pagination.geometry.size))
        backgroundColor = pagination.colors.background
        isOpaque = true
        contentMode = .redraw
        let chromeSize = pagination.style.chromeFontSize
        let headerFont = UIFont(name: "SpaceGrotesk-Medium", size: chromeSize) ?? .systemFont(ofSize: chromeSize, weight: .medium)
        let footerFont = (UIFont(name: "SpaceGrotesk-Regular", size: chromeSize) ?? .systemFont(ofSize: chromeSize))
        header.attributedText = NSAttributedString(string: pagination.title.uppercased(), attributes: [
            .font: headerFont, .kern: chromeSize * 0.16, .foregroundColor: pagination.colors.textDim,
        ])
        header.textAlignment = .center
        header.isHidden = page == 0
        let count = pagination.pageCount
        footer.attributedText = NSAttributedString(string: "\(page + 1) of \(count)", attributes: [
            .font: footerFont.withMonospacedDigits(), .foregroundColor: pagination.colors.textDim,
        ])
        footer.textAlignment = .center
        let left = count - page - 1
        remaining.attributedText = NSAttributedString(
            string: left == 0 ? "" : (left == 1 ? "1 page left" : "\(left) pages left"),
            attributes: [.font: footerFont.withMonospacedDigits(), .foregroundColor: pagination.colors.textDim])
        remaining.textAlignment = .right
        for label in [header, footer, remaining] {
            label.isAccessibilityElement = false
            label.adjustsFontForContentSizeCategory = false
            addSubview(label)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let geometry = pagination.geometry
        let height = pagination.style.chromeFontSize * 1.6
        header.frame = CGRect(x: geometry.contentLeft, y: geometry.headerCenterY - height / 2,
                              width: geometry.contentWidth, height: height)
        footer.frame = CGRect(x: geometry.contentLeft, y: geometry.footerCenterY - height / 2,
                              width: geometry.contentWidth, height: height)
        remaining.frame = footer.frame
    }

    private func origin(of band: ScriptureColumnBand, column: Int) -> CGPoint {
        let geometry = pagination.geometry
        return CGPoint(x: geometry.columnX(column), y: geometry.textTop - band.top)
    }

    override func draw(_ rect: CGRect) {
        let manager = pagination.layoutManager
        let isDark = pagination.style.isDark
        for (column, band) in pagination.bands(onPage: page).enumerated() where band.glyphRange.length > 0 {
            let origin = origin(of: band, column: column)
            for index in pagination.verseRanges.keys.sorted() {
                let highlight = decorations.highlights[index]
                let selected = decorations.selection?.contains(index) == true
                let context = decorations.context?.contains(index) == true
                guard highlight != nil || selected || context else { continue }
                let fill: UIColor? = highlight.map { pagination.colors.highlight($0, isDark: isDark) }
                    ?? (context ? pagination.colors.tint.withAlphaComponent(isDark ? 0.22 : 0.14)
                        : pagination.colors.tint.withAlphaComponent(isDark ? 0.16 : 0.09))
                for line in lineRects(forVerse: index, in: band) {
                    let box = CGRect(x: origin.x + line.minX - 2, y: origin.y + line.baseline - pagination.bodyFont.ascender - 2,
                                     width: line.maxX - line.minX + 4,
                                     height: pagination.bodyFont.ascender - pagination.bodyFont.descender + 5)
                    if let fill {
                        fill.setFill()
                        UIBezierPath(roundedRect: box, cornerRadius: 3).fill()
                    }
                    if selected {
                        pagination.colors.tint.setFill()
                        let thickness: CGFloat = 1.5
                        let y = origin.y + line.baseline + max(2, pagination.bodyFont.pointSize * 0.14)
                        UIRectFill(CGRect(x: origin.x + line.minX, y: y, width: line.maxX - line.minX, height: thickness))
                    }
                }
            }
            manager.drawGlyphs(forGlyphRange: band.glyphRange, at: origin)
        }
    }

    private struct LineRect { let minX: CGFloat; let maxX: CGFloat; let baseline: CGFloat; let top: CGFloat; let bottom: CGFloat }

    /// Line parts of one verse inside one column band, in layout coordinates.
    private func lineRects(forVerse index: Int, in band: ScriptureColumnBand) -> [LineRect] {
        let manager = pagination.layoutManager
        var result: [LineRect] = []
        for range in pagination.verseRanges[index] ?? [] {
            let overlap = NSIntersectionRange(range, band.characterRange)
            guard overlap.length > 0 else { continue }
            let glyphs = manager.glyphRange(forCharacterRange: overlap, actualCharacterRange: nil)
            manager.enumerateLineFragments(forGlyphRange: glyphs) { lineRect, _, container, lineGlyphs, _ in
                var part = NSIntersectionRange(lineGlyphs, glyphs)
                // Leave out a closing line break, so a highlight ends at the last word.
                while part.length > 0 {
                    let character = manager.characterIndexForGlyph(at: NSMaxRange(part) - 1)
                    let unit = (self.pagination.storage.string as NSString).character(at: character)
                    guard unit == 0x0A || unit == 0x20 else { break }
                    part.length -= 1
                }
                guard part.length > 0 else { return }
                let bounds = manager.boundingRect(forGlyphRange: part, in: container)
                var baseline = lineRect.minY + lineRect.height
                // The baseline of a Scripture glyph, not of the raised verse number.
                var glyph = part.location
                while glyph < NSMaxRange(part) {
                    let character = manager.characterIndexForGlyph(at: glyph)
                    if self.pagination.role(atCharacter: character) == .body {
                        baseline = lineRect.minY + manager.location(forGlyphAt: glyph).y
                        break
                    }
                    glyph += 1
                }
                result.append(LineRect(minX: bounds.minX, maxX: bounds.maxX, baseline: baseline,
                                       top: lineRect.minY, bottom: lineRect.maxY))
            }
        }
        return result
    }

    /// The verse under a point on this page, or nil when the point is not on Scripture text.
    func verseIndex(at point: CGPoint, tolerance: CGFloat = 4) -> Int? {
        let geometry = pagination.geometry
        let manager = pagination.layoutManager
        for (column, band) in pagination.bands(onPage: page).enumerated() where band.glyphRange.length > 0 {
            let origin = origin(of: band, column: column)
            let frame = CGRect(x: geometry.columnX(column), y: geometry.textTop,
                               width: geometry.columnWidth, height: band.height)
            guard frame.insetBy(dx: -tolerance, dy: -tolerance).contains(point) else { continue }
            let local = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
            var fraction: CGFloat = 0
            let glyph = manager.glyphIndex(for: local, in: pagination.container, fractionOfDistanceThroughGlyph: &fraction)
            guard NSLocationInRange(glyph, band.glyphRange) else { continue }
            let glyphRect = manager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: pagination.container)
            var lineRect = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            lineRect.size.width = max(lineRect.width, glyphRect.maxX)
            guard lineRect.insetBy(dx: -tolerance, dy: -tolerance).contains(local),
                  glyphRect.minX - tolerance * 4 <= local.x, local.x <= glyphRect.maxX + tolerance * 4 else { continue }
            return pagination.verseIndex(atCharacter: manager.characterIndexForGlyph(at: glyph))
        }
        return nil
    }

    // MARK: Accessibility

    override var accessibilityElements: [Any]? {
        get {
            if let accessibilityCache { return accessibilityCache }
            let built = buildAccessibilityElements()
            accessibilityCache = built
            return built
        }
        set { }
    }

    private func frame(of range: NSRange, band: ScriptureColumnBand, column: Int) -> CGRect {
        let overlap = NSIntersectionRange(range, band.characterRange)
        guard overlap.length > 0 else { return .null }
        let manager = pagination.layoutManager
        let glyphs = manager.glyphRange(forCharacterRange: overlap, actualCharacterRange: nil)
        var union = CGRect.null
        manager.enumerateEnclosingRects(forGlyphRange: glyphs, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                        in: pagination.container) { rect, _ in union = union.union(rect) }
        let origin = origin(of: band, column: column)
        return union.isNull ? .null : union.offsetBy(dx: origin.x, dy: origin.y)
    }

    private func buildAccessibilityElements() -> [UIAccessibilityElement] {
        var ordered: [(Int, UIAccessibilityElement)] = []
        let text = pagination.storage.string as NSString
        let bands = pagination.bands(onPage: page)
        for (column, band) in bands.enumerated() {
            for (label, range) in pagination.titleRanges where NSIntersectionRange(range, band.characterRange).length > 0 {
                let element = UIAccessibilityElement(accessibilityContainer: self)
                element.accessibilityLabel = label
                element.accessibilityTraits = .header
                element.accessibilityIdentifier = label.hasPrefix("Chapter") ? "reader-chapter-heading" : "reader-book-heading"
                element.accessibilityFrameInContainerSpace = frame(of: range, band: band, column: column)
                ordered.append((range.location, element))
            }
            for (kind, range) in pagination.headingRanges where NSIntersectionRange(range, band.characterRange).length > 0 {
                let element = UIAccessibilityElement(accessibilityContainer: self)
                element.accessibilityLabel = text.substring(with: range)
                element.accessibilityTraits = .header
                element.accessibilityIdentifier = "reader-heading-\(kind)"
                element.accessibilityFrameInContainerSpace = frame(of: range, band: band, column: column)
                ordered.append((range.location, element))
            }
        }
        let pageRange = pagination.characterRange(ofPage: page)
        for index in pagination.verses(onPage: page) where pagination.chapter.verses.indices.contains(index) {
            let verse = pagination.chapter.verses[index]
            let bodies = (pagination.verseBodyRanges[index] ?? []).sorted { $0.location < $1.location }
            let visible = bodies.map { NSIntersectionRange($0, pageRange) }.filter { $0.length > 0 }
            let spoken = visible.map { text.substring(with: $0) }.joined()
                .replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
            let startsHere = (pagination.verseRanges[index]?.map(\.location).min() ?? 0) >= pageRange.location
            let element = ScripturePageVerseElement(accessibilityContainer: self)
            element.accessibilityIdentifier = "reader-verse-\(verse.label)"
            element.accessibilityLabel = startsHere ? "Verse \(verse.label). \(spoken)" : "Verse \(verse.label), continued. \(spoken)"
            element.accessibilityTraits = .button
            if decorations.selection?.contains(index) == true { element.accessibilityTraits.insert(.selected) }
            if let color = decorations.highlights[index] { element.accessibilityValue = "\(color.rawValue.capitalized) highlight" }
            var union = CGRect.null
            for (column, band) in bands.enumerated() {
                for range in pagination.verseRanges[index] ?? [] {
                    let rect = frame(of: range, band: band, column: column)
                    if !rect.isNull { union = union.union(rect) }
                }
            }
            element.accessibilityFrameInContainerSpace = union.isNull ? .zero : union
            element.activate = { [weak self] in self?.onActivateVerse?(index); return true }
            ordered.append(((pagination.verseRanges[index]?.map(\.location).min() ?? 0), element))
        }
        return ordered.sorted { $0.0 < $1.0 }.map(\.1)
    }
}

private final class ScripturePageVerseElement: UIAccessibilityElement {
    var activate: (() -> Bool)?
    override func accessibilityActivate() -> Bool { activate?() ?? false }
}

private extension UIFont {
    func withMonospacedDigits() -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .featureSettings: [[UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                                UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector]],
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

// MARK: - Page controller

final class ScripturePageController: UIViewController {
    let id: ScripturePageID
    let pageView: ScripturePageView
    var onAccessibilityScroll: ((Bool) -> Bool)?

    init(id: ScripturePageID, pagination: ScriptureChapterPagination, decorations: ScripturePageDecorations) {
        self.id = id
        pageView = ScripturePageView(pagination: pagination, page: id.page, decorations: decorations)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func loadView() {
        let root = ScripturePageRootView()
        root.onAccessibilityScroll = { [weak self] forward in self?.onAccessibilityScroll?(forward) ?? false }
        root.backgroundColor = pageView.pagination.colors.background
        root.accessibilityIdentifier = "reader-page"
        pageView.frame = root.bounds
        pageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        root.addSubview(pageView)
        view = root
    }
}

/// Answers the VoiceOver three-finger swipe with a page turn.
private final class ScripturePageRootView: UIView {
    var onAccessibilityScroll: ((Bool) -> Bool)?

    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        switch direction {
        case .left, .next: onAccessibilityScroll?(true) ?? false
        case .right, .previous: onAccessibilityScroll?(false) ?? false
        default: false
        }
    }
}

// MARK: - Page book

enum ScripturePageZone: Equatable { case leading, middle, trailing }

struct ScripturePageTap {
    let zone: ScripturePageZone
    let key: ScriptureChapterKey
    let verse: Int?
}

enum ScripturePageTapResult { case none, turn(forward: Bool) }

/// A request to show a page with a page turn, for example when read aloud goes on to the next page.
struct ScripturePageTurnRequest: Equatable {
    let id = UUID()
    let target: ScripturePageID
    let forward: Bool
}

/// A horizontal page book like Apple Books: the page follows the finger, a tap on the left or the right side turns
/// the page, and a turn past the last page of a chapter goes on into the next chapter. It works like the Works
/// reader's page book (`WorkPageBook`).
struct ScripturePageBook: UIViewControllerRepresentable {
    let current: ScripturePageID
    /// Changes when pages are built again or the cached neighbor chapters change.
    let revision: Int
    /// Changes when highlights, the selection, or the context verse change.
    let decorationRevision: Int
    let turnRequest: ScripturePageTurnRequest?
    let background: UIColor
    let pagination: (ScriptureChapterKey) -> ScriptureChapterPagination?
    let neighbor: (ScriptureChapterKey, Bool) -> ScriptureChapterKey?
    let decorations: (ScriptureChapterKey) -> ScripturePageDecorations
    let onTap: (ScripturePageTap) -> ScripturePageTapResult
    let onLongPress: (ScriptureChapterKey, Int) -> Void
    let onActivateVerse: (ScriptureChapterKey, Int) -> Void
    /// A page turn finished. The flag is true when the reader turned the page (finger, tap, or VoiceOver).
    let onSettle: (ScripturePageID, Bool) -> Void
    /// The reader started to drag a page.
    let onDragStart: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal,
                                              options: [.interPageSpacing: 0])
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.view.backgroundColor = background
        controller.view.accessibilityIdentifier = "reader-pages"
        let longPress = UILongPressGestureRecognizer(target: context.coordinator,
                                                     action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.4
        longPress.delegate = context.coordinator
        controller.view.addGestureRecognizer(longPress)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        tap.require(toFail: longPress)
        controller.view.addGestureRecognizer(tap)
        context.coordinator.controller = controller
        context.coordinator.show(current, revision: revision)
        context.coordinator.decorationRevision = decorationRevision
        context.coordinator.lastTurnRequest = turnRequest?.id
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        controller.view.backgroundColor = background
        // A finger is on the page. didFinishAnimating catches up afterwards.
        guard !coordinator.isTransitioning else { return }
        if let turnRequest, coordinator.lastTurnRequest != turnRequest.id {
            coordinator.lastTurnRequest = turnRequest.id
            if coordinator.revision == revision, coordinator.displayed != turnRequest.target {
                coordinator.turn(to: turnRequest.target, forward: turnRequest.forward, byUser: false)
                return
            }
        }
        if coordinator.displayed != current || coordinator.revision != revision {
            coordinator.show(current, revision: revision)
        } else if coordinator.decorationRevision != decorationRevision {
            coordinator.decorationRevision = decorationRevision
            coordinator.refreshDecorations()
        }
    }

    @MainActor final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate,
                                        UIGestureRecognizerDelegate {
        var parent: ScripturePageBook
        weak var controller: UIPageViewController?
        var displayed: ScripturePageID?
        var revision = -1
        var decorationRevision = -1
        var lastTurnRequest: UUID?
        var isTransitioning = false
        private let pages = NSHashTable<ScripturePageController>.weakObjects()

        init(parent: ScripturePageBook) { self.parent = parent }

        func show(_ id: ScripturePageID, revision: Int) {
            guard let controller, let page = makePage(id) else { return }
            self.revision = revision
            decorationRevision = parent.decorationRevision
            displayed = id
            controller.setViewControllers([page], direction: .forward, animated: false)
            updateAccessibilityVisibility()
        }

        func refreshDecorations() {
            for page in pages.allObjects {
                page.pageView.decorations = parent.decorations(page.id.key)
            }
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }

        func neighbor(of id: ScripturePageID, forward: Bool) -> ScripturePageID? {
            guard let pagination = parent.pagination(id.key) else { return nil }
            if forward {
                if id.page + 1 < pagination.pageCount { return ScripturePageID(key: id.key, page: id.page + 1) }
                if let next = parent.neighbor(id.key, true), parent.pagination(next) != nil {
                    return ScripturePageID(key: next, page: 0)
                }
            } else {
                if id.page > 0 { return ScripturePageID(key: id.key, page: id.page - 1) }
                if let previous = parent.neighbor(id.key, false), let other = parent.pagination(previous) {
                    return ScripturePageID(key: previous, page: other.pageCount - 1)
                }
            }
            return nil
        }

        private func makePage(_ id: ScripturePageID) -> ScripturePageController? {
            guard let pagination = parent.pagination(id.key), id.page >= 0, id.page < pagination.pageCount else { return nil }
            let page = ScripturePageController(id: id, pagination: pagination, decorations: parent.decorations(id.key))
            page.onAccessibilityScroll = { [weak self] forward in self?.turn(forward: forward, byUser: true) ?? false }
            page.pageView.onActivateVerse = { [weak self] index in self?.parent.onActivateVerse(id.key, index) }
            pages.add(page)
            return page
        }

        /// Only the page on screen is visible to VoiceOver. The page view controller keeps its neighbors loaded.
        private func updateAccessibilityVisibility() {
            for page in pages.allObjects {
                page.view.accessibilityElementsHidden = page.id != displayed
            }
        }

        /// Turns one page for a tap or a VoiceOver three-finger swipe.
        @discardableResult func turn(forward: Bool, byUser: Bool) -> Bool {
            guard !isTransitioning, let displayed, let target = neighbor(of: displayed, forward: forward) else { return false }
            return turn(to: target, forward: forward, byUser: byUser)
        }

        @discardableResult func turn(to target: ScripturePageID, forward: Bool, byUser: Bool) -> Bool {
            guard let controller, !isTransitioning, let page = makePage(target) else { return false }
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
                self.finish(at: target, byUser: byUser)
            }
            return true
        }

        private func finish(at id: ScripturePageID, byUser: Bool) {
            isTransitioning = false
            displayed = id
            updateAccessibilityVisibility()
            parent.onSettle(id, byUser)
            if let pagination = parent.pagination(id.key) {
                UIAccessibility.post(notification: .pageScrolled,
                                     argument: "\(pagination.title), page \(id.page + 1) of \(pagination.pageCount)")
            }
        }

        // MARK: Data source

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let page = viewController as? ScripturePageController,
                  let target = neighbor(of: page.id, forward: false) else { return nil }
            return makePage(target)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let page = viewController as? ScripturePageController,
                  let target = neighbor(of: page.id, forward: true) else { return nil }
            return makePage(target)
        }

        // MARK: Delegate

        func pageViewController(_ pageViewController: UIPageViewController,
                                willTransitionTo pendingViewControllers: [UIViewController]) {
            isTransitioning = true
            parent.onDragStart()
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed, let page = pageViewController.viewControllers?.first as? ScripturePageController {
                finish(at: page.id, byUser: true)
                return
            }
            isTransitioning = false
            // The turn was cancelled. Apply any update that arrived during the drag.
            if displayed != parent.current || revision != parent.revision {
                show(parent.current, revision: parent.revision)
            } else if decorationRevision != parent.decorationRevision {
                decorationRevision = parent.decorationRevision
                refreshDecorations()
            }
        }

        // MARK: Taps

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            !(other is UILongPressGestureRecognizer && gestureRecognizer is UITapGestureRecognizer)
        }

        private func currentPage() -> ScripturePageController? {
            controller?.viewControllers?.first as? ScripturePageController
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let view = recognizer.view, !isTransitioning,
                  let page = currentPage() else { return }
            let location = recognizer.location(in: view)
            let width = view.bounds.width
            let zone: ScripturePageZone = location.x < width * 0.3 ? .leading : (location.x > width * 0.7 ? .trailing : .middle)
            let verse = page.pageView.verseIndex(at: recognizer.location(in: page.pageView))
            switch parent.onTap(ScripturePageTap(zone: zone, key: page.id.key, verse: verse)) {
            case .none: break
            case let .turn(forward): turn(forward: forward, byUser: true)
            }
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began, !isTransitioning, let page = currentPage(),
                  let verse = page.pageView.verseIndex(at: recognizer.location(in: page.pageView), tolerance: 8) else { return }
            parent.onLongPress(page.id.key, verse)
        }
    }
}
