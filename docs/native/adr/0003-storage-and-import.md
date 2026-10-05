# ADR 0003: storage and import

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Status: ACCEPTED. Full L04 migration acceptance remains open.

## Decision

Keep the existing schema-1 library at `Documents/SQLite/user-library.db`. Use its rows directly. Do not copy them into another persistence model. Make a consistent SQLite backup before the first native write. Preserve passage keys, verse keys, batch IDs, text, and epoch-millisecond timestamps.

Use system SQLite with actor-owned handles, prepared values, synchronous transactions, and scoped statement cleanup. An unsupported schema is a recoverable capability error. Do not downgrade `user_version` or replace an unreadable database with an empty one.

Use the reviewed MMKV Core v2.0.0 read path as a narrow legacy adapter. Pin its source and license. Build with the reviewed `FORCE_POSIX` configuration. Open the default instance read-only and use `getString(..., false)`. Keep this dependency out of the widget. Do not include React Native, JSI, or Hermes.

Compile `LegacyMMKVAdapter.mm` with ARC. ARC manages Objective-C object lifetime across the Swift bridge. Retain the pinned vendor's per-file `-fno-objc-arc` settings. The wrapper must reject a build without ARC. Define `DEBUG=1` for adapter diagnostics only in the Debug configuration.

Locate legacy paths from the current container and configuration. Preserve the original MMKV data/CRC files and unknown keys. Read each value with its source loader semantics. The raw theme key is a distinct normalization path. Do not apply generic JSON parsing to it.

Store native private preferences and progress in one versioned envelope at `Library/Application Support/John/native-state-v1.json`. The envelope contains `formatVersion`, `revision`, `importVersion`, `importSourceHashes`, and typed `state`. It also records capability issue keys without private values. `formatVersion` is 1. A completed legacy import has `importVersion` 1.

One state actor serializes import and later writes. Encode and validate a complete temporary envelope. Atomically replace the destination. The payload and import marker are in the same replacement. Expose imported state only after replacement succeeds. Preserve the previous valid envelope and source recovery files. A failed write does not publish success.

Do not use separate UserDefaults writes for private payload and completion. That would permit a durable completion flag with incomplete state. The single envelope gives L04 a small set of recoverable commit boundaries. App Group UserDefaults remains the existing widget scalar projection.

## Import order

1. Inspect existing native state. If its supported completed envelope is valid, use it. Do not re-import over it.
2. Read legacy MMKV values without mutation.
3. Inspect the library schema. Permit creation only for a fresh install without legacy state or recovery files.
4. If the existing library is valid, make and validate its consistent backup before native completion. Keep unsupported or damaged files and report their capability error.
5. Normalize known feature values. Keep invalid raw source values in the preserved legacy files. Record affected capability keys only.
6. Validate the staged state against the fixture.
7. Commit the complete envelope atomically.
8. Expose state to feature models.
9. Project effective widget preferences.
10. Reconcile owned local reminders.

Before completion, a killed import can repeat the read and staging work. After completion, retries must keep newer native changes. Existing private files remain available for recovery. A fresh install has defaults and an explicit fresh-state envelope.

If the envelope has an unsupported format version, preserve it and return a native-state capability error. Do not import over it. If the primary envelope is damaged, validate the previous envelope before recovery. If neither existing envelope is valid, preserve both files and return a recovery error. Do not treat that condition as a fresh install.

Use a new backup attempt path after a failed SQLite backup. A partial backup file is not a completed recovery snapshot. Complete and validate the snapshot before native library writes start.

## Evidence and limits

The reviewed simulator binary read actual app-created copied MMKV bytes unchanged. It ran three-edition FTS5 and one-section bounded zlib/TEXT decode. The host backup proof retained a committed WAL row. The full-corpus host scan is preliminary.

The same-ID simulator read passed in `build/native-evidence/L01/same-id-read-01/`. The container UUID changed during installation. Library DB/WAL, search DB, and MMKV data/CRC hashes remained equal. The reviewed native executable read the retained live MMKV files and returned exit 0. This proves the narrow retained-data read path.

The harness did not commit native state or read every typed preference. L04 must prove the atomic envelope, live backup, all imported fields, killed/repeated writes, damaged state, and unsupported schemas. Gate A cannot pass from a fresh install alone.
