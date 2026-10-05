#!/usr/bin/env node
import { createHash } from "node:crypto"
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { join, resolve } from "node:path"

const root = resolve(import.meta.dirname, "../../..")
const output = join(import.meta.dirname, "Resources")
const samples = [
  { id: "john-web", edition: "web-ce", book: "JHN", chapter: 1 },
  { id: "psalm-23-web", edition: "web-ce", book: "PSA", chapter: 23 },
  { id: "song-1-web", edition: "web-ce", book: "SNG", chapter: 1 },
  { id: "john-vulgate", edition: "vulgate", book: "JHN", chapter: 1 },
  { id: "john-douay", edition: "douay-rheims", book: "JHN", chapter: 1 },
]

mkdirSync(output, { recursive: true })
const manifest = []
for (const sample of samples) {
  const source = join(root, "src/services/bible/data", sample.edition, `${sample.book}.json`)
  if (!existsSync(source)) throw new Error(`Missing source: ${source}`)
  const sourceBytes = readFileSync(source)
  const book = JSON.parse(sourceBytes.toString("utf8"))
  const chapter = book.chapters.find((value) => value.c === sample.chapter)
  if (!chapter) throw new Error(`Missing ${sample.book} ${sample.chapter}`)
  const payload = {
    edition: sample.edition,
    bookCode: book.code,
    bookName: book.name,
    longName: book.longName,
    chapter,
  }
  const out = join(output, `${sample.id}.json`)
  writeFileSync(out, `${JSON.stringify(payload)}\n`)
  manifest.push({
    id: sample.id,
    source: `src/services/bible/data/${sample.edition}/${sample.book}.json`,
    sourceSha256: createHash("sha256").update(sourceBytes).digest("hex"),
    chapterSha256: createHash("sha256").update(JSON.stringify(chapter)).digest("hex"),
    chapter: sample.chapter,
    verseCount: chapter.verses.length,
  })
}

const workSource = join(
  root,
  "src/services/works/data/chrysostom/homilies-on-the-gospel-of-john.json",
)
const workBytes = readFileSync(workSource)
const work = JSON.parse(workBytes.toString("utf8"))
const section = work.sections[0]
const workSample = {
  collection: "chrysostom",
  workId: work.id,
  title: work.title,
  sectionIndex: 0,
  sectionTitle: section.title,
  paragraphs: section.paragraphs,
}
writeFileSync(join(output, "works-section.json"), `${JSON.stringify(workSample)}\n`)
manifest.push({
  id: "works-section",
  source: "src/services/works/data/chrysostom/homilies-on-the-gospel-of-john.json",
  sourceSha256: createHash("sha256").update(workBytes).digest("hex"),
  sectionIndex: 0,
  paragraphCount: section.paragraphs.length,
  wordCount: section.paragraphs.join(" ").split(/\s+/u).filter(Boolean).length,
})

const unicode = {
  id: "unicode-offsets",
  text: "Before😀e\u0301—after",
  utf16Boundaries: [0, 6, 8, 9, 10, 11, 16],
  note: "Offsets are UTF-16 code units, as used by JavaScript and NSRange.",
}
const unicodeChapter = {
  edition: "synthetic",
  bookCode: "SYN",
  bookName: "Unicode fixture",
  longName: "Unicode fixture",
  chapter: {
    c: 1,
    verses: [
      { n: "1-2", t: unicode.text, br: [[8, "q2"], [10, "q3"]] },
      { n: "3", t: "Second verse.", br: [[0, "p"]] },
    ],
  },
}
writeFileSync(join(output, "unicode-fixture.json"), `${JSON.stringify(unicode)}\n`)
writeFileSync(join(output, "unicode-chapter.json"), `${JSON.stringify(unicodeChapter)}\n`)
writeFileSync(join(output, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`)
console.log(`Prepared ${samples.length} source Bible chapters, one works section, and one Unicode fixture.`)
