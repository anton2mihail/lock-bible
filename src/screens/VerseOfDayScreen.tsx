import { FC, useCallback, useEffect, useState } from "react"
import { Platform, Share, TextStyle, useWindowDimensions, View, ViewStyle } from "react-native"
import { useFocusEffect, useRouter } from "expo-router"

import { Button } from "@/components/Button"
import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import {
  formatVerseForShare,
  dismissWidgetGuide,
  getActiveTranslationMeta,
  getCurrentVerse,
  getRotationInterval,
  isWidgetGuideDismissed,
  nextRotationDate,
  type WidgetVerse,
} from "@/services/bible"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

function timeUntil(next: Date, now: Date): string {
  const ms = next.getTime() - now.getTime()
  const totalMinutes = Math.max(0, Math.round(ms / 60_000))
  const h = Math.floor(totalMinutes / 60)
  const m = totalMinutes % 60
  if (h <= 0) return `New verse in ${m} min`
  if (m === 0) return `New verse in ${h}h`
  return `New verse in ${h}h ${m}m`
}

export const VerseOfDayScreen: FC = function VerseOfDayScreen() {
  const { themed } = useAppTheme()
  const router = useRouter()
  const meta = getActiveTranslationMeta()
  const { fontScale, width } = useWindowDimensions()
  const stackActions = width < 380 || fontScale > 1.2

  const [verse, setVerse] = useState<WidgetVerse | undefined>(() => getCurrentVerse())
  const [countdown, setCountdown] = useState("")
  const [showWidgetGuide, setShowWidgetGuide] = useState(
    () => Platform.OS === "ios" && !isWidgetGuideDismissed(),
  )
  const [showWidgetSteps, setShowWidgetSteps] = useState(false)

  const refresh = useCallback(() => {
    const now = new Date()
    setVerse(getCurrentVerse(now))
    setCountdown(timeUntil(nextRotationDate(now, getRotationInterval()), now))
  }, [])

  // Recompute on focus and keep the verse + countdown live while open.
  useFocusEffect(
    useCallback(() => {
      refresh()
      const id = setInterval(refresh, 30_000)
      return () => clearInterval(id)
    }, [refresh]),
  )

  useEffect(refresh, [refresh])

  const onShare = useCallback(() => {
    if (!verse) return
    Share.share({ message: formatVerseForShare(verse, meta.abbreviation) }).catch(() => {})
  }, [verse, meta.abbreviation])

  const onReadInContext = useCallback(() => {
    if (!verse) return
    router.push({
      pathname: "/read",
      params: {
        book: verse.book,
        chapter: String(verse.chapter),
        verse: verse.verse,
        // Tabs stay mounted. A unique request makes the reader respond even if
        // the same passage is opened again after navigating elsewhere in it.
        contextRequest: String(Date.now()),
      },
    })
  }, [router, verse])

  const onDismissWidgetGuide = useCallback(() => {
    dismissWidgetGuide()
    setShowWidgetGuide(false)
  }, [])

  return (
    <Screen
      preset="auto"
      safeAreaEdges={["top", "bottom"]}
      contentContainerStyle={themed($container)}
    >
      <Button
        text="Back to Today"
        onPress={() => (router.canGoBack() ? router.back() : router.replace("/"))}
      />
      <View style={themed($header)}>
        <Text text="Verse of the moment" preset="subheading" style={themed($eyebrow)} />
        <Text text={countdown} size="xs" style={themed($countdown)} />
      </View>

      {showWidgetGuide && (
        <View style={themed($widgetGuide)} accessibilityRole="summary">
          <Text text="Put Scripture on your lock screen" preset="subheading" />
          <Text
            text="Your Bible and rotating verses work completely offline. Add the widget to keep Scripture visible throughout the day."
            size="xs"
            style={themed($guideBody)}
          />
          {showWidgetSteps && (
            <Text
              text={
                "1. Touch and hold your lock screen, then tap Customize.\n" +
                "2. Tap the box under the clock and choose John 1:1.\n" +
                "3. Add Daily Verse for rotating Scripture, Daily Reading for today’s Gospel, or both.\n" +
                "4. Use the rectangular size when you want the full verse text."
              }
              size="xs"
              style={themed($guideSteps)}
            />
          )}
          <View style={themed([$guideActions, stackActions && $actionsStacked])}>
            <Button
              text={showWidgetSteps ? "Hide steps" : "How to add it"}
              preset="reversed"
              onPress={() => setShowWidgetSteps((visible) => !visible)}
              style={themed($action)}
              accessibilityState={{ expanded: showWidgetSteps }}
            />
            <Button
              text="Got it"
              onPress={onDismissWidgetGuide}
              style={themed($action)}
              accessibilityHint="Dismisses this guide"
            />
          </View>
        </View>
      )}

      <View style={themed($card)}>
        {verse ? (
          <>
            <Text text={`“${verse.text}”`} size="xl" weight="semiBold" />
            <Text text={verse.ref} preset="subheading" style={themed($reference)} />
            <Text text={meta.abbreviation} size="xs" style={themed($translation)} />
          </>
        ) : (
          <Text text="No verse available." preset="subheading" />
        )}
      </View>

      <View style={themed([$actions, stackActions && $actionsStacked])}>
        <Button text="Share" preset="reversed" onPress={onShare} style={themed($action)} />
        <Button text="Read in context" onPress={onReadInContext} style={themed($action)} />
      </View>

      {verse && (
        <Button
          text="Create a Scripture card"
          onPress={() =>
            router.push({
              pathname: "/share-card",
              params: {
                book: verse.book,
                chapter: String(verse.chapter),
                startVerse: verse.verse,
                translation: meta.id,
              },
            })
          }
        />
      )}
      <Text text={meta.attribution} size="xxs" style={themed($attribution)} />
    </Screen>
  )
}

const $container: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexGrow: 1,
  paddingHorizontal: spacing.lg,
  paddingTop: spacing.lg,
  paddingBottom: spacing.xl,
  gap: spacing.lg,
})

const $header: ThemedStyle<ViewStyle> = () => ({
  flexDirection: "row",
  flexWrap: "wrap",
  justifyContent: "space-between",
  alignItems: "baseline",
  gap: 8,
})

const $eyebrow: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.textDim,
})

const $countdown: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
})

const $card: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  flexGrow: 1,
  justifyContent: "center",
  backgroundColor: colors.palette.neutral100,
  borderRadius: 20,
  paddingHorizontal: spacing.lg,
  paddingVertical: spacing.xl,
  gap: spacing.md,
})

const $reference: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
})

const $translation: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.textDim,
  letterSpacing: 1,
})

const $actions: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  gap: spacing.sm,
})

const $actionsStacked: ThemedStyle<ViewStyle> = () => ({
  flexDirection: "column",
})

const $widgetGuide: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  backgroundColor: colors.palette.neutral100,
  borderWidth: 1,
  borderColor: colors.border,
  borderRadius: 16,
  padding: spacing.md,
  gap: spacing.sm,
})

const $guideBody: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.textDim,
})

const $guideSteps: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.text,
  lineHeight: 22,
})

const $guideActions: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  gap: spacing.sm,
})

const $action: ThemedStyle<ViewStyle> = () => ({
  flex: 1,
})

const $attribution: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.textDim,
  textAlign: "center",
})
