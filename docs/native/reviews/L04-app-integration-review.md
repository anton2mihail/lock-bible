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
| A fresh library changes to WAL mode | The journal-mode statement remained at its result row. The following checkpoint failed with SQLite code 6, database table is locked. Finish each statement before the next operation. | Actual simulator failure preserved. Source correction and new-root simulator run are required. |
| Fresh library creation fails before publish | Startup committed revision 1 without a library. Later startup treated the state as completed and could not retry creation. Do not commit completion after a failed fresh bootstrap. | Actual simulator failure preserved. Retry must create schema 1 and revision 1. An existing completed state with a missing library must still reject replacement. |

Run the production matrix from `L04-runtime-acceptance-contract.md`. Source supplies fixtures and runner code in `scripts/native/source-fixtures/l04/`. Main installs, launches, interrupts, and compares files on the dedicated simulator. Host checks stay preliminary.

The failed fresh run reached `beforeStaging`, `afterFreshLibraryTransaction`, and `beforeDurableCommit`. It did not reach `beforeFreshLibraryPublish`. Main preserved its output under `build/native-evidence/L04/fixtures/gate-a-synthetic`. The run used a separate test root. It did not change the Release app data. Gate A remains open.
