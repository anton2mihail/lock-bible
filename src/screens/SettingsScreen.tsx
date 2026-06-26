import { FC, useCallback, useState } from "react"
import { TextStyle, View, ViewStyle } from "react-native"

import { ListItem } from "@/components/ListItem"
import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import {
  getRotationInterval,
  getTranslationId,
  getVerseScope,
  listTranslations,
  ROTATION_INTERVALS,
  setRotationInterval,
  setTranslationId,
  setVerseScope,
  VERSE_SCOPES,
  type RotationInterval,
  type VerseScope,
} from "@/services/bible"
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

export const SettingsScreen: FC = function SettingsScreen() {
  const { themed } = useAppTheme()
  const translations = listTranslations()

  const [translationId, setTranslationIdState] = useState(getTranslationId)
  const [interval, setIntervalState] = useState<RotationInterval>(getRotationInterval)
  const [scope, setScopeState] = useState<VerseScope>(getVerseScope)

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

      <Section title="Translation" themed={themed}>
        {translations.map((t, i) => (
          <ListItem
            key={t.id}
            text={t.fullName}
            rightIcon={t.id === translationId ? "check" : undefined}
            onPress={() => onSelectTranslation(t.id)}
            topSeparator={i > 0}
          />
        ))}
        <Text
          text="More translations (including licensed Catholic editions) can be added later without an app update."
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
            "3. Add “Daily Verse” for the verse itself, and/or “Verse Countdown” " +
            "for a live timer until the next verse.\n" +
            "4. Pick the rectangular size for full text, or the inline/circular size for a compact view."
          }
          style={themed($instructions)}
        />
      </Section>

      <Section title="About" themed={themed}>
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
