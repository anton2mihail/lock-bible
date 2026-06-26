// @ts-nocheck
/**
 * Build the bundled Bible data from a public-domain USFX source.
 *
 * Default source: World English Bible — Catholic Edition (WEB-CE), public
 * domain, full deuterocanon. https://ebible.org/eng-web-c/
 *
 * The translation text layer is intentionally pluggable: this script emits a
 * normalized JSON shape that the app consumes through a translation registry,
 * so a future licensed translation (e.g. NRSVCE) can be dropped in by emitting
 * the same shape under a new translation id — no app code changes required.
 *
 * Usage:
 *   node scripts/build-bible-data.mjs
 *
 * It will reuse a cached USFX file at scripts/.cache/<id>_usfx.xml if present,
 * otherwise download + unzip it from ebible.org (requires the `unzip` CLI).
 */

import { execFileSync } from "node:child_process"
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync, readdirSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = join(__dirname, "..")

// ---- Translation source config -------------------------------------------

const SOURCE = {
  id: "web-ce",
  name: "World English Bible",
  fullName: "World English Bible — Catholic Edition",
  abbreviation: "WEB-CE",
  ebibleId: "eng-web-c",
  language: "en",
  isPublicDomain: true,
  // Attribution shown in-app. WEB is public domain; "World English Bible" is a
  // trademark of eBible.org, so we credit it but no permission is required.
  attribution:
    "Scripture quotations are from the World English Bible (Catholic Edition), which is in the public domain.",
  copyrightNotice: "Public Domain. “World English Bible” is a trademark of eBible.org.",
}

const CACHE_DIR = join(__dirname, ".cache")
const OUT_DIR = join(ROOT, "src", "services", "bible", "data", SOURCE.id)
const WIDGET_VERSES_OUT = join(ROOT, "assets", "bible", "widgetVerses.json")
// A copy bundled into the native iOS widget target so it is self-sufficient
// (renders correctly even before the app has ever been opened).
const WIDGET_TARGET_OUT = join(ROOT, "targets", "widget", "widgetVerses.json")

// ---- Canon classification -------------------------------------------------

const NT_CODES = new Set([
  "MAT", "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH", "PHP",
  "COL", "1TH", "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS", "1PE", "2PE",
  "1JN", "2JN", "3JN", "JUD", "REV",
])

const DEUTERO_CODES = new Set([
  "TOB", "JDT", "ESG", "WIS", "SIR", "BAR", "1MA", "2MA", "1ES", "MAN", "PS2",
  "3MA", "2ES", "4MA", "DAG", "LJE", "S3Y", "SUS", "BEL",
])

function groupFor(code) {
  if (NT_CODES.has(code)) return "nt"
  if (DEUTERO_CODES.has(code)) return "deutero"
  return "ot"
}

// ---- Curated widget verse pool -------------------------------------------
// Short, encouraging, well-known verses. Order here defines the rotation order
// shared verbatim by the JS app and the native widget. Keep references that
// exist in WEB-CE; any that fail to resolve are dropped with a warning.

const WIDGET_REFS = [
  "JHN 3:16", "PSA 23:1", "PSA 23:4", "PHP 4:13", "PHP 4:6", "ROM 8:28",
  "PRO 3:5", "PRO 3:6", "JER 29:11", "ISA 41:10", "ISA 40:31", "MAT 6:33",
  "MAT 11:28", "JOS 1:9", "PSA 46:1", "PSA 46:10", "PSA 27:1", "PSA 118:24",
  "PSA 119:105", "1CO 13:13", "2CO 5:7", "2CO 12:9", "EPH 2:8", "HEB 11:1",
  "HEB 13:5", "JAS 1:5", "1PE 5:7", "1JN 4:19", "PSA 34:8", "PSA 37:4",
  "PSA 55:22", "PSA 91:1", "PSA 139:14", "PSA 145:18", "MIC 6:8", "ZEP 3:17",
  "NAM 1:7", "MAT 5:9", "MAT 5:16", "MAT 28:20", "LUK 1:37", "JHN 8:12",
  "JHN 14:6", "JHN 14:27", "JHN 15:13", "JHN 16:33", "ACT 1:8", "ROM 5:8",
  "ROM 12:2", "ROM 12:12", "ROM 15:13", "1CO 10:13", "1CO 16:14", "2CO 4:18",
  "EPH 4:32", "EPH 6:10", "PHP 1:6", "PHP 4:7", "PHP 4:8", "COL 3:23",
  "2TI 1:7", "HEB 12:2", "1PE 4:8", "1JN 1:9", "REV 21:4", "PSA 121:2",
  "PSA 147:3", "PRO 16:3", "ISA 26:3", "MAT 7:7", "LUK 6:31", "GAL 6:9",
  "1TH 5:16", "1TH 5:18", "PSA 28:7", "PSA 73:26", "PSA 16:8",
  // Deuterocanon — Catholic distinctives
  "WIS 3:1", "SIR 2:6", "TOB 4:7", "WIS 7:7", "SIR 6:14",
]

// ---- USFX parsing ---------------------------------------------------------

// Elements whose entire subtree is non-scripture (footnotes, cross refs, figs).
const SKIP_ELEMENTS = new Set(["f", "fe", "x", "ex", "fig", "rem", "ide", "ndx"])
// Block elements that terminate the current verse (headings, titles, refs).
const HEADING_ELEMENTS = new Set([
  "s", "s1", "s2", "s3", "s4", "ms", "ms1", "ms2", "ms3", "mr", "mt", "mt1",
  "mt2", "mt3", "mt4", "mte", "r", "sr", "d", "sp", "qa", "cl", "cp", "periph",
  "iex", "ip", "im", "io", "io1", "io2", "is", "imt", "toc", "h", "id",
])

const ENTITIES = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'" }

function decodeEntities(s) {
  return s.replace(/&(#x?[0-9a-fA-F]+|[a-zA-Z]+);/g, (m, code) => {
    if (code[0] === "#") {
      const cp = code[1] === "x" || code[1] === "X"
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

function ensureSource() {
  mkdirSync(CACHE_DIR, { recursive: true })
  const xmlPath = join(CACHE_DIR, `${SOURCE.ebibleId}_usfx.xml`)
  const namesPath = join(CACHE_DIR, "BookNames.xml")
  if (existsSync(xmlPath) && existsSync(namesPath)) {
    return { xmlPath, namesPath }
  }
  const zipUrl = `https://ebible.org/Scriptures/${SOURCE.ebibleId}_usfx.zip`
  const zipPath = join(CACHE_DIR, `${SOURCE.ebibleId}_usfx.zip`)
  console.log(`Downloading ${zipUrl} ...`)
  execFileSync("curl", ["-sSL", "--max-time", "120", "-o", zipPath, zipUrl], { stdio: "inherit" })
  console.log("Unzipping ...")
  execFileSync("unzip", ["-o", "-q", zipPath, "-d", CACHE_DIR], { stdio: "inherit" })
  return { xmlPath, namesPath }
}

// ---- Verse lookup for widget pool ----------------------------------------

function buildIndex(books) {
  const idx = new Map()
  for (const b of books) {
    const byChap = new Map()
    for (const ch of b.chapters) {
      const byVerse = new Map()
      for (const v of ch.verses) byVerse.set(v.n, v.t)
      byChap.set(ch.c, byVerse)
    }
    idx.set(b.code, { book: b, byChap })
  }
  return idx
}

function resolveRef(idx, ref) {
  // ref like "JHN 3:16" or "PSA 121:1-2"
  const m = ref.match(/^([0-9A-Z]+)\s+(\d+):(\d+)(?:-(\d+))?$/)
  if (!m) return null
  const [, code, c, v1, v2] = m
  const entry = idx.get(code)
  if (!entry) return null
  const byVerse = entry.byChap.get(parseInt(c, 10))
  if (!byVerse) return null
  const start = parseInt(v1, 10)
  const end = v2 ? parseInt(v2, 10) : start
  const parts = []
  for (let n = start; n <= end; n++) {
    const t = byVerse.get(String(n))
    if (t) parts.push(t)
  }
  if (!parts.length) return null
  return {
    ref: `${entry.book.name} ${c}:${v2 ? `${v1}-${v2}` : v1}`,
    book: code,
    chapter: parseInt(c, 10),
    verse: v1,
    text: parts.join(" "),
    // Testament group, so the app/widget can filter the pool to OT-only or
    // NT-only. For a Catholic Bible, "OT" includes the deuterocanon.
    group: groupFor(code),
  }
}

// ---- Emit -----------------------------------------------------------------

function emit(books) {
  // Clean output dir of generated data (keep nothing stale).
  if (existsSync(OUT_DIR)) {
    for (const f of readdirSync(OUT_DIR)) {
      if (f.endsWith(".json") || f === "index.ts") rmSync(join(OUT_DIR, f))
    }
  }
  mkdirSync(OUT_DIR, { recursive: true })
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
    writeFileSync(join(OUT_DIR, `${b.code}.json`), JSON.stringify(data))
    manifest.push({
      code: b.code,
      name: b.name,
      longName: b.longName,
      group: b.group,
      order: i,
      chapterCount: b.chapters.length,
    })
  }

  writeFileSync(join(OUT_DIR, "manifest.json"), JSON.stringify(manifest, null, 2))

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
  writeFileSync(join(OUT_DIR, "index.ts"), lines.join("\n"))

  // Widget verse pool.
  const idx = buildIndex(books)
  const widgetVerses = []
  for (const ref of WIDGET_REFS) {
    const resolved = resolveRef(idx, ref)
    if (resolved) widgetVerses.push(resolved)
    else console.warn(`  ! widget ref unresolved, skipping: ${ref}`)
  }
  const widgetPayload = {
    translationId: SOURCE.id,
    translationName: SOURCE.fullName,
    abbreviation: SOURCE.abbreviation,
    attribution: SOURCE.attribution,
    generatedFrom: SOURCE.ebibleId,
    verses: widgetVerses,
  }
  writeFileSync(WIDGET_VERSES_OUT, JSON.stringify(widgetPayload, null, 2))
  mkdirSync(dirname(WIDGET_TARGET_OUT), { recursive: true })
  writeFileSync(WIDGET_TARGET_OUT, JSON.stringify(widgetPayload, null, 2))

  // Translation metadata sidecar (consumed by the registry).
  writeFileSync(
    join(OUT_DIR, "meta.json"),
    JSON.stringify(
      {
        id: SOURCE.id,
        name: SOURCE.name,
        fullName: SOURCE.fullName,
        abbreviation: SOURCE.abbreviation,
        language: SOURCE.language,
        isPublicDomain: SOURCE.isPublicDomain,
        attribution: SOURCE.attribution,
        copyrightNotice: SOURCE.copyrightNotice,
      },
      null,
      2,
    ),
  )

  return { books: books.length, widgetVerses: widgetVerses.length }
}

// ---- Main -----------------------------------------------------------------

const { xmlPath, namesPath } = ensureSource()
console.log("Parsing USFX ...")
const xml = readFileSync(xmlPath, "utf8")
const bookNames = parseBookNames(readFileSync(namesPath, "utf8"))
const books = parseUsfx(xml, bookNames)

let totalVerses = 0
for (const b of books) for (const c of b.chapters) totalVerses += c.verses.length

const result = emit(books)
console.log(
  `Done: ${result.books} books, ${totalVerses} verses, ${result.widgetVerses} widget verses.`,
)
console.log(`  -> ${OUT_DIR}`)
console.log(`  -> ${WIDGET_VERSES_OUT}`)
