import type { SQLiteDatabase } from "expo-sqlite"

import type { HighlightColor, PassageSelection, SavedFilter, SavedItem } from "./types"

interface PassageRow {
  passage_key: string
  translation_id: string
  book_code: string
  book_name: string
  book_order: number
  chapter: number
  start_verse: string
  end_verse: string
  start_index: number
  end_index: number
  scripture_text: string
  created_at: number
  updated_at: number
}

interface NoteRow extends PassageRow {
  note_text: string
}

export interface HighlightRow {
  verse_key: string
  batch_id: string
  translation_id: string
  book_code: string
  book_name: string
  book_order: number
  chapter: number
  verse: string
  verse_index: number
  verse_text: string
  color: HighlightColor
  created_at: number
  updated_at: number
}

export function passageKey(
  selection: Pick<
    PassageSelection,
    "translationId" | "bookCode" | "chapter" | "startVerse" | "endVerse"
  >,
): string {
  return [
    selection.translationId,
    selection.bookCode,
    selection.chapter,
    selection.startVerse,
    selection.endVerse,
  ].join(":")
}

export function verseKey(
  translationId: string,
  bookCode: string,
  chapter: number,
  verse: string,
): string {
  return [translationId, bookCode, chapter, verse].join(":")
}

export function passageReference(
  bookName: string,
  chapter: number,
  startVerse: string,
  endVerse: string,
): string {
  const verses = startVerse === endVerse ? startVerse : `${startVerse}–${endVerse}`
  return `${bookName} ${chapter}:${verses}`
}

function rowToSavedItem(row: PassageRow, kind: "bookmark" | "note", noteText?: string): SavedItem {
  return {
    id: `${kind}:${row.passage_key}`,
    kind,
    translationId: row.translation_id,
    bookCode: row.book_code,
    bookName: row.book_name,
    bookOrder: row.book_order,
    chapter: row.chapter,
    startVerse: row.start_verse,
    endVerse: row.end_verse,
    startIndex: row.start_index,
    endIndex: row.end_index,
    scriptureText: row.scripture_text,
    reference: passageReference(row.book_name, row.chapter, row.start_verse, row.end_verse),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    noteText,
  }
}

export function groupHighlightRows(rows: HighlightRow[]): SavedItem[] {
  const groups = new Map<string, HighlightRow[]>()
  for (const row of rows) {
    const key = `${row.batch_id}:${row.book_code}:${row.chapter}:${row.color}`
    const group = groups.get(key) ?? []
    group.push(row)
    groups.set(key, group)
  }

  const items: SavedItem[] = []
  for (const [groupKey, groupRows] of groups) {
    const sorted = [...groupRows].sort((left, right) => left.verse_index - right.verse_index)
    let contiguous: HighlightRow[] = []
    const flush = () => {
      if (!contiguous.length) return
      const first = contiguous[0]
      const last = contiguous[contiguous.length - 1]
      const verseKeys = contiguous.map((row) => row.verse_key)
      items.push({
        id: `highlight:${groupKey}:${first.verse_index}:${last.verse_index}`,
        kind: "highlight",
        translationId: first.translation_id,
        bookCode: first.book_code,
        bookName: first.book_name,
        bookOrder: first.book_order,
        chapter: first.chapter,
        startVerse: first.verse,
        endVerse: last.verse,
        startIndex: first.verse_index,
        endIndex: last.verse_index,
        scriptureText: contiguous.map((row) => `${row.verse} ${row.verse_text}`).join(" "),
        reference: passageReference(first.book_name, first.chapter, first.verse, last.verse),
        createdAt: Math.min(...contiguous.map((row) => row.created_at)),
        updatedAt: Math.max(...contiguous.map((row) => row.updated_at)),
        color: first.color,
        verseKeys,
        highlightVerses: contiguous.map((row) => ({
          verseKey: row.verse_key,
          batchId: row.batch_id,
          verse: row.verse,
          verseIndex: row.verse_index,
          verseText: row.verse_text,
          createdAt: row.created_at,
          updatedAt: row.updated_at,
        })),
      })
      contiguous = []
    }

    for (const row of sorted) {
      const previous = contiguous[contiguous.length - 1]
      if (previous && row.verse_index !== previous.verse_index + 1) flush()
      contiguous.push(row)
    }
    flush()
  }
  return items
}

export async function toggleBookmark(
  database: SQLiteDatabase,
  selection: PassageSelection,
): Promise<boolean> {
  const key = passageKey(selection)
  const existing = await database.getFirstAsync<{ passage_key: string }>(
    "SELECT passage_key FROM bookmarks WHERE passage_key = ?",
    key,
  )
  if (existing) {
    await database.runAsync("DELETE FROM bookmarks WHERE passage_key = ?", key)
    return false
  }

  const now = Date.now()
  await database.runAsync(
    `INSERT INTO bookmarks (
      passage_key, translation_id, book_code, book_name, book_order, chapter,
      start_verse, end_verse, start_index, end_index, scripture_text, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    key,
    selection.translationId,
    selection.bookCode,
    selection.bookName,
    selection.bookOrder,
    selection.chapter,
    selection.startVerse,
    selection.endVerse,
    selection.startIndex,
    selection.endIndex,
    selection.scriptureText,
    now,
    now,
  )
  return true
}

export async function isPassageBookmarked(
  database: SQLiteDatabase,
  selection: PassageSelection,
): Promise<boolean> {
  return !!(await database.getFirstAsync(
    "SELECT 1 FROM bookmarks WHERE passage_key = ?",
    passageKey(selection),
  ))
}

export async function applyHighlight(
  database: SQLiteDatabase,
  selection: PassageSelection,
  color: HighlightColor,
): Promise<void> {
  const now = Date.now()
  const batchId = `${passageKey(selection)}:${now}`
  await database.withTransactionAsync(async () => {
    for (const verse of selection.verses) {
      const key = verseKey(
        selection.translationId,
        selection.bookCode,
        selection.chapter,
        verse.verse,
      )
      await database.runAsync(
        `INSERT OR REPLACE INTO highlights (
          verse_key, batch_id, translation_id, book_code, book_name, book_order,
          chapter, verse, verse_index, verse_text, color, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        key,
        batchId,
        selection.translationId,
        selection.bookCode,
        selection.bookName,
        selection.bookOrder,
        selection.chapter,
        verse.verse,
        verse.index,
        verse.text,
        color,
        now,
        now,
      )
    }
  })
}

export async function clearHighlight(
  database: SQLiteDatabase,
  selection: PassageSelection,
): Promise<void> {
  await database.withTransactionAsync(async () => {
    for (const verse of selection.verses) {
      await database.runAsync(
        "DELETE FROM highlights WHERE verse_key = ?",
        verseKey(selection.translationId, selection.bookCode, selection.chapter, verse.verse),
      )
    }
  })
}

export async function getChapterHighlights(
  database: SQLiteDatabase,
  translationId: string,
  bookCode: string,
  chapter: number,
): Promise<Record<string, HighlightColor>> {
  const rows = await database.getAllAsync<{ verse: string; color: HighlightColor }>(
    `SELECT verse, color FROM highlights
      WHERE translation_id = ? AND book_code = ? AND chapter = ?`,
    translationId,
    bookCode,
    chapter,
  )
  return Object.fromEntries(rows.map((row) => [row.verse, row.color]))
}

export async function getNote(
  database: SQLiteDatabase,
  selection: PassageSelection,
): Promise<string> {
  const row = await database.getFirstAsync<{ note_text: string }>(
    "SELECT note_text FROM notes WHERE passage_key = ?",
    passageKey(selection),
  )
  return row?.note_text ?? ""
}

export async function saveNote(
  database: SQLiteDatabase,
  selection: PassageSelection,
  noteText: string,
): Promise<void> {
  const trimmed = noteText.trim()
  const key = passageKey(selection)
  if (!trimmed) {
    await database.runAsync("DELETE FROM notes WHERE passage_key = ?", key)
    return
  }
  const now = Date.now()
  await database.runAsync(
    `INSERT INTO notes (
      passage_key, translation_id, book_code, book_name, book_order, chapter,
      start_verse, end_verse, start_index, end_index, scripture_text,
      note_text, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(passage_key) DO UPDATE SET
      note_text = excluded.note_text,
      scripture_text = excluded.scripture_text,
      updated_at = excluded.updated_at`,
    key,
    selection.translationId,
    selection.bookCode,
    selection.bookName,
    selection.bookOrder,
    selection.chapter,
    selection.startVerse,
    selection.endVerse,
    selection.startIndex,
    selection.endIndex,
    selection.scriptureText,
    trimmed,
    now,
    now,
  )
}

export async function deleteNote(
  database: SQLiteDatabase,
  selection: PassageSelection,
): Promise<void> {
  await database.runAsync("DELETE FROM notes WHERE passage_key = ?", passageKey(selection))
}

export async function listSavedItems(
  database: SQLiteDatabase,
  filter: SavedFilter = "all",
): Promise<SavedItem[]> {
  const items: SavedItem[] = []
  if (filter === "all" || filter === "bookmark") {
    const rows = await database.getAllAsync<PassageRow>(
      "SELECT * FROM bookmarks ORDER BY updated_at DESC",
    )
    items.push(...rows.map((row) => rowToSavedItem(row, "bookmark")))
  }
  if (filter === "all" || filter === "note") {
    const rows = await database.getAllAsync<NoteRow>("SELECT * FROM notes ORDER BY updated_at DESC")
    items.push(...rows.map((row) => rowToSavedItem(row, "note", row.note_text)))
  }
  if (filter === "all" || filter === "highlight") {
    const rows = await database.getAllAsync<HighlightRow>(
      "SELECT * FROM highlights ORDER BY updated_at DESC, verse_index",
    )
    items.push(...groupHighlightRows(rows))
  }
  return items.sort((left, right) => right.updatedAt - left.updatedAt)
}

export async function deleteSavedItem(database: SQLiteDatabase, item: SavedItem): Promise<void> {
  if (item.kind === "bookmark") {
    await database.runAsync("DELETE FROM bookmarks WHERE passage_key = ?", item.id.slice(9))
  } else if (item.kind === "note") {
    await database.runAsync("DELETE FROM notes WHERE passage_key = ?", item.id.slice(5))
  } else {
    await database.withTransactionAsync(async () => {
      for (const key of item.verseKeys ?? []) {
        await database.runAsync("DELETE FROM highlights WHERE verse_key = ?", key)
      }
    })
  }
}

export async function restoreSavedItem(database: SQLiteDatabase, item: SavedItem): Promise<void> {
  const key = [
    item.translationId,
    item.bookCode,
    item.chapter,
    item.startVerse,
    item.endVerse,
  ].join(":")
  if (item.kind === "bookmark") {
    await database.runAsync(
      `INSERT OR REPLACE INTO bookmarks (
        passage_key, translation_id, book_code, book_name, book_order, chapter,
        start_verse, end_verse, start_index, end_index, scripture_text, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      key,
      item.translationId,
      item.bookCode,
      item.bookName,
      item.bookOrder,
      item.chapter,
      item.startVerse,
      item.endVerse,
      item.startIndex,
      item.endIndex,
      item.scriptureText,
      item.createdAt,
      item.updatedAt,
    )
    return
  }
  if (item.kind === "note") {
    await database.runAsync(
      `INSERT OR REPLACE INTO notes (
        passage_key, translation_id, book_code, book_name, book_order, chapter,
        start_verse, end_verse, start_index, end_index, scripture_text,
        note_text, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      key,
      item.translationId,
      item.bookCode,
      item.bookName,
      item.bookOrder,
      item.chapter,
      item.startVerse,
      item.endVerse,
      item.startIndex,
      item.endIndex,
      item.scriptureText,
      item.noteText ?? "",
      item.createdAt,
      item.updatedAt,
    )
    return
  }

  await database.withTransactionAsync(async () => {
    for (const verse of item.highlightVerses ?? []) {
      await database.runAsync(
        `INSERT OR REPLACE INTO highlights (
          verse_key, batch_id, translation_id, book_code, book_name, book_order,
          chapter, verse, verse_index, verse_text, color, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        verse.verseKey,
        verse.batchId,
        item.translationId,
        item.bookCode,
        item.bookName,
        item.bookOrder,
        item.chapter,
        verse.verse,
        verse.verseIndex,
        verse.verseText,
        item.color ?? "gold",
        verse.createdAt,
        verse.updatedAt,
      )
    }
  })
}
