import { mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { createHash } from "node:crypto"
import { filterByScope, nextRotationDate, rotationSlot, verseIndexForDate, type VerseScope } from "../../../src/services/bible/verseOfDay"


const scopes: VerseScope[] = ["full", "ot", "nt"]
const intervals = [10, 15, 30, 60, 180, 360, 720, 1440]
const editions = ["web-ce", "douay-rheims", "vulgate"].map((id) => { const path = `src/services/bible/data/${id}/widgetVerses.json`; const payload = JSON.parse(readFileSync(path, "utf8")); return { meta: { id }, widgetVerses: payload.verses } })
const cases = [
  { id: "negative-slot", tz: "UTC", instant: "1969-12-31T23:59:59.999Z" },
  { id: "epoch", tz: "UTC", instant: "1970-01-01T00:00:00.000Z" },
  { id: "slot-before", tz: "UTC", instant: "2026-01-01T11:59:59.999Z" },
  { id: "slot-boundary", tz: "UTC", instant: "2026-01-01T12:00:00.000Z" },
  { id: "spring-before", tz: "America/Toronto", instant: "2026-03-08T06:59:59.000Z" },
  { id: "spring-after", tz: "America/Toronto", instant: "2026-03-08T07:00:00.000Z" },
  { id: "fall-before", tz: "America/Toronto", instant: "2026-11-01T05:59:59.000Z" },
  { id: "fall-after", tz: "America/Toronto", instant: "2026-11-01T06:00:00.000Z" },
  { id: "fractional-offset-nepal", tz: "Asia/Kathmandu", instant: "2026-07-15T12:34:56.000Z" },
  { id: "travel-same-instant-west", tz: "America/Los_Angeles", instant: "2026-07-15T12:34:56.000Z" },
  { id: "travel-same-instant-east", tz: "Asia/Kathmandu", instant: "2026-07-15T12:34:56.000Z" },
]
const rows: any[] = []
for (const edition of editions) {
  const sourceBytes = readFileSync(`src/services/bible/data/${edition.meta.id}/widgetVerses.json`)
  const sourceHash = createHash("sha256").update(sourceBytes).digest("hex")
  for (const scope of scopes) {
    const pool = filterByScope(edition.widgetVerses, scope)
    for (const scenario of cases) {
      process.env.TZ = scenario.tz
      const date = new Date(scenario.instant)
      for (const cadenceMinutes of intervals) {
        const index = verseIndexForDate(date, pool.length, cadenceMinutes)
        const next = nextRotationDate(date, cadenceMinutes)
        rows.push({ editionId: edition.meta.id, scope, cadenceMinutes, scenario: scenario.id, timezone: scenario.tz, timezoneOffsetMinutes: date.getTimezoneOffset(), instant: date.toISOString(), localSlot: rotationSlot(date, cadenceMinutes), poolCount: pool.length, poolIndex: index, verse: pool[index] ?? null, nextRotationInstant: next.toISOString() })
      }
    }
  }
}
const result = {
  formatVersion: 1,
  generatedBy: "scripts/native/source-fixtures/rotation-fixtures.ts",
  source: "src/services/bible/verseOfDay.ts and each edition widgetVerses.json",
  sourceSha256: createHash("sha256").update(readFileSync("src/services/bible/verseOfDay.ts")).digest("hex"),
  baselineCommit: "b64e1fc3cfc6a78f508b41d74b71dddfe9ff7697",
  algorithmConstants: { shuffleStride: 104729, shuffleOffset: 1729, intervals, scopes },
  poolSources: editions.map((edition) => ({ editionId: edition.meta.id, count: edition.widgetVerses.length, sha256: createHash("sha256").update(readFileSync(`src/services/bible/data/${edition.meta.id}/widgetVerses.json`)).digest("hex"), orderedRefs: edition.widgetVerses.map((v) => v.ref) })),
  scenarios: cases,
  outputs: rows,
  runtimeBehaviorObserved: false,
}
mkdirSync("build/native-evidence/L00-source", { recursive: true })
writeFileSync("build/native-evidence/L00-source/rotation-fixtures.json", `${JSON.stringify(result, null, 2)}\n`)
console.log(`Wrote ${rows.length} rotation outcomes for ${editions.length} editions, ${scopes.length} scopes, ${intervals.length} cadences, and ${cases.length} clock cases.`)
