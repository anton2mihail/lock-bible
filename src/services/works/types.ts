/** A single homily, letter or treatise within a work. */
export type WorkSection = {
  /** Index within the work; stable, and what a reading position points at. */
  index: number
  title: string
  words: number
  paragraphs: readonly string[]
}

/**
 * How a work reads, which is how the library groups it. Most of the corpus
 * expounds no particular chapter of Scripture, so this - not `book` - is what
 * gives a treatise or a rule its place on the shelf.
 */
export type WorkKind =
  | "commentary"
  | "sermons"
  | "letters"
  | "treatise"
  | "prayers"
  | "devotional"
  | "autobiography"
  | "history"
  | "rule"

/** The manifest entry for a work, bundled so the library lists without I/O. */
export type WorkMeta = {
  id: string
  collectionId: string
  title: string
  order: number
  sectionCount: number
  words: number
  /** The Bible book this work expounds, if it is a commentary on one. */
  book: string | null
  kind: WorkKind
}

/** A homily that expounds a particular chapter of Scripture. */
export type ChapterCommentary = {
  workId: string
  workTitle: string
  collectionId: string
  sectionIndex: number
  sectionTitle: string
}

/** One author's corpus: the unit the library browses by. */
export type WorksCollectionMeta = {
  id: string
  title: string
  author: string
  /** e.g. "Greek Father, 4th century". Null until a collection supplies one. */
  era: string | null
  translation: string
  attribution: string
  workCount: number
  sectionCount: number
  words: number
  order: number
}

/** Where the reader left off, stored per work on the device. */
export type ReadingPosition = {
  workId: string
  sectionIndex: number
  /** Page within the section, which depends on the reader's current type size. */
  pageIndex: number
  updatedAt: number
}
