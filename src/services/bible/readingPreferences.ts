import { load, save } from "@/utils/storage"

export type ReaderTextSize = "small" | "medium" | "large" | "extraLarge"
export type ReaderLineSpacing = "compact" | "comfortable" | "relaxed"
export type ReaderTypeface = "sans" | "serif"

export interface ReaderLocation {
  book: string
  chapter: number
  scrollY: number
  updatedAt: number
}

const KEYS = {
  location: "bible.reader.location",
  textSize: "bible.reader.textSize",
  lineSpacing: "bible.reader.lineSpacing",
  typeface: "bible.reader.typeface",
  widgetGuideDismissed: "bible.widgetGuideDismissed",
} as const

export const READER_TEXT_SIZES: readonly ReaderTextSize[] = [
  "small",
  "medium",
  "large",
  "extraLarge",
]
export const READER_LINE_SPACINGS: readonly ReaderLineSpacing[] = [
  "compact",
  "comfortable",
  "relaxed",
]
export const READER_TYPEFACES: readonly ReaderTypeface[] = ["sans", "serif"]

export const DEFAULT_READER_TEXT_SIZE: ReaderTextSize = "medium"
export const DEFAULT_READER_LINE_SPACING: ReaderLineSpacing = "comfortable"
export const DEFAULT_READER_TYPEFACE: ReaderTypeface = "serif"

function isOneOf<T extends string>(value: unknown, values: readonly T[]): value is T {
  return typeof value === "string" && (values as readonly string[]).includes(value)
}

export function getReaderLocation(): ReaderLocation | null {
  const value = load<ReaderLocation>(KEYS.location)
  if (
    !value ||
    typeof value.book !== "string" ||
    !Number.isInteger(value.chapter) ||
    value.chapter < 1 ||
    typeof value.scrollY !== "number" ||
    !Number.isFinite(value.scrollY)
  ) {
    return null
  }

  return {
    book: value.book,
    chapter: value.chapter,
    scrollY: Math.max(0, value.scrollY),
    updatedAt: typeof value.updatedAt === "number" ? value.updatedAt : 0,
  }
}

export function setReaderLocation(location: Omit<ReaderLocation, "updatedAt">): void {
  save(KEYS.location, {
    ...location,
    scrollY: Math.max(0, location.scrollY),
    updatedAt: Date.now(),
  } satisfies ReaderLocation)
}

export function getReaderTextSize(): ReaderTextSize {
  const value = load<unknown>(KEYS.textSize)
  return isOneOf(value, READER_TEXT_SIZES) ? value : DEFAULT_READER_TEXT_SIZE
}

export function setReaderTextSize(value: ReaderTextSize): void {
  save(KEYS.textSize, value)
}

export function getReaderLineSpacing(): ReaderLineSpacing {
  const value = load<unknown>(KEYS.lineSpacing)
  return isOneOf(value, READER_LINE_SPACINGS) ? value : DEFAULT_READER_LINE_SPACING
}

export function setReaderLineSpacing(value: ReaderLineSpacing): void {
  save(KEYS.lineSpacing, value)
}

export function getReaderTypeface(): ReaderTypeface {
  const value = load<unknown>(KEYS.typeface)
  return isOneOf(value, READER_TYPEFACES) ? value : DEFAULT_READER_TYPEFACE
}

export function setReaderTypeface(value: ReaderTypeface): void {
  save(KEYS.typeface, value)
}

export function isWidgetGuideDismissed(): boolean {
  return load<boolean>(KEYS.widgetGuideDismissed) === true
}

export function dismissWidgetGuide(): void {
  save(KEYS.widgetGuideDismissed, true)
}
