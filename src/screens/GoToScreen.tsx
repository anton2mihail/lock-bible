import { FC, Fragment, useMemo, useRef, useState } from "react"
import {
  LayoutChangeEvent,
  Pressable,
  ScrollView,
  TextStyle,
  TouchableOpacity,
  useWindowDimensions,
  View,
  ViewStyle,
} from "react-native"
import { useLocalSearchParams, useRouter } from "expo-router"
import { Feather } from "@expo/vector-icons"

import { ChapterGrid } from "@/components/ChapterGrid"
import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import { listBooks, type BookGroup, type BookMeta } from "@/services/bible"
import { plural } from "@/services/works"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

const GROUP_LABELS: Record<BookGroup, string> = {
  ot: "Old Testament",
  deutero: "Deuterocanon",
  nt: "New Testament",
}

/**
 * Every book, with the one being read opened to its chapters, so any chapter
 * is two taps away and the current one is one tap from where it was.
 */
export const GoToScreen: FC = function GoToScreen() {
  const router = useRouter()
  const params = useLocalSearchParams<{ book?: string; chapter?: string }>()
  const { themed, theme } = useAppTheme()
  const { height } = useWindowDimensions()
  const books = useMemo(() => listBooks(), [])
  const currentChapter = params.chapter ? Number(params.chapter) : undefined
  const [openBook, setOpenBook] = useState<string | undefined>(params.book)
  const scrollRef = useRef<ScrollView>(null)
  const contentRef = useRef<View>(null)
  const currentChapterRef = useRef<View>(null)
  const scrolledToCurrent = useRef(false)

  const sections = useMemo(
    () =>
      (["ot", "deutero", "nt"] as const)
        .map((group) => ({
          title: GROUP_LABELS[group],
          books: books.filter((book) => book.group === group),
        }))
        .filter((section) => section.books.length > 0),
    [books],
  )

  // Search and this screen sit above the tabs: dismissTo returns to the
  // existing Read tab and hands it the chapter.
  const goTo = (book: BookMeta, chapter: number) =>
    router.dismissTo({
      pathname: "/read",
      params: { book: book.code, chapter: String(chapter), contextRequest: String(Date.now()) },
    })

  const pressBook = (book: BookMeta) => {
    if (book.chapterCount === 1) {
      goTo(book, 1)
      return
    }
    setOpenBook((current) => (current === book.code ? undefined : book.code))
  }

  // Bring where the reader is into view once: the current chapter's cell, a
  // third of the way down the screen (in the Psalms it can be twenty rows into
  // the grid), or the book's row when no chapter was given.
  const scrollOnce = (y: number) => {
    scrolledToCurrent.current = true
    requestAnimationFrame(() => scrollRef.current?.scrollTo({ y: Math.max(0, y), animated: false }))
  }
  const scrollToCurrentChapter = () => {
    const cell = currentChapterRef.current
    const content = contentRef.current
    if (scrolledToCurrent.current || !cell || !content) return
    cell.measureLayout(
      content,
      (_x, y) => scrollOnce(y - height / 3),
      () => {},
    )
  }
  const scrollToCurrentBook = (event: LayoutChangeEvent) => {
    if (scrolledToCurrent.current || currentChapter) return
    scrollOnce(event.nativeEvent.layout.y - theme.spacing.xl)
  }

  return (
    <Screen preset="fixed" safeAreaEdges={["top"]} contentContainerStyle={themed($screen)}>
      <View style={themed($titleRow)}>
        <Text text="Go to" preset="heading" accessibilityRole="header" />
        <TouchableOpacity
          onPress={() => (router.canGoBack() ? router.back() : router.replace("/read"))}
          style={themed($cancelButton)}
          accessibilityRole="button"
          accessibilityLabel="Close"
        >
          <Text text="Cancel" weight="medium" style={themed($cancelText)} />
        </TouchableOpacity>
      </View>

      <ScrollView ref={scrollRef} contentContainerStyle={themed($list)}>
        <View ref={contentRef}>
          {sections.map((section) => (
            <Fragment key={section.title}>
              <Text
                text={section.title}
                preset="formLabel"
                accessibilityRole="header"
                style={themed($sectionHeader)}
              />
              {section.books.map((book) => {
                const open = openBook === book.code
                const current = book.code === params.book
                const icon =
                  book.chapterCount === 1 ? "chevron-right" : open ? "chevron-up" : "chevron-down"
                return (
                  <View key={book.code} onLayout={current ? scrollToCurrentBook : undefined}>
                    <Pressable
                      onPress={() => pressBook(book)}
                      style={({ pressed }) => themed([$bookRow, pressed && $pressed])}
                      accessibilityRole="button"
                      accessibilityState={book.chapterCount > 1 ? { expanded: open } : undefined}
                      accessibilityLabel={`${book.name}, ${plural(book.chapterCount, "chapter")}`}
                      testID={`go-to-book-${book.code}`}
                    >
                      <Text
                        text={book.name}
                        weight={current ? "semiBold" : "normal"}
                        style={themed(current ? $currentBookName : $bookName)}
                      />
                      <Feather name={icon} size={18} color={theme.colors.textDim} />
                    </Pressable>
                    {open && (
                      <View style={themed($chapters)}>
                        <ChapterGrid
                          bookName={book.name}
                          chapterCount={book.chapterCount}
                          currentChapter={current ? currentChapter : undefined}
                          onSelect={(chapter) => goTo(book, chapter)}
                          currentChapterRef={current ? currentChapterRef : undefined}
                          onCurrentChapterLayout={current ? scrollToCurrentChapter : undefined}
                        />
                      </View>
                    )}
                  </View>
                )
              })}
            </Fragment>
          ))}
        </View>
      </ScrollView>
    </Screen>
  )
}

const $screen: ThemedStyle<ViewStyle> = ({ spacing }) => ({ flex: 1, paddingTop: spacing.md })

const $titleRow: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  alignItems: "center",
  justifyContent: "space-between",
  paddingHorizontal: spacing.lg,
  gap: spacing.sm,
})

const $cancelButton: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 44,
  justifyContent: "center",
  paddingHorizontal: spacing.xs,
})

const $cancelText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint })

const $list: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingHorizontal: spacing.lg,
  paddingBottom: spacing.xxl,
})

const $sectionHeader: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.textDim,
  marginTop: spacing.lg,
  marginBottom: spacing.xs,
})

const $bookRow: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  minHeight: 52,
  flexDirection: "row",
  alignItems: "center",
  justifyContent: "space-between",
  gap: spacing.sm,
  borderBottomWidth: 1,
  borderBottomColor: colors.separator,
})

const $pressed: ThemedStyle<ViewStyle> = () => ({ opacity: 0.6 })

const $bookName: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.text, flexShrink: 1 })

const $currentBookName: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
  flexShrink: 1,
})

const $chapters: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingBottom: spacing.md,
})
