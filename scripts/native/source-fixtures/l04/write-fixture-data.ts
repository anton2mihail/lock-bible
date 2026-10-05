import { Database } from "bun:sqlite"
import { createHash } from "node:crypto"
import { copyFileSync, existsSync, mkdirSync, readFileSync, unlinkSync, writeFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import { novenas } from "../../../../src/services/novena/catalog"

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../../../..")
const outputRoot = resolve(process.argv[2] ?? "")
if (!process.argv[2] || existsSync(outputRoot)) throw new Error("Pass a new fixture output directory")
const inputRoot = join(outputRoot, "input")
const legacyRoot = join(inputRoot, "legacy")
const invalidLegacyRoot = join(inputRoot, "invalid-legacy")
const libraryRoot = join(inputRoot, "library")
const variantsRoot = join(inputRoot, "library-variants")
mkdirSync(legacyRoot, { recursive: true })
mkdirSync(invalidLegacyRoot, { recursive: true })
mkdirSync(libraryRoot, { recursive: true })
mkdirSync(variantsRoot, { recursive: true })

const fixedValues: Record<string, string> = {
  "ignite.themeScheme": "dark",
  "bible.translationId": JSON.stringify("douay-rheims"),
  "bible.rotationInterval": JSON.stringify(30),
  "bible.verseScope": JSON.stringify("full"),
  "bible.reader.location": JSON.stringify({ book: "JHN", chapter: 3, scrollY: 321.5, updatedAt: 1791228336690 }),
  "bible.reader.textSize": JSON.stringify("extraLarge"),
  "bible.reader.lineSpacing": JSON.stringify("relaxed"),
  "bible.reader.typeface": JSON.stringify("sans"),
  "bible.reader.layout": JSON.stringify("verses"),
  "bible.widgetGuideDismissed": JSON.stringify(true),
  "bible.reader.selectionHintDismissed": JSON.stringify(true),
  "vesper.prayer.favorites": JSON.stringify(["fixture-prayer-one", "fixture-prayer-two"]),
  "john.calendar-notifications.v1": JSON.stringify({ enabled: true, hour: 7, minute: 5 }),
  "rosary.reminder.v1": JSON.stringify({ enabled: true, frequency: "weekly", hour: 6, minute: 45, weekday: 5, notificationId: "l04-fixture-reminder" }),
  "works.position.v1": JSON.stringify({ "fixture-work": { workId: "fixture-work", sectionIndex: 4, pageIndex: 12, updatedAt: 1791228336690, anchor: { paragraphIndex: 2, utf16Offset: 57 } } }),
  "vesper.sunday.2026-10-05": JSON.stringify({ before: "Synthetic reflection before.", after: "Synthetic reflection after." }),
  "l04.unknown.preserved": JSON.stringify({ marker: "unknown-key-bytes-must-stay" }),
}
for (const novena of novenas) {
  fixedValues[`novena.${novena.id}.progress.v1`] = JSON.stringify({
    completedDays: [1, 3, 9], selectedDay: 4, intention: `Synthetic intention ${novena.id}`,
  })
}

function writeRows(path: string, values: Record<string, string>) {
  const content = Object.entries(values).sort(([a], [b]) => a.localeCompare(b)).map(([key, value]) =>
    `${Buffer.from(key, "utf8").toString("hex")}\t${Buffer.from(value, "utf8").toString("hex")}`,
  ).join("\n") + "\n"
  writeFileSync(path, content)
}
writeRows(join(outputRoot, "legacy-values.tsv"), fixedValues)
writeRows(join(outputRoot, "invalid-legacy-values.tsv"), { ...fixedValues, "bible.reader.textSize": JSON.stringify("unknown-size") })

const expectedProgress = Object.fromEntries(novenas.map(({ id }) => [id, {
  completedDays: [1, 3, 9], selectedDay: 4, intention: `Synthetic intention ${id}`,
}]))
const expected = {
  themeScheme: "dark",
  translationID: "douay-rheims",
  rotationIntervalMinutes: 30,
  verseScope: "full",
  readerLocation: { bookCode: "JHN", chapter: 3, scrollY: 321.5, updatedAt: 1791228336690 },
  readingPreferences: { textSize: "extraLarge", lineSpacing: "relaxed", typeface: "sans", layout: "verses" },
  widgetGuideDismissed: true,
  selectionHintDismissed: true,
  reflections: { "2026-10-05": { before: "Synthetic reflection before.", after: "Synthetic reflection after." } },
  favoritePrayerIDs: ["fixture-prayer-one", "fixture-prayer-two"],
  calendarNotifications: { enabled: true, hour: 7, minute: 5 },
  rosaryReminder: { enabled: true, frequency: "weekly", hour: 6, minute: 45, weekday: 5, notificationID: "l04-fixture-reminder" },
  worksPositions: { "fixture-work": { fields: { workId: "fixture-work", sectionIndex: 4, pageIndex: 12, updatedAt: 1791228336690, anchor: { paragraphIndex: 2, utf16Offset: 57 } } } },
  novenaProgress: expectedProgress,
}
writeFileSync(join(outputRoot, "expected-state.json"), `${JSON.stringify(expected, null, 2)}\n`)

const databasePath = join(outputRoot, "library-source.sqlite")
const database = new Database(databasePath, { create: true })
database.exec("PRAGMA journal_mode=WAL; PRAGMA wal_autocheckpoint=0;")
database.exec(`
  BEGIN IMMEDIATE;
  CREATE TABLE bookmarks (passage_key TEXT PRIMARY KEY NOT NULL, translation_id TEXT NOT NULL, book_code TEXT NOT NULL, book_name TEXT NOT NULL, book_order INTEGER NOT NULL, chapter INTEGER NOT NULL, start_verse TEXT NOT NULL, end_verse TEXT NOT NULL, start_index INTEGER NOT NULL, end_index INTEGER NOT NULL, scripture_text TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
  CREATE INDEX bookmarks_updated_idx ON bookmarks(updated_at DESC);
  CREATE TABLE highlights (verse_key TEXT PRIMARY KEY NOT NULL, batch_id TEXT NOT NULL, translation_id TEXT NOT NULL, book_code TEXT NOT NULL, book_name TEXT NOT NULL, book_order INTEGER NOT NULL, chapter INTEGER NOT NULL, verse TEXT NOT NULL, verse_index INTEGER NOT NULL, verse_text TEXT NOT NULL, color TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
  CREATE INDEX highlights_reference_idx ON highlights(translation_id, book_code, chapter, verse_index);
  CREATE INDEX highlights_updated_idx ON highlights(updated_at DESC);
  CREATE TABLE notes (passage_key TEXT PRIMARY KEY NOT NULL, translation_id TEXT NOT NULL, book_code TEXT NOT NULL, book_name TEXT NOT NULL, book_order INTEGER NOT NULL, chapter INTEGER NOT NULL, start_verse TEXT NOT NULL, end_verse TEXT NOT NULL, start_index INTEGER NOT NULL, end_index INTEGER NOT NULL, scripture_text TEXT NOT NULL, note_text TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
  CREATE INDEX notes_updated_idx ON notes(updated_at DESC);
  PRAGMA user_version=1;
  INSERT INTO bookmarks VALUES ('web-ce:JHN:1:1:1', 'web-ce', 'JHN', 'John', 42, 1, '1', '1', 0, 0, 'In the beginning.', 1700000000000, 1700000000001);
  INSERT INTO highlights VALUES ('web-ce:JHN:1:1', 'web-ce:JHN:1:1:1:1700000000002', 'web-ce', 'JHN', 'John', 42, 1, '1', 0, 'In the beginning.', 'gold', 1700000000002, 1700000000003);
  INSERT INTO notes VALUES ('web-ce:JHN:1:1:1', 'web-ce', 'JHN', 'John', 42, 1, '1', '1', 0, 0, 'In the beginning.', 'Synthetic migration fixture note.', 1700000000004, 1700000000005);
  COMMIT;
`)
database.exec("BEGIN IMMEDIATE; INSERT INTO bookmarks VALUES ('web-ce:JHN:3:16:16', 'web-ce', 'JHN', 'John', 42, 3, '16', '16', 15, 15, 'For God so loved the world.', 1791228336690, 1791228336691); COMMIT;")

const libraryFixture = join(libraryRoot, "user-library.db")
copyFileSync(databasePath, libraryFixture)
if (!existsSync(`${databasePath}-wal`)) throw new Error("Committed WAL fixture is missing")
copyFileSync(`${databasePath}-wal`, `${libraryFixture}-wal`)

const unsupportedPath = join(variantsRoot, "unsupported-schema.db")
copyFileSync(libraryFixture, unsupportedPath)
copyFileSync(`${libraryFixture}-wal`, `${unsupportedPath}-wal`)
const unsupported = new Database(unsupportedPath)
unsupported.exec("PRAGMA wal_autocheckpoint=0; PRAGMA user_version=77;")
unsupported.close()
for (const suffix of ["-wal", "-shm"]) {
  const sidecar = `${unsupportedPath}${suffix}`
  if (existsSync(sidecar) && readFileSync(sidecar).length === 0) unlinkSync(sidecar)
}

const damagedPath = join(variantsRoot, "damaged-library.db")
writeFileSync(damagedPath, Buffer.from("not a SQLite database: synthetic damaged fixture\n", "utf8"))
writeFileSync(`${damagedPath}-wal`, Buffer.from("synthetic damaged WAL\n", "utf8"))
writeFileSync(`${damagedPath}-shm`, Buffer.from("synthetic damaged SHM\n", "utf8"))

const inputs = [join(outputRoot, "legacy-values.tsv"), join(outputRoot, "invalid-legacy-values.tsv"), libraryFixture, `${libraryFixture}-wal`, join(outputRoot, "expected-state.json")]
const manifest = {
  kind: "synthetic-l04-fixture-inputs",
  legacyKeyCount: Object.keys(fixedValues).length,
  novenaCount: novenas.length,
  unknownLegacyKey: "l04.unknown.preserved",
  libraryRowCounts: { bookmarks: 2, highlights: 1, notes: 1 },
  recentWALBookmarkKey: "web-ce:JHN:3:16:16",
  files: Object.fromEntries(inputs.map((path) => [path.slice(outputRoot.length + 1), createHash("sha256").update(readFileSync(path)).digest("hex")])),
}
writeFileSync(join(outputRoot, "fixture-manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`)
database.close()
console.log(`Prepared synthetic fields (${Object.keys(fixedValues).length} keys, ${novenas.length} novenas) and schema-1 WAL library under ${outputRoot}`)
