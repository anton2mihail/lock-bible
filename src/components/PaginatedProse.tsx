import { useCallback, useEffect, useMemo, useRef, useState } from "react"
import {
  FlatList,
  LayoutChangeEvent,
  NativeSyntheticEvent,
  TextLayoutEventData,
  TextLayoutLine,
  TextStyle,
  View,
  ViewStyle,
} from "react-native"

import { Text } from "@/components/Text"

/** A run of consecutive lines taken from one paragraph. */
type Run = { paragraph: number; from: number; to: number }
export type ProsePage = { key: string; runs: readonly Run[] }

type PaginatedProseProps = {
  paragraphs: readonly string[]
  /** Typography the prose is measured and rendered with; both must match. */
  typography: TextStyle
  /** Gap between paragraphs, counted against the page height. */
  paragraphGap: number
  /** Which page to show. Clamped to the pages that exist. */
  page: number
  onPageChange: (page: number, pageCount: number) => void
  textStyle?: TextStyle
  style?: ViewStyle
}

/**
 * Paginates prose into swipeable pages the way a book does, rather than
 * scrolling it.
 *
 * Every paragraph is measured once, off-screen, with `onTextLayout`, which
 * reports the real line boxes the platform produced. Those lines are then
 * packed into page-height columns. Measuring per paragraph rather than over the
 * whole section is what lets a page break mid-paragraph and still keep the
 * paragraph breaks everywhere else — a single measurement of the joined text
 * would lose them.
 *
 * Measurement depends on the type size and the frame, so both are part of the
 * cache key: changing either repaginates from scratch.
 */
export function PaginatedProse({
  paragraphs,
  typography,
  paragraphGap,
  page,
  onPageChange,
  textStyle,
  style,
}: PaginatedProseProps) {
  const [frame, setFrame] = useState({ width: 0, height: 0 })
  const [lines, setLines] = useState<Record<number, TextLayoutLine[]>>({})
  const listRef = useRef<FlatList<ProsePage>>(null)

  // Remeasure whenever the frame or the typography changes.
  const measureKey = `${frame.width}x${frame.height}:${typography.fontSize}:${typography.lineHeight}:${typography.fontFamily}`
  const lastKey = useRef(measureKey)
  if (lastKey.current !== measureKey) {
    lastKey.current = measureKey
    if (Object.keys(lines).length) setLines({})
  }

  const onFrame = useCallback((event: LayoutChangeEvent) => {
    const { width, height } = event.nativeEvent.layout
    setFrame((current) =>
      Math.abs(current.width - width) < 1 && Math.abs(current.height - height) < 1
        ? current
        : { width, height },
    )
  }, [])

  const onParagraphLayout = useCallback(
    (index: number) => (event: NativeSyntheticEvent<TextLayoutEventData>) => {
      const measured = event.nativeEvent.lines
      setLines((current) => (current[index] ? current : { ...current, [index]: measured }))
    },
    [],
  )

  const measured = Object.keys(lines).length === paragraphs.length && paragraphs.length > 0

  const pages = useMemo<ProsePage[]>(() => {
    if (!measured || frame.height <= 0) return []
    const built: ProsePage[] = []
    let runs: Run[] = []
    let used = 0

    const flush = () => {
      if (runs.length) {
        built.push({ key: `p${built.length}`, runs })
        runs = []
      }
      used = 0
    }

    paragraphs.forEach((_, index) => {
      const paragraphLines = lines[index] ?? []
      if (!paragraphLines.length) return
      const gap = runs.length ? paragraphGap : 0
      let cursor = 0

      while (cursor < paragraphLines.length) {
        const leading = cursor === 0 ? gap : 0
        const available = frame.height - used - leading
        const lineHeight = paragraphLines[cursor].height || (typography.lineHeight ?? 24)
        const fits = Math.max(0, Math.floor(available / lineHeight))

        if (fits === 0) {
          // Nothing more fits on this page. If the page is empty the frame is
          // shorter than a single line, so emit one line rather than loop.
          if (!runs.length && used === 0) {
            runs.push({ paragraph: index, from: cursor, to: cursor + 1 })
            cursor += 1
          }
          flush()
          continue
        }

        const take = Math.min(fits, paragraphLines.length - cursor)
        runs.push({ paragraph: index, from: cursor, to: cursor + take })
        used += leading + take * lineHeight
        cursor += take
        if (cursor < paragraphLines.length) flush()
      }
    })
    flush()
    return built
  }, [measured, frame.height, lines, paragraphs, paragraphGap, typography.lineHeight])

  const pageCount = pages.length
  const clamped = pageCount ? Math.min(Math.max(page, 0), pageCount - 1) : 0

  // Tell the parent as soon as pagination finishes. Without this the only
  // caller of onPageChange is onMomentumScrollEnd, so the page indicator sits
  // at "…" until the reader swipes - on the first page of every section - and
  // a restored position past the new last page is never corrected.
  useEffect(() => {
    if (pageCount) onPageChange(clamped, pageCount)
    // Reporting is owed to a new pagination, not to every scroll.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pageCount])

  const onMomentumEnd = useCallback(
    (event: { nativeEvent: { contentOffset: { x: number } } }) => {
      if (!frame.width || !pageCount) return
      const next = Math.round(event.nativeEvent.contentOffset.x / frame.width)
      if (next !== clamped) onPageChange(next, pageCount)
    },
    [frame.width, pageCount, clamped, onPageChange],
  )

  const renderPage = useCallback(
    ({ item }: { item: ProsePage }) => (
      <View style={{ width: frame.width, height: frame.height }}>
        {item.runs.map((run, i) => {
          const source = lines[run.paragraph] ?? []
          const text = source
            .slice(run.from, run.to)
            .map((line) => line.text)
            .join("")
            .trim()
          const continuing = run.from > 0
          return (
            <Text
              key={`${run.paragraph}-${run.from}`}
              text={text}
              selectable
              style={[
                typography,
                textStyle,
                i > 0 && !continuing ? { marginTop: paragraphGap } : null,
              ]}
            />
          )
        })}
      </View>
    ),
    [frame.width, frame.height, lines, typography, textStyle, paragraphGap],
  )

  return (
    <View style={[$fill, style]} onLayout={onFrame}>
      {/* Off-screen measuring pass. Laid out at the real width so the line
          boxes match what the reader will actually see. */}
      {!measured && frame.width > 0 && (
        <View
          style={[$measuring, { width: frame.width }]}
          pointerEvents="none"
          accessibilityElementsHidden
          importantForAccessibility="no-hide-descendants"
        >
          {paragraphs.map((paragraph, index) => (
            <Text
              key={index}
              text={paragraph}
              onTextLayout={onParagraphLayout(index)}
              style={[typography, textStyle]}
            />
          ))}
        </View>
      )}

      {pageCount > 0 && (
        <FlatList
          ref={listRef}
          data={pages}
          keyExtractor={(item) => item.key}
          renderItem={renderPage}
          horizontal
          pagingEnabled
          showsHorizontalScrollIndicator={false}
          initialScrollIndex={clamped}
          getItemLayout={(_, index) => ({
            length: frame.width,
            offset: frame.width * index,
            index,
          })}
          onMomentumScrollEnd={onMomentumEnd}
          windowSize={3}
          removeClippedSubviews
        />
      )}
    </View>
  )
}

const $fill: ViewStyle = { flex: 1 }
/** The measuring pass is laid out for real but never shown. */
const $measuring: ViewStyle = { position: "absolute", opacity: 0 }
