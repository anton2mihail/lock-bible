import { FC, useCallback, useState } from "react"
import { Pressable, TextStyle, View, ViewStyle } from "react-native"
import { useFocusEffect, useRouter } from "expo-router"

import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import { COLLECTIONS, formatReadingLength, getLastRead, plural, WORKS } from "@/services/works"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

/** Rounded for the shelf: "2.5 million words" reads better than the exact count. */
function formatCorpusSize(words: number): string {
  if (words >= 1_000_000) return `${(words / 1_000_000).toFixed(1)}m words`
  return `${Math.round(words / 1000)}k words`
}

export const WorksLibraryScreen: FC = function WorksLibraryScreen() {
  const { themed } = useAppTheme()
  const router = useRouter()
  const [lastRead, setLastRead] = useState(getLastRead)

  useFocusEffect(
    useCallback(() => {
      setLastRead(getLastRead())
    }, []),
  )

  const totalWords = COLLECTIONS.reduce((sum, collection) => sum + collection.words, 0)

  return (
    <Screen preset="scroll" safeAreaEdges={["top"]} contentContainerStyle={themed($container)}>
      <Pressable
        onPress={() => router.back()}
        accessibilityRole="button"
        accessibilityLabel="Back"
        hitSlop={8}
        style={({ pressed }) => themed([$back, pressed && $pressed])}
      >
        <Text text="‹" size="xl" style={themed($backMark)} />
        <Text text="Read" size="sm" weight="semiBold" style={themed($tint)} />
      </Pressable>

      <View style={themed($heading)}>
        <Text text="THE LIBRARY" size="xxs" weight="semiBold" style={themed($eyebrow)} />
        <Text text="The Fathers & Doctors" preset="heading" accessibilityRole="header" />
        <Text
          text={`${plural(COLLECTIONS.length, "author")} · ${plural(WORKS.length, "work")} · ${formatCorpusSize(totalWords)} · reads offline`}
          size="sm"
          style={themed($subtitle)}
        />
      </View>

      {lastRead && (
        <Pressable
          onPress={() =>
            router.push({
              pathname: "/works/[id]",
              params: {
                id: lastRead.work.id,
                section: String(lastRead.position.sectionIndex),
              },
            })
          }
          accessibilityRole="button"
          accessibilityLabel={`Continue ${lastRead.work.title}, section ${lastRead.position.sectionIndex + 1}`}
          testID="works-continue"
          style={({ pressed }) => themed([$continueCard, pressed && $pressed])}
        >
          <Text text="CONTINUE READING" size="xxs" weight="semiBold" style={themed($eyebrow)} />
          <Text text={lastRead.work.title} preset="subheading" />
          <Text
            text={`Section ${lastRead.position.sectionIndex + 1} of ${lastRead.work.sectionCount}`}
            size="xs"
            style={themed($subtitle)}
          />
        </Pressable>
      )}

      <View style={themed($list)}>
        {COLLECTIONS.map((collection) => (
          <Pressable
            key={collection.id}
            onPress={() =>
              router.push({ pathname: "/works/author/[id]", params: { id: collection.id } })
            }
            accessibilityRole="button"
            accessibilityLabel={`${collection.author}. ${plural(collection.workCount, "work")}. ${formatReadingLength(collection.words)}.`}
            testID={`collection-${collection.id}`}
            style={({ pressed }) => themed([$row, pressed && $pressed])}
          >
            <View style={$flex}>
              <Text text={collection.author} weight="medium" />
              <Text
                text={
                  collection.era
                    ? `${collection.era} · ${plural(collection.workCount, "work")} · ${formatCorpusSize(collection.words)}`
                    : `${plural(collection.workCount, "work")} · ${formatCorpusSize(collection.words)}`
                }
                size="xxs"
                style={themed($meta)}
              />
            </View>
            <Text text="›" size="xl" style={themed($tint)} />
          </Pressable>
        ))}
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
const $heading: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.xs })
const $eyebrow: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
  letterSpacing: 1.5,
  textTransform: "uppercase",
})
const $subtitle: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })
const $meta: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })
const $continueCard: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  gap: spacing.xxs,
  backgroundColor: colors.palette.neutral100,
  borderRadius: 18,
  borderCurve: "continuous",
  padding: spacing.lg,
})
const $list: ThemedStyle<ViewStyle> = () => ({})
const $row: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  minHeight: 68,
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.md,
  borderBottomWidth: 1,
  borderBottomColor: colors.separator,
  paddingVertical: spacing.sm,
})
const $tint: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint })
const $pressed: ThemedStyle<ViewStyle> = () => ({ opacity: 0.7 })
const $flex: ViewStyle = { flex: 1 }
