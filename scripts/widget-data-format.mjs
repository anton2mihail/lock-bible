import { Buffer } from "node:buffer"
import { mkdirSync, rmSync, writeFileSync } from "node:fs"
import { join } from "node:path"

export function widgetDataFiles(prefix = "widgetVerses") {
  return {
    records: `${prefix}.dat`,
    offsets: `${prefix}.offsets`,
    oldTestament: `${prefix}.ot`,
    newTestament: `${prefix}.nt`,
    metadata: `${prefix}.meta.json`,
  }
}

export const WIDGET_DATA_FILES = widgetDataFiles()

function uint32Buffer(values) {
  const buffer = Buffer.allocUnsafe(values.length * 4)
  values.forEach((value, index) => buffer.writeUInt32LE(value, index * 4))
  return buffer
}

/**
 * Emit a random-access corpus for the WidgetKit extension.
 *
 * Widget extensions have a much smaller memory budget than the main app. A
 * single JSON array forces Foundation to materialize every verse even though a
 * timeline only needs a handful. The data file below contains compact JSON
 * records, while the tiny binary indexes let Swift map a shuffled scoped index
 * to one record without decoding the rest of Scripture.
 */
export function writeWidgetResources(verses, outputDirectory, prefix = "widgetVerses") {
  mkdirSync(outputDirectory, { recursive: true })
  const files = widgetDataFiles(prefix)

  const rows = []
  const offsets = [0]
  const oldTestament = []
  const newTestament = []
  let byteOffset = 0

  verses.forEach((verse, globalIndex) => {
    // Positional records avoid repeating five property names 38,000 times.
    const row = `${JSON.stringify([
      verse.ref,
      verse.book,
      verse.chapter,
      verse.verse,
      verse.text,
    ])}\n`
    rows.push(row)
    byteOffset += Buffer.byteLength(row)
    offsets.push(byteOffset)

    if (verse.group === "nt") newTestament.push(globalIndex)
    else oldTestament.push(globalIndex)
  })

  if (byteOffset > 0xffffffff) {
    throw new Error("Widget verse corpus is too large for 32-bit offsets")
  }

  writeFileSync(join(outputDirectory, files.records), rows.join(""))
  writeFileSync(join(outputDirectory, files.offsets), uint32Buffer(offsets))
  writeFileSync(join(outputDirectory, files.oldTestament), uint32Buffer(oldTestament))
  writeFileSync(join(outputDirectory, files.newTestament), uint32Buffer(newTestament))
  writeFileSync(
    join(outputDirectory, files.metadata),
    JSON.stringify(
      {
        formatVersion: 1,
        counts: {
          full: verses.length,
          ot: oldTestament.length,
          nt: newTestament.length,
        },
      },
      null,
      2,
    ),
  )

  // Build 7 bundled this monolithic file. Remove it so a widget process never
  // pays the memory and decode cost again.
  if (prefix === "widgetVerses") rmSync(join(outputDirectory, "widgetVerses.json"), { force: true })

  return {
    bytes: byteOffset,
    full: verses.length,
    ot: oldTestament.length,
    nt: newTestament.length,
  }
}
