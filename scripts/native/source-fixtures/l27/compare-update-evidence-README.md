# L27 copied-evidence comparator

This tool compares copied L27 update evidence. It does not open an app container. It does not read a simulator. It does not modify input files. It opens only the copied recovery database, with SQLite read-only access.

The source expectation file remains source evidence. Its fixed IDs, text, and clock values do not replace Main's actual old-app export. Main's copied `old-source-before.json` is the authority for the actual legacy strings and SQLite rows. Main's copied `old-source-after.json` proves that the update preserved those inputs. A source-to-runtime difference fails until a reviewed expectation mapping records the exact raw source value, expected native value, reason, and review authority.

## Command

Use a new evidence directory below `build/native-evidence/L27`. Pass copied files only.

```sh
bun scripts/native/source-fixtures/l27/compare-update-evidence.ts \
  --source-expectations build/native-evidence/L27/source-preparation/run-02/source-expectations.json \
  --before-export build/native-evidence/L27/main-update/before/old-source-before.json \
  --after-export build/native-evidence/L27/main-update/after/old-source-after.json \
  --native-envelope build/native-evidence/L27/main-update/after/native-envelope.json \
  --recovery-db build/native-evidence/L27/main-update/after/user-library.backup.db \
  --recovery-inspect build/native-evidence/L27/main-update/after/recovery-inspect.json \
  --output build/native-evidence/L27/comparison-run-01
```

If an actual old value differs from a source-generated value, pass `--expectation-mapping FILE`. Do not map a difference from the native result. The mapping must state a review authority and a reason for each changed field. The report lists each applied mapping.

The command writes `comparison-report.json` and `comparison-report.sha256`. It writes the report even when a required check fails. It exits with status 1 when a required check fails or is unavailable. It does not call SQLite on either old-source export. It rejects a recovery database that is not self-contained DELETE mode or that has WAL, SHM, or rollback-journal sidecars.

## Input JSON schema

`old-source-before.json` and `old-source-after.json` use this shape. Every table row must include every column in its `columns` list. The `protectedFiles` map must include all five paths shown below. An absent file uses `exists: false`, `sha256: null`, and `sizeBytes: null`.

The provenance fields `bundleID`, `appVersion`, `appBuild`, `appGroupIdentifier`, `mmkvRoot`, and `capturedAt` must be non-empty strings. `processID` must be a positive safe integer. `mmkvRoot` must be relative to the copied container. Signed entitlement groups remain an observation and do not prove access.

```json
{
  "formatVersion": 1,
  "kind": "l27-copied-old-source-export",
  "capturedAt": "2026-10-06T12:00:00.000Z",
  "provenance": {
    "captureKind": "main-copied-old-app",
    "bundleID": "copied observation",
    "appVersion": "copied observation",
    "appBuild": "copied observation",
    "processID": 12345,
    "appGroupIdentifier": "copied observation",
    "signedEntitlementGroups": ["observed group"] ,
    "mmkvRoot": "container-relative path"
  },
  "protectedFiles": {
    "user-library.db": {"exists": true, "sha256": "<64 lowercase hex>", "sizeBytes": 45056},
    "user-library.db-wal": {"exists": false, "sha256": null, "sizeBytes": null},
    "user-library.db-shm": {"exists": false, "sha256": null, "sizeBytes": null},
    "mmkv/data": {"exists": true, "sha256": "<64 lowercase hex>", "sizeBytes": 8192},
    "mmkv/crc": {"exists": true, "sha256": "<64 lowercase hex>", "sizeBytes": 4096}
  },
  "rawMMKVStrings": {"bible.translationId": "\"douay-rheims\""},
  "widgetScalars": {"translationId": {"type": "string", "value": "douay-rheims"}},
  "pendingRequests": [],
  "library": {
    "schemaVersion": 1,
    "journalMode": "wal",
    "integrityCheck": "ok",
    "tables": {
      "bookmarks": {"columns": ["id", "translation_id"], "rows": [{"id": "<actual>", "translation_id": "web-ce"}]},
      "highlights": {"columns": ["id", "batch_id"], "rows": []},
      "notes": {"columns": ["id", "note"], "rows": []}
    }
  }
}
```

For a helper-only synthetic fixture, set `captureKind` to `helper-only-synthetic`. The report then uses `result: "helper-only"`; it cannot report runtime pass. Main must use `main-copied-old-app` only for copied runtime exports and must record the collection source in its evidence notes.

The example rows only show the structure. Main must export every real table column. The comparator checks every value. The copied export must include the exact raw MMKV strings. A hash-only value cannot prove which legacy value the importer read.

`native-envelope.json` is a wrapper around the exact copied native envelope bytes. It must include those bytes as base64. The comparator hashes and parses the bytes, then requires the parsed envelope to match the exported envelope object.

```json
{
  "formatVersion": 1,
  "kind": "l27-copied-native-envelope",
  "envelopeSHA256": "<SHA-256 of decoded rawEnvelopeBase64>",
  "rawEnvelopeBase64": "<base64 of exact envelope file bytes>",
  "envelope": {
    "formatVersion": 1,
    "revision": 1,
    "importVersion": 1,
    "state": {"...": "complete decoded persistent state"}
  },
  "importedReminderID": "L27-imported-rosary-reminder",
  "preservedUnknownLegacyKeys": ["l27.unknown.preserved"]
}
```

`recovery-inspect.json` must describe the copied recovery DB at `--recovery-db`. It must contain `recovery.fileSHA256`, `recovery.schemaVersion`, `recovery.journalMode`, `recovery.integrityCheck`, and full `tables.bookmarks`, `tables.highlights`, and `tables.notes` column and row snapshots. The comparator opens the copied DB read-only. It checks SQLite header mode, actual `user_version`, `integrity_check`, all columns and row values, the copied inspection, and the old-source rows.

## Reviewed expectation mapping

Use this optional shape only when actual values differ from the source fixture. The `reviewAuthority` must name a recorded review. Every mapping entry must use that same authority.

```json
{
  "formatVersion": 1,
  "kind": "l27-reviewed-expectation-mapping",
  "reviewAuthority": "review path or commit",
  "stateOverrides": [
    {
      "sourceKey": "bible.translationId",
      "expectedRawValue": "\"douay-rheims\"",
      "nativePath": "/translationID",
      "expectedNativeValue": "douay-rheims",
      "reason": "Exact reviewed source-to-native value mapping",
      "authority": "review path or commit"
    }
  ],
  "rawLegacyOverrides": [
    {"key": "bible.reader.location", "expectedBefore": "<exact raw value>", "reason": "...", "authority": "review path or commit"}
  ],
  "sourceLibraryRowOverrides": [
    {
      "table": "notes",
      "rowIdentity": {"translation_id": "vulgate", "verse_index": 2},
      "column": "updated_at",
      "sourceExpectedValue": 1791228336790,
      "expectedActualValue": 1791228337000,
      "rationale": "Actual old-app timestamp confirmed by copied before export",
      "authority": "review path or commit"
    }
  ],
  "envelopeRevisionExpectation": {"stage": "fresh import", "expectedRevision": 1, "authority": "review path or commit"}
}
```

`expectedRevision` must be a safe integer of at least 1. Fresh import uses revision 1 unless a reviewed mapping names another stage and value.

`stateOverrides` uses JSON Pointer tokens in `nativePath`. For example, `/worksPositions/chrysostom.homilies-on-the-gospel-of-john/updatedAt` keeps the full work ID intact. A dotted path is rejected because a work ID can contain periods. A simple top-level name, such as `translationID`, is also valid.

`sourceLibraryRowOverrides` maps one source-output cell to one exact cell in one actual old row. The comparator rejects missing rows, duplicate identity matches, and values that do not match both sides of the mapping.

The source generator records logical expected state fields. The comparator projects the actual Codable wire shape for comparison. It removes the separately checked unknown-key list, unwraps `WorkReadingPosition.fields` while preserving all unknown fields inside that object, and treats omitted versus `null` as equivalent only for documented optional fields: `themeScheme`, `readerLocation`, and a null `readerLocation.anchor`. It does not require an encoded `anchor: null`.

If Main has a reviewed exact expectation for pending request data or the App Group identifier, the mapping may add `pendingRequestExpectation` or `appGroupExpectation`. Without these fields, the report records the snapshots as observations only. It does not infer that the operating system accepted a notification schedule or that a signed group is accessible.

## Required comparison checks

The comparator checks these results:

1. All input formats and mandatory fields are present. Missing data fails the report.
2. The protected DB, WAL, SHM, MMKV data, and MMKV CRC existence, size, and hash match before and after the update. An absent sidecar stays absent.
3. Every raw MMKV key and string stays exact. The key set stays exact. Unknown legacy keys stay exact.
4. Widget scalar names, types, and values match the source contract and stay unchanged.
5. Native state matches source expectations plus explicit reviewed mappings. The imported reminder ID matches. Unknown keys remain present. The legacy Reader location has no `anchor`; the imported native anchor is null. `importVersion` is 1 and the revision matches the documented stage. Fresh import requires revision 1.
6. Every SQLite row and column value matches before and after update. Schema, journal mode, and integrity remain valid.
7. The copied recovery DB has no sidecars, uses DELETE journal mode, passes actual `PRAGMA integrity_check` and `PRAGMA user_version`, and matches the before-update row snapshots and copied inspection.
8. Source-generated malformed/absent cases remain `unavailable`. They do not count as runtime checks.

Pending request and signed entitlement observations are facts only unless an exact reviewed mapping supplies an expectation. A report with a missing required field or failed required check has `result: "failed"`. The output does not claim that the installed app version, signed entitlements, OS delivery, or notification taps are accepted.

## SHM policy (optional)

The default is `--shm-policy strict`. It keeps the earlier rule: `user-library.db-shm` must stay byte-for-byte unchanged.

SQLite rebuilds the WAL index when a new process opens a library that has committed WAL frames. This happens even for a read-only open. The main file and the WAL stay unchanged. The SHM file does not. A host run of the real importer on the L27 fixture showed this (see `docs/native/reviews/L27-full-fixture-preparation.md`). With `--shm-policy volatile`, the report records the SHM change as an observation (`observed`, not required). The main database, the WAL, and the MMKV files stay protected. Use `volatile` only with a recorded review. The report has a `shmPolicy` field.
