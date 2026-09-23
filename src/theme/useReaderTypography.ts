import { useMemo } from "react"
import { Platform, TextStyle, useWindowDimensions, ViewStyle } from "react-native"

import {
  getReaderLineSpacing,
  getReaderTextSize,
  getReaderTypeface,
  useReadingPreference,
  type ReaderLineSpacing,
  type ReaderTextSize,
} from "@/services/bible"

import { useAppTheme } from "./context"

const READER_FONT_SIZES: Record<ReaderTextSize, number> = {
  small: 16,
  medium: 18,
  large: 21,
  extraLarge: 24,
}

const READER_LINE_HEIGHTS: Record<ReaderLineSpacing, number> = {
  compact: 1.45,
  comfortable: 1.67,
  relaxed: 1.9,
}

const READER_SERIF_FONT = Platform.select({
  ios: "Georgia",
  android: "serif",
  default: "serif",
})

/** About 65 to 70 characters of text at the reader's chosen size. */
const READING_MEASURE_EMS = 34

/** Shared Scripture typography for the Bible reader and daily-reading passages. */
export function useReaderTypography(): TextStyle {
  const { theme } = useAppTheme()
  const textSize = useReadingPreference(getReaderTextSize)
  const lineSpacing = useReadingPreference(getReaderLineSpacing)
  const typeface = useReadingPreference(getReaderTypeface)
  return useMemo(() => {
    const fontSize = READER_FONT_SIZES[textSize]
    return {
      fontFamily: typeface === "serif" ? READER_SERIF_FONT : theme.typography.primary.normal,
      fontSize,
      lineHeight: Math.round(fontSize * READER_LINE_HEIGHTS[lineSpacing]),
    }
  }, [textSize, lineSpacing, typeface, theme.typography])
}

/**
 * Keeps lines of reading text a comfortable length on an iPad, where a
 * full-width column runs to 150 characters. The column widens with the text
 * size, so larger text keeps the same words per line; phones are narrower than
 * the cap and unaffected. Pass the horizontal padding of the view it styles.
 */
export function useReadingColumn(horizontalPadding = 0): ViewStyle {
  const { fontSize = READER_FONT_SIZES.medium } = useReaderTypography()
  const { fontScale } = useWindowDimensions()
  return useMemo(
    () => ({
      width: "100%",
      maxWidth: Math.round(fontSize * fontScale * READING_MEASURE_EMS + horizontalPadding * 2),
      alignSelf: "center",
    }),
    [fontScale, fontSize, horizontalPadding],
  )
}
