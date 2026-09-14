import type { BookMeta } from "./types"

export interface ParsedReference {
  book: BookMeta
  chapter: number
  startVerse?: string
  endVerse?: string
}

const BOOK_ALIASES: Record<string, string[]> = {
  GEN: ["gen"],
  EXO: ["ex", "exod"],
  LEV: ["lev"],
  NUM: ["num"],
  DEU: ["deut", "dt"],
  JOS: ["josh"],
  JDG: ["judg"],
  PSA: ["ps", "psalm", "psalms"],
  PRO: ["prov"],
  ECC: ["eccl"],
  SNG: ["song", "song of songs", "songs", "sos"],
  ISA: ["isa"],
  JER: ["jer"],
  LAM: ["lam"],
  EZK: ["ezek", "ezk"],
  DAN: ["dan"],
  OBA: ["obad"],
  MIC: ["mic"],
  NAM: ["nah", "nahum"],
  HAB: ["hab"],
  ZEP: ["zeph"],
  HAG: ["hag"],
  ZEC: ["zech"],
  MAL: ["mal"],
  MAT: ["matt", "mt"],
  MRK: ["mark", "mk"],
  LUK: ["luke", "lk"],
  JHN: ["john", "jn"],
  ACT: ["acts"],
  ROM: ["rom"],
  GAL: ["gal"],
  EPH: ["eph"],
  PHP: ["phil", "philippians"],
  COL: ["col"],
  TIT: ["tit"],
  PHM: ["phlm", "philemon"],
  HEB: ["heb"],
  JAS: ["jas", "james"],
  JUD: ["jude"],
  REV: ["rev", "revelation"],
}

export function normalizeReferenceText(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/\p{Mark}/gu, "")
    .toLocaleLowerCase("en")
    .replace(/[.]/g, "")
    .replace(/\s+/g, " ")
    .trim()
}

export function editDistance(left: string, right: string, maximum = Infinity): number {
  if (Math.abs(left.length - right.length) > maximum) return maximum + 1
  const previous = Array.from({ length: right.length + 1 }, (_, index) => index)
  const current = new Array<number>(right.length + 1)

  for (let leftIndex = 1; leftIndex <= left.length; leftIndex += 1) {
    current[0] = leftIndex
    let rowMinimum = current[0]
    for (let rightIndex = 1; rightIndex <= right.length; rightIndex += 1) {
      const substitution =
        previous[rightIndex - 1] + (left[leftIndex - 1] === right[rightIndex - 1] ? 0 : 1)
      current[rightIndex] = Math.min(
        previous[rightIndex] + 1,
        current[rightIndex - 1] + 1,
        substitution,
      )
      rowMinimum = Math.min(rowMinimum, current[rightIndex])
    }
    if (rowMinimum > maximum) return maximum + 1
    previous.splice(0, previous.length, ...current)
  }
  return previous[right.length]
}

function aliasesFor(book: BookMeta): string[] {
  const numberedName = book.name.replace(/^([1-4])\s+/, "$1")
  return [book.code, book.name, book.longName, numberedName, ...(BOOK_ALIASES[book.code] ?? [])]
    .map(normalizeReferenceText)
    .filter(Boolean)
}

function findBook(value: string, books: BookMeta[]): BookMeta | undefined {
  const normalized = normalizeReferenceText(value)
  const exact = books.find((book) => aliasesFor(book).includes(normalized))
  if (exact) return exact
  if (normalized.length < 4) return undefined

  let best: { book: BookMeta; distance: number } | undefined
  for (const book of books) {
    for (const alias of aliasesFor(book)) {
      const maximum = normalized.length >= 8 ? 2 : 1
      const distance = editDistance(normalized, alias, maximum)
      if (distance <= maximum && (!best || distance < best.distance)) best = { book, distance }
    }
  }
  return best?.book
}

export function parseBibleReference(query: string, books: BookMeta[]): ParsedReference | null {
  const normalized = query.replace(/[–—]/g, "-").trim()
  const match = normalized.match(
    /^(.+?)\s+(\d+)(?:(?:\s*:\s*|\s+)(\d+[a-z]?)(?:\s*-\s*(\d+[a-z]?))?)?$/i,
  )
  if (!match) return null

  const book = findBook(match[1], books)
  const chapter = Number(match[2])
  if (!book || !Number.isInteger(chapter) || chapter < 1 || chapter > book.chapterCount) return null

  return {
    book,
    chapter,
    startVerse: match[3],
    endVerse: match[4] ?? match[3],
  }
}
