import { FC, useMemo, useState } from "react"
import { Image, Pressable, TextStyle, View, ViewStyle } from "react-native"
import { useRouter } from "expo-router"

import { Button } from "@/components/Button"
import { companionStyles } from "@/components/companion/Companion"
import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import { mysteryArt, mysteryArtCredit } from "@/services/companion/artwork"
import {
  buildRosarySession,
  getRosaryDevotion,
  getSuggestedRosaryMysterySet,
  SEVEN_SORROWS,
} from "@/services/rosary"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

/** Beyond five beads the rail has no room for readable labels. */
const MAX_LABELLED_BEADS = 5

type RosaryGuideScreenProps = {
  mysterySetId?: string
}

export const RosaryGuideScreen: FC<RosaryGuideScreenProps> = function RosaryGuideScreen({
  mysterySetId,
}) {
  const { themed } = useAppTheme()
  const router = useRouter()
  const devotion = getRosaryDevotion(mysterySetId) ?? getSuggestedRosaryMysterySet()
  const session = useMemo(() => buildRosarySession(devotion), [devotion])
  const { steps } = session
  const showBeadLabels = session.groupLabels.length <= MAX_LABELLED_BEADS
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
  const progressValue = Math.round((completedActions / totalActions) * 100)
  const progressPercent = `${progressValue}%` as `${number}%`

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
          <Text text={session.title} preset="heading" accessibilityRole="header" selectable />
          <Text
            text={
              session.id === SEVEN_SORROWS.id
                ? "May Our Lady of Sorrows keep you close to her Son through the day."
                : "May the mysteries you contemplated remain with you through the day."
            }
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

  const currentGroupLabel =
    step.mysteryIndex === undefined ? undefined : session.groupLabels[step.mysteryIndex]
  const stepArt =
    step.prayer || step.mysteryIndex === undefined
      ? undefined
      : mysteryArt[session.id]?.[step.mysteryIndex]
  // Every mystery image is a public-domain painting with an artist credit.
  const artCredit =
    step.mysteryIndex === undefined
      ? undefined
      : mysteryArtCredit(
          session.id === SEVEN_SORROWS.id ? "sorrows" : session.id,
          step.mysteryIndex,
        )
  const currentRepetition = repetitionIndex + 1
  const buttonLabel =
    stepIndex === steps.length - 1
      ? "Complete the Rosary"
      : step.repetitions > 1
        ? `Complete ${step.title} ${currentRepetition} of ${step.repetitions}`
        : step.prayer
          ? `Complete ${step.title}`
          : session.id === SEVEN_SORROWS.id
            ? "Begin this sorrow"
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
          {/* A glyph standing in for an icon: past this it no longer fits the
              circle, and iOS draws nothing rather than a clipped cross. */}
          <Text text="×" size="xl" maxFontSizeMultiplier={1.4} style={themed($tintText)} />
        </Pressable>
        <View style={themed($titleCopy)}>
          <Text text={session.shortTitle} size="xs" weight="semiBold" />
          <Text text={step.eyebrow} size="xxs" style={themed($subtitle)} />
        </View>
        <Text text={progressPercent} size="xs" weight="semiBold" style={themed($tintText)} />
      </View>

      <View
        style={themed($progressTrack)}
        accessibilityRole="progressbar"
        accessibilityLabel="Progress"
        accessibilityValue={{ min: 0, max: 100, now: progressValue }}
      >
        <View style={themed([$progressFill, { width: progressPercent }])} />
      </View>

      <View
        style={themed($decadeRail)}
        accessibilityLabel={
          session.id === SEVEN_SORROWS.id ? "The seven sorrows" : "Rosary decades"
        }
      >
        {session.groupLabels.map((label, index) => {
          const active = step.mysteryIndex === index
          const prayed = step.mysteryIndex !== undefined && index < step.mysteryIndex
          return (
            <View key={label} style={themed($decadeItem)}>
              <View style={themed([$decadeBead, (active || prayed) && $decadeBeadActive])}>
                {/* Beads keep one size so that five or seven fit across; their
                    numbers stop growing before they outgrow the bead. */}
                <Text
                  text={prayed ? "✓" : String(index + 1)}
                  size="xxs"
                  weight="semiBold"
                  maxFontSizeMultiplier={1.4}
                  style={(active || prayed) && themed($beadTextActive)}
                />
              </View>
              {showBeadLabels && (
                <Text
                  text={label.replace(/^The /, "")}
                  size="xxs"
                  numberOfLines={2}
                  style={themed(active ? $decadeLabelActive : $decadeLabel)}
                />
              )}
            </View>
          )
        })}
      </View>

      {stepArt && (
        <View style={themed($artBlock)}>
          <Image
            source={stepArt}
            style={companionStyles.heroImage}
            accessibilityLabel={currentGroupLabel}
          />
          {artCredit && <Text text={artCredit} size="xxs" style={themed($credit)} selectable />}
        </View>
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
        {step.meditation && (
          <Text text={step.meditation} size="md" style={themed($invocation)} selectable />
        )}
        {!step.prayer && !step.meditation && currentGroupLabel && (
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
const $invocation: ThemedStyle<TextStyle> = () => ({ lineHeight: 30 })
const $artBlock: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.xs })
const $credit: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.textDim,
  textAlign: "center",
})
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
