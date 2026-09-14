import type { NotificationTriggerInput } from "expo-notifications"

import { load, save } from "@/utils/storage"

import type { RosaryReminderSettings } from "./types"

const STORAGE_KEY = "rosary.reminder.v1"
const ANDROID_CHANNEL_ID = "rosary-reminders"

export const DEFAULT_ROSARY_REMINDER: RosaryReminderSettings = {
  enabled: false,
  frequency: "daily",
  hour: 20,
  minute: 0,
  weekday: 2,
}

function isIntegerInRange(value: unknown, min: number, max: number): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= min && value <= max
}

export function normalizeRosaryReminder(value: unknown): RosaryReminderSettings {
  if (!value || typeof value !== "object") return { ...DEFAULT_ROSARY_REMINDER }

  const candidate = value as Partial<RosaryReminderSettings>
  return {
    enabled: candidate.enabled === true,
    frequency: candidate.frequency === "weekly" ? "weekly" : "daily",
    hour: isIntegerInRange(candidate.hour, 0, 23) ? candidate.hour : DEFAULT_ROSARY_REMINDER.hour,
    minute: isIntegerInRange(candidate.minute, 0, 59)
      ? candidate.minute
      : DEFAULT_ROSARY_REMINDER.minute,
    weekday: isIntegerInRange(candidate.weekday, 1, 7)
      ? candidate.weekday
      : DEFAULT_ROSARY_REMINDER.weekday,
    notificationId:
      typeof candidate.notificationId === "string" ? candidate.notificationId : undefined,
  }
}

export function getRosaryReminderSettings(): RosaryReminderSettings {
  return normalizeRosaryReminder(load<unknown>(STORAGE_KEY))
}

export function getRosaryReminderSummary(settings = getRosaryReminderSettings()): string {
  if (!settings.enabled) return "No reminder set"

  const date = new Date(2024, 0, 7, settings.hour, settings.minute)
  const time = new Intl.DateTimeFormat(undefined, { hour: "numeric", minute: "2-digit" }).format(
    date,
  )
  if (settings.frequency === "daily") return `Every day at ${time}`

  const day = new Intl.DateTimeFormat(undefined, { weekday: "long" }).format(
    new Date(2024, 0, 6 + settings.weekday),
  )
  return `Every ${day} at ${time}`
}

export async function scheduleRosaryReminder(
  requested: RosaryReminderSettings,
): Promise<RosaryReminderSettings> {
  const settings = normalizeRosaryReminder(requested)

  if (process.env.EXPO_OS === "web") {
    const webSettings = { ...settings, enabled: false, notificationId: undefined }
    save(STORAGE_KEY, webSettings)
    throw new Error("Rosary reminders are available on iOS and Android.")
  }

  const Notifications = await import("expo-notifications")

  if (settings.notificationId) {
    await Notifications.cancelScheduledNotificationAsync(settings.notificationId).catch(() => {})
  }

  if (!settings.enabled) {
    const disabled = { ...settings, notificationId: undefined }
    save(STORAGE_KEY, disabled)
    return disabled
  }

  if (process.env.EXPO_OS === "android") {
    await Notifications.setNotificationChannelAsync(ANDROID_CHANNEL_ID, {
      name: "Rosary reminders",
      description: "Gentle reminders to pray the Rosary.",
      importance: Notifications.AndroidImportance.DEFAULT,
      sound: "default",
    })
  }

  const currentPermission = await Notifications.getPermissionsAsync()
  const permission = currentPermission.granted
    ? currentPermission
    : await Notifications.requestPermissionsAsync({
        ios: { allowAlert: true, allowSound: true, allowBadge: false },
      })

  if (!permission.granted) {
    const denied = { ...settings, enabled: false, notificationId: undefined }
    save(STORAGE_KEY, denied)
    throw new Error("Notifications are disabled. You can allow them in your device settings.")
  }

  const channelId = process.env.EXPO_OS === "android" ? ANDROID_CHANNEL_ID : undefined
  const trigger: NotificationTriggerInput =
    settings.frequency === "daily"
      ? {
          type: Notifications.SchedulableTriggerInputTypes.DAILY,
          hour: settings.hour,
          minute: settings.minute,
          channelId,
        }
      : {
          type: Notifications.SchedulableTriggerInputTypes.WEEKLY,
          weekday: settings.weekday,
          hour: settings.hour,
          minute: settings.minute,
          channelId,
        }

  const notificationId = await Notifications.scheduleNotificationAsync({
    content: {
      title: "A quiet moment for the Rosary",
      body: "Take a few minutes to pray with Mary and contemplate the life of Christ.",
      sound: "default",
      data: { url: "/pray/rosary" },
    },
    trigger,
  })

  const scheduled = { ...settings, notificationId }
  save(STORAGE_KEY, scheduled)
  return scheduled
}
