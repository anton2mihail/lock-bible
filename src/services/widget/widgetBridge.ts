/**
 * Bridge between the JS app and the native iOS WidgetKit extension.
 *
 * The widget is self-sufficient: it bundles its own copy of the verse pool and
 * defaults to daily rotation, so it renders correctly even before the app has
 * ever been opened. This bridge simply pushes the user's current preferences
 * into the shared App Group container and asks WidgetKit to reload — keeping
 * the lock screen in sync with the app.
 *
 * It degrades to a no-op on Android/web and whenever the native module isn't
 * present (e.g. running in Expo Go or before the widget target is prebuilt), so
 * it is always safe to call.
 */

import { Platform } from "react-native"

import { getActiveTranslationMeta, getRotationInterval, getVerseScope } from "@/services/bible"

/** Must match the App Group declared in app.config.ts and the widget target. */
export const APP_GROUP = "group.com.nrsv.verse"
/** Widget `kind` strings — must match the SwiftUI widgets in VerseWidget.swift. */
export const WIDGET_KIND = "VerseWidget"
export const TIMER_WIDGET_KIND = "VerseTimerWidget"

export const SHARED_KEYS = {
  schemaVersion: "widgetSchemaVersion",
  intervalMinutes: "intervalMinutes",
  scope: "scope",
  translationId: "translationId",
  abbreviation: "abbreviation",
  attribution: "attribution",
  verses: "verses",
} as const

type ExtensionStorageInstance = {
  set: (key: string, value: unknown) => void
  get: (key: string) => string | null
  remove: (key: string) => void
}

type AppleTargetsModule = {
  ExtensionStorage: {
    new (groupId: string): ExtensionStorageInstance
    reloadWidget?: (kind?: string) => void
  }
}

function getModule(): AppleTargetsModule | null {
  if (Platform.OS !== "ios") return null
  try {
    // Lazy require so the bundle works before the native target is installed.
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    return require("@bacons/apple-targets") as AppleTargetsModule
  } catch {
    return null
  }
}

/**
 * Push current preferences + verse pool to the widget and reload it.
 * Call after any change that affects what the widget should display.
 */
export function syncWidget(): void {
  const mod = getModule()
  if (!mod) return
  try {
    const storage = new mod.ExtensionStorage(APP_GROUP)
    const meta = getActiveTranslationMeta()
    const desired = {
      [SHARED_KEYS.schemaVersion]: "2",
      [SHARED_KEYS.intervalMinutes]: String(getRotationInterval()),
      [SHARED_KEYS.scope]: getVerseScope(),
      [SHARED_KEYS.translationId]: meta.id,
      [SHARED_KEYS.abbreviation]: meta.abbreviation,
      [SHARED_KEYS.attribution]: meta.attribution,
    }
    const changed = Object.entries(desired).some(([key, value]) => storage.get(key) !== value)

    // Build 3 stored a curated pool in the shared container. The indexed widget
    // corpus supersedes it, so clean it up once during the schema migration.
    if (storage.get(SHARED_KEYS.schemaVersion) !== desired[SHARED_KEYS.schemaVersion]) {
      storage.remove(SHARED_KEYS.verses)
    }

    if (!changed) return
    storage.set(SHARED_KEYS.schemaVersion, desired[SHARED_KEYS.schemaVersion])
    storage.set(SHARED_KEYS.intervalMinutes, getRotationInterval())
    storage.set(SHARED_KEYS.scope, desired[SHARED_KEYS.scope])
    storage.set(SHARED_KEYS.translationId, desired[SHARED_KEYS.translationId])
    storage.set(SHARED_KEYS.abbreviation, desired[SHARED_KEYS.abbreviation])
    storage.set(SHARED_KEYS.attribution, desired[SHARED_KEYS.attribution])
    // Preferences changed, so refresh both the verse and countdown timelines.
    mod.ExtensionStorage.reloadWidget?.()
  } catch {
    // Never let widget syncing break the app.
  }
}
