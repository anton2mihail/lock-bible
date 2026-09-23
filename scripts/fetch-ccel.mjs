#!/usr/bin/env node
/**
 * Cache the CCEL volumes that build-ccel-works.mjs reads.
 *
 *   node scripts/fetch-ccel.mjs           # everything missing
 *   node scripts/fetch-ccel.mjs npnf108   # just these
 *   node scripts/fetch-ccel.mjs --force   # re-download
 *
 * Downloads into .ccel-cache/, which is gitignored: the volumes are 2-8MB each
 * and re-fetchable, so only the built assets/works/works.db is committed.
 *
 * CCEL's robots.txt allows every agent and asks for Crawl-delay: 10, which this
 * honours - all 38 volumes take about seven minutes, once. There is no bulk
 * route or API; the cache URL pattern is predictable and unauthenticated.
 *
 * On rights: each volume's own ThML metadata records DC.Rights as "Public
 * Domain" and the print sources are 1885-1900, but CCEL's site-wide terms do
 * assert copyright over the library and ask to be contacted about commercial
 * republication. See docs/john/works-pipeline.md for how that is handled.
 */
import { Buffer } from "node:buffer"
import fs from "node:fs"
import path from "node:path"
import { setTimeout as sleep } from "node:timers/promises"
import { fileURLToPath } from "node:url"

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const CACHE = path.join(ROOT, ".ccel-cache")
const CRAWL_DELAY_MS = 10_000

/** Every volume any collection draws on, plus the Dominican Summa. */
const VOLUMES = [
  ...Array.from({ length: 9 }, (_, i) => `anf0${i + 1}`),
  "anf10",
  ...Array.from({ length: 14 }, (_, i) => `npnf1${String(i + 1).padStart(2, "0")}`),
  ...Array.from({ length: 14 }, (_, i) => `npnf2${String(i + 1).padStart(2, "0")}`),
  "summa",
]

/** Author folder on CCEL; everything in the two series is filed under schaff. */
function urlFor(volume) {
  const author = volume === "summa" ? "aquinas" : "schaff"
  return `https://www.ccel.org/ccel/${author[0]}/${author}/${volume}/cache/${volume}.epub`
}

const USER_AGENT =
  "john-1-1-app/1.3 (patristic text ingestion for a free Catholic app; contact antonmihail@gmail.com)"

async function download(volume, destination) {
  const response = await fetch(urlFor(volume), { headers: { "User-Agent": USER_AGENT } })
  if (!response.ok) throw new Error(`HTTP ${response.status}`)
  const bytes = Buffer.from(await response.arrayBuffer())
  // An error page would also arrive with a 200; EPUBs are zips, so check.
  if (bytes.length < 50_000 || bytes.subarray(0, 2).toString() !== "PK") {
    throw new Error(`not an epub (${bytes.length} bytes)`)
  }
  fs.writeFileSync(destination, bytes)
  return bytes.length
}

const args = process.argv.slice(2)
const force = args.includes("--force")
const named = args.filter((a) => !a.startsWith("--"))
const wanted = named.length ? named : VOLUMES

fs.mkdirSync(CACHE, { recursive: true })

let fetched = 0
let skipped = 0
for (const volume of wanted) {
  const destination = path.join(CACHE, `${volume}.epub`)
  if (!force && fs.existsSync(destination)) {
    skipped += 1
    continue
  }
  if (fetched) await sleep(CRAWL_DELAY_MS)
  try {
    const bytes = await download(volume, destination)
    fetched += 1
    console.log(`  ${volume}  ${(bytes / 1048576).toFixed(1)}MB`)
  } catch (error) {
    console.error(`  ${volume}  FAILED: ${error.message}`)
  }
}

console.log(`${fetched} downloaded, ${skipped} already cached → ${path.relative(ROOT, CACHE)}`)
if (fetched) console.log("next: node scripts/build-ccel-works.mjs")
