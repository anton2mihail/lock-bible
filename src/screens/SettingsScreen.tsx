import { FC, useCallback, useState } from "react"
import { TextStyle, TouchableOpacity, View, ViewStyle } from "react-native"
import { router } from "expo-router"

import { ActionRow } from "@/components/companion/Companion"
import { ListItem } from "@/components/ListItem"
import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import {
  getReaderLineSpacing,
  getReaderTextSize,
  getReaderTypeface,
  getRotationInterval,
  getTranslationId,
  getVerseScope,
  listTranslations,
  ROTATION_INTERVALS,
  setReaderLineSpacing,
  setReaderTextSize,
  setReaderTypeface,
  setRotationInterval,
  setTranslationId,
  setVerseScope,
  VERSE_SCOPES,
  type RotationInterval,
  type ReaderLineSpacing,
  type ReaderTextSize,
  type ReaderTypeface,
  type VerseScope,
} from "@/services/bible"
import { calendarCoverage } from "@/services/companion/calendar"
import { syncWidget } from "@/services/widget/widgetBridge"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

const INTERVAL_LABELS: Record<RotationInterval, string> = {
  10: "Every 10 minutes",
  15: "Every 15 minutes",
  30: "Every 30 minutes",
  60: "Every hour",
  180: "Every 3 hours",
  360: "Every 6 hours",
  720: "Every 12 hours",
  1440: "Once a day",
}

const SCOPE_LABELS: Record<VerseScope, string> = {
  full: "Full Bible",
  ot: "Old Testament",
  nt: "New Testament",
}

type AppearancePreference = "system" | "light" | "dark"

const TEXT_SIZE_OPTIONS: readonly { value: ReaderTextSize; label: string }[] = [
  { value: "small", label: "Small" },
  { value: "medium", label: "Default" },
  { value: "large", label: "Large" },
  { value: "extraLarge", label: "Extra large" },
]

const LINE_SPACING_OPTIONS: readonly { value: ReaderLineSpacing; label: string }[] = [
  { value: "compact", label: "Compact" },
  { value: "comfortable", label: "Comfortable" },
  { value: "relaxed", label: "Relaxed" },
]

const TYPEFACE_OPTIONS: readonly { value: ReaderTypeface; label: string }[] = [
  { value: "serif", label: "Serif" },
  { value: "sans", label: "Sans" },
]

const APPEARANCE_OPTIONS: readonly { value: AppearancePreference; label: string }[] = [
  { value: "system", label: "System" },
  { value: "light", label: "Light" },
  { value: "dark", label: "Dark" },
]

export const SettingsScreen: FC = function SettingsScreen() {
  const { setThemeContextOverride, themeContextOverride, themed } = useAppTheme()
  const translations = listTranslations()

  const [translationId, setTranslationIdState] = useState(getTranslationId)
  const [interval, setIntervalState] = useState<RotationInterval>(getRotationInterval)
  const [scope, setScopeState] = useState<VerseScope>(getVerseScope)
  const [readerTextSize, setReaderTextSizeState] = useState<ReaderTextSize>(getReaderTextSize)
  const [readerLineSpacing, setReaderLineSpacingState] =
    useState<ReaderLineSpacing>(getReaderLineSpacing)
  const [readerTypeface, setReaderTypefaceState] = useState<ReaderTypeface>(getReaderTypeface)

  const appearance: AppearancePreference = themeContextOverride ?? "system"

  const onSelectTranslation = useCallback((id: string) => {
    setTranslationId(id)
    setTranslationIdState(id)
    syncWidget()
  }, [])

  const onSelectInterval = useCallback((value: RotationInterval) => {
    setRotationInterval(value)
    setIntervalState(value)
    syncWidget()
  }, [])

  const onSelectScope = useCallback((value: VerseScope) => {
    setVerseScope(value)
    setScopeState(value)
    syncWidget()
  }, [])

  const activeTranslation = translations.find((t) => t.id === translationId) ?? translations[0]

  return (
    <Screen preset="scroll" safeAreaEdges={["top"]} contentContainerStyle={themed($container)}>
      <Text text="Settings" preset="heading" style={themed($title)} />

      <Section title="Reading" themed={themed}>
        <PreferencePicker
          label="Text size"
          value={readerTextSize}
          options={TEXT_SIZE_OPTIONS}
          onSelect={(value) => {
            setReaderTextSize(value)
            setReaderTextSizeState(value)
          }}
        />
        <PreferencePicker
          label="Line spacing"
          value={readerLineSpacing}
          options={LINE_SPACING_OPTIONS}
          onSelect={(value) => {
            setReaderLineSpacing(value)
            setReaderLineSpacingState(value)
          }}
          topSeparator
        />
        <PreferencePicker
          label="Scripture typeface"
          value={readerTypeface}
          options={TYPEFACE_OPTIONS}
          onSelect={(value) => {
            setReaderTypeface(value)
            setReaderTypefaceState(value)
          }}
          topSeparator
        />
        <PreferencePicker
          label="Appearance"
          value={appearance}
          options={APPEARANCE_OPTIONS}
          onSelect={(value) => setThemeContextOverride(value === "system" ? undefined : value)}
          topSeparator
        />
      </Section>

      <Section title="Translation" themed={themed}>
        {translations.map((t, i) => (
          <ListItem
            key={t.id}
            text={t.fullName}
            rightIcon={t.id === translationId ? "check" : undefined}
            onPress={() => onSelectTranslation(t.id)}
            accessibilityRole="radio"
            accessibilityState={{ checked: t.id === translationId }}
            testID={`translation-${t.id}`}
            topSeparator={i > 0}
          />
        ))}
        <Text
          text={`${translations.length} complete Catholic editions are available offline. Your choice also controls the rotating verse and lock-screen widget.`}
          size="xxs"
          style={themed($hint)}
        />
      </Section>

      <Section title="Verse pool" themed={themed}>
        {VERSE_SCOPES.map((value, i) => (
          <ListItem
            key={value}
            text={SCOPE_LABELS[value]}
            rightIcon={value === scope ? "check" : undefined}
            onPress={() => onSelectScope(value)}
            accessibilityRole="radio"
            accessibilityState={{ checked: value === scope }}
            topSeparator={i > 0}
          />
        ))}
        <Text
          text="Which part of Scripture the rotating verse is drawn from. Old Testament includes the deuterocanonical books."
          size="xxs"
          style={themed($hint)}
        />
      </Section>

      <Section title="Verse rotation" themed={themed}>
        {ROTATION_INTERVALS.map((value, i) => (
          <ListItem
            key={value}
            text={INTERVAL_LABELS[value]}
            rightIcon={value === interval ? "check" : undefined}
            onPress={() => onSelectInterval(value)}
            accessibilityRole="radio"
            accessibilityState={{ checked: value === interval }}
            topSeparator={i > 0}
          />
        ))}
        <Text
          text="How often the Verse of the Moment and your lock screen widget change."
          size="xxs"
          style={themed($hint)}
        />
      </Section>

      <Section title="Lock screen widgets" themed={themed}>
        <Text
          text={
            "1. Touch and hold your lock screen, then tap Customize.\n" +
            "2. Tap the box under the clock and choose this app.\n" +
            "3. Choose “Daily Verse” for rotating Scripture or “Daily Reading” for today’s Gospel. You can add both. “Verse Countdown” shows time until the next rotating verse.\n" +
            "4. Pick the rectangular size for full text, or the inline/circular size for a compact view."
          }
          style={themed($instructions)}
        />
      </Section>

      <Section title="Calendar notifications" themed={themed}>
        <ActionRow
          title="Saints, feasts & daily readings"
          subtitle="Choose a delivery time and turn notices on or off"
          icon="bell"
          onPress={() => router.push("/calendar-notifications")}
        />
      </Section>

      <Section title="John 1:1 · Scripture & Prayer" themed={themed}>
        <Text text="A little closer to God, every day." style={themed($about)} />
        <Text
          text={`United States · Roman Rite. Offline reading references: ${calendarCoverage()}. Local observances can differ.`}
          size="xs"
          style={themed($about)}
        />
        <Text
          text="Original sacred illustrations created for John 1:1 with AI. Prayer introductions and teaching summaries are editorial guides; source references are provided alongside them."
          size="xs"
          style={themed($about)}
        />
        <Text
          text="Reading metadata: catholic-readings-api (MIT). Celebration calendar: romcal (MIT). Reflections stay on this device. Confession notes are never saved."
          size="xs"
          style={themed($about)}
        />
        <Text text={activeTranslation.attribution} size="xs" style={themed($about)} />
        <Text text={activeTranslation.copyrightNotice} size="xxs" style={themed($hint)} />
      </Section>
    </Screen>
  )
}

interface SectionProps {
  title: string
  themed: ReturnType<typeof useAppTheme>["themed"]
  children: React.ReactNode
}

function Section({ title, themed, children }: SectionProps) {
  return (
    <View style={themed($section)}>
      <Text text={title} preset="formLabel" style={themed($sectionLabel)} />
      <View style={themed($sectionBody)}>{children}</View>
    </View>
  )
}

interface PreferencePickerProps<T extends string> {
  label: string
  value: T
  options: readonly { value: T; label: string }[]
  onSelect: (value: T) => void
  topSeparator?: boolean
}

function PreferencePicker<T extends string>({
  label,
  value,
  options,
  onSelect,
  topSeparator,
}: PreferencePickerProps<T>) {
  const { themed } = useAppTheme()
  return (
    <View style={themed([$preference, topSeparator && $preferenceSeparator])}>
      <Text text={label} size="xs" weight="medium" />
      <View style={themed($preferenceOptions)} accessibilityRole="radiogroup">
        {options.map((option) => {
          const selected = option.value === value
          return (
            <TouchableOpacity
              key={option.value}
              onPress={() => onSelect(option.value)}
              style={themed([$preferenceOption, selected && $preferenceOptionSelected])}
              accessibilityRole="radio"
              accessibilityState={{ checked: selected }}
              accessibilityLabel={`${label}, ${option.label}`}
            >
              <Text
                text={option.label}
                size="xs"
                weight="medium"
                style={themed(selected ? $preferenceOptionTextSelected : $preferenceOptionText)}
              />
            </TouchableOpacity>
          )
        })}
      </View>
    </View>
  )
}

const $container: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingHorizontal: spacing.lg,
  paddingBottom: spacing.xxl,
  gap: spacing.lg,
})

const $title: ThemedStyle<TextStyle> = ({ spacing }) => ({
  paddingTop: spacing.md,
})

const $section: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  gap: spacing.xs,
})

const $sectionLabel: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.textDim,
})

const $sectionBody: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  backgroundColor: colors.palette.neutral100,
  borderRadius: 16,
  paddingHorizontal: spacing.md,
})

const $preference: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingVertical: spacing.sm,
  gap: spacing.xs,
})

const $preferenceSeparator: ThemedStyle<ViewStyle> = ({ colors }) => ({
  borderTopWidth: 1,
  borderTopColor: colors.separator,
})

const $preferenceOptions: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  flexWrap: "wrap",
  gap: spacing.xs,
})

const $preferenceOption: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  minHeight: 44,
  justifyContent: "center",
  paddingHorizontal: spacing.sm,
  borderWidth: 1,
  borderColor: colors.border,
  borderRadius: 10,
  backgroundColor: colors.background,
})

const $preferenceOptionSelected: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.tint,
  borderColor: colors.tint,
})

const $preferenceOptionText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.text })

const $preferenceOptionTextSelected: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.palette.neutral100,
})

const $hint: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.textDim,
  paddingVertical: spacing.sm,
})

const $instructions: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.text,
  paddingVertical: spacing.sm,
  lineHeight: 24,
})

const $about: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.text,
  paddingTop: spacing.sm,
})
