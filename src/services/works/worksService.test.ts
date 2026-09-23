import { join } from "node:path"
import { DatabaseSync } from "node:sqlite"
import { inflateSync } from "node:zlib"

import {
  COLLECTIONS,
  formatReadingLength,
  getChapterCommentary,
  getCollection,
  getCollectionWorks,
  getWorkMeta,
  hasCommentary,
  loadSection,
  readingMinutes,
  WORK_KIND_LABEL,
  WORKS,
} from "./index"

/**
 * The catalog is bundled JSON and the section text ships as a SQLite asset, so
 * the invariant that actually matters is that the two agree. These tests open
 * the real built database rather than a fixture: a catalog that points at
 * sections the database does not have would send a reader to a blank page, and
 * nothing else in the suite would catch it.
 */
const database = new DatabaseSync(
  join(__dirname, "..", "..", "..", "assets", "works", "works.db"),
  { readOnly: true },
)

type SectionRow = { idx: number; title: string; words: number; paragraphs: Uint8Array }

/** Section text ships deflated; these tests read it the way the app does. */
function paragraphsOf(row: SectionRow): string[] {
  return JSON.parse(inflateSync(row.paragraphs).toString("utf8")) as string[]
}

function sectionsOf(workId: string): SectionRow[] {
  return database
    .prepare("SELECT idx, title, words, paragraphs FROM sections WHERE work_id = ? ORDER BY idx")
    .all(workId) as unknown as SectionRow[]
}

afterAll(() => database.close())

describe("works catalog", () => {
  test("every collection declares a work count matching its works", () => {
    expect(COLLECTIONS.length).toBeGreaterThan(0)
    for (const collection of COLLECTIONS) {
      expect(getCollectionWorks(collection.id)).toHaveLength(collection.workCount)
    }
  })

  test("lists works in order and assigns each a known kind", () => {
    expect(WORKS.length).toBeGreaterThan(30)
    for (const collection of COLLECTIONS) {
      const orders = getCollectionWorks(collection.id).map((work) => work.order)
      expect(orders).toEqual([...orders].sort((a, b) => a - b))
    }
    for (const work of WORKS) {
      expect(WORK_KIND_LABEL[work.kind]).toBeDefined()
      expect(getCollection(work.collectionId)).toBeDefined()
    }
  })

  test("credits a public-domain translation for every collection", () => {
    for (const collection of COLLECTIONS) {
      expect(collection.translation.length).toBeGreaterThan(0)
      expect(collection.attribution).toMatch(/public domain/i)
    }
  })

  test("omits the modern compiler's introduction", () => {
    // The NPNF translation is public domain; that blurb is not part of it.
    expect(WORKS.some((work) => work.id === "introduction")).toBe(false)
  })

  test("estimates reading length in human terms", () => {
    expect(readingMinutes(200)).toBe(1)
    expect(readingMinutes(1)).toBe(1)
    expect(formatReadingLength(2000)).toBe("10 min")
    expect(formatReadingLength(12_000)).toBe("about an hour")
    expect(formatReadingLength(120_000)).toBe("about 10 hours")
  })

  test("gives every work an id qualified by its collection", () => {
    // Slugs repeat across authors - Augustine and Tertullian both wrote "On
    // Patience" - so a bare slug would collide in the database's primary key.
    const ids = new Set<string>()
    for (const work of WORKS) {
      expect(work.id.startsWith(`${work.collectionId}.`)).toBe(true)
      expect(ids.has(work.id)).toBe(false)
      ids.add(work.id)
    }
  })

  test("returns nothing for an unknown work rather than something empty", () => {
    expect(getWorkMeta("not-a-work")).toBeUndefined()
    expect(getCollectionWorks("not-a-collection")).toEqual([])
    expect(sectionsOf("not-a-work")).toHaveLength(0)
  })
})

describe("works database", () => {
  test("holds exactly the sections every work claims", () => {
    for (const work of WORKS) {
      const rows = sectionsOf(work.id)
      expect(rows).toHaveLength(work.sectionCount)
      // Indices are dense and zero-based; the reader pages by incrementing them.
      expect(rows.map((row) => row.idx)).toEqual(rows.map((_, index) => index))
    }
  })

  test("stores real prose in every section", () => {
    const meta = getWorkMeta("chrysostom.homilies-on-the-gospel-of-st-matthew")
    expect(meta).toBeDefined()

    const rows = sectionsOf(meta!.id)
    expect(rows.length).toBeGreaterThan(80)
    for (const row of rows) {
      expect(row.title.length).toBeGreaterThan(0)
      const paragraphs = paragraphsOf(row)
      expect(paragraphs.length).toBeGreaterThan(0)
      expect(paragraphs.every((p) => typeof p === "string" && p.length > 1)).toBe(true)
    }
  })
})

describe("loadSection against the shipped database", () => {
  /**
   * The app reads through expo-sqlite; this stands in for it over the real
   * file, so the deflated blob goes through the same decode path the device
   * uses. Without this the only coverage of decompression would be a mock.
   */
  const asExpoDatabase = {
    getFirstAsync: async <T>(sql: string, params: unknown[]): Promise<T | null> =>
      (database.prepare(sql).get(...(params as never[])) as T) ?? null,
  }

  test("inflates a real section into readable prose", async () => {
    const work = getWorkMeta("augustine.expositions-on-the-book-of-psalms")
    expect(work).toBeDefined()

    const section = await loadSection(
      asExpoDatabase as unknown as Parameters<typeof loadSection>[0],
      work!.id,
      22,
    )
    expect(section).toBeDefined()
    expect(section!.title).toBe("Psalm XXIII")
    expect(section!.paragraphs.length).toBeGreaterThan(3)
    expect(section!.paragraphs.join(" ")).toMatch(/The Lord feedeth me/)
  })

  test("returns undefined for a section that is not there", async () => {
    const section = await loadSection(
      asExpoDatabase as unknown as Parameters<typeof loadSection>[0],
      "augustine.the-confessions",
      9999,
    )
    expect(section).toBeUndefined()
  })
})

describe("chapter commentary", () => {
  test("points a commented chapter at real sections", () => {
    const philippians1 = getChapterCommentary("PHP", 1)
    expect(philippians1.length).toBeGreaterThan(0)

    for (const homily of philippians1) {
      const rows = sectionsOf(homily.workId)
      expect(rows[homily.sectionIndex]).toBeDefined()
      expect(rows[homily.sectionIndex].title).toBe(homily.sectionTitle)
    }
  })

  test("covers the books the Fathers actually expounded", () => {
    for (const code of ["MAT", "JHN", "ACT", "ROM", "1CO", "GAL", "HEB", "PHM"]) {
      expect(hasCommentary(code)).toBe(true)
      expect(getChapterCommentary(code, 1).length).toBeGreaterThan(0)
    }
  })

  test("stays silent for books nobody in the library commented on", () => {
    expect(getChapterCommentary("GEN", 1)).toEqual([])
    expect(getChapterCommentary("REV", 1)).toEqual([])
  })

  test("returns nothing rather than throwing on a chapter out of range", () => {
    expect(getChapterCommentary("PHP", 99)).toEqual([])
    expect(getChapterCommentary(undefined, 1)).toEqual([])
    expect(getChapterCommentary("PHP", undefined)).toEqual([])
  })

  test("never indexes a section that does not exist in its work", () => {
    // A stale index would send the reader to a blank page.
    const counts = new Map(WORKS.map((work) => [work.id, work.sectionCount]))
    // Walk the whole index, not a sample: this is the check that catches a
    // rebuild where the catalog and the database drifted apart.
    for (const chapters of Object.values(allCommentary())) {
      for (const entries of Object.values(chapters)) {
        for (const entry of entries) {
          const count = counts.get(entry.workId)
          expect(count).toBeDefined()
          expect(entry.sectionIndex).toBeGreaterThanOrEqual(0)
          expect(entry.sectionIndex).toBeLessThan(count!)
        }
      }
    }
  })
})

/** Every commentary entry in the catalog, for the exhaustive integrity sweep. */
function allCommentary(): Record<
  string,
  Record<string, { workId: string; sectionIndex: number }[]>
> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  return require("./data/catalog.json").commentary
}
