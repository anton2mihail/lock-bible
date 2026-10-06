// Step 7 widget expectations from the OLD source functions.
//
// Usage (run with the same time zone as the simulator, for example America/Toronto):
//   TZ=America/Toronto bun scripts/native/source-fixtures/step7/widget-expected.ts \
//     <ISO instant> <IANA zone> <edition> <scope> <intervalMinutes>
//
// It sets the old preference keys in a memory stub and calls getCurrentVerse (src/services/bible/bibleService.ts:63),
// nextRotationDate (src/services/bible/verseOfDay.ts:78), and the widget daily file (targets/widget/daily-readings-YYYY.json).
// It prints JSON. It reads no simulator, container, or app file. The output is a source expectation.
Bun.plugin({
  setup(build) {
    const store = new Map<string, string>()
    ;(globalThis as Record<string, unknown>).__step7Store = store
    build.module("react-native-mmkv", () => ({
      exports: {
        MMKV: class {
          getString(key: string) { return store.get(key) }
          set(key: string, value: string) { store.set(key, value) }
          delete(key: string) { store.delete(key) }
          clearAll() { store.clear() }
        },
      },
      loader: "object",
    }))
  },
})
import { readFileSync } from "node:fs"
import { resolve, dirname } from "node:path"
import { fileURLToPath } from "node:url"

const [instantArg, zoneArg, edition, scope, intervalArg] = process.argv.slice(2)
if (!instantArg || !zoneArg || !edition || !scope || !intervalArg) throw new Error("usage: widget-expected.ts <ISO instant> <zone> <edition> <scope> <interval>")
const actualZone = Intl.DateTimeFormat().resolvedOptions().timeZone
if (actualZone !== zoneArg) throw new Error(`Run with TZ=${zoneArg}. This process uses ${actualZone}.`)
const store = (globalThis as Record<string, unknown>).__step7Store as Map<string, string>
store.set("bible.translationId", JSON.stringify(edition))
store.set("bible.verseScope", JSON.stringify(scope))
store.set("bible.rotationInterval", JSON.stringify(Number(intervalArg)))

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../../../..")
const { getCurrentVerse, getActiveTranslationMeta } = await import("../../../../src/services/bible/bibleService")
const { getRotationInterval, getVerseScope, getTranslationId } = await import("../../../../src/services/bible/preferences")
const { nextRotationDate } = await import("../../../../src/services/bible/verseOfDay")

const now = new Date(instantArg)
if (Number.isNaN(now.getTime())) throw new Error("bad instant")
const verse = getCurrentVerse(now)
const meta = getActiveTranslationMeta()
const interval = getRotationInterval()
const next = nextRotationDate(now, interval)
const pad = (n: number) => String(n).padStart(2, "0")
const key = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`
const dailyPath = resolve(root, `targets/widget/daily-readings-${now.getFullYear()}.json`)
let daily: unknown = null
try { daily = (JSON.parse(readFileSync(dailyPath, "utf8")) as Record<string, unknown>)[key] ?? null } catch { daily = null }
const epoch = Math.floor(now.getTime() / 1000)
console.log(JSON.stringify({
  kind: "step7-widget-source-expectation",
  inputs: { instant: now.toISOString(), zone: actualZone, edition: getTranslationId(), scope: getVerseScope(), intervalMinutes: interval },
  verse: verse ? {
    reference: verse.ref, text: verse.text, book: verse.book, chapter: verse.chapter, verse: verse.verse,
    abbreviation: meta.abbreviation, attribution: meta.attribution,
    tapURLShape: `nrsv://read?book=${verse.book}&chapter=${verse.chapter}&verse=${verse.verse}&contextRequest=<epoch seconds of the entry date>`,
    contextRequestIfEntryDateIsInstant: epoch,
  } : null,
  nextVerseAt: next.toISOString(),
  secondsToNextVerse: Math.round((next.getTime() - now.getTime()) / 1000),
  dailyReading: daily,
  dailyKey: key,
  dailyTapURL: `nrsv://daily?date=${key}`,
  sources: {
    verse: "src/services/bible/bibleService.ts:63 getCurrentVerse; src/services/bible/verseOfDay.ts rotationSlot, verseIndexForSlot, nextRotationDate",
    daily: "targets/widget/daily-readings-YYYY.json (same bytes as the widget bundle)",
    urls: "targets/widget/VerseWidget.swift:191 contextURL; targets/widget/DailyReadingWidget.swift:47 url(for:)",
  },
}, null, 2))
