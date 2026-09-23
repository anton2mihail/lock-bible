/**
 * Shared EPUB reading for the patristic pipeline.
 *
 * Two producers use this: build-works-data.mjs for the Chrysostom compilation,
 * and build-ccel-works.mjs for CCEL's volumes. They differ only in where a
 * work sits in the table of contents, which is why `workDepth` is a parameter -
 * CCEL nests some volumes under author names or thematic groupings, so a work
 * is not always a top-level entry.
 */
import { execFileSync } from "node:child_process"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"

/** Strip a fragment: "text/part0116.html#anchor" -> "text/part0116.html". */
export const filePart = (href) => decodeURIComponent(String(href).split("#")[0])

export function unzip(epubPath) {
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
      pending = { depth: stack.length, title: "", src: "", ancestors: stack.map((p) => p.title) }
      stack.push(pending)
      points.push(pending)
      continue
    }
    if (m[1] !== undefined && pending && !pending.title) {
      pending.title = decodeEntities(m[1].replace(/<[^>]+>/g, ""))
        .replace(/\s+/g, " ")
        .trim()
      continue
    }
    if (m[2] !== undefined && pending && !pending.src) pending.src = m[2]
  }
  return points.filter((p) => p.title && p.src)
}

function decodeEntities(text) {
  return text
    .replace(/&nbsp;|&#160;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
}

export function textOf(html) {
  return decodeEntities(html.replace(/<br\s*\/?>/gi, " ").replace(/<[^>]+>/g, ""))
    .replace(/&[a-z]+;/gi, " ")
    .replace(/\s+/g, " ")
    .trim()
}

const BLOCK = /<(p|h[1-6]|blockquote|li)\b[^>]*>([\s\S]*?)<\/\1>/gi
// CCEL marks footnotes with <sup class="Note">615</sup> inline and prints the
// note bodies in <div class="mnote"> blocks. Left in, the markers weld
// themselves to the preceding word - "faith,616 there hath He placed me" - so
// both go before any text is read.
const FOOTNOTE_MARKER = /<sup\b[^>]*class="Note[^"]*"[^>]*>[\s\S]*?<\/sup>/gi
const FOOTNOTE_BODY = /<div\b[^>]*class="mnote"[^>]*>[\s\S]*?<\/div>/gi

/** Block-level paragraphs from one XHTML file, in order. */
export function paragraphsOf(filePath) {
  if (!fs.existsSync(filePath)) return []
  const html = fs.readFileSync(filePath, "utf8")
  const body = (html.match(/<body[^>]*>([\s\S]*)<\/body>/i)?.[1] ?? html)
    .replace(FOOTNOTE_BODY, "")
    .replace(FOOTNOTE_MARKER, "")
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

/** Titles differ only by a trailing period or curly apostrophe across volumes. */
function normaliseTitle(title) {
  return title
    .toLowerCase()
    .replace(/[\u2018\u2019]/g, "'")
    .replace(/\.$/, "")
    .replace(/\s+/g, " ")
    .trim()
}

export const slugify = (s) =>
  s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 60)

const ROMAN_VALUES = { I: 1, V: 5, X: 10, L: 50, C: 100, D: 500, M: 1000 }

export function romanToNumber(text) {
  const upper = text.toUpperCase()
  if (!upper || ![...upper].every((c) => c in ROMAN_VALUES)) return null
  let total = 0
  let highest = 0
  for (const char of [...upper].reverse()) {
    const value = ROMAN_VALUES[char]
    total += value < highest ? -value : value
    highest = Math.max(highest, value)
  }
  return total || null
}

export function toChapter(raw, max = 200) {
  const value = /^\d+$/.test(raw) ? Number(raw) : romanToNumber(raw)
  return value && value > 0 && value < max ? value : null
}

/**
 * CCEL's per-section files open with the print edition's running head - the
 * work's title broken across lines, a rule of dashes, then "Tractate I." and
 * the section heading again - before the first real sentence. None of it is
 * reading. Only the first few paragraphs are examined, and only ones that are
 * short and recognisably a heading are dropped, so a genuine short opening
 * line (a psalm's superscription, say) survives.
 */
const HEADING_SHAPE =
  /^(tractate|homily|homilies|sermon|discourse|chapter|psalm|book|part|letter|epistle)\s+[ivxlcdm\d]+\.?$/i
const RULE_LINE = /^[\s\u2014\u2013\-._*]+$/

function trimRunningHead(paragraphs, sectionTitle, workTitle) {
  const norm = (s) =>
    s
      .toLowerCase()
      .replace(/[\u2018\u2019]/g, "'")
      .replace(/[^a-z0-9' ]+/g, " ")
      .replace(/\s+/g, " ")
      .trim()
  const section = norm(sectionTitle)
  const work = norm(workTitle ?? "")

  // A rule of dashes near the top is the print edition's divider between its
  // running head and the text. Everything above it is the head, whatever it
  // says - Augustine's Psalms opens "St. Augustin on the Psalms." which
  // matches neither the section nor the work title, and without this the scan
  // below stops on it and leaves the whole head in place.
  const divider = paragraphs.slice(0, 4).findIndex((p) => RULE_LINE.test(p.trim()))
  const body = divider >= 0 ? paragraphs.slice(divider + 1) : paragraphs

  let cut = 0
  for (const paragraph of body.slice(0, 6)) {
    const value = norm(paragraph)
    // The heading repeated verbatim goes however long it is - ANF's chapter
    // titles run to a full sentence and are printed twice. The looser tests
    // stay bounded by length so a genuine short opening line survives.
    const repeatsHeading = value.length > 0 && value === section
    const looksLikeHeading =
      paragraph.length < 120 &&
      // Sources sometimes break one heading across two paragraphs, so match
      // any part of the title, not just its opening.
      ((value.length > 2 && section.includes(value)) ||
        HEADING_SHAPE.test(paragraph.trim()) ||
        RULE_LINE.test(paragraph.trim()) ||
        (value.length > 2 && work.includes(value)))
    if (!repeatsHeading && !looksLikeHeading) break
    cut += 1
  }
  return cut ? body.slice(cut) : body
}

/** Open an EPUB and return everything the work builder needs. */
export function openEpub(epubPath) {
  const dir = unzip(epubPath)
  const opfRel = findRootFile(dir)
  const base = path.dirname(path.join(dir, opfRel))
  const { spine } = parseOpf(path.join(dir, opfRel))
  const ncxRel = fs.readdirSync(base).find((f) => f.endsWith(".ncx")) ?? "toc.ncx"
  const points = parseNcx(path.join(base, ncxRel))
  const spineIndex = new Map(spine.map((href, i) => [href, i]))
  return {
    dir,
    base,
    spine,
    points,
    indexOf: (src) => spineIndex.get(filePart(src)) ?? -1,
  }
}

/**
 * Carve an EPUB into works and their sections.
 *
 * `workDepth` says which TOC level holds a work; anything deeper inside that
 * work's spine range becomes its sections. A work whose range contains no
 * deeper entries becomes a single section named after itself.
 */
export function buildWorks(
  { base, spine, points, indexOf },
  {
    workDepth = 0,
    sectionDepth,
    skipTitles = [],
    skipPrefixes = [],
    workOnlySkipTitles = [],
    skipBetween,
    only,
    under,
  },
) {
  const skip = new Set(skipTitles.map((t) => normaliseTitle(t)))
  const prefixes = skipPrefixes.map((t) => normaliseTitle(t))
  // Titles that mean one thing at the top of a volume and another inside a
  // work. "Preface" is the case: the volume's is its editor's, a treatise's is
  // its author's, and only the depth tells them apart.
  const workOnly = new Set(workOnlySkipTitles.map((t) => normaliseTitle(t)))
  const isSkipped = (title) => {
    const key = normaliseTitle(title)
    return skip.has(key) || prefixes.some((prefix) => key.startsWith(prefix))
  }
  // A skipped node takes its whole subtree with it. CCEL files each volume's
  // subject index under "Subject Indexes" as children named after the works
  // they index, which are otherwise indistinguishable from the works.
  const isBuried = (point) => (point.ancestors ?? []).some(isSkipped)

  // `only` and `under` carve one author out of a shared volume. ANF vol. 1 files
  // its works beneath author names, and NPNF2 vol. 12 holds Leo the Great and
  // Gregory the Great side by side; both need splitting into separate shelves.
  const wanted = only && new Set(only.map(normaliseTitle))
  const parents = under && new Set((Array.isArray(under) ? under : [under]).map(normaliseTitle))

  // Some volumes print rejected works as flat siblings of the genuine ones,
  // announced only by a heading. ANF vol. 1 does this with the spurious
  // Ignatian epistles, and one of them shares its title with Polycarp's real
  // letter to the Philippians, so they can only be excluded by position.
  const excluded = (skipBetween ?? []).map(([from, to]) => {
    const at = (title) => {
      const point = points.find((p) => normaliseTitle(p.title) === normaliseTitle(title))
      return point ? indexOf(point.src) : -1
    }
    return [at(from), at(to)]
  })
  const isExcluded = (point) => {
    const i = indexOf(point.src)
    return excluded.some(([from, to]) => from >= 0 && to > from && i >= from && i < to)
  }

  const works = points.filter(
    (p) =>
      p.depth === workDepth &&
      !isExcluded(p) &&
      !isSkipped(p.title) &&
      !workOnly.has(normaliseTitle(p.title)) &&
      !isBuried(p) &&
      (!wanted || wanted.has(normaliseTitle(p.title))) &&
      (!parents || (p.ancestors ?? []).some((a) => parents.has(normaliseTitle(a)))),
  )
  const results = []

  works.forEach((work) => {
    const start = indexOf(work.src)
    if (start < 0) return
    // A work runs until the next entry at its own level OR ABOVE it begins.
    // Shallower matters: ANF files works beneath author names and npnf210
    // beneath thematic groupings, and stopping only at the next same-depth
    // peer let a work swallow the matter introduced by the next grouping.
    const nextPeer = points.find((p) => p.depth <= workDepth && indexOf(p.src) > start)
    const end = nextPeer ? indexOf(nextPeer.src) : spine.length

    // By default every deeper entry is a section, which suits volumes whose
    // chapters sit two levels down. Pin `sectionDepth` where a level has real
    // meaning and its children are subdivisions of it rather than peers -
    // npnf108 is the case in point: Psalm 119's twenty-two Hebrew-letter
    // divisions belong to that psalm, they are not psalms of their own.
    const children = points.filter(
      (p) =>
        (sectionDepth === undefined ? p.depth > workDepth : p.depth === sectionDepth) &&
        indexOf(p.src) >= start &&
        indexOf(p.src) < end,
    )
    // Front matter inside a work - prefaces, advertisements, its own title
    // page - is navigation, not reading, and CCEL puts plenty of it here.
    const kept = children.filter((c) => !isSkipped(c.title) && !isBuried(c))
    const starts = kept.length
      ? kept.map((c) => ({ title: c.title, at: indexOf(c.src) }))
      : [{ title: work.title, at: start }]

    // Whatever sits between the work's own node and its first child belongs to
    // the work: a letter's salutation, a treatise's opening address. Without
    // this it is read by no section and disappears silently - it cost the
    // Ignatian epistles their salutations and left "Fragments of Lactantius"
    // with no fragments in it. The head stops at the first child whether or
    // not that child is kept, so skipped front matter stays skipped.
    const firstChild = children.length ? indexOf(children[0].src) : end
    if (kept.length && firstChild > start) {
      starts.unshift({ title: work.title, at: start, stop: firstChild })
    }

    const sections = []
    starts.forEach((s, i) => {
      const stop = s.stop ?? (i + 1 < starts.length ? starts[i + 1].at : end)
      const paragraphs = []
      for (let f = s.at; f < stop; f += 1) {
        paragraphs.push(...paragraphsOf(path.join(base, spine[f])))
      }
      const body = trimRunningHead(paragraphs, s.title, work.title)
      if (body.length) {
        sections.push({ id: `s${sections.length + 1}`, title: s.title, paragraphs: body })
      }
    })
    if (!sections.length) return

    const words = sections.reduce(
      (n, s) => n + s.paragraphs.reduce((m, p) => m + p.split(" ").length, 0),
      0,
    )
    results.push({
      id: slugify(work.title),
      title: work.title.replace(/\.$/, ""),
      order: results.length + 1,
      sectionCount: sections.length,
      words,
      sections,
    })
  })

  return results
}

/** Write one collection's intermediate JSON: per-work files, manifest, meta. */
export function writeCollection(outDir, meta, works, chapterIndex) {
  fs.rmSync(outDir, { recursive: true, force: true })
  fs.mkdirSync(outDir, { recursive: true })

  for (const work of works) {
    fs.writeFileSync(path.join(outDir, `${work.id}.json`), JSON.stringify(work))
  }
  fs.writeFileSync(path.join(outDir, "chapterIndex.json"), JSON.stringify(chapterIndex ?? {}))

  const manifest = works.map(({ id, title, order, sectionCount, words, book, kind }) => ({
    id,
    title,
    order,
    sectionCount,
    words,
    book: book ?? null,
    ...(kind ? { kind } : {}),
  }))
  fs.writeFileSync(path.join(outDir, "manifest.json"), JSON.stringify(manifest, null, 2))
  fs.writeFileSync(
    path.join(outDir, "meta.json"),
    JSON.stringify(
      {
        ...meta,
        workCount: works.length,
        sectionCount: works.reduce((n, w) => n + w.sectionCount, 0),
        words: works.reduce((n, w) => n + w.words, 0),
      },
      null,
      2,
    ),
  )
}

/**
 * Assemble one work from a run of table-of-contents entries.
 *
 * NPNF1 vol. 1 needs this: its EPUB nests the whole volume under "About This
 * Book" and has no node for the Confessions at all, so the thirteen books that
 * make it up can only be picked out by name. Sections are the entries from
 * `from` up to but excluding `to`.
 */
export function buildRangeWork(
  { base, spine, points, indexOf },
  { id, title, from, to, depth = 1, splitByFile },
) {
  const at = (needle) => {
    const point = points.find(
      (p) => p.depth === depth && normaliseTitle(p.title) === normaliseTitle(needle),
    )
    return point ? indexOf(point.src) : -1
  }
  const start = at(from)
  const stop = to ? at(to) : spine.length
  if (start < 0 || stop <= start) return undefined

  const members = points.filter((p) => {
    const i = indexOf(p.src)
    return p.depth === depth && i >= start && i < stop
  })
  if (!members.length) return undefined

  const sections = []

  // Some ranges are a single table-of-contents node covering hundreds of
  // files - Augustine's letters are one "Division 1" spanning 173 of them.
  // Left whole that is a 361,000-word section with 3,515 paragraphs, which the
  // paginator measures one by one. Split on the files instead, taking each
  // one's number from its name since these carry no headings.
  if (splitByFile) {
    // The number lives in the file name - "npnf101.vii.1.CXV.html" is Letter
    // 115 - and a long letter is split across sub-part files that repeat their
    // parent's numeral, so files are grouped by it rather than counted. The
    // division's own header file carries no numeral and is not a letter.
    // Case-sensitive, and anchored on the division's own file stem. Both
    // matter: the volume's subject index sits inside this spine range as
    // "npnf101.viii.*.html", whose lowercase "viii" a loose match reads as
    // letter 8 and staples an index onto a genuine letter.
    const NUMBERED = /\.([IVXLCDM]+)(?:\.\d+)?\.x?html?$/
    const prefix = `${spine[start].replace(/\.x?html?$/i, "")}.`
    const grouped = new Map()
    for (let f = start; f < stop; f += 1) {
      if (!spine[f].startsWith(prefix)) continue
      const match = NUMBERED.exec(spine[f])
      if (!match) continue
      const number = romanToNumber(match[1])
      if (!number) continue
      const paragraphs = paragraphsOf(path.join(base, spine[f]))
      if (!paragraphs.length) continue
      const bucket = grouped.get(number)
      if (bucket) bucket.push(...paragraphs)
      else grouped.set(number, [...paragraphs])
    }
    for (const number of [...grouped.keys()].sort((a, b) => a - b)) {
      const label = `${splitByFile.label} ${number}`
      const body = trimRunningHead(grouped.get(number), label, title)
      if (body.length) {
        sections.push({ id: `s${sections.length + 1}`, title: label, paragraphs: body })
      }
    }
  } else {
    members.forEach((member, i) => {
      const sectionStart = indexOf(member.src)
      const sectionStop = i + 1 < members.length ? indexOf(members[i + 1].src) : stop
      const paragraphs = []
      for (let f = sectionStart; f < sectionStop; f += 1) {
        paragraphs.push(...paragraphsOf(path.join(base, spine[f])))
      }
      const body = trimRunningHead(paragraphs, member.title, title)
      if (body.length) {
        sections.push({ id: `s${sections.length + 1}`, title: member.title, paragraphs: body })
      }
    })
  }
  if (!sections.length) return undefined

  return {
    id: id ?? slugify(title),
    title,
    order: 0,
    sectionCount: sections.length,
    words: sections.reduce(
      (n, s) => n + s.paragraphs.reduce((m, p) => m + p.split(" ").length, 0),
      0,
    ),
    sections,
  }
}
