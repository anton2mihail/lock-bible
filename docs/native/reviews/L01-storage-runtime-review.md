# L01 storage runtime review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Verdict: ACCEPTED for copied-byte compatibility on the pinned simulator. Full L01-M remains open.

Sol read `build/native-evidence/L01/storage-runtime/run-02.txt`, both input-hash reports, and the harness Info.plist. The run reports exit 0. The worker used `simctl launch --console --arch=arm64` with a separate `com.nrsv.storageproof` harness on the pinned iPhone 17 Pro iOS 26.5 simulator. The harness executable matches the accepted binary SHA-256 `e547c6b0ef9526030bdc4b4f89855206f055cecdfaba7d59368c5e44b0cefe63`.

The run found one MMKV string key with MMKV Core v2 read-only mode. MMKV data and CRC bytes remained unchanged. FTS5 returned results for all three editions. The Works query decoded exactly one section: `chrysostom.homilies-on-the-gospel-of-john`, index 0, 15,703 decoded bytes. Valid TEXT passed. Oversized TEXT, oversized compressed output, and damaged zlib failed.

All five recorded input hashes match before and after the run. The library DB hash was unchanged, but this binary does not query library rows. The native preference value was not compared. No same-ID update or container-continuity claim follows from this result.

The proof's final sentence, `No simulator was opened.`, describes its earlier host use and is false for this launch. Treat the launch record and exit status as runtime evidence. Correct that sentence in the next source revision. Preserve this raw log.

## Required completion evidence

1. Save the exact executable arguments and the harness creation/launch steps in a reproducible script or report.
2. Record SQLite and zlib versions in the next proof revision or the app proof.
3. Install the same-ID proof over the seeded old app without uninstalling. Compare the text-size value, library IDs, text, timestamps, and batches. Confirm the retained container path.
4. Prove a consistent backup of the live library before native writes.

The full importer, complete state fixture, and killed/repeated update evidence remain L04/Gate A conditions. Device-only signed-group retention remains a release condition.
