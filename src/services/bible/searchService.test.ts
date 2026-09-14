import type { SQLiteDatabase } from "expo-sqlite"

import { searchBible } from "./searchService"

const faithRow = {
  id: 1,
  book_code: "HEB",
  book_name: "Hebrews",
  group_name: "nt",
  chapter: 11,
  verse: "1",
  verse_order: 0,
  text: "Now faith is the assurance of things hoped for.",
}

describe("offline Bible search", () => {
  it("lightly corrects a misspelled word when the original has no results", async () => {
    const database = {
      getFirstAsync: jest.fn().mockResolvedValue(null),
      getAllAsync: jest.fn(async (sql: string, ...params: unknown[]) => {
        if (sql.includes("FROM vocabulary")) return [{ word: "faith", frequency: 100 }]
        return params[0] === '"faith"*' ? [faithRow] : []
      }),
    } as unknown as SQLiteDatabase

    const response = await searchBible(database, "fiath")

    expect(response.correctedQuery).toBe("faith")
    expect(response.results).toEqual([
      expect.objectContaining({ reference: "Hebrews 11:1", text: faithRow.text }),
    ])
  })

  it("looks up a reference directly without needing text search", async () => {
    const getAllAsync = jest.fn().mockResolvedValue([
      {
        ...faithRow,
        book_code: "JHN",
        book_name: "John",
        chapter: 3,
        verse: "16",
        verse_order: 15,
      },
    ])
    const database = { getAllAsync } as unknown as SQLiteDatabase

    const response = await searchBible(database, "John 3:16")

    expect(response.isReference).toBe(true)
    expect(response.results[0].reference).toBe("John 3:16")
    expect(getAllAsync.mock.calls[0][1]).toEqual(["web-ce", "JHN", 3, 16, 16, 60])
  })
})
