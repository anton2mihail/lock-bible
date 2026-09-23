/**
 * The patristic works data seam.
 *
 * Two stores, split by what each is for. The catalog - collections, the work
 * manifest and the chapter-to-homily index - is bundled JSON, small and
 * synchronous, so the library lists instantly and the Bible reader can offer a
 * Father beside a chapter without awaiting anything. The section text lives in
 * works.db, a flat SQLite asset, because it is all of the bytes and none of it
 * is needed until someone opens a homily.
 *
 * Following the Bible services, functions that touch the database take it as a
 * parameter; screens get the handle from `useWorksDatabase()`.
 */
import type { SQLiteDatabase } from "expo-sqlite"
import { strFromU8, unzlibSync } from "fflate"

import { load, save } from "@/utils/storage"

import catalog from "./data/catalog.json"
import type {
  ChapterCommentary,
  ReadingPosition,
  WorkMeta,
  WorkSection,
  WorksCollectionMeta,
} from "./types"

const POSITION_KEY = "works.position.v1"

/** Every author's corpus, in shelf order. */
export const COLLECTIONS: readonly WorksCollectionMeta[] = (
  catalog.collections as WorksCollectionMeta[]
)
  .slice()
  .sort((a, b) => a.order - b.order)

const collectionOrder = new Map(COLLECTIONS.map((collection, index) => [collection.id, index]))

/**
 * Every work, shelf by shelf. `order` restarts at 1 in each collection, so it
 * only sorts within one; the collection's own position breaks the tie.
 */
export const WORKS: readonly WorkMeta[] = (catalog.works as WorkMeta[])
  .slice()
  .sort(
    (a, b) =>
      (collectionOrder.get(a.collectionId) ?? 0) - (collectionOrder.get(b.collectionId) ?? 0) ||
      a.order - b.order,
  )

/** Bible book code -> chapter -> the homilies expounding it. */
const COMMENTARY = catalog.commentary as Record<string, Record<string, ChapterCommentary[]>>

const worksByCollection = new Map<string, WorkMeta[]>()
for (const work of WORKS) {
  const bucket = worksByCollection.get(work.collectionId)
  if (bucket) bucket.push(work)
  else worksByCollection.set(work.collectionId, [work])
}

export function getCollection(id: string | undefined): WorksCollectionMeta | undefined {
  return COLLECTIONS.find((collection) => collection.id === id)
}

export function getWorkMeta(id: string | undefined): WorkMeta | undefined {
  return WORKS.find((work) => work.id === id)
}

/** The works in one collection, ready to list. */
export function getCollectionWorks(collectionId: string | undefined): readonly WorkMeta[] {
  return collectionId ? (worksByCollection.get(collectionId) ?? []) : []
}

/**
 * The homilies that expound a given chapter of Scripture, so the Bible reader
 * can offer the Fathers beside the chapter being read. Empty for the books
 * none of them commented on, which is most of the Old Testament.
 */
export function getChapterCommentary(
  bookCode: string | undefined,
  chapter: number | undefined,
): readonly ChapterCommentary[] {
  if (!bookCode || !chapter) return []
  return COMMENTARY[bookCode]?.[String(chapter)] ?? []
}

/** Whether any work comments on this book at all, for cheap list-level checks. */
export function hasCommentary(bookCode: string | undefined): boolean {
  return Boolean(bookCode && COMMENTARY[bookCode])
}

type SectionRow = { idx: number; title: string; words: number; paragraphs: Uint8Array | string }

/**
 * Section text is stored deflated - 15 million words is 107MB as plain text
 * and 43MB this way, which is the difference between an app people will
 * download and one they will not. Inflating a section costs a millisecond or
 * two, against a read that is already asynchronous.
 *
 * A string is accepted as well so that a database built before compression, or
 * a driver that hands back text, still reads rather than throwing.
 */
function decodeParagraphs(value: Uint8Array | string): readonly string[] {
  const json = typeof value === "string" ? value : strFromU8(unzlibSync(value))
  return JSON.parse(json) as string[]
}

/**
 * One section's text. This is the only call that touches the database, and it
 * is deliberately a single section: the largest work in the corpus is 432,000
 * words, and reading homily 40 should not pull homilies 1-39 into memory.
 */
export async function loadSection(
  database: SQLiteDatabase,
  workId: string,
  index: number,
): Promise<WorkSection | undefined> {
  const row = await database.getFirstAsync<SectionRow>(
    "SELECT idx, title, words, paragraphs FROM sections WHERE work_id = ? AND idx = ?",
    [workId, index],
  )
  if (!row) return undefined
  return {
    index: row.idx,
    title: row.title,
    words: row.words,
    paragraphs: decodeParagraphs(row.paragraphs),
  }
}

/** Every section title in a work, for a table of contents. Text is not loaded. */
export async function loadSectionTitles(
  database: SQLiteDatabase,
  workId: string,
): Promise<readonly { index: number; title: string; words: number }[]> {
  const rows = await database.getAllAsync<Omit<SectionRow, "paragraphs">>(
    "SELECT idx, title, words FROM sections WHERE work_id = ? ORDER BY idx",
    [workId],
  )
  return rows.map((row) => ({ index: row.idx, title: row.title, words: row.words }))
}

/** Roughly how long a work takes to read, at a gentle 200 words a minute. */
export function readingMinutes(words: number): number {
  return Math.max(1, Math.round(words / 200))
}

export function formatReadingLength(words: number): string {
  const minutes = readingMinutes(words)
  if (minutes < 60) return `${minutes} min`
  const hours = Math.round(minutes / 60)
  return hours === 1 ? "about an hour" : `about ${hours} hours`
}

type PositionsById = Record<string, ReadingPosition>

function allPositions(): PositionsById {
  const stored = load<unknown>(POSITION_KEY)
  return stored && typeof stored === "object" ? (stored as PositionsById) : {}
}

export function getReadingPosition(workId: string): ReadingPosition | undefined {
  const position = allPositions()[workId]
  if (!position || typeof position.sectionIndex !== "number") return undefined
  return position
}

/**
 * Remembers where the reader stopped. `pageIndex` is tied to the current type
 * size, so it is a hint rather than a promise: changing the text size
 * repaginates, and the section is what actually matters.
 */
export function saveReadingPosition(
  workId: string,
  sectionIndex: number,
  pageIndex: number,
  now = Date.now(),
): void {
  const positions = allPositions()
  positions[workId] = { workId, sectionIndex, pageIndex, updatedAt: now }
  save(POSITION_KEY, positions)
}

/** The work most recently read, for the "continue" card. */
export function getLastRead(): { work: WorkMeta; position: ReadingPosition } | undefined {
  const positions = Object.values(allPositions())
  if (!positions.length) return undefined
  const latest = positions.reduce((a, b) => (a.updatedAt > b.updatedAt ? a : b))
  const work = getWorkMeta(latest.workId)
  return work ? { work, position: latest } : undefined
}
