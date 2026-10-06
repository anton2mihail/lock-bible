import { createHash } from "node:crypto"
import {
  existsSync, lstatSync, mkdirSync, readFileSync, realpathSync, writeFileSync,
} from "node:fs"
import { dirname, relative, resolve } from "node:path"
import { Database } from "bun:sqlite"

type Json = null | boolean | number | string | Json[] | { [key: string]: Json }
type CheckStatus = "passed" | "failed" | "unavailable" | "observed"
type Check = { id: string; status: CheckStatus; required: boolean; detail: string }

const HELP = `Usage:
  bun scripts/native/source-fixtures/l27/compare-update-evidence.ts \\
    --source-expectations FILE --before-export FILE --after-export FILE \\
    --native-envelope FILE --recovery-db FILE --recovery-inspect FILE \\
    --output NEW_EMPTY_DIRECTORY [--expectation-mapping FILE]

All input files must be copied evidence. The output must be a new directory below
build/native-evidence/L27. This tool does not access an app container or modify inputs.`

function parseArgs(argv: string[]): Map<string, string> {
  const args = new Map<string, string>()
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index]
    if (key === "--help" || key === "-h") {
      console.log(HELP)
      process.exit(0)
    }
    if (!key?.startsWith("--")) throw new Error(`Unexpected argument: ${key ?? "<missing>"}`)
    if (args.has(key)) throw new Error(`Duplicate argument: ${key}`)
    const value = argv[index + 1]
    if (!value || value.startsWith("--")) throw new Error(`Missing value for ${key}`)
    args.set(key, value)
    index += 1
  }
  return args
}

const args = parseArgs(process.argv.slice(2))
const requiredArgs = [
  "--source-expectations", "--before-export", "--after-export", "--native-envelope",
  "--recovery-db", "--recovery-inspect", "--output",
]
for (const key of requiredArgs) if (!args.has(key)) throw new Error(`Required argument missing: ${key}\n${HELP}`)
for (const key of args.keys()) {
  if (![...requiredArgs, "--expectation-mapping"].includes(key)) throw new Error(`Unknown argument: ${key}`)
}

const repositoryRoot = resolve(import.meta.dir, "../../../..")
const evidenceRoot = resolve(repositoryRoot, "build/native-evidence/L27")
const canonicalEvidenceRoot = realpathSync(evidenceRoot)
const outputArgument = resolve(args.get("--output")!)
if (!outputArgument.startsWith(`${evidenceRoot}/`)) {
  throw new Error("Output must be a new directory below build/native-evidence/L27")
}
const outputExistsEmpty = existsSync(outputArgument)
if (outputExistsEmpty) {
  if (!lstatSync(outputArgument).isDirectory() || realpathSync(outputArgument) !== outputArgument) {
    throw new Error("Output must be a new real directory, not a symlink or file")
  }
  if (relative(outputArgument, outputArgument) === "") {
    const { readdirSync } = await import("node:fs")
    if (readdirSync(outputArgument).length > 0) throw new Error("Output directory must be empty")
  }
}
const outputParent = dirname(outputArgument)
if (!existsSync(outputParent)) throw new Error("Output parent must already exist")
const outputRoot = realpathSync(outputParent) + `/${outputArgument.slice(outputParent.length + 1)}`
if (!outputRoot.startsWith(`${canonicalEvidenceRoot}/`)) throw new Error("Resolved output path leaves the L27 evidence tree")
const inputPaths = new Map<string, string>()
for (const key of requiredArgs.filter((key) => key !== "--output")) {
  const supplied = resolve(args.get(key)!)
  if (!existsSync(supplied) || !lstatSync(supplied).isFile()) throw new Error(`Input is not a regular file: ${key}`)
  const canonical = realpathSync(supplied)
  if (!canonical.startsWith(`${canonicalEvidenceRoot}/`)) throw new Error(`${key} must be a copied file below build/native-evidence/L27`)
  if (canonical.startsWith(`${outputRoot}/`) || outputRoot.startsWith(`${canonical}/`)) {
    throw new Error(`Input/output paths overlap: ${key}`)
  }
  inputPaths.set(key, canonical)
}
if (args.has("--expectation-mapping")) {
  const supplied = resolve(args.get("--expectation-mapping")!)
  if (!existsSync(supplied) || !lstatSync(supplied).isFile()) throw new Error("Expectation mapping must be a regular file")
  const canonical = realpathSync(supplied)
  if (!canonical.startsWith(`${canonicalEvidenceRoot}/`)) throw new Error("Expectation mapping must be copied below build/native-evidence/L27")
  if (canonical.startsWith(`${outputRoot}/`) || outputRoot.startsWith(`${canonical}/`)) {
    throw new Error("Expectation mapping and output paths overlap")
  }
  inputPaths.set("--expectation-mapping", canonical)
}

function sha256(bytes: Uint8Array): string {
  return createHash("sha256").update(bytes).digest("hex")
}
function readJSON(path: string, label: string): Record<string, any> {
  let parsed: unknown
  try { parsed = JSON.parse(readFileSync(path, "utf8")) } catch (error) {
    throw new Error(`${label} is not valid JSON: ${String(error)}`)
  }
  if (!parsed || Array.isArray(parsed) || typeof parsed !== "object") throw new Error(`${label} must be a JSON object`)
  return parsed as Record<string, any>
}
function stable(value: unknown): string {
  if (value === undefined) return "undefined"
  if (Array.isArray(value)) return `[${value.map(stable).join(",")}]`
  if (value && typeof value === "object") {
    return `{${Object.keys(value as object).sort().map((key) => `${JSON.stringify(key)}:${stable((value as Record<string, unknown>)[key])}`).join(",")}}`
  }
  return JSON.stringify(value)
}
function hasPath(value: unknown, path: string): boolean {
  return getPath(value, path).found
}
function getPath(root: unknown, path: string): { found: boolean; value?: unknown } {
  const parts = path.replace(/^\$\.?/, "").split(".").filter(Boolean)
  let current: any = root
  for (const part of parts) {
    if (current === null || typeof current !== "object" || !Object.hasOwn(current, part)) return { found: false }
    current = current[part]
  }
  return { found: true, value: current }
}
function mappingPathTokens(path: unknown): string[] | null {
  if (typeof path !== "string" || path.length === 0) return null
  if (path.startsWith("/")) {
    const encoded = path.slice(1).split("/")
    if (encoded.some((token) => /~(?![01])/.test(token))) return null
    return encoded.map((token) => token.replaceAll("~1", "/").replaceAll("~0", "~"))
  }
  if (path.includes(".")) return null
  return [path]
}
function setPath(root: Record<string, any>, path: string, value: unknown): void {
  const parts = mappingPathTokens(path) ?? []
  if (!parts.length) throw new Error("Mapping path must identify a field")
  let current: any = root
  for (const part of parts.slice(0, -1)) {
    if (!current || typeof current !== "object" || !Object.hasOwn(current, part)) throw new Error(`Mapping path does not exist: ${path}`)
    current = current[part]
  }
  const last = parts.at(-1)!
  if (!current || typeof current !== "object" || !Object.hasOwn(current, last)) throw new Error(`Mapping path does not exist: ${path}`)
  current[last] = value
}
function cloneJSON<T>(value: T): T { return JSON.parse(JSON.stringify(value)) as T }
function addCheck(checks: Check[], id: string, status: CheckStatus, detail: string, required = true): void {
  checks.push({ id, status, required, detail })
}
const tableNames = ["bookmarks", "highlights", "notes"]
function requireObject(value: unknown, id: string, checks: Check[]): value is Record<string, any> {
  if (!value || Array.isArray(value) || typeof value !== "object") {
    addCheck(checks, id, "failed", "Required JSON object is missing or has the wrong type")
    return false
  }
  return true
}
function requireString(value: unknown, id: string, checks: Check[]): value is string {
  if (typeof value !== "string" || value.length === 0) {
    addCheck(checks, id, "failed", "Required non-empty string is missing")
    return false
  }
  return true
}
function pointerForKey(key: string): string {
  return key.replaceAll("~", "~0").replaceAll("/", "~1")
}

const checks: Check[] = []
const inputHashes = Object.fromEntries([...inputPaths].map(([key, path]) => [
  key, { path: relative(repositoryRoot, path), bytes: readFileSync(path).byteLength, sha256: sha256(readFileSync(path)) },
]))
const source = readJSON(inputPaths.get("--source-expectations")!, "source expectations")
const before = readJSON(inputPaths.get("--before-export")!, "before export")
const after = readJSON(inputPaths.get("--after-export")!, "after export")
const envelope = readJSON(inputPaths.get("--native-envelope")!, "native envelope")
const recoveryInspect = readJSON(inputPaths.get("--recovery-inspect")!, "recovery inspect")
const mapping = args.has("--expectation-mapping")
  ? readJSON(inputPaths.get("--expectation-mapping")!, "expectation mapping")
  : null

const requiredSourceShape = [
  "expectedNativeState", "rawLegacyMMKVStrings", "appGroupWidgetScalars", "sourceLibrary.finalRows",
  "sourceCatalogIdentity.editions", "sourceCatalogIdentity.prayers", "sourceCatalogIdentity.novenas",
]
for (const path of requiredSourceShape) {
  const field = getPath(source, path)
  addCheck(checks, `source.required.${path}`, field.found ? "passed" : "failed",
    field.found ? "Required source expectation is present" : "Mandatory source expectation is missing")
}
for (const key of ["formatVersion", "kind", "provenance"]) {
  const present = Object.hasOwn(source, key)
  addCheck(checks, `source.header.${key}`, present ? "passed" : "failed", present ? "Present" : "Missing")
}
if (source.formatVersion !== 1 || source.kind !== "l27-source-generated-update-contract") {
  addCheck(checks, "source.header.version", "failed", "Unsupported source expectation format")
}
if (source.runtimeBehaviorObserved !== false) {
  addCheck(checks, "source.provenance.sourceOnly", "failed", "Source expectations must remain labeled as not runtime-observed")
}

function checkExport(exported: Record<string, any>, name: string): void {
  addCheck(checks, `${name}.header.version`, exported.formatVersion === 1 ? "passed" : "failed",
    exported.formatVersion === 1 ? "Export format version 1" : "Missing or unsupported export format version")
  addCheck(checks, `${name}.header.kind`, exported.kind === "l27-copied-old-source-export" ? "passed" : "failed",
    exported.kind === "l27-copied-old-source-export" ? "Copied old-app export" : "Wrong export kind")
  addCheck(checks, `${name}.provenance.captureKind`,
    ["main-copied-old-app", "helper-only-synthetic"].includes(exported.provenance?.captureKind) ? "passed" : "failed",
    `Captured origin label: ${String(exported.provenance?.captureKind)}`)
  for (const path of ["provenance.captureKind", "provenance.bundleID", "provenance.appVersion", "provenance.appBuild", "provenance.processID",
    "provenance.appGroupIdentifier", "provenance.signedEntitlementGroups", "provenance.mmkvRoot", "capturedAt", "protectedFiles", "rawMMKVStrings",
    "widgetScalars", "pendingRequests", "library.schemaVersion", "library.journalMode", "library.integrityCheck",
    "library.tables.bookmarks.columns", "library.tables.bookmarks.rows", "library.tables.highlights.columns",
    "library.tables.highlights.rows", "library.tables.notes.columns", "library.tables.notes.rows"]) {
    const present = hasPath(exported, path)
    addCheck(checks, `${name}.required.${path}`, present ? "passed" : "failed",
      present ? "Mandatory field is present" : "Mandatory field is missing")
  }
  const mmkvRoot = exported.provenance?.mmkvRoot
  if (typeof mmkvRoot === "string" && (mmkvRoot.startsWith("/") || mmkvRoot.split(/[\\/]/).includes(".."))) {
    addCheck(checks, `${name}.provenance.mmkvRootIsRelative`, "failed", "MMKV root must be container-relative, not an absolute live path")
  } else addCheck(checks, `${name}.provenance.mmkvRootIsRelative`, mmkvRoot ? "passed" : "failed",
    "MMKV root is recorded as a relative path")
  for (const path of ["provenance.bundleID", "provenance.appVersion", "provenance.appBuild",
    "provenance.appGroupIdentifier", "provenance.mmkvRoot", "capturedAt"]) {
    const field = getPath(exported, path).value
    const valid = typeof field === "string" && field.length > 0
    addCheck(checks, `${name}.provenance.string.${path}`, valid ? "passed" : "failed",
      valid ? "Required provenance value is a non-empty string" : "Required provenance value must be a non-empty string")
  }
  const processID = exported.provenance?.processID
  const validProcessID = Number.isSafeInteger(processID) && processID > 0
  addCheck(checks, `${name}.provenance.processID`, validProcessID ? "passed" : "failed",
    validProcessID ? `Positive process ID ${processID}` : "Process ID must be a positive safe integer")
  for (const path of ["provenance.bundleID", "provenance.appVersion", "provenance.appBuild", "provenance.processID",
    "provenance.appGroupIdentifier", "provenance.mmkvRoot", "capturedAt"]) {
    const field = getPath(exported, path).value
    if (typeof field === "string" && field.length === 0) addCheck(checks, `${name}.valid.${path}`, "failed", "Must not be empty")
  }
  const raw = exported.rawMMKVStrings
  if (raw && typeof raw === "object" && !Array.isArray(raw)) {
    for (const [key, value] of Object.entries(raw)) {
      if (typeof value !== "string") addCheck(checks, `${name}.mmkv.raw.${key}`, "failed", "Raw MMKV value must be a string")
    }
  }
  const protectedFiles = exported.protectedFiles
  if (protectedFiles && typeof protectedFiles === "object" && !Array.isArray(protectedFiles)) {
    for (const name of ["user-library.db", "user-library.db-wal", "user-library.db-shm", "mmkv/data", "mmkv/crc"]) {
      const item = protectedFiles[name]
      const valid = item && typeof item.exists === "boolean" &&
        (item.exists ? typeof item.sha256 === "string" && /^[a-f0-9]{64}$/.test(item.sha256) && Number.isInteger(item.sizeBytes) : item.sha256 == null && item.sizeBytes == null)
      addCheck(checks, `export.protectedFile.${name}`, valid ? "passed" : "failed",
        valid ? "Existence and content metadata are present" : "Protected-file metadata is invalid")
    }
  }
  for (const table of tableNames) {
    const snapshot = exported.library?.tables?.[table]
    if (!snapshot || !Array.isArray(snapshot.columns) || !Array.isArray(snapshot.rows)) continue
    const columns = snapshot.columns
    const validColumns = columns.length > 0 && columns.every((column: unknown) => typeof column === "string") &&
      new Set(columns).size === columns.length
    addCheck(checks, `${name}.library.columnsComplete.${table}`, validColumns ? "passed" : "failed",
      `Table ${table} has ${columns.length} unique column names`)
    let completeRows = validColumns
    for (const row of snapshot.rows) {
      if (!row || Array.isArray(row) || typeof row !== "object" ||
          stable(Object.keys(row).sort()) !== stable([...columns].sort())) {
        completeRows = false
        break
      }
    }
    addCheck(checks, `${name}.library.allColumnValues.${table}`, completeRows ? "passed" : "failed",
      completeRows ? `Every ${table} row includes all ${columns.length} column values` : `At least one ${table} row is incomplete`)
  }
  const signedGroups = exported.provenance?.signedEntitlementGroups
  addCheck(checks, `${name}.signedGroups.observation`, "observed",
    Array.isArray(signedGroups) ? `Observed ${signedGroups.length} signed entitlement group(s); access is not inferred` :
      "Signed entitlement group data is unavailable; access is not inferred", false)
}
checkExport(before, "before")
checkExport(after, "after")
addCheck(checks, "exports.captureKindMatches",
  before.provenance?.captureKind === after.provenance?.captureKind ? "passed" : "failed",
  `Before=${String(before.provenance?.captureKind)}; after=${String(after.provenance?.captureKind)}`)

for (const path of ["envelope.formatVersion", "envelope.revision", "envelope.importVersion", "envelope.state",
  "envelopeSHA256", "rawEnvelopeBase64", "importedReminderID", "preservedUnknownLegacyKeys"]) {
  const present = hasPath(envelope, path)
  addCheck(checks, `nativeEnvelope.required.${path}`, present ? "passed" : "failed",
    present ? "Mandatory field is present" : "Mandatory field is missing")
}
if (envelope.envelope?.formatVersion !== 1) addCheck(checks, "nativeEnvelope.formatVersion", "failed", "Native envelope format must be 1")
const revisionExpectation = mapping?.envelopeRevisionExpectation
const expectedRevision = revisionExpectation === undefined ? 1 : revisionExpectation?.expectedRevision
if (revisionExpectation !== undefined) {
  const validMapping = revisionExpectation && Number.isSafeInteger(revisionExpectation.expectedRevision) && revisionExpectation.expectedRevision >= 1 &&
    typeof revisionExpectation.stage === "string" && revisionExpectation.stage.length > 0 &&
    revisionExpectation.authority === mapping?.reviewAuthority
  addCheck(checks, "nativeEnvelope.revisionMapping", validMapping ? "passed" : "failed",
    validMapping ? `Reviewed stage ${revisionExpectation.stage}` : "Revision mapping needs stage, expectedRevision >= 1, and matching review authority")
}
addCheck(checks, "nativeEnvelope.revision",
  Number.isSafeInteger(envelope.envelope?.revision) && envelope.envelope.revision === expectedRevision ? "passed" : "failed",
  `Expected revision ${String(expectedRevision)}; observed ${String(envelope.envelope?.revision)}`)
if (envelope.envelope?.importVersion !== 1) addCheck(checks, "nativeEnvelope.importVersion", "failed", "Import version must be 1")
if (typeof envelope.envelopeSHA256 !== "string" || !/^[a-f0-9]{64}$/.test(envelope.envelopeSHA256)) {
  addCheck(checks, "nativeEnvelope.hash", "failed", "Native envelope SHA-256 is missing or invalid")
} else if (typeof envelope.rawEnvelopeBase64 === "string") {
  try {
    const rawEnvelopeBytes = Buffer.from(envelope.rawEnvelopeBase64, "base64")
    const actualHash = sha256(rawEnvelopeBytes)
    const rawEnvelopeObject = JSON.parse(rawEnvelopeBytes.toString("utf8"))
    addCheck(checks, "nativeEnvelope.rawBytesHash", actualHash === envelope.envelopeSHA256 ? "passed" : "failed",
      actualHash === envelope.envelopeSHA256 ? "Raw copied envelope bytes match the recorded SHA-256" : "Raw envelope byte hash does not match")
    addCheck(checks, "nativeEnvelope.rawBytesContent", stable(rawEnvelopeObject) === stable(envelope.envelope) ? "passed" : "failed",
      "Decoded raw envelope bytes must match the separately exported envelope object")
  } catch (error) {
    addCheck(checks, "nativeEnvelope.rawBytesHash", "failed", `Raw envelope bytes are invalid: ${String(error)}`)
  }
}
if (!Array.isArray(envelope.preservedUnknownLegacyKeys)) addCheck(checks, "nativeEnvelope.unknownKeys", "failed", "Preserved unknown-key list is missing")
if (!requireString(envelope.importedReminderID, "nativeEnvelope.importedReminderID", checks)) {
  // Required field diagnostic is already recorded above.
}

const mappingEntries = mapping?.stateOverrides ?? []
const sourceExpectedState = cloneJSON(source.expectedNativeState ?? {}) as Record<string, any>
const seenStateOverrides = new Set<string>()
if (mapping) {
  addCheck(checks, "mapping.header", mapping.formatVersion === 1 && mapping.kind === "l27-reviewed-expectation-mapping"
    ? "passed" : "failed", "Mapping must identify format version 1 and reviewed mapping kind")
  addCheck(checks, "mapping.authority", requireString(mapping.reviewAuthority, "mapping.reviewAuthority", checks) ? "passed" : "failed",
    "Mapping authority must be stated")
}
if (!Array.isArray(mappingEntries)) addCheck(checks, "mapping.stateOverrides.shape", "failed", "stateOverrides must be an array")
else for (const item of mappingEntries) {
  if (!requireObject(item, "mapping.stateOverride", checks)) continue
  const path = item.nativePath
  const key = item.sourceKey
  if (typeof path !== "string" || mappingPathTokens(path) === null || typeof key !== "string" || typeof item.expectedRawValue !== "string" ||
      !Object.hasOwn(item, "expectedNativeValue") || !requireString(item.reason, "mapping.stateOverride.reason", checks) ||
      item.authority !== mapping?.reviewAuthority) {
    addCheck(checks, "mapping.stateOverride.valid", "failed", "Override needs source key, exact raw value, native path/value, reason, and matching review authority")
    continue
  }
  if (seenStateOverrides.has(path)) {
    addCheck(checks, `mapping.stateOverride.${path}`, "failed", "Duplicate native path override")
    continue
  }
  seenStateOverrides.add(path)
  const actualRaw = before.rawMMKVStrings?.[key]
  if (actualRaw !== item.expectedRawValue || after.rawMMKVStrings?.[key] !== item.expectedRawValue) {
    addCheck(checks, `mapping.stateOverride.${path}.raw`, "failed", "Mapped raw value does not match both copied exports")
    continue
  }
  try {
    setPath(sourceExpectedState, path, item.expectedNativeValue)
    addCheck(checks, `mapping.stateOverride.${path}`, "passed", `Explicit mapping from ${key}; ${item.reason}`)
  } catch (error) {
    addCheck(checks, `mapping.stateOverride.${path}`, "failed", String(error))
  }
}
function persistentStateProjection(state: Record<string, any>): Record<string, any> {
  const projected = cloneJSON(state)
  delete projected.legacyUnknownKeys
  if (projected.themeScheme === null) delete projected.themeScheme
  if (projected.readerLocation === null) delete projected.readerLocation
  if (projected.readerLocation && typeof projected.readerLocation === "object" && projected.readerLocation.anchor === null) {
    delete projected.readerLocation.anchor
  }
  if (projected.worksPositions && typeof projected.worksPositions === "object") {
    for (const [workID, position] of Object.entries(projected.worksPositions)) {
      const record = position as Record<string, unknown>
      if (record.fields && typeof record.fields === "object" && !Array.isArray(record.fields)) {
        projected.worksPositions[workID] = cloneJSON(record.fields)
      }
    }
  }
  return projected
}
if (envelope.envelope?.state && typeof envelope.envelope.state === "object" && !Array.isArray(envelope.envelope.state) &&
    sourceExpectedState && typeof sourceExpectedState === "object" &&
    stable(persistentStateProjection(envelope.envelope.state)) === stable(persistentStateProjection(sourceExpectedState))) {
  addCheck(checks, "nativeEnvelope.stateMatchesReviewedExpectation", "passed", "All imported state fields match the source expectation and explicit reviewed overrides")
} else {
  addCheck(checks, "nativeEnvelope.stateMatchesReviewedExpectation", "failed",
    "Decoded native state differs from source expectations; add a reviewed explicit mapping for every confirmed difference")
}

const expectedRaw = source.rawLegacyMMKVStrings
if (expectedRaw && before.rawMMKVStrings && after.rawMMKVStrings) {
  const expectedKeys = Object.keys(expectedRaw).sort()
  const actualKeys = Object.keys(before.rawMMKVStrings).sort()
  const afterKeys = Object.keys(after.rawMMKVStrings).sort()
  addCheck(checks, "legacy.rawKeySetMatchesSourceFixture", stable(actualKeys) === stable(expectedKeys) ? "passed" : "failed",
    `Source fixture has ${expectedKeys.length} keys; before export has ${actualKeys.length}`)
  addCheck(checks, "legacy.rawKeySetPreservedAfterUpdate", stable(actualKeys) === stable(afterKeys) ? "passed" : "failed",
    `Before keys=${actualKeys.length}, after keys=${afterKeys.length}`)
  for (const key of expectedKeys) {
    const preserved = before.rawMMKVStrings[key] === after.rawMMKVStrings[key]
    addCheck(checks, `legacy.rawValuePreserved.${key}`, preserved ? "passed" : "failed",
      preserved ? "Exact raw legacy string is unchanged" : "Raw legacy string changed during update")
    if (before.rawMMKVStrings[key] !== expectedRaw[key]) {
      const mapped = Array.isArray(mapping?.rawLegacyOverrides) && mapping.rawLegacyOverrides.some((entry: any) =>
        entry.key === key && entry.expectedBefore === before.rawMMKVStrings[key] &&
        entry.authority === mapping.reviewAuthority && typeof entry.reason === "string" && entry.reason.length > 0)
      addCheck(checks, `legacy.sourceExpectation.${key}`, mapped ? "passed" : "failed",
        mapped ? "Difference has an explicit reviewed source mapping" : "Actual value differs from source fixture; no reviewed exact-raw mapping was supplied")
    } else addCheck(checks, `legacy.sourceExpectation.${key}`, "passed", "Actual value matches source-generated raw string")
  }
  for (const key of Object.keys(before.rawMMKVStrings)) {
    if (!Object.hasOwn(expectedRaw, key)) {
      const preserved = before.rawMMKVStrings[key] === after.rawMMKVStrings[key]
      addCheck(checks, `legacy.unknownRawKeyPreserved.${key}`, preserved ? "passed" : "failed",
        preserved ? "Unknown source key remains byte-for-byte unchanged" : "Unknown source key changed")
    }
  }
}

if (before.widgetScalars && after.widgetScalars) {
  addCheck(checks, "widget.scalarsPreserved",
    stable(before.widgetScalars) === stable(after.widgetScalars) ? "passed" : "failed",
    "Typed widget scalar names, types, and values must remain exact across update")
  const sourceWidget = source.appGroupWidgetScalars
  if (sourceWidget) addCheck(checks, "widget.scalarsMatchSource",
    stable(before.widgetScalars) === stable(sourceWidget) ? "passed" : "failed",
    "Copied widget scalars are compared with the source-generated scalar contract")
}

const protectedNames = ["user-library.db", "user-library.db-wal", "user-library.db-shm", "mmkv/data", "mmkv/crc"]
for (const name of protectedNames) {
  const left = before.protectedFiles?.[name]
  const right = after.protectedFiles?.[name]
  const unchanged = !!left && !!right && stable(left) === stable(right)
  addCheck(checks, `protectedFile.unchanged.${name}`, unchanged ? "passed" : "failed",
    unchanged ? `Existence, size, and SHA-256 are unchanged (${left.exists ? left.sha256 : "absent"})` : "Protected file metadata changed or is missing")
}
const beforeMain = before.protectedFiles?.["user-library.db"]
addCheck(checks, "protectedFile.sourceDBExists", beforeMain?.exists === true ? "passed" : "failed",
  beforeMain?.exists === true ? "Old library main database exists" : "Old library main database must exist")
const beforeWal = before.protectedFiles?.["user-library.db-wal"]
const beforeShm = before.protectedFiles?.["user-library.db-shm"]
addCheck(checks, "protectedFile.sidecarStateRecorded", beforeWal && beforeShm ? "passed" : "failed",
  beforeWal && beforeShm ? `WAL=${beforeWal.exists ? "present" : "absent"}; SHM=${beforeShm.exists ? "present" : "absent"}` : "Both sidecar observations are required")

function sortedRows(rows: Record<string, any[]>): Record<string, any[]> {
  return Object.fromEntries(tableNames.map((name) => [
    name, [...rows[name]].sort((left, right) => stable(left).localeCompare(stable(right))),
  ]))
}
function libraryRows(library: any): Record<string, any[]> | null {
  if (!library?.tables || tableNames.some((name) => !Array.isArray(library.tables[name]?.rows))) return null
  return sortedRows(Object.fromEntries(tableNames.map((name) => [name, library.tables[name].rows])))
}
const beforeRows = libraryRows(before.library)
const afterRows = libraryRows(after.library)
if (beforeRows && afterRows) {
  addCheck(checks, "library.rowsPreservedAfterUpdate", stable(beforeRows) === stable(afterRows) ? "passed" : "failed",
    "All exported rows and every column value must match before and after update")
  addCheck(checks, "library.schemaPreservedAfterUpdate",
    before.library.schemaVersion === after.library.schemaVersion &&
    stable(Object.fromEntries(tableNames.map((name) => [name, before.library.tables[name].columns]))) ===
    stable(Object.fromEntries(tableNames.map((name) => [name, after.library.tables[name].columns]))) ? "passed" : "failed",
    "Schema version and complete table column lists must match")
  addCheck(checks, "library.integrityBefore", before.library.integrityCheck === "ok" ? "passed" : "failed",
    `Before integrity result: ${String(before.library.integrityCheck)}`)
  addCheck(checks, "library.integrityAfter", after.library.integrityCheck === "ok" ? "passed" : "failed",
    `After integrity result: ${String(after.library.integrityCheck)}`)
  addCheck(checks, "library.journalModePreserved",
    String(before.library.journalMode).toLowerCase() === String(after.library.journalMode).toLowerCase() ? "passed" : "failed",
    `Before=${String(before.library.journalMode)}; after=${String(after.library.journalMode)}`)
  const sourceRows = source.sourceLibrary?.finalRows
  if (sourceRows) {
    const expectedSourceRows = sortedRows(cloneJSON(sourceRows))
    const rowOverrides = mapping?.sourceLibraryRowOverrides
    if (rowOverrides !== undefined && !Array.isArray(rowOverrides)) {
      addCheck(checks, "library.sourceOverrideShape", "failed", "sourceLibraryRowOverrides must be an array")
    } else for (const override of rowOverrides ?? []) {
      if (!requireObject(override, "mapping.sourceLibraryRowOverride", checks)) continue
      const { table, rowIdentity, column, sourceExpectedValue, expectedActualValue, rationale, authority } = override
      if (!tableNames.includes(table) || !rowIdentity || typeof rowIdentity !== "object" ||
          typeof column !== "string" || !Object.hasOwn(override, "sourceExpectedValue") ||
          !Object.hasOwn(override, "expectedActualValue") || typeof rationale !== "string" || !rationale ||
          authority !== mapping?.reviewAuthority) {
        addCheck(checks, "mapping.sourceLibraryRowOverride.valid", "failed",
          "Row override needs table, exact row identity, column values, rationale, and matching review authority")
        continue
      }
      const findRow = (rows: Record<string, any[]>) => rows[table].filter((row) =>
        Object.entries(rowIdentity).every(([key, value]) => stable(row[key]) === stable(value)))
      const sourceMatches = findRow(expectedSourceRows)
      const actualMatches = findRow(beforeRows)
      if (sourceMatches.length !== 1 || actualMatches.length !== 1 ||
          stable(sourceMatches[0][column]) !== stable(sourceExpectedValue) ||
          stable(actualMatches[0][column]) !== stable(expectedActualValue)) {
        addCheck(checks, `mapping.sourceLibraryRowOverride.${table}.${column}`, "failed",
          "Override must identify one source row and one actual old row with exact values")
        continue
      }
      sourceMatches[0][column] = expectedActualValue
      addCheck(checks, `mapping.sourceLibraryRowOverride.${table}.${column}`, "passed",
        `Reviewed value mapping applied to one ${table} row: ${rationale}`)
    }
    for (const table of tableNames) {
      expectedSourceRows[table].sort((left, right) => stable(left).localeCompare(stable(right)))
    }
    addCheck(checks, "library.rowsMatchSourceExpectations",
      stable(beforeRows) === stable(expectedSourceRows) ? "passed" : "failed",
      "Actual old rows are compared with executed source repository outputs and explicit reviewed cell mappings")
  }
}

const recoveryPath = inputPaths.get("--recovery-db")!
const recoveryBytes = readFileSync(recoveryPath)
const recoveryHash = sha256(recoveryBytes)
const recoveryMeta = recoveryInspect.recovery
for (const path of ["formatVersion", "recovery.pathRelative", "recovery.fileSHA256", "recovery.schemaVersion", "recovery.journalMode",
  "recovery.integrityCheck", "recovery.tables.bookmarks.columns", "recovery.tables.bookmarks.rows",
  "recovery.tables.highlights.columns", "recovery.tables.highlights.rows", "recovery.tables.notes.columns", "recovery.tables.notes.rows"]) {
  addCheck(checks, `recoveryInspect.required.${path}`, hasPath(recoveryInspect, path) ? "passed" : "failed",
    hasPath(recoveryInspect, path) ? "Mandatory recovery inspection field is present" : "Mandatory recovery inspection field is missing")
}
addCheck(checks, "recoveryInspect.kind", recoveryInspect.kind === "l27-recovery-inspection" ? "passed" : "failed",
  "Recovery inspection must use the documented kind")
const recoveryRelative = recoveryMeta?.pathRelative
let recoveryInspectPathMatches = false
if (typeof recoveryRelative === "string" && !recoveryRelative.startsWith("/") && !recoveryRelative.split(/[\\/]/).includes("..")) {
  const actualRecovery = realpathSync(recoveryPath)
  const expectedRecovery = resolve(canonicalEvidenceRoot, recoveryRelative)
  recoveryInspectPathMatches = existsSync(expectedRecovery) && realpathSync(expectedRecovery) === actualRecovery
  addCheck(checks, "recoveryInspect.pathMatchesCopy", recoveryInspectPathMatches ? "passed" : "failed",
    "Inspection path must identify the supplied copied recovery database")
} else addCheck(checks, "recoveryInspect.pathMatchesCopy", "failed", "Recovery path must be a relative copied-evidence path")
addCheck(checks, "recoveryInspect.dbHashMatches", recoveryMeta?.fileSHA256 === recoveryHash ? "passed" : "failed",
  recoveryMeta?.fileSHA256 === recoveryHash ? `Copied recovery DB SHA-256 ${recoveryHash}` : "Recovery inspect hash does not match copied DB")
addCheck(checks, "recoveryInspect.journalModeDelete", String(recoveryMeta?.journalMode).toLowerCase() === "delete" ? "passed" : "failed",
  `Recorded journal mode: ${String(recoveryMeta?.journalMode)}`)
const recoverySidecars = ["-wal", "-shm", "-journal"].map((suffix) => `${recoveryPath}${suffix}`)
const presentRecoverySidecars = recoverySidecars.filter((path) => existsSync(path))
addCheck(checks, "recoveryDB.noSidecars", presentRecoverySidecars.length === 0 ? "passed" : "failed",
  presentRecoverySidecars.length === 0 ? "Copied recovery database is self-contained" : `Unexpected recovery sidecars: ${presentRecoverySidecars.map((path) => relative(repositoryRoot, path)).join(", ")}`)
const headerJournalMode = recoveryBytes.length > 20 ? `${recoveryBytes[18]}/${recoveryBytes[19]}` : "short-file"
addCheck(checks, "recoveryDB.deleteHeader", headerJournalMode === "1/1" ? "passed" : "failed",
  `SQLite header bytes 18/19 are ${headerJournalMode}; DELETE mode is 1/1`)

let recoveryRows: Record<string, any[]> | null = null
let recoveryDatabase: Database | null = null
const recoveryReadGuard = recoveryMeta?.fileSHA256 === recoveryHash &&
  String(recoveryMeta?.journalMode).toLowerCase() === "delete" && recoveryMeta?.integrityCheck === "ok" &&
  headerJournalMode === "1/1" && presentRecoverySidecars.length === 0 && recoveryInspectPathMatches &&
  recoveryInspect.kind === "l27-recovery-inspection" && recoveryInspect.formatVersion === 1
if (!recoveryReadGuard) {
  addCheck(checks, "recoveryDB.readOnlyQueries", "unavailable",
    "Database was not opened because the copied-file hash, DELETE-mode, integrity, header, or no-sidecar guard failed")
  addCheck(checks, "recoveryDB.actualIntegrity", "unavailable", "Read-only query was blocked by the recovery-file guard")
  addCheck(checks, "recoveryDB.actualSchemaVersion", "unavailable", "Read-only query was blocked by the recovery-file guard")
  for (const table of tableNames) {
    addCheck(checks, `recoveryDB.columns.${table}`, "unavailable", "Read-only query was blocked by the recovery-file guard")
    addCheck(checks, `recoveryDB.rows.${table}`, "unavailable", "Read-only query was blocked by the recovery-file guard")
  }
} else try {
  recoveryDatabase = new Database(recoveryPath, { readonly: true })
  const integrity = recoveryDatabase.query("PRAGMA integrity_check").get() as Record<string, unknown> | null
  const integrityValue = integrity ? Object.values(integrity)[0] : null
  addCheck(checks, "recoveryDB.actualIntegrity", integrityValue === "ok" ? "passed" : "failed",
    `Read-only integrity_check returned ${String(integrityValue)}`)
  const versionRow = recoveryDatabase.query("PRAGMA user_version").get() as Record<string, unknown> | null
  const userVersion = versionRow ? Number(Object.values(versionRow)[0]) : NaN
  addCheck(checks, "recoveryDB.actualSchemaVersion", Number.isInteger(userVersion) && userVersion === recoveryMeta?.schemaVersion ? "passed" : "failed",
    `Read-only user_version=${String(userVersion)}; inspect=${String(recoveryMeta?.schemaVersion)}`)
  const rows: Record<string, any[]> = {}
  for (const table of tableNames) {
    const columns = recoveryDatabase.query(`PRAGMA table_info("${table}")`).all() as Record<string, unknown>[]
    const columnNames = columns.map((row) => String(row.name))
    const dataRows = recoveryDatabase.query(`SELECT * FROM "${table}"`).all() as Record<string, any>[]
    dataRows.sort((left, right) => stable(left).localeCompare(stable(right)))
    const inspected = recoveryMeta?.tables?.[table]
    addCheck(checks, `recoveryDB.columns.${table}`, stable(columnNames) === stable(inspected?.columns) ? "passed" : "failed",
      `Observed ${columnNames.length} columns; compared with copied inspection`)
    const expectedRows = [...(inspected?.rows ?? [])].sort((left: unknown, right: unknown) => stable(left).localeCompare(stable(right)))
    addCheck(checks, `recoveryDB.rows.${table}`, stable(dataRows) === stable(expectedRows) ? "passed" : "failed",
      `Observed ${dataRows.length} complete rows; compared with copied inspection`)
    rows[table] = dataRows
  }
  recoveryRows = rows
  addCheck(checks, "recoveryDB.readOnlyQueries", "passed", "Read-only integrity, schema, and row queries completed")
} catch (error) {
  addCheck(checks, "recoveryDB.readOnlyQueries", "failed", String(error))
} finally {
  try { recoveryDatabase?.close() } catch (error) {
    addCheck(checks, "recoveryDB.close", "failed", String(error))
  }
}
const recoveryHashAfterRead = sha256(readFileSync(recoveryPath))
const sidecarsAfterRead = recoverySidecars.filter((path) => existsSync(path))
addCheck(checks, "recoveryDB.unchangedAfterRead", recoveryHashAfterRead === recoveryHash && sidecarsAfterRead.length === 0 ? "passed" : "failed",
  `After read hash=${recoveryHashAfterRead}; sidecars=${sidecarsAfterRead.length}`)
if (beforeRows && recoveryRows) addCheck(checks, "recoveryDB.rowsMatchOldSource",
  stable(beforeRows) === stable(recoveryRows) ? "passed" : "failed",
  "Copied recovery database rows must exactly match the before-update source rows")

if (recoveryMeta?.integrityCheck !== "ok") addCheck(checks, "recoveryInspect.integrityOk", "failed", "Copied recovery inspection must report integrity_check=ok")
if (before.library?.schemaVersion !== recoveryMeta?.schemaVersion) addCheck(checks, "recovery.schemaMatchesOldSource", "failed",
  "Recovery schema does not match the before-update source library")
else addCheck(checks, "recovery.schemaMatchesOldSource", "passed", `Schema ${before.library.schemaVersion}`)

const sourceUnknown = source.expectedNativeState?.legacyUnknownKeys
const envelopeUnknown = envelope.preservedUnknownLegacyKeys
if (Array.isArray(sourceUnknown) && Array.isArray(envelopeUnknown)) {
  addCheck(checks, "nativeEnvelope.unknownKeysPreserved", stable([...envelopeUnknown].sort()) === stable([...sourceUnknown].sort()) ? "passed" : "failed",
    "Unknown legacy keys must match the source fixture")
}
const legacyReaderLocationRaw = before.rawMMKVStrings?.["bible.reader.location"]
if (typeof legacyReaderLocationRaw === "string") {
  try {
    const legacyReaderLocation = JSON.parse(legacyReaderLocationRaw)
    const missingLegacyAnchor = legacyReaderLocation && typeof legacyReaderLocation === "object" &&
      !Object.hasOwn(legacyReaderLocation, "anchor")
    addCheck(checks, "legacy.readerAnchorAbsent", missingLegacyAnchor ? "passed" : "failed",
      missingLegacyAnchor ? "Copied old Reader location has no anchor field" : "Old Reader location has an anchor field or is invalid JSON")
  } catch {
    addCheck(checks, "legacy.readerAnchorAbsent", "failed", "Old Reader location is not valid JSON")
  }
} else addCheck(checks, "legacy.readerAnchorAbsent", "failed", "Old Reader location raw string is missing")
const importedReminder = source.expectedNativeState?.rosaryReminder?.notificationID
if (typeof importedReminder === "string") addCheck(checks, "nativeEnvelope.importedReminderIDMatches",
  envelope.importedReminderID === importedReminder ? "passed" : "failed",
  `Expected imported reminder ID ${importedReminder}; observed ${String(envelope.importedReminderID)}`)
const readerAnchor = getPath(envelope.envelope?.state, "readerLocation.anchor")
addCheck(checks, "nativeEnvelope.readerAnchorAbsentInLegacyImport",
  !readerAnchor.found || readerAnchor.value == null ? "passed" : "failed",
  "Legacy Reader location must omit the optional anchor or encode it as null")

if (mapping?.pendingRequestExpectation !== undefined) {
  addCheck(checks, "pendingRequests.reviewedExpectation",
    stable(before.pendingRequests) === stable(mapping.pendingRequestExpectation) &&
    stable(after.pendingRequests) === stable(mapping.pendingRequestExpectation) ? "passed" : "failed",
    "Pending request data is checked only against the exact reviewed mapping")
} else addCheck(checks, "pendingRequests.observationOnly", "observed",
  `Before=${Array.isArray(before.pendingRequests) ? before.pendingRequests.length : "missing"}; after=${Array.isArray(after.pendingRequests) ? after.pendingRequests.length : "missing"}; scheduling is not inferred`, false)
if (Array.isArray(before.pendingRequests) && Array.isArray(after.pendingRequests)) {
  addCheck(checks, "pendingRequests.snapshotObserved", "observed",
    `Before and after snapshots captured (${before.pendingRequests.length}/${after.pendingRequests.length} requests); no scheduling result is inferred`, false)
} else addCheck(checks, "pendingRequests.snapshotUnavailable", "unavailable",
  "Copied exports do not contain both pending request snapshots", false)
if (mapping?.appGroupExpectation !== undefined) {
  addCheck(checks, "appGroup.reviewedExpectation",
    before.provenance?.appGroupIdentifier === mapping.appGroupExpectation && after.provenance?.appGroupIdentifier === mapping.appGroupExpectation ? "passed" : "failed",
    "Group identifier is checked only against the exact reviewed mapping")
} else addCheck(checks, "appGroup.observationOnly", "observed",
  `Before=${String(before.provenance?.appGroupIdentifier)}; after=${String(after.provenance?.appGroupIdentifier)}; entitlement access is not inferred`, false)
addCheck(checks, "appGroup.signedEntitlementFacts", "observed",
  `Before=${stable(before.provenance?.signedEntitlementGroups)}; after=${stable(after.provenance?.signedEntitlementGroups)}; access is not inferred`, false)

for (const item of source.defaultsForMalformedOrAbsentVariants?.cases ?? []) {
  addCheck(checks, `sourceOnly.${item.name}`, "unavailable",
    "Source-only absent/malformed case has no Main runtime observation", false)
}

const requiredFailures = checks.filter((check) => check.required && check.status !== "passed")
const report = {
  formatVersion: 1,
  kind: "l27-read-only-update-evidence-comparison",
  result: requiredFailures.length > 0 ? "failed" :
    before.provenance?.captureKind === "main-copied-old-app" ? "passed" : "helper-only",
  generatedAt: new Date().toISOString(),
  runtimeBehaviorObservedByThisTool: false,
  comparedMainSuppliedEvidence: before.provenance?.captureKind === "main-copied-old-app" &&
    after.provenance?.captureKind === "main-copied-old-app",
  evidenceOriginLabel: before.provenance?.captureKind === "helper-only-synthetic" ? "helper-only synthetic fixture" :
    before.provenance?.captureKind === "main-copied-old-app" ? "Main-copied old-app export" : "unverified export origin",
  inputHashes,
  counts: {
    checkCount: checks.length,
    requiredCheckCount: checks.filter((check) => check.required).length,
    requiredPassedCount: checks.filter((check) => check.required && check.status === "passed").length,
    requiredFailedOrUnavailableCount: requiredFailures.length,
    sourceOnlyUnavailableCount: checks.filter((check) => check.status === "unavailable").length,
    beforeRows: beforeRows ? Object.fromEntries(tableNames.map((name) => [name, beforeRows[name].length])) : null,
    recoveryRows: recoveryRows ? Object.fromEntries(tableNames.map((name) => [name, recoveryRows![name].length])) : null,
    rawLegacyKeyCountBefore: before.rawMMKVStrings ? Object.keys(before.rawMMKVStrings).length : null,
    rawLegacyKeyCountAfter: after.rawMMKVStrings ? Object.keys(after.rawMMKVStrings).length : null,
  },
  authority: {
    sourceExpectations: "Source-generated constants and executed repository outputs; source-only malformed/absent cases remain unobserved.",
    oldSourceBefore: "Authority for actual pre-update raw MMKV strings and SQLite rows.",
    oldSourceAfter: "Used only to verify protected inputs remain unchanged after update.",
    nativeEnvelope: "Authority for observed decoded native state, importVersion, and revision.",
    recoveryDB: "Copied self-contained DELETE-mode database, opened read-only for this comparison.",
    expectationMapping: mapping ? mapping.reviewAuthority : null,
    noLivePathsRead: true,
  },
  checks,
  failedRequiredChecks: requiredFailures.map(({ id, detail }) => ({ id, detail })),
}

if (!outputExistsEmpty) mkdirSync(outputRoot, { recursive: false })
writeFileSync(resolve(outputRoot, "comparison-report.json"), `${JSON.stringify(report, null, 2)}\n`, { flag: "wx" })
writeFileSync(resolve(outputRoot, "comparison-report.sha256"), `${sha256(Buffer.from(`${JSON.stringify(report, null, 2)}\n`))}  comparison-report.json\n`, { flag: "wx" })
console.log(JSON.stringify({ output: outputRoot, result: report.result, counts: report.counts }, null, 2))
if (report.result === "failed") process.exitCode = 1
