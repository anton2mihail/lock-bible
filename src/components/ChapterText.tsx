import { Fragment, useMemo, useRef } from "react"
import {
  LayoutChangeEvent,
  NativeSyntheticEvent,
  Platform,
  // Verse spans must inherit the paragraph's Scripture typography; the Text
  // wrapper would reset each one to the base font and size.
  // eslint-disable-next-line no-restricted-imports
  Text as NativeText,
  TextLayoutEventData,
  TextStyle,
  TouchableOpacity,
  View,
  ViewStyle,
} from "react-native"

import {
  layoutChapter,
  LINE_KINDS,
  type Chapter,
  type ChapterBlock,
  type ReaderLayout,
  type TextBlockKind,
  type VerseHeadingKind,
} from "@/services/bible"
import type { HighlightColor } from "@/services/library"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

import { Text } from "./Text"

export const HIGHLIGHT_FILLS: Record<HighlightColor, { light: string; dark: string }> = {
  gold: { light: "#F4D89A", dark: "rgba(244, 216, 154, 0.24)" },
  sage: { light: "#C8D6C0", dark: "rgba(200, 214, 192, 0.24)" },
  rose: { light: "#E6C5C8", dark: "rgba(230, 197, 200, 0.24)" },
  blue: { light: "#C6D5E6", dark: "rgba(198, 213, 230, 0.24)" },
}

export interface ChapterTextProps {
  chapter: Chapter
  layout: ReaderLayout
  /** Scripture typography from useReaderTypography. */
  passageStyle: TextStyle
  selectionRange: [number, number] | null
  /** The passage a link opened, tinted until the reader moves on. */
  contextRange: [number, number] | null
  contextVerse?: string
  highlights: Record<string, HighlightColor>
  onSelectVerse: (verseIndex: number) => void
  /** Where the linked verse begins, measured from the top of this text. */
  onContextVerseY: (y: number) => void
}

/**
 * A chapter set as flowing paragraphs and poetry, or verse by verse. Either
 * way each verse can be tapped to select it and shows its highlight.
 */
export function ChapterText(props: ChapterTextProps) {
  const layout = useMemo(() => layoutChapter(props.chapter), [props.chapter])
  return props.layout === "paragraphs" ? (
    <ParagraphChapter {...props} blocks={layout.blocks} />
  ) : (
    <VerseChapter {...props} verseLayouts={layout.verses} structured={layout.structured} />
  )
}

function useVerseAppearance({
  chapter,
  selectionRange,
  contextRange,
  highlights,
}: Pick<ChapterTextProps, "chapter" | "selectionRange" | "contextRange" | "highlights">) {
  const { theme } = useAppTheme()
  return (verseIndex: number) => {
    const isSelected =
      !!selectionRange && verseIndex >= selectionRange[0] && verseIndex <= selectionRange[1]
    const isInContextRange =
      !!contextRange && verseIndex >= contextRange[0] && verseIndex <= contextRange[1]
    // Selection is drawn as an outline or underline, never a fill, so a
    // highlight's colour shows while its verse is selected.
    const highlightColor = highlights[chapter.verses[verseIndex].n]
    const backgroundColor = highlightColor
      ? theme.isDark
        ? HIGHLIGHT_FILLS[highlightColor].dark
        : HIGHLIGHT_FILLS[highlightColor].light
      : undefined
    return { isSelected, isInContextRange, backgroundColor }
  }
}

interface ContextPosition {
  blocks: ChapterBlock[]
  contextIndex: number
  blockY?: number
  lineY?: number
}

function verseTestId(verseLabel: string, contextVerse: string | undefined) {
  return verseLabel === contextVerse ? "reader-context-verse" : `reader-verse-${verseLabel}`
}

// ---- Paragraphs ------------------------------------------------------------

function ParagraphChapter({ blocks, ...props }: ChapterTextProps & { blocks: ChapterBlock[] }) {
  const { chapter, passageStyle, contextVerse, onSelectVerse, onContextVerseY } = props
  const { themed, theme } = useAppTheme()
  const appearance = useVerseAppearance(props)
  const indent = Math.round((passageStyle.fontSize ?? 18) * 1.25)
  const paragraphGap = Math.round((passageStyle.lineHeight ?? 30) * 0.5)

  // The linked verse sits somewhere inside a block of running text: its line
  // comes from the text layout, the block's position from its own layout.
  const contextIndex = chapter.verses.findIndex((verse) => verse.n === contextVerse)
  const contextBlockIndex = blocks.findIndex(
    (block) =>
      block.type === "text" &&
      block.segments.some((segment) => segment.verseIndex === contextIndex && segment.label),
  )
  // Start over for each chapter and linked verse. This happens during render,
  // not in an effect, which could run after the new blocks' layout events and
  // wipe what they reported.
  const contextPosition = useRef<ContextPosition>({ blocks: [], contextIndex: -1 })
  if (
    contextPosition.current.blocks !== blocks ||
    contextPosition.current.contextIndex !== contextIndex
  ) {
    // The web has no text layout events; its block top is close enough.
    contextPosition.current = {
      blocks,
      contextIndex,
      lineY: Platform.OS === "web" ? 0 : undefined,
    }
  }
  const reportContextPosition = () => {
    const { blockY, lineY } = contextPosition.current
    if (blockY != null && lineY != null) onContextVerseY(blockY + lineY)
  }

  return (
    <>
      {blocks.map((block, index) => {
        if (block.type === "heading") {
          return (
            <ChapterHeading
              key={`h-${index}`}
              kind={block.kind}
              text={block.text}
              passageStyle={passageStyle}
              first={index === 0}
            />
          )
        }

        const previous = blocks[index - 1]
        const lineAfterLine =
          LINE_KINDS.has(block.kind) && previous?.type === "text" && LINE_KINDS.has(previous.kind)
        const marginTop =
          index === 0 || previous?.type === "heading" || (lineAfterLine && !block.stanzaBreak)
            ? 0
            : paragraphGap

        const holdsContext = index === contextBlockIndex
        // Characters before the linked verse's number, for finding its line.
        let contextOffset = 0
        if (holdsContext) {
          for (const [position, segment] of block.segments.entries()) {
            if (segment.verseIndex === contextIndex && segment.label) break
            contextOffset +=
              (position > 0 ? 1 : 0) +
              (segment.label ? segment.label.length + 1 : 0) +
              segment.text.length
          }
          if (contextOffset > 0) contextOffset += 1
        }

        return (
          <View
            key={`b-${index}`}
            style={[{ marginTop }, blockStyle(block.kind, indent)]}
            testID={holdsContext ? "reader-context-block" : undefined}
            onLayout={
              holdsContext
                ? (event: LayoutChangeEvent) => {
                    contextPosition.current.blockY = event.nativeEvent.layout.y
                    reportContextPosition()
                  }
                : undefined
            }
          >
            <NativeText
              style={[themed($passage), passageStyle, lineTextStyle(block.kind)]}
              testID={holdsContext ? "reader-context-block-text" : undefined}
              onTextLayout={
                holdsContext
                  ? (event: NativeSyntheticEvent<TextLayoutEventData>) => {
                      let consumed = 0
                      const lines = event.nativeEvent.lines
                      const line =
                        lines.find((candidate) => {
                          consumed += candidate.text.length
                          return consumed > contextOffset
                        }) ?? lines[lines.length - 1]
                      contextPosition.current.lineY = line?.y ?? 0
                      reportContextPosition()
                    }
                  : undefined
              }
            >
              {block.segments.map((segment, position) => {
                const verse = chapter.verses[segment.verseIndex]
                const { isSelected, isInContextRange, backgroundColor } = appearance(
                  segment.verseIndex,
                )
                return (
                  <Fragment key={`${segment.verseIndex}-${position}`}>
                    {position > 0 && " "}
                    <NativeText
                      onPress={() => onSelectVerse(segment.verseIndex)}
                      testID={segment.label ? verseTestId(verse.n, contextVerse) : undefined}
                      style={[
                        !!backgroundColor && { backgroundColor },
                        isInContextRange &&
                          !backgroundColor && { backgroundColor: theme.colors.palette.primary100 },
                        isSelected && themed($selectedSpan),
                      ]}
                    >
                      {segment.label && (
                        <VerseNumber
                          text={`${segment.label}\u00A0`}
                          lineHeight={passageStyle.lineHeight}
                        />
                      )}
                      {segment.text}
                    </NativeText>
                  </Fragment>
                )
              })}
            </NativeText>
          </View>
        )
      })}
    </>
  )
}

// ---- Verse by verse --------------------------------------------------------

function VerseChapter({
  verseLayouts,
  structured,
  ...props
}: ChapterTextProps & {
  verseLayouts: ReturnType<typeof layoutChapter>["verses"]
  structured: boolean
}) {
  const { chapter, passageStyle, contextVerse, selectionRange, onSelectVerse, onContextVerseY } =
    props
  const { themed } = useAppTheme()
  const appearance = useVerseAppearance(props)
  const indent = Math.round((passageStyle.fontSize ?? 18) * 1.25)

  return (
    <>
      {chapter.verses.map((verse, verseIndex) => {
        const verseLayout = verseLayouts[verseIndex]
        const isContextVerse = verse.n === contextVerse
        const { isSelected, isInContextRange, backgroundColor } = appearance(verseIndex)
        const lines = verseLayout.lines
        const firstLine = lines[0]?.type === "text" ? lines[0] : undefined
        // Set apart the verses that open a prose paragraph or a stanza; in
        // poetry every verse starts a line, which the gap already shows.
        const opensParagraph =
          structured &&
          verseIndex > 0 &&
          verseLayout.startsBlock &&
          verseLayout.headings.length === 0 &&
          !!firstLine &&
          (!LINE_KINDS.has(firstLine.kind) || firstLine.stanzaBreak)
        return (
          <Fragment key={verse.n}>
            {verseLayout.headings.map(([kind, text], index) => (
              <ChapterHeading
                key={`${verse.n}-h-${index}`}
                kind={kind}
                text={text}
                passageStyle={passageStyle}
                first={verseIndex === 0 && index === 0}
              />
            ))}
            <TouchableOpacity
              testID={verseTestId(verse.n, contextVerse)}
              onLayout={
                isContextVerse
                  ? (event: LayoutChangeEvent) => onContextVerseY(event.nativeEvent.layout.y)
                  : undefined
              }
              onPress={() => onSelectVerse(verseIndex)}
              activeOpacity={0.7}
              style={[
                themed($verseTouchable),
                opensParagraph && themed($paragraphStart),
                !!backgroundColor && { backgroundColor },
                isInContextRange && !backgroundColor && themed($contextVerse),
                isSelected && themed($selectedVerse),
              ]}
              accessibilityRole="button"
              accessibilityState={{ selected: isSelected }}
              accessibilityLabel={`Verse ${verse.n}. ${verse.t}`}
              accessibilityHint={
                selectionRange ? "Extends the selected passage to this verse" : "Selects this verse"
              }
            >
              {lines.length > 1 ? (
                lines.map((line, index) =>
                  line.type === "heading" ? (
                    <ChapterHeading
                      key={index}
                      kind={line.kind}
                      text={line.text}
                      passageStyle={passageStyle}
                      first={false}
                    />
                  ) : (
                    <Text
                      key={index}
                      style={[
                        themed($passage),
                        passageStyle,
                        lineTextStyle(line.kind),
                        blockStyle(line.kind, indent),
                        index > 0 && line.stanzaBreak && themed($stanzaBreak),
                      ]}
                    >
                      {index === 0 && (
                        <VerseNumber text={`${verse.n} `} lineHeight={passageStyle.lineHeight} />
                      )}
                      {line.text}
                    </Text>
                  ),
                )
              ) : (
                <Text
                  style={[
                    themed($passage),
                    passageStyle,
                    firstLine && lineTextStyle(firstLine.kind),
                    firstLine && blockStyle(firstLine.kind, indent),
                  ]}
                >
                  <VerseNumber text={`${verse.n} `} lineHeight={passageStyle.lineHeight} />
                  {verse.t}
                </Text>
              )}
            </TouchableOpacity>
          </Fragment>
        )
      })}
    </>
  )
}

// ---- Shared ----------------------------------------------------------------

/**
 * A verse number set small inside its verse. iOS spaces a whole paragraph by
 * the line height of its first character, which is this number, so it takes
 * the passage's line height; the small size's own would pack every line.
 */
function VerseNumber({ text, lineHeight }: { text: string; lineHeight?: number }) {
  const { themed } = useAppTheme()
  return <Text text={text} size="xs" style={[themed($verseNum), { lineHeight }]} />
}

/** Indents for poetry levels, lists and indented paragraphs; centring for pc. */
function blockStyle(kind: TextBlockKind, indent: number): ViewStyle & TextStyle {
  switch (kind) {
    case "q2":
    case "li":
    case "pi":
    case "mi":
      return { paddingLeft: indent }
    case "q3":
      return { paddingLeft: indent * 2 }
    default:
      return {}
  }
}

/** Centred paragraphs. */
function lineTextStyle(kind: TextBlockKind): TextStyle | undefined {
  return kind === "pc" ? { textAlign: "center" } : undefined
}

function ChapterHeading({
  kind,
  text,
  passageStyle,
  first,
}: {
  kind: VerseHeadingKind
  text: string
  passageStyle: TextStyle
  first: boolean
}) {
  const { themed } = useAppTheme()
  const fontSize = passageStyle.fontSize ?? 18
  switch (kind) {
    case "d":
      // Psalm titles belong to the psalm; they read as quieter text, not a header.
      return (
        <Text
          text={text}
          style={[
            themed($psalmTitle),
            {
              fontFamily: passageStyle.fontFamily,
              fontSize: Math.round(fontSize * 0.85),
              lineHeight: Math.round((passageStyle.lineHeight ?? fontSize * 1.6) * 0.85),
            },
          ]}
        />
      )
    case "sp":
      return <Text text={text} size="xs" style={themed([$speaker, first && $firstHeading])} />
    case "ms":
      return (
        <Text
          text={text.toUpperCase()}
          size="xxs"
          weight="semiBold"
          accessibilityRole="header"
          style={themed([$majorSection, first && $firstHeading])}
        />
      )
    default:
      return (
        <Text
          text={text}
          weight="semiBold"
          accessibilityRole="header"
          style={themed([$sectionHeading, first && $firstHeading])}
        />
      )
  }
}

const $passage: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.text,
})

const $verseNum: ThemedStyle<TextStyle> = ({ colors, typography }) => ({
  color: colors.tint,
  fontFamily: typography.primary.medium,
})

const $verseTouchable: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 44,
  justifyContent: "center",
  borderRadius: 8,
  paddingHorizontal: spacing.xs,
  paddingVertical: spacing.xxs,
})

const $paragraphStart: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  marginTop: spacing.sm,
})

const $stanzaBreak: ThemedStyle<TextStyle> = ({ spacing }) => ({
  marginTop: spacing.sm,
})

// With no fill, the outline alone marks the selection, so it is a touch heavier.
const $selectedVerse: ThemedStyle<ViewStyle> = ({ colors }) => ({
  borderWidth: 1.5,
  borderColor: colors.tint,
})

const $selectedSpan: ThemedStyle<TextStyle> = ({ colors }) => ({
  textDecorationLine: "underline",
  textDecorationColor: colors.tint,
})

const $contextVerse: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  backgroundColor: colors.palette.primary100,
  borderRadius: 8,
  paddingHorizontal: spacing.xs,
  paddingVertical: spacing.xxs,
})

const $psalmTitle: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.textDim,
  fontStyle: "italic",
  marginBottom: spacing.xs,
})

const $speaker: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.tint,
  fontStyle: "italic",
  marginTop: spacing.sm,
})

const $majorSection: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.tint,
  letterSpacing: 1.5,
  marginTop: spacing.lg,
  marginBottom: spacing.xs,
})

const $sectionHeading: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.text,
  marginTop: spacing.lg,
  marginBottom: spacing.xs,
})

const $firstHeading: ThemedStyle<TextStyle> = () => ({
  marginTop: 0,
})
