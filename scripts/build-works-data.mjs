#!/usr/bin/env node
/**
 * Turn an EPUB of patristic works into the bundled JSON the app reads offline.
 *
 *   node scripts/build-works-data.mjs <path-to.epub>
 *
 * The output is intermediate: a manifest, a meta file and one JSON per work.
 * scripts/build-works-db.mjs packs that into assets/works/works.db, which is
 * what the app actually ships - bundling the JSON directly cost 2.9x its size
 * in Hermes bytecode.
 *
 * Structure comes from the EPUB's own toc.ncx, which nests neatly here: each
 * top-level navPoint is a work ("Homilies on the Gospel of St. Matthew") and
 * each child is a section within it ("Homily 1"). Spine order decides where a
 * work stops, because the TOC only records where each one starts.
 */
import { execFileSync } from "node:child_process"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"

const ROOT = path.resolve(import.meta.dirname, "..")
const OUT_DIR = path.join(ROOT, "src", "services", "works", "data", "chrysostom")

const META = {
  id: "chrysostom",
  title: "The Complete Works of St John Chrysostom",
  author: "St John Chrysostom",
  era: "Greek Father and Doctor, 4th century",
  order: 2,
  translation: "Nicene and Post-Nicene Fathers, first series (Philip Schaff, 1886–1890)",
  attribution:
    "Translated in the Nicene and Post-Nicene Fathers, first series, edited by Philip Schaff (1886–1890). The translation is in the public domain.",
  // Front matter that is navigation, not reading. "Introduction" is dropped for
  // a different reason: the NPNF translation is public domain, but that blurb is
  // the modern compiler's own biography of Chrysostom and is the one piece of
  // this file that could still carry a live copyright. The works themselves lose
  // nothing by its absence.
  skipTitles: ["Title Page", "Table of Contents", "Cover", "Introduction"],
}

/** Strip a fragment: "text/part0116.html#anchor" -> "text/part0116.html". */
const filePart = (href) => decodeURIComponent(String(href).split("#")[0])

function unzip(epubPath) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "works-epub-"))
  execFileSync("unzip", ["-o", "-q", epubPath, "-d", dir])
  return dir
}

function findRootFile(dir) {
  const container = fs.readFileSync(path.join(dir, "META-INF", "container.xml"), "utf8")
  const match = container.match(/full-path="([^"]+)"/)
  if (!match) throw new Error("container.xml has no rootfile")
  return match[1]
}

function parseOpf(opfPath) {
  const xml = fs.readFileSync(opfPath, "utf8")
  const hrefById = new Map()
  for (const m of xml.matchAll(/<item\b[^>]*\/?>/g)) {
    const id = m[0].match(/\bid="([^"]+)"/)?.[1]
    const href = m[0].match(/\bhref="([^"]+)"/)?.[1]
    if (id && href) hrefById.set(id, decodeURIComponent(href))
  }
  const spine = []
  for (const m of xml.matchAll(/<itemref\b[^>]*idref="([^"]+)"[^>]*\/?>/g)) {
    const href = hrefById.get(m[1])
    if (href) spine.push(href)
  }
  return { spine }
}

/** navPoints in document order, carrying their nesting depth. */
function parseNcx(ncxPath) {
  const xml = fs.readFileSync(ncxPath, "utf8")
  const points = []
  const stack = []
  const token =
    /<navPoint\b[^>]*>|<\/navPoint>|<text>([\s\S]*?)<\/text>|<content\b[^>]*src="([^"]+)"/g
  let pending = null
  for (const m of xml.matchAll(token)) {
    if (m[0].startsWith("</navPoint")) {
      stack.pop()
      continue
    }
    if (m[0].startsWith("<navPoint")) {
      pending = { depth: stack.length, title: "", src: "" }
      stack.push(pending)
      points.push(pending)
      continue
    }
    if (m[1] !== undefined && pending && !pending.title) {
      pending.title = m[1]
        .replace(/<[^>]+>/g, "")
        .replace(/\s+/g, " ")
        .trim()
      continue
    }
    if (m[2] !== undefined && pending && !pending.src) pending.src = m[2]
  }
  return points.filter((p) => p.title && p.src)
}

const BLOCK = /<(p|h[1-6]|blockquote|li)\b[^>]*>([\s\S]*?)<\/\1>/gi

function textOf(html) {
  return html
    .replace(/<br\s*\/?>/gi, " ")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;|&#160;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
    .replace(/&[a-z]+;/gi, " ")
    .replace(/\s+/g, " ")
    .trim()
}

/** Block-level paragraphs from one XHTML file, in order. */
function paragraphsOf(filePath) {
  if (!fs.existsSync(filePath)) return []
  const html = fs.readFileSync(filePath, "utf8")
  const body = html.match(/<body[^>]*>([\s\S]*)<\/body>/i)?.[1] ?? html
  const out = []
  for (const m of body.matchAll(BLOCK)) {
    const text = textOf(m[2])
    // Drop stray single characters and page-number crumbs.
    if (text.length > 1) out.push(text)
  }
  if (!out.length) {
    const flat = textOf(body)
    if (flat.length > 1) out.push(flat)
  }
  return out
}

const slugify = (s) =>
  s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 60)

/**
 * Which Bible book each commentary expounds. Chrysostom's works are mostly
 * homilies on one book, so the work itself fixes the book and only the chapter
 * has to be read out of the homily.
 */
const WORK_BOOK = {
  "homilies-on-the-gospel-of-st-matthew": "MAT",
  "homilies-on-the-gospel-of-john": "JHN",
  "homilies-on-acts": "ACT",
  "homilies-on-romans": "ROM",
  "homilies-on-first-corinthians": "1CO",
  "homilies-on-second-corinthians": "2CO",
  "commentary-on-galatians": "GAL",
  "homilies-on-ephesians": "EPH",
  "homilies-on-philippians": "PHP",
  "homilies-on-colossians": "COL",
  "homilies-on-first-thessalonians": "1TH",
  "homilies-on-second-thessalonians": "2TH",
  "homilies-on-first-timothy": "1TI",
  "homilies-on-second-timothy": "2TI",
  "homilies-on-titus": "TIT",
  "homilies-on-philemon": "PHM",
  "homilies-on-the-epistle-to-the-hebrews": "HEB",
}

const ROMAN_VALUES = { I: 1, V: 5, X: 10, L: 50, C: 100 }

function romanToNumber(text) {
  const upper = text.toUpperCase()
  if (![...upper].every((c) => c in ROMAN_VALUES)) return null
  let total = 0
  let highest = 0
  for (const char of [...upper].reverse()) {
    const value = ROMAN_VALUES[char]
    total += value < highest ? -value : value
    highest = Math.max(highest, value)
  }
  return total || null
}

// Four reference styles appear in this corpus and all four must be read:
//   "Matt. I. 1."            book + roman chapter
//   "Romans 1:1-2"           book + arabic chapter
//   "[Philippians 1:8-11]"   the same, bracketed
//   "Chapter I. Verses 11-14"  chapter only, the book being implied by the work
// The Commentary on Galatians carries no reference at all: it is organised by
// Bible chapter, so its section titles ("Chapter 3") are the reference.
const BOOK_CHAPTER =
  /^\[?\s*(?:[123]|First|Second|Third)?\s*[A-Za-z][A-Za-z]{2,}\.?\s+(\d+|[IVXLC]+)\s*[.:]\s*\d+/
const CHAPTER_ONLY = /^Chapter\s+(\d+|[IVXLC]+)\s*[.:]?\s*(?:Verses?\b|$)/i
const TITLE_CHAPTER = /^Chapter\s+(\d+|[IVXLC]+)\s*$/i

function toChapter(raw) {
  const value = /^\d+$/.test(raw) ? Number(raw) : romanToNumber(raw)
  return value && value > 0 && value < 200 ? value : null
}

/** The chapter a homily expounds, from its opening reference or its title. */
function chapterOf(section) {
  const fromTitle = TITLE_CHAPTER.exec(section.title.trim())
  if (fromTitle) {
    const chapter = toChapter(fromTitle[1])
    if (chapter) return chapter
  }
  for (const paragraph of section.paragraphs.slice(0, 3)) {
    const text = paragraph.trim()
    const match = BOOK_CHAPTER.exec(text) ?? CHAPTER_ONLY.exec(text)
    if (!match) continue
    const chapter = toChapter(match[1])
    if (chapter) return chapter
  }
  return null
}

/**
 * Bible chapter -> the homilies that expound it, so the reader can offer
 * Chrysostom beside the chapter you are actually reading.
 */
function buildChapterIndex(works) {
  const index = {}
  let mapped = 0
  let unmapped = 0

  for (const work of works) {
    const book = WORK_BOOK[work.id]
    if (!book) continue
    index[book] ||= {}

    work.sections.forEach((section, sectionIndex) => {
      // A single-chapter book needs no reference: every homily is on chapter 1.
      const chapter = chapterOf(section) ?? (book === "PHM" ? 1 : null)
      if (!chapter) {
        unmapped += 1
        return
      }
      mapped += 1
      const key = String(chapter)
      index[book][key] ||= []
      index[book][key].push({
        workId: work.id,
        workTitle: work.title,
        sectionIndex,
        sectionTitle: section.title,
      })
    })
  }
  return { index, mapped, unmapped }
}

function build(epubPath) {
  const dir = unzip(epubPath)
  const opfRel = findRootFile(dir)
  const base = path.dirname(path.join(dir, opfRel))
  const { spine } = parseOpf(path.join(dir, opfRel))
  const ncxRel = spine.length
    ? (fs.readdirSync(base).find((f) => f.endsWith(".ncx")) ?? "toc.ncx")
    : "toc.ncx"
  const points = parseNcx(path.join(base, ncxRel))

  const spineIndex = new Map(spine.map((href, i) => [href, i]))
  const indexOf = (src) => spineIndex.get(filePart(src)) ?? -1

  const works = points.filter((p) => p.depth === 0 && !META.skipTitles.includes(p.title))
  const results = []

  works.forEach((work, workPos) => {
    const start = indexOf(work.src)
    if (start < 0) return
    // A work runs until the next top-level entry begins.
    const nextTop = points.find((p) => p.depth === 0 && indexOf(p.src) > start)
    const end = nextTop ? indexOf(nextTop.src) : spine.length

    // Its own children are the sections; a work with none is a single section.
    const children = points.filter(
      (p) => p.depth > 0 && indexOf(p.src) >= start && indexOf(p.src) < end,
    )
    const starts = children.length
      ? children.map((c) => ({ title: c.title, at: indexOf(c.src) }))
      : [{ title: work.title, at: start }]
    if (starts[0].at > start) starts.unshift({ title: work.title, at: start })

    const sections = []
    starts.forEach((s, i) => {
      const stop = i + 1 < starts.length ? starts[i + 1].at : end
      const paragraphs = []
      for (let f = s.at; f < stop; f += 1) {
        paragraphs.push(...paragraphsOf(path.join(base, spine[f])))
      }
      // Calibre repeats the section heading as the first paragraph.
      if (paragraphs[0] && paragraphs[0].toLowerCase() === s.title.toLowerCase()) {
        paragraphs.shift()
      }
      if (paragraphs.length) {
        sections.push({ id: `s${sections.length + 1}`, title: s.title, paragraphs })
      }
    })
    if (!sections.length) return

    const words = sections.reduce(
      (n, s) => n + s.paragraphs.reduce((m, p) => m + p.split(" ").length, 0),
      0,
    )
    results.push({
      id: slugify(work.title),
      title: work.title,
      order: workPos + 1,
      sectionCount: sections.length,
      words,
      sections,
    })
  })

  fs.rmSync(OUT_DIR, { recursive: true, force: true })
  fs.mkdirSync(OUT_DIR, { recursive: true })

  for (const work of results) {
    const { sections, ...rest } = work
    fs.writeFileSync(path.join(OUT_DIR, `${work.id}.json`), JSON.stringify({ ...rest, sections }))
  }

  const { index: chapterIndex, mapped, unmapped } = buildChapterIndex(results)
  fs.writeFileSync(path.join(OUT_DIR, "chapterIndex.json"), JSON.stringify(chapterIndex))

  const manifest = results.map(({ id, title, order, sectionCount, words }) => ({
    id,
    title,
    order,
    sectionCount,
    words,
    book: WORK_BOOK[id] ?? null,
  }))
  fs.writeFileSync(path.join(OUT_DIR, "manifest.json"), JSON.stringify(manifest, null, 2))
  fs.writeFileSync(
    path.join(OUT_DIR, "meta.json"),
    JSON.stringify(
      {
        id: META.id,
        title: META.title,
        author: META.author,
        era: META.era,
        order: META.order,
        translation: META.translation,
        attribution: META.attribution,
        workCount: results.length,
        sectionCount: results.reduce((n, w) => n + w.sectionCount, 0),
        words: results.reduce((n, w) => n + w.words, 0),
      },
      null,
      2,
    ),
  )

  fs.rmSync(dir, { recursive: true, force: true })

  const bytes = fs
    .readdirSync(OUT_DIR)
    .reduce((n, f) => n + fs.statSync(path.join(OUT_DIR, f)).size, 0)
  console.log(
    `${results.length} works, ${manifest.reduce((n, w) => n + w.sectionCount, 0)} sections`,
  )
  console.log(`${(results.reduce((n, w) => n + w.words, 0) / 1000).toFixed(0)}k words`)
  console.log(`${(bytes / 1024 / 1024).toFixed(1)}MB → ${path.relative(ROOT, OUT_DIR)}`)
  console.log(`chapter index: ${mapped} homilies mapped, ${unmapped} without a readable reference`)
  console.log(`next: bun scripts/build-works-db.mjs to pack this into assets/works/works.db`)
}

const epub = process.argv[2]
if (!epub) {
  console.error("usage: node scripts/build-works-data.mjs <path-to.epub>")
  process.exit(1)
}
build(epub)
