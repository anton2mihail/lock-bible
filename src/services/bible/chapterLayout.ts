/**
 * Turns a chapter's structure (see `Verse.br` and `Verse.hd`) into what the
 * reader draws: flowing paragraphs and poetry lines, or one verse per line.
 * Pure, so the rules are testable without rendering anything.
 */

import type { Chapter, VerseBreakKind, VerseHeadingKind } from "./types"

/** A block's kind: every break kind except the stanza mark, which only adds space. */
export type TextBlockKind = Exclude<VerseBreakKind, "b">

/** Poetry lines and list items, which follow each other without paragraph space. */
export const LINE_KINDS: ReadonlySet<TextBlockKind> = new Set(["q1", "q2", "q3", "li"])

/** Part of one verse inside a block. */
export interface LayoutSegment {
  verseIndex: number
  /** Set where the verse begins, so its number is printed there. */
  label?: string
  text: string
}

export type ChapterBlock =
  | { type: "heading"; kind: VerseHeadingKind; text: string; verseIndex: number }
  | { type: "text"; kind: TextBlockKind; stanzaBreak: boolean; segments: LayoutSegment[] }

export type TextBlock = Extract<ChapterBlock, { type: "text" }>

/** One line of a verse set on its own: some of its words, or a heading inside it. */
export type VerseLine =
  | { type: "text"; kind: TextBlockKind; text: string; stanzaBreak: boolean }
  | { type: "heading"; kind: VerseHeadingKind; text: string }

export interface VerseLayout {
  /** Headings printed before the verse. */
  headings: [VerseHeadingKind, string][]
  /** The verse opens a paragraph, stanza or list, so verse-by-verse view sets it apart. */
  startsBlock: boolean
  /** The verse's own lines; more than one where poetry, a list or a heading breaks it. */
  lines: VerseLine[]
}

export interface ChapterLayout {
  /** Whether the edition marks paragraphs here, rather than setting each verse apart. */
  structured: boolean
  /** The chapter as paragraphs, poetry lines and headings. */
  blocks: ChapterBlock[]
  /** The same chapter verse by verse, index-aligned with `chapter.verses`. */
  verses: VerseLayout[]
}

interface BlockStart {
  offset: number
  kind?: TextBlockKind
  stanzaBreak: boolean
}

/** Something that happens at a point in a verse's text. */
type VerseEvent =
  | { offset: number; heading: [VerseHeadingKind, string] }
  | { offset: number; start: BlockStart }

/** One start per offset: the last block kind opened there, and whether a stanza break precedes it. */
function groupBreaks(breaks: [number, VerseBreakKind][]): BlockStart[] {
  const starts: BlockStart[] = []
  for (const [offset, kind] of breaks) {
    let start = starts[starts.length - 1]
    if (!start || start.offset !== offset) {
      start = { offset, stanzaBreak: false }
      starts.push(start)
    }
    if (kind === "b") start.stanzaBreak = true
    else start.kind = kind
  }
  return starts
}

export function layoutChapter(chapter: Chapter): ChapterLayout {
  // Editions without paragraphing set every verse as its own paragraph.
  const structured = chapter.verses.some((verse) => verse.br?.length)
  const blocks: ChapterBlock[] = []
  const verses: VerseLayout[] = []
  let current: TextBlock | undefined
  // The latest block's kind, which text resumes after a heading.
  let lastKind: TextBlockKind = "p"

  const openBlock = (kind: TextBlockKind, stanzaBreak: boolean): TextBlock => {
    current = { type: "text", kind, stanzaBreak, segments: [] }
    blocks.push(current)
    lastKind = kind
    return current
  }

  chapter.verses.forEach((verse, verseIndex) => {
    const headings: [VerseHeadingKind, string][] = []
    const events: VerseEvent[] = []
    for (const [kind, text, offset] of verse.hd ?? []) {
      if (offset) events.push({ offset, heading: [kind, text] })
      else headings.push([kind, text])
    }
    for (const [kind, text] of headings) {
      blocks.push({ type: "heading", kind, text, verseIndex })
      current = undefined
    }

    const starts: BlockStart[] = structured
      ? groupBreaks(verse.br ?? [])
      : [{ offset: 0, kind: "p", stanzaBreak: false }]
    events.push(...starts.map((start) => ({ offset: start.offset, start })))
    // A heading comes before the block that begins where it stands.
    const rank = (event: VerseEvent) => ("heading" in event ? 0 : 1)
    events.sort((a, b) => a.offset - b.offset || rank(a) - rank(b))

    const lines: VerseLine[] = []
    let label: string | undefined = verse.n

    const place = (block: TextBlock, text: string) => {
      if (!text) return
      block.segments.push({ verseIndex, label, text })
      // Only the block's first line follows the stanza break.
      const stanzaBreak = block.stanzaBreak && block.segments.length === 1
      lines.push({ type: "text", kind: block.kind, text, stanzaBreak })
      label = undefined
    }

    // Text before the verse's first break or heading continues the block in progress.
    const firstOffset = events[0]?.offset ?? verse.t.length
    if (firstOffset > 0) {
      place(current ?? openBlock(lastKind, false), verse.t.slice(0, firstOffset).trim())
    }
    events.forEach((event, index) => {
      const end = events[index + 1]?.offset ?? verse.t.length
      const text = verse.t.slice(event.offset, end).trim()
      if ("heading" in event) {
        const [kind, headingText] = event.heading
        blocks.push({ type: "heading", kind, text: headingText, verseIndex })
        lines.push({ type: "heading", kind, text: headingText })
        current = undefined
        // Words after it with no block of their own resume the kind in progress.
        if (text) place(openBlock(lastKind, false), text)
        return
      }
      // A stanza mark with no kind of its own resumes the kind in progress.
      const kind = event.start.kind ?? current?.kind ?? lastKind
      place(openBlock(kind, event.start.stanzaBreak), text)
    })

    verses.push({ headings, startsBlock: starts[0]?.offset === 0, lines })
  })

  return {
    structured,
    blocks: blocks.filter((block) => block.type === "heading" || block.segments.length > 0),
    verses,
  }
}
