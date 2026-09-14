import type { BookGroup, WidgetVerse } from "./types"
import {
  filterByScope,
  nextRotationDate,
  rotationSlot,
  scopeMatches,
  selectVerse,
  verseIndexForDate,
  verseIndexForSlot,
} from "./verseOfDay"

function makePool(groups: BookGroup[]): WidgetVerse[] {
  return groups.map((g, i) => ({
    ref: `Book ${i}:1`,
    book: "BK",
    chapter: i,
    verse: "1",
    text: `verse ${i}`,
    group: g,
  }))
}

const pool = makePool(["ot", "nt", "ot", "deutero", "nt"])

describe("verseOfDay rotation", () => {
  it("is deterministic for the same date", () => {
    const d = new Date("2026-06-26T10:00:00")
    expect(verseIndexForDate(d, pool.length, 1440)).toBe(verseIndexForDate(d, pool.length, 1440))
  })

  it("always returns an index within the pool", () => {
    for (let m = 0; m < 600; m += 7) {
      const d = new Date(2026, 5, 1, 0, m)
      const idx = verseIndexForDate(d, pool.length, 10)
      expect(idx).toBeGreaterThanOrEqual(0)
      expect(idx).toBeLessThan(pool.length)
    }
  })

  it("advances exactly one slot per interval (10 min)", () => {
    const interval = 10
    const base = new Date(2026, 0, 1, 0, 0)
    const later = new Date(base.getTime() + interval * 60_000)
    expect(rotationSlot(later, interval)).toBe(rotationSlot(base, interval) + 1)
  })

  it("holds the same verse within a daily window", () => {
    const morning = new Date(2026, 5, 26, 8)
    const evening = new Date(2026, 5, 26, 22)
    expect(verseIndexForDate(morning, pool.length, 1440)).toBe(
      verseIndexForDate(evening, pool.length, 1440),
    )
  })

  it("changes verse every 15 minutes when cadence is 15", () => {
    const a = new Date(2026, 5, 26, 8, 0)
    const b = new Date(2026, 5, 26, 8, 15)
    const ia = verseIndexForDate(a, pool.length, 15)
    const ib = verseIndexForDate(b, pool.length, 15)
    expect(ib).not.toBe(ia)
  })

  it.each([2, 5, 82, 7_953, 30_076, 38_029])(
    "visits all %i scoped verses exactly once before repeating",
    (count) => {
      const cycle = Array.from({ length: count }, (_, slot) => verseIndexForSlot(slot, count))
      expect(new Set(cycle).size).toBe(count)
      expect(verseIndexForSlot(count, count)).toBe(cycle[0])
    },
  )

  it("does not merely walk through the Bible in stored order", () => {
    const indices = Array.from({ length: 8 }, (_, slot) => verseIndexForSlot(slot, 38_029))
    expect(indices).not.toEqual(Array.from({ length: 8 }, (_, i) => i))
    expect(new Set(indices).size).toBe(indices.length)
  })

  it("nextRotationDate is in the future and slot-aligned", () => {
    const d = new Date(2026, 5, 26, 13, 37)
    const next = nextRotationDate(d, 30)
    expect(next.getTime()).toBeGreaterThan(d.getTime())
    expect(rotationSlot(next, 30)).toBe(rotationSlot(d, 30) + 1)
  })

  it("returns undefined for an empty pool", () => {
    expect(selectVerse([], new Date(), 1440)).toBeUndefined()
  })
})

describe("verse scope", () => {
  it("full scope keeps everything", () => {
    expect(filterByScope(pool, "full")).toHaveLength(pool.length)
  })

  it("nt scope keeps only New Testament verses", () => {
    const nt = filterByScope(pool, "nt")
    expect(nt.every((v) => v.group === "nt")).toBe(true)
    expect(nt).toHaveLength(2)
  })

  it("ot scope includes the deuterocanon", () => {
    const ot = filterByScope(pool, "ot")
    expect(ot.every((v) => v.group === "ot" || v.group === "deutero")).toBe(true)
    expect(ot).toHaveLength(3)
  })

  it("scopeMatches treats deuterocanon as Old Testament", () => {
    expect(scopeMatches("deutero", "ot")).toBe(true)
    expect(scopeMatches("deutero", "nt")).toBe(false)
    expect(scopeMatches("nt", "full")).toBe(true)
  })

  it("filtering preserves order (so JS and Swift indices match)", () => {
    const nt = filterByScope(pool, "nt")
    expect(nt.map((v) => v.chapter)).toEqual([1, 4])
  })
})
