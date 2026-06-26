/**
 * Shared types for the Bible text layer.
 *
 * The shape here is translation-agnostic on purpose: every translation (the
 * bundled public-domain WEB-CE today, a licensed NRSVCE tomorrow) is emitted
 * by scripts/build-bible-data.mjs into this exact shape, so swapping or adding
 * a translation never touches app code — see translations.ts.
 */

export type BookGroup = "ot" | "deutero" | "nt"

export interface Verse {
  /** Verse label as printed — usually "1", occasionally a bridge like "1-2". */
  n: string
  /** Verse text. */
  t: string
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
