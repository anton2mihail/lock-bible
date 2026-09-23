import { FC, useCallback, useEffect, useMemo, useRef, useState } from "react"
import {
  AccessibilityInfo,
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
import { useFocusEffect, useLocalSearchParams, useRouter } from "expo-router"
import { Feather } from "@expo/vector-icons"
import type { KeyboardAwareScrollViewRef } from "react-native-keyboard-controller"

import { Button } from "@/components/Button"
import { ChapterGrid } from "@/components/ChapterGrid"
import { ChapterText } from "@/components/ChapterText"
import { Icon } from "@/components/Icon"
import { ListItem } from "@/components/ListItem"
import { Screen } from "@/components/Screen"
import { SelectionToolbar } from "@/components/SelectionToolbar"
import { Text } from "@/components/Text"
import { TextSettingsSheet } from "@/components/TextSettingsSheet"
import {
  dismissSelectionHint,
  getBook,
  getReaderLayout,
  getReaderLocation,
  getTranslation,
  getTranslationId,
  isSelectionHintDismissed,
  listBooks,
  setReaderLocation,
  type BookGroup,
  type BookMeta,
  useReadingPreference,
  type ReaderLayout,
  type ReaderLocation,
} from "@/services/bible"
import { useLibraryDatabase } from "@/services/database"
import {
  applyHighlight,
  clearHighlight,
  createPassageSelection,
  getChapterHighlights,
  isPassageBookmarked,
  passageReference,
  toggleBookmark,
  type HighlightColor,
} from "@/services/library"
import { COLLECTIONS, getChapterCommentary, getCollection, plural, WORKS } from "@/services/works"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"
import { useReaderTypography, useReadingColumn } from "@/theme/useReaderTypography"
import { useScreenReaderEnabled } from "@/utils/useScreenReaderEnabled"

const GROUP_LABELS: Record<BookGroup, string> = {
  ot: "Old Testament",
  deutero: "Deuterocanon",
  nt: "New Testament",
}

/** Most chapters have one to four homilies; a couple have twenty. */
const COMMENTARY_PREVIEW = 3

type Mode = "books" | "chapters" | "verses"

interface PassageTarget {
  book: BookMeta
  chapter: number
}

export const ReaderScreen: FC = function ReaderScreen() {
  const { themed, theme } = useAppTheme()
  const libraryDatabase = useLibraryDatabase()
  const router = useRouter()
  const { fontScale, width, height } = useWindowDimensions()
  const stackChapterNavigation = width < 360 || fontScale > 1.25
  const params = useLocalSearchParams<{
    book?: string
    chapter?: string
    verse?: string
    endVerse?: string
    contextRequest?: string
  }>()
  // Settings can switch the translation while this tab stays mounted, so the
  // tab re-reads it whenever it regains focus. Text and layout preferences
  // update on their own, including from the Aa sheet over this screen.
  const [translationId, setShownTranslationId] = useState(getTranslationId)
  useFocusEffect(
    useCallback(() => {
      setShownTranslationId(getTranslationId())
    }, []),
  )
  const layoutPreference = useReadingPreference(getReaderLayout)
  const books = useMemo(() => listBooks(translationId), [translationId])
  const meta = getTranslation(translationId).meta
  // Running text can't give each verse its own element, so screen readers
  // always get the chapter verse by verse.
  const screenReaderEnabled = useScreenReaderEnabled()
  const readerLayout: ReaderLayout = screenReaderEnabled ? "verses" : layoutPreference

  // Opening the Read tab returns to the chapter the reader left, where they
  // left it. A link that names a passage (widget, search, Read in context)
  // takes precedence, and the book list stays one step back.
  const [resume] = useState(() => {
    if (params.book) return undefined
    const location = getReaderLocation()
    const savedBook = location && books.find((candidate) => candidate.code === location.book)
    if (!location || !savedBook || location.chapter > savedBook.chapterCount) return undefined
    return { book: savedBook, chapter: location.chapter, scrollY: location.scrollY }
  })

  const initialBook = params.book
    ? books.find((candidate) => candidate.code === params.book)
    : resume?.book
  const initialChapter = params.chapter ? Number(params.chapter) : resume?.chapter

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
  const [selectionBookmarked, setSelectionBookmarked] = useState(false)
  const [actionFeedback, setActionFeedback] = useState("")
  const [showSelectionHint, setShowSelectionHint] = useState(() => !isSelectionHintDismissed())
  const [textSettingsOpen, setTextSettingsOpen] = useState(false)

  const scrollViewRef = useRef<KeyboardAwareScrollViewRef>(null)
  const pendingOffsetRef = useRef<number | null>(resume?.scrollY ?? null)
  const verseBlockYRef = useRef<number | null>(null)
  const contextVerseYRef = useRef<number | null>(null)
  const contextScrollCompletedRef = useRef(false)
  const chapterListRef = useRef<View>(null)
  const currentChapterCellRef = useRef<View>(null)

  // A translation switch reaches this tab through `books`: swap the open book
  // for the new edition's entry, or step back when that edition lacks the book
  // or chapter. The ref limits this to actual switches, not every navigation.
  const booksShownRef = useRef(books)
  useEffect(() => {
    if (booksShownRef.current === books) return
    booksShownRef.current = books
    setSelectionRange(null)
    setActionFeedback("")
    const nextBook = book && books.find((candidate) => candidate.code === book.code)
    if (!nextBook) {
      setBook(undefined)
      setChapter(undefined)
      setMode("books")
      return
    }
    setBook(nextBook)
    if (chapter != null && chapter > nextBook.chapterCount) {
      setChapter(undefined)
      setMode("chapters")
    }
  }, [book, books, chapter])

  const selectedChapter = useMemo(() => {
    if (!book || chapter == null) return undefined
    // For one render after a switch, `book` can belong to the old edition.
    if (!books.some((candidate) => candidate.code === book.code)) return undefined
    return getBook(book.code, translationId).chapters.find((candidate) => candidate.c === chapter)
  }, [book, books, chapter, translationId])

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

  // The toolbar shows whether the selected passage is already bookmarked, so
  // tapping Bookmark again is a visible removal rather than a silent one.
  useEffect(() => {
    if (!selectedPassage) {
      setSelectionBookmarked(false)
      return
    }
    let active = true
    isPassageBookmarked(libraryDatabase, selectedPassage)
      .then((bookmarked) => {
        if (active) setSelectionBookmarked(bookmarked)
      })
      .catch(() => {})
    return () => {
      active = false
    }
  }, [libraryDatabase, selectedPassage])

  // The colour every selected verse shares, and whether any has one at all.
  const selectionHighlight = useMemo(() => {
    const colors = selectedPassage?.verses.map((verse) => chapterHighlights[verse.verse]) ?? []
    const shared = colors[0] && colors.every((color) => color === colors[0]) ? colors[0] : undefined
    return { color: shared, any: colors.some(Boolean) }
  }, [chapterHighlights, selectedPassage])

  // Toolbar results are shown for sight and spoken for VoiceOver, which does
  // not read iOS live regions.
  const announce = useCallback((message: string) => {
    setActionFeedback(message)
    AccessibilityInfo.announceForAccessibility(message)
  }, [])

  const passageStyle = useReaderTypography()
  const readingColumn = useReadingColumn(theme.spacing.lg)

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
      setActionFeedback("")
      setShowSelectionHint(!isSelectionHintDismissed())
      setMode("verses")
      rememberLocation(targetBook, targetChapter, scrollY)
    },
    [rememberLocation],
  )

  // Tab screens remain mounted, so useState's initializer does not run again
  // when a widget or “Read in context” selects the existing Read tab. The book
  // list is read here rather than depended on, so a translation switch does not
  // replay the last request and jump back to its passage.
  useEffect(() => {
    if (!params.book) return
    const requestedBook = listBooks().find((candidate) => candidate.code === params.book)
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

  // Stepping back from a chapter deep in a long book (the Psalms run to 150)
  // opens the grid around it, a third of the way down, rather than at 1.
  const revealCurrentChapter = useCallback(() => {
    const cell = currentChapterCellRef.current
    const list = chapterListRef.current
    if (!cell || !list) return
    cell.measureLayout(
      list,
      (_x, y) => scrollToOffset(y - height / 3, false),
      () => {},
    )
  }, [height, scrollToOffset])

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

  const onContextVerseY = useCallback(
    (y: number) => {
      contextVerseYRef.current = y
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

  // The chapter title opens the book and chapter picker, marked where the reader is.
  const openGoTo = useCallback(() => {
    if (!book) return
    router.push({
      pathname: "/go-to",
      params: chapter != null ? { book: book.code, chapter: String(chapter) } : { book: book.code },
    })
  }, [book, chapter, router])

  // What the Fathers wrote on the chapter in front of the reader. Empty for the
  // books none of them expounded, which is most of the Old Testament.
  const commentary = useMemo(() => getChapterCommentary(book?.code, chapter), [book, chapter])

  // One Father gets his name in the heading and nowhere else; several share a
  // collective heading and are told apart on each row instead.
  const { commentaryHeading, nameAuthorPerRow } = useMemo(() => {
    const authors = new Set(commentary.map((entry) => entry.collectionId))
    const only = authors.size === 1 ? getCollection(commentary[0]?.collectionId) : undefined
    return {
      commentaryHeading: only ? `${only.author} on this chapter` : "The Fathers on this chapter",
      nameAuthorPerRow: authors.size > 1,
    }
  }, [commentary])

  const openCommentary = useCallback(
    (workId: string, sectionIndex: number) =>
      router.push({
        pathname: "/works/[id]",
        params: { id: workId, section: String(sectionIndex) },
      }),
    [router],
  )

  const selectVerse = useCallback((verseIndex: number) => {
    if (!isSelectionHintDismissed()) dismissSelectionHint()
    setActionFeedback("")
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
      announce("Passage copied")
    } catch {
      announce("Passage could not be copied")
    }
  }, [announce, meta.abbreviation, selectedPassage])

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
      announce("Share sheet could not be opened")
    }
  }, [announce, meta.abbreviation, selectedPassage])

  const bookmarkSelection = useCallback(async () => {
    if (!selectedPassage) return
    try {
      const saved = await toggleBookmark(libraryDatabase, selectedPassage)
      setSelectionBookmarked(saved)
      announce(saved ? "Bookmark saved" : "Bookmark removed")
    } catch {
      announce("Bookmark could not be updated")
    }
  }, [announce, libraryDatabase, selectedPassage])

  const highlightSelection = useCallback(
    async (color: HighlightColor) => {
      if (!selectedPassage) return
      try {
        await applyHighlight(libraryDatabase, selectedPassage, color)
        setChapterHighlights((current) => ({
          ...current,
          ...Object.fromEntries(selectedPassage.verses.map((verse) => [verse.verse, color])),
        }))
        announce(`${color[0].toUpperCase() + color.slice(1)} highlight applied`)
      } catch {
        announce("Highlight could not be updated")
      }
    },
    [announce, libraryDatabase, selectedPassage],
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
      announce("Highlight removed")
    } catch {
      announce("Highlight could not be updated")
    }
  }, [announce, libraryDatabase, selectedPassage])

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
        <View style={themed($continueSection)}>
          <Text text="The Church Fathers" preset="formLabel" style={themed($sectionHeader)} />
          <View style={themed($continueSurface)}>
            <ListItem
              text={
                COLLECTIONS.length === 1
                  ? `${COLLECTIONS[0].author} · ${WORKS.length} works`
                  : `${COLLECTIONS.length} authors · ${WORKS.length} works`
              }
              rightIcon="caretRight"
              onPress={() => router.push("/works")}
              testID="read-church-fathers"
              accessibilityRole="button"
              accessibilityLabel={`The Fathers and Doctors. ${WORKS.length} works, available offline.`}
            />
          </View>
        </View>
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
              accessibilityLabel={`${item.name}, ${plural(item.chapterCount, "chapter")}`}
              bottomSeparator
            />
          )}
        />
      </Screen>
    )
  }

  if (mode === "chapters" && book) {
    return (
      <Screen
        preset="scroll"
        safeAreaEdges={["top"]}
        contentContainerStyle={[themed($padded), readingColumn]}
        scrollViewRef={scrollViewRef}
      >
        <View ref={chapterListRef}>
          <ReaderHeader
            title={book.name}
            backLabel="Back to books"
            onBack={goBack}
            onTitlePress={openGoTo}
            onSearch={openSearch}
            themed={themed}
            tint={theme.colors.text}
            accent={theme.colors.tint}
          />
          <ChapterGrid
            bookName={book.name}
            chapterCount={book.chapterCount}
            currentChapter={chapter}
            onSelect={openChapter}
            currentChapterRef={currentChapterCellRef}
            onCurrentChapterLayout={revealCurrentChapter}
          />
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
          contentContainerStyle={[
            themed([$padded, selectionRange && $paddedWithToolbar]),
            readingColumn,
          ]}
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
            onTitlePress={openGoTo}
            onTextSettings={() => setTextSettingsOpen(true)}
            onSearch={openSearch}
            themed={themed}
            tint={theme.colors.text}
            accent={theme.colors.tint}
          />
          {showSelectionHint && (
            <Text
              text="Tap a verse to select it. Tap another verse to select a range."
              size="xxs"
              style={themed($selectionHint)}
            />
          )}
          <View
            testID="reader-verse-block"
            style={themed([$verseBlock, readerLayout === "paragraphs" && $verseBlockFlowing])}
            onLayout={onVerseBlockLayout}
          >
            {selectedChapter && (
              <ChapterText
                chapter={selectedChapter}
                layout={readerLayout}
                passageStyle={passageStyle}
                selectionRange={selectionRange}
                contextRange={contextRange}
                contextVerse={contextVerse}
                highlights={chapterHighlights}
                onSelectVerse={selectVerse}
                onContextVerseY={onContextVerseY}
              />
            )}
          </View>

          {commentary.length > 0 && (
            <View style={themed($continueSection)}>
              <Text text={commentaryHeading} preset="formLabel" style={themed($sectionHeader)} />
              <View style={themed($continueSurface)}>
                {commentary.slice(0, COMMENTARY_PREVIEW).map((homily) => (
                  <ListItem
                    key={`${homily.workId}-${homily.sectionIndex}`}
                    text={
                      nameAuthorPerRow
                        ? `${homily.sectionTitle} · ${getCollection(homily.collectionId)?.author ?? ""}`
                        : homily.sectionTitle
                    }
                    rightIcon="caretRight"
                    onPress={() => openCommentary(homily.workId, homily.sectionIndex)}
                    accessibilityRole="button"
                    accessibilityLabel={`${homily.sectionTitle}, ${homily.workTitle}`}
                  />
                ))}
                {commentary.length > COMMENTARY_PREVIEW && (
                  <ListItem
                    text={`All ${commentary.length} readings on this chapter`}
                    rightIcon="caretRight"
                    onPress={() =>
                      router.push({
                        pathname: "/commentary/[book]/[chapter]",
                        params: { book: book?.code ?? "", chapter: String(chapter ?? 1) },
                      })
                    }
                    accessibilityRole="button"
                  />
                )}
              </View>
            </View>
          )}

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
                  onPress={() => openPassage(previousPassage.book, previousPassage.chapter)}
                  accessibilityLabel={`Previous chapter, ${previousPassage.book.name} chapter ${previousPassage.chapter}`}
                />
              )}
            </View>
            <View style={themed($chapterNavigationSlot)}>
              {nextPassage && (
                <Button
                  text={`Next\n${nextPassage.book.name} ${nextPassage.chapter}`}
                  preset="reversed"
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
            highlightColor={selectionHighlight.color}
            highlighted={selectionHighlight.any}
            bookmarked={selectionBookmarked}
            feedback={actionFeedback}
            onClose={() => {
              setSelectionRange(null)
              setActionFeedback("")
            }}
            onCopy={copySelection}
            onShare={shareSelection}
            onBookmark={bookmarkSelection}
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

        <TextSettingsSheet visible={textSettingsOpen} onClose={() => setTextSettingsOpen(false)} />
      </View>
    )
  }

  return null
}

interface ReaderHeaderProps {
  title: string
  backLabel: string
  onBack: () => void
  /** The title opens the book and chapter picker. */
  onTitlePress: () => void
  /** Adds the Aa button, for text size, spacing and typeface. */
  onTextSettings?: () => void
  onSearch?: () => void
  themed: ReturnType<typeof useAppTheme>["themed"]
  tint: string
  accent: string
}

function ReaderHeader({
  title,
  backLabel,
  onBack,
  onTitlePress,
  onTextSettings,
  onSearch,
  themed,
  tint,
  accent,
}: ReaderHeaderProps) {
  return (
    <View style={themed($readerHeader)}>
      <View style={themed($readerToolbar)}>
        <TouchableOpacity
          onPress={onBack}
          style={themed($backButton)}
          accessibilityRole="button"
          accessibilityLabel={backLabel}
          hitSlop={8}
        >
          <Icon icon="caretLeft" size={24} color={tint} />
        </TouchableOpacity>
        <View style={themed($readerActions)}>
          {onTextSettings && (
            <TouchableOpacity
              onPress={onTextSettings}
              style={themed($headerIconButton)}
              accessibilityRole="button"
              accessibilityLabel="Text settings"
              testID="reader-text-settings"
            >
              <Text
                text="Aa"
                size="md"
                weight="semiBold"
                maxFontSizeMultiplier={1.4}
                style={themed($searchButtonText)}
              />
            </TouchableOpacity>
          )}
          {onSearch && (
            <TouchableOpacity
              onPress={onSearch}
              style={themed($headerIconButton)}
              accessibilityRole="button"
              accessibilityLabel="Search Scripture"
            >
              <Feather name="search" size={22} color={accent} />
            </TouchableOpacity>
          )}
        </View>
      </View>
      {/* The title has a line to itself, so even "1 Thessalonians 5" fits. It
          grows only so far with the system text size, like iOS's large titles:
          iOS lays a shrunk-to-fit title out at its unshrunk height, so a much
          larger one would open a gap above the text. */}
      <TouchableOpacity
        onPress={onTitlePress}
        style={themed($titleButton)}
        accessibilityRole="button"
        accessibilityLabel={title}
        accessibilityHint="Choose another book or chapter"
        testID="reader-title"
      >
        <Text
          text={title}
          preset="heading"
          numberOfLines={1}
          adjustsFontSizeToFit
          minimumFontScale={0.6}
          maxFontSizeMultiplier={1.4}
          style={themed($titleButtonText)}
        />
        <Feather name="chevron-down" size={22} color={tint} />
      </TouchableOpacity>
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
  paddingTop: spacing.xs,
  paddingBottom: spacing.xxs,
})

const $readerToolbar: ThemedStyle<ViewStyle> = () => ({
  minHeight: 44,
  flexDirection: "row",
  alignItems: "center",
  justifyContent: "space-between",
})

const $readerActions: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  alignItems: "center",
  // Brings the last icon, not its touch target, to the text's right edge.
  marginRight: -spacing.xs,
})

const $backButton: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minWidth: 44,
  minHeight: 44,
  alignItems: "flex-start",
  justifyContent: "center",
  paddingRight: spacing.xs,
})

const $titleButton: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  alignSelf: "flex-start",
  maxWidth: "100%",
  minHeight: 44,
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.xxs,
})

const $titleButtonText: ThemedStyle<TextStyle> = () => ({ flexShrink: 1 })

const $headerIconButton: ThemedStyle<ViewStyle> = () => ({
  minWidth: 44,
  minHeight: 44,
  alignItems: "center",
  justifyContent: "center",
})

const $verseBlock: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  marginTop: spacing.sm,
  gap: spacing.xs,
})

// Paragraphs and poetry lines carry their own spacing.
const $verseBlockFlowing: ThemedStyle<ViewStyle> = () => ({
  gap: 0,
})

const $selectionHint: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.textDim,
  marginBottom: spacing.xs,
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
