#!/usr/bin/env bun
/**
 * Turn St Thomas Aquinas's Catena Aurea (all four Gospels, Newman's 1841-45 translation) into library works.
 *
 *   bun scripts/build-catena.mjs        # then: bun scripts/build-works-db.mjs
 *
 * Input: .ccel-cache/catena1.txt (Matthew) and catena2.txt (Mark), fetched from
 * https://ccel.org/ccel/a/aquinas/catenaN/cache/catenaN.txt with the library's User-Agent and CCEL's 10-second
 * crawl delay. Print basis: London, J.G.F. and J. Rivington, 1842 (Newman's edition): public domain by date.
 * CCEL credits "William Whiston" as translator; that is a CCEL error (see scripts/works-sources.json).
 *
 * The text is a run of sections ("lectiones"): numbered Gospel verse lines, a separator line of underscores, then
 * the Fathers' comments. "Chapter N" lines start chapters. Matthew 11 has no heading in the CCEL text, so a verse
 * number that restarts at 1 also starts the next chapter.
 *
 * Luke and John: .ccel-cache/CALuke.htm and CAJohn.htm from github.com/Geremia/AquinasOperaOmnia (Fr Joseph Kenny,
 * O.P.'s transcription, Latin beside English). The English is Newman's translation, public domain, "except Prooemium
 * and bracketed portions by Joseph Kenny, O.P." Those are modern and not public domain, so the script skips the
 * prooemium (chapter 0), every comment that starts with "[", and every bracketed span longer than three words.
 *
 * Output: src/services/works/data/aquinas/catena-aurea-{matthew,mark,luke,john}.json, the Aquinas manifest entries, and the
 * Aquinas chapterIndex.json (one entry per section, with fromVerse and toVerse, so Today can find the section that
 * covers a daily Gospel). The script fails if any chapter is missing or any verse is covered twice.
 */
import { readFileSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..")
const OUT = join(ROOT, "src", "services", "works", "data", "aquinas")

const BOOKS = [
  { file: "catena1.txt", code: "MAT", name: "Matthew", id: "catena-aurea-matthew", title: "Catena Aurea: Matthew", chapters: 28, order: 6 },
  { file: "catena2.txt", code: "MRK", name: "Mark", id: "catena-aurea-mark", title: "Catena Aurea: Mark", chapters: 16, order: 7 },
  { file: "CALuke.htm", html: true, code: "LUK", name: "Luke", id: "catena-aurea-luke", title: "Catena Aurea: Luke", chapters: 24, order: 8 },
  { file: "CAJohn.htm", html: true, code: "JHN", name: "John", id: "catena-aurea-john", title: "Catena Aurea: John", chapters: 21, order: 9 },
]

const SEPARATOR = /^\s*_{20,}\s*$/
const CHAPTER = /^Chapter (\d+)/
// Scanning errors in the CCEL text: "l" for "1" ("l.", "3l."), a comma for the period ("32,"); Mark uses "Ver. 1:".
// The period is sometimes lost entirely ("66 So they went"), so a capital letter after the number also counts.
const VERSE = /^\s*(?:Ver\.\s*)?(\d[\dl]*|l[\dl]*)(?:\s*[-–]\s*(\d[\dl]*|l[\dl]*))?(?:[.,:]\s+|\s+(?=[A-Z"]))(.*)$/
const num = (s) => Number(String(s).replace(/l/g, "1"))
const clean = (s) => s.replace(/\s+/g, " ").replace(/&lt;\.?h\d&gt;/g, "").trim()

const ENTITIES = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " " }
const text = (h) => h.replace(/<[^>]+>/g, " ")
  .replace(/&(#x?[0-9a-f]+|\w+);/gi, (m, e) => e[0] === "#" ? String.fromCodePoint(e[1] === "x" || e[1] === "X" ? parseInt(e.slice(2), 16) : Number(e.slice(1))) : (ENTITIES[e] ?? m))
  .replace(/\s+/g, " ").trim()
// Fr Kenny's additions: drop bracketed spans of more than three words. Short glosses ("[be made]") are Newman's style.
const dropKenny = (s) => s.replace(/\[([^\]]*)\]/g, (m, inner) => inner.trim().split(/\s+/).length > 3 ? "" : m).replace(/\s+([.,;:])/g, "$1").replace(/\s+/g, " ").trim()
const titleCase = (s) => s.toLowerCase().replace(/(^|[\s.\-])([a-z])/g, (m, a, b) => a + b.toUpperCase())

// Kenny's HTML: <a name="N"> per chapter; each "Lectio" table has one Gospel row (English verses in a
// <span style="color:red">) and one row per comment ("<b>NAME</b>; text", English in the last cell).
function parseHtml(book) {
  const raw = readFileSync(join(ROOT, ".ccel-cache", book.file), "utf8")
  const anchors = [...raw.matchAll(/name="(\d+)" id="\d+"/g)].map((m) => ({ at: m.index, chapter: Number(m[1]) }))
  const chapterAt = (pos) => anchors.filter((a) => a.at < pos).at(-1)?.chapter ?? 0
  const starts = [...raw.matchAll(/<b>Lectio \d+<\/b>/g)].map((m) => m.index)
  const sections = []
  starts.forEach((start, i) => {
    const chapter = chapterAt(start)
    if (chapter < 1) return
    const chunk = raw.slice(start, starts[i + 1] ?? raw.length)
    const rows = chunk.split(/<tr style="text-align:justify" valign="top">/).slice(1).map((r) => r.split("<tr")[0])
    const cells = (row) => row.split(/<td[^>]*>/).slice(1)
    const gospelRow = rows.find((r) => /<span style="color:red">/.test(cells(r).at(-1) ?? ""))
    if (!gospelRow) throw new Error(`${book.name} ${chapter}: lectio ${i + 1} has no Gospel row`)
    const gospel = dropKenny(text(cells(gospelRow).at(-1)))
    const verses = [...gospel.matchAll(/(?:^|\s)(\d+)[a-d]?(?:\.\s|\s(?=[A-Z]))/g)].map((m) => Number(m[1]))
    if (!verses.length) throw new Error(`${book.name} ${chapter}: lectio ${i + 1} has no verse numbers`)
    const comments = []
    for (const row of rows.slice(rows.indexOf(gospelRow) + 1)) {
      const cell = cells(row).at(-1) ?? ""
      if (!text(cell) || text(cell).startsWith("[")) continue
      // The Father's name is the bold text at the start: "<b>CHRYS.</b> ...", "<b>EUSEBIUS</b>; ...".
      const bold = cell.match(/^\s*<b>([^<]{1,50})<\/b>\s*[;:.,]?\s*/)
      const name = bold ? titleCase(text(bold[1]).replace(/[;:.,\s]+$/, "")) : null
      const body = dropKenny(text(bold ? cell.slice(bold[0].length) : cell)).replace(/^[;:.,]\s*/, "")
      if (body) comments.push(name ? `${name}: ${body}` : body)
    }
    if (!comments.length) return
    const from = Math.min(...verses), to = Math.max(...verses)
    sections.push({ chapter, from, to, title: `${book.name} ${chapter}:${from}${to > from ? `–${to}` : ""}`, paragraphs: [gospel, ...comments] })
  })
  return sections
}

function parse(book) {
  if (book.html) return parseHtml(book)
  const raw = readFileSync(join(ROOT, ".ccel-cache", book.file), "utf8").replace(/\r/g, "")
  const lines = raw.split("\n")
  // Drop the CCEL header: everything before the first verse line of chapter 1.
  const start = lines.findIndex((l) => /^\s*(Ver\.\s*)?[1l][.:]\s/.test(l))
  if (start < 0) throw new Error(`${book.name}: no first verse`)
  // One pass over paragraphs. Separator lines and blank lines end a paragraph; "Chapter N" lines set the chapter.
  const items = []
  let para = []
  const flush = () => { if (para.length) { items.push({ text: clean(para.join(" ")) }); para = [] } }
  for (const line of lines.slice(start)) {
    const heading = line.trim().match(CHAPTER)
    if (heading) { flush(); items.push({ chapter: Number(heading[1]) }); continue }
    if (SEPARATOR.test(line)) { flush(); items.push({ separator: true }); continue }
    if (line.trim() === "") { flush(); continue }
    para.push(line)
  }
  flush()

  const sections = []
  let chapter = 1
  let lastVerse = 0
  let pending = []          // verse paragraphs waiting for their first comment
  let headingSeen = false
  // Verses only open a block: right after a separator or a chapter heading. Once a comment starts, numbered
  // paragraphs are part of the comment (the Fathers number their own points) until the next separator.
  let zone = "open"
  for (const item of items) {
    if (item.separator) { zone = "open"; continue }
    if (item.chapter) {
      // Verses with no comment before a new chapter (for example Matthew 15:39) join the chapter's last section.
      const last = sections.at(-1)
      if (pending.length && last && last.chapter === pending[0].chapter) {
        last.to = pending.at(-1).to
        last.title = `${book.name} ${last.chapter}:${last.from}–${last.to}`
        last.paragraphs[0] += " " + pending.map((v) => `${v.from}${v.to > v.from ? `–${v.to}` : ""}. ${v.text}`).join(" ")
      }
      pending = []
      chapter = item.chapter; lastVerse = 0; headingSeen = true; zone = "open"; continue
    }
    const m = zone !== "comment" ? item.text.match(VERSE) : null
    if (m) {
      zone = "verses"
      const from = num(m[1]), to = num(m[2] ?? m[1])
      // Matthew 11 has no heading: verse 1 again (with no heading just before) means the next chapter.
      if (from === 1 && lastVerse > 1 && !headingSeen) chapter += 1
      headingSeen = false
      lastVerse = to
      pending.push({ chapter, from, to, text: clean(m[3]) })
      continue
    }
    headingSeen = false
    zone = "comment"
    if (pending.length) {
      const c = pending[0].chapter
      const from = pending[0].from
      const to = pending.at(-1).to
      const title = `${book.name} ${c}:${from}${to > from ? `–${to}` : ""}`
      const gospel = pending.map((v) => `${v.from}${v.to > v.from ? `–${v.to}` : ""}. ${v.text}`).join(" ")
      sections.push({ chapter: c, from, to, title, paragraphs: [gospel] })
      pending = []
    }
    if (sections.length) sections.at(-1).paragraphs.push(item.text)
  }
  return sections
}

function check(book, sections) {
  const chapters = new Set(sections.map((s) => s.chapter))
  for (let c = 1; c <= book.chapters; c++) if (!chapters.has(c)) throw new Error(`${book.name}: chapter ${c} missing`)
  if (Math.max(...chapters) !== book.chapters) throw new Error(`${book.name}: ${Math.max(...chapters)} chapters`)
  // Sections may share a boundary verse (the source splits some verses), but must not leave gaps.
  const covered = new Set()
  for (const s of sections) for (let v = s.from; v <= s.to; v++) covered.add(`${s.chapter}:${v}`)
  const gaps = []
  for (const c of chapters) {
    const last = Math.max(...sections.filter((s) => s.chapter === c).map((s) => s.to))
    for (let v = 1; v <= last; v++) if (!covered.has(`${c}:${v}`)) gaps.push(`${c}:${v}`)
  }
  // A few verses are absent from the CCEL text itself (for example Matthew 5:15-16). Report them; fail if many.
  if (gaps.length) console.warn(`${book.name}: verses with no section (absent from the source): ${gaps.join(", ")}`)
  if (gaps.length > 12) throw new Error(`${book.name}: ${gaps.length} verses not covered; the parser is probably wrong`)
  return covered.size
}

const manifestPath = join(OUT, "manifest.json")
const manifest = JSON.parse(readFileSync(manifestPath, "utf8")).filter((w) => !w.id.startsWith("catena-aurea"))
const chapterIndex = {}
for (const book of BOOKS) {
  const sections = parse(book)
  const verses = check(book, sections)
  const words = sections.reduce((n, s) => n + s.paragraphs.join(" ").split(/\s+/).length, 0)
  writeFileSync(join(OUT, `${book.id}.json`), JSON.stringify({
    id: book.id, title: book.title, order: book.order, sectionCount: sections.length, words, book: book.code,
    sections: sections.map((s, i) => ({ id: `s${i + 1}`, title: s.title, paragraphs: s.paragraphs })),
  }))
  manifest.push({ id: book.id, title: book.title, order: book.order, sectionCount: sections.length, words, book: book.code, kind: "commentary" })
  const byChapter = (chapterIndex[book.code] = {})
  sections.forEach((s, i) => (byChapter[s.chapter] ??= []).push({
    workId: book.id, workTitle: book.title, sectionIndex: i, sectionTitle: s.title, fromVerse: s.from, toVerse: s.to,
  }))
  console.log(`${book.name.padEnd(8)} chapters ${book.chapters}  sections ${sections.length}  verses ${verses}  words ${words}`)
}
writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n")
writeFileSync(join(OUT, "chapterIndex.json"), JSON.stringify(chapterIndex))
