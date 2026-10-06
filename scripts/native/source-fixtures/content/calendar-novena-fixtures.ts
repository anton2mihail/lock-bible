import { createHash } from "node:crypto"
import { readFileSync, writeFileSync, mkdirSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import {
  addDays,
  calendarCoverage,
  celebrationFor,
  dateKey,
  parseDate,
  readingsFor,
  seasonFor,
  upcomingSunday,
} from "../../../../src/services/companion/calendar"
import { NOVENA_DAY_COUNT } from "../../../../src/services/novena/padrePioNovena"
import { novenas } from "../../../../src/services/novena/catalog"
import { emptyNovenaProgress, normalizeNovenaProgress } from "../../../../src/services/novena/progressModel"

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../../../..")
const output = resolve(process.argv[2] ?? join(root, "build/native-evidence/L13-content/calendar-novena-fixtures.json"))
const timezone = process.argv[3] ?? "America/Toronto"
process.env.TZ = timezone
const actualTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone
if (actualTimezone !== timezone) throw new Error(`Expected timezone ${timezone}, got ${actualTimezone}`)

const sourcePaths = [
  "src/services/companion/calendar.ts",
  "src/services/companion/data/readings-us.json",
  "src/services/companion/data/celebrations-us.json",
  "src/screens/companion/TodayScreen.tsx",
  "src/screens/companion/ReadingsScreen.tsx",
  "src/services/novena/catalog.ts",
  "src/services/novena/progressModel.ts",
  "src/services/novena/progress.ts",
  "src/screens/NovenaScreen.tsx",
  "src/services/novena/expandedNovenas.ts",
  "src/services/novena/padrePioNovena.ts",
  "src/services/novena/perpetualHelpNovena.ts",
  "src/services/novena/stJosephNovena.ts",
  "src/services/novena/stJudeNovena.ts",
  "src/services/novena/stPeregrineNovena.ts",
  "src/services/novena/stThereseNovena.ts",
]
const sourceHashes = Object.fromEntries(sourcePaths.map((path) => [
  path,
  createHash("sha256").update(readFileSync(join(root, path))).digest("hex"),
]))

function localInstant(iso: string) {
  const instant = new Date(iso)
  return {
    iso,
    epochMilliseconds: instant.getTime(),
    localDate: dateKey(instant),
    offsetMinutesEast: -instant.getTimezoneOffset(),
  }
}

function calendarValue(value: string) {
  const date = parseDate(value)
  const readings = readingsFor(date)
  const celebration = celebrationFor(date)
  return {
    date: dateKey(date),
    season: seasonFor(date),
    title: readings?.title ?? celebration?.title ?? null,
    readings: readings?.readings ?? [],
    celebration: celebration ? { title: celebration.title, season: celebration.season, rank: celebration.rank, color: celebration.color ?? null } : null,
  }
}

const dates = [
  "2025-08-25",
  "2026-01-01",
  "2026-04-05",
  "2026-09-13",
  "2027-12-31",
  "2032-12-31",
]
const readingsData = JSON.parse(readFileSync(join(root, "src/services/companion/data/readings-us.json"), "utf8")) as Record<string, unknown>
const allDates = Object.keys(readingsData).sort()
const yearCoverage = Object.fromEntries([...new Set(allDates.map((date) => date.slice(0, 4)))].map((year) => {
  const yearDates = allDates.filter((date) => date.startsWith(`${year}-`))
  return [year, { first: yearDates[0], last: yearDates.at(-1), count: yearDates.length }]
}))
const referenceMapping = Object.fromEntries(allDates.map((date) => {
  const entry = readingsFor(parseDate(date))
  return [date, (entry?.readings ?? []).map(({ label, reference }) => ({ label, reference }))]
}))

const instants = [
  "2026-03-08T04:59:59Z",
  "2026-03-08T05:00:00Z",
  "2026-03-08T06:59:59Z",
  "2026-03-08T07:00:00Z",
  "2026-11-01T03:59:59Z",
  "2026-11-01T04:00:00Z",
  "2026-11-01T05:59:59Z",
  "2026-11-01T06:00:00Z",
  "2026-09-14T03:59:59Z",
  "2026-09-14T04:00:00Z",
]
const instantCases = instants.map(localInstant)
const selectorFallback = new Date("2026-09-09T16:45:00Z")
const readingsSelectors = [
  { route: "daily", parameter: undefined, fallbackLocalDate: dateKey(selectorFallback), selected: calendarValue(dateKey(parseDate(undefined, selectorFallback))) },
  { route: "sunday", parameter: undefined, fallbackLocalDate: dateKey(selectorFallback), selected: calendarValue(dateKey(parseDate(undefined, upcomingSunday(selectorFallback)))) },
  { route: "daily", parameter: "2026-04-05", fallbackLocalDate: dateKey(selectorFallback), selected: calendarValue(dateKey(parseDate("2026-04-05", selectorFallback))) },
  { route: "daily", parameter: "2026-02-30", fallbackLocalDate: dateKey(selectorFallback), selected: calendarValue(dateKey(parseDate("2026-02-30", selectorFallback))) },
  { route: "daily", parameter: "2040-01-01", fallbackLocalDate: dateKey(selectorFallback), selected: calendarValue(dateKey(parseDate("2040-01-01", selectorFallback))) },
]

function normalized(value: unknown) {
  return normalizeNovenaProgress(value)
}

function sourceMappedCallbacks() {
  let progress = normalized({ ...emptyNovenaProgress, intention: "  Fixture intention  " })
  const steps: Array<Record<string, unknown>> = []
  const selectDay = (selectedDay: number) => {
    progress = normalized({ ...progress, selectedDay })
    steps.push({ action: "selectDay", selectedDay, progress })
  }
  const completeDay = () => {
    if (progress.completedDays.includes(progress.selectedDay)) {
      steps.push({ action: "completeDay", selectedDay: progress.selectedDay, changed: false, progress })
      return
    }
    const selectedDay = progress.selectedDay
    const completedDays = [...progress.completedDays, selectedDay].sort((a, b) => a - b)
    const nextIncomplete = Array.from({ length: NOVENA_DAY_COUNT }, (_, index) => index + 1)
      .find((day) => !completedDays.includes(day))
    progress = normalized({
      ...progress,
      completedDays,
      selectedDay: nextIncomplete ?? progress.selectedDay,
    })
    steps.push({ action: "completeDay", selectedDay, changed: true, progress })
  }

  selectDay(5)
  completeDay()
  selectDay(5)
  completeDay()
  selectDay(9)
  completeDay()
  progress = normalized({ ...emptyNovenaProgress })
  steps.push({ action: "startAgain", progress })
  return {
    mapping: "selectDay, completeDay, and startAgain mirror NovenaScreen.tsx callbacks; they are not exported source functions",
    steps,
  }
}

function transitionOutputs() {
  const output: Record<string, unknown> = {}
  for (const novena of novenas) {
    let progress = normalized(emptyNovenaProgress)
    const steps: Array<Record<string, unknown>> = [{ action: "initial", progress }]
    const intention = "  Fixture intention  "
    progress = normalized({ ...progress, intention })
    steps.push({ action: "setIntention", input: intention, progress })

    const completions: Array<Record<string, unknown>> = []
    for (let selectedDay = 1; selectedDay <= NOVENA_DAY_COUNT; selectedDay += 1) {
      const completedDays = [...progress.completedDays, selectedDay].sort((a, b) => a - b)
      const nextIncomplete = Array.from({ length: NOVENA_DAY_COUNT }, (_, index) => index + 1)
        .find((day) => !completedDays.includes(day))
      progress = normalized({ ...progress, completedDays, selectedDay: nextIncomplete ?? selectedDay })
      completions.push({ action: "completeDay", selectedDay, isComplete: progress.completedDays.length === NOVENA_DAY_COUNT, progress })
    }
    steps.push(...completions)
    progress = normalized({ ...emptyNovenaProgress })
    steps.push({ action: "startAgain", progress })
    output[novena.id] = {
      storageKey: `novena.${novena.id}.progress.v1`,
      reducerSource: "progressModel.normalizeNovenaProgress",
      screenCallbackSource: "NovenaScreen.tsx",
      steps,
      callbackSequence: sourceMappedCallbacks(),
    }
  }
  return output
}

const result = {
  formatVersion: 1,
  timezone,
  calendar: {
    label: "United States · Roman Rite",
    coverage: calendarCoverage(),
    dateCount: allDates.length,
    yearCoverage,
    dateOutputs: dates.map(calendarValue),
    referenceMapping,
    readingsSelectors,
    instantCases,
    addDaysAcrossYear: dateKey(addDays(parseDate("2026-12-31"), 1)),
    sundayExamples: ["2026-09-09", "2026-09-13", "2026-12-31"].map((date) => ({ date, upcoming: dateKey(upcomingSunday(parseDate(date))) })),
  },
  novena: {
    dayCount: NOVENA_DAY_COUNT,
    ids: novenas.map(({ id }) => id),
    transitions: transitionOutputs(),
    malformedInput: normalized({ completedDays: "all", selectedDay: 20, intention: null }),
  },
  sourceHashes,
}

mkdirSync(dirname(output), { recursive: true })
writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`)
console.log(`Wrote ${allDates.length} calendar dates and ${novenas.length} novena transitions for ${timezone}: ${output}`)
