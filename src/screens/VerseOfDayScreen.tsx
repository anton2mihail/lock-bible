import { FC, useCallback, useEffect, useState } from "react"
import { Share, TextStyle, View, ViewStyle } from "react-native"
import { useFocusEffect, useRouter } from "expo-router"

import { Button } from "@/components/Button"
import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import {
  formatVerseForShare,
  getActiveTranslationMeta,
  getCurrentVerse,
  getRotationInterval,
  nextRotationDate,
  type WidgetVerse,
} from "@/services/bible"
import { syncWidget } from "@/services/widget/widgetBridge"
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

  const [verse, setVerse] = useState<WidgetVerse | undefined>(() => getCurrentVerse())
  const [countdown, setCountdown] = useState("")

  const refresh = useCallback(() => {
    const now = new Date()
    setVerse(getCurrentVerse(now))
    setCountdown(timeUntil(nextRotationDate(now, getRotationInterval()), now))
  }, [])

  // Recompute on focus and keep the verse + countdown live while open.
  useFocusEffect(
    useCallback(() => {
      refresh()
      // Keep the widget in sync whenever the user lands on Today.
      syncWidget()
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
    router.push({ pathname: "/read", params: { book: verse.book, chapter: String(verse.chapter) } })
  }, [router, verse])

  return (
    <Screen
      preset="auto"
      safeAreaEdges={["top", "bottom"]}
      contentContainerStyle={themed($container)}
    >
      <View style={themed($header)}>
        <Text text="Verse of the moment" preset="subheading" style={themed($eyebrow)} />
        <Text text={countdown} size="xs" style={themed($countdown)} />
      </View>

      <View style={themed($card)}>
        {verse ? (
          <>
            <Text text={`“${verse.text}”`} preset="heading" style={themed($verseText)} />
            <Text text={verse.ref} preset="subheading" style={themed($reference)} />
            <Text text={meta.abbreviation} size="xs" style={themed($translation)} />
          </>
        ) : (
          <Text text="No verse available." preset="subheading" />
        )}
      </View>

      <View style={themed($actions)}>
        <Button text="Share" preset="reversed" onPress={onShare} style={themed($action)} />
        <Button text="Read in context" onPress={onReadInContext} style={themed($action)} />
      </View>

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
  justifyContent: "space-between",
  alignItems: "baseline",
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

const $verseText: ThemedStyle<TextStyle> = () => ({
  lineHeight: 36,
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

const $action: ThemedStyle<ViewStyle> = () => ({
  flex: 1,
})

const $attribution: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.textDim,
  textAlign: "center",
})
