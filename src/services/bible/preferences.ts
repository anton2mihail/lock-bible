/**
 * User preferences for the Bible experience, persisted via the app's MMKV
 * storage (src/utils/storage). Kept tiny and synchronous so screens and the
 * widget bridge can read them without async ceremony.
 */

import { load, save } from "@/utils/storage"

import { DEFAULT_TRANSLATION_ID, TRANSLATIONS } from "./translations"
import {
  DEFAULT_ROTATION_INTERVAL,
  DEFAULT_VERSE_SCOPE,
  ROTATION_INTERVALS,
  VERSE_SCOPES,
  type RotationInterval,
  type VerseScope,
} from "./verseOfDay"

const KEYS = {
  translationId: "bible.translationId",
  rotationInterval: "bible.rotationInterval",
  verseScope: "bible.verseScope",
} as const

export function getTranslationId(): string {
  const id = load<string>(KEYS.translationId)
  return id && TRANSLATIONS[id] ? id : DEFAULT_TRANSLATION_ID
}

export function setTranslationId(id: string): void {
  save(KEYS.translationId, id)
}

export function getRotationInterval(): RotationInterval {
  const value = load<number>(KEYS.rotationInterval)
  return value && (ROTATION_INTERVALS as readonly number[]).includes(value)
    ? (value as RotationInterval)
    : DEFAULT_ROTATION_INTERVAL
}

export function setRotationInterval(interval: RotationInterval): void {
  save(KEYS.rotationInterval, interval)
}

export function getVerseScope(): VerseScope {
  const value = load<string>(KEYS.verseScope)
  return value && (VERSE_SCOPES as readonly string[]).includes(value)
    ? (value as VerseScope)
    : DEFAULT_VERSE_SCOPE
}

export function setVerseScope(scope: VerseScope): void {
  save(KEYS.verseScope, scope)
}
