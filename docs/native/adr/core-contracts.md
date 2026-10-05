# Core contracts

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Status: ACCEPTED for the independent Core start. App integration, full migration, and renderer approval retain their gates.

## Package

Create `native/John/Packages/JohnCore/Package.swift` and `Sources/JohnCore/`. Use Swift 6 and iOS 26.0. Keep Foundation-only domain code. Link system SQLite and zlib through small C/system-library targets. Do not add a unit-test target. Main Luna owns the project reference and simulator run.

## Identity and data

| Type | Required fields or values |
| --- | --- |
| `TranslationID` | String values `web-ce`, `douay-rheims`, `vulgate` |
| `BookCode`, `VerseLabel` | Exact nonempty source strings; validate against repository data at the boundary |
| `PassageID` | `translationId`, `bookCode`, `chapter`, `startVerse`, `endVerse`; exact legacy key |
| `PassageSelection` | Source fields in `src/services/library/types.ts`; immutable values; validated ordered indices |
| `ReaderAnchor` | `verseLabel`, `utf16Offset` |
| `WorksAnchor` | `sectionIndex`, `paragraphIndex`, `utf16Offset` |
| `ReadingPreferences` | Source text-size, line-spacing, typeface, and layout enums; source defaults |
| `SavedItem` | Source fields, exact IDs, original timestamps and highlight batch data |
| `WorkSection` | `index`, `title`, `words`, `paragraphs` |
| `RotatingVerse` | `reference`, `bookCode`, `chapter`, `verseLabel`, `text` |

Use `Int64` for epoch-millisecond stored timestamps. Verse indices are zero-based. Chapter numbers are one-based. Unicode offsets are UTF-16 code units. Metadata and catalog types preserve source fields and optional values. Do not rename stored edition, book, passage, or verse keys.

## Repositories

Repository contracts use immutable `Sendable` inputs and outputs. Actor implementations own all handles and statements. Resource roots and the clock are injected.

| Contract | Implementation | Required behavior |
| --- | --- | --- |
| `BibleRepository` | `BundledBibleRepository` | Return editions/manifests and one requested chapter. Load a book lazily. Bound any cache. Do not decode all books at startup. |
| `SearchRepository` | `SQLiteSearchRepository` | Use source reference parser and FTS5 ordering. Scope values are `all`, `ot`, `nt`. Return the caller's request ID with results/correction. Do not convert missing results into a storage error. |
| `WorksRepository` | `SQLiteWorksRepository` | Browse catalog without opening the DB. Read contents without paragraphs. Read one requested row by work ID and section index. Return a distinct missing section. |
| `RotationRepository` | `IndexedRotationRepository` | Read exact pool counts and selected indexed records. Validate offsets and record shape. Map `.dat`; do not decode the full pool. |
| `LibraryRepository` | `SQLiteLibraryRepository` | Retain schema-1 rows at the original path. Use prepared operations and synchronous transactions. Preserve undo data and timestamps. |

The first bounded Core task implements Bible, Works, and Rotation repositories. It can prepare the shared SQLite helper and the library read/backup boundary. Full Search behavior and writable library operations remain L04/L09/L10 integration work.

Use the reviewed 400,000-byte decoded Works limit for both BLOB and TEXT. Validate a JSON string array. Return damaged data and missing section separately. Do not scan the Works corpus from runtime code.

The clock supplies the current instant and timezone offset at that instant. Keep local-date logic Gregorian. Rotation math preserves source floor and modulo behavior, including negative slots. Preserve exact OT/NT row order. The 792 fixtures remain the native acceptance set.

## Failure boundary

Use explicit errors for missing resource, invalid resource, unsupported schema, unreadable library, failed backup, and failed write. Keep recovery files unchanged. A library open failure must not create an empty replacement. A transaction rolls back in full on error. No SQL transaction can suspend before commit or rollback.

The legacy MMKV read adapter remains separate from JohnCore and the widget. The full importer and native-state envelope are not part of this first Core task.

## Handoff

Return public type/method names, source paths, package build result, and a short integration guide. Main Luna integrates the package reference and runs the repositories in the simulator. Host build success does not prove runtime parity.
