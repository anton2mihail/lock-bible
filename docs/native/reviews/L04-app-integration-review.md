# L04 app integration review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: source integration in progress. Simulator acceptance is open.

The app uses the accepted NativeStateStore and injected Documents/mmkv root. Its adapter is a separate app-only static target. Core and the widget must not depend on MMKV. Main owns the generated project and simulator run.

| Trigger | Finding and required result | Review status |
| --- | --- | --- |
| A URL arrives after startup | Enqueue set the drain flag before a method that rejected an active flag. Only the drain method must acquire and release it. | Corrected source reviewed. Repeated ready URLs and queued cold URLs need simulator proof. |
| A valid previous envelope is active | The app rejected every native capability string, including the recovery warning. A committed recovered envelope must remain writable through the state actor. | Corrected loaded-envelope guard reviewed. A setting action must retain damaged bytes and commit the new value. |
| A durable mutation succeeds after a transient error | Project the returned envelope and clear the error. Do not project a proposed UI snapshot before commit. | Current source uses the returned envelope. Runtime proof remains open. |
| Adapter target compiles AES and OpenSSL files | Initial generated file paths treated nested sources as root files. Preserve aes/ and aes/openssl/ paths from the authoritative vendor target. | Source correction is present. Final app build remains required. |
| Full MMKV sources compile with C++17 | Heterogeneous unordered_map find needs the vendor project's gnu++20 setting. The wrapper-only C++17 check did not prove the full target. Use gnu++20, libc++, and FORCE_POSIX=1. | Main corrected the generator. Production build 05 passed. Sol's earlier broad C++17 instruction was incomplete. |
| A valid state exists but a save or library error occurs | The shell hid capability messages when it showed its normal content. Show a concise error in the affected settings or Saved flow. Keep valid reading available. | Main has the correction request. Simulator error-state proof remains open. |
| A fresh library changes to WAL mode | The first source had an unfinished journal-mode row. Finish and finalize all validation statements. Check the transaction and statement state before a direct checkpoint of `main`. | The direct TRUNCATE checkpoint now passes. Checked close leaves an empty WAL and transient SHM on the simulator. The narrow temporary-file cleanup is reviewed. Successful bootstrap remains open. |
| Fresh library creation fails before publish | Startup committed revision 1 without a library. Later startup treated the state as completed and could not retry creation. Do not commit completion after a failed fresh bootstrap. | Guard corrected in `f01857b`. The corrected runtime failure leaves no envelope. Successful retry and existing-state missing-library protection remain open. |

Run the production matrix from `L04-runtime-acceptance-contract.md`. Source supplies fixtures and runner code in `scripts/native/source-fixtures/l04/`. Main installs, launches, interrupts, and compares files on the dedicated simulator. Host checks stay preliminary.

The failed fresh run reached `beforeStaging`, `afterFreshLibraryTransaction`, and `beforeDurableCommit`. It did not reach `beforeFreshLibraryPublish`. Its preserved result is `build/native-evidence/L04/startup-01/data-container-E1847C67/Documents/L04Outputs/fresh-install/scenario-result.json`. The run used a separate test root. It did not change the Release app data. Gate A remains open.

Source committed the expanded fixture runner at `c6c79bb`. Runner SHA-256 is `c178b723a7f26d3b606f2762eff28efaffe496034928499b5fb515ca1a163a69`. It checks full typed state, recent WAL data, concurrent initial revisions, safe fresh retry, missing-library protection, backup retry, and state recovery after replacement. These are source checks until Main supplies actual simulator results.

The first launch after the fix lacked top-level fixture metadata. It did not run the scenario. Its Today capture shows the protected earlier dev container with a missing library. It is error-state evidence. The next launch used the full fixture root and `fresh-install-accepted-04`. Its JSON reports SQLite code 6, no DB, and no envelope. The installed executable and debug dylib match the build product. Main will use a clean task-owned DerivedData path after Source supplies stable files.

The clean diagnostic build used the reviewed source hashes. A fresh process, PID 74603, ran `fresh-install-diagnostic-01`. It reports `fresh schema wal_checkpoint failed: sqlite(code: 6, message: "database table is locked")`. No library or envelope was published. This result identifies the failed operation. Source must record transaction and active-statement status before the next checkpoint change.

The diagnostic uses [`sqlite3_stmt_busy` with `sqlite3_next_stmt`](https://www.sqlite.org/c3ref/stmt_busy.html) to identify unfinished statements. [`sqlite3_txn_state`](https://www.sqlite.org/c3ref/txn_state.html) reports the connection's transaction state. If the code uses the [direct WAL checkpoint API](https://www.sqlite.org/c3ref/wal_checkpoint_v2.html), a successful TRUNCATE on `main` must return `SQLITE_OK` and zero for both frame counts. Matching negative counts do not prove a successful WAL checkpoint.

The next fresh process, PID 89259, passed the direct checkpoint. Checked close also passed in `fresh-install-close-01`. That run found only `-wal:0` and `-shm:32768`. It published no DB or envelope. The reviewed cleanup applies only to the unique unpublished bootstrap DB. It requires no active transaction or busy statement, TRUNCATE status `SQLITE_OK` with counts `0/0`, and close status `SQLITE_OK`. It rejects any rollback journal or nonempty WAL. It removes only the empty WAL and transient SHM. It then requires all sidecars absent before exclusive publication.

The reviewed source hashes are LibraryBoundary `8ffc9ca4d79e5a38be2288c73f72e804bd2bb857d12b3503fa8b1403c7cf6adb`, SQLiteSupport `ca0002c92771b00e087e229fab43c38d330d04ec86a4a67982f8c24b76ab8ef6`, and NativeStateStore `432954ceecfa0a3c3db077d9c917b40079240fc5014eafd0a6f825e0dc00f315`. Host and simulator SDK builds pass. Runtime acceptance remains open.

The clean app build in `DerivedData-fresh-retry-04` failed when Clang read a vendor header and obtained its current directory. The errors were `Operation not permitted`. The folder and file owner permissions were normal. No script sandbox error was present. The retry in known-good `DerivedData-fresh-retry-03` passed. Preserve both logs. Verify the accepted source compilation and installed binary hashes before the next fresh process. The precise environment cause remains unproved. No vendor file or user permission was changed.

`fresh-install-close-02` ran as PID 11157. Its JSON shows a published DB and revision 1. Host read-only inspection reports schema 1, integrity `ok`, and zero library rows. The runner has no library summary. Its same-actor cached load does not prove restart. Source corrected the runner to use a new actor and report the exact post-run inspection error. Main must still check a new process.

`missing-library-state-01` passes. Completed revision 1 remains readable. The missing-library capability is reported. The DB is not recreated. The first valid-import process, PID 19814, ended without JSON or captured console output. Its cause remains open. An unsupported-library run reports SQLite code 14 instead of schema 77. Its old generic capability predicate is insufficient. Require `unsupportedSchema(77)` for that case.

Every app run must record its bundle ID, PID, and `NSHomeDirectory`. Derive fixture and output paths from that process's Documents directory. Reject roots outside its current sandbox. The host must resolve `get_app_container` after install before it copies fixtures. Check this before changing SQLite open flags. A host-readable copied DB alone does not prove that the app can access that absolute path.

The runner and recovery helpers use `#if DEBUG`. Their standalone source check must pass `-D DEBUG` and `-swift-version 6`. A check without that condition can skip their bodies. Main's Debug app build remains the required integration check. The new helper check must use the fresh simulator module and both C module maps.
