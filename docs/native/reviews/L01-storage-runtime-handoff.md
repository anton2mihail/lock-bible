# L01 storage runtime handoff

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Verdict: ACCEPTED for the limited simulator read below. Full L01-M remains open.

## Reviewed source

Sol read the complete corrected proof, build script, README, host output, and binary metadata. The required SQLite cleanup, final Works step check, prepared binding checks, bounded TEXT/BLOB decode, and output-path guard are present.

| Item | SHA-256 |
| --- | --- |
| `storage_proof.mm` | `72d6dfd82877c29398561857cf825b1746f7792d19a142e533b6644df6574d7d` |
| `run-storage-proof.sh` | `7415806da73589ccd819821ba2832b99babb48e618081f9c62325f4e391c7c3f` |
| `storage-proof-simulator` | `e547c6b0ef9526030bdc4b4f89855206f055cecdfaba7d59368c5e44b0cefe63` |

The host audit passed. It decoded 16,146 sections. The maximum decoded value was 332,199 bytes. Oversized TEXT, oversized compressed data, and damaged zlib failed. Three-edition FTS queries and committed-WAL backup passed. These are preliminary host results. They do not prove simulator behavior.

## Run scope

Only the main Luna worker controls the simulator. Use the pinned iPhone 17 Pro simulator. Use `legacy-read` only. Use the copied app-created fixture under `build/native-evidence/L00/synthetic-legacy-fixture/`. Keep the live app container unchanged.

1. Verify the source and simulator-binary hashes above.
2. Resolve all input and output paths to physical paths. Do not use symbolic links. The proof guard compares normalized paths but does not resolve symbolic links.
3. Record MMKV data/CRC and both input database hashes before the run.
4. Use `bible.reader.textSize` as the expected key.
5. Load `chrysostom.homilies-on-the-gospel-of-john`, section `0`.
6. Use a new output directory under `build/native-evidence/L01/storage-runtime/`.
7. Run the arm64 simulator executable in the simulator runtime. If direct spawn is unavailable, use a small simulator app harness with the same reviewed source.
8. Save the command, exit status, runtime metadata, and output. Record the SQLite and zlib library versions when the harness can report them.
9. Compare all protected input hashes after the run. All must remain unchanged.

Use this argument order:

```text
storage-proof-simulator legacy-read <copied-search.db> <bundled-works.db> <new-output-dir> <copied-mmkv-root> bible.reader.textSize chrysostom.homilies-on-the-gospel-of-john 0
```

The run must report one MMKV string key, all three edition FTS results, exactly one Works row, and the bounded-decode recovery checks. It must exit with status 0. Do not run `host-audit` on the simulator. Do not run `synthetic-create` on the legacy fixture.

## Open acceptance conditions

This run proves MMKV key presence and byte preservation. It does not compare the decoded preference value with its expected native value. The same-ID app proof must compare the medium text-size value and all three library rows with the fixture. It must retain the data-container path after installation without uninstalling.

The app must still prove a consistent live-library backup and error handling. L04 must prove the full versioned importer and killed/repeated migration. Signed App Group retention and device-only checks remain release conditions.
