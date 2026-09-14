import { getBook } from "@/services/bible/bibleService"
import type { BookMeta, Chapter } from "@/services/bible/types"

import type { PassageSelection, SavedItem } from "./types"

export function createPassageSelection(
  translationId: string,
  book: BookMeta,
  chapter: Chapter,
  firstIndex: number,
  secondIndex = firstIndex,
): PassageSelection | null {
  const startIndex = Math.max(0, Math.min(firstIndex, secondIndex))
  const endIndex = Math.min(chapter.verses.length - 1, Math.max(firstIndex, secondIndex))
  const selected = chapter.verses.slice(startIndex, endIndex + 1)
  if (!selected.length) return null

  return {
    translationId,
    bookCode: book.code,
    bookName: book.name,
    bookOrder: book.order,
    chapter: chapter.c,
    startVerse: selected[0].n,
    endVerse: selected[selected.length - 1].n,
    startIndex,
    endIndex,
    scriptureText: selected.map((verse) => `${verse.n} ${verse.t}`).join(" "),
    verses: selected.map((verse, offset) => ({
      verse: verse.n,
      index: startIndex + offset,
      text: verse.t,
    })),
  }
}

export function selectionFromReference(
  translationId: string,
  book: BookMeta,
  chapterNumber: number,
  startVerse: string,
  endVerse = startVerse,
): PassageSelection | null {
  const chapter = getBook(book.code).chapters.find((candidate) => candidate.c === chapterNumber)
  if (!chapter) return null
  const startIndex = chapter.verses.findIndex((verse) => verse.n === startVerse)
  const endIndex = chapter.verses.findIndex((verse) => verse.n === endVerse)
  if (startIndex < 0 || endIndex < 0) return null
  return createPassageSelection(translationId, book, chapter, startIndex, endIndex)
}

export function selectionFromSavedItem(item: SavedItem, book: BookMeta): PassageSelection | null {
  return selectionFromReference(
    item.translationId,
    book,
    item.chapter,
    item.startVerse,
    item.endVerse,
  )
}
