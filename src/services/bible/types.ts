/**
 * Shared types for the Bible text layer.
 *
 * The shape here is translation-agnostic on purpose: every translation (the
 * bundled public-domain WEB-CE today, a licensed NRSVCE tomorrow) is emitted
 * by scripts/build-bible-data.mjs into this exact shape, so swapping or adding
 * a translation never touches app code — see translations.ts.
 */

export type BookGroup = "ot" | "deutero" | "nt"

/**
 * A block of text beginning inside or at the start of a verse: prose paragraphs
 * (p, m flush, pi/mi indented, pc centered), list items (li), poetry lines by
 * indent level (q1-q3), and a stanza break before the next block (b).
 */
export type VerseBreakKind = "p" | "m" | "pi" | "mi" | "pc" | "li" | "q1" | "q2" | "q3" | "b"

/**
 * A heading printed with a verse: a Psalm title (d), a section heading (s), a
 * major section such as "BOOK 1" (ms), or a speaker in the Song of Songs (sp).
 */
export type VerseHeadingKind = "d" | "s" | "ms" | "sp"

/**
 * [kind, text] before the verse, or [kind, text, offset into `t`] where the
 * heading falls inside it. Its words are not part of the verse text.
 */
export type VerseHeading = [VerseHeadingKind, string] | [VerseHeadingKind, string, number]

export interface Verse {
  /** Verse label as printed — usually "1", occasionally a bridge like "1-2". */
  n: string
  /** Verse text. */
  t: string
  /**
   * Where blocks begin: [character offset into `t`, kind], in order. Only
   * editions with real paragraphing carry this; without it every verse is
   * set on its own line.
   */
  br?: [number, VerseBreakKind][]
  /** Headings printed with this verse, in order. */
  hd?: VerseHeading[]
}

export interface Chapter {
  /** Chapter number. */
  c: number
  verses: Verse[]
}

export interface BookData {
  code: string
  name: string
  longName: string
  group: BookGroup
  chapters: Chapter[]
}

/** Lightweight book descriptor loaded up front for navigation (no verse text). */
export interface BookMeta {
  code: string
  name: string
  longName: string
  group: BookGroup
  order: number
  chapterCount: number
}

export interface TranslationMeta {
  id: string
  name: string
  fullName: string
  abbreviation: string
  language: string
  isPublicDomain: boolean
  /** Attribution line surfaced in-app (required text for licensed editions). */
  attribution: string
  copyrightNotice: string
}

/** A single rotating verse for the verse-of-the-day / widget pool. */
export interface WidgetVerse {
  ref: string
  book: string
  chapter: number
  verse: string
  text: string
  /** Testament group, used to filter the pool to OT-only / NT-only. */
  group: BookGroup
}

export interface WidgetVersePayload {
  translationId: string
  translationName: string
  abbreviation: string
  attribution: string
  verses: WidgetVerse[]
}

/**
 * A registered translation. `loadBook` is synchronous but lazy: the underlying
 * per-book JSON is only parsed by Metro's require cache when first opened.
 */
export interface Translation {
  meta: TranslationMeta
  manifest: BookMeta[]
  widgetVerses: WidgetVerse[]
  loadBook: (code: string) => BookData
}
