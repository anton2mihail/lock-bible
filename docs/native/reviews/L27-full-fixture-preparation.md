# L27 full fixture preparation

Date: 6 October 2026.
Owner: Source.
Status: fixture and tools prepared on the host. No simulator ran. Main owns the simulator steps. Sol accepted this work with six required fixes on 6 October 2026 (`L27-full-fixture-review.md`). This version applies those fixes.

This is handoff step 9 preparation. It follows `L27-full-fixture-source-contract.md`. It is separate from the L25 fixture. The accepted L25 fixture stays unchanged.

## Result

- The fixture holds old-app data in the old Expo app's own storage formats: MMKV, `user-library.db` with a committed WAL, and the App Group widget plist. It holds no native file.
- It covers all persistent categories that the old source writes. Section 3 lists them with the source line of each format.
- The real `JohnCore` importer ran on macOS against copies of the fixture. It imported all categories. The result equals the source expectation. It covered first import, restart, a native change, repeat update, and four process-kill boundaries.
- The existing comparator ran on that host evidence. It reports `helper-only`, with 251 of 251 required checks passed for the first import. Stages 3 and 4 pass 255 of 255.
- The stale native files in the old container are a real blocker. The host probe proved it. The seed tool moves them away and records them. See section 4.
- One conflict needed a decision. SQLite changes `user-library.db-shm` when a new process opens a library that has WAL frames. The comparator requires an unchanged SHM. I added an optional `--shm-policy volatile` flag. The default stays strict. Sol allowed it with conditions (section 10, ruling 1).
- The seed tool now refuses `--apply` without `--expect-manifest-sha256`. It also refuses `--apply` with `--skip-app-check` unless `--allow-nonsimulator-root` is set. See section 8.

## 1. Files

| Item | Path |
| --- | --- |
| Fixture | `build/native-evidence/L27/full-fixture-01/` |
| Manifest | `build/native-evidence/L27/full-fixture-01/manifest.json`, SHA-256 `e95f67e49e9a55fb067a914af80a902e6f9883bd4ecf9b4fcfac8ec6f4e945f1`, and `manifest.tsv` |
| Host evidence | `build/native-evidence/L27/full-fixture-01-host-check/` (`host-run-summary.json` SHA-256 `e2edc7d16adf3c65355f44d1b8f2a194416117ab5117de8578289c8d38c643f9`) |
| Build log and MMKV build products | `build/native-evidence/L27/full-fixture-01-work/` (not in the manifest) |
| Tool | `scripts/native/source-fixtures/l27/l27_fixture.py`, SHA-256 `44752bf39221bf6e38f47711c6c9a84f6945a85a2c9766287da6a4b6503ca51e`. This is the hash after the two seed guards of Sol's required fixes 1 and 2. The earlier tool hash `2b2eb4c87c89…` stays in `full-fixture-01/manifest.json` and in `full-fixture-01-host-check/host-run-summary.json`. Those two files were not changed. The manifest hash `e95f67e4…` is the pin; it does not depend on the tool hash. |
| Probe fixture (host only, never seeded) | `build/native-evidence/L27/full-fixture-01-probes/`, manifest SHA-256 `49dcad9e4f542d9711832f8442876d4fc2518826b48128736d01af8029669769` |
| Probe host check | `build/native-evidence/L27/full-fixture-01-probes-host-check/`, `host-run-summary.json` SHA-256 `7348e85d219936ee20e13503f8f47d03f32ce5f54c3e3802a7395b8b293dee1c` |
| Data builder | `scripts/native/source-fixtures/l27/build-full-fixture-data.ts` |
| Host importer harness | `scripts/native/source-fixtures/l27/host-importer/` |
| Comparator (optional flag added) | `scripts/native/source-fixtures/l27/compare-update-evidence.ts` |

Fixture files (container path, mode, SHA-256 first 12):

| Container path | Mode | SHA-256 | Purpose |
| --- | --- | --- | --- |
| `Documents/SQLite/bible-search.db` | 0600 | `e2ee48c4edae` | Same bytes as the bundled search DB. Copied only if different. |
| `Documents/SQLite/user-library.db` | 0644 | `6b6aa179c05c` | WAL mode. Main file holds 3 bookmarks and 8 highlights. |
| `Documents/SQLite/user-library.db-wal` | 0644 | `6b76aa0ebcc4` | Committed frames. Replay gives 3 notes and one note edit. |
| `Documents/SQLite/user-library.db-shm` | 0644 | `e7aa10c517ef` | WAL index, as a killed app leaves it. |
| `Documents/mmkv/mmkv.default` | 0700 | `7798cb0a8a8d` | 45 keys. |
| `Documents/mmkv/mmkv.default.crc` | 0700 | `c3bb368d148b` | MMKV meta and CRC. |
| `Library/Preferences/group.com.nrsv.verse.plist` | 0600 | `936941037ebb` | Widget scalars. Binary plist. |

`expected/` holds the comparator contract (`source-expectations.json`), the category table (`category-expectations.json`), decoded values, library rows, citations, and prepare checks. All modes allow owner write.

How the files were made:

- **MMKV.** `create-mmk-v2-fixture.cpp` wrote the files with MMKV Core v2.0.0. The old app uses the same core through `react-native-mmkv` 3.3.3. Source checked the output two ways: `mmkv_decode.py` (CRC passes, 45 keys equal the source rows) and the vendored host reader `storage-proof-host legacy-read` (45 keys, files unchanged).
- **Library.** The old source functions `migrateLibraryDatabase`, `toggleBookmark`, `applyHighlight`, and `saveNote` ran on a file database in WAL mode. The bookmarks and highlights were checkpointed into the main file. The notes and one note edit stayed in the WAL. Source copied the three files while the connection was open and idle. A read of the main file alone shows 0 notes. A read with the WAL shows 3.
- **Widget plist.** The six values that `widgetBridge.ts` writes. `intervalMinutes` is a number. The others are strings.

## 2. Data in the fixture

- Appearance Dark, edition Douay–Rheims, 60 minutes, scope `nt`.
- Reader: John 3, scroll 418.75, Extra large, Relaxed, Sans, Verse by verse. Both dismissal flags true.
- Three prayer favorites in a non-catalog order.
- Three Sunday reflections. One has quotes and a new line. One has an empty `before`.
- All 27 novenas. Shapes: partial, empty, and fully complete. Intentions: plain, empty, and a multi-line text with quotes and an emoji.
- Two Works positions (Homily 10 of John, and The Confessions). The old app writes no paragraph anchor, so none is seeded.
- Calendar notices on at 07:05. Rosary reminder weekly, Thursday, 06:45, with ID `L27-imported-rosary-reminder`.
- Library: 3 editions. Bookmarks 3. Highlights 8 with overlap (WEB-CE gold verses 1–3 then sage verses 2–4: final verse 1 gold, verses 2–4 sage). Notes 3. The Douay–Rheims note was edited, so its `updated_at` is later than its `created_at`.

The two preservation probes of the earlier source contract (an extra Works field and an unknown key) are not old-app formats. They are off by default. `prepare --probes` adds them. Sol ruled that the probes stay host only (section 10, ruling 2). Section 11 holds the probe evidence. Do not seed the probe fixture.

## 3. Old formats and source lines

Every format below comes from the old source. `build-full-fixture-data.ts` finds each line by its text. A source change stops the build.

| Category | Old format | Source |
| --- | --- | --- |
| MMKV | `new MMKV()`; `save` stores `JSON.stringify(value)`; `load` runs `JSON.parse` | `src/utils/storage/index.ts:3`, `:57`, `:43` |
| Appearance | Raw string in `ignite.themeScheme`. System removes the override. | `src/theme/context.tsx:62`, `src/components/ReadingSettings.tsx:97` |
| Edition, cadence, scope | `bible.translationId`, `bible.rotationInterval`, `bible.verseScope` (JSON) | `src/services/bible/preferences.ts:20`, `:31`, `:42`, `:53` |
| Reader typography | `bible.reader.textSize`, `lineSpacing`, `typeface`, `layout` (JSON strings) | `src/services/bible/readingPreferences.ts:17`, `:102`, `:111`, `:120`, `:129` |
| Reader position | `bible.reader.location` JSON `{book, chapter, scrollY, updatedAt}` | `readingPreferences.ts:89` |
| Dismissal flags | JSON `true` | `readingPreferences.ts:137`, `:146` |
| Favorites | `vesper.prayer.favorites` JSON array | `src/services/companion/preferences.ts:21` |
| Reflections | `vesper.sunday.<date>` JSON `{before, after}` | `companion/preferences.ts:12` |
| Novena progress | `novena.<id>.progress.v1` JSON `{completedDays, selectedDay, intention}` | `src/services/novena/progress.ts:6`, `:14`; `progressModel.ts:21` |
| Works positions | `works.position.v1` map `workId -> {workId, sectionIndex, pageIndex, updatedAt}` | `src/services/works/worksService.ts:28`, `:180` |
| Calendar notices | `john.calendar-notifications.v1` JSON `{enabled, hour, minute}`. The request IDs `john-calendar:<ms>` are not stored. | `src/services/companion/calendarNotifications.ts:7`, `:119`, `:41` |
| Rosary reminder | `rosary.reminder.v1` JSON with `notificationId` from the OS call | `src/services/rosary/reminders.ts:7`, `:122`, `:133` |
| Widget preferences | App Group `group.com.nrsv.verse` defaults. Interval is a number. | `src/services/widget/widgetBridge.ts:20`, `:70`, `:87` |
| Widget configurations | Static widgets. No per-widget user settings. | `targets/widget/VerseWidget.swift:436` |
| Library | WAL mode, schema 1 | `src/services/database/libraryDatabase.ts:6`, `:68`; `src/services/library/libraryRepository.ts:155`, `:202`, `:281` |

## 4. Stale native state: handling rule

**Problem.** The old container at `com.nrsv.verse` holds `Library/Application Support/John/native-state-v1.json`, `native-state-v1.previous.json`, and a `recovery/` backup. They are copies of the preserved production native state. `NativeStateStore` reads a valid primary file first. It then skips the MMKV import. If the primary is missing, it uses a valid previous file.

**Proof.** The host probe copied those two files next to the fixture and ran the real importer. It loaded revision 2 with a Psalm 23 Reader location. It made no import and no backup. See `host-run-summary.json`, `staleStateProbe`.

**Rule.**

1. The L27 seed removes the whole `Library/Application Support/John` folder before it copies the fixture. It copies every file to `<report>/before/` first, with its SHA-256 and mode. `seed-report.json` lists them under `staleNativeFilesMovedAway`.
2. `verify` fails while that folder exists. In L25 the same files are only a note.
3. Do not install any native build under `com.nrsv.verse` before `verify` passes.
4. The old Expo app does not create that folder. After the seed, the first native launch must find no native state file.
5. The tool refuses to seed when the installed app is not the old Expo build. It checks `main.jsbundle` and the absence of `App/Catalogs`.
6. Do this after all L25 captures. A later old-app capture on the same container needs a new seed and this rule again.
7. A clean container is an alternative. It needs an uninstall. Main decides that. The seed tool works on both.

## 5. What the host seeds and what needs the old app

| Item | Host seed | Needs the old app to run |
| --- | --- | --- |
| MMKV values, all keys | Yes | No |
| Library rows, WAL rows | Yes | No |
| Widget scalars | Yes (plist) | No |
| Rosary reminder ID | A text value only | A real ID is a UUID from the OS call (`reminders.ts:122`) |
| Pending Rosary request | No | Yes. Needs the notification permission alert and the reminder screen. |
| Pending calendar requests (up to 30 `john-calendar:<ms>`) | No | Yes. Same permission and the Settings screen. |
| Notification permission state | No. `simctl privacy` has no notifications service. | Yes, through the system alert. |
| Installed widget instances | No | Home screen action. Source shows static widgets only. |
| Exact SQLite and MMKV bytes written by the running app | No. The host copies are close. | Yes |

Any value that an old-app action changes goes into a reviewed mapping. `l27_fixture.py mapping` reads the copied before export. It allows only four keys: `bible.reader.location`, `rosary.reminder.v1`, `john.calendar-notifications.v1`, and `works.position.v1`. It stops on any other difference. A launch of the old app appends a new Reader location entry (seen in the L25 recon).

## 6. Expected outcomes

Source ran the real importer on macOS. The table is that observation, with the source expectation as the reference. All checks passed.

| Stage | Expected result | Host observation |
| --- | --- | --- |
| First import | Revision 1, `importVersion` 1, no issues. State equals `expectedNativeState`. `importSourceHashes` equal the MMKV data and CRC hashes. One recovery backup that holds all rows (3, 8, 3). No previous file. | Passed. Envelope SHA-256 `66db722138…`. |
| Restart (native wins) | Same envelope bytes. Revision 1. No new backup. | Passed. |
| Native change | Text size set to `large`. Revision 2. Previous file equals the revision 1 envelope. Only `readingPreferences.textSize` differs. Import hashes unchanged. | Passed. Envelope `bcdd5c1677…`. |
| Repeat update | Same revision 2 bytes. No import. No new backup. | Passed. |
| Library | Main file and WAL unchanged. Rows read from the library equal the old rows. | Main file and WAL unchanged. SHM changed. |
| MMKV | Data and CRC files unchanged. | Unchanged. |

Interruption boundaries. The harness killed the process with SIGKILL at each checkpoint of the first import. It then started the importer twice.

| Boundary | State after the kill | After restart | Second restart |
| --- | --- | --- | --- |
| `beforeStaging` | No state file. No backup. | Imports. Revision 1. 1 backup. | Stable. |
| `beforeDurableCommit` | No state file. 1 backup exists. | Imports again. Revision 1. 2 backups. | Stable. |
| `afterPrimaryRename` | Valid primary file. 1 backup. | Loads it. Revision 1. 1 backup. | Stable. |
| `afterDurableCommit` | Valid primary file. 1 backup. | Loads it. Revision 1. 1 backup. | Stable. |
| Failure after the rename (injected) | Import reports a write error. | Loads revision 1. | Stable. |

Every boundary ends with one valid revision 1 envelope that equals the expectation. A killed import can leave an extra recovery backup. Every backup is a valid library copy.

Per category (full table in `expected/category-expectations.json`; each row has the old format, the old value, the source lines, and the result at each stage): every category maps to one native path and stays unchanged at the restart and the repeat update. The two OS-linked categories (calendar notices and Rosary reminder) carry an `osState` note.

## 7. Comparator wiring

The tool makes the comparator inputs from copies. All paths stay below `build/native-evidence/L27`.

```sh
T=scripts/native/source-fixtures/l27/l27_fixture.py
python3 $T export-old --data-tree <copied container> --out <dir>/old-source-before.json \
  --capture-kind main-copied-old-app --app-version 1.2.2 --app-build 15 --process-id <pid> --signed-groups <list>
python3 $T wrap-envelope --envelope <copied native-state-v1.json> --out <dir>/native-envelope.json
python3 $T inspect-recovery --recovery-db <copied recovery .sqlite> --out <dir>/recovery-inspect.json
python3 $T mapping --source-expectations build/native-evidence/L27/full-fixture-01/expected/source-expectations.json \
  --before-export <dir>/old-source-before.json --out <dir>/mapping.json --review-authority <review path> \
  --stage "native-wins revision 2" --revision 2 \
  --native-override 'bible.reader.textSize::/readingPreferences/textSize::"large"'
bun scripts/native/source-fixtures/l27/compare-update-evidence.ts --source-expectations … --before-export … \
  --after-export … --native-envelope … --recovery-db … --recovery-inspect … --output <new dir> [--expectation-mapping …]
```

Host results (`full-fixture-01-host-check/compare/`):

| Run | Result | Required checks passed |
| --- | --- | --- |
| Stage 1, strict SHM | `failed`: `protectedFile.unchanged.user-library.db-shm` | 251 of 252 |
| Stage 1, volatile SHM | `helper-only` | 251 of 251 |
| Stage 2 restart, volatile | `helper-only` | 251 of 251 |
| Stage 3 native change with mapping, volatile | `helper-only` | 255 of 255 |
| Stage 4 repeat update with mapping, volatile | `helper-only` | 255 of 255 |

`helper-only` is correct. The inputs are host exports. Only Main's exports can give `passed`.

**SHM finding.** The main file and the WAL stay unchanged. SQLite rewrites the SHM when the first connection of a new process opens a library that has WAL frames. The real old app leaves such frames. The comparator rule "SHM unchanged" would fail on a correct update. The new flag `--shm-policy volatile` records the SHM change as an observation. The database, WAL, and MMKV stay protected. The default is `strict`. Sol reviewed the flag and allowed it under five conditions (section 10, ruling 1). The comparator (`12002bb9d6ca2f89a7e6f91c7bd8563091583c37de14c95b262e21f9681e312d`) and its README (`4e42f6260a108073986951ebe49011d96f4f10d030f0ed12b6ba2182ffbba406`) changed. The earlier accepted hashes were `9a36921d…` and `abfe78db…`.

## 8. Simulator steps for Main

Use the dedicated device `37D1870B-F16D-488A-8F20-959201F970D9`. Pass the explicit UDID to every command. Never use `booted`. Boot no other John device. Use a new folder below `build/native-evidence/L27/` for each run.

**Ordering.** Run L27 only after all L25 old-app captures on `37D1870B…` are finished. After L27, the `com.nrsv.verse` container holds L27 data and the native Release app. A later L25 baseline capture needs a new install of the Expo build and an L25 reseed.

**Two runs (Sol, ruling 3).**

- Run A (required): steps 1 to 9, then 14 to 22. It gives exact values. Only `bible.reader.location` may change.
- Run B (required for the real Rosary ID claim): reinstall the old Expo build with `simctl install`. Do not uninstall first, so the container stays the same. Check precondition 1 again before step 4. Record the installed executable and `main.jsbundle` hashes (`ed4396fa…`, `35f5befd…`). Repeat steps 4 to 9 with a new seed folder. Then do the supplement (steps 10 to 13), then steps 14 to 22.
- Interruption attempts (step 23) follow step 22.

Preconditions:

1. The old Expo Release app `com.nrsv.verse` is installed. Its executable and `main.jsbundle` hashes match the L00 artifact (`ed4396fa…`, `35f5befd…`). Version 1.2.2 (15).
2. The native Release build for the same ID is built and NOT installed. Record its product hashes.
3. Confirm these hashes: manifest `e95f67e49e9a55fb067a914af80a902e6f9883bd4ecf9b4fcfac8ec6f4e945f1`, and `l27_fixture.py` `44752bf39221bf6e38f47711c6c9a84f6945a85a2c9766287da6a4b6503ca51e`.
3a. Record two harness hashes together. Source: `host-importer/Sources/L27HostImporter/main.swift`, SHA-256 `edcd6ee4c2048fabb6d12c2f914bbf1f83aab15c88904c9e0f4d69fa7465280a`. Binary (`build/native-evidence/L27/_host-importer-build/debug/L27HostImporter`): SHA-256 `fd7549bc748bc3351c0705dda59c33f0d2483d9f44e58c14aca1f9de5611b0c9`. Both are the values of the host runs in this document. If either hash differs, record the new value and say why.
3b. Run `xcrun simctl get_app_container <UDID> com.nrsv.verse group.com.nrsv.verse`. Record the full result (a path, or the error text). The seed writes the widget plist only in the data container (`Library/Preferences/group.com.nrsv.verse.plist`). The L00 fixture observed it there. If a group container exists and holds `Library/Preferences/group.com.nrsv.verse.plist`, STOP. Do not seed. The fixture then needs a reviewed seed target for that container.

Seed:

4. Stop the old app: `xcrun simctl terminate <UDID> com.nrsv.verse`.
5. Check that it is stopped: `xcrun simctl spawn <UDID> launchctl list`. No `UIKitApplication:com.nrsv.verse[` entry may remain.
6. Dry run: `python3 $T seed --udid <UDID> --expect-manifest-sha256 <manifest hash>`. Read the plan. Confirm that it lists the stale native folder.
7. Apply: `python3 $T seed --udid <UDID> --expect-manifest-sha256 <manifest hash> --apply --confirm-apps-stopped --report-dir build/native-evidence/L27/<run>/seed`. The tool refuses `--apply` without `--expect-manifest-sha256`. It also refuses `--apply` with `--skip-app-check` unless `--allow-nonsimulator-root` is set. Do not use `--skip-app-check` on a simulator container.
8. Verify before any launch: `python3 $T verify --udid <UDID> --expect-manifest-sha256 <manifest hash>`. It must exit 0. The native state folder must be absent.
9. Record the manifest hash, the `seed-report.json` hash, the data root, and the moved stale files.

Run B only. OS supplement (real reminder ID and real pending requests):

10. Launch the old app. Open Settings, then Calendar notifications. Turn them on at 07:05. Accept the system alert.
11. Open Pray, then Rosary, then Reminders. Choose weekly, Thursday, 06:45. Turn it on.
12. Record the PID as in step 14c. Terminate the old app. Copy the raw notification subsystem files.
13. The old app changed MMKV. Use the `mapping` command in step 17 to record it. Run A does not do this supplement. In run A the reminder ID stays the text value, and `pendingRequests` stays empty.

Before export (both runs):

14. Launch the old app once, and record the process.
    1. Run A: after `verify` (step 8) passes, launch the old app once. Take no action. Run B: use the launch of steps 10 to 12.
    2. Wait for the Today screen.
    3. Run `xcrun simctl spawn <UDID> launchctl list`. Find the `UIKitApplication:com.nrsv.verse[` entry. Record its PID. If you launch more than once, record the PID of the last launch.
    4. Terminate the old app. Check it as in step 5.
    The comparator needs a positive process ID (`compare-update-evidence.ts:235–238`). This launch also makes the export follow a real old-app process. A launch can rewrite the library SHM or checkpoint the WAL. The export after this launch is the comparison base.
15. Copy the data container (`Documents`, `Library`) to `build/native-evidence/L27/<run>/before-tree`. Hash every file.
16. Run `export-old` on the copy with `--capture-kind main-copied-old-app`, the real version, build, and the PID from step 14.
17. Run `mapping`. Run A: only `bible.reader.location` may differ. If the mapping lists any other key, stop. Run B: the tool also allows `rosary.reminder.v1` and `john.calendar-notifications.v1`. It refuses any key that is not allowed.

Update:

18. Install the native Release app over the old app. Do not uninstall: `xcrun simctl install <UDID> <native Release John.app>`. Record the new container UUID.
19. Launch the native app. Wait for the Today screen. Terminate it.
20. Copy the container. Copy `native-state-v1.json` and the recovery backup. Run `wrap-envelope`, `inspect-recovery`, `export-old`, and the comparator (stage 1). Use `--shm-policy volatile` only under ruling 1 (section 10).
21. Native wins: in Settings change the Reader text size to Large. Terminate. Launch. Check Large. Terminate. Copy. Run the comparator with the mapping (revision 2).
22. Repeat update: install the same native Release again with no uninstall. Launch. Terminate. Copy. Check that the envelope bytes equal step 21 and that no new recovery backup exists. Run the comparator.
23. Interruption (Release, best effort; Sol, ruling 4). Make at least three attempts. Each attempt starts from a fresh seed. For each attempt:
    1. Reinstall the old Expo build with `simctl install`. Do not uninstall first. Check precondition 1 again and record the installed executable and `main.jsbundle` hashes. Repeat steps 4 to 9 with a new folder for the attempt.
    2. Install the native Release app as in step 18.
    3. Launch the native app: `xcrun simctl launch <UDID> com.nrsv.verse`. Poll `xcrun simctl spawn <UDID> launchctl list` for the `UIKitApplication:com.nrsv.verse[` entry. Read its PID.
    4. Kill the process with SIGKILL: `xcrun simctl spawn <UDID> kill -9 <PID>`. Do not rely on `simctl terminate` alone. It does not state the signal. Kill time: attempt 1 as soon as the PID appears; attempt 2 about 0.3 s after; attempt 3 about 1 s after.
    5. Before any restart, copy `Library/Application Support/John` from the container. Record the state files and the recovery backups, each with a SHA-256.
    6. Classify the boundary from these files with the host table in section 6: no state file and no backup is the `beforeStaging` pattern; no state file and one backup is the `beforeDurableCommit` pattern; a valid primary file and one backup is the `afterPrimaryRename` or `afterDurableCommit` pattern (the two look the same).
    7. Launch the native app. Terminate it. Launch it again. Terminate it. Copy the folder again.
    8. After the second launch, the folder must hold one valid revision 1 envelope that equals the expectation. Extra recovery backups are allowed. Each backup must be a valid library copy (`inspect-recovery`).
    9. If no attempt stops the import before the durable commit, record that. Then the host table in section 6 and the accepted Gate A Debug recovery scenarios stay the exact boundary evidence.
24. Pending notification requests after the update. Do not use the native snapshot helper for L27. The DEBUG helper is integrated (commit `2dfdae4`), but it exists only in the Debug app `com.nrsv.verse.dev`. It cannot read the pending requests of `com.nrsv.verse` after a Release update. The L27 app is the Release build. The accepted L27 evidence for notices is: the native envelope `rosaryReminder.notificationID` equals the old MMKV `notificationId` (run B), and both notice settings import exactly. Optional observation (run B): copy the raw notification subsystem files before and after the update. Record whether the Rosary identifier is present. This is an observation only. It is not field-level acceptance. Field-level pending-request acceptance stays with L22 (Debug, `.dev`).

## 9. Gaps

1. Pending notification requests and permission state cannot come from the host. The old app cannot export them. The native snapshot helper (commit `2dfdae4`) is integrated, but it runs only in the `.dev` Debug app. It cannot read `com.nrsv.verse` requests after a Release update. Field-level pending-request acceptance stays with L22 (Debug, `.dev`). L27 uses the envelope ID match and the notice settings (step 24).
2. The Release build has no import checkpoints. Exact interruption boundaries are host evidence only, with the accepted Gate A Debug recovery scenarios.
3. The host harness reads decoded MMKV strings. It mirrors the key selection of `LegacyMMKVAdapter.mm`. The real MMKV adapter runs only in the app.
4. The SQLite and MMKV bytes come from the pinned MMKV core and the old source functions. They are not bytes from the running old app.
5. Installed widget configurations are not seedable. The source shows static widgets.
6. The L27 `source-expectations.json` of this fixture has no absent or malformed cases. They stay in `source-preparation/run-03`.
7. Signed App Group access, widget continuity, an older baseline, and physical-device evidence stay open, as in the source contract.

## 10. Rulings (Sol, 6 October 2026)

Source: `L27-full-fixture-review.md`. These rulings answer the four questions of the first version of this document.

1. **`--shm-policy volatile`: allowed, with five conditions.** The SHM file is the WAL index. SQLite rebuilds it from the WAL. It holds no saved rows. Sol reproduced the change with a read-only open of a copy.
    1. Use `volatile` only for stages after a new process opened the library. Write "SHM policy volatile per `L27-full-fixture-review.md`" in the run record.
    2. The main file, the WAL, `mmkv.default`, and `mmkv.default.crc` stay strict. A change to one of them fails the stage.
    3. The before export must show an SHM file. Record both SHM hashes from the report.
    4. The complete row comparison and the recovery database checks must pass.
    5. Do not use `volatile` for any file other than `user-library.db-shm`.
2. **Preservation probes: host only.** The probes are not old-app formats. Do not seed them. Keep the simulator fixture old-format only. Section 11 holds the host evidence for the two probes.
3. **OS supplement (steps 10 to 13): yes, as run B after run A.** Limits of run B: the native snapshot helper cannot read `com.nrsv.verse` pending requests (step 24). Accepted L27 notice evidence is the envelope ID match plus the exact import of both notice settings. Raw notification files are an observation only. Field-level pending-request acceptance stays with L22.
4. **Interruption evidence: enough, with the amendments in step 23.** The exact boundaries come from three sources together: the host table in section 6, the accepted Gate A Debug recovery scenarios, and the Release best-effort kill of step 23.

Conditions from the review for Main:

- Finish all L25 captures that need the old app on `37D1870B…` first (section 8, ordering).
- Use the explicit UDID in every command. Never use `booted`.
- Run A, then run B. Each run uses a new folder below `build/native-evidence/L27/` and a new seed.
- A comparator result of `passed` needs Main's copied exports (`main-copied-old-app`). Host results stay `helper-only`.

## 11. Probe host evidence (Sol required fix 5)

The probe fixture is host only. Do not seed it. It differs from the main fixture in two MMKV items: an extra field on one Works position, and one unknown key. It also adds an anchor to that Works position. The data builder also writes new library bytes, so its `user-library.db`, WAL, and SHM hashes differ from `full-fixture-01`. The main fixture was not changed.

Commands (6 October 2026, host only, no simulator):

```sh
python3 scripts/native/source-fixtures/l27/l27_fixture.py prepare --probes --out build/native-evidence/L27/full-fixture-01-probes
python3 scripts/native/source-fixtures/l27/l27_fixture.py host-run --fixture build/native-evidence/L27/full-fixture-01-probes --out build/native-evidence/L27/full-fixture-01-probes-host-check
```

| Item | SHA-256 |
| --- | --- |
| `full-fixture-01-probes/manifest.json` | `49dcad9e4f542d9711832f8442876d4fc2518826b48128736d01af8029669769` |
| `full-fixture-01-probes-host-check/host-run-summary.json` | `7348e85d219936ee20e13503f8f47d03f32ce5f54c3e3802a7395b8b293dee1c` |
| `full-fixture-01-probes/expected/source-expectations.json` | `a59a15c212a8172dbeefa191bbc0ee6160dab048f6806a9832daf60a4d4041d4` |
| Probe `mmkv.default` (46 keys) | `0d4d6febc74933353cbe1ad045d9b48cb5ab77b521ed8e375a3e2b154bf71779` |
| Probe `mmkv.default.crc` | `5ce2d7cb8bef2be72b939bca363a4881aff510d2f54ac224182de14fc97382a8` |
| Probe `user-library.db` | `97ebd5e62042050f2b87ae8c66fba57b4168a616c9f50eac15a71051e2cb38e5` |
| Probe `user-library.db-wal` | `bc6e960e0e39a79d3454b247b17b844dd64e446aef13e9d375c5c556cd0647bb` |
| Probe `user-library.db-shm` | `03d66c33048b57c7f86f5e862f2401960937b12a247b909b0818dc7c39c15835` |
| Harness binary (reused build) | `fd7549bc748bc3351c0705dda59c33f0d2483d9f44e58c14aca1f9de5611b0c9` |
| Stage 1 envelope | `b8294466d9b30125e507a08d2084a88b6240afe170b012ad947e606b135357e5` |
| Stage 3 envelope (revision 2) | `dbc6bd27727042b9460a219714dcd792aeb2814cbbc9877b4661d8839cef9632` |

The probe manifest records the tool hash `44752bf3…`. The host summary records the same tool hash.

Host results: all 26 summary checks passed. Stage 1 revision 1, no issues, state equals expectation. Restart: same bytes. Native change: revision 2, only `textSize` changed. Repeat update: same bytes. All four interrupt boundaries and the injected failure end with revision 1 equal to the expectation. Only the SHM changed. Comparator results (all `helper-only`): stage 1 strict `failed` on the SHM check only (253 of 254 required checks); stage 1 volatile 253 of 253; restart 253 of 253; native change 257 of 257; repeat update 257 of 257. The stale-state probe is unchanged: the real store loads revision 2 and makes no import.

What the importer does with the two probes:

- **Extra Works field `sourceExtra`.** `LegacyStateNormalizer.swift` checks only that `sectionIndex` is a finite number. It then keeps the whole position object as `WorkReadingPosition(fields:)`. The envelope holds `worksPositions["chrysostom.homilies-on-the-gospel-of-john"].fields` with `sourceExtra` `"preserve-this-field"`, the added `anchor` (`paragraphIndex` 2, `utf16Offset` 57), `pageIndex`, `sectionIndex`, `updatedAt`, and `workId`. The importer preserves the extra field exactly. The state still equals the expectation, and the field is unchanged at restart, native change, and repeat update.
- **Unknown key `l27.unknown.preserved`.** The importer does not import it. `LegacyMMKVAdapter.mm` (line 97) skips every key that is not in the known set and does not start with `vesper.sunday.`. The host harness uses the same selection. The key is absent from the native envelope. It stays in MMKV: `mmkv.default` and `mmkv.default.crc` are unchanged at every stage, and both comparator exports show 46 keys before and after. The envelope check `preservedUnknownLegacyKeys` that the `wrap-envelope` helper writes is a copy of the expectation list. It is not an observation of the envelope. The evidence for this key is the unchanged MMKV bytes.
