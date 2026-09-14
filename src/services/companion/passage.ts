import { getActiveTranslationMeta } from "@/services/bible"
import { parseBibleReference } from "@/services/bible/referenceParser"
import { getTranslation } from "@/services/bible/translations"

export type PassageParams = {
  book?: string
  chapter?: string
  startVerse?: string
  endVerse?: string
  translation?: string
}
export type PrayerPassage = {
  reference: string
  text: string
  translation: string
  attribution: string
  params: Required<PassageParams>
}
export function resolvePassage(params: PassageParams): PrayerPassage | null {
  const translation = getTranslation(params.translation ?? getActiveTranslationMeta().id)
  const book = translation.manifest.find((b) => b.code === params.book)
  const number = Number(params.chapter)
  if (!book || !Number.isInteger(number) || number < 1 || number > book.chapterCount) return null
  const chapter = translation.loadBook(book.code).chapters.find((c) => c.c === number)
  if (!chapter) return null
  const first = params.startVerse ? chapter.verses.findIndex((v) => v.n === params.startVerse) : 0
  const last = params.endVerse ? chapter.verses.findIndex((v) => v.n === params.endVerse) : first
  if (first < 0 || last < first) return null
  const verses = chapter.verses.slice(first, last + 1)
  const startVerse = verses[0].n,
    endVerse = verses[verses.length - 1].n
  return {
    reference: `${book.name} ${number}:${startVerse}${startVerse === endVerse ? "" : `–${endVerse}`}`,
    text: verses.map((v) => v.t).join("\n\n"),
    translation: translation.meta.abbreviation,
    attribution: translation.meta.attribution,
    params: {
      book: book.code,
      chapter: String(number),
      startVerse,
      endVerse,
      translation: translation.meta.id,
    },
  }
}
/** Opens a whole source chapter for complex citations; never silently drops parts. */
export function referenceTarget(reference: string): {
  book: string
  chapter: string
  verse?: string
  endVerse?: string
  contextRequest: string
} | null {
  const books = getTranslation("web-ce").manifest
  let normalized = reference.replace(/^See\s+/i, "").replace(/\s+/g, " ")
  // The US lectionary uses NAB chapter divisions. WEB-CE incorporates the
  // Greek additions within Esther and uses the three-chapter division of Joel.
  normalized = normalized.replace(/^Joel 3:/i, "Joel 2:").replace(/^Joel 4:/i, "Joel 3:")
  const estherChapters: Record<string, number> = { A: 1, B: 3, C: 4, D: 5, E: 8, F: 10 }
  normalized = normalized.replace(
    /^Esther ([A-F]):/i,
    (_, section: string) => `Esther ${estherChapters[section.toUpperCase()]}:`,
  )
  normalized = normalized.replace(/^(Philemon|Jude|2 John|3 John) (\d+)(?![\d:])/i, "$1 1:$2")
  const match = normalized.match(/^(.+?)\s+(\d+):/)
  if (!match) return null
  const parsed = parseBibleReference(`${match[1]} ${match[2]}`, books)
  if (!parsed) return null
  // Psalm and some OT numbering differ in the Latin and Douay–Rheims editions.
  // Reference links use WEB-CE consistently; the reader is told explicitly by its caller.
  return {
    book: parsed.book.code,
    chapter: String(parsed.chapter),
    contextRequest: String(Date.now()),
  }
}
