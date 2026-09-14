import { FC, useCallback, useEffect, useState } from "react"
import { Image } from "react-native"
import {
  Linking,
  Pressable,
  ScrollView,
  TextStyle,
  useWindowDimensions,
  View,
  ViewStyle,
} from "react-native"
import { useRouter } from "expo-router"

import { Button } from "@/components/Button"
import { companionStyles } from "@/components/companion/Companion"
import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import { TextField } from "@/components/TextField"
import { novenaArt } from "@/services/companion/artwork"
import {
  emptyNovenaProgress,
  getNovena,
  loadNovenaProgress,
  NOVENA_DAY_COUNT,
  saveNovenaProgress,
  type NovenaProgress,
} from "@/services/novena"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

const days = Array.from({ length: NOVENA_DAY_COUNT }, (_, index) => index + 1)

type NovenaScreenProps = {
  novenaId?: string
}

export const NovenaScreen: FC<NovenaScreenProps> = function NovenaScreen({ novenaId }) {
  const {
    themed,
    theme: { colors },
  } = useAppTheme()
  const router = useRouter()
  const { fontScale } = useWindowDimensions()
  const novena = getNovena(novenaId)
  const [progress, setProgress] = useState<NovenaProgress>(() =>
    novena ? loadNovenaProgress(novena.id) : { ...emptyNovenaProgress },
  )

  useEffect(() => {
    if (novena) setProgress(loadNovenaProgress(novena.id))
  }, [novena])

  const updateProgress = useCallback(
    (next: NovenaProgress) => {
      if (!novena) return
      setProgress(next)
      saveNovenaProgress(novena.id, next)
    },
    [novena],
  )

  const selectDay = useCallback(
    (selectedDay: number) => updateProgress({ ...progress, selectedDay }),
    [progress, updateProgress],
  )

  const updateIntention = useCallback(
    (intention: string) => updateProgress({ ...progress, intention }),
    [progress, updateProgress],
  )

  const completeDay = useCallback(() => {
    if (progress.completedDays.includes(progress.selectedDay)) return

    const completedDays = [...progress.completedDays, progress.selectedDay].sort((a, b) => a - b)
    const nextIncomplete = days.find((day) => !completedDays.includes(day))
    updateProgress({
      ...progress,
      completedDays,
      selectedDay: nextIncomplete ?? progress.selectedDay,
    })
  }, [progress, updateProgress])

  const startAgain = useCallback(() => updateProgress({ ...emptyNovenaProgress }), [updateProgress])

  const isComplete = progress.completedDays.length === NOVENA_DAY_COUNT
  const selectedIsComplete = progress.completedDays.includes(progress.selectedDay)

  if (!novena) {
    return (
      <Screen
        preset="fixed"
        safeAreaEdges={["top"]}
        contentContainerStyle={themed($missingContainer)}
      >
        <Text text="Novena not found" preset="heading" />
        <Text text="This prayer is not in your offline library." style={themed($subtitle)} />
        <Button text="Back to novenas" onPress={() => router.back()} />
      </Screen>
    )
  }

  return (
    <Screen
      preset="scroll"
      safeAreaEdges={["top"]}
      contentContainerStyle={themed($container)}
      ScrollViewProps={{ keyboardDismissMode: "interactive" }}
    >
      <Pressable
        testID="novena-back"
        onPress={() => router.back()}
        accessibilityRole="button"
        accessibilityLabel="Back to novenas"
        hitSlop={8}
        style={({ pressed }) => themed([$back, pressed && $dayButtonPressed])}
      >
        <Text text="‹" size="xl" style={themed($backMark)} />
        <Text text="Novenas" size="sm" weight="semiBold" style={themed($backText)} />
      </Pressable>

      <Image source={novenaArt(novena.id)} style={companionStyles.heroImage} accessible={false} />
      <View style={themed($heading)}>
        <Text text="NOVENA · 9 DAYS" size="xxs" weight="semiBold" style={themed($eyebrow)} />
        <Text text={novena.title} preset="heading" accessibilityRole="header" />
        <Text text={novena.subtitle} size="sm" style={themed($subtitle)} />
        {novena.traditionalStart && novena.feastDay && (
          <View style={themed($dates)}>
            <Text text={`Begins ${novena.traditionalStart}`} size="xs" />
            <View style={themed($dateDivider)} />
            <Text text={`Feast ${novena.feastDay}`} size="xs" />
          </View>
        )}
      </View>

      <View testID="novena-about" style={themed($aboutCard)}>
        <Text text="ABOUT THIS NOVENA" size="xxs" weight="semiBold" style={themed($sectionLabel)} />
        <Text text={novena.about} size="sm" style={themed($aboutText)} />
        <Text text={`Patronage · ${novena.patronage}`} size="xs" weight="semiBold" />
      </View>

      <View style={themed($progressCard)} accessibilityRole="summary">
        <View style={themed($progressHeader)}>
          <Text
            text={isComplete ? "Novena complete" : `Day ${progress.selectedDay}`}
            preset="subheading"
          />
          <Text
            text={`${progress.completedDays.length} of ${NOVENA_DAY_COUNT} prayed`}
            size="xs"
            style={themed($progressCount)}
          />
        </View>

        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={themed($dayRail)}
          accessibilityLabel="Choose a novena day"
        >
          {days.map((day, index) => {
            const selected = day === progress.selectedDay
            const complete = progress.completedDays.includes(day)
            return (
              <View key={day} style={$dayItem}>
                {index > 0 && <View style={themed([$connector, complete && $connectorComplete])} />}
                <Pressable
                  onPress={() => selectDay(day)}
                  accessibilityRole="button"
                  accessibilityLabel={`Day ${day}${complete ? ", complete" : ""}`}
                  accessibilityState={{ selected }}
                  hitSlop={4}
                  style={({ pressed }) =>
                    themed([
                      $dayButton,
                      complete && $dayButtonComplete,
                      selected && $dayButtonSelected,
                      pressed && $dayButtonPressed,
                      fontScale > 1.3 && $dayButtonLargeText,
                    ])
                  }
                >
                  <Text
                    text={complete ? "✓" : String(day)}
                    size="xs"
                    weight="semiBold"
                    style={[
                      themed($dayText),
                      (complete || selected) && { color: colors.palette.neutral100 },
                    ]}
                  />
                </Pressable>
              </View>
            )
          })}
        </ScrollView>
      </View>

      <TextField
        label="Your intention"
        helper="Stored privately on this device."
        placeholder="Name the grace you are asking for…"
        value={progress.intention}
        onChangeText={updateIntention}
        multiline
        numberOfLines={3}
        containerStyle={themed($intention)}
        inputWrapperStyle={themed($intentionInput)}
        accessibilityLabel="Your novena intention"
      />

      <View style={themed($prayerCard)}>
        <Text text={`Day ${progress.selectedDay} prayer`} size="xs" style={themed($sectionLabel)} />
        {novena.opening && <Text text={novena.opening} size="lg" weight="semiBold" />}

        <View style={themed($ornament)} accessibilityElementsHidden importantForAccessibility="no">
          <View style={themed($ornamentLine)} />
          <Text text="✦" size="xs" style={themed($ornamentMark)} />
          <View style={themed($ornamentLine)} />
        </View>

        {novena.sections.map((section, index) => (
          <View key={section.title ?? index} style={themed($prayerSection)}>
            {section.title && <Text text={section.title} preset="subheading" />}
            {section.paragraphs.map((paragraph) => (
              <Text key={paragraph} text={paragraph} size="md" style={themed($prayerText)} />
            ))}
            {section.response && (
              <Text text={section.response} size="sm" weight="semiBold" style={themed($response)} />
            )}
          </View>
        ))}
      </View>

      {isComplete ? (
        <Button
          text="Start the novena again"
          onPress={startAgain}
          accessibilityHint="Clears all nine completed days and your intention"
        />
      ) : (
        <Button
          text={
            selectedIsComplete
              ? `Day ${progress.selectedDay} complete`
              : `Mark day ${progress.selectedDay} complete`
          }
          onPress={completeDay}
          disabled={selectedIsComplete}
          disabledStyle={themed($completedButton)}
          disabledTextStyle={themed($completedButtonText)}
        />
      )}

      <Text
        text={`Devotion source · ${novena.sourceName}`}
        size="xxs"
        style={themed($source)}
        accessibilityRole="link"
        onPress={() => Linking.openURL(novena.sourceUrl).catch(() => {})}
      />
    </Screen>
  )
}

const $container: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingHorizontal: spacing.lg,
  paddingTop: spacing.lg,
  paddingBottom: spacing.xxl,
  gap: spacing.lg,
})

const $missingContainer: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flex: 1,
  justifyContent: "center",
  paddingHorizontal: spacing.lg,
  gap: spacing.lg,
})

const $back: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 40,
  alignSelf: "flex-start",
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.xxs,
})

const $backMark: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
  marginTop: -2,
})

const $backText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint })

const $heading: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.xs })

const $eyebrow: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
  letterSpacing: 1.8,
})

const $subtitle: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })

const $dates: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  alignItems: "center",
  flexWrap: "wrap",
  gap: spacing.sm,
  marginTop: spacing.xs,
})

const $dateDivider: ThemedStyle<ViewStyle> = ({ colors }) => ({
  width: 3,
  height: 3,
  borderRadius: 2,
  backgroundColor: colors.tint,
})

const $aboutCard: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  backgroundColor: colors.palette.neutral100,
  borderRadius: 16,
  borderLeftWidth: 3,
  borderLeftColor: colors.tint,
  padding: spacing.md,
  gap: spacing.sm,
})

const $aboutText: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.textDim,
  lineHeight: 23,
})

const $progressCard: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  backgroundColor: colors.palette.neutral100,
  borderRadius: 20,
  borderWidth: 1,
  borderColor: colors.border,
  paddingVertical: spacing.md,
  gap: spacing.md,
  overflow: "hidden",
})

const $progressHeader: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingHorizontal: spacing.md,
  flexDirection: "row",
  flexWrap: "wrap",
  justifyContent: "space-between",
  alignItems: "baseline",
  gap: spacing.xs,
})

const $progressCount: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })

const $dayRail: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingHorizontal: spacing.md,
  alignItems: "center",
})

const $dayItem: ViewStyle = { flexDirection: "row", alignItems: "center" }

const $connector: ThemedStyle<ViewStyle> = ({ colors }) => ({
  width: 10,
  height: 1,
  backgroundColor: colors.separator,
})

const $connectorComplete: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.tint,
})

const $dayButton: ThemedStyle<ViewStyle> = ({ colors }) => ({
  width: 34,
  height: 34,
  borderRadius: 17,
  borderWidth: 1,
  borderColor: colors.border,
  backgroundColor: colors.background,
  justifyContent: "center",
  alignItems: "center",
})

const $dayButtonLargeText: ThemedStyle<ViewStyle> = () => ({
  width: 40,
  height: 40,
  borderRadius: 20,
})
const $dayButtonComplete: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.tint,
  borderColor: colors.tint,
})
const $dayButtonSelected: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.palette.neutral800,
  borderColor: colors.palette.neutral800,
  transform: [{ scale: 1.08 }],
})
const $dayButtonPressed: ThemedStyle<ViewStyle> = () => ({ opacity: 0.72 })
const $dayText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })

const $intention: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  backgroundColor: colors.palette.neutral100,
  borderRadius: 16,
  padding: spacing.md,
})

const $intentionInput: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.background,
  borderColor: colors.border,
  borderRadius: 10,
})

const $prayerCard: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  backgroundColor: colors.palette.neutral100,
  borderRadius: 20,
  paddingHorizontal: spacing.lg,
  paddingVertical: spacing.xl,
  gap: spacing.lg,
})

const $sectionLabel: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
  textTransform: "uppercase",
  letterSpacing: 1.4,
})

const $ornament: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.sm,
})

const $ornamentLine: ThemedStyle<ViewStyle> = ({ colors }) => ({
  height: 1,
  flex: 1,
  backgroundColor: colors.separator,
})

const $ornamentMark: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint })

const $prayerSection: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.sm })
const $prayerText: ThemedStyle<TextStyle> = () => ({ lineHeight: 30 })

const $response: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.tint,
  borderLeftWidth: 2,
  borderLeftColor: colors.tint,
  paddingLeft: spacing.md,
  lineHeight: 25,
})

const $completedButton: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.palette.neutral300,
  borderColor: colors.palette.neutral300,
})
const $completedButtonText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })

const $source: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.textDim,
  textAlign: "center",
  textDecorationLine: "underline",
})
