import { useState } from "react"
import { Linking, Platform, Switch } from "react-native"
import DateTimePicker from "@react-native-community/datetimepicker"

import { Button } from "@/components/Button"
import { ActionRow, Muted, Page, SectionTitle } from "@/components/companion/Companion"
import { Text } from "@/components/Text"
import {
  getCalendarNotificationSettings,
  saveCalendarNotifications,
} from "@/services/companion/calendarNotifications"

export function CalendarNotificationsScreen() {
  const [settings, setSettings] = useState(getCalendarNotificationSettings)
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState("")
  const [showTime, setShowTime] = useState(false)
  const time = new Date(2024, 0, 1, settings.hour, settings.minute)
  const supported = Platform.OS !== "web"
  const save = async () => {
    setBusy(true)
    setMessage("")
    try {
      const saved = await saveCalendarNotifications(settings)
      setSettings(saved)
      setMessage(
        saved.enabled ? "Calendar notifications are on." : "Calendar notifications are off.",
      )
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : "Could not update notifications. Please try again.",
      )
    } finally {
      setBusy(false)
    }
  }
  return (
    <Page
      title="A day in the Church"
      eyebrow="Calendar notifications"
      subtitle="A gentle morning notice for today’s saint, feast, or liturgical observance, with the Gospel reference when available."
    >
      <SectionTitle title="Notify me each day" />
      <Switch
        accessibilityLabel="Enable calendar notifications"
        disabled={busy || !supported}
        value={settings.enabled}
        onValueChange={(enabled) => {
          setSettings({ ...settings, enabled })
          setMessage("")
        }}
      />
      {supported ? (
        <ActionRow
          title="Delivery time"
          subtitle={time.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}
          icon="clock"
          onPress={() => {
            if (!busy) setShowTime(true)
          }}
        />
      ) : (
        <Text text="Delivery time · 8:00 AM" />
      )}
      {supported && showTime && (
        <DateTimePicker
          value={time}
          mode="time"
          display={Platform.OS === "ios" ? "spinner" : "default"}
          onChange={(_event, date) => {
            if (Platform.OS === "android") setShowTime(false)
            if (date) {
              setSettings({ ...settings, hour: date.getHours(), minute: date.getMinutes() })
              setMessage("")
            }
          }}
          accessibilityLabel="Calendar notification time"
        />
      )}
      <Muted text="United States · Roman Rite. Parish calendars and transferred feasts can differ. Each notice opens that date’s readings." />
      <Muted text="Notices are scheduled on your phone up to a month ahead. Open John 1:1 at least monthly to keep them coming, and after changing time zones to update the delivery time." />
      {!supported && <Muted text="Notifications are available in the iOS and Android app." />}
      {!!message && <Text text={message} accessibilityLiveRegion="polite" />}
      <Button
        text={busy ? "Saving…" : "Save notifications"}
        disabled={busy || !supported}
        onPress={save}
      />
      {supported && (
        <Button
          text="Device notification settings"
          onPress={() =>
            Linking.openSettings().catch(() =>
              setMessage("Open your device’s Settings app to manage notification permissions."),
            )
          }
        />
      )}
    </Page>
  )
}
