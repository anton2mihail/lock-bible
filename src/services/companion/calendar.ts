import celebrations from "./data/celebrations-us.json"
import readings from "./data/readings-us.json"

export type ReadingReference = { label: string; reference: string }
export type CalendarEntry = { title: string; readings: ReadingReference[] }
export type Season = "advent" | "christmas" | "lent" | "triduum" | "easter" | "ordinary"
const calendar = readings as Record<string, CalendarEntry>

/** Calendar dates use local noon so time zones and daylight saving never move a day. */
export function dateKey(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`
}
export function parseDate(value: string | undefined, fallback = new Date()): Date {
  if (!value || !/^\d{4}-\d{2}-\d{2}$/.test(value))
    return new Date(fallback.getFullYear(), fallback.getMonth(), fallback.getDate(), 12)
  const [y, m, d] = value.split("-").map(Number)
  const result = new Date(y, m - 1, d, 12)
  return dateKey(result) === value ? result : parseDate(undefined, fallback)
}
export function addDays(date: Date, days: number): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + days, 12)
}
export function upcomingSunday(date = new Date()): Date {
  return addDays(date, (7 - date.getDay()) % 7)
}
export function easterSunday(year: number): Date {
  const a = year % 19,
    b = Math.floor(year / 100),
    c = year % 100
  const d = Math.floor(b / 4),
    e = b % 4,
    f = Math.floor((b + 8) / 25)
  const g = Math.floor((b - f + 1) / 3),
    h = (19 * a + b - d - g + 15) % 30
  const i = Math.floor(c / 4),
    k = c % 4,
    l = (32 + 2 * e + 2 * i - h - k) % 7
  const m = Math.floor((a + 11 * h + 22 * l) / 451),
    n = h + l - 7 * m + 114
  return new Date(year, Math.floor(n / 31) - 1, (n % 31) + 1, 12)
}
export function seasonFor(date: Date): Season {
  const day = parseDate(dateKey(date)),
    year = day.getFullYear(),
    easter = easterSunday(year)
  const christmas = new Date(year, 11, 25, 12)
  const advent = addDays(christmas, -(christmas.getDay() || 7) - 21)
  const jan2 = new Date(year, 0, 2, 12)
  const epiphany = addDays(jan2, (7 - jan2.getDay()) % 7)
  const baptism = addDays(epiphany, epiphany.getDate() >= 7 ? 1 : 7)
  if (day <= baptism || day >= christmas) return "christmas"
  if (day >= advent) return "advent"
  if (day >= easter && day <= addDays(easter, 49)) return "easter"
  if (day >= addDays(easter, -3) && day < easter) return "triduum"
  if (day >= addDays(easter, -46) && day < easter) return "lent"
  return "ordinary"
}
export const SEASON_NAMES: Record<Season, string> = {
  advent: "Advent",
  christmas: "Christmas",
  lent: "Lent",
  triduum: "The Sacred Triduum",
  easter: "Easter",
  ordinary: "Ordinary Time",
}
export function readingsFor(date: Date): CalendarEntry | undefined {
  return calendar[dateKey(date)]
}
export function readingsUrl(date: Date): string {
  return `https://bible.usccb.org/bible/readings/${String(date.getMonth() + 1).padStart(2, "0")}${String(date.getDate()).padStart(2, "0")}${String(date.getFullYear()).slice(-2)}.cfm`
}
export const CALENDAR_LABEL = "United States · Roman Rite"
export function calendarCoverage(): string {
  const dates = Object.keys(calendar).sort()
  return dates.length ? `${dates[0]} to ${dates[dates.length - 1]}` : "No offline dates installed"
}

export type Celebration = { title: string; season: string; rank: string; color?: string }
export function celebrationFor(date: Date): Celebration | undefined {
  return (celebrations as Record<string, Celebration>)[dateKey(date)]
}
