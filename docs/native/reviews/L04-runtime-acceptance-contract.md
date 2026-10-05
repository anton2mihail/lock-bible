# L04 runtime acceptance contract

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Status: required before Gate A.

## Ownership

Source Luna implements the state store, importer, library boundary, and diagnostic checkpoints. Main Luna runs the native app in the pinned simulator. Use synthetic private data. Do not add unit tests for these scenarios.

The state actor owns every durable native-state change. Feature updates must preserve unrelated state. Do not replace the current actor state with a stale UI snapshot. Return the committed revision and state after a successful update. The UI must not show a failed write as saved.

## Evidence matrix

| Scenario | Required result |
| --- | --- |
| Fresh install | Create supported native defaults and schema-1 library. Launch without legacy files. |
| Release update | Install over the old Release app without uninstalling. Preserve all fixture rows and values. |
| Recent WAL row | Keep the committed row in the consistent recovery backup and live library. |
| Full preference fixture | Compare every inventoried field after native normalization. Keep exact edition IDs, indices, timestamps, highlight batches, progress, favorites, reflections, reminders, and positions. |
| Import interrupted before commit | Relaunch and repeat staging safely. Do not publish a completed payload. |
| Import interrupted after replacement | Relaunch from the completed envelope. Do not re-import over it. |
| Native value changed after import | Keep that value on repeated startup and repeated import requests. |
| Invalid legacy value | Apply its exact source loader behavior. Record only the affected capability key. Keep the legacy source bytes. |
| Unsupported library schema | Keep original DB/WAL files. Report the library capability error. Do not downgrade or create a replacement. |
| Damaged existing library | Keep the original files. Report the library capability error. Keep independent state available where safe. |
| Unsupported native envelope | Keep the file. Report the native-state capability error. Do not import or write defaults over it. |
| Damaged primary envelope | Validate the previous envelope before recovery. If neither is valid, preserve both and report recovery failure. |
| Failed durable state write | Return failure and retain the last committed revision. Do not expose success. |
| Failed backup attempt | Keep the library. Retry with a new output path. Do not use a partial backup as a valid snapshot. |
| Unknown legacy keys | Keep the MMKV data and CRC files unchanged. Do not discard source recovery data. |

## Repository checks

Run Bible chapter and passage requests for all editions. Compare exact labels, text, and structure with canonical source data. Run one requested Works section through both real BLOB and synthetic TEXT paths. Record system SQLite and zlib versions. Verify a distinct missing-section result and bounded damaged-data errors.

Run the same indexed rotation repository against app and widget roots. Compare exact selected records and pool order. Run the 792 source rotation cases against native math when that math is available. Do not eagerly decode the complete text pools at launch.

Run the package through the production app target with Swift 6 strict concurrency. SDK-only compilation is not runtime acceptance. Save commands, build logs, file hashes, structured comparison results, and simulator captures under `build/native-evidence/L04/`.

The narrow L01 harness remains accepted for retained-data reading. It does not replace this full migration evidence.
