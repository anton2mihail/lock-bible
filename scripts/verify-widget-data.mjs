import { readdirSync, readFileSync, statSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

import { widgetDataFiles } from "./widget-data-format.mjs"

const root = join(dirname(fileURLToPath(import.meta.url)), "..")
const target = join(root, "targets/widget")
const dataRoot = join(root, "src", "services", "bible", "data")

function readUInt32(buffer, index) {
  return buffer.readUInt32LE(index * 4)
}

function assert(condition, message) {
  if (!condition) throw new Error(message)
}

let corpusCount = 0
let totalBytes = 0
for (const translationId of readdirSync(dataRoot)) {
  const sourcePath = join(dataRoot, translationId, "widgetVerses.json")
  let source
  try {
    source = JSON.parse(readFileSync(sourcePath, "utf8")).verses
  } catch (error) {
    if (error.code === "ENOENT") continue
    throw error
  }
  const files = widgetDataFiles(translationId)
  const records = readFileSync(join(target, files.records))
  const offsets = readFileSync(join(target, files.offsets))
  const ot = readFileSync(join(target, files.oldTestament))
  const nt = readFileSync(join(target, files.newTestament))

  assert(offsets.length === (source.length + 1) * 4, `${translationId}: offset count mismatch`)
  assert(readUInt32(offsets, 0) === 0, `${translationId}: first offset is not zero`)
  assert(
    readUInt32(offsets, source.length) === records.length,
    `${translationId}: last offset does not match data size`,
  )

  for (let index = 0; index < source.length; index += 1) {
    const start = readUInt32(offsets, index)
    const end = readUInt32(offsets, index + 1)
    const decoded = JSON.parse(records.subarray(start, end).toString("utf8"))
    const verse = source[index]
    assert(decoded[0] === verse.ref, `${translationId}: reference mismatch at ${index}`)
    assert(decoded[4] === verse.text, `${translationId}: text mismatch at ${index}`)
  }

  const expectedOt = source.flatMap((verse, index) => (verse.group === "nt" ? [] : [index]))
  const expectedNt = source.flatMap((verse, index) => (verse.group === "nt" ? [index] : []))
  assert(ot.length === expectedOt.length * 4, `${translationId}: OT index count mismatch`)
  assert(nt.length === expectedNt.length * 4, `${translationId}: NT index count mismatch`)
  expectedOt.forEach((value, index) =>
    assert(readUInt32(ot, index) === value, `${translationId}: OT map mismatch at ${index}`),
  )
  expectedNt.forEach((value, index) =>
    assert(readUInt32(nt, index) === value, `${translationId}: NT map mismatch at ${index}`),
  )

  const corpusBytes = Object.values(files).reduce(
    (sum, file) => sum + statSync(join(target, file)).size,
    0,
  )
  assert(corpusBytes < 7_000_000, `${translationId}: widget resources too large`)
  corpusCount += 1
  totalBytes += corpusBytes
}

assert(corpusCount === 3, `Expected 3 widget corpora, found ${corpusCount}`)
console.log(`Verified ${corpusCount} random-access widget corpora in ${totalBytes} bytes.`)
