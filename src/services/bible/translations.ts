/**
 * Translation registry — the single seam where new Bible editions plug in.
 *
 * To add a licensed translation (e.g. NRSVCE) later:
 *   1. Run the data pipeline for it (emit data/<id>/ + a widgetVerses payload).
 *   2. Add a `Translation` entry here.
 * No screen, widget, or service code needs to change.
 */

import { bookLoaders as douayRheimsBookLoaders } from "./data/douay-rheims"
import douayRheimsManifest from "./data/douay-rheims/manifest.json"
import douayRheimsMeta from "./data/douay-rheims/meta.json"
import douayRheimsWidgetPayload from "./data/douay-rheims/widgetVerses.json"
import { bookLoaders as vulgateBookLoaders } from "./data/vulgate"
import vulgateManifest from "./data/vulgate/manifest.json"
import vulgateMeta from "./data/vulgate/meta.json"
import vulgateWidgetPayload from "./data/vulgate/widgetVerses.json"
import { bookLoaders as webCeBookLoaders } from "./data/web-ce"
import webCeManifest from "./data/web-ce/manifest.json"
import webCeMeta from "./data/web-ce/meta.json"
import webCeWidgetPayload from "./data/web-ce/widgetVerses.json"
import type { BookData, BookMeta, Translation, TranslationMeta, WidgetVersePayload } from "./types"

const webCe: Translation = {
  meta: webCeMeta as TranslationMeta,
  manifest: webCeManifest as BookMeta[],
  widgetVerses: (webCeWidgetPayload as WidgetVersePayload).verses,
  loadBook: (code: string): BookData => {
    const loader = webCeBookLoaders[code]
    if (!loader) throw new Error(`Unknown book code: ${code}`)
    return loader()
  },
}

function createTranslation(
  meta: TranslationMeta,
  manifest: BookMeta[],
  widgetPayload: WidgetVersePayload,
  bookLoaders: Record<string, () => BookData>,
): Translation {
  return {
    meta,
    manifest,
    widgetVerses: widgetPayload.verses,
    loadBook: (code: string): BookData => {
      const loader = bookLoaders[code]
      if (!loader) throw new Error(`Unknown book code: ${code}`)
      return loader()
    },
  }
}

const douayRheims = createTranslation(
  douayRheimsMeta as TranslationMeta,
  douayRheimsManifest as BookMeta[],
  douayRheimsWidgetPayload as WidgetVersePayload,
  douayRheimsBookLoaders,
)

const vulgate = createTranslation(
  vulgateMeta as TranslationMeta,
  vulgateManifest as BookMeta[],
  vulgateWidgetPayload as WidgetVersePayload,
  vulgateBookLoaders,
)

export const TRANSLATIONS: Record<string, Translation> = {
  [webCe.meta.id]: webCe,
  [douayRheims.meta.id]: douayRheims,
  [vulgate.meta.id]: vulgate,
}

/** The translation used when the user has not chosen one (or chose an unknown id). */
export const DEFAULT_TRANSLATION_ID = webCe.meta.id

export function getTranslation(id: string | null | undefined): Translation {
  return (id && TRANSLATIONS[id]) || TRANSLATIONS[DEFAULT_TRANSLATION_ID]
}

export function listTranslations(): TranslationMeta[] {
  return Object.values(TRANSLATIONS).map((t) => t.meta)
}
