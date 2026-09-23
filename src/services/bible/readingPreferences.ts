import { load, save } from "@/utils/storage"

export type ReaderTextSize = "small" | "medium" | "large" | "extraLarge"
export type ReaderLineSpacing = "compact" | "comfortable" | "relaxed"
export type ReaderTypeface = "sans" | "serif"
/** Flowing paragraphs and poetry lines, or every verse on its own line. */
export type ReaderLayout = "paragraphs" | "verses"

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
  layout: "bible.reader.layout",
  widgetGuideDismissed: "bible.widgetGuideDismissed",
  selectionHintDismissed: "bible.reader.selectionHintDismissed",
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
export const READER_LAYOUTS: readonly ReaderLayout[] = ["paragraphs", "verses"]

export const DEFAULT_READER_TEXT_SIZE: ReaderTextSize = "medium"
export const DEFAULT_READER_LINE_SPACING: ReaderLineSpacing = "comfortable"
export const DEFAULT_READER_TYPEFACE: ReaderTypeface = "serif"
export const DEFAULT_READER_LAYOUT: ReaderLayout = "paragraphs"

function isOneOf<T extends string>(value: unknown, values: readonly T[]): value is T {
  return typeof value === "string" && (values as readonly string[]).includes(value)
}

// Settings and the reader's text sheet change how Scripture looks while the
// other screens stay mounted, so those screens subscribe instead of re-reading
// on focus. The reader behind the sheet restyles as each option is tapped.
const listeners = new Set<() => void>()

/** Calls `listener` after any text or layout preference changes. */
export function subscribeToReadingPreferences(listener: () => void): () => void {
  listeners.add(listener)
  return () => {
    listeners.delete(listener)
  }
}

function savePreference(key: string, value: unknown): void {
  save(key, value)
  listeners.forEach((listener) => listener())
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
  savePreference(KEYS.textSize, value)
}

export function getReaderLineSpacing(): ReaderLineSpacing {
  const value = load<unknown>(KEYS.lineSpacing)
  return isOneOf(value, READER_LINE_SPACINGS) ? value : DEFAULT_READER_LINE_SPACING
}

export function setReaderLineSpacing(value: ReaderLineSpacing): void {
  savePreference(KEYS.lineSpacing, value)
}

export function getReaderTypeface(): ReaderTypeface {
  const value = load<unknown>(KEYS.typeface)
  return isOneOf(value, READER_TYPEFACES) ? value : DEFAULT_READER_TYPEFACE
}

export function setReaderTypeface(value: ReaderTypeface): void {
  savePreference(KEYS.typeface, value)
}

export function getReaderLayout(): ReaderLayout {
  const value = load<unknown>(KEYS.layout)
  return isOneOf(value, READER_LAYOUTS) ? value : DEFAULT_READER_LAYOUT
}

export function setReaderLayout(value: ReaderLayout): void {
  savePreference(KEYS.layout, value)
}

export function isWidgetGuideDismissed(): boolean {
  return load<boolean>(KEYS.widgetGuideDismissed) === true
}

export function dismissWidgetGuide(): void {
  save(KEYS.widgetGuideDismissed, true)
}

/** The reader explains verse selection until the reader has selected a verse once. */
export function isSelectionHintDismissed(): boolean {
  return load<boolean>(KEYS.selectionHintDismissed) === true
}

export function dismissSelectionHint(): void {
  save(KEYS.selectionHintDismissed, true)
}
