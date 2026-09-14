// @ts-nocheck
/**
 * Build the bundled Bible data from a public-domain USFX source.
 *
 * Sources: public-domain Catholic editions from eBible.org. Every source is
 * normalized to the 73-book Catholic canon before it is emitted.
 *
 * The translation text layer is intentionally pluggable: this script emits a
 * normalized JSON shape that the app consumes through a translation registry,
 * so a future licensed translation (e.g. NRSVCE) can be dropped in by emitting
 * the same shape under a new translation id — no app code changes required.
 *
 * Usage:
 *   node scripts/build-bible-data.mjs             # all translations
 *   node scripts/build-bible-data.mjs web-ce      # one translation
 *
 * It will reuse a cached USFX file at scripts/.cache/<id>_usfx.xml if present,
 * otherwise download + unzip it from ebible.org (requires the `unzip` CLI).
 */

import { execFileSync } from "node:child_process"
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync, readdirSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

import { writeWidgetResources } from "./widget-data-format.mjs"

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = join(__dirname, "..")

// ---- Translation source config -------------------------------------------

const SOURCES = {
  "web-ce": {
    id: "web-ce",
    name: "World English Bible",
    fullName: "World English Bible — Catholic Edition",
    abbreviation: "WEB-CE",
    ebibleId: "eng-web-c",
    language: "en",
    isPublicDomain: true,
    attribution:
      "Scripture quotations are from the World English Bible (Catholic Edition), which is in the public domain.",
    copyrightNotice: "Public Domain. “World English Bible” is a trademark of eBible.org.",
    canonicalReplacements: { EST: "ESG", DAN: "DAG" },
  },
  "douay-rheims": {
    id: "douay-rheims",
    name: "Douay–Rheims",
    fullName: "Douay–Rheims 1899 American Edition",
    abbreviation: "DRB",
    ebibleId: "engDRA",
    language: "en",
    isPublicDomain: true,
    attribution:
      "Scripture quotations are from the public-domain Douay–Rheims American Edition of 1899.",
    copyrightNotice: "Public Domain. Source files courtesy of eBible.org.",
  },
  "vulgate": {
    id: "vulgate",
    name: "Clementine Vulgate",
    fullName: "Clementine Vulgate 1598 — Latin",
    abbreviation: "VUL",
    ebibleId: "latVUC",
    language: "la",
    isPublicDomain: true,
    attribution: "Scripture text is from the public-domain Clementine Vulgate of 1598 in Latin.",
    copyrightNotice: "Public Domain. Source files courtesy of eBible.org.",
  },
}

const CACHE_DIR = join(__dirname, ".cache")
const WIDGET_VERSES_OUT = join(ROOT, "assets", "bible", "widgetVerses.json")
// Random-access resources bundled into the native iOS widget target so it is
// self-sufficient without decoding the complete corpus into memory.
const WIDGET_TARGET_DIR = join(ROOT, "targets", "widget")

const CATHOLIC_BOOK_CODES = [
  "GEN",
  "EXO",
  "LEV",
  "NUM",
  "DEU",
  "JOS",
  "JDG",
  "RUT",
  "1SA",
  "2SA",
  "1KI",
  "2KI",
  "1CH",
  "2CH",
  "EZR",
  "NEH",
  "TOB",
  "JDT",
  "EST",
  "1MA",
  "2MA",
  "JOB",
  "PSA",
  "PRO",
  "ECC",
  "SNG",
  "WIS",
  "SIR",
  "ISA",
  "JER",
  "LAM",
  "BAR",
  "EZK",
  "DAN",
  "HOS",
  "JOL",
  "AMO",
  "OBA",
  "JON",
  "MIC",
  "NAM",
  "HAB",
  "ZEP",
  "HAG",
  "ZEC",
  "MAL",
  "MAT",
  "MRK",
  "LUK",
  "JHN",
  "ACT",
  "ROM",
  "1CO",
  "2CO",
  "GAL",
  "EPH",
  "PHP",
  "COL",
  "1TH",
  "2TH",
  "1TI",
  "2TI",
  "TIT",
  "PHM",
  "HEB",
  "JAS",
  "1PE",
  "2PE",
  "1JN",
  "2JN",
  "3JN",
  "JUD",
  "REV",
]

// ---- Canon classification -------------------------------------------------

const NT_CODES = new Set([
  "MAT",
  "MRK",
  "LUK",
  "JHN",
  "ACT",
  "ROM",
  "1CO",
  "2CO",
  "GAL",
  "EPH",
  "PHP",
  "COL",
  "1TH",
  "2TH",
  "1TI",
  "2TI",
  "TIT",
  "PHM",
  "HEB",
  "JAS",
  "1PE",
  "2PE",
  "1JN",
  "2JN",
  "3JN",
  "JUD",
  "REV",
])

const DEUTERO_CODES = new Set([
  "TOB",
  "JDT",
  "ESG",
  "WIS",
  "SIR",
  "BAR",
  "1MA",
  "2MA",
  "1ES",
  "MAN",
  "PS2",
  "3MA",
  "2ES",
  "4MA",
  "DAG",
  "LJE",
  "S3Y",
  "SUS",
  "BEL",
])

function groupFor(code) {
  if (NT_CODES.has(code)) return "nt"
  if (DEUTERO_CODES.has(code)) return "deutero"
  return "ot"
}

// ---- USFX parsing ---------------------------------------------------------

// Elements whose entire subtree is non-scripture (footnotes, cross refs, figs).
const SKIP_ELEMENTS = new Set(["f", "fe", "x", "ex", "fig", "rem", "ide", "ndx"])
// Block elements that terminate the current verse (headings, titles, refs).
const HEADING_ELEMENTS = new Set([
  "s",
  "s1",
  "s2",
  "s3",
  "s4",
  "ms",
  "ms1",
  "ms2",
  "ms3",
  "mr",
  "mt",
  "mt1",
  "mt2",
  "mt3",
  "mt4",
  "mte",
  "r",
  "sr",
  "d",
  "sp",
  "qa",
  "cl",
  "cp",
  "periph",
  "iex",
  "ip",
  "im",
  "io",
  "io1",
  "io2",
  "is",
  "imt",
  "toc",
  "h",
  "id",
])

const ENTITIES = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'" }

function decodeEntities(s) {
  return s.replace(/&(#x?[0-9a-fA-F]+|[a-zA-Z]+);/g, (m, code) => {
    if (code[0] === "#") {
      const cp =
        code[1] === "x" || code[1] === "X"
          ? parseInt(code.slice(2), 16)
          : parseInt(code.slice(1), 10)
      return Number.isFinite(cp) ? String.fromCodePoint(cp) : m
    }
    return ENTITIES[code] ?? m
  })
}

function collapse(s) {
  return decodeEntities(s).replace(/\s+/g, " ").trim()
}

function attr(raw, name) {
  const m = raw.match(new RegExp(`${name}\\s*=\\s*"([^"]*)"`))
  return m ? m[1] : undefined
}

/**
 * Parse the USFX XML into an ordered list of books:
 *   { code, name, longName, group, chapters: [{ c, verses: [{ n, t }] }] }
 */
function parseUsfx(xml, bookNames) {
  const books = []
  let book = null
  let chapter = null
  let verseNum = null
  let buf = ""
  let skipDepth = 0

  // Stack of currently-open element names, so we can match skip elements that
  // contain nested tags before their close.
  const stack = []

  const flushVerse = () => {
    if (book && chapter && verseNum != null) {
      const t = collapse(buf)
      if (t) chapter.verses.push({ n: verseNum, t })
    }
    verseNum = null
    buf = ""
  }

  const tagRe = /<(\/?)([a-zA-Z][\w-]*)((?:[^>"']|"[^"]*"|'[^']*')*?)(\/?)\s*>/g
  let last = 0
  let m
  while ((m = tagRe.exec(xml))) {
    const text = xml.slice(last, m.index)
    if (text && skipDepth === 0 && verseNum != null) buf += text
    last = tagRe.lastIndex

    const closing = m[1] === "/"
    const name = m[2]
    const rawAttrs = m[3]
    const selfClose = m[4] === "/"

    if (SKIP_ELEMENTS.has(name)) {
      if (closing) skipDepth = Math.max(0, skipDepth - 1)
      else if (!selfClose) skipDepth++
      continue
    }

    if (closing) {
      // pop matching from stack (best-effort)
      const idx = stack.lastIndexOf(name)
      if (idx !== -1) stack.length = idx
      continue
    }

    switch (name) {
      case "book": {
        flushVerse()
        const code = attr(rawAttrs, "id")
        const meta = bookNames[code] || {}
        book = {
          code,
          name: meta.short || code,
          longName: meta.long || meta.short || code,
          group: groupFor(code),
          chapters: [],
        }
        books.push(book)
        chapter = null
        break
      }
      case "c": {
        flushVerse()
        const cn = parseInt(attr(rawAttrs, "id") || "0", 10)
        chapter = { c: cn, verses: [] }
        if (book) book.chapters.push(chapter)
        break
      }
      case "v": {
        flushVerse()
        verseNum = attr(rawAttrs, "id") || null
        buf = ""
        break
      }
      case "ve": {
        flushVerse()
        break
      }
      default:
        if (HEADING_ELEMENTS.has(name)) flushVerse()
        break
    }

    if (!selfClose && !SKIP_ELEMENTS.has(name)) stack.push(name)
  }
  flushVerse()

  // Drop any books that ended up with no verses (e.g. front matter peripherals).
  return books.filter((b) => b.chapters.some((c) => c.verses.length > 0))
}

function parseBookNames(xml) {
  const map = {}
  const re = /<book\s+([^>]*?)\/>/g
  let m
  while ((m = re.exec(xml))) {
    const raw = m[1]
    const code = attr(raw, "code")
    if (!code) continue
    map[code] = { short: attr(raw, "short"), long: attr(raw, "long"), abbr: attr(raw, "abbr") }
  }
  return map
}

// ---- Source acquisition ---------------------------------------------------

function ensureSource(source) {
  const sourceCache = join(CACHE_DIR, source.ebibleId)
  mkdirSync(sourceCache, { recursive: true })
  const xmlPath = join(sourceCache, `${source.ebibleId}_usfx.xml`)
  const namesPath = join(sourceCache, "BookNames.xml")
  if (existsSync(xmlPath) && existsSync(namesPath)) {
    return { xmlPath, namesPath }
  }
  const zipUrl = `https://ebible.org/Scriptures/${source.ebibleId}_usfx.zip`
  const zipPath = join(sourceCache, `${source.ebibleId}_usfx.zip`)
  console.log(`Downloading ${zipUrl} ...`)
  execFileSync("curl", ["-sSL", "--max-time", "120", "-o", zipPath, zipUrl], { stdio: "inherit" })
  console.log("Unzipping ...")
  execFileSync("unzip", ["-o", "-q", zipPath, "-d", sourceCache], { stdio: "inherit" })
  return { xmlPath, namesPath }
}

// ---- Emit -----------------------------------------------------------------

function normalizeCatholicCanon(books, source) {
  const byCode = new Map(books.map((book) => [book.code, book]))
  const normalized = CATHOLIC_BOOK_CODES.map((code) => {
    const sourceCode = source.canonicalReplacements?.[code] ?? code
    const book = byCode.get(sourceCode)
    if (!book) throw new Error(`${source.id} is missing canonical book ${code} (${sourceCode})`)
    if (sourceCode === code) return { ...book, group: groupFor(code) }
    return {
      ...book,
      code,
      name: code === "EST" ? "Esther" : "Daniel",
      longName: code === "EST" ? "The Book of Esther" : "The Book of Daniel",
      group: "ot",
    }
  })
  if (normalized.length !== 73)
    throw new Error(`Expected 73 Catholic books, found ${normalized.length}`)
  return normalized
}

function emit(source, books) {
  const outDir = join(ROOT, "src", "services", "bible", "data", source.id)
  // Clean output dir of generated data (keep nothing stale).
  if (existsSync(outDir)) {
    for (const f of readdirSync(outDir)) {
      if (f.endsWith(".json") || f === "index.ts") rmSync(join(outDir, f))
    }
  }
  mkdirSync(outDir, { recursive: true })
  mkdirSync(dirname(WIDGET_VERSES_OUT), { recursive: true })

  const manifest = []
  for (let i = 0; i < books.length; i++) {
    const b = books[i]
    const data = {
      code: b.code,
      name: b.name,
      longName: b.longName,
      group: b.group,
      chapters: b.chapters.map((c) => ({ c: c.c, verses: c.verses })),
    }
    writeFileSync(join(outDir, `${b.code}.json`), JSON.stringify(data))
    manifest.push({
      code: b.code,
      name: b.name,
      longName: b.longName,
      group: b.group,
      order: i,
      chapterCount: b.chapters.length,
    })
  }

  writeFileSync(join(outDir, "manifest.json"), JSON.stringify(manifest, null, 2))

  // Static require index — Metro needs literal require paths, so we generate
  // one lazy thunk per book. The thunks defer JSON parse until a book is opened.
  const lines = [
    "// AUTO-GENERATED by scripts/build-bible-data.mjs — do not edit by hand.",
    'import type { BookData } from "../../types"',
    "",
    "export const bookLoaders: Record<string, () => BookData> = {",
    ...books.map((b) => `  "${b.code}": () => require("./${b.code}.json") as BookData,`),
    "}",
    "",
  ]
  writeFileSync(join(outDir, "index.ts"), lines.join("\n"))

  // Complete widget verse pool. The selection algorithm permutes these entries
  // so every verse appears once per cycle before any reference repeats.
  const widgetVerses = books.flatMap((book) =>
    book.chapters.flatMap((chapter) =>
      chapter.verses.map((verse) => ({
        ref: `${book.name} ${chapter.c}:${verse.n}`,
        book: book.code,
        chapter: chapter.c,
        verse: verse.n,
        text: verse.t,
        group: book.group,
      })),
    ),
  )
  const widgetPayload = {
    translationId: source.id,
    translationName: source.fullName,
    abbreviation: source.abbreviation,
    attribution: source.attribution,
    generatedFrom: source.ebibleId,
    verses: widgetVerses,
  }
  writeFileSync(join(outDir, "widgetVerses.json"), JSON.stringify(widgetPayload))
  if (source.id === "web-ce") writeFileSync(WIDGET_VERSES_OUT, JSON.stringify(widgetPayload))
  writeWidgetResources(widgetVerses, WIDGET_TARGET_DIR, source.id)

  // Translation metadata sidecar (consumed by the registry).
  writeFileSync(
    join(outDir, "meta.json"),
    JSON.stringify(
      {
        id: source.id,
        name: source.name,
        fullName: source.fullName,
        abbreviation: source.abbreviation,
        language: source.language,
        isPublicDomain: source.isPublicDomain,
        attribution: source.attribution,
        copyrightNotice: source.copyrightNotice,
      },
      null,
      2,
    ),
  )

  return { books: books.length, widgetVerses: widgetVerses.length, outDir }
}

// ---- Main -----------------------------------------------------------------

const requestedIds = process.argv.slice(2)
const selectedIds = requestedIds.length ? requestedIds : Object.keys(SOURCES)
for (const id of selectedIds) {
  const source = SOURCES[id]
  if (!source)
    throw new Error(`Unknown translation '${id}'. Choose: ${Object.keys(SOURCES).join(", ")}`)
  const { xmlPath, namesPath } = ensureSource(source)
  console.log(`Parsing ${source.fullName} ...`)
  const xml = readFileSync(xmlPath, "utf8")
  const bookNames = parseBookNames(readFileSync(namesPath, "utf8"))
  const books = normalizeCatholicCanon(parseUsfx(xml, bookNames), source)

  let totalVerses = 0
  for (const book of books)
    for (const chapter of book.chapters) totalVerses += chapter.verses.length

  const result = emit(source, books)
  console.log(
    `Done: ${result.books} books, ${totalVerses} verses, ${result.widgetVerses} widget verses.`,
  )
  console.log(`  -> ${result.outDir}`)
}
