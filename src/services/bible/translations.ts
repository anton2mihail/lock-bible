/**
 * Translation registry — the single seam where new Bible editions plug in.
 *
 * To add a licensed translation (e.g. NRSVCE) later:
 *   1. Run the data pipeline for it (emit data/<id>/ + a widgetVerses payload).
 *   2. Add a `Translation` entry here.
 * No screen, widget, or service code needs to change.
 */

import widgetPayload from "@assets/bible/widgetVerses.json"

import { bookLoaders } from "./data/web-ce"
import webCeManifest from "./data/web-ce/manifest.json"
import webCeMeta from "./data/web-ce/meta.json"
import type { BookData, BookMeta, Translation, TranslationMeta, WidgetVersePayload } from "./types"

const webCe: Translation = {
  meta: webCeMeta as TranslationMeta,
  manifest: webCeManifest as BookMeta[],
  widgetVerses: (widgetPayload as WidgetVersePayload).verses,
  loadBook: (code: string): BookData => {
    const loader = bookLoaders[code]
    if (!loader) throw new Error(`Unknown book code: ${code}`)
    return loader()
  },
}

export const TRANSLATIONS: Record<string, Translation> = {
  [webCe.meta.id]: webCe,
}

/** The translation used when the user has not chosen one (or chose an unknown id). */
export const DEFAULT_TRANSLATION_ID = webCe.meta.id

export function getTranslation(id: string | null | undefined): Translation {
  return (id && TRANSLATIONS[id]) || TRANSLATIONS[DEFAULT_TRANSLATION_ID]
}

export function listTranslations(): TranslationMeta[] {
  return Object.values(TRANSLATIONS).map((t) => t.meta)
}
