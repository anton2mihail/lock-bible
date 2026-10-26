#!/usr/bin/env bun
/**
 * Build "A Year with the Fathers": one reading a day for 2027, from works.db.
 *
 *   bun scripts/build-year-plan.mjs
 *
 * Writes src/services/works/data/year-plan.json (what the apps read) and
 * docs/john/year-plan-2027.md (the same plan, for review).
 *
 * Every word a person reads is the Fathers' own, from the library. The app only
 * chooses the order. The order follows the Church's year: Day 1 is 1 January
 * 2027, so St Leo's sermon for a feast falls on that feast, the Lent sermons in
 * Lent, the lectures for the newly baptized in Easter week, and the Nativity
 * sermons in the octave of Christmas. Between the feasts, classic works are
 * read straight through.
 *
 * A stream is a list of library sections read in order over a fixed list of
 * days. Where a stream has more text than days, a reading is cut between
 * paragraphs. The cut points are chosen together (dynamic programming) so that
 * the days are of even length and a cut falls, in order of preference, at a
 * new section, at a heading, or at a numbered paragraph.
 *
 * Only canonized saints, Doctors and the Apostolic Fathers are used. Sections
 * written by a translator (prefaces, "Argument", notes) are left out.
 */
import { Database } from "bun:sqlite"
import { readFileSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { inflateSync } from "node:zlib"

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..")
const DB_PATH = join(ROOT, "assets", "works", "works.db")
const CATALOG_PATH = join(ROOT, "src", "services", "works", "data", "catalog.json")
const PLAN_PATH = join(ROOT, "src", "services", "works", "data", "year-plan.json")
const REVIEW_PATH = join(ROOT, "docs", "john", "year-plan-2027.md")

const YEAR = 2027
const DAYS_IN_YEAR = 365
/** Hard limits for one day. 2,500 words is about 12 minutes; a whole sermon up to that stays whole. */
export const MIN_WORDS = 500
export const MAX_WORDS = 2500
/** The first days anyone can read without the library purchase. */
export const FREE_DAYS = 7

const LEO = "leo-great.the-letters-and-sermons-of-leo-the-great"
const CYRIL = "cyril-jerusalem.the-catechetical-lectures-of-s-cyril"
const NAZIANZEN = "gregory-nazianzen.select-orations-of-saint-gregory-nazianzen"
const CYPRIAN = "cyprian.the-treatises-of-cyprian"

/** The library's section titles for St Leo, with the editor's slips corrected for display. */
const LEO_TITLES = {
  176: "On the Fast of the Tenth Month, I", 179: "On the Fast of the Tenth Month, VIII",
  186: "On the Feast of the Nativity, VIII", 198: "On the Passion, IV", 209: "On Pentecost (Whitsuntide), I",
  210: "On Pentecost (Whitsuntide), III", 214: "On the Feast of St Lawrence the Martyr",
  216: "On the Fast of the Seventh Month, V",
}

const range = (from, to) => Array.from({ length: to - from + 1 }, (_, i) => from + i)

/**
 * The year, in day numbers of 2027 (Day 1 = 1 January). `days` is a list of
 * ranges; `sections` are read in the order given. `author` overrides the
 * collection's author where a collection holds several (the Apostolic Fathers).
 */
const STREAMS = [
  { days: "1-7", parts: [
    { work: "apostolic-fathers.the-teaching-of-the-twelve-apostles", author: "The Didache", label: "The Didache", sections: range(0, 16) },
    { work: "apostolic-fathers.epistle-to-diognetus", author: "The Letter to Diognetus", label: "The Letter to Diognetus", sections: range(0, 12) },
    { work: "apostolic-fathers.epistle-to-the-philippians", author: "St Polycarp", label: "Letter to the Philippians", mixedLabel: "St Polycarp, Letter to the Philippians", sections: range(0, 14), titles: { 0: "Greeting" } },
  ] },
  { days: "8-11", parts: [{ work: LEO, sections: range(187, 190) }] },
  { days: "12-40", parts: [{ work: "athanasius.the-incarnation-of-the-word", label: "On the Incarnation", sections: range(0, 56), chapterOffset: 1 }] },
  { days: "41-45", parts: [{ work: LEO, sections: range(191, 195) }] },
  { days: "46-50,52-79", parts: [
    { work: CYRIL, label: "Catechetical Lectures", sections: [11, 12, 13, 14],
      titles: { 11: "Procatechesis", 12: "Lecture I", 13: "Lecture II, On Repentance", 14: "Lecture III, On Baptism" } },
    { work: "ambrose.concerning-repentance", label: "Concerning Repentance", sections: range(0, 29),
      books: { 1: "Book I", 19: "Book II" } },
  ] },
  { days: "51", parts: [{ work: LEO, sections: [196], titles: { 196: "On the Transfiguration" } }] },
  { days: "80", parts: [{ work: LEO, sections: [197] }] },
  { days: "81", parts: [{ work: LEO, sections: [199] }] },
  { days: "82", parts: [{ work: LEO, sections: [201] }] },
  { days: "83", parts: [{ work: LEO, sections: [198] }] },
  { days: "84", parts: [{ work: LEO, sections: [200] }] },
  { days: "85", parts: [{ work: LEO, sections: [202] }] },
  { days: "86", parts: [{ work: LEO, sections: [205] }] },
  { days: "87", parts: [{ work: LEO, sections: [206] }] },
  // Cyril preached these five to the newly baptized in Easter week.
  { days: "88-93", parts: [{ work: CYRIL, label: "Lectures on the Mysteries", sections: range(30, 34),
    titles: { 30: "I", 31: "II, On Baptism", 32: "III, On Chrism", 33: "IV, On the Body and Blood of Christ", 34: "V, On the Liturgy" } }] },
  { days: "94", parts: [{ work: NAZIANZEN, label: "Oration I", sections: [0], titles: { 0: "On Easter" } }] },
  { days: "95-100", parts: [{ work: "ambrose.on-the-mysteries", label: "On the Mysteries", sections: range(0, 8) }] },
  { days: "101-125,128-135", parts: [
    { work: "augustine.ten-homilies-on-the-first-epistle-of-john", label: "Homilies on the First Epistle of John", sections: range(0, 10),
      titles: { 0: "Prologue", 1: "Homily I", 2: "Homily II", 3: "Homily III", 4: "Homily IV", 5: "Homily V", 6: "Homily VI",
        7: "Homily VII", 8: "Homily VIII", 9: "Homily IX", 10: "Homily X" } },
  ] },
  { days: "126", parts: [{ work: LEO, sections: [207] }] },
  { days: "127", parts: [{ work: LEO, sections: [208] }] },
  { days: "136", parts: [{ work: LEO, sections: [209] }] },
  { days: "137", parts: [{ work: LEO, sections: [210] }] },
  { days: "138-141", parts: [{ work: NAZIANZEN, label: "Oration XLI, On Pentecost", sections: [20] }] },
  { days: "142-152", parts: [{ work: CYRIL, label: "Catechetical Lectures", sections: [27, 28],
    titles: { 27: "Lecture XVI, On the Holy Ghost", 28: "Lecture XVII, On the Holy Ghost" } }] },
  // The sections carry the translator's long summaries as titles, so the days are numbered instead.
  { days: "153-179", parts: [{ work: "athanasius.life-of-antony-vita-antoni", label: "Life of St Antony", sections: range(1, 45), numberDays: true }] },
  { days: "180", parts: [{ work: LEO, sections: [212] }] },
  // Ends on 27 August, St Monica, with Book IX, where she dies.
  { days: "181-221,223-239", parts: [{ work: "augustine.the-confessions", label: "Confessions", sections: range(0, 8) }] },
  { days: "222", parts: [{ work: LEO, sections: [214] }] },
  { days: "240-257", parts: [{ work: "augustine.the-confessions", label: "Confessions", sections: [9] }] },
  { days: "258", parts: [{ work: LEO, sections: [215] }] },
  { days: "260", parts: [{ work: LEO, sections: [216] }] },
  { days: "261", parts: [{ work: LEO, sections: [217] }] },
  { days: "259,262-304", parts: [
    { work: CYPRIAN, label: "On the Lord's Prayer", sections: [3] },
    { work: "vincent-lerins.the-commonitory-of-vincent-of-l-rins-for-the-antiquity-and-u", label: "The Commonitory", sections: range(0, 33) },
    { work: "augustine.the-enchiridion", label: "The Enchiridion", sections: [0, ...range(2, 123)], chapterOffset: -1 },
  ] },
  { days: "305", parts: [{ work: LEO, sections: [218], titles: { 218: "On the Beatitudes" } }] },
  { days: "306-331", parts: [
    { work: "augustine.on-care-to-be-had-for-the-dead", label: "On Care to Be Had for the Dead", sections: range(0, 23), chapterOffset: 0 },
    { work: CYPRIAN, label: "On the Mortality", sections: [6] },
    { work: CYPRIAN, label: "On the Advantage of Patience", sections: [8] },
  ] },
  { days: "332-348", parts: [{ work: "aquinas.catena-aurea-luke", label: "Catena Aurea", sections: range(0, 37), catena: true }] },
  { days: "349-352", parts: [{ work: LEO, sections: range(176, 179) }] },
  // 18 December is the weekday Gospel of Matthew 1:18–25; Luke 2 is the Gospel of Christmas itself.
  { days: "353-358", parts: [{ work: "aquinas.catena-aurea-matthew", label: "Catena Aurea", sections: range(8, 13), catena: true }] },
  { days: "359-365", parts: [{ work: LEO, sections: range(180, 186) }] },
]

/** Named days of 2027 that the plan follows (Roman calendar). */
const FEASTS = {
  1: "Mary, Mother of God", 41: "Ash Wednesday", 51: "Saturday before the Second Sunday of Lent",
  80: "Palm Sunday", 81: "Monday of Holy Week", 82: "Tuesday of Holy Week", 83: "Wednesday of Holy Week",
  84: "Holy Thursday", 85: "Good Friday", 86: "Holy Saturday", 87: "Easter Sunday", 88: "Easter Monday",
  94: "Second Sunday of Easter", 126: "The Ascension", 136: "Pentecost", 180: "Ss Peter and Paul",
  222: "St Lawrence", 239: "St Monica", 240: "St Augustine", 258: "Ember Wednesday",
  259: "Ss Cornelius and Cyprian", 260: "Ember Friday", 261: "Ember Saturday", 305: "All Saints",
  306: "All Souls", 332: "First Sunday of Advent", 349: "Ember Wednesday of Advent", 359: "Christmas",
}

function parseDays(spec) {
  return spec.split(",").flatMap((part) => {
    const [a, b] = part.split("-").map(Number)
    return range(a, b ?? a)
  })
}

const wordCount = (text) => (text.match(/\S+/g) ?? []).length

/** Where a day may begin: the earlier in this list, the better. */
function kindOf(text, paragraphIndex) {
  if (paragraphIndex === 0) return "section"
  if (/^[—–-]{3,}$/.test(text.trim())) return "rule"
  const words = wordCount(text)
  if (words <= 25 && (/^(chapter|book|lecture|section|homily|sermon|treatise|oration|part)\b/i.test(text)
      || /^[IVXLC]+\.\s/.test(text) || !/[.!?:;”"’)]$/.test(text.trim()))) return "heading"
  if (/^(\d+\.|§)/.test(text)) return "numbered"
  return "plain"
}
const BREAK_COST = { section: 0, heading: 1, numbered: 2, plain: 4, rule: Infinity }

function dateOfDay(day) {
  const d = new Date(Date.UTC(YEAR, 0, day))
  return d.toISOString().slice(0, 10)
}

/** The season of a 2027 date, by the Roman calendar (Baptism of the Lord 10 Jan, Easter 28 Mar). */
function seasonOf(day) {
  if (day <= 10) return "christmas"
  if (day < 41) return "ordinary"
  if (day < 80) return "lent"
  if (day < 87) return "holy-week"
  if (day <= 136) return "easter"
  if (day < 332) return "ordinary"
  if (day < 359) return "advent"
  return "christmas"
}

function shortTitle(title) {
  // "On the Passion, III.; delivered on the Sunday before Easter." and "(June 29)" are the editor's notes.
  const t = title.trim().split(/\.[;:,]\s/)[0].replace(/\.$/, "").replace(/\s*\([^)]*\)$/, "")
  const m = t.match(/^(Chapter|Book|Lecture|Section)\s+[IVXLC\d]+/i)
  if (m) return m[0]
  if (t.length <= 70) return t
  return t.slice(0, 70).replace(/\s+\S*$/, "") + "…"
}

function main() {
  const db = new Database(DB_PATH, { readonly: true })
  const catalog = JSON.parse(readFileSync(CATALOG_PATH, "utf8"))
  const collections = new Map(catalog.collections.map((c) => [c.id, c]))
  const works = new Map(catalog.works.map((w) => [w.id, w]))
  const sectionQuery = db.query("select title, paragraphs from sections where work_id = ? and idx = ?")

  const planned = new Map()
  for (const stream of STREAMS) {
    const days = parseDays(stream.days)
    const units = []
    for (const part of stream.parts) {
      const work = works.get(part.work)
      if (!work) throw new Error(`Unknown work ${part.work}`)
      const collection = collections.get(work.collectionId)
      let book = null
      for (const section of part.sections) {
        const row = sectionQuery.get(part.work, section)
        if (!row) throw new Error(`Missing section ${part.work} ${section}`)
        if (part.books?.[section]) book = part.books[section]
        const paragraphs = JSON.parse(inflateSync(row.paragraphs).toString())
        paragraphs.forEach((text, p) => units.push({
          part, work, collection, section, title: row.title, book, p,
          words: wordCount(text), kind: kindOf(text, p),
        }))
      }
    }
    const cuts = split(units, days.length, stream.days)
    cuts.forEach(([from, to], k) => {
      const slice = units.slice(from, to)
      planned.set(days[k], { slice, index: k, count: days.length })
    })
  }

  const sectionDays = new Map()
  for (const [day, { slice }] of [...planned].sort((a, b) => a[0] - b[0])) {
    for (const key of new Set(slice.map((u) => `${u.work.id}#${u.section}`))) {
      if (!sectionDays.has(key)) sectionDays.set(key, [])
      sectionDays.get(key).push(day)
    }
  }
  const out = []
  for (let day = 1; day <= DAYS_IN_YEAR; day++) {
    const entry = planned.get(day)
    if (!entry) throw new Error(`Day ${day} has no reading`)
    out.push(describe(day, entry, sectionDays))
  }
  writeFileSync(PLAN_PATH, JSON.stringify({
    version: 1,
    name: "A Year with the Fathers",
    year: YEAR,
    startDate: dateOfDay(1),
    freeDays: FREE_DAYS,
    minWords: MIN_WORDS,
    maxWords: MAX_WORDS,
    days: out,
  }, null, 1) + "\n")
  writeFileSync(REVIEW_PATH, review(out))
  const words = out.map((d) => d.words)
  console.log(`year-plan.json: ${out.length} days, ${words.reduce((a, b) => a + b, 0)} words, `
    + `${Math.min(...words)}–${Math.max(...words)} a day`)
}

/** Split units into exactly n days. Returns [from, to) pairs. */
function split(units, n, label) {
  const total = units.reduce((a, u) => a + u.words, 0)
  const target = total / n
  const prefix = [0]
  for (const u of units) prefix.push(prefix.at(-1) + u.words)
  const N = units.length
  // A day may end before unit i only where a day may begin at unit i, and never right after a heading.
  const breakCost = (i) => {
    if (i === N) return 0
    if (i === 0) return Infinity
    if (units[i - 1].kind === "heading" && units[i - 1].p > 0) return Infinity
    return BREAK_COST[units[i].kind]
  }
  const cost = Array.from({ length: n + 1 }, () => new Float64Array(N + 1).fill(Infinity))
  const back = Array.from({ length: n + 1 }, () => new Int32Array(N + 1).fill(-1))
  cost[0][0] = 0
  for (let k = 1; k <= n; k++) {
    for (let i = 1; i <= N; i++) {
      const bc = breakCost(i)
      if (bc === Infinity) continue
      for (let j = i - 1; j >= 0; j--) {
        const w = prefix[i] - prefix[j]
        if (w > MAX_WORDS) break
        if (w < MIN_WORDS || cost[k - 1][j] === Infinity) continue
        const c = cost[k - 1][j] + 2 * ((w - target) / target) ** 2 + bc
        if (c < cost[k][i]) { cost[k][i] = c; back[k][i] = j }
      }
    }
  }
  if (cost[n][N] === Infinity) throw new Error(`Days ${label}: no split of ${total} words into ${n} days`)
  const cuts = []
  for (let k = n, i = N; k > 0; k--) { const j = back[k][i]; cuts.unshift([j, i]); i = j }
  return cuts
}

function describe(day, { slice, index, count }, sectionDays) {
  const readings = []
  for (const u of slice) {
    const last = readings.at(-1)
    if (last && last.workId === u.work.id && last.section === u.section) last.toParagraph = u.p
    else readings.push({ workId: u.work.id, section: u.section, fromParagraph: u.p, toParagraph: u.p })
  }
  const groups = []
  for (const u of slice) {
    if (groups.at(-1)?.part !== u.part) groups.push({ part: u.part, units: [] })
    groups.at(-1).units.push(u)
  }
  const authors = [...new Set(groups.map((g) => g.part.author ?? g.units[0].collection.author))]
  const apostolic = groups.every((g) => g.units[0].work.id.startsWith("apostolic-fathers."))
  const author = authors.length > 1 && apostolic ? "The Apostolic Fathers" : authors.join(" and ")
  const context = { day, sectionDays, alone: groups.length === 1, index, count }
  const words = slice.reduce((a, u) => a + u.words, 0)
  return {
    day,
    date: dateOfDay(day),
    season: seasonOf(day),
    ...(FEASTS[day] ? { feast: FEASTS[day] } : {}),
    author,
    work: [...new Set(groups.map((g) => g.part.label ?? "Sermons"))].join("; "),
    // "Book I, chapter V": a chapter after a comma is lower case; a title that starts with it keeps its capital.
    title: groups.map((g) => groupTitle(g, context)).join("; ").replace(/, Chapter/g, ", chapter"),
    words,
    minutes: Math.max(1, Math.round(words / 200)),
    readings,
  }
}

function sectionName(part, u) {
  if (part.titles?.[u.section]) return part.titles[u.section]
  if (part.work === LEO && LEO_TITLES[u.section]) return LEO_TITLES[u.section]
  if (part.chapterOffset !== undefined) return `${u.section + part.chapterOffset}`
  return [u.book, shortTitle(u.title)].filter(Boolean).join(", ")
}

/** "part 2 of 3" when a section is read over several days. */
function partOf(u, day, sectionDays) {
  const days = sectionDays.get(`${u.work.id}#${u.section}`)
  return days.length > 1 ? ` (part ${days.indexOf(day) + 1} of ${days.length})` : ""
}

function groupTitle({ part, units }, { day, sectionDays, alone, index, count }) {
  // The author line already names a work like the Didache; alone it needs only the chapters.
  const label = alone && part.author && part.label === part.author ? null : (alone ? part.label : part.mixedLabel ?? part.label) ?? null
  if (part.numberDays) return `${label}, part ${index + 1} of ${count}`
  if (part.catena) {
    const ref = (t) => t.match(/^(\w+) (\d+):(\d+)(?:–(\d+))?/)
    const a = ref(units[0].title), b = ref(units.at(-1).title)
    const single = units[0].section === units.at(-1).section ? partOf(units[0], day, sectionDays) : ""
    const end = b[4] ?? b[3]
    return `${label}, on ${a[1]} ${a[2]}:${a[3]}${end === a[3] ? "" : `–${end}`}${single}`
  }
  // Sections of only a heading carry no text of their own; name the day by the sections with text.
  const named = units.filter((u) => u.p === 0 && sectionWords(units, u.section) >= 60)
  const first = units[0].p === 0 && named.length ? named[0] : units[0]
  const last = units.at(-1).p === 0 || !named.length ? (named.at(-1) ?? units.at(-1)) : units.at(-1)
  let range
  if (first.section === last.section) {
    range = sectionName(part, first) + partOf(first, day, sectionDays)
  } else if (part.chapterOffset !== undefined) {
    range = `${sectionName(part, first)}–${sectionName(part, last)}`
  } else {
    const a = sectionName(part, first), b = sectionName(part, last)
    const pa = partOf(first, day, sectionDays), pb = partOf(last, day, sectionDays)
    // "Book I, Chapter VI – Book I, Chapter VII" reads as "Book I, Chapters VI–VII".
    const ma = a.match(/^(.*?)(Chapter|Lecture|Section) ([IVXLC\d]+)$/), mb = b.match(/^(.*?)(Chapter|Lecture|Section) ([IVXLC\d]+)$/)
    if (ma && mb && ma[1] === mb[1] && ma[2] === mb[2] && !pa && !pb) range = `${ma[1]}${ma[2]}s ${ma[3]}–${mb[3]}`
    else range = `${a}${pa} – ${b}${pb}`
  }
  if (part.chapterOffset !== undefined) {
    const many = first.section !== last.section
    range = `${many ? "chapters" : "chapter"} ${range}`
  }
  if (!label) return range
  // A work of one section: "On the Lord's Prayer (part 2 of 5)", not "On the Lord's Prayer, On the Lord's Prayer".
  const bare = range.replace(/ \(part \d+ of \d+\)$/, "")
  if (label.toLowerCase().endsWith(bare.toLowerCase())) return label + range.slice(bare.length)
  return `${label}, ${range}`
}

function sectionWords(units, section) {
  return units.filter((u) => u.section === section).reduce((a, u) => a + u.words, 0)
}

/** Runs of days with the same author and work, for the overview table. */
function glance(days, months) {
  const rows = []
  const fmt = (date) => `${Number(date.slice(8))} ${months[Number(date.slice(5, 7)) - 1].slice(0, 3)}`
  for (const d of days) {
    const key = d.author === d.work ? d.author : `${d.author} · ${d.work}`
    const last = rows.at(-1)
    if (last && last.key === key) { last.to = d; continue }
    rows.push({ key, from: d, to: d })
  }
  return rows.map(({ key, from, to }) => from === to
    ? `| ${from.day} | ${fmt(from.date)} | ${key}${from.feast ? ` (**${from.feast}**)` : ""} |`
    : `| ${from.day}–${to.day} | ${fmt(from.date)} – ${fmt(to.date)} | ${key} |`)
}

function review(days) {
  const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September",
    "October", "November", "December"]
  const lines = [
    "# A Year with the Fathers: the 2027 plan (draft for review)",
    "",
    "Generated by `bun scripts/build-year-plan.mjs` from the library (`works.db`). One reading a day, Day 1 =",
    "1 January 2027. Every word is the Fathers' own, as in the library; the app only chooses the order.",
    `Days 1–${FREE_DAYS} are free. Each day is ${MIN_WORDS}–${MAX_WORDS} words; minutes are at 200 words a minute.`,
    "Feasts are in bold.",
    "",
    "## The year at a glance",
    "",
    "| Days | Dates | Reading |",
    "|---|---|---|",
    ...glance(days, months),
    "",
  ]
  let month = -1
  for (const d of days) {
    const m = Number(d.date.slice(5, 7)) - 1
    if (m !== month) { if (month >= 0) lines.push(""); month = m; lines.push(`## ${months[m]}`, "") }
    const feast = d.feast ? ` — **${d.feast}**` : ""
    lines.push(`- ${Number(d.date.slice(8))} ${months[m].slice(0, 3)} · Day ${d.day}${feast} · ${d.author}, `
      + `*${d.title}* · ${d.minutes} min`)
  }
  lines.push("")
  return lines.join("\n")
}

if (import.meta.main) main()
