# L04 error, recovery, and closed WAL review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: listed simulator cases accepted. Gate A remains open.

## Accepted error and recovery cases

The app build in `xcodebuild-wrapper-recovery-02.log` passed. The installed executable and debug library match the build product. Their SHA-256 values are `b0b42482a51245c17583e382c504ed92f6e0b4f42435131af8b154a313dd28c2` and `7612e749b9bfea56621214c15dface27c1b83169727fc86c4886419400f107c6`. The wrapper uses ARC. The vendor retains its no-ARC settings.

The three `corruption-v2/*/scenario-result-v3.json` results pass. Truncated data and metadata return through the size checks. A damaged digest returns through `file-check-failed`. Each returns a structured import failure. No native envelope or library is published. `fixture-preservation.txt` compares the source, copied input, and post-run hashes for both files. They match in all three cases. This accepts wrapper SHA-256 `8ed7764fa109dd66e002dc39b6959a750f92f64935863719b940f1431446bdd5` and the corrected active-data fixtures. Preserve the earlier crash and padding controls.

The three results under `recovery-matrix-02/` pass. Format 2 bytes remain unchanged and writes are blocked. A valid previous envelope recovers revision 1; the next write saves the damaged primary bytes before revision 2. When both envelopes are damaged, both files remain unchanged and writes are blocked. These are actual simulator results, with separate process records and output roots.

The before-commit run pauses PID 8579 at `beforeDurableCommit`. No primary exists before or after termination. New PID 8868 resumes the same root and commits revision 1. Library and WAL hashes match before and after. The after-rename run pauses PID 9103 at `afterPrimaryRename`. A valid revision-1 primary exists. The old process is absent after termination. New PID 9264 reads revision 1 and preserves the envelope bytes. These two interruption cases are accepted.

Evidence root: `build/native-evidence/L04/`. Each accepted folder retains process paths, launch records, results, and logs.

## Closed WAL decision

The host proof in `private-copy-proof-02/proof.json` builds a complete closed database with WAL header bytes `0202` and no sidecars. A separate private copy changes to DELETE mode, with bytes `0101`. Schema 1, integrity `ok`, and row counts 2/1/1 survive read-only reopen. The original fixture hashes and sidecar set remain unchanged. The proof is sufficient to choose a bounded fallback. It does not prove simulator access. The script must also record and compare the generated closed-source hash after private normalization.

The fallback applies only when an existing nonempty main file has WAL header `0202`, no WAL, SHM, or rollback journal, and direct read inspection returns `SQLITE_CANTOPEN`. Copy the stable main file to a unique owned directory. Compare its hash and sidecar set before and after copying, and before returning results. Normalize only the copy to DELETE mode. Finish all mode queries. Validate integrity, supported schema, exact required columns, and table reads. Close and reopen the copy read-only.

Keep unsupported schema as `unsupportedSchema(77)`. Reject damaged input. Do not infer a past clean close. Do not use immutable mode. Do not change source bytes or source sidecars. A missing committed WAL cannot be reconstructed from the main file.

The connection must own the private workspace. Cleanup must follow statement and connection release. Before a mutation, require a separate durable validated backup. Close and invalidate the private read cache. Write only to the original library. Later reads must use the original write connection or a new read. They must not use an old snapshot.

Main must run closed schema 1, clean schema 77, damaged input, and read-after-write cases on the simulator. Source must provide stable hashes and build results first. Same-ID production import, startup URLs, durable preferences, and matching scoped commits remain Gate A requirements.
