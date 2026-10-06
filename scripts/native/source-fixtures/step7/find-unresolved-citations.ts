// Step 7 source expectation: which installed readings can the OLD app not open as a passage?
// The old app calls referenceTarget(reference) (src/services/companion/passage.ts:47) for each reading row.
// A null result is the "reference could not be opened" case. This script lists every such reading.
// Read only. It writes only to stdout (JSON). Run with Bun.
// The old modules import react-native-mmkv through the storage helper. Stub it before the dynamic imports.
Bun.plugin({
  setup(build) {
    build.module("react-native-mmkv", () => ({
      exports: { MMKV: class { getString() { return undefined } set() {} delete() {} clearAll() {} } },
      loader: "object",
    }))
  },
})
const { readingsFor, addDays } = await import("../../../../src/services/companion/calendar")
const { referenceTarget } = await import("../../../../src/services/companion/passage")

const start = new Date(Number(process.argv[2] ?? 2025), 0, 1)
const years = Number(process.argv[3] ?? 8)
const unresolved: { date: string; title: string; label: string; reference: string }[] = []
let days = 0
let rows = 0
for (let offset = 0; offset < years * 366; offset += 1) {
  const date = addDays(start, offset)
  if (date.getFullYear() >= start.getFullYear() + years) break
  const entry = readingsFor(date)
  if (!entry) continue
  days += 1
  for (const reading of entry.readings) {
    rows += 1
    if (referenceTarget(reading.reference) === null) {
      const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`
      unresolved.push({ date: key, title: entry.title, label: reading.label, reference: reading.reference })
    }
  }
}
console.log(JSON.stringify({ source: "src/services/companion/passage.ts:47 referenceTarget", daysWithReadings: days, readingRows: rows,
  unresolvedCount: unresolved.length, first: unresolved.slice(0, 20) }, null, 2))
