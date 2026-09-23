import { FC, useCallback, useEffect, useMemo, useState } from "react"
import {
  ActivityIndicator,
  FlatList,
  Modal,
  Pressable,
  TextStyle,
  useWindowDimensions,
  View,
  ViewStyle,
} from "react-native"
import { useRouter } from "expo-router"

import { PaginatedProse } from "@/components/PaginatedProse"
import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import { useWorksDatabase, useWorksDatabaseState } from "@/services/database"
import {
  getCollection,
  getReadingPosition,
  getWorkMeta,
  loadSection,
  loadSectionTitles,
  saveReadingPosition,
  WORK_SECTION_NOUN,
  type WorkSection,
} from "@/services/works"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"
import { useReaderTypography, useReadingColumn } from "@/theme/useReaderTypography"

const PARAGRAPH_GAP = 14
/** Contents titles wrap to two lines of the `sm` text size. */
const CONTENTS_TITLE_LINE_HEIGHT = 24
/**
 * The reader's own labels and controls stop growing here. Uncapped, at the
 * largest text sizes they took most of the screen, and the pages between them
 * held a word or two.
 */
const CHROME_TEXT_SCALE = 1.5

type WorkReaderScreenProps = {
  workId?: string
  /** Section to open at; falls back to wherever the reader left off. */
  section?: string
}

export const WorkReaderScreen: FC<WorkReaderScreenProps> = function WorkReaderScreen({
  workId,
  section,
}) {
  const { themed, theme } = useAppTheme()
  const router = useRouter()
  const typography = useReaderTypography()
  const readingColumn = useReadingColumn(theme.spacing.lg)
  const { fontScale } = useWindowDimensions()
  // Rows keep one height so the contents can open at the current section, but
  // that height follows the text size so a two-line title is never clipped.
  const contentsRowHeight = Math.max(56, Math.ceil(CONTENTS_TITLE_LINE_HEIGHT * 2 * fontScale + 8))
  const database = useWorksDatabase()
  const databaseState = useWorksDatabaseState()

  const meta = getWorkMeta(workId)
  const collection = getCollection(meta?.collectionId)

  const saved = useMemo(() => (meta ? getReadingPosition(meta.id) : undefined), [meta])
  const requested = section !== undefined ? Number(section) : undefined
  const [sectionIndex, setSectionIndex] = useState(() => {
    const start = Number.isInteger(requested) ? (requested as number) : (saved?.sectionIndex ?? 0)
    return Math.max(0, start)
  })
  const [page, setPage] = useState(() =>
    Number.isInteger(requested) ? 0 : (saved?.pageIndex ?? 0),
  )
  const [pageCount, setPageCount] = useState(0)
  const [current, setCurrent] = useState<WorkSection | undefined>(undefined)
  const [missing, setMissing] = useState(false)
  const [contentsOpen, setContentsOpen] = useState(false)
  const [contents, setContents] = useState<readonly { index: number; title: string }[]>([])

  // The text now comes from SQLite, one section at a time. Clearing first keeps
  // the previous homily from flashing under the new title while it loads.
  useEffect(() => {
    if (!meta) return
    if (databaseState === "failed") {
      setMissing(true)
      return
    }
    // Still copying on first open; the spinner stands until it lands.
    if (!database) return
    let cancelled = false
    setCurrent(undefined)
    setMissing(false)
    loadSection(database, meta.id, sectionIndex)
      .then((loaded) => {
        if (cancelled) return
        if (loaded) setCurrent(loaded)
        else setMissing(true)
      })
      .catch(() => {
        // A spinner that never resolves reads as a hang; say so instead.
        if (!cancelled) setMissing(true)
      })
    return () => {
      cancelled = true
    }
  }, [database, databaseState, meta, sectionIndex])

  const openContents = useCallback(() => {
    setContentsOpen(true)
    if (contents.length || !meta || !database) return
    loadSectionTitles(database, meta.id)
      .then(setContents)
      .catch(() => setContents([]))
  }, [contents.length, database, meta])

  const onPageChange = useCallback(
    (next: number, total: number) => {
      setPage(next)
      setPageCount(total)
      if (meta) saveReadingPosition(meta.id, sectionIndex, next)
    },
    [meta, sectionIndex],
  )

  const goToSection = useCallback(
    (next: number) => {
      if (!meta) return
      const clamped = Math.max(0, Math.min(next, meta.sectionCount - 1))
      setSectionIndex(clamped)
      setPage(0)
      setPageCount(0)
      saveReadingPosition(meta.id, clamped, 0)
    },
    [meta],
  )

  if (!meta) {
    return (
      <Screen preset="fixed" safeAreaEdges={["top"]} contentContainerStyle={themed($missing)}>
        <Text text="That work isn’t available" preset="subheading" />
        <Pressable onPress={() => router.back()} accessibilityRole="button" hitSlop={8}>
          <Text text="Go back" size="sm" style={themed($tint)} />
        </Pressable>
      </Screen>
    )
  }

  const noun = WORK_SECTION_NOUN[meta.kind] ?? "section"
  const atFirst = sectionIndex === 0
  const atLast = sectionIndex >= meta.sectionCount - 1

  return (
    <Screen
      preset="fixed"
      safeAreaEdges={["top", "bottom"]}
      contentContainerStyle={[themed($screen), readingColumn]}
    >
      <View style={themed($topBar)}>
        <Pressable
          onPress={() => router.back()}
          accessibilityRole="button"
          accessibilityLabel="Close the reader"
          hitSlop={10}
          style={({ pressed }) => themed([$closeButton, pressed && $pressed])}
        >
          {/* A glyph standing in for an icon: past this it no longer fits the
              circle, and iOS draws nothing rather than a clipped cross. */}
          <Text text="×" size="xl" maxFontSizeMultiplier={1.4} style={themed($tint)} />
        </Pressable>
        <View style={$titleCopy}>
          <Text
            text={current?.title ?? meta.title}
            size="xs"
            weight="semiBold"
            numberOfLines={1}
            maxFontSizeMultiplier={CHROME_TEXT_SCALE}
          />
          {/* A one-section work names its only section after itself; saying it twice reads as a bug. */}
          {current && current.title !== meta.title && (
            <Text
              text={meta.title}
              size="xxs"
              style={themed($dim)}
              numberOfLines={1}
              maxFontSizeMultiplier={CHROME_TEXT_SCALE}
            />
          )}
        </View>
        <Text
          text={pageCount ? `${page + 1}/${pageCount}` : "…"}
          accessibilityLabel={pageCount ? `Page ${page + 1} of ${pageCount}` : "Loading pages"}
          size="xxs"
          weight="semiBold"
          maxFontSizeMultiplier={CHROME_TEXT_SCALE}
          style={themed([$tint, $tabular])}
        />
      </View>

      {current ? (
        <PaginatedProse
          // Remounting per section keeps each one's measurement pass independent.
          key={`${meta.id}:${sectionIndex}`}
          paragraphs={current.paragraphs}
          typography={typography}
          paragraphGap={PARAGRAPH_GAP}
          page={page}
          onPageChange={onPageChange}
          textStyle={{ color: theme.colors.text }}
          style={themed($prose)}
        />
      ) : (
        <View style={themed($loading)}>
          {missing ? (
            <Text
              text={
                databaseState === "failed"
                  ? "The library could not be opened on this device"
                  : "That section could not be opened"
              }
              size="sm"
              style={themed($dim)}
            />
          ) : (
            <ActivityIndicator color={theme.colors.tint} />
          )}
        </View>
      )}

      <View style={themed($footer)}>
        <Pressable
          onPress={() => goToSection(sectionIndex - 1)}
          disabled={atFirst}
          accessibilityRole="button"
          accessibilityLabel={`Previous ${noun}`}
          accessibilityState={{ disabled: atFirst }}
          hitSlop={8}
          style={({ pressed }) => themed([$step, pressed && $pressed])}
        >
          <Text
            text="‹"
            size="lg"
            maxFontSizeMultiplier={CHROME_TEXT_SCALE}
            style={themed(atFirst ? $disabled : $tint)}
          />
        </Pressable>

        <Pressable
          onPress={openContents}
          disabled={meta.sectionCount < 2}
          accessibilityRole="button"
          accessibilityLabel={`Contents, ${noun} ${sectionIndex + 1} of ${meta.sectionCount}`}
          hitSlop={10}
          style={({ pressed }) => themed([$contentsButton, pressed && $pressed])}
        >
          <Text
            text={`${sectionIndex + 1} of ${meta.sectionCount}`}
            size="xxs"
            maxFontSizeMultiplier={CHROME_TEXT_SCALE}
            style={themed([meta.sectionCount < 2 ? $dim : $tint, $tabular])}
          />
        </Pressable>

        <Pressable
          onPress={() => goToSection(sectionIndex + 1)}
          disabled={atLast}
          accessibilityRole="button"
          accessibilityLabel={`Next ${noun}`}
          accessibilityState={{ disabled: atLast }}
          hitSlop={8}
          style={({ pressed }) => themed([$step, pressed && $pressed])}
        >
          <Text
            text="›"
            size="lg"
            maxFontSizeMultiplier={CHROME_TEXT_SCALE}
            style={themed(atLast ? $disabled : $tint)}
          />
        </Pressable>
      </View>

      {collection && (
        <Text
          text={collection.translation}
          size="xxs"
          maxFontSizeMultiplier={CHROME_TEXT_SCALE}
          style={themed($attribution)}
        />
      )}

      {/* Some works run to a thousand sections; stepping there one arrow at a
          time is not navigation. Titles only - the query skips the text. */}
      <Modal
        visible={contentsOpen}
        animationType="slide"
        onRequestClose={() => setContentsOpen(false)}
        presentationStyle="pageSheet"
      >
        <View style={themed($sheet)}>
          <View style={themed($sheetBar)}>
            <Text
              text={meta.title}
              size="xs"
              weight="semiBold"
              numberOfLines={1}
              style={$flexText}
            />
            <Pressable
              onPress={() => setContentsOpen(false)}
              accessibilityRole="button"
              accessibilityLabel="Close contents"
              hitSlop={10}
            >
              <Text text="Done" size="sm" weight="semiBold" style={themed($tint)} />
            </Pressable>
          </View>
          <FlatList
            data={contents}
            keyExtractor={(item) => String(item.index)}
            initialScrollIndex={Math.min(sectionIndex, Math.max(contents.length - 1, 0))}
            getItemLayout={(_, index) => ({
              length: contentsRowHeight,
              offset: contentsRowHeight * index,
              index,
            })}
            ListEmptyComponent={
              <View style={themed($loading)}>
                <ActivityIndicator color={theme.colors.tint} />
              </View>
            }
            renderItem={({ item }) => (
              <Pressable
                onPress={() => {
                  setContentsOpen(false)
                  goToSection(item.index)
                }}
                accessibilityRole="button"
                accessibilityState={{ selected: item.index === sectionIndex }}
                style={({ pressed }) => [
                  themed([$sheetRow, pressed && $pressed]),
                  { height: contentsRowHeight },
                ]}
              >
                <Text
                  text={`${item.index + 1}.`}
                  size="xxs"
                  style={themed([$dim, $tabular, $sheetNumber])}
                />
                <Text
                  text={item.title}
                  size="sm"
                  weight={item.index === sectionIndex ? "semiBold" : "normal"}
                  numberOfLines={2}
                  style={$flexText}
                />
              </Pressable>
            )}
          />
        </View>
      </Modal>
    </Screen>
  )
}

const $screen: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flex: 1,
  paddingHorizontal: spacing.lg,
  paddingTop: spacing.xs,
  paddingBottom: spacing.xs,
})
const $missing: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flex: 1,
  alignItems: "center",
  justifyContent: "center",
  gap: spacing.sm,
})
const $topBar: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 44,
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.sm,
})
const $closeButton: ThemedStyle<ViewStyle> = ({ colors }) => ({
  width: 40,
  height: 40,
  borderRadius: 20,
  alignItems: "center",
  justifyContent: "center",
  backgroundColor: colors.palette.neutral100,
})
const $prose: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flex: 1,
  marginTop: spacing.sm,
})
const $loading: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flex: 1,
  alignItems: "center",
  justifyContent: "center",
  marginTop: spacing.sm,
})
const $footer: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  minHeight: 44,
  flexDirection: "row",
  alignItems: "center",
  justifyContent: "space-between",
  borderTopWidth: 1,
  borderTopColor: colors.separator,
  paddingTop: spacing.xs,
})
const $step: ThemedStyle<ViewStyle> = () => ({
  minWidth: 44,
  minHeight: 44,
  alignItems: "center",
  justifyContent: "center",
})
const $attribution: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.textDim,
  textAlign: "center",
  paddingTop: spacing.xxs,
})
const $tint: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint })
const $dim: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })
const $disabled: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.border })
const $pressed: ThemedStyle<ViewStyle> = () => ({ opacity: 0.6 })
const $titleCopy: ViewStyle = { flex: 1, alignItems: "center" }
const $tabular: TextStyle = { fontVariant: ["tabular-nums"] }
const $contentsButton: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 44,
  justifyContent: "center",
  paddingHorizontal: spacing.sm,
})
const $sheet: ThemedStyle<ViewStyle> = ({ colors }) => ({
  flex: 1,
  backgroundColor: colors.background,
})
const $sheetBar: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  minHeight: 52,
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.md,
  paddingHorizontal: spacing.lg,
  borderBottomWidth: 1,
  borderBottomColor: colors.separator,
})
const $sheetRow: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.sm,
  paddingHorizontal: spacing.lg,
  borderBottomWidth: 1,
  borderBottomColor: colors.separator,
})
const $sheetNumber: TextStyle = { minWidth: 34 }
const $flexText: TextStyle = { flex: 1 }
