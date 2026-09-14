import { groupHighlightRows, passageKey, passageReference } from "./libraryRepository"
import type { HighlightRow } from "./libraryRepository"

describe("library passage identity", () => {
  it("creates stable translation-aware passage keys", () => {
    expect(
      passageKey({
        translationId: "web-ce",
        bookCode: "JHN",
        chapter: 3,
        startVerse: "16",
        endVerse: "18",
      }),
    ).toBe("web-ce:JHN:3:16:18")
  })

  it("formats single verses and ranges", () => {
    expect(passageReference("John", 3, "16", "16")).toBe("John 3:16")
    expect(passageReference("John", 3, "16", "18")).toBe("John 3:16–18")
  })
})

describe("highlight grouping", () => {
  function row(verse: string, index: number, batch = "batch-a"): HighlightRow {
    return {
      verse_key: `web-ce:JHN:3:${verse}`,
      batch_id: batch,
      translation_id: "web-ce",
      book_code: "JHN",
      book_name: "John",
      book_order: 65,
      chapter: 3,
      verse,
      verse_index: index,
      verse_text: `Verse ${verse}`,
      color: "gold",
      created_at: 100,
      updated_at: 100,
    }
  }

  it("groups contiguous verses from one highlight action", () => {
    const items = groupHighlightRows([row("16", 15), row("17", 16), row("18", 17)])
    expect(items).toHaveLength(1)
    expect(items[0]).toMatchObject({ reference: "John 3:16–18", color: "gold" })
  })

  it("splits a highlight batch when an overlapping edit leaves a gap", () => {
    const items = groupHighlightRows([row("16", 15), row("18", 17)])
    expect(items.map((item) => item.reference)).toEqual(["John 3:16", "John 3:18"])
  })
})
