// L27 full same-ID update fixture: host data builder (called by l27_fixture.py `prepare`).
//
// It writes old-app data in the old Expo app's own storage formats. It does not use any native format.
//   - MMKV rows: key and value strings, exactly as src/ writes them (hex TSV; l27_fixture.py makes the MMKV files).
//   - user-library.db: made by the executed old source functions (migrateLibraryDatabase, toggleBookmark,
//     applyHighlight, saveNote) on a file database in WAL mode, as src/services/database/libraryDatabase.ts opens it.
//   - Widget scalars: the six values that src/services/widget/widgetBridge.ts writes to the App Group defaults.
//   - source-expectations.json: the contract for scripts/native/source-fixtures/l27/compare-update-evidence.ts.
//
// The output folder must be new and below build/native-evidence/L27. Run with Bun.
import { createHash } from "node:crypto"
import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import { Database } from "bun:sqlite"
import type { SQLiteDatabase } from "expo-sqlite"
import { PRAYERS } from "../../../../src/services/companion/prayers"
import { novenas } from "../../../../src/services/novena/catalog"
import { NOVENA_DAY_COUNT } from "../../../../src/services/novena/padrePioNovena"
import { normalizeNovenaProgress } from "../../../../src/services/novena/progressModel"
import { TRANSLATIONS } from "../../../../src/services/bible/translations"
import type { PassageSelection } from "../../../../src/services/library/types"
import {
  applyHighlight, listSavedItems, saveNote, toggleBookmark,
} from "../../../../src/services/library/libraryRepository"
import { migrateLibraryDatabase } from "../../../../src/services/database/libraryDatabase"
import worksCatalog from "../../../../src/services/works/data/catalog.json"

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../../../..")
const outputRoot = resolve(process.argv[2] ?? "")
const withProbes = process.argv.includes("--probes")
const allowedRoot = resolve(repositoryRoot, "build/native-evidence/L27")
if (!process.argv[2] || !outputRoot.startsWith(`${allowedRoot}/`)) {
  throw new Error("Pass a new output path below build/native-evidence/L27")
}
if (existsSync(outputRoot)) throw new Error(`Output already exists: ${outputRoot}`)
mkdirSync(resolve(outputRoot, "library"), { recursive: true })

const readBytes = (path: string) => readFileSync(resolve(repositoryRoot, path))
const hashBytes = (bytes: Uint8Array) => createHash("sha256").update(bytes).digest("hex")

// ---- Citations: file:line of the source line that defines each stored format. -------------------------
// The script finds the line by its exact text. A source change that moves or removes the line stops the build.
const citations: Record<string, string> = {}
function cite(name: string, file: string, needle: string): string {
  const lines = readFileSync(resolve(repositoryRoot, file), "utf8").split("\n")
  const index = lines.findIndex((line) => line.includes(needle))
  if (index < 0) throw new Error(`Citation text not found in ${file}: ${needle}`)
  const value = `${file}:${index + 1}`
  citations[name] = value
  return value
}
cite("mmkv.instance", "src/utils/storage/index.ts", "export const storage = new MMKV()")
cite("mmkv.saveJSON", "src/utils/storage/index.ts", "saveString(key, JSON.stringify(value))")
cite("mmkv.saveString", "src/utils/storage/index.ts", "storage.set(key, value)")
cite("mmkv.loadParsesJSON", "src/utils/storage/index.ts", "return JSON.parse(almostThere ?? \"\") as T")
cite("theme.rawString", "src/theme/context.tsx", "useMMKVString(\"ignite.themeScheme\", storage)")
cite("theme.systemClears", "src/components/ReadingSettings.tsx", "setThemeContextOverride(value === \"system\" ? undefined : value)")
cite("bible.keys", "src/services/bible/preferences.ts", "translationId: \"bible.translationId\"")
cite("bible.rotationInterval", "src/services/bible/preferences.ts", "save(KEYS.rotationInterval, interval)")
cite("bible.verseScope", "src/services/bible/preferences.ts", "save(KEYS.verseScope, scope)")
cite("bible.translationId", "src/services/bible/preferences.ts", "save(KEYS.translationId, id)")
cite("reader.keys", "src/services/bible/readingPreferences.ts", "location: \"bible.reader.location\"")
cite("reader.location", "src/services/bible/readingPreferences.ts", "save(KEYS.location, {")
cite("reader.textSize", "src/services/bible/readingPreferences.ts", "savePreference(KEYS.textSize, value)")
cite("reader.lineSpacing", "src/services/bible/readingPreferences.ts", "savePreference(KEYS.lineSpacing, value)")
cite("reader.typeface", "src/services/bible/readingPreferences.ts", "savePreference(KEYS.typeface, value)")
cite("reader.layout", "src/services/bible/readingPreferences.ts", "savePreference(KEYS.layout, value)")
cite("reader.widgetGuide", "src/services/bible/readingPreferences.ts", "save(KEYS.widgetGuideDismissed, true)")
cite("reader.selectionHint", "src/services/bible/readingPreferences.ts", "save(KEYS.selectionHintDismissed, true)")
cite("favorites.save", "src/services/companion/preferences.ts", "\"vesper.prayer.favorites\",")
cite("reflection.save", "src/services/companion/preferences.ts", "saveString(`vesper.sunday.${date}`, JSON.stringify(value))")
cite("calendar.key", "src/services/companion/calendarNotifications.ts", "const KEY = \"john.calendar-notifications.v1\"")
cite("calendar.save", "src/services/companion/calendarNotifications.ts", "saveString(KEY, JSON.stringify(settings))")
cite("calendar.requestIDs", "src/services/companion/calendarNotifications.ts", "identifier: `${PREFIX}${date.getTime()}`")
cite("rosary.key", "src/services/rosary/reminders.ts", "const STORAGE_KEY = \"rosary.reminder.v1\"")
cite("rosary.save", "src/services/rosary/reminders.ts", "save(STORAGE_KEY, scheduled)")
cite("rosary.notificationId", "src/services/rosary/reminders.ts", "const notificationId = await Notifications.scheduleNotificationAsync({")
cite("works.key", "src/services/works/worksService.ts", "const POSITION_KEY = \"works.position.v1\"")
cite("works.save", "src/services/works/worksService.ts", "positions[workId] = { workId, sectionIndex, pageIndex, updatedAt: now }")
cite("novena.key", "src/services/novena/progress.ts", "return `novena.${novenaId}.progress.v1`")
cite("novena.save", "src/services/novena/progress.ts", "save(progressKey(novenaId), normalizeNovenaProgress(progress))")
cite("novena.model", "src/services/novena/progressModel.ts", "export function normalizeNovenaProgress(value: unknown): NovenaProgress {")
cite("widget.group", "src/services/widget/widgetBridge.ts", "export const APP_GROUP = \"group.com.nrsv.verse\"")
cite("widget.scalars", "src/services/widget/widgetBridge.ts", "[SHARED_KEYS.schemaVersion]: \"2\",")
cite("widget.intervalIsNumber", "src/services/widget/widgetBridge.ts", "storage.set(SHARED_KEYS.intervalMinutes, getRotationInterval())")
cite("widget.static", "targets/widget/VerseWidget.swift", "StaticConfiguration(kind: kind, provider: VerseProvider())")
cite("library.open", "src/services/database/libraryDatabase.ts", "PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;")
cite("library.version", "src/services/database/libraryDatabase.ts", "PRAGMA user_version = ${LIBRARY_SCHEMA_VERSION}")
cite("library.bookmark", "src/services/library/libraryRepository.ts", "export async function toggleBookmark(")
cite("library.highlight", "src/services/library/libraryRepository.ts", "export async function applyHighlight(")
cite("library.note", "src/services/library/libraryRepository.ts", "export async function saveNote(")

const sourceHashes: Record<string, string> = {}
for (const path of new Set(Object.values(citations).map((entry) => entry.slice(0, entry.lastIndexOf(":"))))) {
  sourceHashes[path] = hashBytes(readBytes(path))
}
for (const path of [
  "native/John/Packages/JohnCore/Sources/JohnCore/LegacyStateNormalizer.swift",
  "docs/native/inventory/persistent-state-and-sqlite.md",
  "scripts/native/source-fixtures/l27/build-full-fixture-data.ts",
]) sourceHashes[path] = hashBytes(readBytes(path))
for (const id of Object.keys(TRANSLATIONS).sort()) {
  const path = `src/services/bible/data/${id}/JHN.json`
  sourceHashes[path] = hashBytes(readBytes(path))
}

// ---- Source catalogs -------------------------------------------------------------------------------------
const editions = Object.values(TRANSLATIONS)
const requiredEditionIDs = ["web-ce", "douay-rheims", "vulgate"]
if (editions.length !== 3 || requiredEditionIDs.some((id) => !TRANSLATIONS[id])) throw new Error("The source edition set changed")
if (novenas.length !== 27) throw new Error(`Expected 27 source novenas, got ${novenas.length}`)

function sourceSelection(translationID: string, firstIndex: number, lastIndex: number): PassageSelection {
  const translation = TRANSLATIONS[translationID]
  const bookMeta = translation?.manifest.find((book) => book.code === "JHN")
  if (!translation || !bookMeta) throw new Error(`Missing source edition or JHN descriptor: ${translationID}`)
  const book = translation.loadBook("JHN")
  const chapter = book.chapters.find((candidate) => candidate.c === 1)
  if (!chapter) throw new Error(`Missing JHN 1 in ${translationID}`)
  const selected = chapter.verses.slice(firstIndex, lastIndex + 1)
  if (selected.length !== lastIndex - firstIndex + 1) throw new Error(`Missing requested JHN verses in ${translationID}`)
  return {
    translationId: translationID, bookCode: book.code, bookName: book.name, bookOrder: bookMeta.order,
    chapter: chapter.c, startVerse: selected[0].n, endVerse: selected[selected.length - 1].n,
    startIndex: firstIndex, endIndex: lastIndex,
    scriptureText: selected.map((verse) => `${verse.n} ${verse.t}`).join(" "),
    verses: selected.map((verse, offset) => ({ verse: verse.n, index: firstIndex + offset, text: verse.t })),
  }
}

class SourceDatabase {
  constructor(private readonly database: Database) {}
  async execAsync(sql: string): Promise<void> { this.database.exec(sql) }
  async getFirstAsync<T>(sql: string, ...values: unknown[]): Promise<T | null> {
    return (this.database.query(sql).get(...values as never[]) as T | null | undefined) ?? null
  }
  async getAllAsync<T>(sql: string, ...values: unknown[]): Promise<T[]> {
    return this.database.query(sql).all(...values as never[]) as T[]
  }
  async runAsync(sql: string, ...values: unknown[]): Promise<unknown> {
    return this.database.query(sql).run(...values as never[])
  }
  async withTransactionAsync(operation: () => Promise<void>): Promise<void> {
    this.database.exec("BEGIN IMMEDIATE")
    try { await operation(); this.database.exec("COMMIT") } catch (error) { this.database.exec("ROLLBACK"); throw error }
  }
}

// ---- Library (old source functions on a file database in WAL mode) ----------------------------------------
const clockStart = 1791228400000
let clockCalls = 0
const originalNow = Date.now
Date.now = () => { clockCalls += 1; return clockStart + clockCalls * 10 }

const liveDatabasePath = resolve(outputRoot, "library", "user-library.db")
const liveDatabase = new Database(liveDatabasePath, { create: true })
const sourceDatabase = new SourceDatabase(liveDatabase) as unknown as SQLiteDatabase
const operations: Record<string, unknown>[] = []
let walFrozen = false
let savedItems: Awaited<ReturnType<typeof listSavedItems>> = []
let rawRows: Record<string, Record<string, unknown>[]> = {}
const noteTexts: Record<string, string> = {
  "web-ce": "L27 note · web-ce — “mercy” and “grace”\nSecond line with a tab:\tend ✝",
  "douay-rheims": "L27 note · douay-rheims — draft",
  vulgate: "L27 note · vulgate — Gloria Patri",
}
try {
  await migrateLibraryDatabase(sourceDatabase)
  for (const translationID of requiredEditionIDs) {
    await toggleBookmark(sourceDatabase, sourceSelection(translationID, 0, 1))
    operations.push({ kind: "bookmark", translationID, verses: [1, 2] })
  }
  const highlights = [
    { translationID: "web-ce", start: 0, end: 2, color: "gold" },
    { translationID: "web-ce", start: 1, end: 3, color: "sage" },
    { translationID: "douay-rheims", start: 0, end: 1, color: "rose" },
    { translationID: "vulgate", start: 0, end: 1, color: "blue" },
  ] as const
  for (const [order, operation] of highlights.entries()) {
    const selection = sourceSelection(operation.translationID, operation.start, operation.end)
    await applyHighlight(sourceDatabase, selection, operation.color)
    operations.push({ kind: "highlight", order: order + 1, translationID: operation.translationID,
      verses: selection.verses.map((verse) => verse.verse), color: operation.color })
  }
  // Everything above goes into the main file. Everything below stays in the WAL, as in a running old app.
  liveDatabase.exec("PRAGMA wal_checkpoint(TRUNCATE)")
  liveDatabase.exec("PRAGMA wal_autocheckpoint=0")
  for (const translationID of requiredEditionIDs) {
    await saveNote(sourceDatabase, sourceSelection(translationID, 2, 2), translationID === "douay-rheims" ? "L27 note · douay-rheims — first text" : noteTexts[translationID])
    operations.push({ kind: "note", translationID, verses: [3], walOnly: true })
  }
  // An edit keeps created_at and changes updated_at (ON CONFLICT DO UPDATE in saveNote).
  await saveNote(sourceDatabase, sourceSelection("douay-rheims", 2, 2), noteTexts["douay-rheims"])
  operations.push({ kind: "noteEdit", translationID: "douay-rheims", verses: [3], walOnly: true })
  savedItems = await listSavedItems(sourceDatabase)
  rawRows = {
    bookmarks: liveDatabase.query("SELECT * FROM bookmarks ORDER BY translation_id").all() as Record<string, unknown>[],
    highlights: liveDatabase.query("SELECT * FROM highlights ORDER BY translation_id, verse_index").all() as Record<string, unknown>[],
    notes: liveDatabase.query("SELECT * FROM notes ORDER BY translation_id").all() as Record<string, unknown>[],
  }
  // Copy the three files while the connection is open and idle. The WAL keeps its committed frames.
  copyFileSync(liveDatabasePath, resolve(outputRoot, "library", "user-library.db.copy"))
  copyFileSync(`${liveDatabasePath}-wal`, resolve(outputRoot, "library", "user-library.db-wal.copy"))
  copyFileSync(`${liveDatabasePath}-shm`, resolve(outputRoot, "library", "user-library.db-shm.copy"))
  walFrozen = true
} finally {
  Date.now = originalNow
  liveDatabase.close()
}
if (!walFrozen) throw new Error("The WAL copy was not made")

// ---- Old-app MMKV values -----------------------------------------------------------------------------------
const prayers = PRAYERS.slice(0, 3)
if (prayers.length !== 3) throw new Error("The source prayer sample changed")
const favoriteIDs = [prayers[2].id, prayers[0].id, prayers[1].id] // Not catalog order: order must survive.

const novenaProgress = Object.fromEntries(novenas.map((novena, index) => {
  const intentions = [
    `L27 intention for ${novena.id}`,
    `L27 intention for ${novena.id}: “peace”\nfor my family — 🙏`,
    "",
  ]
  const shapes = [
    { completedDays: [9, 1, 3, 3], selectedDay: 4 },
    { completedDays: [2, 5], selectedDay: 6 },
    { completedDays: [], selectedDay: 1 },
    { completedDays: [1, 2, 3, 4, 5, 6, 7, 8, 9], selectedDay: 9 },
  ]
  return [novena.id, normalizeNovenaProgress({ ...shapes[index % 4], intention: intentions[index % 3] })]
}))
const novenaRaw = Object.fromEntries(novenas.map((novena) => [
  `novena.${novena.id}.progress.v1`, JSON.stringify(novenaProgress[novena.id]),
]))

const works = worksCatalog.works as { id: string; title: string; collectionId: string; sectionCount: number; book: string | null }[]
const johnHomilies = works.find((work) => work.id === "chrysostom.homilies-on-the-gospel-of-john")
const confessions = works.find((work) => work.id === "augustine.the-confessions")
if (!johnHomilies || !confessions || johnHomilies.sectionCount <= 9 || confessions.sectionCount <= 2) {
  throw new Error("Required Works source rows changed")
}

const selectedEdition = TRANSLATIONS["douay-rheims"]
const readerUpdatedAt = 1791228500000
const worksUpdatedAt = { homily: 1791228510000, confessions: 1791228520000 }
const widgetScalars = {
  widgetSchemaVersion: { type: "string", value: "2" },
  intervalMinutes: { type: "number", value: 60 },
  scope: { type: "string", value: "nt" },
  translationId: { type: "string", value: selectedEdition.meta.id },
  abbreviation: { type: "string", value: selectedEdition.meta.abbreviation },
  attribution: { type: "string", value: selectedEdition.meta.attribution },
}
// Stored exactly as the old source writes them. Key order follows the source object literals.
const legacyValues: Record<string, string> = {
  "ignite.themeScheme": "dark",
  "bible.translationId": JSON.stringify(selectedEdition.meta.id),
  "bible.rotationInterval": JSON.stringify(60),
  "bible.verseScope": JSON.stringify("nt"),
  "bible.reader.location": JSON.stringify({ book: "JHN", chapter: 3, scrollY: 418.75, updatedAt: readerUpdatedAt }),
  "bible.reader.textSize": JSON.stringify("extraLarge"),
  "bible.reader.lineSpacing": JSON.stringify("relaxed"),
  "bible.reader.typeface": JSON.stringify("sans"),
  "bible.reader.layout": JSON.stringify("verses"),
  "bible.widgetGuideDismissed": JSON.stringify(true),
  "bible.reader.selectionHintDismissed": JSON.stringify(true),
  "vesper.prayer.favorites": JSON.stringify(favoriteIDs),
  "john.calendar-notifications.v1": JSON.stringify({ enabled: true, hour: 7, minute: 5 }),
  "rosary.reminder.v1": JSON.stringify({ enabled: true, frequency: "weekly", hour: 6, minute: 45, weekday: 5, notificationId: "L27-imported-rosary-reminder" }),
  "works.position.v1": JSON.stringify({
    [johnHomilies.id]: { workId: johnHomilies.id, sectionIndex: 9, pageIndex: 3, updatedAt: worksUpdatedAt.homily },
    [confessions.id]: { workId: confessions.id, sectionIndex: 2, pageIndex: 1, updatedAt: worksUpdatedAt.confessions },
  }),
  "vesper.sunday.2026-09-13": JSON.stringify({ before: "I will listen with patience.", after: "I will carry mercy into the week." }),
  "vesper.sunday.2026-09-20": JSON.stringify({ before: "I will notice one gift — “thanks”.", after: "I will serve one person.\nThen rest. ✝" }),
  "vesper.sunday.2026-10-04": JSON.stringify({ before: "", after: "Only an evening note." }),
  ...novenaRaw,
}
if (withProbes) {
  // Optional preservation probes. They are NOT old-app formats. The old app never writes them.
  legacyValues["works.position.v1"] = JSON.stringify({
    [johnHomilies.id]: { workId: johnHomilies.id, sectionIndex: 9, pageIndex: 3, updatedAt: worksUpdatedAt.homily,
      anchor: { paragraphIndex: 2, utf16Offset: 57 }, sourceExtra: "preserve-this-field" },
    [confessions.id]: { workId: confessions.id, sectionIndex: 2, pageIndex: 1, updatedAt: worksUpdatedAt.confessions },
  })
  legacyValues["l27.unknown.preserved"] = "raw unknown legacy value stays byte-for-byte"
}

const worksNative: Record<string, unknown> = {
  [johnHomilies.id]: JSON.parse(legacyValues["works.position.v1"])[johnHomilies.id],
  [confessions.id]: JSON.parse(legacyValues["works.position.v1"])[confessions.id],
}
const reflections: Record<string, unknown> = {}
for (const [key, raw] of Object.entries(legacyValues)) {
  if (key.startsWith("vesper.sunday.")) reflections[key.slice("vesper.sunday.".length)] = JSON.parse(raw)
}
const expectedNativeState = {
  themeScheme: "dark",
  translationID: selectedEdition.meta.id,
  rotationIntervalMinutes: 60,
  verseScope: "nt",
  readerLocation: { bookCode: "JHN", chapter: 3, scrollY: 418.75, updatedAt: readerUpdatedAt, anchor: null },
  readingPreferences: { textSize: "extraLarge", lineSpacing: "relaxed", typeface: "sans", layout: "verses" },
  widgetGuideDismissed: true,
  selectionHintDismissed: true,
  favoritePrayerIDs: favoriteIDs,
  calendarNotifications: { enabled: true, hour: 7, minute: 5 },
  rosaryReminder: { enabled: true, frequency: "weekly", hour: 6, minute: 45, weekday: 5, notificationID: "L27-imported-rosary-reminder" },
  reflections,
  novenaProgress,
  worksPositions: worksNative,
  legacyUnknownKeys: withProbes ? ["l27.unknown.preserved"] : [],
}

function encodeTSV(values: Record<string, string>): string {
  return Object.entries(values).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)).map(([key, value]) =>
    `${Buffer.from(key, "utf8").toString("hex")}\t${Buffer.from(value, "utf8").toString("hex")}`,
  ).join("\n") + "\n"
}

const output = {
  formatVersion: 1,
  kind: "l27-source-generated-update-contract",
  runtimeBehaviorObserved: false,
  generatedBy: "scripts/native/source-fixtures/l27/build-full-fixture-data.ts",
  fixtureKind: withProbes ? "old-app-formats-with-preservation-probes" : "old-app-formats-only",
  baselineCommit: "b64e1fc3cfc6a78f508b41d74b71dddfe9ff7697",
  provenance: {
    sourceHashes,
    citations,
    fixturePurpose: "Expectations for the host-seeded old-app data in build/native-evidence/L27/full-fixture-01. Main's actual pre-update export stays the authority.",
    liveMMKVOrSQLiteCreated: true,
    expectedAppLibrarySchemaVersion: 1,
    expectedWidgetGroup: "group.com.nrsv.verse",
  },
  expectedNativeState,
  rawLegacyMMKVStrings: legacyValues,
  appGroupWidgetScalars: widgetScalars,
  sourceCatalogIdentity: {
    prayers: prayers.map(({ id, title, category }) => ({ id, title, category })),
    prayerCount: PRAYERS.length,
    novenas: novenas.map(({ id, title, subtitle, sections }) => ({ id, title, subtitle, dayCount: NOVENA_DAY_COUNT, sectionCount: sections.length })),
    novenaCount: novenas.length,
    works: [johnHomilies, confessions],
    editions: editions.map(({ meta, manifest }) => ({
      id: meta.id, fullName: meta.fullName, abbreviation: meta.abbreviation,
      attribution: meta.attribution, bookCount: manifest.length, john: manifest.find((book) => book.code === "JHN"),
    })),
  },
  sourceLibrary: {
    expectedOutputAuthority: "Executed source functions on a file database in WAL mode: migrateLibraryDatabase, toggleBookmark, applyHighlight, saveNote, listSavedItems. The clock is Date.now = 1791228400000 + 10 per call.",
    schemaVersion: 1,
    journalMode: "wal",
    clock: { start: clockStart, stepMilliseconds: 10, calls: clockCalls },
    operations,
    walOnlyTables: ["notes"],
    finalRows: rawRows,
    savedItems,
    rowCounts: Object.fromEntries(Object.entries(rawRows).map(([table, rows]) => [table, rows.length])),
    overlapExpectation: {
      webCE: "The second highlight replaces verses 2 and 3 from the first batch. Verse 1 keeps its first batch. Verses 2 through 4 share the second batch.",
      finalRowIdentity: rawRows.highlights?.map((row) => ({
        verseKey: row.verse_key, batchID: row.batch_id, translationID: row.translation_id,
        verse: row.verse, verseIndex: row.verse_index, color: row.color,
      })),
    },
  },
  oldAppExportRequirements: {
    status: "Main-owned runtime capture",
    requireSameProductionBundleIDWithoutUninstall: true,
    beforeAndAfterHashes: ["user-library.db", "user-library.db-wal", "user-library.db-shm", "mmkv/data", "mmkv/crc"],
    retainNativeAnchor: "Legacy Reader location has no native anchor field. The expected native anchor is null.",
  },
}

const tsv = encodeTSV(legacyValues)
writeFileSync(resolve(outputRoot, "legacy-values.tsv"), tsv)
writeFileSync(resolve(outputRoot, "source-expectations.json"), `${JSON.stringify(output, null, 2)}\n`)
writeFileSync(resolve(outputRoot, "group-prefs.json"), `${JSON.stringify(widgetScalars, null, 2)}\n`)
writeFileSync(resolve(outputRoot, "format-sources.json"), `${JSON.stringify({ formatVersion: 1, citations }, null, 2)}\n`)
console.log(JSON.stringify({
  outputRoot, legacyKeys: Object.keys(legacyValues).length, novenas: novenas.length,
  rowCounts: output.sourceLibrary.rowCounts, clockCalls, probes: withProbes,
}))
