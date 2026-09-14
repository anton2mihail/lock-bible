export const HIGHLIGHT_COLORS = ["gold", "sage", "rose", "blue"] as const
export type HighlightColor = (typeof HIGHLIGHT_COLORS)[number]

export interface PassageVerse {
  verse: string
  index: number
  text: string
}

export interface PassageSelection {
  translationId: string
  bookCode: string
  bookName: string
  bookOrder: number
  chapter: number
  startVerse: string
  endVerse: string
  startIndex: number
  endIndex: number
  scriptureText: string
  verses: PassageVerse[]
}

export type SavedItemKind = "bookmark" | "highlight" | "note"

export interface SavedHighlightVerse {
  verseKey: string
  batchId: string
  verse: string
  verseIndex: number
  verseText: string
  createdAt: number
  updatedAt: number
}

export interface SavedItem {
  id: string
  kind: SavedItemKind
  translationId: string
  bookCode: string
  bookName: string
  bookOrder: number
  chapter: number
  startVerse: string
  endVerse: string
  startIndex: number
  endIndex: number
  scriptureText: string
  reference: string
  updatedAt: number
  createdAt: number
  color?: HighlightColor
  noteText?: string
  verseKeys?: string[]
  highlightVerses?: SavedHighlightVerse[]
}

export type SavedFilter = "all" | "bookmark" | "highlight" | "note"
