import { createHash } from "node:crypto"
import { mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { mock } from "bun:test"

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../../../..")
const output = resolve(process.argv[2] ?? join(root, "build/native-evidence/L22/source-notifications.json"))
const storageValues = new Map<string, string>()
let failStorageWrite = false
let permissionGranted = true
let serialID = 0
let pending: any[] = []
const scheduled: any[] = []
const cancelled: string[] = []

class MemoryMMKV {
  getString(key: string) { return storageValues.get(key) }
  set(key: string, value: string) {
    if (failStorageWrite) throw new Error("fixture storage write failure")
    storageValues.set(key, value)
  }
  delete(key: string) { storageValues.delete(key) }
  clearAll() { storageValues.clear() }
}

const notificationModule = {
  SchedulableTriggerInputTypes: { DATE: "date", DAILY: "daily", WEEKLY: "weekly" },
  AndroidImportance: { DEFAULT: 3 },
  getPermissionsAsync: async () => ({ granted: permissionGranted }),
  requestPermissionsAsync: async () => ({ granted: permissionGranted }),
  getAllScheduledNotificationsAsync: async () => pending.map((item) => ({ ...item })),
  scheduleNotificationAsync: async (request: any) => {
    scheduled.push(request)
    const identifier = request.identifier ?? `fixture-created-${++serialID}`
    pending.push({ ...request, identifier })
    return identifier
  },
  cancelScheduledNotificationAsync: async (identifier: string) => {
    cancelled.push(identifier)
    pending = pending.filter((item) => item.identifier !== identifier)
  },
  setNotificationChannelAsync: async () => undefined,
}

mock.module("react-native", () => ({ Platform: { OS: "ios" } }))
mock.module("react-native-mmkv", () => ({ MMKV: MemoryMMKV }))
mock.module("expo-notifications", () => notificationModule)
process.env.EXPO_OS = "ios"

const calendarService = await import("../../../../src/services/companion/calendarNotifications")
const calendar = await import("../../../../src/services/companion/calendar")
const rosaryService = await import("../../../../src/services/rosary/reminders")

const RealDate = globalThis.Date
let fixedNow = 0
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

function resetStub() {
  pending = []
  scheduled.length = 0
  cancelled.length = 0
  storageValues.clear()
  failStorageWrite = false
  permissionGranted = true
  serialID = 0
}

function serializableDate(date: Date) {
  return {
    iso: date.toISOString(),
    epochMilliseconds: date.getTime(),
    local: `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}T${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`,
    offsetMinutesEast: -date.getTimezoneOffset(),
  }
}

function sourceHashes() {
  const paths = [
    "src/services/companion/calendarNotifications.ts",
    "src/services/companion/calendar.ts",
    "src/services/companion/data/readings-us.json",
    "src/services/companion/data/celebrations-us.json",
    "src/services/rosary/reminders.ts",
    "src/services/rosary/types.ts",
    "src/screens/companion/CalendarNotificationsScreen.tsx",
    "src/screens/rosary/rosary-reminder-screen.tsx",
    "scripts/native/source-fixtures/notifications/notice-fixtures.ts",
  ]
  return Object.fromEntries(paths.map((path) => [path, createHash("sha256").update(readFileSync(join(root, path))).digest("hex")]))
}

async function calendarSaveCase(name: string, timezone: string, nowISO: string,
                                settings = { enabled: true, hour: 8, minute: 0 },
                                setup?: () => void) {
  resetStub()
  process.env.TZ = timezone
  fixedNow = new RealDate(nowISO).getTime()
  setup?.()
  const before = pending.map((item) => ({ identifier: item.identifier, content: item.content ?? null, trigger: item.trigger ?? null }))
  let result: unknown = null
  let error: string | null = null
  try { result = await calendarService.saveCalendarNotifications(settings) }
  catch (caught) { error = caught instanceof Error ? caught.message : String(caught) }
  return {
    name, timezone, now: serializableDate(new RealDate(fixedNow)), settings,
    result,
    error,
    before,
    scheduled: scheduled.map((request) => ({
      identifier: request.identifier,
      title: request.content?.title,
      body: request.content?.body,
      sound: request.content?.sound,
      data: request.content?.data,
      trigger: request.trigger ? { type: request.trigger.type, date: request.trigger.date ? serializableDate(request.trigger.date) : null, channelId: request.trigger.channelId ?? null } : null,
    })),
    cancelled: [...cancelled],
    afterIDs: pending.map((item) => item.identifier),
    stored: storageValues.get("john.calendar-notifications.v1") ?? null,
  }
}

function planCase(name: string, timezone: string, nowISO: string, hour: number, minute: number) {
  process.env.TZ = timezone
  const now = new RealDate(nowISO)
  const items = calendarService.calendarNotificationPlan({ enabled: true, hour, minute }, now)
  return {
    name, timezone, now: serializableDate(now), hour, minute, count: items.length,
    items: items.map((item) => ({
      identifier: item.identifier,
      date: serializableDate(item.date),
      title: item.title,
      body: item.body,
      url: item.url,
    })),
  }
}

async function rosaryCase(name: string, settings: any, permission: boolean) {
  resetStub()
  permissionGranted = permission
  let result: unknown = null
  let error: string | null = null
  try { result = await rosaryService.scheduleRosaryReminder(settings) }
  catch (caught) { error = caught instanceof Error ? caught.message : String(caught) }
  return {
    name, settings, result, error,
    scheduled: scheduled.map((request) => ({
      identifier: request.identifier ?? null,
      content: request.content,
      trigger: request.trigger,
    })),
    cancelled: [...cancelled],
    stored: storageValues.get("rosary.reminder.v1") ?? null,
  }
}

const coverage = calendar.calendarCoverage()
const [, coverageEnd] = coverage.split(" to ")
if (!coverageEnd) throw new Error(`Unexpected calendar coverage: ${coverage}`)
const installedDates = Object.keys(JSON.parse(readFileSync(join(root, "src/services/companion/data/readings-us.json"), "utf8")))
  .sort()
const firstDate = installedDates[0]
const lastDate = installedDates.at(-1)!
const genericFallbackDates = installedDates.filter((key) => {
  const date = calendar.parseDate(key)
  return !!calendar.celebrationFor(date) && !calendar.readingsFor(date)?.readings.some((reading) => reading.label === "Gospel")
})

const calendarPlans = [
  planCase("toronto-before-08", "America/Toronto", "2026-10-06T11:59:59.000Z", 8, 0),
  planCase("toronto-at-08", "America/Toronto", "2026-10-06T12:00:00.000Z", 8, 0),
  planCase("toronto-after-08", "America/Toronto", "2026-10-06T12:00:01.000Z", 8, 0),
  planCase("utc-before-08", "UTC", "2026-10-06T07:59:59.000Z", 8, 0),
  planCase("utc-at-08", "UTC", "2026-10-06T08:00:00.000Z", 8, 0),
  planCase("utc-after-08", "UTC", "2026-10-06T08:00:01.000Z", 8, 0),
  planCase("spring-before", "America/Toronto", "2026-03-08T04:59:59.000Z", 8, 0),
  planCase("spring-nonexistent-0230", "America/Toronto", "2026-03-07T07:00:00.000Z", 2, 30),
  planCase("spring-after", "America/Toronto", "2026-03-08T07:00:01.000Z", 8, 0),
  planCase("fall-before", "America/Toronto", "2026-11-01T03:59:59.000Z", 8, 0),
  planCase("fall-repeated-0130", "America/Toronto", "2026-10-31T04:00:00.000Z", 1, 30),
  planCase("fall-after", "America/Toronto", "2026-11-01T06:00:01.000Z", 8, 0),
  planCase("coverage-end", "UTC", `${lastDate}T00:00:01.000Z`, 8, 0),
  planCase("no-plan-after-calendar-data", "UTC", "2099-12-31T23:59:59.000Z", 8, 0),
]
const genericFallbackPlanItems = calendarPlans.flatMap((plan) => plan.items)
  .filter((item) => item.body === "Take a moment with today’s Catholic calendar and readings.")

const calendarOperations = [
  await calendarSaveCase("calendar-plan-capacity-30", "America/Toronto", "2026-10-06T11:00:00.000Z"),
  await calendarSaveCase("calendar-unrelated-capacity", "America/Toronto", "2026-10-06T11:00:00.000Z", undefined,
    () => { pending = [...Array.from({ length: 40 }, (_, i) => ({ identifier: `other:${i}` })), { identifier: "rosary:legacy", content: { title: "Keep Rosary" } }] }),
  await calendarSaveCase("calendar-owned-reconcile-preserves-other-features", "America/Toronto", "2026-10-06T11:00:00.000Z", undefined,
    () => {
      const plan = calendarService.calendarNotificationPlan({ enabled: true, hour: 8, minute: 0 }, new Date(fixedNow))
      pending = [
        { identifier: plan[0]?.identifier, content: { title: "Keep matching calendar request" } },
        { identifier: "john-calendar:1", content: { title: "Remove obsolete calendar request", body: "Old" }, trigger: { date: new Date(fixedNow + 3_600_000) } },
        { identifier: "rosary:legacy", content: { title: "Keep Rosary" } },
        { identifier: "unrelated:keep", content: { title: "Keep other" } },
      ]
    }),
  await calendarSaveCase("calendar-disabled-removes-only-owned", "America/Toronto", "2026-10-06T11:00:00.000Z",
    { enabled: false, hour: 9, minute: 15 },
    () => { pending = [
      { identifier: "john-calendar:1", content: { title: "Owned calendar" } },
      { identifier: "rosary:legacy", content: { title: "Keep Rosary" } },
      { identifier: "other:keep", content: { title: "Keep other" } },
    ] }),
  await calendarSaveCase("calendar-no-permission", "America/Toronto", "2026-10-06T11:00:00.000Z", undefined,
    () => { permissionGranted = false }),
  await calendarSaveCase("calendar-no-capacity", "America/Toronto", "2026-10-06T11:00:00.000Z", undefined,
    () => { pending = Array.from({ length: 62 }, (_, i) => ({ identifier: `other:${i}` })) }),
  await calendarSaveCase("calendar-no-plan", "UTC", "2099-12-31T23:59:59.000Z"),
  await calendarSaveCase("calendar-storage-failure-rollback", "America/Toronto", "2026-10-06T11:00:00.000Z", undefined,
    () => {
      failStorageWrite = true
      pending = [{ identifier: `john-calendar:${fixedNow + 7_200_000}`, content: { title: "Restore this old future request", body: "Old" } }]
    }),
]

const rosaryOperations = [
  await rosaryCase("default-disabled", rosaryService.DEFAULT_ROSARY_REMINDER, true),
  await rosaryCase("enabled-daily", { enabled: true, frequency: "daily", hour: 20, minute: 0, weekday: 2 }, true),
  await rosaryCase("enabled-weekly-monday", { enabled: true, frequency: "weekly", hour: 20, minute: 0, weekday: 2 }, true),
  await rosaryCase("replace-legacy-request", { enabled: true, frequency: "weekly", hour: 20, minute: 0, weekday: 2, notificationId: "legacy-rosary-id" }, true),
  await rosaryCase("disabled-removes-owned-id", { enabled: false, frequency: "daily", hour: 20, minute: 0, weekday: 2, notificationId: "legacy-rosary-id" }, true),
  await rosaryCase("denied-source-resets-settings", { enabled: true, frequency: "weekly", hour: 20, minute: 0, weekday: 2, notificationId: "legacy-rosary-id" }, false),
]

globalThis.Date = RealDate
const result = {
  formatVersion: 1,
  evidenceKind: "actual-source-execution-with-controlled-notification-and-storage-stubs",
  nativeContractBoundary: {
    note: "The following source behavior is separate from the frozen native serialized/durable settings contract.",
    rosaryPermissionDenial: "Source cancels its stored notificationID first, then stores disabled settings with no ID before throwing. Native must follow its reviewed durable rollback contract instead.",
    calendarPermissionDenial: "Source throws before schedule changes or settings save.",
  },
  calendar: {
    coverage,
    installedDateCount: installedDates.length,
    firstDate,
    lastDate,
    normalization: [
      null,
      { enabled: 1, hour: 24, minute: 10 },
      { enabled: true, hour: 8, minute: 59 },
      { enabled: false, hour: -1, minute: 60 },
    ].map((input) => ({ input, output: calendarService.normalizeCalendarNotifications(input) })),
    genericFallbackDates,
    genericFallbackPlanItems,
    plans: calendarPlans,
    operations: calendarOperations,
    planRules: "Actual calendarNotificationPlan: offsets 0...30, local delivery hour/minute, only future instants with a celebration, plan capped at 30.",
  },
  rosary: {
    normalization: [
      null,
      { enabled: "yes", frequency: "weekly", hour: 25, minute: 12.5, weekday: 0, notificationId: 44 },
      { enabled: true, frequency: "weekly", hour: 20, minute: 55, weekday: 7, notificationId: "source-id" },
    ].map((input) => ({ input, output: rosaryService.normalizeRosaryReminder(input) })),
    operations: rosaryOperations,
    sourceConstants: { title: "A quiet moment for the Rosary", body: "Take a few minutes to pray with Mary and contemplate the life of Christ.", payload: { url: "/pray/rosary" }, sound: "default", defaultSettings: rosaryService.DEFAULT_ROSARY_REMINDER },
  },
  sourceHashes: sourceHashes(),
}

mkdirSync(dirname(output), { recursive: true })
writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`)
console.log(`Wrote ${calendarPlans.length} calendar plan cases and ${rosaryOperations.length} Rosary service cases: ${output}`)
