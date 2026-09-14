import { useCallback, useMemo, useState } from "react"
import { Platform, TextStyle } from "react-native"
import { useFocusEffect } from "expo-router"

import {
  getReaderLineSpacing,
  getReaderTextSize,
  getReaderTypeface,
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

/** Shared Scripture typography for the Bible reader and daily-reading passages. */
export function useReaderTypography(): TextStyle {
  const { theme } = useAppTheme()
  const [textSize, setTextSize] = useState(getReaderTextSize)
  const [lineSpacing, setLineSpacing] = useState(getReaderLineSpacing)
  const [typeface, setTypeface] = useState(getReaderTypeface)
  useFocusEffect(
    useCallback(() => {
      setTextSize(getReaderTextSize())
      setLineSpacing(getReaderLineSpacing())
      setTypeface(getReaderTypeface())
    }, []),
  )
  return useMemo(() => {
    const fontSize = READER_FONT_SIZES[textSize]
    return {
      fontFamily: typeface === "serif" ? READER_SERIF_FONT : theme.typography.primary.normal,
      fontSize,
      lineHeight: Math.round(fontSize * READER_LINE_HEIGHTS[lineSpacing]),
    }
  }, [textSize, lineSpacing, typeface, theme.typography])
}
