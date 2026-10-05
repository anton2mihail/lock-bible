# L01 storage proof contract

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Assigned worker: GPT-6 Luna source/resource worker.
Status: preparatory L01 sub-ticket allowed. Full S00 and L01 acceptance remain open.

## Scope

Prepare a small native proof while the old release-mode simulator build runs. This work does not choose the final app project or final dependencies. It does not prove update retention.

Allowed writes: `build/native-evidence/L01/storage-proof/` and `scripts/native/source-fixtures/` for reproducible proof preparation. Keep source hashes for files under ignored build output. Do not change app source, canonical resources, `native/John/`, the primary prototype project, parity matrix, work ledger, review documents, ADRs, or production configs.

The main Luna worker owns simulator control, app install/launch, baseline capture, and same-ID update work. This worker must not boot, change, install, launch, or capture the active baseline simulator. Return a runnable proof and instructions to the main worker. If a separate simulator becomes available, obtain coordination approval from Sol before using it.

## Required proof code

1. Open the existing `assets/bible/bible-search.db` with system `sqlite3` in read-only mode. Run the source FTS5 query with prepared values and `bm25`, book, chapter, and verse ordering. Include WEB-CE, Douay–Rheims, and Vulgate queries. Record result IDs and the exact SQLite library/runtime used.
2. Open `assets/works/works.db` read-only. Load one real compressed section. Use zlib-wrapped inflate. Preserve the exact paragraph array. Bound the decoded output and validate its shape.
3. Decode a separate synthetic legacy TEXT row. Apply the same output-size bound. Do not alter the bundled database. Include missing-row and damaged-BLOB results.
4. Prepare a narrow MMKV adapter using a compatible MMKV Core implementation. Prefer proving the installed v2.0.0 Core first. Exclude React Native, JSI, and Hermes from the proof target. Keep the MMKV license and source provenance.
5. Open supplied MMKV fixture paths read-only. Use the actual L00 files when the runtime worker supplies them. Do not delete, create, repair, or write those files. Do not invent a binary parser.
6. Keep synthetic fixture creation in a separate explicit mode. Use a new output-only directory. Fail if that directory already contains files. A legacy-read invocation must never call synthetic creation or deletion.
7. Report key presence, type, and fixture comparison results. Use synthetic data only. Do not log private values. Preserve unknown keys and source files. Compare data/CRC hashes before and after reads.
8. Prepare a SQLite backup-API path for a writable synthetic WAL fixture. Check that the backup contains the latest committed note/bookmark rows. Bound retries and report a failed deadline. Close/finalize all handles and statements on error. Keep each transaction synchronous in its owner.

The output directory must not overlap the MMKV input directory or either input database. Resolve paths before this check. Use the copied app-created fixture for the first simulator read. Keep the live old app container unchanged.

Use host execution only to find compile or format defects. Label host results as host results. They do not prove iOS simulator FTS5, zlib, or MMKV compatibility. A full-corpus host sweep is a preliminary data audit. The normal simulator proof must load requested sections only.

Compile the proof for the simulator SDK. The main worker must run its real code in the iOS 26 simulator before acceptance. A headless simulator process can prove system-library compatibility. The app must still prove its actual repository behavior and same-ID container continuity.

## Handoff and acceptance

Return source files, hashes, dependency/version/provenance, build command/result, fixture input paths, output paths, and the exact run instructions. Put worker reports in `scripts/native/source-fixtures/l01/README.md` or the assigned evidence directory. Keep Sol review/ADR files unchanged.

Distinguish prepared, host-checked, simulator-checked, and unverified. Sol will review the code before runtime use. The main worker will run the proof on iOS 26 after baseline capture. The later same-ID L01/L04 rehearsal must use the actual old container. A separate-ID proof with copied fixture bytes proves format compatibility only.
