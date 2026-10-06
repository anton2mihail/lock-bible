// Expected notice requests for one session instant. Source only. No simulator, no phone, no OS notification API.
//
// It runs the real old source (`calendarNotificationPlan` in src/services/companion/calendarNotifications.ts and
// `scheduleRosaryReminder` in src/services/rosary/reminders.ts). It replaces storage, Expo notifications, and the clock
// with the same bounded in-memory stubs as notice-fixtures.ts. It does not re-implement a planning rule.
//
// Usage (from the repository root):
//   bun scripts/native/source-fixtures/notifications/notice-expected.ts \
//     --now 2026-10-06T12:48:48Z --tz America/Toronto --calendar 09:15 \
//     --rosary weekly --rosary-weekday 2 --rosary-time 08:30 \
//     --json build/native-evidence/S02/session-01/notes/expected-notices.json \
//     --md build/native-evidence/S02/session-01/notes/expected-notices.md
//
// Options:
//   --now ISO        Session instant (UTC, ISO 8601). Required.
//   --tz ZONE        IANA time zone of the phone. Required.
//   --calendar HH:MM Calendar notice time, or `off`. Default off.
//   --rosary MODE    off | daily | weekly. Default off.
//   --rosary-time HH:MM   Rosary time. Default 20:00.
//   --rosary-weekday N    1 (Sunday) to 7 (Saturday), weekly only. Default 2 (Monday).
//   --json PATH / --md PATH   New output files. An existing file stops the script. Without --md the table goes to stdout.
//   --compare FILE   A decoded snapshot stage file (`systemSnapshot.pendingRequests`). Compares it with the expected
//                    requests. Exit code 1 on any difference.
//
// The Rosary "next trigger" date is computed here from the trigger fields (the old source sets only hour, minute, and
// weekday; iOS picks the date). Everything else comes from the old source.
import { createHash } from "node:crypto"
import { existsSync, readFileSync, writeFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { mock } from "bun:test"

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../../../..")

function arg(name: string, fallback?: string): string | undefined {
  const index = process.argv.indexOf(`--${name}`)
  return index >= 0 && index + 1 < process.argv.length ? process.argv[index + 1] : fallback
}
function fail(message: string): never {
  console.error(`notice-expected: ${message}`)
  process.exit(2)
}

const nowText = arg("now") ?? fail("--now is required")
const timezone = arg("tz") ?? fail("--tz is required")
const calendarArg = arg("calendar", "off")!
const rosaryMode = arg("rosary", "off")!
const rosaryTime = arg("rosary-time", "20:00")!
const rosaryWeekday = Number(arg("rosary-weekday", "2"))
const jsonPath = arg("json")
const mdPath = arg("md")
const comparePath = arg("compare")
for (const path of [jsonPath, mdPath]) if (path && existsSync(resolve(path))) fail(`output file already exists: ${path}`)
if (!["off", "daily", "weekly"].includes(rosaryMode)) fail("--rosary must be off, daily, or weekly")
if (!Number.isInteger(rosaryWeekday) || rosaryWeekday < 1 || rosaryWeekday > 7) fail("--rosary-weekday must be 1 to 7")
function parseTime(text: string, label: string): { hour: number; minute: number } {
  const match = /^([0-9]{1,2}):([0-9]{2})$/.exec(text)
  if (!match || Number(match[1]) > 23 || Number(match[2]) > 59) fail(`${label} must be HH:MM`)
  return { hour: Number(match![1]), minute: Number(match![2]) }
}

// ---- Stubs (same approach as notice-fixtures.ts) ----------------------------------------------------------------
const storageValues = new Map<string, string>()
const scheduled: any[] = []
class MemoryMMKV {
  getString(key: string) { return storageValues.get(key) }
  set(key: string, value: string) { storageValues.set(key, value) }
  delete(key: string) { storageValues.delete(key) }
  clearAll() { storageValues.clear() }
}
const notificationModule = {
  SchedulableTriggerInputTypes: { DATE: "date", DAILY: "daily", WEEKLY: "weekly" },
  AndroidImportance: { DEFAULT: 3 },
  getPermissionsAsync: async () => ({ granted: true }),
  requestPermissionsAsync: async () => ({ granted: true }),
  getAllScheduledNotificationsAsync: async () => [],
  scheduleNotificationAsync: async (request: any) => { scheduled.push(request); return request.identifier ?? "fixture-created-1" },
  cancelScheduledNotificationAsync: async () => undefined,
  setNotificationChannelAsync: async () => undefined,
}
mock.module("react-native", () => ({ Platform: { OS: "ios" } }))
mock.module("react-native-mmkv", () => ({ MMKV: MemoryMMKV }))
mock.module("expo-notifications", () => notificationModule)
process.env.EXPO_OS = "ios"
process.env.TZ = timezone

const calendarService = await import("../../../../src/services/companion/calendarNotifications")
const rosaryService = await import("../../../../src/services/rosary/reminders")

const RealDate = globalThis.Date
const fixedNow = new RealDate(nowText).getTime()
if (!Number.isFinite(fixedNow)) fail("--now is not a valid instant")
class FixtureDate extends RealDate {
  constructor()
  constructor(value: string | number | Date)
  constructor(year: number, month: number, day?: number, hour?: number, minute?: number, second?: number, millisecond?: number)
  constructor(...args: any[]) {
    if (args.length === 0) super(fixedNow)
    else if (args.length === 1) super(args[0] instanceof RealDate ? args[0].getTime() : args[0])
    else super(args[0], args[1], args[2] ?? 1, args[3] ?? 0, args[4] ?? 0, args[5] ?? 0, args[6] ?? 0)
  }
  static now() { return fixedNow }
}
globalThis.Date = FixtureDate as DateConstructor
const now = new RealDate(fixedNow)

const pad = (n: number) => String(n).padStart(2, "0")
function localParts(date: Date) {
  return { year: date.getFullYear(), month: date.getMonth() + 1, day: date.getDate(), hour: date.getHours(), minute: date.getMinutes(), second: date.getSeconds() }
}
function localText(date: Date) {
  const p = localParts(date)
  return `${p.year}-${pad(p.month)}-${pad(p.day)} ${pad(p.hour)}:${pad(p.minute)}`
}

// ---- Calendar: the real plan -------------------------------------------------------------------------------------
type Row = {
  identifier: string; title: string; body: string; url: string; sound: string
  triggerUTC: string; triggerEpochMs: number; local: string; offsetMinutesEast: number
  components: { year: number; month: number; day: number; hour: number; minute: number; second: number }
}
const calendarRows: Row[] = []
let calendarSettings: { enabled: boolean; hour: number; minute: number } | null = null
if (calendarArg !== "off") {
  const { hour, minute } = parseTime(calendarArg, "--calendar")
  calendarSettings = { enabled: true, hour, minute }
  const plan = calendarService.calendarNotificationPlan(calendarSettings, new RealDate(fixedNow)).slice(0, 30)
  for (const item of plan) {
    calendarRows.push({
      identifier: item.identifier, title: item.title, body: item.body, url: item.url, sound: "default",
      triggerUTC: item.date.toISOString(), triggerEpochMs: item.date.getTime(), local: localText(item.date),
      offsetMinutesEast: -item.date.getTimezoneOffset(), components: localParts(item.date),
    })
  }
}

// ---- Rosary: the real scheduler ----------------------------------------------------------------------------------
let rosary: any = null
if (rosaryMode !== "off") {
  const { hour, minute } = parseTime(rosaryTime, "--rosary-time")
  scheduled.length = 0
  await rosaryService.scheduleRosaryReminder({ enabled: true, frequency: rosaryMode as "daily" | "weekly", hour, minute, weekday: rosaryWeekday })
  const request = scheduled[0]
  // Next trigger date: the first local time after `now` that matches the trigger fields (Expo weekday: 1 = Sunday).
  const next = new RealDate(fixedNow)
  next.setHours(hour, minute, 0, 0)
  for (let step = 0; step < 15; step++) {
    const weekdayOk = rosaryMode === "daily" || next.getDay() + 1 === rosaryWeekday
    if (next.getTime() > fixedNow && weekdayOk) break
    next.setDate(next.getDate() + 1)
    next.setHours(hour, minute, 0, 0)
  }
  rosary = {
    title: request.content.title, body: request.content.body, sound: request.content.sound, url: request.content.data.url,
    trigger: { type: request.trigger.type, hour, minute, ...(rosaryMode === "weekly" ? { weekday: rosaryWeekday } : {}) },
    repeats: true,
    nextTriggerUTC: next.toISOString(), nextLocal: localText(next),
    note: "The old source sets hour, minute, and weekday only. The next date is computed here. The native app uses the fixed ID john-rosary:reminder.",
  }
}

// ---- Output ------------------------------------------------------------------------------------------------------
const offsets = [...new Set(calendarRows.map((r) => r.offsetMinutesEast))]
const dstChange = calendarRows.find((row, i) => i > 0 && row.offsetMinutesEast !== calendarRows[i - 1].offsetMinutesEast)
const sourcePaths = [
  "src/services/companion/calendarNotifications.ts", "src/services/companion/calendar.ts",
  "src/services/companion/data/readings-us.json", "src/services/companion/data/celebrations-us.json",
  "src/services/rosary/reminders.ts", "scripts/native/source-fixtures/notifications/notice-expected.ts",
]
const result = {
  schema: "notice-expected-v1",
  input: { now: nowText, nowEpochMs: fixedNow, timezone, calendar: calendarArg, rosary: rosaryMode, rosaryTime, rosaryWeekday },
  calendar: {
    count: calendarRows.length, requests: calendarRows,
    utcOffsetsMinutesEast: offsets,
    firstOffsetChange: dstChange ? { atLocal: dstChange.local, atUTC: dstChange.triggerUTC, offsetMinutesEast: dstChange.offsetMinutesEast } : null,
  },
  rosary,
  sourceSha256: Object.fromEntries(sourcePaths.map((p) => [p, createHash("sha256").update(readFileSync(join(root, p))).digest("hex")])),
  note: "Calendar rows come from the old calendarNotificationPlan with a fixed clock. The trigger is a one-shot date trigger for each row.",
}

function markdown(): string {
  const lines = [
    "# Expected notices", "",
    `Session instant: \`${nowText}\`. Time zone: \`${timezone}\` (local ${localText(now)}). Tool: \`notice-expected.ts\` (old source, fixed clock).`, "",
  ]
  if (calendarRows.length) {
    lines.push(`## Calendar notices (${calendarRows.length} requests, daily at ${calendarArg})`, "",
      "| # | Local delivery | UTC | UTC offset | Title | Body | URL |", "| --- | --- | --- | --- | --- | --- | --- |")
    calendarRows.forEach((r, i) => lines.push(
      `| ${i + 1} | ${r.local} | ${r.triggerUTC} | ${r.offsetMinutesEast / 60 >= 0 ? "+" : ""}${r.offsetMinutesEast / 60} h | ${r.title} | ${r.body} | \`${r.url}\` |`))
    lines.push("", dstChange
      ? `The UTC offset changes at row ${calendarRows.indexOf(dstChange) + 1} (${dstChange.local} local). The local delivery time stays ${calendarArg}.`
      : "The UTC offset does not change in this window.", "")
  } else lines.push("## Calendar notices", "", "Off.", "")
  if (rosary) {
    lines.push("## Rosary reminder", "", "| Field | Value |", "| --- | --- |",
      `| Title | ${rosary.title} |`, `| Body | ${rosary.body} |`, `| URL | \`${rosary.url}\` |`,
      `| Trigger | ${rosary.trigger.type}${rosary.trigger.weekday ? `, weekday ${rosary.trigger.weekday}` : ""}, ${pad(rosary.trigger.hour)}:${pad(rosary.trigger.minute)}, repeats |`,
      `| Next delivery (computed here) | ${rosary.nextLocal} local, ${rosary.nextTriggerUTC} |`, "")
  } else lines.push("## Rosary reminder", "", "Off.", "")
  return lines.join("\n")
}

// ---- Compare ------------------------------------------------------------------------------------------------------
function compare(path: string): boolean {
  const stage = JSON.parse(readFileSync(resolve(path), "utf8"))
  const pending: any[] = stage.systemSnapshot?.pendingRequests ?? stage.pendingRequests ?? []
  const problems: string[] = []
  const calendarPending = pending.filter((p) => String(p.identifier).startsWith("john-calendar:"))
    .sort((a, b) => String(a.identifier).localeCompare(String(b.identifier)))
  const expected = [...calendarRows].sort((a, b) => a.identifier.localeCompare(b.identifier))
  if (calendarPending.length !== expected.length) problems.push(`calendar count ${calendarPending.length} != expected ${expected.length}`)
  let matched = 0
  expected.forEach((row, i) => {
    const got = calendarPending[i]
    if (!got) return
    const url = got.content?.userInfo?.url?.value
    const c = got.trigger?.calendarComponents ?? {}
    const checks: [string, unknown, unknown][] = [
      ["identifier", got.identifier, row.identifier], ["title", got.content?.title, row.title], ["body", got.content?.body, row.body],
      ["url", url, row.url], ["sound", got.content?.sound, row.sound], ["nextTriggerDateUTC", got.trigger?.nextTriggerDateUTC, row.triggerUTC],
      ["repeats", got.trigger?.repeats, false], ["calendarTimeZone", c.calendarTimeZoneIdentifier, timezone],
      ["year", c.year, row.components.year], ["month", c.month, row.components.month], ["day", c.day, row.components.day],
      ["hour", c.hour, row.components.hour], ["minute", c.minute, row.components.minute],
    ]
    const bad = checks.filter(([, a, b]) => a !== b)
    if (bad.length === 0) matched++
    else problems.push(`${row.identifier}: ` + bad.map(([n, a, b]) => `${n} got ${JSON.stringify(a)} expected ${JSON.stringify(b)}`).join("; "))
  })
  const rosaryPending = pending.filter((p) => String(p.identifier).startsWith("john-rosary:"))
  if (rosary) {
    if (rosaryPending.length !== 1) problems.push(`rosary count ${rosaryPending.length} != 1`)
    else {
      const got = rosaryPending[0]
      const c = got.trigger?.calendarComponents ?? {}
      const checks: [string, unknown, unknown][] = [
        ["title", got.content?.title, rosary.title], ["body", got.content?.body, rosary.body], ["url", got.content?.userInfo?.url?.value, rosary.url],
        ["sound", got.content?.sound, rosary.sound], ["repeats", got.trigger?.repeats, true], ["hour", c.hour, rosary.trigger.hour],
        ["minute", c.minute, rosary.trigger.minute], ["weekday", c.weekday, rosary.trigger.weekday], ["nextTriggerDateUTC", got.trigger?.nextTriggerDateUTC, rosary.nextTriggerUTC],
      ].filter(([name, , expectedValue]) => !(name === "weekday" && expectedValue === undefined)) as [string, unknown, unknown][]
      const bad = checks.filter(([, a, b]) => a !== b)
      if (bad.length) problems.push("rosary: " + bad.map(([n, a, b]) => `${n} got ${JSON.stringify(a)} expected ${JSON.stringify(b)}`).join("; "))
    }
  } else if (rosaryPending.length) problems.push(`rosary request present (${rosaryPending.length}) but expected off`)
  console.error(`compare ${path}: calendar ${matched}/${expected.length} rows match exactly; rosary ${rosary ? (rosaryPending.length === 1 ? "checked" : "missing") : "off"}`)
  for (const p of problems) console.error(`  DIFFERENCE: ${p}`)
  return problems.length === 0
}

if (jsonPath) writeFileSync(resolve(jsonPath), JSON.stringify(result, null, 2) + "\n", { flag: "wx" })
if (mdPath) writeFileSync(resolve(mdPath), markdown() + "\n", { flag: "wx" })
else if (!comparePath) console.log(markdown())
if (comparePath) process.exit(compare(comparePath) ? 0 : 1)
