import { useSyncExternalStore } from "react"

import { subscribeToReadingPreferences } from "./readingPreferences"

/**
 * A text or layout preference that stays current wherever it is shown: the
 * reader, its text sheet and Settings all update as soon as any one changes it.
 */
export function useReadingPreference<T>(read: () => T): T {
  return useSyncExternalStore(subscribeToReadingPreferences, read)
}
