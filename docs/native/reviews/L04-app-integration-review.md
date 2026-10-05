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
| A fresh library changes to WAL mode | The first source had an unfinished journal-mode row. Finishing the rows did not remove the observed SQLite code 6 failure. Identify the exact failed operation and finalize all validation statements before the next write. | Corrected simulator run still fails. Source must supply operation context and explicit finalization. The next app build must have verified binary provenance. |
| Fresh library creation fails before publish | Startup committed revision 1 without a library. Later startup treated the state as completed and could not retry creation. Do not commit completion after a failed fresh bootstrap. | Guard corrected in `f01857b`. The corrected runtime failure leaves no envelope. Successful retry and existing-state missing-library protection remain open. |

Run the production matrix from `L04-runtime-acceptance-contract.md`. Source supplies fixtures and runner code in `scripts/native/source-fixtures/l04/`. Main installs, launches, interrupts, and compares files on the dedicated simulator. Host checks stay preliminary.

The failed fresh run reached `beforeStaging`, `afterFreshLibraryTransaction`, and `beforeDurableCommit`. It did not reach `beforeFreshLibraryPublish`. Main preserved its output under `build/native-evidence/L04/fixtures/gate-a-synthetic`. The run used a separate test root. It did not change the Release app data. Gate A remains open.

Source committed the expanded fixture runner at `c6c79bb`. Runner SHA-256 is `c178b723a7f26d3b606f2762eff28efaffe496034928499b5fb515ca1a163a69`. It checks full typed state, recent WAL data, concurrent initial revisions, safe fresh retry, missing-library protection, backup retry, and state recovery after replacement. These are source checks until Main supplies actual simulator results.

The first launch after the fix lacked top-level fixture metadata. It did not run the scenario. Its Today capture shows the protected earlier dev container with a missing library. It is error-state evidence. The next launch used the full fixture root and `fresh-install-accepted-04`. Its JSON reports SQLite code 6, no DB, and no envelope. The installed executable and debug dylib match the build product. Main will use a clean task-owned DerivedData path after Source supplies stable files.
