import { readFileSync } from "node:fs"
import { join } from "node:path"
import { DatabaseSync } from "node:sqlite"
import { inflateSync } from "node:zlib"

/**
 * "A Year with the Fathers" (data/year-plan.json, built by scripts/build-year-plan.mjs) points into
 * works.db by section and paragraph. These tests open the real database: a plan entry that points at a
 * paragraph the library does not have would open a blank reading on that day of the year.
 */
type Reading = { workId: string; section: number; fromParagraph: number; toParagraph: number }
type Day = {
  day: number
  date: string
  season: string
  feast?: string
  author: string
  title: string
  words: number
  minutes: number
  readings: Reading[]
}
type Plan = { year: number; startDate: string; freeDays: number; minWords: number; maxWords: number; days: Day[] }

const root = join(__dirname, "..", "..", "..")
const plan = JSON.parse(readFileSync(join(__dirname, "data", "year-plan.json"), "utf8")) as Plan
const database = new DatabaseSync(join(root, "assets", "works", "works.db"), { readOnly: true })

const paragraphCache = new Map<string, string[]>()
function paragraphs(workId: string, section: number): string[] | null {
  const key = `${workId}#${section}`
  if (!paragraphCache.has(key)) {
    const row = database
      .prepare("SELECT paragraphs FROM sections WHERE work_id = ? AND idx = ?")
      .get(workId, section) as { paragraphs: Uint8Array } | undefined
    if (!row) return null
    paragraphCache.set(key, JSON.parse(inflateSync(row.paragraphs).toString("utf8")) as string[])
  }
  return paragraphCache.get(key)!
}

const wordCount = (text: string) => (text.match(/\S+/g) ?? []).length

/** Same rule as FathersLibraryAccess.isSectionFree (iOS) and FathersAccess.isSectionFree (Android). */
function isSectionFree(workId: string, section: number): boolean {
  return section === 0 || workId === "augustine.the-confessions" || workId.startsWith("apostolic-fathers.")
}

/** Gregorian Easter (anonymous algorithm), to check the plan's movable feasts. */
function easter(year: number): Date {
  const a = year % 19, b = Math.floor(year / 100), c = year % 100
  const d = Math.floor(b / 4), e = b % 4, f = Math.floor((b + 8) / 25), g = Math.floor((b - f + 1) / 3)
  const h = (19 * a + b - d - g + 15) % 30, i = Math.floor(c / 4), k = c % 4
  const l = (32 + 2 * e + 2 * i - h - k) % 7, m = Math.floor((a + 11 * h + 22 * l) / 451)
  const month = Math.floor((h + l - 7 * m + 114) / 31), day = ((h + l - 7 * m + 114) % 31) + 1
  return new Date(Date.UTC(year, month - 1, day))
}
const iso = (date: Date) => date.toISOString().slice(0, 10)
const addDays = (date: Date, days: number) => new Date(date.getTime() + days * 86_400_000)
const dayOf = (date: string) => plan.days.find((d) => d.date === date)!

describe("A Year with the Fathers", () => {
  it("has one reading for every day of 2027, from 1 January", () => {
    expect(plan.year).toBe(2027)
    expect(plan.startDate).toBe("2027-01-01")
    expect(plan.days).toHaveLength(365)
    plan.days.forEach((d, i) => {
      expect(d.day).toBe(i + 1)
      expect(d.date).toBe(iso(addDays(new Date(Date.UTC(2027, 0, 1)), i)))
      expect(d.readings.length).toBeGreaterThan(0)
      expect(d.title.length).toBeGreaterThan(0)
      expect(d.author.length).toBeGreaterThan(0)
    })
  })

  it("Y1: every reading points at sections and paragraphs the library has", () => {
    for (const d of plan.days) {
      for (const r of d.readings) {
        const ps = paragraphs(r.workId, r.section)
        expect({ day: d.day, workId: r.workId, section: r.section, found: ps !== null })
          .toEqual({ day: d.day, workId: r.workId, section: r.section, found: true })
        expect(r.fromParagraph).toBeGreaterThanOrEqual(0)
        expect(r.toParagraph).toBeGreaterThanOrEqual(r.fromParagraph)
        expect(r.toParagraph).toBeLessThan(ps!.length)
      }
    }
  })

  it("Y2: each day is between the word limits, and its word count is the text's", () => {
    for (const d of plan.days) {
      const counted = d.readings.reduce((sum, r) => sum + paragraphs(r.workId, r.section)!
        .slice(r.fromParagraph, r.toParagraph + 1)
        .reduce((a, p) => a + wordCount(p), 0), 0)
      expect({ day: d.day, words: d.words }).toEqual({ day: d.day, words: counted })
      expect(d.words).toBeGreaterThanOrEqual(plan.minWords)
      expect(d.words).toBeLessThanOrEqual(plan.maxWords)
      expect(d.minutes).toBe(Math.max(1, Math.round(d.words / 200)))
    }
  })

  it("never reads the same paragraph twice", () => {
    const seen = new Set<string>()
    for (const d of plan.days) {
      for (const r of d.readings) {
        for (let p = r.fromParagraph; p <= r.toParagraph; p++) {
          const key = `${r.workId}#${r.section}#${p}`
          expect({ day: d.day, key, repeated: seen.has(key) }).toEqual({ day: d.day, key, repeated: false })
          seen.add(key)
        }
      }
    }
  })

  it("Y5: the free days use only sections that read free without the library", () => {
    expect(plan.freeDays).toBe(7)
    for (const d of plan.days.slice(0, plan.freeDays)) {
      for (const r of d.readings) expect({ day: d.day, ...r, free: isSectionFree(r.workId, r.section) })
        .toEqual({ day: d.day, ...r, free: true })
    }
  })

  it("uses only saints, Doctors and the Apostolic Fathers", () => {
    const allowed = new Set(["apostolic-fathers", "leo-great", "athanasius", "cyril-jerusalem", "ambrose", "augustine",
      "gregory-nazianzen", "cyprian", "vincent-lerins", "aquinas"])
    for (const d of plan.days) for (const r of d.readings) expect(allowed).toContain(r.workId.split(".")[0])
  })

  it("puts the feasts on their 2027 dates", () => {
    const e = easter(2027)
    expect(iso(e)).toBe("2027-03-28")
    expect(dayOf(iso(addDays(e, -46))).feast).toBe("Ash Wednesday")
    expect(dayOf(iso(addDays(e, -7))).feast).toBe("Palm Sunday")
    expect(dayOf(iso(addDays(e, -2))).feast).toBe("Good Friday")
    expect(dayOf(iso(e)).feast).toBe("Easter Sunday")
    expect(dayOf(iso(addDays(e, 39))).feast).toBe("The Ascension")
    expect(dayOf(iso(addDays(e, 49))).feast).toBe("Pentecost")
    expect(dayOf("2027-11-28").feast).toBe("First Sunday of Advent")
    expect(dayOf("2027-12-25").feast).toBe("Christmas")
    expect(dayOf("2027-12-25").title).toBe("On the Feast of the Nativity, I")
    expect(dayOf(iso(addDays(e, -46))).title).toBe("On Lent, I")
    expect(dayOf(iso(e)).title).toBe("On the Lord's Resurrection, II")
  })

  it("gives each season's days their season", () => {
    const e = easter(2027)
    for (const d of plan.days) {
      const t = Date.parse(d.date)
      if (t >= addDays(e, -46).getTime() && t < addDays(e, -7).getTime()) expect(d.season).toBe("lent")
      if (t >= addDays(e, -7).getTime() && t < e.getTime()) expect(d.season).toBe("holy-week")
      if (t >= e.getTime() && t <= addDays(e, 49).getTime()) expect(d.season).toBe("easter")
    }
  })

  it("Y8: never calls the plan a resolution, a goal, a challenge, a habit or a streak", () => {
    const text = JSON.stringify(plan.days.map(({ title, author, feast }) => ({ title, author, feast })))
    expect(text).not.toMatch(/\b(resolution|goal|challenge|habit|streak)s?\b/i)
  })
})
