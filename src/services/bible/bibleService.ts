/**
 * Facade over the active translation: book navigation, chapter/verse access,
 * and the current verse-of-the-day. Loaded books are memoized so re-opening a
 * book or flipping chapters doesn't re-parse JSON.
 */

import { getRotationInterval, getTranslationId, getVerseScope } from "./preferences"
import { getTranslation } from "./translations"
import type {
  BookData,
  BookMeta,
  Chapter,
  Translation,
  TranslationMeta,
  WidgetVerse,
} from "./types"
import { filterByScope, selectVerse } from "./verseOfDay"

const bookCache = new Map<string, BookData>()

function active(): Translation {
  return getTranslation(getTranslationId())
}

export function getActiveTranslationMeta(): TranslationMeta {
  return active().meta
}

/**
 * Screens that stay mounted (the Read tab) pass the translation they are
 * showing, so a change made in Settings reaches them as a dependency.
 */
export function listBooks(translationId: string = getTranslationId()): BookMeta[] {
  return getTranslation(translationId).manifest
}

export function getBook(code: string, translationId: string = getTranslationId()): BookData {
  const translation = getTranslation(translationId)
  const cacheKey = `${translation.meta.id}:${code}`
  const cached = bookCache.get(cacheKey)
  if (cached) return cached
  const book = translation.loadBook(code)
  bookCache.set(cacheKey, book)
  return book
}

export function getChapter(code: string, chapter: number): Chapter | undefined {
  return getBook(code).chapters.find((c) => c.c === chapter)
}

export function getWidgetVerses(): WidgetVerse[] {
  return active().widgetVerses
}

/** The verse pool after applying the user's testament scope (never empty). */
export function getScopedVerses(): WidgetVerse[] {
  const all = getWidgetVerses()
  const scoped = filterByScope(all, getVerseScope())
  return scoped.length ? scoped : all
}

/** The verse currently shown on the lock screen, for the device's clock. */
export function getCurrentVerse(now: Date = new Date()): WidgetVerse | undefined {
  return selectVerse(getScopedVerses(), now, getRotationInterval())
}
