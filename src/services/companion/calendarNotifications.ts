import { Platform } from "react-native"

import { load, saveString } from "@/utils/storage"

import { addDays, celebrationFor, dateKey, readingsFor } from "./calendar"

const KEY = "john.calendar-notifications.v1"
const PREFIX = "john-calendar:"
const CHANNEL = "catholic-calendar"
export type CalendarNotificationSettings = { enabled: boolean; hour: number; minute: number }
export const DEFAULT_CALENDAR_NOTIFICATIONS: CalendarNotificationSettings = {
  enabled: false,
  hour: 8,
  minute: 0,
}
export function normalizeCalendarNotifications(value: unknown): CalendarNotificationSettings {
  const data =
    value && typeof value === "object" ? (value as Partial<CalendarNotificationSettings>) : {}
  const valid = (n: unknown, max: number): n is number =>
    typeof n === "number" && Number.isInteger(n) && n >= 0 && n <= max
  return {
    enabled: data.enabled === true,
    hour: valid(data.hour, 23) ? data.hour : 8,
    minute: valid(data.minute, 59) ? data.minute : 0,
  }
}
export function getCalendarNotificationSettings() {
  return normalizeCalendarNotifications(load(KEY))
}
export function calendarNotificationPlan(settings: CalendarNotificationSettings, now = new Date()) {
  const plan = []
  for (let offset = 0; offset <= 30; offset++) {
    const date = addDays(now, offset)
    date.setHours(settings.hour, settings.minute, 0, 0)
    if (date <= now) continue
    const celebration = celebrationFor(date)
    if (!celebration) continue
    const readings = readingsFor(date)
    const gospel = readings?.readings.find((r) => r.label === "Gospel")?.reference
    plan.push({
      identifier: `${PREFIX}${date.getTime()}`,
      date,
      title: readings?.title ?? celebration.title,
      body: gospel
        ? `Today’s Gospel: ${gospel}. Open your daily readings.`
        : "Take a moment with today’s Catholic calendar and readings.",
      url: `/daily?date=${dateKey(date)}`,
    })
  }
  return plan.slice(0, 30)
}

// Serialize foreground replenishment with settings changes to avoid duplicate or stale schedules.
let queue: Promise<unknown> = Promise.resolve()
function serial<T>(work: () => Promise<T>): Promise<T> {
  const result = queue.then(work, work)
  queue = result.catch(() => {})
  return result
}

async function reconcile(requested: CalendarNotificationSettings, askPermission: boolean) {
  const settings = normalizeCalendarNotifications(requested)
  if (Platform.OS === "web") {
    if (settings.enabled)
      throw Error("Calendar notifications are available in the iOS and Android app.")
    return settings
  }
  const Notifications: typeof import("expo-notifications") = require("expo-notifications")
  if (settings.enabled) {
    if (Platform.OS === "android")
      await Notifications.setNotificationChannelAsync(CHANNEL, {
        name: "Catholic calendar",
        importance: Notifications.AndroidImportance.DEFAULT,
        sound: "default",
      })
    let permission = await Notifications.getPermissionsAsync()
    if (!permission.granted && askPermission)
      permission = await Notifications.requestPermissionsAsync({
        ios: { allowAlert: true, allowSound: true, allowBadge: false },
      })
    if (!permission.granted)
      throw Error("Allow notifications in your device settings to receive calendar events.")
  }
  const pending = await Notifications.getAllScheduledNotificationsAsync()
  const owned = pending.filter((n) => n.identifier.startsWith(PREFIX))
  // Leave room for existing Rosary reminders and other application notifications.
  const capacity = Math.max(0, Math.min(30, 62 - (pending.length - owned.length)))
  if (settings.enabled && capacity === 0)
    throw Error("Your notification schedule is full. Remove a reminder and try again.")
  const plan = settings.enabled ? calendarNotificationPlan(settings).slice(0, capacity) : []
  if (settings.enabled && plan.length === 0)
    throw Error(
      "No upcoming calendar dates are installed. Update John 1:1 to refresh the calendar.",
    )
  const desired = new Set(plan.map((p) => p.identifier))
  const existing = new Set(owned.map((n) => n.identifier))
  const created: string[] = []
  const removed: typeof owned = []
  try {
    for (const old of owned) {
      if (!desired.has(old.identifier)) {
        await Notifications.cancelScheduledNotificationAsync(old.identifier)
        removed.push(old)
      }
    }
    for (const item of plan) {
      if (existing.has(item.identifier)) continue
      const id = await Notifications.scheduleNotificationAsync({
        identifier: item.identifier,
        content: { title: item.title, body: item.body, sound: "default", data: { url: item.url } },
        trigger: {
          type: Notifications.SchedulableTriggerInputTypes.DATE,
          date: item.date,
          channelId: Platform.OS === "android" ? CHANNEL : undefined,
        },
      })
      created.push(id)
    }
    if (!saveString(KEY, JSON.stringify(settings)))
      throw Error("Could not save notification settings. Please try again.")
  } catch (error) {
    await Promise.allSettled(
      created.map((id) => Notifications.cancelScheduledNotificationAsync(id)),
    )
    await Promise.allSettled(
      removed.map((old) => {
        const date = new Date(Number(old.identifier.slice(PREFIX.length)))
        if (!Number.isFinite(date.getTime()) || date <= new Date()) return Promise.resolve()
        return Notifications.scheduleNotificationAsync({
          identifier: old.identifier,
          content: {
            title: old.content.title,
            body: old.content.body,
            data: old.content.data,
            sound: "default",
          },
          trigger: {
            type: Notifications.SchedulableTriggerInputTypes.DATE,
            date,
            channelId: Platform.OS === "android" ? CHANNEL : undefined,
          },
        })
      }),
    )
    throw error
  }
  return settings
}
export function saveCalendarNotifications(settings: CalendarNotificationSettings) {
  return serial(() => reconcile(settings, true))
}
export function refreshCalendarNotifications() {
  return serial(async () => {
    const settings = getCalendarNotificationSettings()
    if (settings.enabled) await reconcile(settings, false)
  })
}
