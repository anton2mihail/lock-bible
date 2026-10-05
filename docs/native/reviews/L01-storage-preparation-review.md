# L01 storage preparation review

## Follow-up review

Sol read the corrected source with SHA-256 `2bf94fe1c54c2745efa1a2c7bf12734e4a53cb4cbc6b2ef86f99f654cc282c49`. Separate creation and read modes fix the unconditional MMKV deletion. The one-row Works query, three-edition FTS order, and five-second backup deadline address the requested scope changes.

Runtime handoff remains pending. The worker must finish failure-path cleanup for SQLite objects. The Works loop must check its final step result. The output path must not overlap an input. A zero-byte TEXT value must not pass a null pointer to the string constructor. An oversized TEXT fixture must prove the output bound.

The main worker will use a copied app-created fixture for the first simulator read. It will preserve the live baseline container. This check proves format compatibility only. The same-ID install and read remain required for full L01-M.

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Worker: GPT-6 Luna source/resource worker.
Verdict: CHANGES REQUIRED before simulator handoff.
Reviewed source hash: `0a07fddef9534b1cc9826233f02703ab7b6cb3fda2bed630e4b96dbb5d649701`.
Reviewed source: `scripts/native/source-fixtures/l01/storage_proof.mm`.
Toolchain reported by worker: Xcode 26.6 (`17F113`), SDK 26.5.

## Evidence reviewed

Sol read the complete C++/Objective-C++ proof and build script. Sol read the host run, source hashes, and binary-type record. The host run reports MMKV synthetic reads, one WEB-CE FTS query, all 16,146 compressed works sections, TEXT fallback, corrupt/oversized BLOB rejection, and a SQLite WAL backup row.

The largest decoded section is reported as 332,199 bytes. The proof uses a 400,000-byte limit. This full-corpus host sweep is a preliminary data audit. The iOS simulator binary was compiled and linked. It was not run. No actual app-derived MMKV files were read. No update retention was proved.

## Required corrections

| Severity | File and function | Trigger | Observed | Expected and check |
| --- | --- | --- | --- | --- |
| P1 | `storage_proof.mm`, `main` | Pass an actual legacy MMKV fixture root | `fs::remove_all(mmkv)` deletes that root before synthetic setup | Separate legacy-read and synthetic-create modes. Legacy-read never changes input files. Synthetic creation uses a new output-only directory and rejects existing content. Verify identical data/CRC hashes after read and after rejected creation. |
| P2 | `storage_proof.mm`, `decodeSection` | Supply oversized TEXT or an invalid/null column buffer | TEXT bypasses `maxBytes`; pointer use lacks explicit checks | Apply one size bound to TEXT and BLOB. Check type, size, and pointer before copying. Verify oversized TEXT rejection and valid legacy TEXT. |
| P2 | `storage_proof.mm`, `proveFTS` | Compare native results with source in all editions | Only WEB-CE is queried. Equal-rank source ordering is absent | Use prepared values and source order: `bm25`, `book_order`, `chapter`, `verse_order`. Query all three editions. Record IDs and runtime SQLite version. |
| P2 | `storage_proof.mm`, `proveSQLiteBackup` | Backup returns `SQLITE_BUSY` or `SQLITE_LOCKED` | Loop has no deadline or delay | Bound retries. Return a readable failure when the deadline expires. Verify a normal committed WAL row and a controlled lock/failure result. |
| P2 | SQLite proof functions | Prepare, step, or decode throws | Handles/statements are closed only on the normal path | Use cleanup guards for handles, statements, backup objects, and SQLite error buffers. Check final step status. Re-run normal and error scenarios. |

The runtime worker was told not to use the current binary with actual MMKV paths. It confirmed that the baseline container will remain unchanged. The source worker will return corrected code, host checks, new source hashes, and exact simulator run instructions.

## Review ownership

The worker's report had replaced the Sol-owned storage contract. The worker moved its report to `scripts/native/source-fixtures/l01/README.md`. Sol restored the contract and its scope boundaries. Further worker reports belong in the assigned implementation/evidence paths.

No final storage dependency or native project choice is approved by this review. S01 remains open.
