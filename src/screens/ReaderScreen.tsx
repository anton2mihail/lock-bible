import { FC, useCallback, useMemo, useState } from "react"
import { SectionList, TextStyle, TouchableOpacity, View, ViewStyle } from "react-native"
import { useLocalSearchParams } from "expo-router"

import { Icon } from "@/components/Icon"
import { ListItem } from "@/components/ListItem"
import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import {
  getActiveTranslationMeta,
  getBook,
  listBooks,
  type BookGroup,
  type BookMeta,
} from "@/services/bible"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

const GROUP_LABELS: Record<BookGroup, string> = {
  ot: "Old Testament",
  deutero: "Deuterocanon",
  nt: "New Testament",
}

type Mode = "books" | "chapters" | "verses"

export const ReaderScreen: FC = function ReaderScreen() {
  const { themed, theme } = useAppTheme()
  const params = useLocalSearchParams<{ book?: string; chapter?: string }>()
  const books = useMemo(() => listBooks(), [])
  const meta = getActiveTranslationMeta()

  const initialBook = params.book ? books.find((b) => b.code === params.book) : undefined
  const initialChapter = params.chapter ? Number(params.chapter) : undefined

  const [mode, setMode] = useState<Mode>(
    initialBook ? (initialChapter ? "verses" : "chapters") : "books",
  )
  const [book, setBook] = useState<BookMeta | undefined>(initialBook)
  const [chapter, setChapter] = useState<number | undefined>(initialChapter)

  const sections = useMemo(() => {
    const groups: BookGroup[] = ["ot", "deutero", "nt"]
    return groups
      .map((g) => ({ title: GROUP_LABELS[g], data: books.filter((b) => b.group === g) }))
      .filter((s) => s.data.length > 0)
  }, [books])

  const openBook = useCallback((b: BookMeta) => {
    setBook(b)
    setChapter(undefined)
    setMode("chapters")
  }, [])

  const openChapter = useCallback((c: number) => {
    setChapter(c)
    setMode("verses")
  }, [])

  const goBack = useCallback(() => {
    setMode((m) => (m === "verses" ? "chapters" : "books"))
  }, [])

  // ---- Books list ----
  if (mode === "books") {
    return (
      <Screen preset="fixed" safeAreaEdges={["top"]} contentContainerStyle={themed($flex)}>
        <Text text="Read the Bible" preset="heading" style={themed($screenTitle)} />
        <SectionList
          sections={sections}
          keyExtractor={(item) => item.code}
          contentContainerStyle={themed($listContent)}
          stickySectionHeadersEnabled={false}
          renderSectionHeader={({ section }) => (
            <Text text={section.title} preset="formLabel" style={themed($sectionHeader)} />
          )}
          renderItem={({ item }) => (
            <ListItem
              text={item.name}
              rightIcon="caretRight"
              onPress={() => openBook(item)}
              bottomSeparator
            />
          )}
        />
      </Screen>
    )
  }

  // ---- Chapter grid ----
  if (mode === "chapters" && book) {
    const chapters = Array.from({ length: book.chapterCount }, (_, i) => i + 1)
    return (
      <Screen preset="scroll" safeAreaEdges={["top"]} contentContainerStyle={themed($padded)}>
        <ReaderHeader title={book.name} onBack={goBack} themed={themed} tint={theme.colors.text} />
        <View style={themed($grid)}>
          {chapters.map((c) => (
            <TouchableOpacity key={c} style={themed($chip)} onPress={() => openChapter(c)}>
              <Text text={String(c)} style={themed($chipText)} />
            </TouchableOpacity>
          ))}
        </View>
      </Screen>
    )
  }

  // ---- Verses ----
  if (mode === "verses" && book && chapter != null) {
    const data = getBook(book.code)
    const chap = data.chapters.find((c) => c.c === chapter)
    return (
      <Screen preset="scroll" safeAreaEdges={["top"]} contentContainerStyle={themed($padded)}>
        <ReaderHeader
          title={`${book.name} ${chapter}`}
          onBack={goBack}
          themed={themed}
          tint={theme.colors.text}
        />
        <View style={themed($verseBlock)}>
          {chap?.verses.map((v) => (
            <Text key={v.n} style={themed($passage)}>
              <Text text={`${v.n} `} size="xs" style={themed($verseNum)} />
              {v.t}
            </Text>
          ))}
        </View>
        <Text text={meta.attribution} size="xxs" style={themed($attribution)} />
      </Screen>
    )
  }

  return null
}

interface ReaderHeaderProps {
  title: string
  onBack: () => void
  themed: ReturnType<typeof useAppTheme>["themed"]
  tint: string
}

function ReaderHeader({ title, onBack, themed, tint }: ReaderHeaderProps) {
  return (
    <View style={themed($readerHeader)}>
      <TouchableOpacity onPress={onBack} style={themed($backButton)} accessibilityRole="button">
        <Icon icon="caretLeft" size={24} color={tint} />
      </TouchableOpacity>
      <Text text={title} preset="heading" style={themed($headerTitle)} />
    </View>
  )
}

const $flex: ThemedStyle<ViewStyle> = () => ({ flex: 1 })

const $screenTitle: ThemedStyle<TextStyle> = ({ spacing }) => ({
  paddingHorizontal: spacing.lg,
  paddingTop: spacing.md,
  paddingBottom: spacing.sm,
})

const $listContent: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingHorizontal: spacing.lg,
  paddingBottom: spacing.xl,
})

const $sectionHeader: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.textDim,
  marginTop: spacing.lg,
  marginBottom: spacing.xs,
})

const $padded: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingHorizontal: spacing.lg,
  paddingBottom: spacing.xxl,
})

const $readerHeader: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  alignItems: "center",
  paddingVertical: spacing.sm,
  gap: spacing.xs,
})

const $backButton: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingVertical: spacing.xs,
  paddingRight: spacing.xs,
})

const $headerTitle: ThemedStyle<TextStyle> = () => ({ flex: 1 })

const $grid: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  flexWrap: "wrap",
  gap: spacing.sm,
  marginTop: spacing.sm,
})

const $chip: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  width: 52,
  height: 52,
  borderRadius: 12,
  backgroundColor: colors.palette.neutral100,
  alignItems: "center",
  justifyContent: "center",
  borderWidth: 1,
  borderColor: colors.border,
  marginRight: 0,
  paddingHorizontal: spacing.xxxs,
})

const $chipText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.text })

const $verseBlock: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  marginTop: spacing.sm,
  gap: spacing.xs,
})

const $passage: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.text,
  fontSize: 18,
  lineHeight: 30,
})

const $verseNum: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
})

const $attribution: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.textDim,
  marginTop: spacing.xl,
})
