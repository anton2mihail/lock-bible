# L27 full fixture review

Date: 6 October 2026.
Reviewer: Sol (architecture, review, and acceptance).
Status: **Accepted with fixes.** The fixture bytes, the host evidence, and the comparator change are accepted. Main must not seed until required fixes 1–6 are in place. No fix changes a fixture file or the manifest.

## Reviewed boundary

Sol did not use a simulator, build, or run the host importer. Sol read copies only. The scratch copies are outside the repository.

| Item | SHA-256 |
| --- | --- |
| `docs/native/reviews/L27-full-fixture-preparation.md` | `03ae27daf54650c03e5542b60bc4f2c2f560d3f5aa6a8a427bec52c4124d559d` |
| `scripts/native/source-fixtures/l27/l27_fixture.py` | `2b2eb4c87c890228b3c11fa53d5610bdb0a44e4eb29b900c3450321f917a0dc2` |
| `scripts/native/source-fixtures/l27/build-full-fixture-data.ts` | `8e586f37bae4859c21c08f01bfb1656562622087bd264bf5334b2442247c60ca` |
| `scripts/native/source-fixtures/l27/host-importer/Sources/L27HostImporter/main.swift` | `edcd6ee4c2048fabb6d12c2f914bbf1f83aab15c88904c9e0f4d69fa7465280a` |
| `scripts/native/source-fixtures/l27/compare-update-evidence.ts` | `12002bb9d6ca2f89a7e6f91c7bd8563091583c37de14c95b262e21f9681e312d` (HEAD `9a36921d…`) |
| `scripts/native/source-fixtures/l27/compare-update-evidence-README.md` | `4e42f6260a108073986951ebe49011d96f4f10d030f0ed12b6ba2182ffbba406` (HEAD `abfe78db…`) |
| `scripts/native/source-fixtures/l27/README.md` | `efdb4315b6918e85993b93f62dff730ddea2ddeeaf8017075c09eec1ce0a985a` |
| `scripts/native/source-fixtures/l27/prepare-source-expectations.ts` | `c62d787673d8723cc757b58f778a0b9eb477994d64e96be0595a208fdb011caf` (unchanged, accepted) |
| `build/native-evidence/L27/full-fixture-01/manifest.json` | `e95f67e49e9a55fb067a914af80a902e6f9883bd4ecf9b4fcfac8ec6f4e945f1` |
| `build/native-evidence/L27/full-fixture-01-host-check/host-run-summary.json` | `e2edc7d16adf3c65355f44d1b8f2a194416117ab5117de8578289c8d38c643f9` |

All 14 manifest rows match the files on disk: SHA-256 and mode. The manifest names the tool `2b2eb4c8…`, the data builder `8e586f37…`, the MMKV decoder `17c6f0cc…`, and the committed MMKV creator `scripts/native/source-fixtures/l04/create-mmk-v2-fixture.cpp` (`e83c468a…`).

## Scope note

The source contract limited the earlier preparation step: Source did not create MMKV or database bytes. This fixture is a later step that the coordinator requested. Sol accepts Source-made old-format bytes as the L27 seed. The contract rule stays: Main's actual pre-install export of the old container is the authority for exact values. Required fix 3 makes that export follow a real old-app process.

## Independent checks

### MMKV

Sol decoded a copy with Sol's own decoder (not `mmkv_decode.py`). The meta CRC and the computed CRC are both `67d0d3ff` over 4644 bytes. The tail is zero. There are 45 keys: 15 preference keys, 3 reflections, and 27 novenas. The final strings equal `rawLegacyMMKVStrings` in `expected/source-expectations.json` exactly.

Spot values: `ignite.themeScheme` is the raw string `dark` (not JSON). `bible.translationId` is `"douay-rheims"`. `bible.rotationInterval` is `60`. `bible.reader.location` is John 3, `scrollY` 418.75. `rosary.reminder.v1` has `weekday` 5. The old source maps weekday 5 to Thursday (`reminders.ts:54–55`). `works.position.v1` has `{workId, sectionIndex, pageIndex, updatedAt}` only. This matches `worksService.ts:180`.

### Library

The main-file header has WAL mode (bytes 18–19 = `02 02`). Sol opened copies with sqlite3.

| Read | `user_version` | Integrity | Bookmarks | Highlights | Notes |
| --- | --- | --- | --- | --- | --- |
| Main file only (`immutable=1`) | 1 | ok | 3 | 8 | 0 |
| Main file + WAL (read-only) | 1 | ok | 3 | 8 | 3 |

Highlight overlap is correct: WEB-CE verse 1 is gold with batch `…:1:3:…`; verses 2–4 are sage with batch `…:2:4:…`. Douay–Rheims (rose) and Vulgate (blue) have verses 1–2. The Douay–Rheims note has `created_at` `1791228400090` and `updated_at` `1791228400110`.

**SHM reproduction.** Sol's read-only sqlite3 open of the copy changed the SHM from `e7aa10c5…` to `ade18957…`. The main file (`6b6aa179…`) and the WAL (`6b76aa0e…`) did not change. The new SHM hash equals the host importer's result. This confirms Source's SHM finding with a different SQLite client.

### Widget plist

The file is a binary plist with six keys. `intervalMinutes` is an integer (60). `widgetSchemaVersion`, `scope`, `translationId`, `abbreviation`, and `attribution` are strings. This matches `widgetBridge.ts:70–92`. That code writes `intervalMinutes` with `getRotationInterval()`, a number.

### Source line citations

Sol opened every cited line. All match the stated format:

`storage/index.ts:3, :43, :57`; `theme/context.tsx:62`; `ReadingSettings.tsx:97`; `bible/preferences.ts:20, :31, :42, :53`; `readingPreferences.ts:17, :89, :102, :111, :120, :129, :137, :146`; `companion/preferences.ts:12, :21`; `novena/progress.ts:6, :14`; `progressModel.ts:21`; `worksService.ts:28, :180`; `calendarNotifications.ts:7, :41, :119`; `reminders.ts:7, :122, :133`; `widgetBridge.ts:20, :70, :87`; `targets/widget/VerseWidget.swift:436`; `libraryDatabase.ts:6, :68`; `libraryRepository.ts:155, :202, :281`.

One path is wrong in the preparation document. `libraryRepository.ts` is in `src/services/library/`, not `src/services/database/`. `expected/format-sources.json` has the correct path. See optional note 1.

### Coverage against the source contract

| Contract item | Fixture | Result |
| --- | --- | --- |
| Translation, cadence, scope | Douay–Rheims, 60, `nt` | Covered |
| Every Reader preference, appearance | Extra large, Relaxed, Sans, Verse by verse, Dark | Covered |
| Legacy Reader book, chapter, offset, time | John 3, 418.75, `1791228500000` | Covered. No native anchor. |
| Guide and selection flags | both `true` | Covered |
| Ordered favorites | `meals`, `morning`, `evening` | Covered |
| Multiple Sunday reflections | 3, with quotes, new line, empty `before` | Covered |
| Both notice settings, imported Rosary ID | 07:05 on; weekly Thursday 06:45, text ID | Covered (text ID only) |
| All 27 novenas | 27 keys | Covered |
| Real Works ID with section and page | Homily 10 of John, The Confessions | Covered |
| Works paragraph / UTF-16 position | not seeded | **Correct omission.** The old app writes no paragraph field (`worksService.ts:180`). |
| Extra preserved Works field, unknown legacy key | off by default (`--probes`) | **Open.** See ruling 2 and required fix 5. |
| Library: 3 editions, bookmarks and notes per edition, overlap, batch IDs | 3 / 8 / 3 | Covered |
| Absent and malformed variants kept separate | in `source-preparation/run-03` | Covered |

## Seed tool safety

| Check | Result |
| --- | --- |
| Dry run by default | Yes (`cmd_seed` line 543). |
| `--apply` needs `--confirm-apps-stopped` and a new `--report-dir` below `build/native-evidence/L27` | Yes (lines 508–516). |
| Container bundle check | Yes. `MCMMetadataIdentifier` must be `com.nrsv.verse` (line 427). With `--udid`, the root must contain `/Devices/<UDID>/` (line 414). |
| Refuses a non-Expo install | Yes. It needs `main.jsbundle` and rejects `App/Catalogs` (lines 442–445). **Gap:** `--skip-app-check` turns this off, also with `--apply`. See required fix 2. |
| Manifest pin | `--expect-manifest-sha256` works when given. **Gap:** it is optional with `--apply`. See required fix 1. |
| Backups | Every removed, replaced, or moved file goes to `<report>/before/` first, with SHA-256, mode, and size. |
| Stale native state | The whole `Library/Application Support/John` folder is backed up file by file, then removed. `seed-report.json` lists it under `staleNativeFilesMovedAway`. |
| `verify` while the folder exists | Fails (line 487–489). |
| Copy | Temporary file, mode, then `os.replace`. |
| Comparator helpers | `export-old`, `wrap-envelope`, `inspect-recovery`, and `mapping` read only copies below `build/native-evidence/L27` and refuse an existing output. |
| `mapping` | Allows only `bible.reader.location`, `rosary.reminder.v1`, `john.calendar-notifications.v1`, and `works.position.v1`. Any other difference stops it. |

The stale native-state rule in section 4 of the preparation document is accepted. It agrees with `L25-capture-fixture-review.md`: keep the files during L25; back them up and remove them only in the L27 seed, after all L25 captures. The host `staleStateProbe` proves the risk: the real store loaded revision 2 with Psalm 23 and made no import.

## Host importer and interruption evidence

The harness links the real `JohnCore` `NativeStateStore` (Debug build, macOS) and its DEBUG checkpoint and failure hooks. It feeds decoded MMKV strings with the same key selection as `LegacyMMKVAdapter.mm`.

| Stage | Result in `host-run-summary.json` |
| --- | --- |
| First import | Revision 1, no issues, state equals the expectation, import hashes equal the MMKV files, one backup, no previous file |
| Restart | Same envelope `66db7221…`, no new backup |
| Native change | Revision 2 (`bcdd5c16…`); previous file equals revision 1 |
| Repeat update | Same revision 2 bytes, no new backup |
| Protected files | Only the SHM changed |

| Boundary (SIGKILL in a separate process) | After the kill | After 2 restarts |
| --- | --- | --- |
| `beforeStaging` | no state, no backup | revision 1, 1 backup |
| `beforeDurableCommit` | no state, 1 backup | revision 1, 2 backups |
| `afterPrimaryRename` | primary `66db7221…`, 1 backup | revision 1, 1 backup |
| `afterDurableCommit` | primary `66db7221…`, 1 backup | revision 1, 1 backup |
| Injected failure after rename | write error, primary present | revision 1 at the second start |

Every boundary ends with the expected revision 1 state. This is exact host evidence for the full fixture. Limits: stages 1–4 run in one process with new store objects; MMKV is read from decoded strings, not by the real adapter; the build is macOS Debug.

## Comparator change

The diff adds one optional argument, `--shm-policy strict|volatile`, with default `strict`. Only the check `protectedFile.unchanged.user-library.db-shm` changes in `volatile` mode. It becomes `observed` and not required, with both hashes in the detail. The main file, the WAL, and both MMKV files stay required. The report records `shmPolicy`. `observed` is an existing status. A required check still needs `passed`. **Accepted.** These hashes replace the accepted comparator hashes in `L27-full-fixture-source-contract.md`: script `12002bb9…`, README `4e42f626…`.

## Rulings

### Ruling 1: `--shm-policy volatile`

**Allowed, with conditions.** The SHM file is the WAL index. It is shared-memory state that SQLite rebuilds from the WAL. It holds no saved rows. If the main file and the WAL keep the same bytes, the saved database is the same. Sol reproduced the SHM change with a read-only open of a copy.

Conditions:

1. Use `volatile` only for stages after a new process opened the library. Record "SHM policy volatile per `L27-full-fixture-review.md`" in the run record.
2. The main file, the WAL, `mmkv.default`, and `mmkv.default.crc` stay strict. A change to one of them fails the stage.
3. The before export must show an SHM file. Record both SHM hashes from the report.
4. The complete row comparison and the recovery database checks must pass.
5. Do not use `volatile` for any file other than `user-library.db-shm`.

### Ruling 2: preservation probes

**No second simulator fixture.** The probes are not old-app formats. Do not seed them. Keep the simulator fixture old-format only. The contract items (extra Works field, unknown legacy key) still need recorded evidence. Close them with host evidence on a separate probe variant (required fix 5).

### Ruling 3: OS supplement (steps 10–13)

**Yes, as a second run (run B), after run A.**

- **Run A** (required): seed, verify, one plain old-app launch (required fix 3), export, update, and the stages. It gives exact values with only the Reader-location mapping.
- **Run B** (required for the real Rosary ID claim): seed again, run steps 10–12 in the old app, export, update. The old app makes a real `notificationId` and real pending requests through the permission alert. `mapping` covers the changed keys.

Limits for run B:

- The native snapshot helper (`2dfdae4`) is DEBUG-only. The Debug app is `com.nrsv.verse.dev`. It cannot read the pending requests of `com.nrsv.verse`. The L27 app is the Release build. **The helper cannot read L27 pending requests.** Correct step 24 and gap 1 (required fix 4).
- Accepted L27 evidence for notices: the native envelope `rosaryReminder.notificationID` equals the old MMKV `notificationId`, and both notice settings import exactly.
- Optional observation: copy the raw notification subsystem files before and after the update. Record whether the Rosary identifier is present. This is an observation only, not field-level acceptance.
- Field-level pending-request acceptance stays with L22 (Debug, `.dev`).

### Ruling 4: interruption evidence

**Enough, with amendments.** Exact boundaries come from three sources together: the host table for the full fixture (this review), the accepted Gate A Debug recovery scenarios on the simulator, and the Release best-effort kill below.

Amendments to step 23:

1. Kill with SIGKILL, as the host harness does. Read the PID with `xcrun simctl spawn <UDID> launchctl list`. Then run `xcrun simctl spawn <UDID> kill -9 <PID>`. Do not rely on `simctl terminate` alone; it does not state the signal.
2. Make at least three kill attempts, each from a fresh seed: as soon as the PID appears, about 0.3 s later, and about 1 s later.
3. After each kill and before the restart, copy `Library/Application Support/John`. Record the state files and the recovery backups. Classify the boundary from these files with the host table.
4. Each attempt must end, after two launches, with one valid revision 1 envelope equal to the expectation. Extra recovery backups are allowed. Each backup must be a valid library copy.
5. If no attempt stops the import before the durable commit, record that. The host table and Gate A then remain the exact boundary evidence.

## Required fixes

1. **`l27_fixture.py`, `cmd_seed`, after line 511.** Add:

   ```python
   if args.apply and not args.expect_manifest_sha256:
       fail("--apply needs --expect-manifest-sha256.")
   ```

2. **`l27_fixture.py`, `cmd_seed`, after line 511.** Add:

   ```python
   if args.apply and args.skip_app_check and not args.allow_nonsimulator_root:
       fail("--skip-app-check is not allowed with --apply on a simulator container.")
   ```

3. **Preparation document, steps 14–16.** Replace "If you did not run the supplement, the old app never launched. Then this step only repeats the check." with these steps. After `verify` passes, launch the old app once with no action. Wait for the Today screen. Record its PID from `launchctl list`. Stop it. Copy the container. Run `export-old` with that PID. Run `mapping`; only `bible.reader.location` may differ. The comparator requires a positive process ID (`compare-update-evidence.ts:235–238`). This launch also makes the export follow a real old-app process.

4. **Preparation document, step 24 and section 9 gap 1.** Replace both with ruling 3: the DEBUG helper is integrated at `2dfdae4`, but it runs only in the `.dev` Debug app. It cannot read `com.nrsv.verse` requests after a Release update.

5. **Probe host evidence.** Run `prepare --probes --out build/native-evidence/L27/full-fixture-01-probes` and `host-run --fixture build/native-evidence/L27/full-fixture-01-probes --out build/native-evidence/L27/full-fixture-01-probes-host-check`. Record both manifest and summary hashes in the preparation document. State what the importer does with the extra Works field and the unknown key. Do not seed the probe variant.

6. **Preparation document, preconditions.** Add after precondition 3:
   - Record the hash of `host-importer/Sources/L27HostImporter/main.swift` (`edcd6ee4…`) beside the harness binary hash `fd7549bc…`.
   - Run `xcrun simctl get_app_container <UDID> com.nrsv.verse group.com.nrsv.verse` and record the result. The seed writes the widget plist only in the data container (`Library/Preferences/group.com.nrsv.verse.plist`), where the L00 fixture observed it. If a group container exists and holds `Library/Preferences/group.com.nrsv.verse.plist`, stop. The fixture then needs a reviewed seed target for that container.
   - Replace step 23 with the ruling 4 amendments.

## Optional notes

1. Preparation document section 3: change `libraryRepository.ts:155` to `src/services/library/libraryRepository.ts:155`.
2. `check_old_app_bundle` could also compare the `main.jsbundle` SHA-256 with the L00 artifact (`35f5befd…`). Precondition 1 covers this manually.
3. Run A launches the old app once. A launch can rewrite the library SHM or checkpoint the WAL. The before export after that launch is the comparison base, so the update check stays valid.
4. After L27 runs on `37D1870B…`, the `com.nrsv.verse` container holds L27 data and the native Release app. Any later L25 baseline capture needs the Expo build again and an L25 reseed.

## Conditions for Main

1. Finish all L25 captures that need the old app on `37D1870B…` first.
2. Apply required fixes 1–6. Record the new tool hash. The manifest `e95f67e4…` stays valid.
3. Use the explicit UDID in every command. Never use `booted`.
4. Run A, then run B. Each run uses a new folder below `build/native-evidence/L27/` and a new seed.
5. Use `--shm-policy volatile` only under ruling 1.
6. A comparator result of `passed` needs Main's copied exports (`main-copied-old-app`). Host results stay `helper-only`.

## Fix re-check

Date: 6 October 2026. Sol re-checked only required fixes 1–6 and the run B open item. Sol did not use a simulator.

| File | SHA-256 |
| --- | --- |
| `scripts/native/source-fixtures/l27/l27_fixture.py` | `44752bf39221bf6e38f47711c6c9a84f6945a85a2c9766287da6a4b6503ca51e` |
| `docs/native/reviews/L27-full-fixture-preparation.md` | `ef3b4815f65187308692f7eb4d9d985f7e10f7eb663bbb67789027a89ddbd0ed` |
| `build/native-evidence/L27/full-fixture-01-probes/manifest.json` | `49dcad9e4f542d9711832f8442876d4fc2518826b48128736d01af8029669769` |
| `build/native-evidence/L27/full-fixture-01-probes-host-check/host-run-summary.json` | `7348e85d219936ee20e13503f8f47d03f32ce5f54c3e3802a7395b8b293dee1c` |
| `build/native-evidence/L27/full-fixture-01/manifest.json` | `e95f67e49e9a55fb067a914af80a902e6f9883bd4ecf9b4fcfac8ec6f4e945f1` (unchanged) |

1. **Fix 1: accepted.** `cmd_seed` lines 500–501 refuse `--apply` without `--expect-manifest-sha256`. Sol removed the four new guard lines from a copy. The result hashes to `2b2eb4c8…`, the reviewed tool. The tool change is only the two guards.
2. **Fix 2: accepted.** Lines 502–503 refuse `--apply` with `--skip-app-check` unless `--allow-nonsimulator-root` is set. Both guards run before the manifest, root, and app checks.

   Sol ran both guards on a fake container in the session scratch folder:

   | Command | Result |
   | --- | --- |
   | `--apply` with no manifest pin | `ERROR: --apply needs --expect-manifest-sha256.` exit 2 |
   | `--apply --skip-app-check` with a pin, no `--allow-nonsimulator-root` | `ERROR: --skip-app-check is not allowed with --apply on a simulator container.` exit 2 |
   | Same, on a `CoreSimulator/Devices/…` fake path | Same error, exit 2 |
   | Dry run with no pin | Allowed, exit 0, plan printed |

   No report folder was made. No file was written.
3. **Fix 3: accepted.** Step 14 has the run A plain launch, the PID from `launchctl list`, and the stop check. Step 16 uses that PID. Step 17 allows only `bible.reader.location` in run A.
4. **Fix 4: accepted.** Step 24 and gap 1 state that the DEBUG helper runs only in `com.nrsv.verse.dev` and cannot read `com.nrsv.verse` requests. Notice evidence is the envelope ID match and the exact settings import.
5. **Fix 5: accepted.** The probe variant is host only. Sol checked the summary: 26 of 26 checks pass. The comparator gives stage 1 strict 253 of 254 (SHM only), and volatile 253 of 253, 253 of 253, 257 of 257, and 257 of 257. Both the manifest and the summary record tool `44752bf3…`. The stage 1 envelope keeps `sourceExtra` `"preserve-this-field"` in the Works position `fields`. The unknown key `l27.unknown.preserved` is absent from the envelope. `LegacyMMKVAdapter.mm:97` skips it. It stays in the unchanged MMKV bytes. Sol agrees with Source's note: `preservedUnknownLegacyKeys` from `wrap-envelope` copies the expectation. It is not an observation. The evidence for the unknown key is the strict MMKV hash check.
6. **Fix 6: accepted.** Precondition 3 names tool `44752bf3…`. Precondition 3a records the harness source `edcd6ee4…` and the binary `fd7549bc…`. Precondition 3b records the App Group container result and stops if the group plist exists there. Step 23 has the ruling 4 changes. Section 3 now cites `src/services/library/libraryRepository.ts`.

**Open item: "run B starts with an Expo build reinstall": accepted, with one change.** After run A, the native Release app is installed under `com.nrsv.verse`. The seed tool refuses that install. A reinstall of the Expo build is therefore needed. The seed then backs up and removes the run A native state. Change: after each Expo reinstall (run B and each step 23 attempt), check precondition 1 again before step 4. Record the installed executable and `main.jsbundle` hashes (`ed4396fa…`, `35f5befd…`). Use `simctl install` without an uninstall, so the container stays the same.

**Final verdict: Accepted.** Main can seed after all L25 old-app captures are finished, with the change above.
