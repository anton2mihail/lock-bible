import { Platform } from "react-native"

import { load, saveString } from "@/utils/storage"

import {
  calendarNotificationPlan,
  DEFAULT_CALENDAR_NOTIFICATIONS,
  normalizeCalendarNotifications,
  refreshCalendarNotifications,
  saveCalendarNotifications,
} from "./calendarNotifications"

jest.mock("@/utils/storage", () => ({ load: jest.fn(), saveString: jest.fn() }))
jest.mock("expo-notifications", () => ({
  getPermissionsAsync: jest.fn(),
  requestPermissionsAsync: jest.fn(),
  getAllScheduledNotificationsAsync: jest.fn(),
  cancelScheduledNotificationAsync: jest.fn(),
  scheduleNotificationAsync: jest.fn(),
  SchedulableTriggerInputTypes: { DATE: "date" },
}))
const Notifications = require("expo-notifications")

const settings = { enabled: true, hour: 8, minute: 15 }
const initialOS = Platform.OS
beforeEach(() => {
  jest.clearAllMocks()
  jest.useFakeTimers().setSystemTime(new Date(2026, 8, 9, 7))
  Object.defineProperty(Platform, "OS", { value: "ios", configurable: true })
  ;(load as jest.Mock).mockReturnValue(settings)
  ;(saveString as jest.Mock).mockReturnValue(true)
  Notifications.getPermissionsAsync.mockResolvedValue({ granted: true })
  Notifications.getAllScheduledNotificationsAsync.mockResolvedValue([])
  Notifications.scheduleNotificationAsync.mockImplementation(
    async (r: { identifier: string }) => r.identifier,
  )
  Notifications.cancelScheduledNotificationAsync.mockResolvedValue(undefined)
})
afterEach(() => {
  jest.useRealTimers()
  Object.defineProperty(Platform, "OS", { value: initialOS, configurable: true })
})

test("invalid preferences fall back to an opt-in morning schedule", () => {
  expect(normalizeCalendarNotifications({ hour: 24, minute: -1 })).toEqual(
    DEFAULT_CALENDAR_NOTIFICATIONS,
  )
})
test("plans actual calendar events with dated reading links, skipping elapsed times", () => {
  const plan = calendarNotificationPlan(settings, new Date(2026, 8, 9, 9))
  expect(plan).toHaveLength(30)
  expect(plan[0].url).toBe("/daily?date=2026-09-10")
  expect(plan.every((p) => p.date.getHours() === 8 && p.date.getMinutes() === 15)).toBe(true)
  const today = calendarNotificationPlan(settings, new Date(2026, 8, 9, 7))[0]
  expect(today.title).toContain("Peter Claver")
  expect(today.body).toContain("Luke 6:20-26")
  expect(calendarNotificationPlan(settings, new Date(2040, 0, 1))).toEqual([])
})
test("replenishment preserves unrelated reminders and does not duplicate existing calendar notices", async () => {
  const plan = calendarNotificationPlan(settings)
  Notifications.getAllScheduledNotificationsAsync.mockResolvedValue([
    { identifier: "rosary-existing" },
    { identifier: plan[0].identifier },
    { identifier: "john-calendar:1" },
  ])
  await refreshCalendarNotifications()
  expect(Notifications.scheduleNotificationAsync).toHaveBeenCalledTimes(29)
  expect(Notifications.cancelScheduledNotificationAsync).toHaveBeenCalledTimes(1)
  expect(Notifications.cancelScheduledNotificationAsync).toHaveBeenCalledWith("john-calendar:1")
  expect(Notifications.requestPermissionsAsync).not.toHaveBeenCalled()
})
test("disabling removes only calendar notices", async () => {
  Notifications.getAllScheduledNotificationsAsync.mockResolvedValue([
    { identifier: "rosary-existing" },
    { identifier: "john-calendar:1" },
  ])
  await saveCalendarNotifications({ ...settings, enabled: false })
  expect(Notifications.cancelScheduledNotificationAsync).toHaveBeenCalledWith("john-calendar:1")
  expect(Notifications.scheduleNotificationAsync).not.toHaveBeenCalled()
  expect(Notifications.getPermissionsAsync).not.toHaveBeenCalled()
})
test("denied permissions do not change the existing schedule or saved settings", async () => {
  Notifications.getPermissionsAsync.mockResolvedValue({ granted: false })
  Notifications.requestPermissionsAsync.mockResolvedValue({ granted: false })
  await expect(saveCalendarNotifications(settings)).rejects.toThrow("Allow notifications")
  expect(Notifications.cancelScheduledNotificationAsync).not.toHaveBeenCalled()
  expect(saveString).not.toHaveBeenCalled()
})
test("failed persistence removes newly scheduled notifications", async () => {
  ;(saveString as jest.Mock).mockReturnValue(false)
  await expect(saveCalendarNotifications(settings)).rejects.toThrow("Could not save")
  expect(Notifications.cancelScheduledNotificationAsync).toHaveBeenCalledTimes(30)
})
test("web does not request native permissions", async () => {
  Object.defineProperty(Platform, "OS", { value: "web", configurable: true })
  await expect(saveCalendarNotifications(settings)).rejects.toThrow("iOS and Android")
  expect(Notifications.getPermissionsAsync).not.toHaveBeenCalled()
})

test("a failed time change restores the previous future notice", async () => {
  const old = calendarNotificationPlan(settings)[0]
  Notifications.getAllScheduledNotificationsAsync.mockResolvedValue([
    {
      identifier: old.identifier,
      content: { title: old.title, body: old.body, data: { url: old.url } },
    },
  ])
  Notifications.scheduleNotificationAsync.mockRejectedValueOnce(
    Error("Device schedule unavailable"),
  )
  await expect(saveCalendarNotifications({ ...settings, hour: 9 })).rejects.toThrow(
    "Device schedule unavailable",
  )
  expect(Notifications.scheduleNotificationAsync).toHaveBeenLastCalledWith(
    expect.objectContaining({ identifier: old.identifier }),
  )
  expect(saveString).not.toHaveBeenCalled()
})

test("simultaneous enable and disable requests finish with calendar notices off", async () => {
  const pending = new Map<string, { identifier: string }>([["rosary", { identifier: "rosary" }]])
  Notifications.getAllScheduledNotificationsAsync.mockImplementation(async () => [
    ...pending.values(),
  ])
  Notifications.scheduleNotificationAsync.mockImplementation(async (r: { identifier: string }) => {
    pending.set(r.identifier, r)
    return r.identifier
  })
  Notifications.cancelScheduledNotificationAsync.mockImplementation(async (id: string) => {
    pending.delete(id)
  })
  await Promise.all([
    saveCalendarNotifications(settings),
    saveCalendarNotifications({ ...settings, enabled: false }),
  ])
  expect([...pending.keys()]).toEqual(["rosary"])
  expect(JSON.parse((saveString as jest.Mock).mock.calls.at(-1)[1]).enabled).toBe(false)
})
