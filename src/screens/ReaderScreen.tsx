import { FC, useCallback, useEffect, useMemo, useRef, useState } from "react"
import {
  LayoutChangeEvent,
  NativeScrollEvent,
  NativeSyntheticEvent,
  SectionList,
  Share,
  TextStyle,
  TouchableOpacity,
  useWindowDimensions,
  View,
  ViewStyle,
} from "react-native"
import * as Clipboard from "expo-clipboard"
import { useLocalSearchParams, useRouter } from "expo-router"
import type { KeyboardAwareScrollViewRef } from "react-native-keyboard-controller"

import { Button } from "@/components/Button"
import { Icon } from "@/components/Icon"
import { ListItem } from "@/components/ListItem"
import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import {
  getActiveTranslationMeta,
  getBook,
  getReaderLocation,
  listBooks,
  setReaderLocation,
  type BookGroup,
  type BookMeta,
  type ReaderLocation,
} from "@/services/bible"
import { useLibraryDatabase } from "@/services/database"
import {
  applyHighlight,
  clearHighlight,
  createPassageSelection,
  getChapterHighlights,
  passageReference,
  toggleBookmark,
  type HighlightColor,
  type PassageSelection,
} from "@/services/library"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"
import { useReaderTypography } from "@/theme/useReaderTypography"

const GROUP_LABELS: Record<BookGroup, string> = {
  ot: "Old Testament",
  deutero: "Deuterocanon",
  nt: "New Testament",
}

type Mode = "books" | "chapters" | "verses"

interface PassageTarget {
  book: BookMeta
  chapter: number
}

const HIGHLIGHT_FILLS: Record<HighlightColor, { light: string; dark: string }> = {
  gold: { light: "#F4D89A", dark: "rgba(244, 216, 154, 0.24)" },
  sage: { light: "#C8D6C0", dark: "rgba(200, 214, 192, 0.24)" },
  rose: { light: "#E6C5C8", dark: "rgba(230, 197, 200, 0.24)" },
  blue: { light: "#C6D5E6", dark: "rgba(198, 213, 230, 0.24)" },
}

export const ReaderScreen: FC = function ReaderScreen() {
  const { themed, theme } = useAppTheme()
  const libraryDatabase = useLibraryDatabase()
  const router = useRouter()
  const { fontScale, width } = useWindowDimensions()
  const stackChapterNavigation = width < 360 || fontScale > 1.25
  const params = useLocalSearchParams<{
    book?: string
    chapter?: string
    verse?: string
    endVerse?: string
    contextRequest?: string
  }>()
  const books = useMemo(() => listBooks(), [])
  const meta = getActiveTranslationMeta()

  const initialBook = params.book
    ? books.find((candidate) => candidate.code === params.book)
    : undefined
  const initialChapter = params.chapter ? Number(params.chapter) : undefined

  const [mode, setMode] = useState<Mode>(
    initialBook && initialChapter ? "verses" : initialBook ? "chapters" : "books",
  )
  const [book, setBook] = useState<BookMeta | undefined>(initialBook)
  const [chapter, setChapter] = useState<number | undefined>(initialChapter)
  const [contextVerse, setContextVerse] = useState<string | undefined>(params.verse)
  const [contextEndVerse, setContextEndVerse] = useState<string | undefined>(params.endVerse)
  const [savedLocation, setSavedLocation] = useState<ReaderLocation | null>(getReaderLocation)
  const [selectionRange, setSelectionRange] = useState<[number, number] | null>(null)
  const [chapterHighlights, setChapterHighlights] = useState<Record<string, HighlightColor>>({})
  const [showHighlightChoices, setShowHighlightChoices] = useState(false)
  const [actionFeedback, setActionFeedback] = useState("")

  const scrollViewRef = useRef<KeyboardAwareScrollViewRef>(null)
  const pendingOffsetRef = useRef<number | null>(null)
  const verseBlockYRef = useRef<number | null>(null)
  const contextVerseYRef = useRef<number | null>(null)
  const contextScrollCompletedRef = useRef(false)

  const selectedChapter = useMemo(() => {
    if (!book || chapter == null) return undefined
    return getBook(book.code).chapters.find((candidate) => candidate.c === chapter)
  }, [book, chapter])

  const selectedPassage = useMemo(() => {
    if (!book || !selectedChapter || !selectionRange) return null
    return createPassageSelection(
      meta.id,
      book,
      selectedChapter,
      selectionRange[0],
      selectionRange[1],
    )
  }, [book, meta.id, selectedChapter, selectionRange])

  const contextRange = useMemo<[number, number] | null>(() => {
    if (!selectedChapter || !contextVerse) return null
    const startIndex = selectedChapter.verses.findIndex((verse) => verse.n === contextVerse)
    if (startIndex < 0) return null
    const requestedEndIndex = selectedChapter.verses.findIndex(
      (verse) => verse.n === (contextEndVerse ?? contextVerse),
    )
    const endIndex = requestedEndIndex >= 0 ? requestedEndIndex : startIndex
    return [Math.min(startIndex, endIndex), Math.max(startIndex, endIndex)]
  }, [contextEndVerse, contextVerse, selectedChapter])

  useEffect(() => {
    if (!book || chapter == null) {
      setChapterHighlights({})
      return
    }
    getChapterHighlights(libraryDatabase, meta.id, book.code, chapter)
      .then(setChapterHighlights)
      .catch(() => setChapterHighlights({}))
  }, [book, chapter, libraryDatabase, meta.id])

  const passageStyle = useReaderTypography()

  const rememberLocation = useCallback(
    (targetBook: BookMeta, targetChapter: number, scrollY: number) => {
      const nextLocation: ReaderLocation = {
        book: targetBook.code,
        chapter: targetChapter,
        scrollY: Math.max(0, scrollY),
        updatedAt: Date.now(),
      }
      setReaderLocation(nextLocation)
      setSavedLocation(nextLocation)
    },
    [],
  )

  const openPassage = useCallback(
    (
      targetBook: BookMeta,
      targetChapter: number,
      options?: { verse?: string; endVerse?: string; scrollY?: number },
    ) => {
      const scrollY = options?.scrollY ?? 0
      verseBlockYRef.current = null
      contextVerseYRef.current = null
      contextScrollCompletedRef.current = false
      pendingOffsetRef.current = options?.verse ? null : scrollY
      setBook(targetBook)
      setChapter(targetChapter)
      setContextVerse(options?.verse)
      setContextEndVerse(options?.endVerse)
      setSelectionRange(null)
      setShowHighlightChoices(false)
      setActionFeedback("")
      setMode("verses")
      rememberLocation(targetBook, targetChapter, scrollY)
    },
    [rememberLocation],
  )

  // Tab screens remain mounted, so useState's initializer does not run again
  // when a widget or “Read in context” selects the existing Read tab.
  useEffect(() => {
    if (!params.book) return
    const requestedBook = books.find((candidate) => candidate.code === params.book)
    if (!requestedBook) return

    const requestedChapter = Number(params.chapter)
    const hasValidChapter =
      Number.isInteger(requestedChapter) &&
      requestedChapter >= 1 &&
      requestedChapter <= requestedBook.chapterCount

    if (hasValidChapter) {
      openPassage(requestedBook, requestedChapter, {
        verse: params.verse,
        endVerse: params.endVerse,
      })
    } else {
      setBook(requestedBook)
      setChapter(undefined)
      setContextVerse(undefined)
      setContextEndVerse(undefined)
      setMode("chapters")
    }
  }, [
    books,
    openPassage,
    params.book,
    params.chapter,
    params.contextRequest,
    params.endVerse,
    params.verse,
  ])

  const sections = useMemo(() => {
    const groups: BookGroup[] = ["ot", "deutero", "nt"]
    return groups
      .map((group) => ({
        title: GROUP_LABELS[group],
        data: books.filter((candidate) => candidate.group === group),
      }))
      .filter((section) => section.data.length > 0)
  }, [books])

  const continueTarget = useMemo(() => {
    if (!savedLocation) return undefined
    const savedBook = books.find((candidate) => candidate.code === savedLocation.book)
    if (!savedBook || savedLocation.chapter < 1 || savedLocation.chapter > savedBook.chapterCount) {
      return undefined
    }
    return { book: savedBook, chapter: savedLocation.chapter }
  }, [books, savedLocation])

  const openBook = useCallback((selectedBook: BookMeta) => {
    setBook(selectedBook)
    setChapter(undefined)
    setContextVerse(undefined)
    setContextEndVerse(undefined)
    setSelectionRange(null)
    setMode("chapters")
  }, [])

  const openChapter = useCallback(
    (selectedChapter: number) => {
      if (!book) return
      openPassage(book, selectedChapter)
    },
    [book, openPassage],
  )

  const continueReading = useCallback(() => {
    if (!continueTarget || !savedLocation) return
    openPassage(continueTarget.book, continueTarget.chapter, { scrollY: savedLocation.scrollY })
  }, [continueTarget, openPassage, savedLocation])

  const goBack = useCallback(() => {
    setContextVerse(undefined)
    setContextEndVerse(undefined)
    setSelectionRange(null)
    setMode((currentMode) => (currentMode === "verses" ? "chapters" : "books"))
  }, [])

  const adjacentPassage = useCallback(
    (direction: -1 | 1): PassageTarget | undefined => {
      if (!book || chapter == null) return undefined
      const bookIndex = books.findIndex((candidate) => candidate.code === book.code)
      if (bookIndex < 0) return undefined

      const adjacentChapter = chapter + direction
      if (adjacentChapter >= 1 && adjacentChapter <= book.chapterCount) {
        return { book, chapter: adjacentChapter }
      }

      const adjacentBook = books[bookIndex + direction]
      if (!adjacentBook) return undefined
      return {
        book: adjacentBook,
        chapter: direction === 1 ? 1 : adjacentBook.chapterCount,
      }
    },
    [book, books, chapter],
  )

  const previousPassage = adjacentPassage(-1)
  const nextPassage = adjacentPassage(1)

  const scrollToOffset = useCallback((offset: number, animated: boolean) => {
    requestAnimationFrame(() => {
      scrollViewRef.current?.scrollTo({ y: Math.max(0, offset), animated })
    })
  }, [])

  const tryScrollToContext = useCallback(() => {
    if (
      !contextVerse ||
      contextScrollCompletedRef.current ||
      verseBlockYRef.current == null ||
      contextVerseYRef.current == null
    ) {
      return
    }
    contextScrollCompletedRef.current = true
    scrollToOffset(verseBlockYRef.current + contextVerseYRef.current - 24, true)
  }, [contextVerse, scrollToOffset])

  const onVerseBlockLayout = useCallback(
    (event: LayoutChangeEvent) => {
      verseBlockYRef.current = event.nativeEvent.layout.y
      tryScrollToContext()
    },
    [tryScrollToContext],
  )

  const onContextVerseLayout = useCallback(
    (event: LayoutChangeEvent) => {
      contextVerseYRef.current = event.nativeEvent.layout.y
      tryScrollToContext()
    },
    [tryScrollToContext],
  )

  const onContentSizeChange = useCallback(() => {
    if (contextVerse) {
      tryScrollToContext()
      return
    }
    if (pendingOffsetRef.current == null) return
    const pendingOffset = pendingOffsetRef.current
    pendingOffsetRef.current = null
    scrollToOffset(pendingOffset, false)
  }, [contextVerse, scrollToOffset, tryScrollToContext])

  const persistScrollPosition = useCallback(
    (event: NativeSyntheticEvent<NativeScrollEvent>) => {
      if (!book || chapter == null) return
      rememberLocation(book, chapter, event.nativeEvent.contentOffset.y)
    },
    [book, chapter, rememberLocation],
  )

  const openSearch = useCallback(() => router.push("/search" as never), [router])

  const selectVerse = useCallback((verseIndex: number) => {
    setActionFeedback("")
    setShowHighlightChoices(false)
    setSelectionRange((current) => {
      if (!current) return [verseIndex, verseIndex]
      if (current[0] === verseIndex && current[1] === verseIndex) return null
      return [Math.min(current[0], verseIndex), Math.max(current[0], verseIndex)]
    })
  }, [])

  const copySelection = useCallback(async () => {
    if (!selectedPassage) return
    const reference = passageReference(
      selectedPassage.bookName,
      selectedPassage.chapter,
      selectedPassage.startVerse,
      selectedPassage.endVerse,
    )
    try {
      await Clipboard.setStringAsync(
        `${selectedPassage.scriptureText}\n${reference} (${meta.abbreviation})`,
      )
      setActionFeedback("Passage copied")
    } catch {
      setActionFeedback("Passage could not be copied")
    }
  }, [meta.abbreviation, selectedPassage])

  const shareSelection = useCallback(async () => {
    if (!selectedPassage) return
    const reference = passageReference(
      selectedPassage.bookName,
      selectedPassage.chapter,
      selectedPassage.startVerse,
      selectedPassage.endVerse,
    )
    try {
      await Share.share({
        message: `${selectedPassage.scriptureText}\n${reference} (${meta.abbreviation})`,
      })
    } catch {
      setActionFeedback("Share sheet could not be opened")
    }
  }, [meta.abbreviation, selectedPassage])

  const bookmarkSelection = useCallback(async () => {
    if (!selectedPassage) return
    try {
      const saved = await toggleBookmark(libraryDatabase, selectedPassage)
      setActionFeedback(saved ? "Bookmark saved" : "Bookmark removed")
    } catch {
      setActionFeedback("Bookmark could not be updated")
    }
  }, [libraryDatabase, selectedPassage])

  const highlightSelection = useCallback(
    async (color: HighlightColor) => {
      if (!selectedPassage) return
      try {
        await applyHighlight(libraryDatabase, selectedPassage, color)
        setChapterHighlights((current) => ({
          ...current,
          ...Object.fromEntries(selectedPassage.verses.map((verse) => [verse.verse, color])),
        }))
        setShowHighlightChoices(false)
        setActionFeedback(`${color[0].toUpperCase() + color.slice(1)} highlight applied`)
      } catch {
        setActionFeedback("Highlight could not be updated")
      }
    },
    [libraryDatabase, selectedPassage],
  )

  const removeSelectionHighlight = useCallback(async () => {
    if (!selectedPassage) return
    try {
      await clearHighlight(libraryDatabase, selectedPassage)
      setChapterHighlights((current) => {
        const next = { ...current }
        selectedPassage.verses.forEach((verse) => delete next[verse.verse])
        return next
      })
      setShowHighlightChoices(false)
      setActionFeedback("Highlight removed")
    } catch {
      setActionFeedback("Highlight could not be updated")
    }
  }, [libraryDatabase, selectedPassage])

  const openNote = useCallback(() => {
    if (!selectedPassage) return
    router.push({
      pathname: "/note",
      params: {
        book: selectedPassage.bookCode,
        chapter: String(selectedPassage.chapter),
        startVerse: selectedPassage.startVerse,
        endVerse: selectedPassage.endVerse,
      },
    } as never)
  }, [router, selectedPassage])

  if (mode === "books") {
    return (
      <Screen preset="fixed" safeAreaEdges={["top"]} contentContainerStyle={themed($flex)}>
        <View style={themed($screenTitleRow)}>
          <Text text="Read the Bible" preset="heading" accessibilityRole="header" />
          <TouchableOpacity
            onPress={openSearch}
            style={themed($searchButton)}
            accessibilityRole="button"
            accessibilityLabel="Search Scripture"
          >
            <Text text="Search" weight="medium" style={themed($searchButtonText)} />
          </TouchableOpacity>
        </View>
        {continueTarget && (
          <View style={themed($continueSection)}>
            <Text text="Continue reading" preset="formLabel" style={themed($sectionHeader)} />
            <View style={themed($continueSurface)}>
              <ListItem
                text={`${continueTarget.book.name} ${continueTarget.chapter}`}
                rightIcon="caretRight"
                onPress={continueReading}
                accessibilityRole="button"
                accessibilityLabel={`Continue reading ${continueTarget.book.name} chapter ${continueTarget.chapter}`}
              />
            </View>
          </View>
        )}
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
              accessibilityRole="button"
              accessibilityLabel={`${item.name}, ${item.chapterCount} chapters`}
              bottomSeparator
            />
          )}
        />
      </Screen>
    )
  }

  if (mode === "chapters" && book) {
    const chapters = Array.from({ length: book.chapterCount }, (_, index) => index + 1)
    return (
      <Screen preset="scroll" safeAreaEdges={["top"]} contentContainerStyle={themed($padded)}>
        <ReaderHeader
          title={book.name}
          backLabel="Back to books"
          onBack={goBack}
          onSearch={openSearch}
          themed={themed}
          tint={theme.colors.text}
        />
        <View style={themed($grid)}>
          {chapters.map((chapterNumber) => (
            <TouchableOpacity
              key={chapterNumber}
              style={themed($chip)}
              onPress={() => openChapter(chapterNumber)}
              accessibilityRole="button"
              accessibilityLabel={`${book.name} chapter ${chapterNumber}`}
            >
              <Text
                text={String(chapterNumber)}
                style={themed($chipText)}
                maxFontSizeMultiplier={1.6}
              />
            </TouchableOpacity>
          ))}
        </View>
      </Screen>
    )
  }

  if (mode === "verses" && book && chapter != null) {
    return (
      <View style={themed($flex)}>
        <Screen
          preset="scroll"
          safeAreaEdges={["top"]}
          contentContainerStyle={themed([$padded, selectionRange && $paddedWithToolbar])}
          scrollViewRef={scrollViewRef}
          ScrollViewProps={{
            onContentSizeChange,
            onScrollEndDrag: persistScrollPosition,
            onMomentumScrollEnd: persistScrollPosition,
          }}
        >
          <ReaderHeader
            title={`${book.name} ${chapter}`}
            backLabel={`Back to ${book.name} chapters`}
            onBack={goBack}
            onSearch={openSearch}
            themed={themed}
            tint={theme.colors.text}
          />
          <Text
            text="Tap a verse to select it. Tap another verse to select a range."
            size="xxs"
            style={themed($selectionHint)}
          />
          <View
            testID="reader-verse-block"
            style={themed($verseBlock)}
            onLayout={onVerseBlockLayout}
          >
            {selectedChapter?.verses.map((verse, verseIndex) => {
              const isContextVerse = verse.n === contextVerse
              const isInContextRange =
                !!contextRange && verseIndex >= contextRange[0] && verseIndex <= contextRange[1]
              const isSelected =
                !!selectionRange &&
                verseIndex >= selectionRange[0] &&
                verseIndex <= selectionRange[1]
              const highlightColor = chapterHighlights[verse.n]
              const backgroundColor = isSelected
                ? theme.isDark
                  ? HIGHLIGHT_FILLS.gold.dark
                  : HIGHLIGHT_FILLS.gold.light
                : highlightColor
                  ? theme.isDark
                    ? HIGHLIGHT_FILLS[highlightColor].dark
                    : HIGHLIGHT_FILLS[highlightColor].light
                  : undefined
              return (
                <TouchableOpacity
                  key={verse.n}
                  testID={isContextVerse ? "reader-context-verse" : `reader-verse-${verse.n}`}
                  onLayout={isContextVerse ? onContextVerseLayout : undefined}
                  onPress={() => selectVerse(verseIndex)}
                  activeOpacity={0.7}
                  style={[
                    themed($verseTouchable),
                    !!backgroundColor && { backgroundColor },
                    isInContextRange && !backgroundColor && themed($contextVerse),
                    isSelected && themed($selectedVerse),
                  ]}
                  accessibilityRole="button"
                  accessibilityState={{ selected: isSelected }}
                  accessibilityLabel={`Verse ${verse.n}. ${verse.t}`}
                  accessibilityHint={
                    selectionRange
                      ? "Extends the selected passage to this verse"
                      : "Selects this verse"
                  }
                >
                  <Text style={[themed($passage), passageStyle]}>
                    <Text text={`${verse.n} `} size="xs" style={themed($verseNum)} />
                    {verse.t}
                  </Text>
                </TouchableOpacity>
              )
            })}
          </View>

          <View
            style={themed([
              $chapterNavigation,
              stackChapterNavigation && $chapterNavigationStacked,
            ])}
          >
            <View style={themed($chapterNavigationSlot)}>
              {previousPassage && (
                <Button
                  text={`Previous\n${previousPassage.book.name} ${previousPassage.chapter}`}
                  preset="reversed"
                  onPress={() => openPassage(previousPassage.book, previousPassage.chapter)}
                  accessibilityLabel={`Previous chapter, ${previousPassage.book.name} chapter ${previousPassage.chapter}`}
                />
              )}
            </View>
            <View style={themed($chapterNavigationSlot)}>
              {nextPassage && (
                <Button
                  text={`Next\n${nextPassage.book.name} ${nextPassage.chapter}`}
                  onPress={() => openPassage(nextPassage.book, nextPassage.chapter)}
                  accessibilityLabel={`Next chapter, ${nextPassage.book.name} chapter ${nextPassage.chapter}`}
                />
              )}
            </View>
          </View>

          <Text text={meta.attribution} size="xxs" style={themed($attribution)} />
        </Screen>

        {selectedPassage && (
          <SelectionToolbar
            passage={selectedPassage}
            showHighlightChoices={showHighlightChoices}
            feedback={actionFeedback}
            onClose={() => {
              setSelectionRange(null)
              setShowHighlightChoices(false)
              setActionFeedback("")
            }}
            onCopy={copySelection}
            onShare={shareSelection}
            onBookmark={bookmarkSelection}
            onShowHighlights={() => setShowHighlightChoices((current) => !current)}
            onHighlight={highlightSelection}
            onClearHighlight={removeSelectionHighlight}
            onNote={openNote}
            onPray={() =>
              router.push({
                pathname: "/lectio",
                params: {
                  book: selectedPassage.bookCode,
                  chapter: String(selectedPassage.chapter),
                  startVerse: selectedPassage.startVerse,
                  endVerse: selectedPassage.endVerse,
                  translation: selectedPassage.translationId,
                },
              })
            }
            onCard={() =>
              router.push({
                pathname: "/share-card",
                params: {
                  book: selectedPassage.bookCode,
                  chapter: String(selectedPassage.chapter),
                  startVerse: selectedPassage.startVerse,
                  endVerse: selectedPassage.endVerse,
                  translation: selectedPassage.translationId,
                },
              })
            }
          />
        )}
      </View>
    )
  }

  return null
}

interface ReaderHeaderProps {
  title: string
  backLabel: string
  onBack: () => void
  onSearch?: () => void
  themed: ReturnType<typeof useAppTheme>["themed"]
  tint: string
}

function ReaderHeader({ title, backLabel, onBack, onSearch, themed, tint }: ReaderHeaderProps) {
  return (
    <View style={themed($readerHeader)}>
      <TouchableOpacity
        onPress={onBack}
        style={themed($backButton)}
        accessibilityRole="button"
        accessibilityLabel={backLabel}
        hitSlop={8}
      >
        <Icon icon="caretLeft" size={24} color={tint} />
      </TouchableOpacity>
      <Text text={title} preset="heading" style={themed($headerTitle)} accessibilityRole="header" />
      {onSearch && (
        <TouchableOpacity
          onPress={onSearch}
          style={themed($headerSearchButton)}
          accessibilityRole="button"
          accessibilityLabel="Search Scripture"
        >
          <Text text="Search" size="xs" weight="medium" style={themed($searchButtonText)} />
        </TouchableOpacity>
      )}
    </View>
  )
}

interface SelectionToolbarProps {
  passage: PassageSelection
  showHighlightChoices: boolean
  feedback: string
  onClose: () => void
  onCopy: () => void | Promise<void>
  onShare: () => void | Promise<void>
  onBookmark: () => void | Promise<void>
  onShowHighlights: () => void
  onHighlight: (color: HighlightColor) => void | Promise<void>
  onClearHighlight: () => void | Promise<void>
  onNote: () => void
  onPray: () => void
  onCard: () => void
}

function SelectionToolbar({
  passage,
  showHighlightChoices,
  feedback,
  onClose,
  onCopy,
  onShare,
  onBookmark,
  onShowHighlights,
  onHighlight,
  onClearHighlight,
  onNote,
  onPray,
  onCard,
}: SelectionToolbarProps) {
  const { themed, theme } = useAppTheme()
  const reference = passageReference(
    passage.bookName,
    passage.chapter,
    passage.startVerse,
    passage.endVerse,
  )
  const actions = [
    { label: "Copy", onPress: onCopy },
    { label: "Share", onPress: onShare },
    { label: "Bookmark", onPress: onBookmark },
    { label: "Highlight", onPress: onShowHighlights },
    { label: "Note", onPress: onNote },
    { label: "Pray", onPress: onPray },
    { label: "Create card", onPress: onCard },
  ]

  return (
    <View style={themed($selectionToolbar)} accessibilityRole="toolbar">
      <View style={themed($selectionSummary)}>
        <Text text={reference} size="xs" weight="semiBold" />
        <TouchableOpacity
          onPress={onClose}
          style={themed($closeSelection)}
          accessibilityRole="button"
          accessibilityLabel="Clear passage selection"
        >
          <Icon icon="x" size={18} color={theme.colors.text} />
        </TouchableOpacity>
      </View>
      {showHighlightChoices && (
        <View style={themed($highlightChoices)} accessibilityRole="radiogroup">
          {(Object.keys(HIGHLIGHT_FILLS) as HighlightColor[]).map((color) => (
            <TouchableOpacity
              key={color}
              onPress={() => onHighlight(color)}
              style={[
                themed($highlightChoice),
                {
                  backgroundColor: theme.isDark
                    ? HIGHLIGHT_FILLS[color].dark
                    : HIGHLIGHT_FILLS[color].light,
                },
              ]}
              accessibilityRole="button"
              accessibilityLabel={`Apply ${color} highlight`}
            >
              <Text text={color[0].toUpperCase() + color.slice(1)} size="xxs" weight="medium" />
            </TouchableOpacity>
          ))}
          <TouchableOpacity
            onPress={onClearHighlight}
            style={themed($highlightChoice)}
            accessibilityRole="button"
            accessibilityLabel="Remove highlight"
          >
            <Text text="None" size="xxs" weight="medium" />
          </TouchableOpacity>
        </View>
      )}
      <View style={themed($selectionActions)}>
        {actions.map((action) => (
          <TouchableOpacity
            key={action.label}
            onPress={action.onPress}
            style={themed($selectionAction)}
            accessibilityRole="button"
            accessibilityLabel={`${action.label} ${reference}`}
          >
            <Text text={action.label} size="xxs" weight="medium" style={themed($actionLabel)} />
          </TouchableOpacity>
        ))}
      </View>
      {!!feedback && (
        <Text
          text={feedback}
          size="xxs"
          style={themed($actionFeedback)}
          accessibilityLiveRegion="polite"
        />
      )}
    </View>
  )
}

const $flex: ThemedStyle<ViewStyle> = () => ({ flex: 1 })

const $screenTitleRow: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  alignItems: "center",
  justifyContent: "space-between",
  gap: spacing.sm,
  paddingHorizontal: spacing.lg,
  paddingTop: spacing.md,
  paddingBottom: spacing.sm,
})

const $searchButton: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  minHeight: 44,
  justifyContent: "center",
  paddingHorizontal: spacing.sm,
  borderWidth: 1,
  borderColor: colors.border,
  borderRadius: 10,
  backgroundColor: colors.palette.neutral100,
})

const $searchButtonText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint })

const $continueSection: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingHorizontal: spacing.lg,
  paddingBottom: spacing.xs,
})

const $continueSurface: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  backgroundColor: colors.palette.neutral100,
  borderRadius: 14,
  paddingHorizontal: spacing.md,
  borderWidth: 1,
  borderColor: colors.border,
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

const $paddedWithToolbar: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingBottom: spacing.xxxl + spacing.xxl,
})

const $readerHeader: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  alignItems: "center",
  paddingVertical: spacing.sm,
  gap: spacing.xs,
})

const $backButton: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minWidth: 44,
  minHeight: 44,
  alignItems: "flex-start",
  justifyContent: "center",
  paddingRight: spacing.xs,
})

const $headerTitle: ThemedStyle<TextStyle> = () => ({ flex: 1 })

const $headerSearchButton: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minWidth: 60,
  minHeight: 44,
  justifyContent: "center",
  alignItems: "flex-end",
  paddingLeft: spacing.xs,
})

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

const $chipText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.text })

const $verseBlock: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  marginTop: spacing.sm,
  gap: spacing.xs,
})

const $selectionHint: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.textDim,
  marginBottom: spacing.xs,
})

const $verseTouchable: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 44,
  justifyContent: "center",
  borderRadius: 8,
  paddingHorizontal: spacing.xs,
  paddingVertical: spacing.xxs,
})

const $selectedVerse: ThemedStyle<ViewStyle> = ({ colors }) => ({
  borderWidth: 1,
  borderColor: colors.tint,
})

const $passage: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.text,
})

const $verseNum: ThemedStyle<TextStyle> = ({ colors, typography }) => ({
  color: colors.tint,
  fontFamily: typography.primary.medium,
})

const $contextVerse: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  backgroundColor: colors.palette.primary100,
  borderRadius: 8,
  paddingHorizontal: spacing.xs,
  paddingVertical: spacing.xxs,
})

const $selectionToolbar: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  backgroundColor: colors.palette.neutral100,
  borderTopWidth: 1,
  borderTopColor: colors.border,
  paddingHorizontal: spacing.sm,
  paddingTop: spacing.xs,
  paddingBottom: spacing.xs,
  gap: spacing.xxs,
})

const $selectionSummary: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 32,
  flexDirection: "row",
  alignItems: "center",
  justifyContent: "space-between",
  paddingLeft: spacing.xs,
})

const $closeSelection: ThemedStyle<ViewStyle> = () => ({
  width: 44,
  height: 44,
  alignItems: "center",
  justifyContent: "center",
})

const $selectionActions: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  gap: spacing.xxxs,
})

const $selectionAction: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flex: 1,
  minHeight: 44,
  alignItems: "center",
  justifyContent: "center",
  paddingHorizontal: spacing.xxxs,
})

const $actionLabel: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.text,
  textAlign: "center",
})

const $highlightChoices: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  gap: spacing.xs,
})

const $highlightChoice: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  flex: 1,
  minHeight: 44,
  alignItems: "center",
  justifyContent: "center",
  borderRadius: 8,
  borderWidth: 1,
  borderColor: colors.border,
  paddingHorizontal: spacing.xxxs,
})

const $actionFeedback: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
  textAlign: "center",
})

const $chapterNavigation: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  gap: spacing.sm,
  marginTop: spacing.xl,
})

const $chapterNavigationStacked: ThemedStyle<ViewStyle> = () => ({
  flexDirection: "column",
})

const $chapterNavigationSlot: ThemedStyle<ViewStyle> = () => ({ flex: 1 })

const $attribution: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.textDim,
  marginTop: spacing.xl,
})
