# Native rebuild work ledger

Updated: 6 October 2026

Current checkpoint: Gate A is accepted at Main integration `df8cc9b`. Gates B through E remain open. All 29 routes and the final release gates remain in scope. Main owns the project, shared integration, simulator, and signing actions. Source owns isolated source, resource, fixture, and simulator test preparation.

The full seeded existing-note/Saved journey is accepted at review `8f66582`. It checks all four filters, note edit/reopen/delete, bookmark deletion, and Undo. Final database schema is 1; integrity is `ok`; row counts are 2 bookmarks, 1 highlight, and 0 notes. Note creation, non-WEB identity, Undo expiry/failure, and full visual parity remain open.

Verse Moment passes the exact 2 Timothy 2:23 → Reader 2 Timothy 2 → verse 23 route with WEB-CE attribution. The short ivory card exports at 1080×1440. The actual native Copy action dismisses its share panel and removes the new temporary PNG. Both backgrounds, long text, preview agreement, repeat/cancel behavior, and complete card parity remain open. See `reviews/Remaining-gate-runtime-order.md`.

Corrected notification service source is accepted at `6e87cfa`. Simulator process 13149 passes all 25 injected-center observations in `L22/runtime-09`. Actual system permission, pending-request round trips, delivery, lifecycle refresh, and warm/cold taps remain open. The app and widget Debug property lists resolve to `group.com.nrsv.verse.dev`. Effective signed group access remains open.

Reader run 09 captures anchor `48:44` and proves the corrected Settings leaf identifier/value. Run 10 captures `47:0`; its restart image shows verse 47 and its footer image shows both controls above the tabs. The new mask stops status overlap, but its actual clip edge must agree with the capture boundary. Reflow still shows verses 15–19. Main is correcting final-layout restoration. Full Reader/Aa and matched John/Psalm/Song parity remain open. See `reviews/L07-reader-anchor-source-review.md`.

Source has prepared the isolated content and Settings/Works UI journeys. The first content batch has three test failures. Recorded frames show keyboard-covered targets for L14/L18 and a running 55-second timer for L15. The corrected gesture and timer helper is accepted at `6f83b790`; its runtime rerun remains open. Disabled-notice feedback is accepted with matching installed/product hashes and final disabled state. Actual system permission and delivery remain open. See `reviews/L13-L24-action-audit-20261006.md`.

Reader bookmark, highlight, and new-note actions are integrated at source. The pure toolbar is committed at `6681ac6b`. Main's build 16 passes. The next smoke ran the older foundation test; it did not check the new actions. Selection and new-note runtime acceptance remain open. Source's full L27 source expectations are accepted at `f0b943c`. Main will supply the actual old-app snapshot and run the update. Source prepares the Vulgate note-creation journey. L28 release-resource preparation is accepted at `329d931`; project packaging, archive, effective entitlements, and signing remain open.
Plan: [SwiftUI iOS 26 rebuild](../swiftui-ios26-rebuild-plan.md)
Branch: `codex/swiftui-ios26-rebuild`

Search repository/parser and the corrected 19-observation library comparator pass on the simulator. Reader taps observe verse 10 and range 10–12. The remaining range transition, full Search UI behavior, widgets, content persistence/temporary state, Works resume, media lifecycle, and final release evidence remain open. Do not repeat accepted Gate A or Saved checks without a relevant change or a specific fault.

| Ticket | Owner | Depends on | Status | Implementation SHA | Sol verdict | Evidence / note |
| --- | --- | --- | --- | --- | --- | --- |
| L00 | Main and Source Luna | None | Source inventory accepted; full route capture open | `7aaede8`, `07287f9` | Staged acceptance | L00 inventory and core simulator baseline |
| S00 | GPT-6.1 Sol | L00 | Accepted for staged baseline | `587be12` | Accepted | Full route and device evidence remains tracked |
| L01 | Main and Source Luna | S00 | Minimum renderer and same-ID read accepted | `3bebe1a` | Accepted for S01 | Full importer proof remains L04 |
| S01 | GPT-6.1 Sol | L01 | Contracts accepted | `587be12` | Accepted | ADRs 0001–0006 and Core contracts |
| L02 | Main Luna | S01 | Swift 6 build and expanded simulator UI test pass | `c997283` | Foundation accepted; hosted CI unobserved | `docs/native/L02-runtime.md`; post-cleanup integrity and UI automation target remain open |
| L03 | Source Luna | S01, L02 | Indexed resources and provenance correction accepted | `3e84efa`, `91a57a8` | Source staging accepted | 377 exact files; manifest `dc108b37a9d3cca837b931026add9db619642a9a395c231cc98b8ea487fe6ebc` |
| L04 | Source Luna; Main owns runtime | L02, L03 | Required bounded storage and same-ID Release runtime checks pass | `2aaef1d`, `0fa667f`, `f01857b`, `a647491`, `41608bd`, `d3e7b73`, `f7dfb6e`, `c62195f`; runner `082661c`; app `df8cc9b` | Accepted for Gate A | `L04-error-recovery-and-closed-wal-review.md`; `L04-private-read-copy-source-review.md`; `L04-same-id-release-import-review.md` |
| L05 | Main Luna | L02, S01 | Foundation, cold startup, durable size, failure-state controls, and same-process repeated URLs pass | `c997283`, `df8cc9b` | Foundation accepted; full chrome remains later | `Gate-A-acceptance.md`; full Reader and route comparisons remain open |
| Gate A | GPT-6.1 Sol | L02–L05 | Accepted for the foundation scope | `df8cc9b` | Accepted | `Gate-A-acceptance.md`; full Reader, route fidelity, signing, and final release remain later gates |
| L06–L07 | Main Luna | Reviewed L04 runtime; L01 | Source build passes; UI04 observes the first two range transitions | Pending | Remaining runtime and visual corrections required | `L06/reader-build-03.log`; `L06/reader-ui-04.log`; matched valid-library images and full parity remain open |
| L08–L12 | Main and Source Luna | Plan dependencies | L08 active; L09 repository runtime accepted; L10 comparator19/19 accepted; full seeded existing-note/Saved/delete/Undo UI accepted; exact Verse Moment-to-Reader route passes | L09 `88ec254`; L10 `d6d5c00`; comparator `18c9306`; UI review `8f66582`; source fixtures `2429a8b`, `7473d79`, `ee6ca10`, `cb355d4` | Bounded runtime acceptance | Full Reader/Aa, new note/non-WEB identity, remaining Search/Verse Moment controls and visuals, widget runtime remain open |
| Gate B | GPT-6.1 Sol | L06–L12 | Active | N/A | Pending | Full Reader/Aa, exact Search, existing-user library, Saved/notes, Verse Moment/widgets, offline fresh/upgrade flows |
| L13–L19 | Source Luna; Main owns integration/runtime | Plan dependencies | Complete source batch and target inclusion pass; short ivory PNG/Copy/temp cleanup passes; other native runtime active | Core `d1b045a`, `5fcd729`; feature scopes `8ddb2dc`, `774fc84`; source fixtures `1439075`, `67158cf`, `123ce62`, `32efc89`; contract `53290b3` | Bounded export acceptance; full runtime pending | Exact content persistence/temporary state, both/long PNG and preview agreement, all-route visuals remain open |
| Gate C | GPT-6.1 Sol | L13–L19 | Active | N/A | Pending | Devotional routes, source content, persistent and temporary state |
| L20–L24 | Source owns isolated source/tests; Main owns shared integration/lifecycle/runtime | Plan dependencies | Target builds pass; L22 injected-center comparison25/25 accepted; full route/OS runtime active | Feature scopes `8ddb2dc`, `774fc84`; notice views `a7b2649`; service `6e87cfa`; helper `3e909b1`; semantic leaves `560c5be`; tests `a43f55a` | Bounded source/runtime acceptance | Works pagination/resume, actual notice OS behavior, media Release/lifecycle, Settings/credits, and visuals remain open |
| Gate D | GPT-6.1 Sol | L20–L24 | Queued | N/A | Pending | Works, notices, media gates, Settings |
| L25–L27 | Luna | Gates C, D for final runtime | L27 source expectations accepted; final runtime queued | L27 preparation `f0b943c` | Source preparation accepted; final runtime pending | All-route fidelity, performance, lifecycle, full release update and interruption recovery |
| Gate E | GPT-6.1 Sol | L25–L27 | Queued | N/A | Pending | Full integration and parity review |
| L28 | Luna | Gate E for final archive | Release resource source preparation accepted; final archive queued | `329d931` | Source preparation accepted | Packaging, archive, signing, privacy/API audit, screenshots, reproducible release evidence remain open |
| S02 | GPT-6.1 Sol | L28 | Queued | N/A | Pending | Final readiness review |

## Historical feature checkpoints

The following entries record earlier states. The current checkpoint above takes precedence.

The second Search/Saved run reached query results, Reader, and Saved. Filter assertions failed because a container identifier replaced all filter button identifiers. Exact result coordinates, filters, note actions, and UI parity were open at that checkpoint. The later corrected Saved flow is accepted above.

The coherent content/widget build passes at `L06/content-widget-build-05.log`. This accepts target compilation only. Works files are present but have concrete compile and first-layout corrections before inclusion. Full content, widget, Verse Moment, Works, and source-matched route runtime remain open.

The short corrected Search/Saved run passes one test in 21.048 seconds with no failures. Search navigation, Reader book agreement, and selected Notes filter are accepted. Exact passage identity, the other filters, note operations, undo, and visual parity remain open. Works source corrections are present and accepted for target inclusion. Its target compile and runtime remain open. Source begins isolated L23/L24 while Main owns the next coherent integration and L22.

## L00 checks

- [x] Build and launch the existing app on a dedicated iOS 26 simulator.
- [ ] Capture all five tab roots. Today and Read are captured. Other roots remain source-only.
- [ ] Record all 29 routes and important states in the parity matrix. The route inventory is complete. Most route states remain source-only.
- [x] Record bundle IDs, URL schemes, native metadata, and actual storage paths. App Group entitlement behavior remains unverified because the build is unsigned.
- [x] Capture a synthetic legacy-state fixture and record SQLite journal state.
- [x] Mark simulator observations separately from source-only findings.
- [x] Send the staged evidence paths, simulator details, storage findings, and build result to Sol.

No app source or target behavior changes are part of L00.

## L00 runtime evidence

- Simulator: iPhone 17 Pro, model `iPhone18,1`, iOS 26.5 runtime `23F77`, UDID `37D1870B-F16D-488A-8F20-959201F970D9`.
- Toolchain: Xcode 26.6, build 17F113. The Release simulator build passed. See `build/native-evidence/L00/old-app-release-build.log`.
- Build products: native bundle ID `com.nrsv.verse`, native version `1.2.2 (15)`. The current JavaScript app config is `1.5.0 (18)`. Record these as separate values.
- Widget bundle ID: `com.nrsv.verse.widget`. Source app group ID: `group.com.nrsv.verse`. URL schemes in the built app: `nrsv`, `com.nrsv.verse`, `exp+nrsv`.
- The build used `CODE_SIGNING_ALLOWED=NO`. The installed app has no usable signed App Group entitlement. Shared container and widget data are not verified by this run.
- App data container: `.../Containers/Data/Application/7FA0CAAF-5F22-4446-854C-C902C7EBBE21` on this simulator.
- Search DB: `Documents/SQLite/bible-search.db` (34,607,104 bytes in this run).
- User library: `Documents/SQLite/user-library.db` (schema `user_version=1`, `journal_mode=wal`), with `user-library.db-wal` and `user-library.db-shm` while active.
- Preferences: `Documents/mmkv/mmkv.default` and `Documents/mmkv/mmkv.default.crc`. The reader preference key was observed in this instance as `bible.reader.textSize` with value `medium` after a live Large then Default change.
- The fixture under `build/native-evidence/L00/synthetic-legacy-fixture/` came from a fresh dedicated simulator. UI actions created one John 1:1 bookmark, one gold highlight, and one note. The fixture also includes search DB, MMKV data and CRC, and preference plists. It is a copy. Do not run tools that can delete or mutate its source.
- Screenshots use the iPhone 17 Pro light appearance, 1206 x 2622 pixels (402 x 874 points), status bar time 9:41, and the app default text setting (Medium, Comfortable, Serif, Paragraphs) unless the image name says otherwise.
- `07-release-launch.png` shows a clean Today screen and all five tabs. `08-reader-john-1.png` shows unselected WEB-CE John 1 and all five tabs. `09-aas-live-large.png` shows live Large text while Aa is open. `10-reader-john-1-highlighted.png` shows the saved gold highlight and selected John 1:1 action sheet.
- `02-today.png` and the earlier development screenshots include the Expo developer control. They are not clean shell comparison images. The unsigned Debug app also showed a notification Keychain entitlement error; the Release capture did not show that error.
- Runtime observations currently cover Today, the Read list, John book/chapter selection, the John 1 Reader, Psalm 23 heading and poetry, Scripture search entry/results and return to John 1, the note editor, saved bookmark/highlight/note actions, and Aa live restyle. All other route states remain open.
- No complete L00 simulator parity pass is claimed. See the status per route in `docs/native/parity-matrix.md`.

## L01 prototype and runtime proof

- Sol accepted the ReaderProof renderer/pagination mechanism and selected custom flat Feather tab chrome. See ADR 0004, ADR 0006, `03-works-page-2.png`, and `04-shell-comparison.png`. Remaining visual, poetry, range, anchor, and accessibility checks move to production reader tickets.
- The reviewed read-only storage harness was installed over the seeded `com.nrsv.verse` app without an uninstall step. It read the expected MMKV key, queried the three FTS editions, decoded one Works section, and exited 0. The app container UUID changed. The new container kept exact database, WAL, search, and MMKV bytes; all three library rows matched the copied fixture. See `docs/native/reviews/L01-same-id-read-report.md`.
- A consistent online SQLite backup passed integrity check before the install. L04 must prove typed MMKV value normalization, importer writes, repeat/interruption handling, signed App Group continuity, and release update behavior.


- Preparation is permitted by `docs/native/reviews/L01-renderer-preparation-contract.md`.
- Proof-only files are under `native/Prototypes/ReaderProof/`. They are not production app code.
- Sample resources use existing WEB-CE John 1, Psalm 23, Song of Songs 1, Douay–Rheims John 1, one real Works section, and one synthetic Unicode string. See the local sample manifest.
- The prototype build and minimum simulator checks passed. The accepted mechanism is recorded in S01. Production Reader fidelity remains open.
- Sol accepted the corrected legacy-read mode for a copied-byte simulator proof. It read `bible.reader.textSize`, queried FTS5 for three editions, and decoded the requested Works section. The process returned exit 0. MMKV data/CRC and both input databases kept the same hashes. Output: `build/native-evidence/L01/storage-runtime/run-02.txt`. This does not prove same-ID app migration or compare the decoded preference value.
- The proof ran in the pinned iOS 26.5 simulator using a separate `com.nrsv.storageproof` app bundle. Its final output line says “No simulator was opened,” although `simctl launch` started the app process in the simulator. SQLite and zlib version strings were not reported.

## Earlier Gate A checkpoints

The L02 images prove the native shell and live in-memory reading controls. They do not prove the full Reader, durable preferences, migration, or widget behavior. Gate A remains open. Main can prepare bounded Reader navigation and rendering after its foundation commit. Source continues storage corrections. Main remains the only simulator and project writer.

The indexed stage contains 351 app resources (132,783,642 bytes) and 23 widget resources (18,164,087 bytes). The two output trees match across 377 files. The net app size reduction is 4,665,507 bytes. The resource verifier correction has SHA-256 `5ac5fcf3e3987c73d1f3490cf6e9131765a10cdde19c018fd8204627e60eebd9`. The verifier correction is committed at `91a57a8`.

The host rotation comparison matches 792 rows. Fixture SHA-256: `9f888bd7648c1f9422a320a3e3be1617eb2f8bbde7238377f903fb9268c528f9`. RotationMath SHA-256: `5ce600cc5940a9053044d0cf7e843d907b9129c7338e98a3b2f056ee362c4f38`. This is preliminary host evidence. Main must run the production simulator comparison.

The app-only adapter and state store compile in the production app. Build 05 passed after the target used the pinned vendor paths, gnu++20, libc++, and FORCE_POSIX. Core and the widget have no MMKV dependency.

The first separate-root fresh-install scenario failed with SQLite code 6, `database table is locked`. No library DB was published, but revision 1 state was committed. Source must finish the WAL-mode statement before the checkpoint. Source must also prevent completed state after failed fresh library creation. Main preserved the failure. Main will run a new output root after source review. The missing-library protection for existing completed state remains required. Gate A is open.

The first bootstrap correction is `f01857b`. The corrected simulator run still has SQLite code 6, but it leaves no completed state. Source is adding exact operation context and explicit statement finalization. Main verified that installed app binaries match the build product. The expanded runtime runner is `c6c79bb`. Successful fresh creation, full import, and the bounded same-ID importer run remain required.

The direct checkpoint of `main` now passes with TRUNCATE frame counts `0/0`. Checked close leaves only an empty WAL and transient SHM. Sol reviewed the narrow cleanup for the unique unpublished bootstrap DB. LibraryBoundary SHA-256 is `8ffc9ca4d79e5a38be2288c73f72e804bd2bb857d12b3503fa8b1403c7cf6adb`. SQLiteSupport is `ca0002c92771b00e087e229fab43c38d330d04ec86a4a67982f8c24b76ab8ef6`. NativeStateStore is `432954ceecfa0a3c3db077d9c917b40079240fc5014eafd0a6f825e0dc00f315`. Host and simulator SDK builds pass. Main's new DerivedData path had a Clang access failure. Its known-good path retry passes. Fresh runtime results remain required.

Signed executable metadata from three old IPA archives declares `group.com.nrsv.verse`. Their Info.plist files have no `AppGroup` key. The pinned wrapper selects `Documents/mmkv` when that key is absent. The current ad-hoc dev simulator product has no effective group entitlement. Signed group URL and file access remain unproved. See `L04-legacy-root-selection.md`.

`fresh-install-close-02` publishes schema 1 and revision 1. Core reopening has no recorded summary yet. Its cached same-actor load is not restart evidence. `missing-library-state-01` passes and keeps the missing library protected. A valid import process ends without JSON. Unsupported-library evidence has SQLite code 14 instead of the expected schema 77. Process sandbox paths, console output, and exact error predicates are required before acceptance. The standalone runner check must enable DEBUG and Swift 6.

The current process logs confirm the test paths are inside its sandbox. SQLite opens the fresh DB and clean schema-77 DB, but later operations still return code 14. The import crash report identifies an invalid retained object from the non-ARC wrapper. Main's ARC wrapper build keeps vendor no-ARC overrides. The corrected import reads MMKV and writes JSON; backup validation remains blocked by SQLite. Sol accepted the diagnostic hashes listed in `L04-app-integration-review.md` for the next simulator probe. Source prepares L09 fixtures outside active Core during that run.

PID 52936 locates the import failure at the first backup-summary PRAGMA. Source inspection and online backup pass. The backup has a WAL header and no sidecars. The raw journal-mode probe does not exercise a real read transaction. Sol approved bounded user_version, integrity, and count queries on three isolated copied DBs. Gate A remains open until fresh reopening and full typed import pass.

The real read-transaction comparison passes on source WAL plus matching sidecars. It fails at user_version for the private backup and fresh file without sidecars. Sol approved DELETE journal mode only for new private bootstrap/backup outputs. Source prepares the focused correction. Main owns fresh/import/restart validation. Existing source-library access without sidecars remains open.

`fresh-private-delete-01` passes schema/state creation and a new-actor read. A new-process restart remains required. Import reaches its validated backup but is blocked by a stale private-target SHM. Sol approved guarded cleanup at LibraryBoundary SHA-256 `51843591d7a0ca9e7727da820778f4f6b19cf07e746f5ac15f2ecb4c604bf626`. Main owns the next import run. Gate A remains open.

`valid-private-delete-02` passes full typed state and recent WAL row checks at the reviewed hash. Its schema/counts are 1 and 2/1/1. Source committed the boundary as `a647491`. Fresh/import process restarts, recovery/interruption, closed-WAL source access, and bounded same-ID production import remain open. The isolated fresh and valid-import scenarios are accepted.

Fresh and imported roots pass new-process reads at PIDs 92161 and 93437. Envelope bytes and revision 1 stay unchanged; capabilities are none. Matching diagnostic dependencies are committed at `41608bd`. The current integrity check has 101 nonempty sources and 74/74 vendor matches. Corrected MMKV damage fixtures replace padding changes with actual header/metadata/checksum damage. The first corrected error path needs process/stack diagnosis. Gate A remains open.
