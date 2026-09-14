#!/usr/bin/env node

import { Database } from "bun:sqlite"
import { statSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const scriptDir = dirname(fileURLToPath(import.meta.url))
const databasePath = join(scriptDir, "..", "assets", "bible", "bible-search.db")
const database = new Database(databasePath, { readonly: true })

function scalar(sql, ...params) {
  return database.prepare(sql).get(...params)
}

const indexed = scalar("SELECT count(*) AS count FROM verses").count
const metadata = Number(scalar("SELECT value FROM metadata WHERE key = 'verse_count'").value)
const translationIds = scalar(
  "SELECT value FROM metadata WHERE key = 'translation_ids'",
).value.split(",")

if (translationIds.length !== 3 || metadata !== indexed) {
  throw new Error(`Expected 3 translations and ${indexed} metadata verses, found ${metadata}.`)
}

for (const translationId of translationIds) {
  const verses = scalar(
    "SELECT count(*) AS count FROM verses WHERE translation_id = ?",
    translationId,
  ).count
  const expected = Number(
    scalar("SELECT value FROM metadata WHERE key = ?", `verse_count:${translationId}`).value,
  )
  const books = scalar(
    "SELECT count(*) AS count FROM books WHERE translation_id = ?",
    translationId,
  ).count
  const john316 = scalar(
    `SELECT text FROM verses
      WHERE translation_id = ? AND book_code = 'JHN' AND chapter = 3 AND verse = '16'`,
    translationId,
  )
  const searchTerm = translationId === "vulgate" ? "Deus" : "faith"
  const fullTextSearch = scalar(
    `SELECT count(*) AS count
       FROM verse_search
       JOIN verses v ON v.id = verse_search.rowid
      WHERE verse_search MATCH ? AND v.translation_id = ?`,
    searchTerm,
    translationId,
  ).count

  if (verses !== expected || books !== 73) {
    throw new Error(
      `${translationId}: expected 73 books and ${expected} verses, found ${books}/${verses}.`,
    )
  }
  if (!john316?.text || fullTextSearch < 1) {
    throw new Error(`${translationId}: reference or full-text lookup failed.`)
  }
}

database.close()
console.log(
  `Verified ${translationIds.length} translations, 73 books each, ${indexed.toLocaleString()} verses, reference/full-text lookup, and ${(statSync(databasePath).size / 1_048_576).toFixed(1)} MB asset size.`,
)
