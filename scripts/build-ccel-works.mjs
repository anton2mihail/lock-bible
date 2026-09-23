#!/usr/bin/env node
/**
 * Turn CCEL's ANF/NPNF volumes into the intermediate JSON the works pipeline
 * reads, then hand off to build-works-db.mjs.
 *
 *   node scripts/build-ccel-works.mjs [collectionId ...]
 *
 * Source: the EPUBs at
 * https://www.ccel.org/ccel/s/schaff/<volume>/cache/<volume>.epub, cached
 * locally by scripts/fetch-ccel.mjs. The translations are the Ante-Nicene
 * Fathers (Roberts & Donaldson, 1885-87) and the Nicene and Post-Nicene
 * Fathers (Schaff, 1886-1900) - every volume's own ThML metadata records
 * DC.Rights as Public Domain, and the print sources are all pre-1929.
 *
 * Only extracted paragraph text is kept. Every CCEL-authored node is skipped by
 * title: "About This Book" is CCEL's own modern blurb, and the indexes, subject
 * indexes and print-edition page concordances are apparatus rather than text.
 * Prolegomena are dropped too - in several volumes those are a named Victorian
 * editor's own essay, not the Father's words, and this app should not present
 * one as the other.
 *
 * There is no generic rule for where a work sits in a CCEL table of contents.
 * npnf102 puts works at depth 0, npnf103 nests them under thematic groupings at
 * depth 1, and npnf101's TOC has no work nodes at all. Hence the table below:
 * one short entry per volume, each eyeballed against its actual TOC.
 */
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

import { buildRangeWork, buildWorks, openEpub, toChapter, writeCollection } from "./lib/epub.mjs"

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const CACHE = path.join(ROOT, ".ccel-cache")
const DATA_ROOT = path.join(ROOT, "src", "services", "works", "data")

/** Apparatus and CCEL-authored matter, skipped at every depth. */
const COMMON_SKIP = [
  "About This Book",
  "Title Page",
  "Second Title Page",
  "Table of Contents",
  "Contents",
  "Credits",
  // NB: no bare "Preface". CCEL uses that title both for a volume editor's
  // preface and for the Father's own - Origen opens De Principiis with his,
  // Lactantius the Divine Institutes with his - and skipping it by title took
  // the authors' with the editors'. The editors' are removed by name in
  // EDITORIAL below instead.
  "Editor's Preface",
  "Editor’s Preface",
  "Translator's Preface",
  "Translator’s Preface",
  "Advertisement",
  "Indexes",
  "Index of Subjects",
  "Subject Index",
  "Subject Indexes",
  "Index of Scripture References",
  "Index of Pages of the Print Edition",
  "Greek Words and Phrases",
  "Hebrew Words and Phrases",
  "Latin Words and Phrases",
  "German Words and Phrases",
  "French Words and Phrases",
  "Series Title",
  "Prolegomena",
  "Introductory Essay",
  "Introductory Essay.",
  "Bibliography",
  "Editorial Preface",
  "Chronological Table",
  "Chronological Tables",
  "Genealogical Tables",
  "Dates of Treatises, &c., Here Translated.",
]

/**
 * Matched against the start of a title. These vary per volume - "Introductory
 * Essay on the Manichæan Heresy", "Preface to Volume II. Of the Edinburgh
 * Edition" - and are all the nineteenth-century editor writing rather than the
 * Father. A skipped node takes its subtree, which is what removes each volume's
 * subject index; CCEL names those children after the works they index.
 */
const WORK_ONLY_SKIP = ["Preface", "Introduction", "Note", "Prefatory Note", "Prefatory Notice"]

const COMMON_SKIP_PREFIXES = [
  "Introductory Essay",
  "Introductory Note",
  "Introductory Notice",
  "Preface to",
  "Dedication of",
  "Index of",
  "Indexes",
  "Prolegomena",
  "Appendix",
  "Subject Index",
  "A Select Bibliography",
  "Elucidation",
]

const NPNF1 = {
  translation: "Nicene and Post-Nicene Fathers, first series (Philip Schaff, 1886–1890)",
  attribution:
    "Translated in the Nicene and Post-Nicene Fathers, first series, edited by Philip Schaff (1886–1890). The translation is in the public domain.",
}

const NPNF2 = {
  translation: "Nicene and Post-Nicene Fathers, second series (Schaff & Wace, 1890–1900)",
  attribution:
    "Translated in the Nicene and Post-Nicene Fathers, second series, edited by Philip Schaff and Henry Wace (1890–1900). The translation is in the public domain.",
}

const ANF = {
  translation: "Ante-Nicene Fathers (Alexander Roberts & James Donaldson, 1885–1887)",
  attribution:
    "Translated in the Ante-Nicene Fathers, edited by Alexander Roberts and James Donaldson (1885–1887). The translation is in the public domain.",
}

const DOMINICAN = {
  translation: "Translated by the Fathers of the English Dominican Province (1911–1925)",
  attribution:
    "Translated by the Fathers of the English Dominican Province (1911–1925). The translation is in the public domain.",
}

/**
 * One entry per shelf. `order` is reading order in the library, roughly
 * chronological, with the Doctors who carry the most weight first.
 *
 * A volume entry says where that volume hides its works. `only` and `under`
 * split volumes that hold more than one author - ANF vol. 1 files everything
 * beneath author names, and NPNF2 vol. 12 is Leo the Great and Gregory the
 * Great bound together.
 */
const COLLECTIONS = [
  {
    id: "augustine",
    title: "The Works of St Augustine",
    author: "St Augustine of Hippo",
    era: "Latin Father, 4th–5th century",
    order: 1,
    ...NPNF1,
    volumes: [
      {
        volume: "npnf101",
        workDepth: 0,
        rangeWorks: [
          { title: "The Confessions", from: "Book I", to: "Division 1" },
          {
            title: "The Letters of St Augustine",
            from: "Division 1",
            to: "Index of Scripture References",
            splitByFile: { label: "Letter" },
          },
        ],
      },
      { volume: "npnf102", workDepth: 0 },
      { volume: "npnf103", workDepth: 1 },
      { volume: "npnf104", workDepth: 1 },
      { volume: "npnf105", workDepth: 0 },
      { volume: "npnf106", workDepth: 0 },
      { volume: "npnf107", workDepth: 0 },
      { volume: "npnf108", workDepth: 0, sectionDepth: 1 },
    ],
  },
  {
    id: "aquinas",
    title: "The Summa Theologica",
    author: "St Thomas Aquinas",
    era: "Doctor of the Church, 13th century",
    order: 3,
    ...DOMINICAN,
    volumes: [{ volume: "summa", workDepth: 0, skip: ["Appendix"] }],
  },
  {
    id: "jerome",
    title: "The Letters and Treatises of St Jerome",
    author: "St Jerome",
    era: "Latin Father, 4th–5th century",
    order: 4,
    ...NPNF2,
    volumes: [{ volume: "npnf206", workDepth: 0 }],
  },
  {
    id: "gregory-great",
    title: "The Works of St Gregory the Great",
    author: "St Gregory the Great",
    era: "Pope and Doctor, 6th century",
    order: 5,
    ...NPNF2,
    volumes: [
      {
        volume: "npnf212",
        workDepth: 0,
        only: ["The Book of Pastoral Rule, and Selected Epistles, of Gregory the Great."],
      },
      { volume: "npnf213", workDepth: 0, only: ["Selected Epistles of Gregory the Great."] },
    ],
  },
  {
    id: "ambrose",
    title: "The Works of St Ambrose",
    author: "St Ambrose of Milan",
    era: "Latin Father, 4th century",
    order: 6,
    ...NPNF2,
    volumes: [{ volume: "npnf210", workDepth: 1 }],
  },
  {
    id: "athanasius",
    title: "The Works of St Athanasius",
    author: "St Athanasius",
    era: "Greek Father, 4th century",
    order: 7,
    ...NPNF2,
    volumes: [{ volume: "npnf204", workDepth: 0 }],
  },
  {
    id: "basil",
    title: "The Works of St Basil the Great",
    author: "St Basil the Great",
    era: "Greek Father, 4th century",
    order: 8,
    ...NPNF2,
    volumes: [{ volume: "npnf208", workDepth: 0 }],
  },
  {
    id: "gregory-nazianzen",
    title: "The Orations and Letters of St Gregory Nazianzen",
    author: "St Gregory Nazianzen",
    era: "Greek Father, 4th century",
    order: 9,
    ...NPNF2,
    volumes: [
      {
        volume: "npnf207",
        workDepth: 0,
        only: [
          "Select Orations of Saint Gregory Nazianzen.",
          "Select Letters of Saint Gregory Nazianzen.",
        ],
      },
    ],
  },
  {
    id: "gregory-nyssa",
    title: "The Works of St Gregory of Nyssa",
    author: "St Gregory of Nyssa",
    era: "Greek Father, 4th century",
    order: 10,
    ...NPNF2,
    volumes: [{ volume: "npnf205", workDepth: 1 }],
  },
  {
    id: "cyril-jerusalem",
    title: "The Catechetical Lectures",
    author: "St Cyril of Jerusalem",
    era: "Doctor of the Church, 4th century",
    order: 11,
    ...NPNF2,
    volumes: [
      { volume: "npnf207", workDepth: 0, only: ["The Catechetical Lectures of S. Cyril."] },
    ],
  },
  {
    id: "john-damascene",
    title: "An Exposition of the Orthodox Faith",
    author: "St John Damascene",
    era: "Doctor of the Church, 8th century",
    order: 12,
    ...NPNF2,
    volumes: [{ volume: "npnf209", workDepth: 0 }],
  },
  {
    id: "leo-great",
    title: "The Letters and Sermons of St Leo the Great",
    author: "St Leo the Great",
    era: "Pope and Doctor, 5th century",
    order: 13,
    ...NPNF2,
    volumes: [
      { volume: "npnf212", workDepth: 0, only: ["The Letters and Sermons of Leo the Great."] },
    ],
  },
  {
    id: "cassian",
    title: "The Institutes and Conferences",
    author: "St John Cassian",
    era: "Monastic Father, 5th century",
    order: 14,
    ...NPNF2,
    volumes: [{ volume: "npnf211", workDepth: 0, only: ["The Works of John Cassian."] }],
  },
  {
    id: "ephraim",
    title: "Hymns and Homilies",
    author: "St Ephraim the Syrian",
    era: "Doctor of the Church, 4th century",
    order: 15,
    ...NPNF2,
    volumes: [
      {
        volume: "npnf213",
        workDepth: 0,
        only: [
          "Selections from the Hymns and Homilies of Ephraim the Syrian and from the Demonstrations of Aphrahat the Persian Sage.",
        ],
      },
    ],
  },
  {
    id: "eusebius",
    title: "The Church History",
    author: "Eusebius of Caesarea",
    era: "Historian, 4th century",
    order: 16,
    ...NPNF2,
    volumes: [{ volume: "npnf201", workDepth: 0 }],
  },
  {
    id: "vincent-lerins",
    title: "The Commonitory",
    author: "St Vincent of Lérins",
    era: "Monastic Father, 5th century",
    order: 17,
    ...NPNF2,
    volumes: [
      {
        volume: "npnf211",
        workDepth: 0,
        only: [
          "The Commonitory of Vincent of Lérins, For the Antiquity and Universality of the Catholic Faith Against the Profane Novelties of All Heresies.",
        ],
      },
    ],
  },
  {
    id: "apostolic-fathers",
    title: "The Apostolic Fathers",
    author: "The Apostolic Fathers",
    era: "1st–2nd century",
    order: 18,
    ...ANF,
    volumes: [
      {
        volume: "anf01",
        workDepth: 1,
        under: ["CLEMENT OF ROME", "MATHETES", "POLYCARP", "IGNATIUS", "BARNABAS", "PAPIAS"],
        // Universally rejected as forgeries; ANF prints them beside the genuine
        // letters, and presenting them as Ignatius would be an error of substance.
        skipBetween: [
          [
            "Introductory Note to the Spurious Epistles of Ignatius",
            "Introductory Note to the Martyrdom of Ignatius",
          ],
        ],
      },
      { volume: "anf02", workDepth: 1, under: ["THE PASTOR OF HERMAS"] },
      { volume: "anf07", workDepth: 1, under: ["The Teaching of the Twelve Apostles"] },
    ],
  },
  {
    id: "justin-martyr",
    title: "The Apologies and the Dialogue with Trypho",
    author: "St Justin Martyr",
    era: "Apologist, 2nd century",
    order: 19,
    ...ANF,
    volumes: [{ volume: "anf01", workDepth: 1, under: ["JUSTIN MARTYR"] }],
  },
  {
    id: "irenaeus",
    title: "Against Heresies",
    author: "St Irenaeus of Lyons",
    era: "Doctor of the Church, 2nd century",
    order: 20,
    ...ANF,
    volumes: [{ volume: "anf01", workDepth: 1, under: ["IRENÆUS"] }],
  },
  {
    id: "clement-alexandria",
    title: "The Works of St Clement of Alexandria",
    author: "St Clement of Alexandria",
    era: "Greek Father, 2nd–3rd century",
    order: 21,
    ...ANF,
    volumes: [{ volume: "anf02", workDepth: 1, under: ["CLEMENT OF ALEXANDRIA"] }],
  },
  {
    id: "tertullian",
    title: "The Works of Tertullian",
    author: "Tertullian",
    era: "Latin apologist, 2nd–3rd century",
    order: 22,
    ...ANF,
    volumes: [
      { volume: "anf03", workDepth: 1, under: ["Apologetic.", "Anti-Marcion.", "Ethical."] },
      { volume: "anf04", workDepth: 1, under: ["Tertullian: Part Fourth."] },
    ],
  },
  {
    id: "origen",
    title: "The Works of Origen",
    author: "Origen of Alexandria",
    era: "Greek Father, 3rd century",
    order: 23,
    ...ANF,
    volumes: [{ volume: "anf04", workDepth: 1, under: ["Origen."] }],
  },
  {
    id: "cyprian",
    title: "The Letters and Treatises of St Cyprian",
    author: "St Cyprian of Carthage",
    era: "Bishop and martyr, 3rd century",
    order: 24,
    ...ANF,
    volumes: [{ volume: "anf05", workDepth: 1, under: ["Cyprian."] }],
  },
  {
    id: "hippolytus",
    title: "The Extant Works of St Hippolytus",
    author: "St Hippolytus of Rome",
    era: "Presbyter and martyr, 3rd century",
    order: 25,
    ...ANF,
    volumes: [{ volume: "anf05", workDepth: 1, under: ["Hippolytus."] }],
  },
  {
    id: "lactantius",
    title: "The Divine Institutes",
    author: "Lactantius",
    era: "Latin apologist, 3rd–4th century",
    order: 26,
    ...ANF,
    volumes: [{ volume: "anf07", workDepth: 1, under: ["Lactantius"] }],
  },
]

/**
 * How to read a Bible chapter out of a section title, per work.
 *
 *   psalm       "Psalm CXIX"          -> 119
 *   chapterRef  "Chapter I. 1–5."     -> 1, the book being fixed by the work
 *   scriptureRef "…Matt. v. 16…"      -> book and chapter both from the title
 */
const WORK_RULES = {
  "expositions-on-the-book-of-psalms": { book: "PSA", chapters: "psalm" },
  "lectures-or-tractates-on-the-gospel-according-to-st-john": {
    book: "JHN",
    chapters: "chapterRef",
  },
  "ten-homilies-on-the-first-epistle-of-john": { book: "1JN", chapters: "chapterRef" },
  "sermons-on-selected-lessons-of-the-new-testament": { chapters: "scriptureRef" },
  "our-lord-s-sermon-on-the-mount": { book: "MAT", chapters: "wholeWork", spans: [5, 6, 7] },
}

/** Book names as the Victorian translators abbreviate them in sermon titles. */
const BOOK_NAMES = [
  [/^(?:st\.?\s*)?matt(?:hew)?\b/i, "MAT"],
  [/^(?:st\.?\s*)?mark\b/i, "MRK"],
  [/^(?:st\.?\s*)?luke\b/i, "LUK"],
  [/^(?:st\.?\s*)?john\b/i, "JHN"],
  [/^acts\b/i, "ACT"],
  [/^rom(?:ans)?\b/i, "ROM"],
  [/^1\s*cor|^i\.?\s*cor/i, "1CO"],
  [/^2\s*cor|^ii\.?\s*cor/i, "2CO"],
  [/^gal(?:atians)?\b/i, "GAL"],
  [/^eph(?:esians)?\b/i, "EPH"],
  [/^phil(?:ippians)?\b/i, "PHP"],
  [/^col(?:ossians)?\b/i, "COL"],
  [/^1\s*tim|^i\.?\s*tim/i, "1TI"],
  [/^2\s*tim|^ii\.?\s*tim/i, "2TI"],
  [/^heb(?:rews)?\b/i, "HEB"],
  [/^jas\b|^james\b/i, "JAS"],
  [/^1\s*john|^i\.?\s*john/i, "1JN"],
  [/^ps(?:alm)?s?\b/i, "PSA"],
  [/^gen(?:esis)?\b/i, "GEN"],
  [/^isa(?:iah)?\b/i, "ISA"],
]

const CHAPTER_REF = /^Chapter\s+([IVXLC]+|\d+)\b/i
const PSALM_REF = /^Psalm\s+([IVXLC]+|\d+)\b/i
// "On the words of the Gospel, Matt. v. 16" / "…John xvi. 24…"
const SCRIPTURE_REF =
  /(?:^|[,:]\s*)([1-3]?\s*(?:St\.?\s*)?[A-Za-z]{2,}\.?)\s+([ivxlcIVXLC]+|\d+)\s*[.:]\s*\d/

function bookCodeOf(name) {
  const cleaned = name.trim().replace(/\s+/g, " ")
  for (const [pattern, code] of BOOK_NAMES) if (pattern.test(cleaned)) return code
  return null
}

/** One section's Bible reference, or null when the title carries none. */
function referenceOf(section, rule) {
  if (rule.chapters === "psalm") {
    const m = PSALM_REF.exec(section.title)
    const chapter = m && toChapter(m[1], 151)
    return chapter ? [{ book: "PSA", chapter }] : null
  }
  if (rule.chapters === "chapterRef") {
    const m = CHAPTER_REF.exec(section.title)
    const chapter = m && toChapter(m[1])
    return chapter ? [{ book: rule.book, chapter }] : null
  }
  if (rule.chapters === "scriptureRef") {
    const m = SCRIPTURE_REF.exec(section.title)
    if (!m) return null
    const book = bookCodeOf(m[1])
    const chapter = toChapter(m[2])
    return book && chapter ? [{ book, chapter }] : null
  }
  if (rule.chapters === "wholeWork") {
    return rule.spans.map((chapter) => ({ book: rule.book, chapter }))
  }
  return null
}

function buildChapterIndex(works) {
  const index = {}
  let mapped = 0
  let unmapped = 0

  for (const work of works) {
    const rule = WORK_RULES[work.id]
    if (!rule) continue
    work.sections.forEach((section, sectionIndex) => {
      const refs = referenceOf(section, rule)
      if (!refs || !refs.length) {
        unmapped += 1
        return
      }
      mapped += 1
      for (const { book, chapter } of refs) {
        index[book] ??= {}
        const key = String(chapter)
        index[book][key] ??= []
        index[book][key].push({
          workId: work.id,
          workTitle: work.title,
          sectionIndex,
          sectionTitle: section.title,
        })
      }
    })
  }
  return { index, mapped, unmapped }
}

/**
 * Editorial matter CCEL files INSIDE a work, which the title-based skip lists
 * never see because they only judge work-level nodes.
 *
 * These are named one by one rather than matched by pattern, because the
 * titles do not separate them from the Fathers' own writing: "Introduction."
 * is Robertson's essay at the head of Athanasius's Defence Against the Arians
 * and, one section later, Athanasius himself saying "I supposed that, after so
 * many proofs of my innocence had been given...". A pattern broad enough to
 * catch the first deletes the second. Indices are into the work as built,
 * before any dropping.
 */
const EDITORIAL_SECTIONS = {
  "against-the-arians-orationes-contra-arianos-iv": [0],
  "against-the-heathen-contra-gentes": [0],
  "answer-to-eunomius-second-book": [0],
  "apology-to-the-emperor-apologia-ad-constantium": [0],
  "arian-history-historia-arianorum-ad-monachos": [0],
  "circular-to-bishops-of-egypt-and-libya-ad-episcopos-gypti-et": [0],
  "defence-against-the-arians-apologia-contra-arianos": [0],
  "defence-of-dionysius-de-sententia-dionysii": [0],
  "defence-of-his-flight-apologia-de-fuga": [0],
  "defence-of-the-nicene-definition-de-decretis": [0],
  "deposition-of-arius-depositio-arii": [0],
  "encyclical-letter-epistola-encyclica": [0],
  "letter-of-eusebius-epistola-eusebii": [0],
  "letters-of-athanasius-with-two-ancient-chronicles-of-his-lif": [0, 1, 3],
  "life-of-antony-vita-antoni": [0],
  "on-luke-x-22-illud-omnia-c": [0],
  "on-the-councils-of-ariminum-and-seleucia-de-synodis": [0],
  "statement-of-faith-expositio-fidei": [0],
  "synodal-letter-to-the-bishops-of-africa-ad-afros-epistola-sy": [0],
  "synodal-letter-to-the-people-of-antioch-tomus-ad-antiochenos": [0],
  "the-incarnation-of-the-word": [0],
  "concerning-repentance": [1],
  "concerning-virgins": [0],
  "concerning-widows": [0],
  "on-the-duties-of-the-clergy": [0],
  "on-the-holy-spirit": [0],
  "on-the-mysteries": [0],
  "on-virginity": [0],
  "on-the-making-of-man": [0],
  "a-treatise-on-nature-and-grace": [1],
  "on-christian-doctrine": [0],
  "ten-homilies-on-the-first-epistle-of-john": [0],
  "the-book-of-pastoral-rule-and-selected-epistles-of-gregory-t": [0],
  "the-catechetical-lectures-of-s-cyril": [0],
  "the-commonitory-of-vincent-of-l-rins-for-the-antiquity-and-u": [1],
  "the-hex-meron": [0],
  "the-letters": [0],
  "the-letters-and-sermons-of-leo-the-great": [0],
  "the-life-of-constantine-with-orations-of-constantine-and-eus": [0, 9, 31, 32, 309],
  "selected-epistles-of-gregory-the-great": [0],
  "selections-from-the-hymns-and-homilies-of-ephraim-the-syrian": [0],
  "select-letters-of-saint-gregory-nazianzen": [0],
  "select-orations-of-saint-gregory-nazianzen": [9],
  "prefaces": [0],
}

/** Whole works that are an editor writing, not a Father. */
const EDITORIAL_WORKS = new Set([
  "introduction-by-the-american-editor",
  "prefatory-notice",
  // Symmachus was the pagan Prefect of Rome petitioning to restore the Altar
  // of Victory; his memorial is printed beside Ambrose's reply to it, and on
  // an Ambrose shelf it reads as Ambrose arguing for the Vestal Virgins.
  "the-memorial-of-symmachus-prefect-of-the-city",
  "memorial-of-symmachus-the-prefect-of-the-city",
])

/** Remove editorial matter, then renumber what is left. */
function dropEditorial(works) {
  let sections = 0
  const kept = works.filter((work) => !EDITORIAL_WORKS.has(work.id))
  const droppedWorks = works.length - kept.length
  for (const work of kept) {
    const drop = new Set(EDITORIAL_SECTIONS[work.id] ?? [])
    if (!drop.size) continue
    const before = work.sections.length
    work.sections = work.sections
      .filter((_, index) => !drop.has(index))
      .map((section, index) => ({ ...section, id: `s${index + 1}` }))
    sections += before - work.sections.length
    work.sectionCount = work.sections.length
    work.words = work.sections.reduce(
      (n, s) => n + s.paragraphs.reduce((m, p) => m + p.split(" ").length, 0),
      0,
    )
  }
  return { works: kept, droppedWorks, droppedSections: sections }
}

function buildCollection(config) {
  const all = []
  for (const {
    volume,
    workDepth,
    sectionDepth,
    skip = [],
    skipBetween,
    only,
    under,
    rangeWorks,
  } of config.volumes) {
    const epubPath = path.join(CACHE, `${volume}.epub`)
    if (!fs.existsSync(epubPath)) {
      console.error(`  ${volume}: not cached - run scripts/fetch-ccel.mjs first`)
      continue
    }
    const epub = openEpub(epubPath)
    // Volumes whose table of contents has no node for a work at all; the work
    // is named here and assembled from the entries it spans.
    const ranges = (rangeWorks ?? []).map((range) => buildRangeWork(epub, range)).filter(Boolean)
    const works = buildWorks(epub, {
      workDepth,
      sectionDepth,
      skipTitles: [...COMMON_SKIP, ...skip],
      skipPrefixes: COMMON_SKIP_PREFIXES,
      workOnlySkipTitles: WORK_ONLY_SKIP,
      skipBetween,
      only,
      under,
    })
    works.unshift(...ranges)
    fs.rmSync(epub.dir, { recursive: true, force: true })
    console.log(
      `  ${volume}: ${works.length} works, ` +
        `${works.reduce((n, w) => n + w.sectionCount, 0)} sections, ` +
        `${(works.reduce((n, w) => n + w.words, 0) / 1000).toFixed(0)}k words`,
    )
    all.push(...works)
  }

  // Ordering follows the volumes, and each work carries the book it expounds.
  // Titles repeat within a collection - Polycarp and Ignatius both wrote to the
  // Philippians - and the intermediate JSON is named after the slug, so a
  // duplicate would overwrite its predecessor without a word.
  const used = new Map()
  all.forEach((work, i) => {
    const seen = used.get(work.id) ?? 0
    used.set(work.id, seen + 1)
    if (seen) work.id = `${work.id}-${seen + 1}`
    work.order = i + 1
    work.book = WORK_RULES[work.id]?.book ?? null
  })

  const trimmed = dropEditorial(all)
  const works = trimmed.works
  works.forEach((work, i) => {
    work.order = i + 1
  })
  if (trimmed.droppedWorks || trimmed.droppedSections) {
    console.log(
      `  dropped ${trimmed.droppedWorks} editorial works, ` +
        `${trimmed.droppedSections} editorial sections`,
    )
  }
  all.length = 0
  all.push(...works)

  const { index, mapped, unmapped } = buildChapterIndex(all)
  const outDir = path.join(DATA_ROOT, config.id)
  const { volumes: _volumes, ...meta } = config
  writeCollection(outDir, meta, all, index)

  console.log(
    `${config.author}: ${all.length} works, ` +
      `${all.reduce((n, w) => n + w.sectionCount, 0)} sections, ` +
      `${(all.reduce((n, w) => n + w.words, 0) / 1e6).toFixed(2)}m words`,
  )
  console.log(`  chapter index: ${mapped} sections mapped, ${unmapped} without a reference`)
  return all
}

const wanted = process.argv.slice(2)
const targets = wanted.length ? COLLECTIONS.filter((c) => wanted.includes(c.id)) : COLLECTIONS
if (!targets.length) {
  console.error(`no such collection. known: ${COLLECTIONS.map((c) => c.id).join(", ")}`)
  process.exit(1)
}
for (const config of targets) buildCollection(config)
console.log("\nnext: bun scripts/build-works-db.mjs")
