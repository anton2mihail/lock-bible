import { createHash } from "node:crypto"
import { mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import ts from "typescript"
import manifest from "../../../../src/services/bible/data/web-ce/manifest.json"
import { parseBibleReference } from "../../../../src/services/bible/referenceParser.ts"

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../../../..")
const output = resolve(process.argv[2] ?? join(root, "build/native-evidence/L13-content/preparation/reference-target-fixtures.json"))
const sourcePaths = [
  "src/services/companion/passage.ts",
  "src/services/bible/referenceParser.ts",
  "src/services/bible/translations.ts",
  "src/services/bible/data/web-ce/manifest.json",
]
const cases = [
  { id: "simple", citation: "John 3:16" },
  { id: "complex-see-prefix", citation: "See   1 Corinthians 13:4-7, 12" },
  { id: "joel-3-remap", citation: "Joel 3:1-5" },
  { id: "joel-4-remap", citation: "Joel 4:2-3" },
  { id: "esther-addition", citation: "Esther C:7" },
  { id: "single-chapter", citation: "Jude 5" },
  { id: "invalid", citation: "No such passage" },
  { id: "unicode-digit", citation: "Jude ١" },
]
const passageSource = readFileSync(join(root, "src/services/companion/passage.ts"), "utf8")
const syntax = ts.createSourceFile("passage.ts", passageSource, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS)
const declaration = syntax.statements.find((statement) => ts.isFunctionDeclaration(statement) && statement.name?.text === "referenceTarget")
if (!declaration) throw new Error("referenceTarget source function is missing")
const functionText = declaration.getText(syntax).replace(/^export\s+/, "")
const compiled = ts.transpile(functionText, { target: ts.ScriptTarget.ES2022 })
const getTranslation = (id: string) => {
  if (id !== "web-ce") throw new Error(`Unexpected source translation: ${id}`)
  return { manifest }
}
const referenceTarget = new Function("parseBibleReference", "getTranslation", `${compiled}; return referenceTarget;`)(parseBibleReference, getTranslation) as (value: string) => { book: string; chapter: string; contextRequest: string } | null
const rows = cases.map(({ id, citation }) => {
  const output = referenceTarget(citation)
  return {
    id,
    citation,
    target: output ? { book: output.book, chapter: Number(output.chapter) } : null,
    contextRequestOmitted: Boolean(output),
  }
})
mkdirSync(dirname(output), { recursive: true })
writeFileSync(output, `${JSON.stringify({
  formatVersion: 1,
  generatedBy: "scripts/native/source-fixtures/content/reference-target-fixtures.ts",
  policy: "Keep the original citation. Use only its mapped WEB-CE book and chapter to open a whole chapter.",
  sourceHashes: Object.fromEntries(sourcePaths.map((path) => [path, createHash("sha256").update(readFileSync(join(root, path))).digest("hex")])),
  cases: rows,
}, null, 2)}\n`, { flag: "wx" })
console.log(`Wrote ${rows.length} source referenceTarget outputs to ${output}`)
