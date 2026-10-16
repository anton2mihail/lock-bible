import { createHash } from "node:crypto"
import { mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import {
  CALENDAR_LABEL,
  SEASON_NAMES,
  calendarCoverage,
  celebrationFor,
  dateKey,
  parseDate,
  readingsFor,
  seasonFor,
  upcomingSunday,
} from "../../../../src/services/companion/calendar.ts"
import { getSuggestedRosaryMysterySet } from "../../../../src/services/rosary/catalog.ts"
import { novenas } from "../../../../src/services/novena/catalog.ts"
import { normalizeNovenaProgress } from "../../../../src/services/novena/progressModel.ts"

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../../../..")
const output = resolve(process.argv[2] ?? join(root, "build/native-evidence/L10-L11/today-source-contract.json"))
mkdirSync(dirname(output), { recursive: true })

const sourcePaths = [
  "scripts/native/source-fixtures/content/today-source-contract.ts",
  "src/screens/companion/TodayScreen.tsx",
  "src/screens/companion/ReadingsScreen.tsx",
  "src/services/companion/calendar.ts",
  "src/services/companion/data/readings-us.json",
  "src/services/companion/data/celebrations-us.json",
  "src/services/companion/calendar.test.ts",
  "src/services/novena/index.ts",
  "src/services/novena/catalog.ts",
  "src/services/novena/progress.ts",
  "src/services/novena/progressModel.ts",
  "src/services/novena/catalog.test.ts",
  "src/services/novena/progress.test.ts",
  "src/services/rosary/catalog.ts",
  "src/services/rosary/types.ts",
  "src/services/rosary/catalog.test.ts",
]
const hash = (path: string) => createHash("sha256").update(readFileSync(join(root, path))).digest("hex")
const toLocalDate = (key: string, hour = 12, minute = 0) => {
  const [year, month, day] = key.split("-").map(Number)
  return new Date(year, month - 1, day, hour, minute)
}
const readingValue = (date: Date) => {
  const entry = readingsFor(date)
  return entry ? { title: entry.title, readings: entry.readings } : null
}
const fallbackValue = (date: Date) => {
  const entry = readingsFor(date)
  const celebration = celebrationFor(date)
  const season = seasonFor(date)
  return {
    date: dateKey(date),
    reading: entry ?? null,
    celebration: celebration ?? null,
    season,
    todayCardTitle: entry?.title ?? celebration?.title ?? SEASON_NAMES[season],
    readingsScreenEmptyText: entry
      ? null
      : "Reading references for this date aren’t in your offline library. Open the official readings when you’re connected.",
  }
}

const readingsSource = JSON.parse(readFileSync(join(root, "src/services/companion/data/readings-us.json"), "utf8")) as Record<string, unknown>
const finiteDates = Object.keys(readingsSource).sort()
const finiteDateSet = new Set(finiteDates)
const calendarGapDates: string[] = []
for (let date = toLocalDate(finiteDates[0]); dateKey(date) <= finiteDates.at(-1)!; date.setDate(date.getDate() + 1)) {
  const key = dateKey(date)
  if (!finiteDateSet.has(key)) calendarGapDates.push(key)
}
const calendarDays = finiteDates.map((key) => {
  const date = toLocalDate(key)
  return { date: key, expectedDateKey: dateKey(date), expectedReadings: readingValue(date) }
})

const sundayStart = parseDate("2026-09-07")
const sundaySequence = Array.from({ length: 7 }, (_, offset) => {
  const day = new Date(sundayStart.getFullYear(), sundayStart.getMonth(), sundayStart.getDate() + offset, 12)
  const sunday = upcomingSunday(day)
  return { date: dateKey(day), weekday: day.getDay(), upcomingSunday: dateKey(sunday), includesToday: dateKey(day) === dateKey(sunday) }
})

const prayerBoundaryDates = ["2026-03-08", "2026-11-01", "2026-09-13"]
const prayerBoundaries = prayerBoundaryDates.flatMap((key) => [
  toLocalDate(key, 16, 59),
  toLocalDate(key, 17, 0),
]).map((date) => {
  const hour = date.getHours()
  return {
    localDateTime: `${dateKey(date)}T${String(hour).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`,
    date: dateKey(date),
    localHour: hour,
    prayerTitle: hour < 17 ? "Morning Offering" : "Night Prayer",
    prayerID: hour < 17 ? "morning" : "evening",
  }
})

const rosaryLocalWeekdays = Array.from({ length: 7 }, (_, offset) => {
  const date = toLocalDate("2026-09-07", 0, 15)
  date.setDate(date.getDate() + offset)
  return {
    localDateTime: `${dateKey(date)}T${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`,
    localWeekday: date.getDay(),
    suggestedSet: getSuggestedRosaryMysterySet(date).id,
  }
})
const rosaryMidnightTransition = [
  toLocalDate("2026-09-07", 23, 45),
  toLocalDate("2026-09-08", 0, 15),
].map((date) => ({
  localDateTime: `${dateKey(date)}T${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`,
  localWeekday: date.getDay(),
  suggestedSet: getSuggestedRosaryMysterySet(date).id,
}))

const syntheticProgress = Object.fromEntries(novenas.map((novena, index) => {
  if (index === 0) return [novena.id, { completedDays: [2, 7], selectedDay: 8, intention: "" }]
  if (index === 1) return [novena.id, { completedDays: [4], selectedDay: 4, intention: "  For a safe journey  " }]
  if (index === 2) return [novena.id, { completedDays: [1, 2, 3, 4, 5, 6, 7, 8, 9], selectedDay: 9, intention: "Completed cycle" }]
  if (index === 3) return [novena.id, { completedDays: [], selectedDay: 1, intention: "   " }]
  if (index === 4) return [novena.id, { completedDays: [1, 2, 3, 4, 5, 6, 7, 8], selectedDay: 6, intention: "" }]
  return [novena.id, { completedDays: [], selectedDay: 1, intention: "" }]
}))
const novenaStates = novenas.map((novena) => {
  const progress = normalizeNovenaProgress(syntheticProgress[novena.id])
  const active = (progress.completedDays.length > 0 || progress.intention.trim().length > 0) && progress.completedDays.length < 9
  const nextDay = Array.from({ length: 9 }, (_, index) => index + 1).find((day) => !progress.completedDays.includes(day)) ?? 9
  return {
    id: novena.id,
    title: novena.title,
    catalogIndex: novenas.indexOf(novena),
    completedDays: progress.completedDays,
    intention: progress.intention,
    active,
    continueSubtitle: active ? `Continue with day ${nextDay}` : null,
  }
})

const fallbackDates = [...new Set(["2025-08-24", ...calendarGapDates, finiteDates[0], finiteDates.at(-1)!, "2028-01-01", "2040-01-01"])]
const result = {
  formatVersion: 1,
  generatedBy: "scripts/native/source-fixtures/content/today-source-contract.ts",
  sourceHashes: Object.fromEntries(sourcePaths.map((path) => [path, hash(path)])),
  runtimeInputs: {
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    calendarLabel: CALENDAR_LABEL,
    note: "All date constructors use local time. The novena progress values are synthetic.",
  },
  sourceRules: {
    prayerBoundary: "TodayScreen uses local getHours() < 17. Hour 16 is morning; hour 17 is evening.",
    activeNovenaOrder: "TodayScreen maps the source catalog order, then filters progress with completedDays.length > 0 or intention.trim(), and completedDays.length < 9.",
    novenaSubtitle: "The screen selects the first incomplete day from 1 through 9, or 9 when none is found.",
    upcomingSunday: "upcomingSunday uses local getDay(); Sunday returns the same date.",
    rosaryWeekday: "getSuggestedRosaryMysterySet uses local Date.getDay().",
    readingCoverage: "readingsFor returns undefined outside the finite bundled key set. Today falls back to celebration title, then season title. ReadingsScreen shows its offline missing-date message.",
    novenaProgressProvenance: "normalizeNovenaProgress is called. The TodayScreen load/map/filter sequence is represented from its source because loadNovenaProgress reads app storage.",
  },
  finiteCalendar: {
    coverage: calendarCoverage(),
    dateCount: finiteDates.length,
    missingDatesInsideCoverage: calendarGapDates,
    dates: calendarDays,
  },
  sundaySequence,
  prayerBoundaries,
  rosaryLocalWeekdays,
  rosaryMidnightTransition,
  novenas: {
    catalogOrder: novenas.map((novena) => novena.id),
    syntheticProgress: syntheticProgress,
    statesInSourceOrder: novenaStates,
    activeInSourceOrder: novenaStates.filter((state) => state.active).map(({ id, title, continueSubtitle }) => ({ id, title, continueSubtitle })),
  },
  readingFallbacks: fallbackDates.map((key) => fallbackValue(toLocalDate(key))),
}

writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`)
console.log(`Wrote ${finiteDates.length} finite calendar dates and source Today selectors to ${output}`)
