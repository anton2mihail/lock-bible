import { createHash } from "node:crypto"
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
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
  applyHighlight,
  listSavedItems,
  saveNote,
  toggleBookmark,
} from "../../../../src/services/library/libraryRepository"
import { migrateLibraryDatabase } from "../../../../src/services/database/libraryDatabase"
import worksCatalog from "../../../../src/services/works/data/catalog.json"

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../../../..")
const outputRoot = resolve(process.argv[2] ?? "")
const allowedRoot = resolve(repositoryRoot, "build/native-evidence/L27")
if (!process.argv[2] || !outputRoot.startsWith(`${allowedRoot}/`)) {
  throw new Error("Pass a new output path below build/native-evidence/L27")
}
if (existsSync(outputRoot)) throw new Error(`Output already exists: ${outputRoot}`)
mkdirSync(outputRoot, { recursive: true })

const readBytes = (path: string) => readFileSync(resolve(repositoryRoot, path))
const hashBytes = (bytes: Uint8Array) => createHash("sha256").update(bytes).digest("hex")
const sourceHashes: Record<string, string> = {}
const sourceFiles = [
  "src/utils/storage/index.ts",
  "src/services/companion/prayers.ts",
  "src/services/novena/catalog.ts",
  "src/services/novena/expandedNovenas.ts",
  "src/services/novena/padrePioNovena.ts",
  "src/services/novena/perpetualHelpNovena.ts",
  "src/services/novena/stJosephNovena.ts",
  "src/services/novena/stJudeNovena.ts",
  "src/services/novena/stPeregrineNovena.ts",
  "src/services/novena/stThereseNovena.ts",
  "src/services/novena/progressModel.ts",
  "src/services/bible/translations.ts",
  "src/services/bible/preferences.ts",
  "src/services/bible/readingPreferences.ts",
  "src/services/bible/verseOfDay.ts",
  "src/services/companion/preferences.ts",
  "src/services/companion/calendarNotifications.ts",
  "src/services/rosary/reminders.ts",
  "src/services/works/worksService.ts",
  "src/services/library/selection.ts",
  "src/services/library/libraryRepository.ts",
  "src/services/library/types.ts",
  "src/services/database/libraryDatabase.ts",
  "src/services/widget/widgetBridge.ts",
  "targets/widget/VerseWidget.swift",
  "targets/widget/DailyReadingWidget.swift",
  "src/services/works/data/catalog.json",
  "src/services/works/data/chrysostom/homilies-on-the-gospel-of-john.json",
  "src/utils/storage/index.ts",
  "native/John/Packages/JohnCore/Sources/JohnCore/LegacyStateNormalizer.swift",
  "docs/native/inventory/persistent-state-and-sqlite.md",
  "scripts/native/source-fixtures/l27/prepare-source-expectations.ts",
]
for (const path of sourceFiles) sourceHashes[path] = hashBytes(readBytes(path))
for (const id of Object.keys(TRANSLATIONS).sort()) {
  const path = `src/services/bible/data/${id}/JHN.json`
  sourceHashes[path] = hashBytes(readBytes(path))
}

const editions = Object.values(TRANSLATIONS)
const requiredEditionIDs = ["web-ce", "douay-rheims", "vulgate"]
if (editions.length !== 3 || requiredEditionIDs.some((id) => !TRANSLATIONS[id])) {
  throw new Error("The source edition set changed")
}
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
    translationId: translationID,
    bookCode: book.code,
    bookName: book.name,
    bookOrder: bookMeta.order,
    chapter: chapter.c,
    startVerse: selected[0].n,
    endVerse: selected[selected.length - 1].n,
    startIndex: firstIndex,
    endIndex: lastIndex,
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
    try {
      await operation()
      this.database.exec("COMMIT")
    } catch (error) {
      this.database.exec("ROLLBACK")
      throw error
    }
  }
}

const fixedTimestamps = [
  1791228336690, 1791228336700, 1791228336710,
  1791228336720, 1791228336730, 1791228336740, 1791228336750,
  1791228336760, 1791228336770, 1791228336780, 1791228336790,
  1791228336800, 1791228336810,
]
const originalNow = Date.now
let clockIndex = 0
Date.now = () => {
  const value = fixedTimestamps[clockIndex]
  if (value === undefined) throw new Error("The fixed source clock sequence was exhausted")
  clockIndex += 1
  return value
}

const inMemorySQLite = new Database(":memory:")
const sourceDatabase = new SourceDatabase(inMemorySQLite) as unknown as SQLiteDatabase
const overlapOperations: { order: number; translationID: string; verses: string[]; color: string; timestamp: number }[] = []
let savedItems: Awaited<ReturnType<typeof listSavedItems>> = []
let rawRows: Record<string, Record<string, unknown>[]> = {}
try {
  await migrateLibraryDatabase(sourceDatabase)
  for (const translationID of requiredEditionIDs) {
    await toggleBookmark(sourceDatabase, sourceSelection(translationID, 0, 1))
  }

  const highlights = [
    { translationID: "web-ce", start: 0, end: 2, color: "gold" },
    { translationID: "web-ce", start: 1, end: 3, color: "sage" },
    { translationID: "douay-rheims", start: 0, end: 1, color: "rose" },
    { translationID: "vulgate", start: 0, end: 1, color: "blue" },
  ] as const
  for (let order = 0; order < highlights.length; order += 1) {
    const operation = highlights[order]
    await applyHighlight(sourceDatabase, sourceSelection(operation.translationID, operation.start, operation.end), operation.color)
    overlapOperations.push({
      order: order + 1,
      translationID: operation.translationID,
      verses: sourceSelection(operation.translationID, operation.start, operation.end).verses.map((verse) => verse.verse),
      color: operation.color,
      timestamp: fixedTimestamps[3 + order],
    })
  }

  for (const translationID of requiredEditionIDs) {
    await saveNote(sourceDatabase, sourceSelection(translationID, 2, 2), `L27 source note · ${translationID}`)
  }
  savedItems = await listSavedItems(sourceDatabase)
  rawRows = {
    bookmarks: inMemorySQLite.query("SELECT * FROM bookmarks ORDER BY translation_id").all() as Record<string, unknown>[],
    highlights: inMemorySQLite.query("SELECT * FROM highlights ORDER BY translation_id, verse_index").all() as Record<string, unknown>[],
    notes: inMemorySQLite.query("SELECT * FROM notes ORDER BY translation_id").all() as Record<string, unknown>[],
  }
} finally {
  Date.now = originalNow
  inMemorySQLite.close()
}

const prayers = PRAYERS.slice(0, 3)
if (prayers.length !== 3) throw new Error("The source prayer sample changed")
const selectedNovena = novenas.find((novena) => novena.id === "st-padre-pio")
if (!selectedNovena) throw new Error("Missing source Padre Pio novena")
const novenaProgress = Object.fromEntries(novenas.map((novena, index) => {
  const candidate = index % 3 === 0
    ? { completedDays: [9, 1, 3, 3], selectedDay: 4, intention: `L27 intention ${novena.id}` }
    : index % 3 === 1
      ? { completedDays: [2, 5], selectedDay: 6, intention: `L27 intention ${novena.id}` }
      : { completedDays: [], selectedDay: 1, intention: `L27 intention ${novena.id}` }
  return [novena.id, normalizeNovenaProgress(candidate)]
}))
const novenaRaw = Object.fromEntries(novenas.map((novena) => [
  `novena.${novena.id}.progress.v1`, JSON.stringify(novenaProgress[novena.id]),
]))

const works = worksCatalog.works as { id: string; title: string; collectionId: string; sectionCount: number; book: string | null }[]
const johnHomilies = works.find((work) => work.id === "chrysostom.homilies-on-the-gospel-of-john")
const confessions = works.find((work) => work.id === "augustine.the-confessions")
if (!johnHomilies || !confessions || johnHomilies.sectionCount <= 9) throw new Error("Required Works source rows changed")
const homilyData = JSON.parse(readBytes("src/services/works/data/chrysostom/homilies-on-the-gospel-of-john.json").toString("utf8")) as {
  sections: { title: string; paragraphs: string[] }[]
}
const selectedSection = homilyData.sections[9]
const selectedParagraph = selectedSection?.paragraphs[2]
const selectedAnchor = { paragraphIndex: 2, utf16Offset: 57 }
if (!selectedSection || selectedSection.title !== "Homily 10" || !selectedParagraph || selectedParagraph.length < selectedAnchor.utf16Offset) {
  throw new Error("Selected Works anchor is outside the source section")
}

const selectedEdition = TRANSLATIONS["douay-rheims"]
const widgetScalars = {
  widgetSchemaVersion: { type: "string", value: "2" },
  intervalMinutes: { type: "number", value: 60 },
  scope: { type: "string", value: "full" },
  translationId: { type: "string", value: selectedEdition.meta.id },
  abbreviation: { type: "string", value: selectedEdition.meta.abbreviation },
  attribution: { type: "string", value: selectedEdition.meta.attribution },
}

const legacyValues: Record<string, string> = {
  "ignite.themeScheme": "dark",
  "bible.translationId": JSON.stringify(selectedEdition.meta.id),
  "bible.rotationInterval": JSON.stringify(60),
  "bible.verseScope": JSON.stringify("full"),
  "bible.reader.location": JSON.stringify({ book: "JHN", chapter: 3, scrollY: 418.75, updatedAt: fixedTimestamps[0] }),
  "bible.reader.textSize": JSON.stringify("large"),
  "bible.reader.lineSpacing": JSON.stringify("relaxed"),
  "bible.reader.typeface": JSON.stringify("sans"),
  "bible.reader.layout": JSON.stringify("verses"),
  "bible.widgetGuideDismissed": JSON.stringify(true),
  "bible.reader.selectionHintDismissed": JSON.stringify(true),
  "vesper.prayer.favorites": JSON.stringify(prayers.map((prayer) => prayer.id)),
  "john.calendar-notifications.v1": JSON.stringify({ enabled: true, hour: 7, minute: 5 }),
  "rosary.reminder.v1": JSON.stringify({ enabled: true, frequency: "weekly", hour: 6, minute: 45, weekday: 5, notificationId: "L27-imported-rosary-reminder" }),
  "works.position.v1": JSON.stringify({
    [johnHomilies.id]: {
      workId: johnHomilies.id, sectionIndex: 9, pageIndex: 3, updatedAt: fixedTimestamps[1],
      anchor: selectedAnchor, sourceExtra: "preserve-this-field",
    },
    [confessions.id]: { workId: confessions.id, sectionIndex: 2, pageIndex: 1, updatedAt: fixedTimestamps[2] },
  }),
  "vesper.sunday.2026-09-13": JSON.stringify({ before: "I will listen with patience.", after: "I will carry mercy into the week." }),
  "vesper.sunday.2026-09-20": JSON.stringify({ before: "I will notice one gift.", after: "I will serve one person." }),
  "l27.unknown.preserved": "raw unknown legacy value stays byte-for-byte",
  ...novenaRaw,
}

const expectedNativeState = {
  themeScheme: "dark",
  translationID: selectedEdition.meta.id,
  rotationIntervalMinutes: 60,
  verseScope: "full",
  readerLocation: { bookCode: "JHN", chapter: 3, scrollY: 418.75, updatedAt: fixedTimestamps[0], anchor: null },
  readingPreferences: { textSize: "large", lineSpacing: "relaxed", typeface: "sans", layout: "verses" },
  widgetGuideDismissed: true,
  selectionHintDismissed: true,
  favoritePrayerIDs: prayers.map((prayer) => prayer.id),
  calendarNotifications: { enabled: true, hour: 7, minute: 5 },
  rosaryReminder: { enabled: true, frequency: "weekly", hour: 6, minute: 45, weekday: 5, notificationID: "L27-imported-rosary-reminder" },
  reflections: {
    "2026-09-13": { before: "I will listen with patience.", after: "I will carry mercy into the week." },
    "2026-09-20": { before: "I will notice one gift.", after: "I will serve one person." },
  },
  novenaProgress,
  worksPositions: {
    [johnHomilies.id]: { workId: johnHomilies.id, sectionIndex: 9, pageIndex: 3, updatedAt: fixedTimestamps[1], anchor: selectedAnchor, sourceExtra: "preserve-this-field" },
    [confessions.id]: { workId: confessions.id, sectionIndex: 2, pageIndex: 1, updatedAt: fixedTimestamps[2] },
  },
  legacyUnknownKeys: ["l27.unknown.preserved"],
}

const defaultCases = [
  { name: "absentValues", input: {}, expected: {
    themeScheme: null, translationID: "web-ce", rotationIntervalMinutes: 1440, verseScope: "full",
    readerLocation: null, readingPreferences: { textSize: "medium", lineSpacing: "comfortable", typeface: "serif", layout: "paragraphs" },
    widgetGuideDismissed: false, selectionHintDismissed: false, favoritePrayerIDs: [],
    calendarNotifications: { enabled: false, hour: 8, minute: 0 },
    rosaryReminder: { enabled: false, frequency: "daily", hour: 20, minute: 0, weekday: 2, notificationID: null },
    reflections: {}, novenaProgress: {}, worksPositions: {},
  } },
  { name: "rawUnknownTheme", input: { "ignite.themeScheme": "sepia" }, expected: { themeScheme: "sepia" } },
  { name: "unknownTranslation", input: { "bible.translationId": JSON.stringify("unknown-edition") }, expected: { translationID: "web-ce" } },
  { name: "unsupportedRotation", input: { "bible.rotationInterval": JSON.stringify(45) }, expected: { rotationIntervalMinutes: 1440 } },
  { name: "unknownScope", input: { "bible.verseScope": JSON.stringify("all") }, expected: { verseScope: "full" } },
  { name: "invalidReaderLocation", input: { "bible.reader.location": JSON.stringify({ book: "JHN", chapter: 0, scrollY: 10 }) }, expected: { readerLocation: null } },
  { name: "invalidTextSize", input: { "bible.reader.textSize": JSON.stringify("huge") }, expected: { readingPreferences: { textSize: "medium" } } },
  { name: "invalidLineSpacing", input: { "bible.reader.lineSpacing": JSON.stringify("wide") }, expected: { readingPreferences: { lineSpacing: "comfortable" } } },
  { name: "invalidTypeface", input: { "bible.reader.typeface": JSON.stringify("mono") }, expected: { readingPreferences: { typeface: "serif" } } },
  { name: "invalidLayout", input: { "bible.reader.layout": JSON.stringify("continuous") }, expected: { readingPreferences: { layout: "paragraphs" } } },
  { name: "invalidDismissalFlags", input: { "bible.widgetGuideDismissed": JSON.stringify("true"), "bible.reader.selectionHintDismissed": JSON.stringify(1) }, expected: { widgetGuideDismissed: false, selectionHintDismissed: false } },
  { name: "mixedFavorites", input: { "vesper.prayer.favorites": JSON.stringify(["morning", 2, "our-father"]) }, expected: { favoritePrayerIDs: ["morning", "our-father"] } },
  { name: "invalidCalendarTime", input: { "john.calendar-notifications.v1": JSON.stringify({ enabled: true, hour: 25, minute: -1 }) }, expected: { calendarNotifications: { enabled: true, hour: 8, minute: 0 } } },
  { name: "invalidRosaryReminder", input: { "rosary.reminder.v1": JSON.stringify({ enabled: true, frequency: "monthly", hour: 25, minute: 70, weekday: 9, notificationId: 5 }) }, expected: { rosaryReminder: { enabled: true, frequency: "daily", hour: 20, minute: 0, weekday: 2, notificationID: null } } },
  { name: "invalidWorksPosition", input: { "works.position.v1": JSON.stringify({ "fixture-work": { workId: "fixture-work", sectionIndex: "nine" } }) }, expected: { worksPositions: {} } },
  { name: "invalidNovenaProgress", input: { "novena.st-padre-pio.progress.v1": JSON.stringify({ completedDays: [0, 2, 2, 10], selectedDay: 12, intention: 7 }) }, expected: { novenaProgress: { "st-padre-pio": { completedDays: [2], selectedDay: 1, intention: "" } } } },
  { name: "invalidReflectionFields", input: { "vesper.sunday.2026-09-13": JSON.stringify({ before: 4, after: "text" }) }, expected: { reflections: { "2026-09-13": { before: "", after: "text" } } } },
  { name: "malformedJSON", input: { "vesper.prayer.favorites": "[" }, expected: { favoritePrayerIDs: [] } },
]

function encodeTSV(values: Record<string, string>): string {
  return Object.entries(values).sort(([left], [right]) => left < right ? -1 : left > right ? 1 : 0).map(([key, value]) =>
    `${Buffer.from(key, "utf8").toString("hex")}\t${Buffer.from(value, "utf8").toString("hex")}`,
  ).join("\n") + "\n"
}

const output = {
  formatVersion: 1,
  kind: "l27-source-generated-update-contract",
  runtimeBehaviorObserved: false,
  generatedBy: "scripts/native/source-fixtures/l27/prepare-source-expectations.ts",
  baselineCommit: "b64e1fc3cfc6a78f508b41d74b71dddfe9ff7697",
  provenance: {
    sourceHashes,
    fixturePurpose: "Source expectations only. Main creates and exports the real old-app fixture.",
    liveMMKVOrSQLiteCreated: false,
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
      attribution: meta.attribution, bookCount: manifest.length,
      john: manifest.find((book) => book.code === "JHN"),
    })),
  },
  sourceLibrary: {
    expectedOutputAuthority: "Executed source functions: migrateLibraryDatabase, toggleBookmark, applyHighlight, saveNote, listSavedItems with a fixed Date.now sequence. The source SQLite rows and grouped saved-item values below are direct function outputs.",
    schemaVersion: 1,
    fixedClock: fixedTimestamps,
    highlightOperations: overlapOperations,
    finalRows: rawRows,
    savedItems,
    rowCounts: Object.fromEntries(Object.entries(rawRows).map(([table, rows]) => [table, rows.length])),
    overlapExpectation: {
      webCE: "The second source highlight replaces verses 2 and 3 from the first batch. Verse 1 stays in its first batch. Verses 2 through 4 share the second batch.",
      finalRowIdentity: rawRows.highlights?.map((row) => ({
        verseKey: row.verse_key, batchID: row.batch_id, translationID: row.translation_id,
        verse: row.verse, verseIndex: row.verse_index, color: row.color,
      })),
    },
  },
  defaultsForMalformedOrAbsentVariants: {
    expectedOutputAuthority: "Reviewed reconstruction of LegacyStateNormalizer.swift. These cases were not produced by the old JavaScript preference getter functions.",
    executedSourceFunctions: ["normalizeNovenaProgress", "migrateLibraryDatabase", "toggleBookmark", "applyHighlight", "saveNote", "listSavedItems"],
    cases: defaultCases,
  },
  legacyPreferenceLoaderProvenance: {
    expectedValuesForImportedLegacyState: "Reviewed reconstruction from LegacyStateNormalizer.swift and docs/native/inventory/persistent-state-and-sqlite.md.",
    oldApplicationLoaderModules: [
      "src/utils/storage/index.ts", "src/services/bible/preferences.ts", "src/services/bible/readingPreferences.ts",
      "src/services/companion/preferences.ts", "src/services/companion/calendarNotifications.ts",
      "src/services/rosary/reminders.ts", "src/services/works/worksService.ts", "src/services/novena/progressModel.ts",
    ],
    rawThemeIsNotJSONParsed: true,
    genericLoadParsesJSONOnce: true,
  },
  worksAnchorSourceValidation: {
    workID: johnHomilies.id,
    sectionIndex: 9,
    sectionTitle: selectedSection.title,
    paragraphIndex: selectedAnchor.paragraphIndex,
    utf16Offset: selectedAnchor.utf16Offset,
    paragraphUTF16Length: selectedParagraph.length,
    validatedAgainst: "src/services/works/data/chrysostom/homilies-on-the-gospel-of-john.json",
  },
  oldAppExportRequirements: {
    status: "Main-owned runtime capture",
    requireSameProductionBundleIDWithoutUninstall: true,
    beforeAndAfterHashes: ["user-library.db", "user-library.db-wal", "user-library.db-shm", "mmkv/data", "mmkv/crc"],
    record: ["bundleID", "appVersion", "appBuild", "AppGroup entitlement", "MMKV root", "processID", "widget scalar key types", "pending local notice IDs/triggers/payloads", "consistent recovery backup path/hash/schema/row counts/integrity"],
    retainNativeAnchor: "Legacy Reader location has no native anchor field; expected native anchor is null.",
  },
}

const tsv = encodeTSV(legacyValues)
const jsonBytes = Buffer.from(`${JSON.stringify(output, null, 2)}\n`)
const tsvPath = resolve(outputRoot, "legacy-values.tsv")
const jsonPath = resolve(outputRoot, "source-expectations.json")
writeFileSync(tsvPath, tsv)
writeFileSync(jsonPath, jsonBytes)
const manifest = {
  formatVersion: 1,
  kind: "l27-source-expectation-manifest",
  runtimeBehaviorObserved: false,
  legacyKeyCount: Object.keys(legacyValues).length,
  novenaKeyCount: novenas.length,
  editionCount: editions.length,
  prayerFavoriteCount: prayers.length,
  reflectionDateCount: Object.keys(expectedNativeState.reflections).length,
  workPositionCount: Object.keys(expectedNativeState.worksPositions).length,
  sqliteSchemaVersion: 1,
  sqliteRowCounts: output.sourceLibrary.rowCounts,
  highlightOverlapOperationCount: overlapOperations.length,
  malformedOrAbsentCaseCount: defaultCases.length,
  sourceHashes,
  outputFiles: {
    "legacy-values.tsv": { bytes: Buffer.byteLength(tsv), sha256: hashBytes(Buffer.from(tsv)) },
    "source-expectations.json": { bytes: jsonBytes.length, sha256: hashBytes(jsonBytes) },
  },
}
writeFileSync(resolve(outputRoot, "fixture-manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`)
console.log(JSON.stringify({ outputRoot, manifest }, null, 2))
