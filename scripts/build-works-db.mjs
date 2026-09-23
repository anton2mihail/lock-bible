#!/usr/bin/env bun
/**
 * Pack every patristic collection into the SQLite database the app ships.
 *
 *   bun scripts/build-works-db.mjs
 *
 * Why a database rather than the bundled JSON this replaces: importing JSON
 * makes Metro inline it as JavaScript source, which Hermes then compiles to
 * bytecode. Chrysostom alone cost 12.8MB on disk and 37MB of main.jsbundle - a
 * 2.9x tax. The Bible already avoids this by shipping a .db as a flat asset,
 * memory-mapped instead of parsed, and the works now do the same.
 *
 * The split matters. Section TEXT lives in SQLite, because it is all of the
 * bytes and none of it is needed until someone opens a homily. Everything the
 * UI needs to navigate - the collection list, the work manifest, the
 * chapter-to-homily index - stays in a small bundled catalog.json, so browsing
 * the library and offering a Father beside a Bible chapter stay synchronous.
 *
 * Input is the intermediate JSON under src/services/works/data/<collection>/,
 * whatever produced it (build-works-data.mjs for an EPUB, fetch-ccel.mjs for
 * CCEL). Adding a collection means dropping a directory there and re-running.
 */
import { Database } from "bun:sqlite"
import { Buffer } from "node:buffer"
import {
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { deflateSync } from "node:zlib"

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..")
const DATA_ROOT = join(ROOT, "src", "services", "works", "data")
const DB_PATH = join(ROOT, "assets", "works", "works.db")
const CATALOG_PATH = join(DATA_ROOT, "catalog.json")

/**
 * How a work reads, which is how the library groups it. A commentary is
 * anything that walks a book of Scripture in order; the rest are grouped by
 * what the reader is actually picking up. Derived from the title because that
 * is what the sources give us, with the ambiguous ones named outright.
 */
const KIND_OVERRIDES = {
  "the-confessions": "autobiography",
  "the-city-of-god": "treatise",
  "the-imitation-of-christ": "devotional",
  "the-holy-rule-of-st-benedict": "rule",
  "the-ecclesiastical-history-of-the-english-people": "history",
  // Letters and sermons bound together; the letters dominate the volume.
  "the-letters-and-sermons-of-leo-the-great": "letters",
}

// "Epistle" as the head noun means the work IS a letter ("Epistle XVII: To
// Valentinian II", "First Epistle to the Corinthians"). "Epistle" governed by
// a preposition means the work is ABOUT one ("Against the Epistle of
// Manichaeus", "A Treatise on the Spirit and the Letter"), and shelving those
// under Letters makes the library claim something false about them.
const LETTERS_TITLE =
  /^(?:(?:the|a|an|first|second|third|select|selected|some|two|four|seven)\s+)*(?:letter|epistle|correspondence|register)/

function kindFor(id, title, book) {
  if (KIND_OVERRIDES[id]) return KIND_OVERRIDES[id]
  const t = title.toLowerCase()
  if (book) return "commentary"
  if (/\bhomil|\btractate|\bsermon|\bdiscourse|\blecture/.test(t)) return "sermons"
  // Anchored, because a title merely CONTAINING the word is usually a treatise
  // about one: "A Treatise on the Spirit and the Letter", "Against the Epistle
  // of Manichaeus", "Answer to the Letters of Petilian". Shelving those under
  // Letters makes the library claim something false about them.
  if (LETTERS_TITLE.test(t)) return "letters"
  if (/^(the\s+)?(holy\s+)?rule\b|\bthe institutes\b/.test(t)) return "rule"
  if (/\bhistory|\bchronicle|\blives?\b|\blife of\b/.test(t)) return "history"
  if (/\bprayer|\bmeditation|\bsoliloqu/.test(t)) return "prayers"
  return "treatise"
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"))
}

function collectionDirs() {
  if (!existsSync(DATA_ROOT)) throw new Error(`No data directory at ${DATA_ROOT}`)
  return readdirSync(DATA_ROOT)
    .map((name) => join(DATA_ROOT, name))
    .filter((dir) => statSync(dir).isDirectory() && existsSync(join(dir, "meta.json")))
    .sort()
}

mkdirSync(dirname(DB_PATH), { recursive: true })
if (existsSync(DB_PATH)) rmSync(DB_PATH)

const database = new Database(DB_PATH, { create: true })
// Section text is deflated, which is what makes the corpus shippable: 15
// million words is 107MB stored as plain text and 43MB stored this way. The
// page size matters nearly as much as the compression - each section is one
// large value, and 64KB pages waste far less on the tail page of an overflow
// chain than the 4KB default. Both must be set before any table exists.
database.exec(`
  PRAGMA page_size = 65536;
  PRAGMA journal_mode = OFF;
  PRAGMA synchronous = OFF;
  PRAGMA temp_store = MEMORY;
  CREATE TABLE metadata (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL
  );
  CREATE TABLE sections (
    work_id TEXT NOT NULL,
    idx INTEGER NOT NULL,
    title TEXT NOT NULL,
    words INTEGER NOT NULL,
    paragraphs BLOB NOT NULL,
    PRIMARY KEY (work_id, idx)
  ) WITHOUT ROWID;
`)

const insertSection = database.prepare(
  "INSERT INTO sections (work_id, idx, title, words, paragraphs) VALUES (?, ?, ?, ?, ?)",
)
const insertMeta = database.prepare("INSERT INTO metadata (key, value) VALUES (?, ?)")

const catalog = { collections: [], works: [], commentary: {} }
let totalSections = 0
let totalWords = 0

const writeAll = database.transaction((dirs) => {
  for (const dir of dirs) {
    const meta = readJson(join(dir, "meta.json"))
    const manifest = readJson(join(dir, "manifest.json"))
    const chapterIndexPath = join(dir, "chapterIndex.json")
    const chapterIndex = existsSync(chapterIndexPath) ? readJson(chapterIndexPath) : {}

    catalog.collections.push({
      id: meta.id,
      title: meta.title,
      author: meta.author,
      era: meta.era ?? null,
      translation: meta.translation,
      attribution: meta.attribution,
      workCount: manifest.length,
      sectionCount: meta.sectionCount,
      words: meta.words,
      order: meta.order ?? catalog.collections.length,
    })

    for (const work of [...manifest].sort((a, b) => a.order - b.order)) {
      const source = readJson(join(dir, `${work.id}.json`))
      // Qualified because slugs repeat across authors - Augustine and
      // Tertullian both wrote "On Patience" - and the reader addresses a work
      // by id alone, with no collection in the route.
      const workId = `${meta.id}.${work.id}`
      source.sections.forEach((section, idx) => {
        insertSection.run(
          workId,
          idx,
          section.title,
          section.words ?? section.paragraphs.join(" ").split(/\s+/).length,
          deflateSync(Buffer.from(JSON.stringify(section.paragraphs), "utf8"), { level: 9 }),
        )
      })
      totalSections += source.sections.length
      totalWords += work.words

      catalog.works.push({
        id: workId,
        collectionId: meta.id,
        title: work.title,
        order: work.order,
        sectionCount: work.sectionCount,
        words: work.words,
        book: work.book ?? null,
        kind: work.kind ?? kindFor(work.id, work.title, work.book),
      })
    }

    // Commentary entries are merged across collections so a single chapter can
    // offer several Fathers at once, which is the whole point of the feature.
    for (const [book, chapters] of Object.entries(chapterIndex)) {
      const target = (catalog.commentary[book] ??= {})
      for (const [chapter, entries] of Object.entries(chapters)) {
        ;(target[chapter] ??= []).push(
          ...entries.map((e) => ({
            ...e,
            workId: `${meta.id}.${e.workId}`,
            collectionId: meta.id,
          })),
        )
      }
    }
  }
})

const dirs = collectionDirs()
writeAll(dirs)

insertMeta.run("schemaVersion", "2")
// Recorded so a reader can tell how to decode the column rather than guess.
insertMeta.run("paragraphEncoding", "zlib-json")
insertMeta.run("sectionCount", String(totalSections))
insertMeta.run("words", String(totalWords))
insertMeta.run("collections", catalog.collections.map((c) => c.id).join(","))

database.exec("VACUUM;")
database.close()

catalog.collections.sort((a, b) => a.order - b.order)
writeFileSync(CATALOG_PATH, JSON.stringify(catalog) + "\n")

const dbBytes = statSync(DB_PATH).size
const catalogBytes = statSync(CATALOG_PATH).size
const mb = (n) => `${(n / 1048576).toFixed(2)}MB`
console.log(`collections  ${catalog.collections.length}`)
console.log(`works        ${catalog.works.length}`)
console.log(`sections     ${totalSections.toLocaleString()}`)
console.log(`words        ${totalWords.toLocaleString()}`)
console.log(`works.db     ${mb(dbBytes)}  (flat asset, deflated sections)`)
console.log(`catalog.json ${mb(catalogBytes)}  (bundled, keeps navigation synchronous)`)
