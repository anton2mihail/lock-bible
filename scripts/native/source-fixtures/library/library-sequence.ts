import { createHash } from "node:crypto"
import { mkdirSync, writeFileSync, readFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import { Database } from "bun:sqlite"

import {
  applyHighlight,
  deleteSavedItem,
  groupHighlightRows,
  listSavedItems,
  restoreSavedItem,
  saveNote,
  toggleBookmark,
} from "../../../../src/services/library/libraryRepository.ts"
import type { PassageSelection, SavedItem } from "../../../../src/services/library/types.ts"

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../../../..")
const output = resolve(process.argv[2] ?? join(root, "build/native-evidence/L10-L11/library-sequence.json"))
mkdirSync(dirname(output), { recursive: true })

const sourcePaths = [
  "scripts/native/source-fixtures/library/library-sequence.ts",
  "src/services/library/libraryRepository.ts",
  "src/services/library/types.ts",
  "src/services/library/selection.ts",
  "src/services/database/libraryDatabase.ts",
  "src/screens/ReaderScreen.tsx",
  "src/screens/SavedScreen.tsx",
  "src/screens/NoteEditorScreen.tsx",
  "src/screens/ReaderScreen.test.tsx",
  "src/screens/SavedScreen.test.tsx",
  "src/screens/NoteEditorScreen.test.tsx",
]
const sha = (path: string) => createHash("sha256").update(readFileSync(join(root, path))).digest("hex")

const db = new Database(":memory:")
db.exec(`
  CREATE TABLE bookmarks (
    passage_key TEXT PRIMARY KEY NOT NULL, translation_id TEXT NOT NULL, book_code TEXT NOT NULL,
    book_name TEXT NOT NULL, book_order INTEGER NOT NULL, chapter INTEGER NOT NULL,
    start_verse TEXT NOT NULL, end_verse TEXT NOT NULL, start_index INTEGER NOT NULL,
    end_index INTEGER NOT NULL, scripture_text TEXT NOT NULL, created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  );
  CREATE TABLE highlights (
    verse_key TEXT PRIMARY KEY NOT NULL, batch_id TEXT NOT NULL, translation_id TEXT NOT NULL,
    book_code TEXT NOT NULL, book_name TEXT NOT NULL, book_order INTEGER NOT NULL,
    chapter INTEGER NOT NULL, verse TEXT NOT NULL, verse_index INTEGER NOT NULL,
    verse_text TEXT NOT NULL, color TEXT NOT NULL, created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  );
  CREATE TABLE notes (
    passage_key TEXT PRIMARY KEY NOT NULL, translation_id TEXT NOT NULL, book_code TEXT NOT NULL,
    book_name TEXT NOT NULL, book_order INTEGER NOT NULL, chapter INTEGER NOT NULL,
    start_verse TEXT NOT NULL, end_verse TEXT NOT NULL, start_index INTEGER NOT NULL,
    end_index INTEGER NOT NULL, scripture_text TEXT NOT NULL, note_text TEXT NOT NULL,
    created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
  );
`)

const adapter = {
  async getFirstAsync<T>(sql: string, ...args: unknown[]) { return db.query(sql).get(...args) as T | null },
  async getAllAsync<T>(sql: string, ...args: unknown[]) { return db.query(sql).all(...args) as T[] },
  async runAsync(sql: string, ...args: unknown[]) { return db.query(sql).run(...args) },
  async withTransactionAsync(callback: () => Promise<void>) {
    db.exec("BEGIN IMMEDIATE")
    try { await callback(); db.exec("COMMIT") }
    catch (error) { db.exec("ROLLBACK"); throw error }
  },
}

const selection = (start: number, end: number): PassageSelection => {
  const verses = Array.from({ length: end - start + 1 }, (_, offset) => {
    const index = start + offset
    const verse = String(index + 1)
    return { verse, index, text: `Source verse ${verse}` }
  })
  return {
    translationId: "web-ce", bookCode: "JHN", bookName: "John", bookOrder: 65,
    chapter: 3, startVerse: verses[0].verse, endVerse: verses.at(-1)!.verse,
    startIndex: start, endIndex: end,
    scriptureText: verses.map((item) => `${item.verse} ${item.text}`).join(" "), verses,
  }
}

let clock = 1_800_000_000_000
const originalNow = Date.now
Date.now = () => clock++

const snapshots: Record<string, unknown> = {}
const all = () => listSavedItems(adapter as never, "all")
const ids = (items: SavedItem[]) => items.map((item) => item.id)

try {
  const bookmarkPassage = selection(15, 17)
  snapshots.bookmarkAdd = await toggleBookmark(adapter as never, bookmarkPassage)
  snapshots.afterBookmarkAdd = await all()
  snapshots.bookmarkRemove = await toggleBookmark(adapter as never, bookmarkPassage)
  snapshots.afterBookmarkRemove = await all()
  snapshots.bookmarkRestore = await toggleBookmark(adapter as never, bookmarkPassage)

  const highlightActions = [
    { color: "gold", passage: selection(15, 17) },
    { color: "sage", passage: selection(18, 18) },
    { color: "rose", passage: selection(20, 21) },
    { color: "blue", passage: selection(22, 22) },
  ] as const
  for (const item of highlightActions) await applyHighlight(adapter as never, item.passage, item.color)
  snapshots.highlightRows = db.query("SELECT * FROM highlights ORDER BY verse_index").all()
  snapshots.highlightGroups = groupHighlightRows(snapshots.highlightRows as never)

  const notePassage = selection(15, 17)
  await saveNote(adapter as never, notePassage, "  Keep this private note. \n ")
  snapshots.noteAfterTrimmedSave = db.query("SELECT * FROM notes").all()
  await saveNote(adapter as never, notePassage, " \n  ")
  snapshots.noteAfterEmptySave = db.query("SELECT * FROM notes").all()
  await saveNote(adapter as never, notePassage, "Final note")
  snapshots.noteAfterFinalSave = db.query("SELECT * FROM notes").all()

  for (const filter of ["all", "bookmark", "highlight", "note"] as const) {
    const items = await listSavedItems(adapter as never, filter)
    snapshots[`saved-${filter}`] = { ids: ids(items), items }
  }

  const beforeDelete = await all()
  const deleteTarget = beforeDelete.find((item) => item.kind === "highlight" && item.color === "gold")!
  await deleteSavedItem(adapter as never, deleteTarget)
  snapshots.afterDelete = await all()
  await restoreSavedItem(adapter as never, deleteTarget)
  snapshots.afterUndo = await all()
  snapshots.restoredHighlightRows = db.query("SELECT * FROM highlights ORDER BY verse_index").all()

  const result = {
    formatVersion: 1,
    sourceGeneratedBy: "scripts/native/source-fixtures/library/library-sequence.ts",
    sourceHashes: Object.fromEntries(sourcePaths.map((path) => [path, sha(path)])),
    provenance: {
      actions: "The fixture calls the existing libraryRepository functions with an in-memory SQLite adapter.",
      screens: "SavedScreen load/filter and delete/undo callbacks are described from source. The screen test calls deletion and restoration with mocks; it does not run the repository.",
      sourceTestActions: [
        "ReaderScreen.test.tsx: bookmarks, highlights, and opens a note for the selected passage.",
        "ReaderScreen.test.tsx: shows a passage that is already bookmarked, so a second tap reads as removal.",
        "SavedScreen.test.tsx: opens a saved range in the reader.",
        "SavedScreen.test.tsx: deletes a saved item and offers undo.",
        "NoteEditorScreen.test.tsx: loads and saves a private note for the full selected range.",
        "NoteEditorScreen.test.tsx: deletes an existing note.",
      ],
      timestamps: "Date.now is fixed to a sequence starting at 1800000000000 milliseconds.",
      selection: "Passage rows are small synthetic John 3 selections. Verse indexes and labels are exact fixture inputs.",
    },
    request: {
      translationId: "web-ce", bookCode: "JHN", bookName: "John", bookOrder: 65, chapter: 3,
      bookmarkRange: { firstIndex: 15, lastIndex: 17, firstVerse: "16", lastVerse: "18" },
      highlightRanges: highlightActions.map(({ color, passage }) => ({
        color, startIndex: passage.startIndex, endIndex: passage.endIndex,
        startVerse: passage.startVerse, endVerse: passage.endVerse,
      })),
      noteInput: "  Keep this private note. \n ",
    },
    snapshots,
  }
  writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`)
  console.log(`Wrote source library sequence to ${output}`)
} finally {
  Date.now = originalNow
  db.close()
}
