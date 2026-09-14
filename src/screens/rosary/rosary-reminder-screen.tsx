import { FC, useState } from "react"
import { Pressable, Switch, TextStyle, View, ViewStyle } from "react-native"
import { useRouter } from "expo-router"
import DateTimePicker from "@react-native-community/datetimepicker"

import { Button } from "@/components/Button"
import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import {
  getRosaryReminderSettings,
  getRosaryReminderSummary,
  scheduleRosaryReminder,
  type RosaryReminderFrequency,
  type RosaryReminderSettings,
} from "@/services/rosary"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

const WEEKDAYS = [
  { value: 1, short: "Sun", long: "Sunday" },
  { value: 2, short: "Mon", long: "Monday" },
  { value: 3, short: "Tue", long: "Tuesday" },
  { value: 4, short: "Wed", long: "Wednesday" },
  { value: 5, short: "Thu", long: "Thursday" },
  { value: 6, short: "Fri", long: "Friday" },
  { value: 7, short: "Sat", long: "Saturday" },
] as const

export const RosaryReminderScreen: FC = function RosaryReminderScreen() {
  const { themed } = useAppTheme()
  const router = useRouter()
  const [settings, setSettings] = useState<RosaryReminderSettings>(getRosaryReminderSettings)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState<string>()
  const [error, setError] = useState<string>()

  const timeValue = new Date(2024, 0, 1, settings.hour, settings.minute)

  const setFrequency = (frequency: RosaryReminderFrequency) => {
    setSettings((current) => ({ ...current, frequency }))
    setMessage(undefined)
  }

  const saveReminder = async () => {
    setSaving(true)
    setMessage(undefined)
    setError(undefined)
    try {
      const saved = await scheduleRosaryReminder(settings)
      setSettings(saved)
      setMessage(
        saved.enabled ? `Saved · ${getRosaryReminderSummary(saved)}` : "Reminder turned off",
      )
    } catch (caught) {
      setSettings(getRosaryReminderSettings())
      setError(caught instanceof Error ? caught.message : "The reminder could not be saved.")
    } finally {
      setSaving(false)
    }
  }

  return (
    <Screen preset="scroll" safeAreaEdges={["top"]} contentContainerStyle={themed($container)}>
      <Pressable
        onPress={() => router.back()}
        accessibilityRole="button"
        accessibilityLabel="Back to Rosary"
        hitSlop={8}
        style={({ pressed }) => themed([$back, pressed && $pressed])}
      >
        <Text text="‹" size="xl" style={themed($backMark)} />
        <Text text="Rosary" size="sm" weight="semiBold" style={themed($tintText)} />
      </Pressable>

      <View style={themed($heading)}>
        <Text text="PRAYER RHYTHM" size="xxs" weight="semiBold" style={themed($eyebrow)} />
        <Text text="Rosary reminder" preset="heading" accessibilityRole="header" selectable />
        <Text
          text="Your phone schedules this reminder locally. It works without an account, server, or internet connection."
          size="sm"
          style={themed($subtitle)}
          selectable
        />
      </View>

      <View style={themed($settingsCard)}>
        <View style={themed($settingRow)}>
          <View style={$flex}>
            <Text text="Remind me to pray" weight="semiBold" />
            <Text
              text={
                settings.enabled
                  ? "Reminder will repeat until turned off"
                  : "No notifications scheduled"
              }
              size="xs"
              style={themed($subtitle)}
              selectable
            />
          </View>
          <Switch
            value={settings.enabled}
            onValueChange={(enabled) => {
              setSettings((current) => ({ ...current, enabled }))
              setMessage(undefined)
            }}
            accessibilityLabel="Enable Rosary reminder"
          />
        </View>

        <View style={themed($separator)} />

        <View style={themed($settingBlock)}>
          <Text text="Repeat" size="xs" weight="semiBold" />
          <View style={themed($segmented)} accessibilityRole="radiogroup">
            {(["daily", "weekly"] as const).map((frequency) => {
              const selected = settings.frequency === frequency
              return (
                <Pressable
                  key={frequency}
                  onPress={() => setFrequency(frequency)}
                  accessibilityRole="radio"
                  accessibilityState={{ checked: selected }}
                  style={({ pressed }) =>
                    themed([$segment, selected && $segmentSelected, pressed && $pressed])
                  }
                >
                  <Text
                    text={frequency === "daily" ? "Every day" : "Once a week"}
                    size="xs"
                    weight="semiBold"
                    style={selected && themed($segmentTextSelected)}
                  />
                </Pressable>
              )
            })}
          </View>
        </View>

        {settings.frequency === "weekly" && (
          <>
            <View style={themed($separator)} />
            <View style={themed($settingBlock)}>
              <Text text="Day" size="xs" weight="semiBold" />
              <View style={themed($weekdayRow)} accessibilityRole="radiogroup">
                {WEEKDAYS.map((day) => {
                  const selected = settings.weekday === day.value
                  return (
                    <Pressable
                      key={day.value}
                      onPress={() => {
                        setSettings((current) => ({ ...current, weekday: day.value }))
                        setMessage(undefined)
                      }}
                      accessibilityRole="radio"
                      accessibilityLabel={day.long}
                      accessibilityState={{ checked: selected }}
                      style={({ pressed }) =>
                        themed([$weekday, selected && $weekdaySelected, pressed && $pressed])
                      }
                    >
                      <Text
                        text={day.short.slice(0, 1)}
                        size="xs"
                        weight="semiBold"
                        style={selected && themed($segmentTextSelected)}
                      />
                    </Pressable>
                  )
                })}
              </View>
              <Text
                text={WEEKDAYS.find((day) => day.value === settings.weekday)?.long}
                size="xxs"
                style={themed($subtitle)}
              />
            </View>
          </>
        )}

        <View style={themed($separator)} />

        <View style={themed($timeRow)}>
          <View style={$flex}>
            <Text text="Time" size="xs" weight="semiBold" />
            <Text
              text="Uses your device’s current time zone"
              size="xxs"
              style={themed($subtitle)}
            />
          </View>
          {process.env.EXPO_OS === "web" ? (
            <Text
              text={`${String(settings.hour).padStart(2, "0")}:${String(settings.minute).padStart(2, "0")}`}
              weight="semiBold"
              style={$tabularNumbers}
            />
          ) : (
            <DateTimePicker
              value={timeValue}
              mode="time"
              display="compact"
              minuteInterval={5}
              onChange={(_event, date) => {
                if (!date) return
                setSettings((current) => ({
                  ...current,
                  hour: date.getHours(),
                  minute: date.getMinutes(),
                }))
                setMessage(undefined)
              }}
              accessibilityLabel="Rosary reminder time"
            />
          )}
        </View>
      </View>

      <View style={themed($privacyCard)}>
        <Text text="ON-DEVICE REMINDER" size="xxs" weight="semiBold" style={themed($eyebrow)} />
        <Text
          text="The operating system stores and delivers the schedule. The app does not upload the time or require push-notification tokens."
          size="xs"
          style={themed($subtitle)}
          selectable
        />
      </View>

      {message && (
        <Text text={message} size="xs" weight="semiBold" style={themed($success)} selectable />
      )}
      {error && <Text text={error} size="xs" style={themed($error)} selectable />}

      <Button
        text={saving ? "Saving…" : settings.enabled ? "Save reminder" : "Turn reminder off"}
        preset="reversed"
        onPress={saveReminder}
        disabled={saving}
      />
    </Screen>
  )
}

const $container: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingHorizontal: spacing.lg,
  paddingTop: spacing.md,
  paddingBottom: spacing.xxl,
  gap: spacing.lg,
})
const $back: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 40,
  alignSelf: "flex-start",
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.xxs,
})
const $backMark: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint, marginTop: -2 })
const $tintText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint })
const $heading: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.xs })
const $eyebrow: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
  letterSpacing: 1.5,
})
const $subtitle: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })
const $settingsCard: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  backgroundColor: colors.palette.neutral100,
  borderRadius: 20,
  borderCurve: "continuous",
  paddingHorizontal: spacing.md,
})
const $settingRow: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 76,
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.md,
  paddingVertical: spacing.sm,
})
const $settingBlock: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingVertical: spacing.md,
  gap: spacing.sm,
})
const $timeRow: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 76,
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.md,
  paddingVertical: spacing.sm,
})
const $separator: ThemedStyle<ViewStyle> = ({ colors }) => ({
  height: 1,
  backgroundColor: colors.separator,
})
const $segmented: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  flexDirection: "row",
  gap: spacing.xs,
  padding: spacing.xxs,
  borderRadius: 12,
  backgroundColor: colors.background,
})
const $segment: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flex: 1,
  minHeight: 42,
  borderRadius: 9,
  alignItems: "center",
  justifyContent: "center",
  paddingHorizontal: spacing.xs,
})
const $segmentSelected: ThemedStyle<ViewStyle> = ({ colors }) => ({ backgroundColor: colors.tint })
const $segmentTextSelected: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.palette.neutral100,
})
const $weekdayRow: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  justifyContent: "space-between",
  gap: spacing.xxs,
})
const $weekday: ThemedStyle<ViewStyle> = ({ colors }) => ({
  flex: 1,
  aspectRatio: 1,
  maxHeight: 44,
  borderRadius: 22,
  alignItems: "center",
  justifyContent: "center",
  backgroundColor: colors.background,
})
const $weekdaySelected: ThemedStyle<ViewStyle> = ({ colors }) => ({ backgroundColor: colors.tint })
const $privacyCard: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  borderLeftWidth: 3,
  borderLeftColor: colors.tint,
  paddingLeft: spacing.md,
  gap: spacing.xs,
})
const $success: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
  textAlign: "center",
})
const $error: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.error,
  textAlign: "center",
})
const $pressed: ThemedStyle<ViewStyle> = () => ({ opacity: 0.7 })
const $flex: ViewStyle = { flex: 1 }
const $tabularNumbers: TextStyle = { fontVariant: ["tabular-nums"] }
