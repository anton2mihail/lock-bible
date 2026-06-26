/**
 * Deterministic verse-of-the-day selection.
 *
 * The whole widget design hinges on this being a pure function of the date:
 * the JS app and the native Swift widget compute the SAME index from the SAME
 * clock, so the lock screen and the app always agree — with zero background
 * work, network, or shared mutable state. The Swift `TimelineProvider` mirrors
 * this exact arithmetic (see targets/widget/VerseWidget.swift).
 *
 * Algorithm: count whole rotation "slots" since the Unix epoch in the device's
 * LOCAL time, then index into the verse pool modulo its length. Cadence is
 * measured in MINUTES so sub-hour rotation (10/15/30 min) is supported.
 */

import type { BookGroup, WidgetVerse } from "./types"

/** Supported rotation cadences, in minutes. 1440 = once daily, 10 = every 10 min. */
export const ROTATION_INTERVALS = [10, 15, 30, 60, 180, 360, 720, 1440] as const
export type RotationInterval = (typeof ROTATION_INTERVALS)[number]

export const DEFAULT_ROTATION_INTERVAL: RotationInterval = 1440

/** Which slice of Scripture the rotating pool draws from. */
export const VERSE_SCOPES = ["full", "ot", "nt"] as const
export type VerseScope = (typeof VERSE_SCOPES)[number]

export const DEFAULT_VERSE_SCOPE: VerseScope = "full"

const MINUTE_MS = 60_000

/** Whole minutes since the epoch in the device's local timezone. */
function localMinutesSinceEpoch(date: Date): number {
  const localMs = date.getTime() - date.getTimezoneOffset() * MINUTE_MS
  return Math.floor(localMs / MINUTE_MS)
}

/** The rotation slot number for a given date and cadence (in minutes). */
export function rotationSlot(date: Date, intervalMinutes: number): number {
  return Math.floor(localMinutesSinceEpoch(date) / intervalMinutes)
}

/**
 * Index into a verse pool of `count` entries for the given date/cadence.
 * Always returns a value in [0, count). Mirrors the Swift implementation.
 */
export function verseIndexForDate(date: Date, count: number, intervalMinutes: number): number {
  if (count <= 0) return 0
  const slot = rotationSlot(date, intervalMinutes)
  return ((slot % count) + count) % count
}

/** The moment the verse will next change, given the current date and cadence. */
export function nextRotationDate(date: Date, intervalMinutes: number): Date {
  const nextSlot = rotationSlot(date, intervalMinutes) + 1
  const localMs = nextSlot * intervalMinutes * MINUTE_MS
  // Convert the local boundary back to an absolute instant.
  return new Date(localMs + date.getTimezoneOffset() * MINUTE_MS)
}

/** Whether a book group belongs to the selected scope. OT includes deuterocanon. */
export function scopeMatches(group: BookGroup, scope: VerseScope): boolean {
  if (scope === "nt") return group === "nt"
  if (scope === "ot") return group === "ot" || group === "deutero"
  return true
}

/** Filter a verse pool to the selected scope, preserving order. */
export function filterByScope(verses: WidgetVerse[], scope: VerseScope): WidgetVerse[] {
  if (scope === "full") return verses
  return verses.filter((v) => scopeMatches(v.group, scope))
}

/** Pick the current verse from a pool for the given date/cadence. */
export function selectVerse(
  verses: WidgetVerse[],
  date: Date,
  intervalMinutes: number,
): WidgetVerse | undefined {
  if (!verses.length) return undefined
  return verses[verseIndexForDate(date, verses.length, intervalMinutes)]
}

/** A shareable string for a verse, including its reference and translation. */
export function formatVerseForShare(verse: WidgetVerse, abbreviation: string): string {
  return `“${verse.text}”\n— ${verse.ref} (${abbreviation})`
}
