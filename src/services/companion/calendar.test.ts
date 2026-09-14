import {
  addDays,
  calendarCoverage,
  celebrationFor,
  dateKey,
  easterSunday,
  parseDate,
  readingsFor,
  seasonFor,
  upcomingSunday,
} from "./calendar"

const d = (value: string) => parseDate(value)
describe("the offline Catholic calendar", () => {
  test("keeps dates local and validates route parameters", () => {
    expect(dateKey(d("2026-09-09"))).toBe("2026-09-09")
    expect(dateKey(parseDate("2026-02-30", d("2026-09-09")))).toBe("2026-09-09")
    expect(dateKey(addDays(d("2026-03-08"), 1))).toBe("2026-03-09")
    expect(dateKey(upcomingSunday(d("2026-09-09")))).toBe("2026-09-13")
    expect(dateKey(upcomingSunday(d("2026-09-13")))).toBe("2026-09-13")
    expect(dateKey(upcomingSunday(d("2026-12-31")))).toBe("2027-01-03")
  })
  test("handles movable seasons, Advent rollover, and the January Baptism exception", () => {
    expect(dateKey(easterSunday(2026))).toBe("2026-04-05")
    expect(seasonFor(d("2026-02-17"))).toBe("ordinary")
    expect(seasonFor(d("2026-02-18"))).toBe("lent")
    expect(seasonFor(d("2026-04-02"))).toBe("triduum")
    expect(seasonFor(d("2026-04-05"))).toBe("easter")
    expect(seasonFor(d("2026-05-24"))).toBe("easter")
    expect(seasonFor(d("2026-05-25"))).toBe("ordinary")
    expect(seasonFor(d("2026-11-29"))).toBe("advent")
    expect(seasonFor(d("2026-12-25"))).toBe("christmas")
    expect(seasonFor(d("2024-01-08"))).toBe("christmas")
    expect(seasonFor(d("2024-01-09"))).toBe("ordinary")
  })
  test("includes every day of 2026 and 2027 with a Gospel and a celebration", () => {
    for (let day = d("2026-01-01"); day < d("2028-01-01"); day = addDays(day, 1)) {
      const entry = readingsFor(day)
      expect({
        date: dateKey(day),
        hasGospel: entry?.readings.some((r) => r.label === "Gospel"),
      }).toEqual({ date: dateKey(day), hasGospel: true })
      expect(celebrationFor(day)?.title).toBeTruthy()
    }
    expect(calendarCoverage()).toContain("2027-12-31")
  })
  test("does not substitute a random verse when an offline date is absent", () => {
    expect(readingsFor(d("2040-01-01"))).toBeUndefined()
  })
  test("matches independently checked Sunday and Easter references", () => {
    expect(
      readingsFor(d("2026-09-13"))?.readings.find((r) => r.label === "Gospel")?.reference,
    ).toBe("Matthew 18:21-35")
    expect(
      readingsFor(d("2026-04-05"))?.readings.find((r) => r.label === "Gospel")?.reference,
    ).toBe("John 20:1-9")
  })
})
