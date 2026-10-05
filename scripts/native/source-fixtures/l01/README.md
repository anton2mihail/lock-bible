# L01 storage proof

Owner: GPT-6 Luna. Reviewer: GPT-6.1 Sol.

## Scope

This is a host proof and a simulator SDK compile. It does not open the app, install an app, or access a user container. MMKV values are synthetic. SQLite backup rows are synthetic. The Bible search and works databases are read-only baseline resources.

The proof uses the installed `react-native-mmkv` 3.3.3 package and its Core v2.0.0. The Xcode project builds both host and iOS Simulator static libraries with `FORCE_POSIX`, as the package podspec does. The adapter opens the default `mmkv.default` instance with `MMKV_READ_ONLY`. It calls `getString(..., false)` to disable in-place value modification. It records SHA-256 for both MMKV data and `.crc` files before and after reads.

The program has three modes. `synthetic-create` creates a fixture only at a path that does not exist. It fails if the path exists. `legacy-read` opens the supplied MMKV root in read-only mode. It does not create, remove, or write files in that root. It accepts a comma-separated list of expected keys, a work ID, and a section index. It decodes only that section with the source `WHERE work_id = ? AND idx = ?` query. `host-audit` runs a separate full-corpus scan. All output paths must stay separate from the MMKV root and both input databases. The program rejects paths that overlap.

The program tests these source contracts:

- It reads three synthetic MMKV string values with the v2 Core API. It checks the instance ID and compares both MMKV file hashes before and after the read.
- It prepares one parameterized FTS5 query for each bundled edition. It orders results by `bm25`, `book_order`, `chapter`, and `verse_order`.
- It reads every section in `works.db`, inflates zlib data, and checks that each result is a JSON array of strings. It also decodes a separate synthetic SQLite `TEXT` row.
- The largest decoded section in this database is 332,199 bytes: `gregory-nyssa.answer-to-eunomius-second-book`, section 0. The proof limit is 400,000 bytes. A separate 500,001-byte fixture and a damaged zlib fixture must fail.
- It keeps a SQLite source connection open in WAL mode with a committed row. It copies that state with `sqlite3_backup` and checks the copied row. Expo's `backupDatabaseAsync` calls the same SQLite backup API. This host proof does not call the Expo API.

## Run

Install the repository's locked dependencies. Run this command from the repository root:

```sh
scripts/native/source-fixtures/l01/run-storage-proof.sh
```

The command writes build logs, source hashes, a host run report, and both host and simulator binaries under `build/native-evidence/L01/storage-proof/`. The host binary reads the existing databases in place. It does not copy them.

## Acceptance limits

The host run verifies MMKV Core file compatibility with a synthetic legacy-shaped store. It does not verify the app container path or user values. The simulator executable is only compiled. It is not run. Sol and the runtime worker must use the actual simulator container for L01-M, verify the App Group `Info.plist` value and database paths, and test Expo's backup function on a live app database.

## Host result

The preparatory run passed on an arm64 Mac with Xcode 26.6 (17F113). MMKV Core v2.0.0 built for macOS and iOS Simulator with SDK 26.5. The proof source compiled and linked for the iOS 26.0 Simulator target. The simulator binary was not run.

The host proof read 16,146 valid works sections. The largest decoded JSON value was 332,199 bytes. The valid legacy `TEXT` value passed. The 500,001-byte compressed fixture and invalid zlib bytes were rejected. FTS5 returned results for `web-ce`, `douay-rheims`, and `vulgate`. The online backup kept the committed WAL row. The synthetic MMKV default instance returned three string keys. Both the data and CRC hashes matched before and after the read. Backup retries stop after five seconds.

Main Luna will first use a copied, app-created MMKV fixture. The preparatory read does not need a live MMKV root. The copy must include its data and CRC files. The same read-only mode can later inspect the actual app container after the runtime worker authorizes that check.

The runtime worker can use `build/native-evidence/L01/storage-proof/storage-proof-simulator` in an app target or simulator harness. The harness must pass these arguments to read from the copied MMKV fixture and one selected section:

```sh
storage-proof-simulator legacy-read <search.db> <works.db> <output-dir> <copied-mmkv-root> <expected-keys-csv> <work-id> <section-index>
```

The worker must set the expected keys from the legacy store. The worker must set a real work ID and section index. The output directory is separate from the read-only MMKV root. This executable compiles for arm64 iOS Simulator 26.0. This task did not install or run it.

The run report, Xcode logs, binary types, and source hashes are in `build/native-evidence/L01/storage-proof/`. The report includes the synthetic MMKV hashes. It contains no user values. The data and works databases were opened in read-only mode and were not copied.
