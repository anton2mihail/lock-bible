import type { SQLiteDatabase } from "expo-sqlite"

const LIBRARY_SCHEMA_VERSION = 1

export async function migrateLibraryDatabase(database: SQLiteDatabase): Promise<void> {
  await database.execAsync("PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;")
  const row = await database.getFirstAsync<{ user_version: number }>("PRAGMA user_version")
  const currentVersion = row?.user_version ?? 0

  if (currentVersion < 1) {
    await database.execAsync(`
      CREATE TABLE IF NOT EXISTS bookmarks (
        passage_key TEXT PRIMARY KEY NOT NULL,
        translation_id TEXT NOT NULL,
        book_code TEXT NOT NULL,
        book_name TEXT NOT NULL,
        book_order INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        start_verse TEXT NOT NULL,
        end_verse TEXT NOT NULL,
        start_index INTEGER NOT NULL,
        end_index INTEGER NOT NULL,
        scripture_text TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS bookmarks_updated_idx ON bookmarks(updated_at DESC);

      CREATE TABLE IF NOT EXISTS highlights (
        verse_key TEXT PRIMARY KEY NOT NULL,
        batch_id TEXT NOT NULL,
        translation_id TEXT NOT NULL,
        book_code TEXT NOT NULL,
        book_name TEXT NOT NULL,
        book_order INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        verse TEXT NOT NULL,
        verse_index INTEGER NOT NULL,
        verse_text TEXT NOT NULL,
        color TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS highlights_reference_idx
        ON highlights(translation_id, book_code, chapter, verse_index);
      CREATE INDEX IF NOT EXISTS highlights_updated_idx ON highlights(updated_at DESC);

      CREATE TABLE IF NOT EXISTS notes (
        passage_key TEXT PRIMARY KEY NOT NULL,
        translation_id TEXT NOT NULL,
        book_code TEXT NOT NULL,
        book_name TEXT NOT NULL,
        book_order INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        start_verse TEXT NOT NULL,
        end_verse TEXT NOT NULL,
        start_index INTEGER NOT NULL,
        end_index INTEGER NOT NULL,
        scripture_text TEXT NOT NULL,
        note_text TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS notes_updated_idx ON notes(updated_at DESC);
    `)
  }

  await database.execAsync(`PRAGMA user_version = ${LIBRARY_SCHEMA_VERSION}`)
}
