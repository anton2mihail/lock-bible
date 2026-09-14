import { FC, useMemo, useState } from "react"
import { Image, Pressable, TextStyle, View, ViewStyle } from "react-native"
import { useRouter } from "expo-router"

import { Button } from "@/components/Button"
import { companionStyles } from "@/components/companion/Companion"
import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import { mysteryArt } from "@/services/companion/artwork"
import {
  buildRosaryGuide,
  getRosaryMysterySet,
  getSuggestedRosaryMysterySet,
} from "@/services/rosary"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

type RosaryGuideScreenProps = {
  mysterySetId?: string
}

export const RosaryGuideScreen: FC<RosaryGuideScreenProps> = function RosaryGuideScreen({
  mysterySetId,
}) {
  const { themed } = useAppTheme()
  const router = useRouter()
  const set = getRosaryMysterySet(mysterySetId) ?? getSuggestedRosaryMysterySet()
  const steps = useMemo(() => buildRosaryGuide(set), [set])
  const [stepIndex, setStepIndex] = useState(0)
  const [repetitionIndex, setRepetitionIndex] = useState(0)
  const [complete, setComplete] = useState(false)

  const step = steps[stepIndex]
  const totalActions = useMemo(
    () => steps.reduce((total, item) => total + item.repetitions, 0),
    [steps],
  )
  const completedBefore = useMemo(
    () => steps.slice(0, stepIndex).reduce((total, item) => total + item.repetitions, 0),
    [stepIndex, steps],
  )
  const completedActions = complete ? totalActions : completedBefore + repetitionIndex
  const progressPercent = `${Math.round((completedActions / totalActions) * 100)}%` as `${number}%`

  const goForward = () => {
    if (repetitionIndex + 1 < step.repetitions) {
      setRepetitionIndex((value) => value + 1)
      return
    }
    if (stepIndex + 1 >= steps.length) {
      setComplete(true)
      return
    }
    setStepIndex((value) => value + 1)
    setRepetitionIndex(0)
  }

  const goBack = () => {
    if (complete) {
      setComplete(false)
      return
    }
    if (repetitionIndex > 0) {
      setRepetitionIndex((value) => value - 1)
      return
    }
    if (stepIndex > 0) {
      const previous = steps[stepIndex - 1]
      setStepIndex((value) => value - 1)
      setRepetitionIndex(previous.repetitions - 1)
    }
  }

  if (complete) {
    return (
      <Screen
        preset="scroll"
        safeAreaEdges={["top"]}
        contentContainerStyle={themed($completionContainer)}
      >
        <View style={themed($completionMark)} accessibilityElementsHidden>
          <Text text="✢" size="xxl" style={themed($tintText)} />
        </View>
        <View style={themed($centeredCopy)}>
          <Text text="ROSARY COMPLETE" size="xxs" weight="semiBold" style={themed($eyebrow)} />
          <Text text={set.title} preset="heading" accessibilityRole="header" selectable />
          <Text
            text="May the mysteries you contemplated remain with you through the day."
            size="sm"
            style={themed($subtitleCentered)}
            selectable
          />
        </View>
        <Button text="Return to Rosary" preset="reversed" onPress={() => router.back()} />
        <Button
          text="Pray again"
          onPress={() => {
            setStepIndex(0)
            setRepetitionIndex(0)
            setComplete(false)
          }}
        />
      </Screen>
    )
  }

  const currentMystery =
    step.mysteryIndex === undefined ? undefined : set.mysteries[step.mysteryIndex]
  const currentRepetition = repetitionIndex + 1
  const buttonLabel =
    stepIndex === steps.length - 1
      ? "Complete the Rosary"
      : step.repetitions > 1
        ? `Complete ${step.title} ${currentRepetition} of ${step.repetitions}`
        : step.prayer
          ? `Complete ${step.title}`
          : "Begin this decade"

  return (
    <Screen preset="scroll" safeAreaEdges={["top"]} contentContainerStyle={themed($container)}>
      <View style={themed($topBar)}>
        <Pressable
          onPress={() => router.back()}
          accessibilityRole="button"
          accessibilityLabel="Close Rosary guide"
          hitSlop={8}
          style={({ pressed }) => themed([$closeButton, pressed && $pressed])}
        >
          <Text text="×" size="xl" style={themed($tintText)} />
        </Pressable>
        <View style={themed($titleCopy)}>
          <Text text={set.shortTitle} size="xs" weight="semiBold" />
          <Text text={step.eyebrow} size="xxs" style={themed($subtitle)} />
        </View>
        <Text text={progressPercent} size="xs" weight="semiBold" style={themed($tintText)} />
      </View>

      <View style={themed($progressTrack)} accessibilityRole="progressbar">
        <View style={themed([$progressFill, { width: progressPercent }])} />
      </View>

      <View style={themed($decadeRail)} accessibilityLabel="Rosary decades">
        {set.mysteries.map((mystery, index) => {
          const active = step.mysteryIndex === index
          const prayed = step.mysteryIndex !== undefined && index < step.mysteryIndex
          return (
            <View key={mystery.title} style={themed($decadeItem)}>
              <View style={themed([$decadeBead, (active || prayed) && $decadeBeadActive])}>
                <Text
                  text={prayed ? "✓" : String(index + 1)}
                  size="xxs"
                  weight="semiBold"
                  style={(active || prayed) && themed($beadTextActive)}
                />
              </View>
              <Text
                text={mystery.title.replace(/^The /, "")}
                size="xxs"
                numberOfLines={2}
                style={themed(active ? $decadeLabelActive : $decadeLabel)}
              />
            </View>
          )
        })}
      </View>

      {!step.prayer && step.mysteryIndex !== undefined && (
        <Image
          source={mysteryArt[set.id][step.mysteryIndex]}
          style={companionStyles.heroImage}
          accessibilityLabel={currentMystery?.title}
        />
      )}
      <View style={themed($prayerCard)}>
        <Text text={step.eyebrow} size="xxs" weight="semiBold" style={themed($eyebrow)} />
        <Text text={step.title} preset="heading" accessibilityRole="header" selectable />
        {step.repetitions > 1 && (
          <View style={themed($counter)} accessibilityRole="summary">
            <Text
              text={`${currentRepetition} / ${step.repetitions}`}
              size="xs"
              weight="semiBold"
              style={$tabularNumbers}
            />
          </View>
        )}
        {step.instruction && (
          <Text text={step.instruction} size="sm" style={themed($meditation)} selectable />
        )}
        {step.prayer && (
          <Text text={step.prayer.text} size="lg" style={themed($prayerText)} selectable />
        )}
        {!step.prayer && currentMystery && (
          <View style={themed($mysteryFruit)}>
            <Text text="Pause and bring this mystery before God." size="sm" selectable />
          </View>
        )}
      </View>

      <View style={themed($actions)}>
        <Button text={buttonLabel} preset="reversed" onPress={goForward} style={$flex} />
        {(stepIndex > 0 || repetitionIndex > 0) && (
          <Pressable
            onPress={goBack}
            accessibilityRole="button"
            accessibilityLabel="Previous prayer"
            style={({ pressed }) => themed([$previousButton, pressed && $pressed])}
          >
            <Text text="Previous" size="xs" weight="semiBold" style={themed($tintText)} />
          </Pressable>
        )}
      </View>
    </Screen>
  )
}

const $container: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingHorizontal: spacing.lg,
  paddingTop: spacing.sm,
  paddingBottom: spacing.xxl,
  gap: spacing.lg,
})
const $completionContainer: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexGrow: 1,
  justifyContent: "center",
  paddingHorizontal: spacing.xl,
  paddingVertical: spacing.xxl,
  gap: spacing.lg,
})
const $completionMark: ThemedStyle<ViewStyle> = ({ colors }) => ({
  width: 96,
  height: 96,
  borderRadius: 48,
  backgroundColor: colors.palette.neutral100,
  alignItems: "center",
  justifyContent: "center",
  alignSelf: "center",
})
const $centeredCopy: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  alignItems: "center",
  gap: spacing.sm,
})
const $subtitleCentered: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.textDim,
  textAlign: "center",
})
const $topBar: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 48,
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.sm,
})
const $closeButton: ThemedStyle<ViewStyle> = ({ colors }) => ({
  width: 44,
  height: 44,
  borderRadius: 22,
  alignItems: "center",
  justifyContent: "center",
  backgroundColor: colors.palette.neutral100,
})
const $titleCopy: ThemedStyle<ViewStyle> = () => ({ flex: 1, alignItems: "center" })
const $tintText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint })
const $subtitle: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })
const $eyebrow: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
  letterSpacing: 1.4,
  textTransform: "uppercase",
})
const $progressTrack: ThemedStyle<ViewStyle> = ({ colors }) => ({
  height: 4,
  borderRadius: 2,
  backgroundColor: colors.separator,
  overflow: "hidden",
})
const $progressFill: ThemedStyle<ViewStyle> = ({ colors }) => ({
  height: "100%",
  backgroundColor: colors.tint,
})
const $decadeRail: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  justifyContent: "space-between",
  gap: spacing.xs,
})
const $decadeItem: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flex: 1,
  alignItems: "center",
  gap: spacing.xs,
})
const $decadeBead: ThemedStyle<ViewStyle> = ({ colors }) => ({
  width: 34,
  height: 34,
  borderRadius: 17,
  alignItems: "center",
  justifyContent: "center",
  backgroundColor: colors.palette.neutral100,
  borderWidth: 1,
  borderColor: colors.border,
})
const $decadeBeadActive: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.tint,
  borderColor: colors.tint,
})
const $beadTextActive: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.palette.neutral100,
})
const $decadeLabel: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.textDim,
  textAlign: "center",
  lineHeight: 14,
})
const $decadeLabelActive: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
  textAlign: "center",
  lineHeight: 14,
})
const $prayerCard: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  minHeight: 360,
  backgroundColor: colors.palette.neutral100,
  borderRadius: 24,
  borderCurve: "continuous",
  padding: spacing.lg,
  gap: spacing.md,
})
const $counter: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  alignSelf: "flex-start",
  borderRadius: 99,
  backgroundColor: colors.background,
  paddingVertical: spacing.xxs,
  paddingHorizontal: spacing.sm,
})
const $meditation: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint })
const $prayerText: ThemedStyle<TextStyle> = () => ({ lineHeight: 34 })
const $mysteryFruit: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  borderLeftWidth: 3,
  borderLeftColor: colors.tint,
  paddingLeft: spacing.md,
})
const $actions: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.sm })
const $previousButton: ThemedStyle<ViewStyle> = () => ({
  minHeight: 44,
  alignItems: "center",
  justifyContent: "center",
})
const $pressed: ThemedStyle<ViewStyle> = () => ({ opacity: 0.7 })
const $flex: ViewStyle = { flex: 1 }
const $tabularNumbers: TextStyle = { fontVariant: ["tabular-nums"] }
