/**
 * Bridge between the JS app and the native iOS WidgetKit extension.
 *
 * The widget is self-sufficient: it bundles its own copy of the verse pool and
 * defaults to daily rotation, so it renders correctly even before the app has
 * ever been opened. This bridge simply pushes the user's current preferences
 * (and, optionally, an updated verse pool) into the shared App Group container
 * and asks WidgetKit to reload — keeping the lock screen in sync with the app.
 *
 * It degrades to a no-op on Android/web and whenever the native module isn't
 * present (e.g. running in Expo Go or before the widget target is prebuilt), so
 * it is always safe to call.
 */

import { Platform } from "react-native"

import {
  getActiveTranslationMeta,
  getRotationInterval,
  getVerseScope,
  getWidgetVerses,
} from "@/services/bible"

/** Must match the App Group declared in app.config.ts and the widget target. */
export const APP_GROUP = "group.com.nrsv.verse"
/** Widget `kind` strings — must match the SwiftUI widgets in VerseWidget.swift. */
export const WIDGET_KIND = "VerseWidget"
export const TIMER_WIDGET_KIND = "VerseTimerWidget"

export const SHARED_KEYS = {
  intervalMinutes: "intervalMinutes",
  scope: "scope",
  abbreviation: "abbreviation",
  attribution: "attribution",
  verses: "verses",
} as const

type ExtensionStorageInstance = {
  set: (key: string, value: unknown) => void
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
    storage.set(SHARED_KEYS.intervalMinutes, getRotationInterval())
    storage.set(SHARED_KEYS.scope, getVerseScope())
    storage.set(SHARED_KEYS.abbreviation, meta.abbreviation)
    storage.set(SHARED_KEYS.attribution, meta.attribution)
    // Ship the verse pool too, so an OTA update to the curated list reaches the
    // widget without a native rebuild. The widget filters this by scope itself,
    // and falls back to its bundled copy when this key is absent. `group` is
    // included so the widget can apply OT-only / NT-only filtering.
    storage.set(
      SHARED_KEYS.verses,
      JSON.stringify(getWidgetVerses().map(({ ref, text, group }) => ({ ref, text, group }))),
    )
    // No kind → reload every widget (the verse widget and the countdown widget).
    mod.ExtensionStorage.reloadWidget?.()
  } catch {
    // Never let widget syncing break the app.
  }
}
