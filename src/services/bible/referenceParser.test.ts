import manifest from "./data/web-ce/manifest.json"
import { editDistance, parseBibleReference } from "./referenceParser"
import { buildFtsQuery } from "./searchService"
import type { BookMeta } from "./types"

const books = manifest as BookMeta[]

describe("Bible reference parsing", () => {
  it.each([
    ["John 3:16", "JHN", 3, "16", "16"],
    ["Jn 3 16", "JHN", 3, "16", "16"],
    ["John 3:16-18", "JHN", 3, "16", "18"],
    ["Psalm 23", "PSA", 23, undefined, undefined],
    ["1 John 4:9", "1JN", 4, "9", "9"],
    ["Phillipians 4:6", "PHP", 4, "6", "6"],
  ])("parses %s", (query, code, chapter, startVerse, endVerse) => {
    const result = parseBibleReference(query, books)
    expect(result).toMatchObject({
      book: expect.objectContaining({ code }),
      chapter,
      startVerse,
      endVerse,
    })
  })

  it("rejects chapters outside the selected book", () => {
    expect(parseBibleReference("Jude 4:1", books)).toBeNull()
  })

  it("bounds edit distance work", () => {
    expect(editDistance("phillipians", "philippians", 2)).toBe(2)
    expect(editDistance("john", "genesis", 2)).toBeGreaterThan(2)
  })
})

describe("full-text query building", () => {
  it("builds prefix AND queries", () => {
    expect(buildFtsQuery("faith hope")).toBe('"faith"* AND "hope"*')
  })

  it("preserves exact phrases", () => {
    expect(buildFtsQuery('"God so loved"')).toBe('"god so loved"')
  })

  it("ignores punctuation-only input", () => {
    expect(buildFtsQuery("!!!")).toBeNull()
  })
})
