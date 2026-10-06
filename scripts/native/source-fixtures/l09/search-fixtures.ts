import { createHash } from "node:crypto"
import { readFileSync, mkdirSync, writeFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath, pathToFileURL } from "node:url"
import { Database } from "bun:sqlite"

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../../../..")
const output = resolve(process.argv[2] ?? join(root, "build/native-evidence/L09/source-search-fixtures.json"))
mkdirSync(dirname(output), { recursive: true })

type FixtureEdition = "web-ce" | "douay-rheims" | "vulgate"
;(globalThis as typeof globalThis & { __l09Edition?: FixtureEdition }).__l09Edition = "web-ce"

const searchFixturePlugin: BunPlugin = {
  name: "l09-source-search-fixture-adapters",
  setup(builder) {
    builder.onResolve({ filter: /^\.\/(preferences|bibleService)$/ }, (args) => {
      if (!args.importer.endsWith("/searchService.ts")) return
      return { path: args.path.slice(2), namespace: "l09-search-stub" }
    })
    builder.onLoad({ filter: /.*/, namespace: "l09-search-stub" }, (args) => {
      if (args.path === "preferences") {
        return {
          loader: "ts",
          contents: `export function getTranslationId(): string { return (globalThis as any).__l09Edition ?? "web-ce" }`,
        }
      }
      return {
        loader: "ts",
        contents: `import { readFileSync } from "node:fs"; import { join } from "node:path";
          export function listBooks() { const edition=(globalThis as any).__l09Edition ?? "web-ce";
          return JSON.parse(readFileSync(join(${JSON.stringify(root)}, "src/services/bible/data", edition, "manifest.json"), "utf8")); }`,
      }
    })
  },
}

const moduleOutput = join(root, "build/native-evidence/L09/search-fixture-module")
const buildResult = await Bun.build({
  entrypoints: [join(root, "src/services/bible/searchService.ts")],
  outdir: moduleOutput,
  naming: "searchService.js",
  target: "bun",
  plugins: [searchFixturePlugin],
})
if (!buildResult.success) throw new Error(buildResult.logs.map((log) => log.message).join("\n"))

const [{ searchBible, buildFtsQuery }, parser] = await Promise.all([
  import(pathToFileURL(join(moduleOutput, "searchService.js")).href),
  import("../../../../src/services/bible/referenceParser.ts"),
])
const database = new Database(join(root, "assets/bible/bible-search.db"), { readonly: true })
let activeTrace: Array<{ sql: string; parameters: unknown[] }> | undefined
const adapter = {
  async getAllAsync(sql: string, ...args: unknown[]) {
    const parameters = args.length === 1 && Array.isArray(args[0]) ? args[0] : args
    activeTrace?.push({ sql: sql.replace(/\s+/g, " ").trim(), parameters })
    return database.query(sql).all(...parameters)
  },
  async getFirstAsync(sql: string, ...args: unknown[]) {
    const parameters = args.length === 1 && Array.isArray(args[0]) ? args[0] : args
    activeTrace?.push({ sql: sql.replace(/\s+/g, " ").trim(), parameters })
    return database.query(sql).get(...parameters)
  },
}

const cases = [
  { id: "empty-trimmed", translationID: "web-ce", scope: "all", query: "   " },
  { id: "reference-john-316", translationID: "web-ce", scope: "all", query: "John 3:16" },
  { id: "reference-reversed-range", translationID: "web-ce", scope: "all", query: "John 3:17-16" },
  { id: "reference-suffix-cast", translationID: "web-ce", scope: "all", query: "Psalm 3:1a" },
  { id: "reference-chapter-only", translationID: "web-ce", scope: "all", query: "John 3", limit: 3 },
  { id: "reference-ot-scope-includes-deutero", translationID: "web-ce", scope: "ot", query: "Wisdom 1:1" },
  { id: "reference-scope-excludes", translationID: "web-ce", scope: "ot", query: "John 3:16" },
  { id: "reference-deutero-excluded-nt", translationID: "web-ce", scope: "nt", query: "Wisdom 1:1" },
  { id: "reference-song-alias", translationID: "web-ce", scope: "all", query: "Song of Songs 1:1" },
  { id: "reference-fuzzy-book", translationID: "web-ce", scope: "all", query: "Johm 3:16" },
  { id: "invalid-chapter-text-fallback", translationID: "web-ce", scope: "all", query: "John 500:2" },
  { id: "text-faith-default-limit", translationID: "web-ce", scope: "all", query: "faith" },
  { id: "text-faith-limit-one", translationID: "web-ce", scope: "all", query: "faith", limit: 1 },
  { id: "text-faith-ot", translationID: "web-ce", scope: "ot", query: "faith" },
  { id: "text-faith-nt", translationID: "web-ce", scope: "nt", query: "faith" },
  { id: "text-faith-douay", translationID: "douay-rheims", scope: "all", query: "faith" },
  { id: "text-deus-vulgate", translationID: "vulgate", scope: "all", query: "deus" },
  { id: "phrase-source-order", translationID: "web-ce", scope: "all", query: '"In the beginning"' },
  { id: "phrase-skips-correction", translationID: "web-ce", scope: "all", query: '"fiath"' },
  { id: "correction-fiath", translationID: "web-ce", scope: "all", query: "fiath" },
  { id: "correction-respects-nt-scope", translationID: "web-ce", scope: "nt", query: "fiath" },
  { id: "no-correction-found", translationID: "web-ce", scope: "all", query: "qzxvqqq" },
  { id: "punctuation-tokenization", translationID: "web-ce", scope: "all", query: "faith, hope & love!" },
  { id: "dotted-text-tokenization", translationID: "web-ce", scope: "all", query: "faith.hope" },
  { id: "dotted-phrase-tokenization", translationID: "web-ce", scope: "all", query: '"In.the beginning"' },
  { id: "vulgate-reference", translationID: "vulgate", scope: "all", query: "John 3:16" },
  { id: "douay-reference", translationID: "douay-rheims", scope: "all", query: "John 3:16" },
  ...(["web-ce", "douay-rheims", "vulgate"] as const).flatMap((translationID) =>
    (["all", "ot", "nt"] as const).map((scope) => ({
      id: `edition-scope-${translationID}-${scope}`,
      translationID,
      scope,
      query: "faith",
      limit: 2,
    })),
  ),
  { id: "reference-scope-vulgate-nt", translationID: "vulgate", scope: "nt", query: "John 3:16" },
  { id: "reference-scope-douay-ot-excludes-nt", translationID: "douay-rheims", scope: "ot", query: "John 3:16" },
  { id: "reference-reversed-numeric-cast", translationID: "web-ce", scope: "all", query: "John 3:19-17" },
  { id: "correction-quoted-phrase-no-rewrite", translationID: "web-ce", scope: "all", query: '"fiath and hope"' },
  { id: "correction-fallback-no-match", translationID: "web-ce", scope: "all", query: "qzxvqqq" },
] as const

const results = []
for (const fixture of cases) {
  ;(globalThis as typeof globalThis & { __l09Edition?: FixtureEdition }).__l09Edition = fixture.translationID
  activeTrace = []
  const response = await searchBible(
    adapter as never,
    fixture.query,
    fixture.scope as "all" | "ot" | "nt",
    "limit" in fixture ? fixture.limit : undefined,
  )
  results.push({ requestID: fixture.id, request: fixture, expected: response, sqlTrace: activeTrace })
}
activeTrace = undefined

const referenceCases = [
  "John 3:16", "John 3:17-16", "Psalm 3:1a", "Wisdom 1:1", "Song of Songs 1:1",
  "Johm 3:16", "John 500:2", "Jn 3:16", "1 John 1:1", "John 3", "John 3:16-",
  "Mar 1:1", "Gen 1:1", "Xohn 1:1", "GenesiX 1:1", "Gxnesix 1:1", "Gxnesisx 1:1",
  "JÓHN 3:16", "Jo\u0301hn 3:16",
]
const parsedReferences = referenceCases.map((query) => {
  const byEdition = Object.fromEntries(([
    "web-ce", "douay-rheims", "vulgate",
  ] as const).map((edition) => {
    const manifest = JSON.parse(readFileSync(join(root, "src/services/bible/data", edition, "manifest.json"), "utf8"))
    const parsed = parser.parseBibleReference(query, manifest)
    return [edition, parsed ? {
      code: parsed.book.code, group: parsed.book.group, order: parsed.book.order,
      chapter: parsed.chapter, startVerse: parsed.startVerse ?? null, endVerse: parsed.endVerse ?? null,
    } : null]
  }))
  return { query, byEdition }
})

const parserProbes = {
  normalized: ["  JÓHN.  3  ", "Jo\u0301hn 3", "Song   of Songs", "1 John"].map((value) => ({
    value, expected: parser.normalizeReferenceText(value),
  })),
  utf16EditDistance: [
    ["😀", "", 2], ["𐐀", "𐐁", 1], ["faith", "fiath", 2],
  ].map(([left, right]) => ({ left, right, expected: parser.editDistance(String(left), String(right)) })),
  ftsQueries: ["faith, hope & love!", '"In the beginning"', '"fiath"', "   "].map((query) => ({
    query, expected: buildFtsQuery(query),
  })),
}

const hash = (path: string) => createHash("sha256").update(readFileSync(join(root, path))).digest("hex")
const sourcePaths = [
  "src/services/bible/referenceParser.ts",
  "src/services/bible/searchService.ts",
  "scripts/build-bible-search.mjs",
  "scripts/native/source-fixtures/l09/search-fixtures.ts",
  "assets/bible/bible-search.db",
  ...["web-ce", "douay-rheims", "vulgate"].flatMap((edition) => [
    `src/services/bible/data/${edition}/manifest.json`,
    `src/services/bible/data/${edition}/meta.json`,
  ]),
]
const fixture = {
  formatVersion: 1,
  sourceGeneratedBy: "src/services/bible/searchService.ts and referenceParser.ts",
  sourceRules: {
    supportedEditions: ["web-ce", "douay-rheims", "vulgate"],
    scopes: { all: "all groups", ot: ["ot", "deutero"], nt: ["nt"] },
    defaultResultLimit: 60,
    referenceVerseRange: "CAST(v.verse AS INTEGER) BETWEEN min(start, end) AND max(start, end)",
    textResultOrder: ["bm25(verse_search)", "v.book_order", "v.chapter", "v.verse_order"],
    correction: {
      onlyAfterZeroOriginalTextResults: true,
      quotedInputIsNotCorrected: true,
      minimumTokenLength: 4,
      maxCandidates: 300,
      candidateOrder: ["frequency DESC", "stable source order for ties"],
      maximumEdits: "1 for token length 4; 2 for token length 5 or more",
    },
    editDistanceUnit: "UTF-16 code unit",
  },
  databaseMetadata: Object.fromEntries(database.query("SELECT key, value FROM metadata ORDER BY key").all().map((row: any) => [row.key, row.value])),
  sourceHashes: Object.fromEntries(sourcePaths.map((path) => [path, hash(path)])),
  cases: results,
  parsedReferences,
  parserProbes,
}
database.close()
writeFileSync(output, `${JSON.stringify(fixture, null, 2)}\n`)
console.log(`Wrote ${results.length} source search cases and parser probes to ${output}`)
