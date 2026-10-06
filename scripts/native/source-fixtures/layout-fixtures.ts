import { createHash } from "node:crypto"
import { mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import { layoutChapter } from "../../../src/services/bible/chapterLayout"

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../../..")
const sampleRoot = join(root, "native/Prototypes/ReaderProof/Resources")
const output = resolve(process.argv[2] ?? join(root, "build/native-evidence/L06/chapter-layout-expected.json"))
const sourceFiles = [
  "src/services/bible/chapterLayout.ts",
  "src/services/bible/types.ts",
]

function sha256(bytes: Uint8Array): string {
  return createHash("sha256").update(bytes).digest("hex")
}

const examples = [
  { id: "john-web", path: "john-web.json", source: "src/services/bible/data/web-ce/JHN.json" },
  { id: "psalm-23-web", path: "psalm-23-web.json", source: "src/services/bible/data/web-ce/PSA.json" },
  { id: "song-1-web", path: "song-1-web.json", source: "src/services/bible/data/web-ce/SNG.json" },
  { id: "unicode-offsets", path: "unicode-chapter.json", source: "synthetic:UTF-16 boundary fixture" },
]

const results = examples.map((example) => {
  const inputBytes = readFileSync(join(sampleRoot, example.path))
  const input = JSON.parse(inputBytes.toString("utf8")) as {
    chapter: Parameters<typeof layoutChapter>[0]
  }
  return {
    id: example.id,
    inputPath: `native/Prototypes/ReaderProof/Resources/${example.path}`,
    inputSha256: sha256(inputBytes),
    sourcePath: example.source,
    layout: layoutChapter(input.chapter),
  }
})

const sourceHashes = Object.fromEntries(
  sourceFiles.map((path) => [path, sha256(readFileSync(join(root, path)))]),
)
const manifest = {
  schemaVersion: 1,
  generator: "scripts/native/source-fixtures/layout-fixtures.ts",
  sourceHashes,
  results,
}
mkdirSync(dirname(output), { recursive: true })
writeFileSync(output, `${JSON.stringify(manifest, null, 2)}\n`, { flag: "wx" })
console.log(`Wrote ${results.length} chapter layout expectations to ${output}`)
