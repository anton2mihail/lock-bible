import { Ref } from "react"
import { TextStyle, TouchableOpacity, View, ViewStyle } from "react-native"

import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

import { Text } from "./Text"

export interface ChapterGridProps {
  bookName: string
  chapterCount: number
  /** The chapter being read, marked so the reader can see where they are. */
  currentChapter?: number
  onSelect: (chapter: number) => void
  /** The current chapter's cell, for scrolling a long book to it once laid out. */
  currentChapterRef?: Ref<View>
  onCurrentChapterLayout?: () => void
}

/** A book's chapters as a grid of numbers. */
export function ChapterGrid({
  bookName,
  chapterCount,
  currentChapter,
  onSelect,
  currentChapterRef,
  onCurrentChapterLayout,
}: ChapterGridProps) {
  const { themed } = useAppTheme()
  return (
    <View style={themed($grid)}>
      {Array.from({ length: chapterCount }, (_, index) => index + 1).map((chapter) => {
        const current = chapter === currentChapter
        return (
          <TouchableOpacity
            key={chapter}
            ref={current ? currentChapterRef : undefined}
            onLayout={current ? onCurrentChapterLayout : undefined}
            style={themed([$chip, current && $chipCurrent])}
            onPress={() => onSelect(chapter)}
            accessibilityRole="button"
            accessibilityState={{ selected: current }}
            accessibilityLabel={`${bookName} chapter ${chapter}`}
          >
            <Text
              text={String(chapter)}
              style={themed(current ? $chipTextCurrent : $chipText)}
              maxFontSizeMultiplier={1.6}
            />
          </TouchableOpacity>
        )
      })}
    </View>
  )
}

const $grid: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  flexWrap: "wrap",
  gap: spacing.sm,
  marginTop: spacing.sm,
})

const $chip: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  width: 52,
  minHeight: 52,
  borderRadius: 12,
  backgroundColor: colors.palette.neutral100,
  alignItems: "center",
  justifyContent: "center",
  borderWidth: 1,
  borderColor: colors.border,
  paddingHorizontal: spacing.xxxs,
})

const $chipCurrent: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.tint,
  borderColor: colors.tint,
})

const $chipText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.text })

const $chipTextCurrent: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.palette.neutral100,
})
