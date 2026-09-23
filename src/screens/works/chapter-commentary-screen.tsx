import { FC, useMemo } from "react"
import { Pressable, TextStyle, View, ViewStyle } from "react-native"
import { useRouter } from "expo-router"

import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import { listBooks } from "@/services/bible"
import {
  getChapterCommentary,
  getCollection,
  plural,
  type ChapterCommentary,
} from "@/services/works"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

type ChapterCommentaryScreenProps = {
  book?: string
  chapter?: string
}

/**
 * Everything the Fathers wrote on one chapter of Scripture.
 *
 * The Bible reader shows the first three and then offered "All 55 readings on
 * this chapter" with nowhere to send anyone; this is where that goes. It reads
 * only the bundled catalog, so it does not mount the works database - which is
 * why it sits outside /works.
 */
export const ChapterCommentaryScreen: FC<ChapterCommentaryScreenProps> =
  function ChapterCommentaryScreen({ book, chapter }) {
    const { themed } = useAppTheme()
    const router = useRouter()

    const chapterNumber = chapter ? Number(chapter) : undefined
    const entries = getChapterCommentary(book, chapterNumber)

    const bookName = useMemo(
      () => listBooks().find((candidate) => candidate.code === book)?.name ?? book ?? "",
      [book],
    )

    // Grouped by author: on a well-covered chapter this is two or three
    // Fathers with a dozen readings each, and an ungrouped list of fifty-five
    // rows gives no sense of whose they are.
    const groups = useMemo(() => {
      const byCollection = new Map<string, ChapterCommentary[]>()
      for (const entry of entries) {
        const bucket = byCollection.get(entry.collectionId)
        if (bucket) bucket.push(entry)
        else byCollection.set(entry.collectionId, [entry])
      }
      return [...byCollection.entries()].map(([collectionId, items]) => ({
        collectionId,
        author: getCollection(collectionId)?.author ?? "",
        items,
      }))
    }, [entries])

    if (!entries.length) {
      return (
        <Screen preset="fixed" safeAreaEdges={["top"]} contentContainerStyle={themed($missing)}>
          <Text text="No readings on this chapter" preset="subheading" />
          <Pressable onPress={() => router.back()} accessibilityRole="button" hitSlop={8}>
            <Text text="Go back" size="sm" style={themed($tint)} />
          </Pressable>
        </Screen>
      )
    }

    return (
      <Screen preset="scroll" safeAreaEdges={["top"]} contentContainerStyle={themed($container)}>
        <Pressable
          onPress={() => router.back()}
          accessibilityRole="button"
          accessibilityLabel={`Back to ${bookName} ${chapterNumber}`}
          hitSlop={8}
          style={({ pressed }) => themed([$back, pressed && $pressed])}
        >
          <Text text="‹" size="xl" style={themed($backMark)} />
          <Text
            text={`${bookName} ${chapterNumber}`}
            size="sm"
            weight="semiBold"
            style={themed($tint)}
          />
        </Pressable>

        <View style={themed($heading)}>
          <Text text="THE FATHERS ON" size="xxs" weight="semiBold" style={themed($eyebrow)} />
          <Text text={`${bookName} ${chapterNumber}`} preset="heading" accessibilityRole="header" />
          <Text
            text={`${plural(entries.length, "reading")} · ${plural(groups.length, "author")}`}
            size="sm"
            style={themed($subtitle)}
          />
        </View>

        {groups.map((group) => (
          <View key={group.collectionId} style={themed($group)}>
            <Text
              text={group.author}
              preset="formLabel"
              style={themed($groupHeader)}
              accessibilityRole="header"
            />
            {group.items.map((entry) => (
              <Pressable
                key={`${entry.workId}-${entry.sectionIndex}`}
                onPress={() =>
                  router.push({
                    pathname: "/works/[id]",
                    params: { id: entry.workId, section: String(entry.sectionIndex) },
                  })
                }
                accessibilityRole="button"
                accessibilityLabel={`${entry.sectionTitle}, ${entry.workTitle}, ${group.author}`}
                testID={`commentary-${entry.workId}-${entry.sectionIndex}`}
                style={({ pressed }) => themed([$row, pressed && $pressed])}
              >
                <View style={$flex}>
                  <Text text={entry.sectionTitle} weight="medium" />
                  <Text text={entry.workTitle} size="xxs" style={themed($meta)} />
                </View>
                <Text text="›" size="xl" style={themed($tint)} />
              </Pressable>
            ))}
          </View>
        ))}
      </Screen>
    )
  }

const $container: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingHorizontal: spacing.lg,
  paddingTop: spacing.md,
  paddingBottom: spacing.xxl,
  gap: spacing.lg,
})
const $missing: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flex: 1,
  alignItems: "center",
  justifyContent: "center",
  gap: spacing.sm,
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
const $group: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.xxs })
const $groupHeader: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.textDim,
  marginBottom: spacing.xxs,
})
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
