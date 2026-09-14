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
 * LOCAL time, then map the slot through a deterministic permutation of the
 * verse pool. Cadence is measured in MINUTES so sub-hour rotation (10/15/30
 * min) is supported. The permutation visits every verse exactly once before
 * repeating, without keeping shuffle state that the app and widget could lose.
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

// These constants are mirrored in VerseWidget.swift. The stride is adjusted
// upward when necessary until it is coprime with the active pool size; that
// makes `(slot * stride + offset) mod count` a full-cycle permutation.
const SHUFFLE_STRIDE = 104_729
const SHUFFLE_OFFSET = 1_729

function greatestCommonDivisor(a: number, b: number): number {
  let x = Math.abs(a)
  let y = Math.abs(b)
  while (y !== 0) {
    const remainder = x % y
    x = y
    y = remainder
  }
  return x
}

function permutationStride(count: number): number {
  let stride = SHUFFLE_STRIDE
  while (greatestCommonDivisor(stride, count) !== 1) stride += 2
  return stride
}

/** Whole minutes since the epoch in the device's local timezone. */
function localMinutesSinceEpoch(date: Date): number {
  const localMs = date.getTime() - date.getTimezoneOffset() * MINUTE_MS
  return Math.floor(localMs / MINUTE_MS)
}

/** The rotation slot number for a given date and cadence (in minutes). */
export function rotationSlot(date: Date, intervalMinutes: number): number {
  return Math.floor(localMinutesSinceEpoch(date) / intervalMinutes)
}

/** Map a rotation slot into a full-cycle shuffled pool. Mirrors the Swift implementation. */
export function verseIndexForSlot(slot: number, count: number): number {
  if (count <= 0) return 0
  const stride = permutationStride(count)
  const index = (slot * stride + SHUFFLE_OFFSET) % count
  return (index + count) % count
}

/** Index into a shuffled verse pool for the given date/cadence. */
export function verseIndexForDate(date: Date, count: number, intervalMinutes: number): number {
  return verseIndexForSlot(rotationSlot(date, intervalMinutes), count)
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
