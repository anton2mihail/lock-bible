# L25 capture fixture review

Date: 6 October 2026.
Reviewer: Sol (architecture, review, and acceptance).
Status: **Accepted with fixes.** The fixture bytes and the seed tool are accepted. Two documentation fixes are required before Main seeds the simulator. The fixture files and the manifest do not change.

## Reviewed boundary

Sol did not use a simulator, build, or change a fixture or product file. Sol opened copies only, in the session scratch folder. Sol ran the tool `check` on the fixture trees. Sol ran `seed` and `verify` on fake container trees in the scratch folder only.

| Item | SHA-256 |
| --- | --- |
| `build/native-evidence/L25/capture-fixture-01/manifest.json` | `aee48b2c6b09cfa509e8242776914468a2a0fb8d9ea18082d634af5970c2ba58` |
| `scripts/native/source-fixtures/l25/l25_fixture.py` | `b88623dcdb2aa1a55d9b7e1777ac90de41d8ef116d55c6d84a62734f558f2fa5` |
| `scripts/native/source-fixtures/l25/mmkv_decode.py` | `17c6f0ccd78ba26a1e108263edcfd500c0e374aadceee5dc1d52595ae14759e1` |
| `docs/native/reviews/L25-capture-fixture-alignment.md` | `0f713442db129bb06c5d1cf0ecca636b7e982afccc13c4a1f4dac77a5222c8bb` |
| `native/John/SimulatorSupport/ReaderParity-README.md` | `40fab884701cb28923820435d34ce1ad64893ef3521d220ece0349a41caec3d6` |
| `native/John/SimulatorSupport/AllRouteCapture-README.md` | `bb13697169aa9ddb61ca94bbd21dd71bd3412a1f8b204654633e3f608bff9c7e` |

The manifest hash matches the coordinator's value. `toolSha256` and `mmkvDecoderSha256` in the manifest match the two script files.

All 13 manifest rows match the files on disk: SHA-256, mode, and size. The five frozen L00 inputs still match `OLD_INPUTS` (`e2ee48c4edae`, `827c7badbcf2`, `750151a47be0`, `6f3e7ca99b9c`, `f61f300fd1b0`). Their modes are 0600, 0644, 0700, 0700, and 0600. The preserved production snapshot hashes match the handoff (`files.sha256` `caf3e19a…`, `run.txt` `38dfa1d5…`).

Sol hashed every file in the fixture and in the L00 fixture before and after the `check` run. The combined hash and the file count (48) did not change. No `-wal` or `-shm` file appeared.

## Coordinator decisions (given)

1. Keep the saved John 1 Reader location in both apps. Do not re-encode MMKV for a book-list start. Document the README exception.
2. Use the frozen L00 MMKV.
3. Both apps use the real device clock. Capture both apps on the same local date and on the same side of 17:00 Toronto time. Main records host time zone and time for each run.
4. Keep the search DB copy. Skip it when it is identical.
5. The 0400 note in the handoff was about a task copy. Record current modes. Change nothing.

## Independent decode

### Old MMKV

Sol decoded a copy with a separate decoder that Sol wrote. It does not import `mmkv_decode.py`.

- The meta CRC is `353e4164`. The computed CRC32 over the 373-byte region is `353e4164`. The bytes after the region are zero.
- The log has six entries: three `bible.reader.location` writes, one `selectionHintDismissed`, `textSize` `"large"`, then `textSize` `"medium"`.
- The final values match the Source table: location `{"book":"JHN","chapter":1,"scrollY":0,"updatedAt":1791228309419}`, `selectionHintDismissed` `true`, `textSize` `"medium"`. There are no other keys.

Sol did not repeat the vendored MMKV host-reader run. Its command line needs the search and Works databases. Two independent decoders agree.

### Libraries (sqlite3 CLI on copies)

The old DB header has WAL mode (bytes 18–19 = `02 02`). The native DB has DELETE mode (`01 01`). Sol opened both copies with `?immutable=1`. This makes no side file.

| Check | Old | Native |
| --- | --- | --- |
| `user_version` | 1 | 1 |
| `integrity_check` | ok | ok |
| Tables, indexes, autoindexes | 10 objects | same 10 objects |
| Schema text | multi-line | single-line; same columns, types, keys, and indexes |

Row JSON from `SELECT *` is byte-identical for each table (SHA-256 prefixes: bookmarks `dc7d4d0db17fba88`, highlights `716fcb2ea9d06d08`, notes `171cb7ff9dcdf98e`).

| Row | Values in both apps |
| --- | --- |
| Bookmark | `web-ce:JHN:1:1:1`, edition `web-ce`, John (order 49), chapter 1, verses 1–1, indexes 0–0, text "1 In the beginning was the Word…", created and updated `1791228301502` |
| Highlight | `web-ce:JHN:1:1`, batch `web-ce:JHN:1:1:1:1791228336690`, edition `web-ce`, verse 1, index 0, color `gold`, created and updated `1791228336690` |
| Note | `web-ce:JHN:1:1:1`, edition `web-ce`, verses 1–1, note text "L00 synthetic migration fixture note.", created and updated `1791228326670` |

Edition identity, verse range, color, note text, and timestamps are identical.

### Native envelope

The envelope has `formatVersion` 1, `revision` 28, `importVersion` 1, empty `importSourceHashes`, and empty `issues`. These values pass `NativeStateEnvelope.validate()` rules in source. The state has all 14 `NativePersistentState` fields except `themeScheme`. That field is optional, and absent means System. Reader location is John 1, `scrollY` 0, `updatedAt` `1791228309419`, no anchor. This equals the decoded old value. The other values equal the old app values or the old-app source defaults. Sol confirmed the defaults in `src/services/bible/readingPreferences.ts` (`medium`, `comfortable`, `serif`, `paragraphs`) and `DEFAULT_TRANSLATION_ID` (`web-ce`).

### 22-category claim

`compare()` produces exactly 22 rows: 3 tables, schema, Reader location, 4 typography values, edition, appearance, selection hint, widget guide, rotation, favorites, reflections, novenas, Calendar, Rosary, Works, unknown keys, and widget scalars.

Sol ran:

```text
python3 scripts/native/source-fixtures/l25/l25_fixture.py check \
  --old-data build/native-evidence/L25/capture-fixture-01/old/com.nrsv.verse \
  --native-data build/native-evidence/L25/capture-fixture-01/native/com.nrsv.verse.dev \
  --native-group-plist build/native-evidence/L25/capture-fixture-01/reference/native-group-prefs-expected.plist
```

Result: 22 `MATCH`, exit 0. The claim is accepted.

The old app and the native app store no other preference. The old app uses only `react-native-mmkv` (`src/utils/storage/index.ts`). The native app has no `@AppStorage`, `@SceneStorage`, or `UserDefaults.standard` use.

## Seed tool safety

Sol made fake old, native, and wrong-bundle containers in the scratch folder. They had stale `-wal`, `-shm`, `-journal`, and `previous` files, a stale envelope, and a read-only `Documents/SQLite` folder.

| Check | Result |
| --- | --- |
| Dry run is the default | Yes. It printed the plan and changed nothing. |
| `--apply` without `--confirm-apps-stopped` | Refused, exit 2. |
| `--apply` needs a new `--report-dir` | Yes. A second run with the same folder was refused, exit 2. |
| Bundle-ID container check | Yes. The `com.example.other` container was refused, exit 2. |
| Simulator path check | Yes. A root outside `CoreSimulator/Devices` was refused without `--allow-nonsimulator-root`. |
| `simctl` use | Only `get_app_container … data`, and only with `--udid`. No boot, install, launch, or terminate call. |
| WAL, SHM, journal | Removed before the copy, after a backup. |
| Native `previous` envelope | Removed after a backup. |
| Backups | Six files in `before/`. `seed-report.json` lists the hash and mode of each. |
| Copy | Temporary file, mode set, then `os.replace`. |
| Read-only folder | Made owner-writable (0555 to 0755). |
| Post-apply check | 7 rows `OK`. `verify` exit 0. A second dry run planned nothing. |
| `seed-report.json` | Records `manifestSha256` `aee48b2c…`. |
| Frozen-fixture mutation | None. `prepare` refuses an existing folder. `read_rows` and `build_native_db` work on temporary copies. `mmkv_decode` opens files read-only. |

## Stale old-container native files

The old container holds `Library/Application Support/John/native-state-v1.json` (`93928719964b…`) and `native-state-v1.previous.json` (`160521a934f1…`). These bytes equal the preserved production snapshot copies.

- **L25 risk: low.** The Expo app does not read these files. The tool leaves them in place and prints a note. Keep them for L25. Record their hashes.
- **L27 risk: blocking.** L27 installs the native Release app over the old app without an uninstall. The native store reads a valid primary envelope first and does not import MMKV. These files would replace the old-app import with Psalm 23 / `large` production state. The L27 procedure must start from a clean old-app container or remove these files under its own reviewed step. Do not install any native build under `com.nrsv.verse` while these files exist.

## Other findings

1. The frozen L00 SQLite folder has a 0-byte `user-library.db-wal` (5 October 15:27) and a 32 KB `-shm` (5 October 16:12). Something opened the frozen DB in place before this task. The main-file hash still matches. The empty WAL adds no rows. Do not open the frozen DB in place again.
2. Both capture tests already handle a restored chapter. The baseline path taps `Back to …` up to three times. The native path taps `reader-back` up to three times. A John 1 start therefore works in both apps.
3. The capture tests change preferences through Settings and move the Reader. Each method pair changes saved state.

## Required fixes

1. **`native/John/SimulatorSupport/ReaderParity-README.md`, line 11 ("Seed and profile").** After the sentence "The seed must have no saved Reader location.", add:

   > Exception for the L25 paired captures: the accepted seed `l25-capture-fixture-01` keeps one saved Reader location in both apps, WEB-CE John 1 at `scrollY` 0 with no anchor. Each journey reaches the book list through the visible Back controls (`Back to John chapters`, then `Back to books` in the baseline; `reader-back` in the native app). All other runs still need a seed with no saved Reader location.

2. **`docs/native/reviews/L25-capture-fixture-alignment.md`.**
   - Line 171 (step 9): change it to: "Seed both apps again before each method pair. A method pair is one baseline test method and the matching native test method. Repeat steps 1 to 5 with a new report folder."
   - Line 204 (Limits): change it to: "This fixture has one saved Reader location. This is an accepted L25 exception. See `ReaderParity-README.md`."
   - Lines 206–212: rename "Open questions" to "Decisions" and replace the five questions with the five coordinator decisions in this review.

Both fixes change documents only. The fixture, the manifest, and the scripts stay unchanged. Their hashes stay valid.

## Optional notes

1. `l25_fixture.py` lines 260–261 and 265–266: when MMKV has no key, the old app uses its source default (`web-ce`, `DEFAULT_ROTATION_INTERVAL`, default scope). It does not read the group plist. The tool uses the group plist as the fallback and labels the edition `group-plist`. The values are equal in this fixture. Use the source defaults and label them `default`. This matters for later `check` runs on changed containers.
2. `l25_fixture.py` lines 636–664: when `--udid` is set, require `/Devices/<udid>/` in each resolved data root. This also covers a root given by an explicit option.
3. Add `--expect-manifest-sha256` to `seed` and `verify`. Stop when the manifest hash differs. Precondition 1 below covers this manually.
4. Add the presence, SHA-256, and mode of `staleOldContainerPaths` to `seed-report.json`. Precondition 8 below covers this manually.
5. `compare()` checks reflections by key list and novenas by count only. Both are empty here. Compare full values when a later fixture has entries.
6. The tool has no restore command. The `before/` backups and `seed-report.json` are enough for a manual restore.

## Seeding preconditions for Main

1. Confirm these SHA-256 values before any step: `manifest.json` `aee48b2c6b09cfa509e8242776914468a2a0fb8d9ea18082d634af5970c2ba58`, `l25_fixture.py` `b88623dcdb2aa1a55d9b7e1777ac90de41d8ef116d55c6d84a62734f558f2fa5`, `mmkv_decode.py` `17c6f0ccd78ba26a1e108263edcfd500c0e374aadceee5dc1d52595ae14759e1`. Stop if one differs.
2. Confirm that required fixes 1 and 2 are in place.
3. Use only the dedicated simulator `37D1870B-F16D-488A-8F20-959201F970D9`. Do not boot another task simulator. Confirm that `com.nrsv.verse` is the verified original Expo build and that `com.nrsv.verse.dev` is the new coherent native build. Record both installed executable hashes.
4. Stop both apps with `xcrun simctl terminate 37D1870B-F16D-488A-8F20-959201F970D9 com.nrsv.verse` and `… com.nrsv.verse.dev`. Then run `xcrun simctl spawn 37D1870B-F16D-488A-8F20-959201F970D9 launchctl list`. No `UIKitApplication:com.nrsv.verse[` or `UIKitApplication:com.nrsv.verse.dev[` entry may remain. Pass `--confirm-apps-stopped` only after this check.
5. Run `seed --udid 37D1870B-F16D-488A-8F20-959201F970D9` as a dry run. Confirm that both data roots are under `/Devices/37D1870B-F16D-488A-8F20-959201F970D9/data/Containers/Data/Application/`. Read the plan.
6. Run `seed --udid … --apply --confirm-apps-stopped --report-dir build/native-evidence/L25/capture-seed-NN`. Use a new `NN` for each seed. The command must exit 0.
7. Run `verify --udid …` before any launch. All 7 rows must be `OK`. No stale removable file may remain. Exit 0.
8. Record in the run record: the manifest hash, the `seed-report.json` hash, both data roots, and the presence, SHA-256, and mode of the two stale old-container files. Do not remove them in L25.
9. Seed acceptance, first pair only: launch each app to its root without navigation. Stop both apps. Copy both data containers. Run `check` on the copies. All 22 rows must be `MATCH`. Only `updatedAt` may change; `scrollY` must stay 0. Then repeat steps 4–8 before the first capture.
10. Do not pass `-L14FeatureDate` or `-L14FeatureTimeZone`. The simulator time zone must be `America/Toronto`. Record host time zone, host time, and device time at the start and end of each app run. Both runs of a method pair must be on the same local date and on the same side of 17:00 Toronto time. If a pair crosses 17:00 or midnight, discard the pair, reseed, and repeat it.
11. Keep the same status-bar override (9:41, Wi-Fi 3 bars, cellular 4 bars, battery 100%) and the same effective appearance for both apps. Record both appearance values. The app appearance preference stays System.
12. Set `L25_SEED_ID=l25-capture-fixture-01`, `L25_SEED_MANIFEST_SHA256=aee48b2c6b09cfa509e8242776914468a2a0fb8d9ea18082d634af5970c2ba58`, and the `L25_SEED_STATE` text from the alignment document.
13. For each method pair, run the baseline method, then the native method. Reseed both apps (steps 4–8) before the next method pair.
14. Do not open a frozen L00 file or a fixture file in place. Do not change any L00 or fixture mode. Keep the `bible-search.db` row as `copy-if-different`.

## Addendum (6 October 2026)

`l25_fixture.py` changed to `36549ad8fc4fde6d7de6c8f30a387d526bf346d43611660c09f8e2f4db962d5c`. The change is limited to the old-app default fallbacks in `describe_old` (optional note 1). Use this hash in seeding precondition 1. The manifest `aee48b2c…` stays valid. See `L25-helper-and-run-plan-review.md`.
