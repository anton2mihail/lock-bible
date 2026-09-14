import { FC, useCallback, useState } from "react"
import { Image, Pressable, TextStyle, View, ViewStyle } from "react-native"
import { useFocusEffect, useRouter } from "expo-router"

import { Button } from "@/components/Button"
import { art, companionStyles } from "@/components/companion/Companion"
import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import { rosaryCover } from "@/services/companion/artwork"
import {
  getRosaryReminderSettings,
  getRosaryReminderSummary,
  getSuggestedRosaryMysterySet,
  ROSARY_MEDIA_EPISODES,
  ROSARY_MYSTERY_SETS,
  type RosaryMysterySet,
} from "@/services/rosary"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

export const RosaryHomeScreen: FC = function RosaryHomeScreen() {
  const { themed } = useAppTheme()
  const router = useRouter()
  const suggestedSet = getSuggestedRosaryMysterySet()
  const [reminderSummary, setReminderSummary] = useState(() => getRosaryReminderSummary())

  useFocusEffect(
    useCallback(() => {
      setReminderSummary(getRosaryReminderSummary(getRosaryReminderSettings()))
    }, []),
  )

  const beginRosary = useCallback(
    (set: RosaryMysterySet) =>
      router.push({ pathname: "/pray/rosary-guide", params: { set: set.id } }),
    [router],
  )

  return (
    <Screen preset="scroll" safeAreaEdges={["top"]} contentContainerStyle={themed($container)}>
      <Pressable
        onPress={() => router.back()}
        accessibilityRole="button"
        accessibilityLabel="Back to prayer library"
        hitSlop={8}
        style={({ pressed }) => themed([$back, pressed && $pressed])}
      >
        <Text text="‹" size="xl" style={themed($backMark)} />
        <Text text="Prayer Library" size="sm" weight="semiBold" style={themed($tintText)} />
      </Pressable>

      <Image source={art.mary} style={companionStyles.heroImage} accessible={false} />
      <View style={themed($heading)}>
        <Text text="THE MOST HOLY ROSARY" size="xxs" weight="semiBold" style={themed($eyebrow)} />
        <Text text="Pray the Rosary" preset="heading" accessibilityRole="header" selectable />
        <Text
          text="A quiet, step-by-step meditation on the life of Christ with Mary. The complete prayer guide works offline."
          size="sm"
          style={themed($subtitle)}
          selectable
        />
      </View>

      <View style={themed($featuredCard)}>
        <View style={themed($cardHeader)}>
          <View style={themed($cardCopy)}>
            <Text text="SUGGESTED TODAY" size="xxs" weight="semiBold" style={themed($eyebrow)} />
            <Text text={suggestedSet.title} preset="subheading" selectable />
            <Text
              text={suggestedSet.customaryDays}
              size="xs"
              style={themed($subtitle)}
              selectable
            />
          </View>
          <View style={themed($rosaryMark)} accessibilityElementsHidden>
            <Text text="✢" size="xl" style={themed($markText)} />
          </View>
        </View>

        <View style={themed($mysteryPreview)}>
          {suggestedSet.mysteries.map((mystery, index) => (
            <View key={mystery.title} style={themed($mysteryRow)}>
              <View style={themed($numberBead)}>
                <Text text={String(index + 1)} size="xxs" weight="semiBold" />
              </View>
              <Text text={mystery.title} size="xs" style={$flexText} selectable />
            </View>
          ))}
        </View>

        <Button
          text="Begin today’s Rosary"
          preset="reversed"
          onPress={() => beginRosary(suggestedSet)}
        />
      </View>

      <Pressable
        onPress={() => router.push("/pray/rosary-reminder")}
        accessibilityRole="button"
        accessibilityLabel={`Rosary reminder. ${reminderSummary}`}
        style={({ pressed }) => themed([$utilityCard, pressed && $pressed])}
      >
        <View style={themed($utilityIcon)}>
          <Text text="◷" size="lg" style={themed($tintText)} />
        </View>
        <View style={$flex}>
          <Text text="Rosary reminder" weight="semiBold" />
          <Text text={reminderSummary} size="xs" style={themed($subtitle)} selectable />
          <Text text="Scheduled privately on this device" size="xxs" style={themed($meta)} />
        </View>
        <Text text="›" size="xl" style={themed($chevron)} />
      </Pressable>

      <View style={themed($section)}>
        <View style={themed($sectionHeading)}>
          <Text text="Choose a mystery" preset="subheading" />
          <Text text="Sundays vary by liturgical season" size="xxs" style={themed($meta)} />
        </View>
        <View style={themed($list)}>
          {ROSARY_MYSTERY_SETS.map((set) => (
            <Pressable
              key={set.id}
              onPress={() => beginRosary(set)}
              accessibilityRole="button"
              accessibilityLabel={`${set.title}. ${set.customaryDays}`}
              style={({ pressed }) => themed([$setCard, pressed && $pressed])}
            >
              <Image source={rosaryCover[set.id]} style={$cover} accessible={false} />
              <View style={$flex}>
                <Text text={set.title} weight="semiBold" selectable />
                <Text text={set.customaryDays} size="xxs" style={themed($eyebrow)} selectable />
                <Text text={set.description} size="xs" style={themed($subtitle)} selectable />
              </View>
              <Text text="›" size="xl" style={themed($chevron)} />
            </Pressable>
          ))}
        </View>
      </View>

      <View style={themed($section)}>
        <View style={themed($sectionHeading)}>
          <Text text="The Rosary with Bishop Barron" preset="subheading" />
          <Text
            text="Watch the Rosary on Word on Fire’s official channels. An internet connection is needed."
            size="xs"
            style={themed($subtitle)}
            selectable
          />
        </View>
        <Pressable
          onPress={() =>
            router.push({ pathname: "/pray/rosary-media", params: { episode: suggestedSet.id } })
          }
          accessibilityRole="button"
          accessibilityLabel={`Open ${suggestedSet.title} media`}
          style={({ pressed }) => themed([$mediaCard, pressed && $pressed])}
        >
          <View style={themed($playMark)}>
            <Text text="▶" size="sm" style={themed($playText)} />
          </View>
          <View style={$flex}>
            <Text
              text={`${suggestedSet.shortTitle} Mysteries`}
              weight="semiBold"
              style={themed($mediaTitle)}
            />
            <Text
              text="Bishop Robert Barron · Word on Fire"
              size="xs"
              style={themed($mediaSubtitle)}
            />
          </View>
          <Text text="›" size="xl" style={themed($chevron)} />
        </Pressable>
        <Text
          text={`${ROSARY_MEDIA_EPISODES.length} episodes catalogued from the official series`}
          size="xxs"
          style={themed($meta)}
        />
      </View>
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
  textTransform: "uppercase",
})
const $subtitle: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })
const $meta: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })
const $featuredCard: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  backgroundColor: colors.palette.neutral100,
  borderRadius: 24,
  borderCurve: "continuous",
  borderWidth: 1,
  borderColor: colors.border,
  padding: spacing.lg,
  gap: spacing.lg,
})
const $cardHeader: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  alignItems: "flex-start",
  gap: spacing.md,
})
const $cardCopy: ThemedStyle<ViewStyle> = ({ spacing }) => ({ flex: 1, gap: spacing.xxs })
const $rosaryMark: ThemedStyle<ViewStyle> = ({ colors }) => ({
  width: 52,
  height: 52,
  borderRadius: 26,
  backgroundColor: colors.background,
  alignItems: "center",
  justifyContent: "center",
})
const $markText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint })
const $mysteryPreview: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.sm })
const $mysteryRow: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.sm,
})
const $numberBead: ThemedStyle<ViewStyle> = ({ colors }) => ({
  width: 28,
  height: 28,
  borderRadius: 14,
  alignItems: "center",
  justifyContent: "center",
  backgroundColor: colors.background,
  borderWidth: 1,
  borderColor: colors.border,
})
const $utilityCard: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  minHeight: 96,
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.md,
  backgroundColor: colors.palette.neutral100,
  borderRadius: 18,
  borderCurve: "continuous",
  padding: spacing.md,
})
const $utilityIcon: ThemedStyle<ViewStyle> = ({ colors }) => ({
  width: 48,
  height: 48,
  borderRadius: 16,
  alignItems: "center",
  justifyContent: "center",
  backgroundColor: colors.background,
})
const $chevron: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint })
const $section: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.md })
const $sectionHeading: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.xxs })
const $list: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.sm })
const $setCard: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  minHeight: 112,
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.md,
  backgroundColor: colors.palette.neutral100,
  borderRadius: 18,
  borderCurve: "continuous",
  padding: spacing.md,
})
const $mediaCard: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  minHeight: 88,
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.md,
  backgroundColor: colors.palette.neutral800,
  borderRadius: 18,
  borderCurve: "continuous",
  padding: spacing.md,
})
const $playMark: ThemedStyle<ViewStyle> = ({ colors }) => ({
  width: 46,
  height: 46,
  borderRadius: 23,
  alignItems: "center",
  justifyContent: "center",
  backgroundColor: colors.tint,
})
const $playText: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.palette.neutral100,
  paddingLeft: 2,
})
const $mediaTitle: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.palette.neutral100 })
const $mediaSubtitle: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.palette.neutral300,
})
const $pressed: ThemedStyle<ViewStyle> = () => ({ opacity: 0.72, transform: [{ scale: 0.99 }] })
const $flex: ViewStyle = { flex: 1 }
const $flexText: TextStyle = { flex: 1 }

const $cover = { width: 72, height: 84, borderRadius: 10 }
