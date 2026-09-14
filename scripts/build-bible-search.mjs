#!/usr/bin/env node

import { Database } from "bun:sqlite"
import { createHash } from "node:crypto"
import { existsSync, readdirSync, readFileSync, rmSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const scriptDir = dirname(fileURLToPath(import.meta.url))
const rootDir = join(scriptDir, "..")
const dataRoot = join(rootDir, "src", "services", "bible", "data")
const outputPath = join(rootDir, "assets", "bible", "bible-search.db")
const translationDirs = readdirSync(dataRoot)
  .map((name) => join(dataRoot, name))
  .filter((directory) => existsSync(join(directory, "manifest.json")))

if (existsSync(outputPath)) rmSync(outputPath)

const database = new Database(outputPath, { create: true })
database.exec(`
  PRAGMA journal_mode = OFF;
  PRAGMA synchronous = OFF;
  PRAGMA temp_store = MEMORY;
  CREATE TABLE metadata (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL
  );
  CREATE TABLE books (
    translation_id TEXT NOT NULL,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    long_name TEXT NOT NULL,
    group_name TEXT NOT NULL,
    book_order INTEGER NOT NULL,
    chapter_count INTEGER NOT NULL,
    PRIMARY KEY (translation_id, code)
  );
  CREATE TABLE verses (
    id INTEGER PRIMARY KEY NOT NULL,
    translation_id TEXT NOT NULL,
    book_code TEXT NOT NULL,
    book_name TEXT NOT NULL,
    book_order INTEGER NOT NULL,
    group_name TEXT NOT NULL,
    chapter INTEGER NOT NULL,
    verse TEXT NOT NULL,
    verse_order INTEGER NOT NULL,
    text TEXT NOT NULL
  );
  CREATE INDEX verses_reference_idx
    ON verses (translation_id, book_code, chapter, verse_order);
  CREATE VIRTUAL TABLE verse_search USING fts5(
    text,
    book_name,
    content='verses',
    content_rowid='id',
    tokenize='unicode61 remove_diacritics 2'
  );
  CREATE TABLE vocabulary (
    translation_id TEXT NOT NULL,
    word TEXT NOT NULL,
    frequency INTEGER NOT NULL,
    PRIMARY KEY (translation_id, word)
  );
`)

const insertBook = database.prepare(`
  INSERT INTO books (
    translation_id, code, name, long_name, group_name, book_order, chapter_count
  ) VALUES (?, ?, ?, ?, ?, ?, ?)
`)
const insertVerse = database.prepare(`
  INSERT INTO verses (
    translation_id, book_code, book_name, book_order, group_name,
    chapter, verse, verse_order, text
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
`)
const insertVocabulary = database.prepare(
  "INSERT INTO vocabulary (translation_id, word, frequency) VALUES (?, ?, ?)",
)
const insertMetadata = database.prepare("INSERT INTO metadata (key, value) VALUES (?, ?)")

const sourceHash = createHash("sha256")
let verseCount = 0
const translationCounts = new Map()

function wordsIn(text) {
  return (
    text
      .normalize("NFKD")
      .replace(/\p{Mark}/gu, "")
      .toLocaleLowerCase("en")
      .match(/[\p{Letter}\p{Number}]+(?:['’][\p{Letter}\p{Number}]+)*/gu) ?? []
  )
}

database.exec("BEGIN IMMEDIATE")
try {
  for (const dataDir of translationDirs) {
    const manifest = JSON.parse(readFileSync(join(dataDir, "manifest.json"), "utf8"))
    const meta = JSON.parse(readFileSync(join(dataDir, "meta.json"), "utf8"))
    const vocabulary = new Map()
    let currentCount = 0

    for (const bookMeta of manifest) {
      const raw = readFileSync(join(dataDir, `${bookMeta.code}.json`), "utf8")
      const book = JSON.parse(raw)
      sourceHash.update(meta.id).update(raw)
      insertBook.run(
        meta.id,
        bookMeta.code,
        bookMeta.name,
        bookMeta.longName,
        bookMeta.group,
        bookMeta.order,
        bookMeta.chapterCount,
      )

      for (const chapter of book.chapters) {
        chapter.verses.forEach((verse, verseIndex) => {
          insertVerse.run(
            meta.id,
            book.code,
            book.name,
            bookMeta.order,
            book.group,
            chapter.c,
            verse.n,
            verseIndex,
            verse.t,
          )
          verseCount += 1
          currentCount += 1
          for (const word of wordsIn(`${book.name} ${verse.t}`)) {
            vocabulary.set(word, (vocabulary.get(word) ?? 0) + 1)
          }
        })
      }
    }

    for (const [word, frequency] of vocabulary) {
      if (word.length >= 3 || frequency >= 5) insertVocabulary.run(meta.id, word, frequency)
    }
    translationCounts.set(meta.id, currentCount)
  }

  database.exec("INSERT INTO verse_search(verse_search) VALUES('rebuild')")
  insertMetadata.run("translation_ids", [...translationCounts.keys()].join(","))
  insertMetadata.run("verse_count", String(verseCount))
  for (const [translationId, count] of translationCounts) {
    insertMetadata.run(`verse_count:${translationId}`, String(count))
  }
  insertMetadata.run("source_sha256", sourceHash.digest("hex"))
  insertMetadata.run("schema_version", "1")
  database.exec("COMMIT")
  database.exec("ANALYZE; VACUUM;")
} catch (error) {
  database.exec("ROLLBACK")
  throw error
} finally {
  database.close()
}

console.log(
  `Built ${outputPath} with ${verseCount.toLocaleString()} verses across ${translationCounts.size} translations.`,
)
