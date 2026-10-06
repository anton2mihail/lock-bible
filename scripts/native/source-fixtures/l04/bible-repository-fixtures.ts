import { createHash } from "node:crypto"
import { mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../../../..")
const output = resolve(process.argv[2] ?? "build/native-evidence/L04/repository/bible-fixtures.json")
const editions = ["web-ce", "douay-rheims", "vulgate"]
const samples = [{ code: "JHN", chapter: 1 }, { code: "PSA", chapter: 23 }, { code: "SNG", chapter: 1 }]
const hash = (data: Buffer) => createHash("sha256").update(data).digest("hex")
const rows = []
for (const edition of editions) {
  const manifestBytes = readFileSync(`${root}/src/services/bible/data/${edition}/manifest.json`)
  const manifest = JSON.parse(manifestBytes.toString("utf8"))
  for (const sample of samples) {
    const bookBytes = readFileSync(`${root}/src/services/bible/data/${edition}/${sample.code}.json`)
    const book = JSON.parse(bookBytes.toString("utf8"))
    const descriptor = manifest.find((entry: any) => entry.code === sample.code)
    const chapter = book.chapters.find((entry: any) => entry.c === sample.chapter)
    if (!descriptor || !chapter) throw new Error(`Missing ${edition}/${sample.code}/${sample.chapter}`)
    const endIndex = Math.min(2, chapter.verses.length - 1)
    const selected = chapter.verses.slice(0, endIndex + 1)
    rows.push({
      edition, manifestSha256: hash(manifestBytes), bookFileSha256: hash(bookBytes),
      book: { code: descriptor.code, name: descriptor.name, order: descriptor.order },
      chapter: { c: chapter.c, verses: chapter.verses },
      passage: {
        startIndex: 0, endIndex,
        startVerse: selected[0].n, endVerse: selected.at(-1).n,
        scriptureText: selected.map((verse: any) => `${verse.n} ${verse.t}`).join(" "),
        verses: selected.map((verse: any, index: number) => ({ verse: verse.n, index, text: verse.t })),
      },
    })
  }
}
const result = {
  schemaVersion: 1,
  generator: "scripts/native/source-fixtures/l04/bible-repository-fixtures.ts",
  sourceHashes: Object.fromEntries(editions.flatMap((edition) => [
    [`src/services/bible/data/${edition}/manifest.json`, hash(readFileSync(`${root}/src/services/bible/data/${edition}/manifest.json`))],
    ...samples.map((sample) => {
      const path = `src/services/bible/data/${edition}/${sample.code}.json`
      return [path, hash(readFileSync(`${root}/${path}`))]
    }),
  ])),
  outputs: rows,
}
mkdirSync(dirname(output), { recursive: true })
writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`)
console.log(`Wrote ${rows.length} Bible chapter and passage source cases: ${output}`)
