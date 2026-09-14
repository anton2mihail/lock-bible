import type { SQLiteDatabase } from "expo-sqlite"

import { listBooks } from "./bibleService"
import { getTranslationId } from "./preferences"
import { editDistance, parseBibleReference } from "./referenceParser"
import type { BookGroup } from "./types"

export type SearchScope = "all" | "ot" | "nt"

export interface BibleSearchResult {
  id: number
  bookCode: string
  bookName: string
  group: BookGroup
  chapter: number
  verse: string
  verseOrder: number
  text: string
  reference: string
}

export interface BibleSearchResponse {
  results: BibleSearchResult[]
  correctedQuery?: string
  isReference: boolean
}

interface VerseRow {
  id: number
  book_code: string
  book_name: string
  group_name: BookGroup
  chapter: number
  verse: string
  verse_order: number
  text: string
}

interface VocabularyRow {
  word: string
  frequency: number
}

function mapResult(row: VerseRow): BibleSearchResult {
  return {
    id: row.id,
    bookCode: row.book_code,
    bookName: row.book_name,
    group: row.group_name,
    chapter: row.chapter,
    verse: row.verse,
    verseOrder: row.verse_order,
    text: row.text,
    reference: `${row.book_name} ${row.chapter}:${row.verse}`,
  }
}

function scopeClause(scope: SearchScope): string {
  if (scope === "nt") return " AND v.group_name = 'nt'"
  if (scope === "ot") return " AND v.group_name IN ('ot', 'deutero')"
  return ""
}

function searchableTokens(query: string): string[] {
  return (
    query
      .normalize("NFKD")
      .replace(/\p{Mark}/gu, "")
      .toLocaleLowerCase("en")
      .match(/[\p{Letter}\p{Number}]+(?:['’][\p{Letter}\p{Number}]+)*/gu) ?? []
  )
}

export function buildFtsQuery(query: string): string | null {
  const phrase = query.trim().match(/^"(.+)"$/)
  if (phrase) {
    const cleaned = searchableTokens(phrase[1]).join(" ")
    return cleaned ? `"${cleaned.replace(/"/g, '""')}"` : null
  }
  const tokens = searchableTokens(query)
  if (!tokens.length) return null
  return tokens.map((token) => `"${token.replace(/"/g, '""')}"*`).join(" AND ")
}

async function runTextSearch(
  database: SQLiteDatabase,
  translationId: string,
  query: string,
  scope: SearchScope,
  limit: number,
): Promise<BibleSearchResult[]> {
  const ftsQuery = buildFtsQuery(query)
  if (!ftsQuery) return []
  const rows = await database.getAllAsync<VerseRow>(
    `SELECT v.id, v.book_code, v.book_name, v.group_name, v.chapter,
            v.verse, v.verse_order, v.text
       FROM verse_search
       JOIN verses v ON v.id = verse_search.rowid
      WHERE verse_search MATCH ?
        AND v.translation_id = ?${scopeClause(scope)}
      ORDER BY bm25(verse_search), v.book_order, v.chapter, v.verse_order
      LIMIT ?`,
    ftsQuery,
    translationId,
    limit,
  )
  return rows.map(mapResult)
}

async function correctedWord(
  database: SQLiteDatabase,
  translationId: string,
  token: string,
): Promise<string> {
  if (token.length < 4) return token
  const exact = await database.getFirstAsync<{ word: string }>(
    "SELECT word FROM vocabulary WHERE translation_id = ? AND word = ?",
    translationId,
    token,
  )
  if (exact) return token

  // Two edits covers common adjacent-key and transposition mistakes such as
  // "fiath" while still keeping very short words conservative.
  const maximum = token.length >= 5 ? 2 : 1
  const candidates = await database.getAllAsync<VocabularyRow>(
    `SELECT word, frequency
       FROM vocabulary
      WHERE translation_id = ?
        AND substr(word, 1, 1) = substr(?, 1, 1)
        AND length(word) BETWEEN ? AND ?
      ORDER BY frequency DESC
      LIMIT 300`,
    translationId,
    token,
    token.length - maximum,
    token.length + maximum,
  )
  const matches = candidates
    .map((candidate) => ({ ...candidate, distance: editDistance(token, candidate.word, maximum) }))
    .filter((candidate) => candidate.distance <= maximum)
    .sort((left, right) => left.distance - right.distance || right.frequency - left.frequency)
  return matches[0]?.word ?? token
}

async function correctQuery(
  database: SQLiteDatabase,
  translationId: string,
  query: string,
): Promise<string> {
  if (query.trim().startsWith('"')) return query
  const tokens = searchableTokens(query)
  const corrected = await Promise.all(
    tokens.map((token) => correctedWord(database, translationId, token)),
  )
  return corrected.join(" ")
}

export async function searchBible(
  database: SQLiteDatabase,
  rawQuery: string,
  scope: SearchScope = "all",
  limit = 60,
): Promise<BibleSearchResponse> {
  const query = rawQuery.trim()
  if (!query) return { results: [], isReference: false }
  const translationId = getTranslationId()

  const reference = parseBibleReference(query, listBooks())
  if (reference) {
    const params: (string | number)[] = [translationId, reference.book.code, reference.chapter]
    let verseClause = ""
    if (reference.startVerse) {
      const start = Number.parseInt(reference.startVerse, 10)
      const end = Number.parseInt(reference.endVerse ?? reference.startVerse, 10)
      verseClause = " AND CAST(v.verse AS INTEGER) BETWEEN ? AND ?"
      params.push(Math.min(start, end), Math.max(start, end))
    }
    params.push(limit)
    const rows = await database.getAllAsync<VerseRow>(
      `SELECT v.id, v.book_code, v.book_name, v.group_name, v.chapter,
              v.verse, v.verse_order, v.text
         FROM verses v
        WHERE v.translation_id = ?
          AND v.book_code = ? AND v.chapter = ?${verseClause}${scopeClause(scope)}
        ORDER BY v.verse_order
        LIMIT ?`,
      params,
    )
    return { results: rows.map(mapResult), isReference: true }
  }

  const results = await runTextSearch(database, translationId, query, scope, limit)
  if (results.length) return { results, isReference: false }

  const correctedQuery = await correctQuery(database, translationId, query)
  if (correctedQuery === searchableTokens(query).join(" ")) {
    return { results: [], isReference: false }
  }
  const correctedResults = await runTextSearch(
    database,
    translationId,
    correctedQuery,
    scope,
    limit,
  )
  return {
    results: correctedResults,
    correctedQuery: correctedResults.length ? correctedQuery : undefined,
    isReference: false,
  }
}
