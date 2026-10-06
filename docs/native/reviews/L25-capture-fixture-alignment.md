# L25 capture fixture alignment

Date: 6 October 2026.
Owner: Source.
Status: fixture prepared from copied evidence. No simulator ran. Main owns the seeding and the runs.

This fixture is for the L25 paired captures only. It is not the L27 update fixture.

## Result

The newest old-app and native evidence copies did not match. The old app had saved rows. The native app had none. The Reader location differed. Typography, edition, appearance, and widget values already matched.

The new fixture makes the saved state equal for both apps. The tool checks 22 categories. All 22 match in the new fixture. Four categories did not match in the old evidence: bookmarks, highlights, notes, and Reader location.

Text size is `medium` in both apps. Line spacing, typeface, and layout use the same defaults in both apps. The fixture changes no preference.

## Inputs

All inputs are copies under `build/native-evidence/`. The tool opened no live container. It did not change any evidence file. Every input copy has a SHA-256 and a mode in `expected/input-copies.tsv` (66 rows).

| Role | Input copy | SHA-256 (first 12) | Mode |
| --- | --- | --- | --- |
| Old DB (frozen L00) | `L00/synthetic-legacy-fixture/Documents/SQLite/user-library.db` | `827c7badbcf2` | 0644 |
| Old search DB | `L00/.../bible-search.db` | `e2ee48c4edae` | 0600 |
| Old MMKV data | `L00/.../mmkv/mmkv.default` | `750151a47be0` | 0700 |
| Old MMKV CRC | `L00/.../mmkv/mmkv.default.crc` | `6f3e7ca99b9c` | 0700 |
| Old widget prefs | `L00/.../group.com.nrsv.verse.plist` | `f61f300fd1b0` | 0600 |
| Old MMKV, newest copy | `L25/baseline-john1-parity-01/data-after/Documents/mmkv/mmkv.default` | `73892799e3b8` | 0700 |
| Native DB, newest copy | `L22/positive-notice-native-dev-02/data-after/AppData/Documents/SQLite/user-library.db` | `12570cd7535e` | 0644 |
| Native envelope, newest copy (revision 27) | `L22/.../native-state-v1.json` | `baba821db53b` | 0600 |
| Native widget prefs | `L22/.../group.com.nrsv.verse.dev.plist` | `f61f300fd1b0` | 0600 |
| Preserved production snapshot | `L25/preserve-prod-native-before-baseline-01/` | `files.sha256` = `caf3e19a73c9` | 0444 |

The preserved snapshot is unchanged. Its `files.sha256` and `run.txt` hashes match the handoff.

The L00 fixture files have modes 0600, 0644, and 0700 now. The handoff "0400" note was about a task copy. The file hashes match the recorded values. Source did not change any mode.

## How the values were decoded

The old MMKV file is a log. Later entries replace earlier entries. Source decoded it two ways.

1. `scripts/native/source-fixtures/l25/mmkv_decode.py` reads the log. It checks the CRC32 and the actual size from the `.crc` file. Both pass.
2. The vendored MMKV Core v2.0.0 host reader (`build/native-evidence/L01/storage-proof/storage-proof-host legacy-read`) opened a copy. It reports 3 keys and unchanged file hashes.

The frozen MMKV has three keys:

| Key | Value |
| --- | --- |
| `bible.reader.location` | `{"book":"JHN","chapter":1,"scrollY":0,"updatedAt":1791228309419}` |
| `bible.reader.selectionHintDismissed` | `true` |
| `bible.reader.textSize` | `"medium"` (the log also has an earlier `"large"`) |

The old app has no other saved preference. It uses source defaults for the rest.

The native envelope for the fixture passed the real `JohnCore` decoder and `validate()` in a scratch host package. The re-encoded bytes are identical to the file.

## Alignment table

"Old evidence" means the newest old-app copy (`baseline-john1-parity-01/data-after`) against the newest native copy (`positive-notice-native-dev-02/data-after`).

| Category | Old value | Native value (old evidence) | Match before | Fixture value (both apps) | Match after |
| --- | --- | --- | --- | --- | --- |
| Bookmarks | 1 row, `web-ce:JHN:1:1:1` | 0 rows | No | 1 row, same 13 columns | Yes |
| Highlights | 1 row, gold, `web-ce:JHN:1:1` | 0 rows | No | 1 row, gold, same 13 columns | Yes |
| Notes | 1 row, "L00 synthetic migration fixture note." | 0 rows | No | 1 row, same 14 columns | Yes |
| Library schema | `user_version` 1, integrity `ok` | same | Yes | same | Yes |
| Reader location | John 1, scrollY 4194.33 (moved by the last run) | John 1, scrollY 3743, anchor verse 45 offset 77 | No | John 1, scrollY 0, no anchor | Yes |
| Text size | `medium` (MMKV) | `medium` | Yes | `medium` | Yes |
| Line spacing | `comfortable` (default) | `comfortable` | Yes | `comfortable` | Yes |
| Typeface | `serif` (default) | `serif` | Yes | `serif` | Yes |
| Reader layout | `paragraphs` (default) | `paragraphs` | Yes | `paragraphs` | Yes |
| Edition | `web-ce` (old-app default) | `web-ce` | Yes | `web-ce` | Yes |
| Appearance preference | absent (System) | absent (System) | Yes | absent (System) | Yes |
| Selection hint dismissed | true | true | Yes | true | Yes |
| Widget guide dismissed | false | false | Yes | false | Yes |
| Rotation interval and scope | 1440, full | 1440, full | Yes | 1440, full | Yes |
| Favorites, reflections, novenas | none | none | Yes | none | Yes |
| Calendar notice setting | absent (off, 08:00) | off, 08:00 | Yes | off, 08:00 | Yes |
| Rosary reminder setting | absent (off, daily 20:00) | off, daily 20:00 | Yes | off, daily 20:00 | Yes |
| Works positions | none | none | Yes | none | Yes |
| Unknown legacy keys | none | not applicable | Yes | none | Yes |
| Widget scalar values | WEB-CE, 1440, full, schema 2 | identical (same file hash) | Yes | identical | Yes |

Facts from run records, not from files:

| Category | Recorded value | Source |
| --- | --- | --- |
| Device and layout | iPhone 17 Pro, 402 × 874 points, iOS 26.5 (23F77) | `baseline-l00-preflight-01/run.txt` |
| Effective appearance | Light | same |
| Status bar | 9:41, Wi-Fi 3 bars, cellular 4 bars, battery 100% | same |
| Time zone | America/Toronto | same; the host zone is the same |
| Date | Actual device clock in both apps | See Decisions, item 3 |

## Findings

1. The old evidence had more mismatches than the handoff lists. The native copy had zero bookmarks and zero notes, not only zero highlights.
2. The Reader location is not stable. Each capture run moves it. The old app moved to scrollY 4194.33. The native app moved to scrollY 3743. Seed both apps again before each paired run.
3. The old container holds `native-state-v1.json` and `native-state-v1.previous.json`. They are copies of the preserved production native state (hash `93928719964b`). They show Psalm 23 and `large`. The old app ignores them. They are not preference evidence. Do not copy them into this fixture.
4. Those two files are a risk for L27. The same-ID update test would treat them as native state. Remove them, or use a clean container, in the L27 procedure. This fixture does not remove them.
5. The old DB main file holds the 3 rows. A read of the main file alone and a read with the WAL give the same row counts. The seeding step removes the container WAL and SHM files.
6. The native DB uses DELETE journal mode. The old DB header says WAL mode. Both are schema 1 with the same table shapes. Source did not change that difference.

## Unresolved mismatches

None in saved state.

One item cannot be resolved from files. The old app cannot take a fixed date. The native app can (`-L14FeatureDate`). Both apps must use the actual device clock. See Decisions, item 3.

## Fixture

Path: `build/native-evidence/L25/capture-fixture-01/`.

Manifest: `manifest.json` (SHA-256 `aee48b2c6b09cfa509e8242776914468a2a0fb8d9ea18082d634af5970c2ba58`) and `manifest.tsv`. Each row has path, SHA-256, mode, size, action, container path, and purpose. Use the `manifest.json` hash as `L25_SEED_MANIFEST_SHA256`.

Provenance. The manifest `toolSha256` (`b88623dc…`) names the tool that prepared the fixture. Seed, verify, and check use `l25_fixture.py` `36549ad8fc4fde6d7de6c8f30a387d526bf346d43611660c09f8e2f4db962d5c`. It differs only in the old-app default fallbacks in `describe_old`. Record both hashes in each run record.

| Fixture file | Action | Mode | Purpose |
| --- | --- | --- | --- |
| `old/com.nrsv.verse/Documents/SQLite/bible-search.db` | copy if different | 0600 | Old search DB. Same bytes as the installed copy. |
| `old/.../Documents/SQLite/user-library.db` | copy | 0644 | Old library: 1 bookmark, 1 gold highlight, 1 note. |
| `old/.../Documents/mmkv/mmkv.default` | copy | 0700 | Old MMKV: John 1 top, `medium`, hint dismissed. |
| `old/.../Documents/mmkv/mmkv.default.crc` | copy | 0700 | MMKV meta and CRC. Copy with the data file. |
| `old/.../Library/Preferences/group.com.nrsv.verse.plist` | copy | 0600 | Old widget scalar values. |
| `native/com.nrsv.verse.dev/Documents/SQLite/user-library.db` | copy | 0644 | Native library with the same 3 rows. |
| `native/.../Library/Application Support/John/native-state-v1.json` | copy | 0600 | Native envelope, revision 28. |
| `reference/native-group-prefs-expected.plist` | compare only | 0644 | Expected native widget values. Do not copy. |
| `expected/*` | evidence only | 0644 | Decoded MMKV, DB rows, envelope, alignment, input list. |

All modes allow owner write. The fixture folders are 0755.

How Source built the native files:

- The native DB is the closed native DB (zero rows) plus the 3 old rows. Source inserted them with SQL. All columns are equal.
- The native envelope keeps the revision 27 values. It uses revision 28. It resets the Reader location to the decoded old value. It has no anchor.
- The fixture has no `previous` file for the native envelope. The seeding step removes the stale one.

## Seeding procedure

Script: `scripts/native/source-fixtures/l25/l25_fixture.py`. It uses only the Python standard library. It defaults to a dry run. It calls `xcrun simctl get_app_container` only when you pass `--udid`. It never boots, installs, launches, or stops anything.

Preconditions:

- The dedicated simulator is booted by Main.
- The original app (`com.nrsv.verse`) and the native dev app (`com.nrsv.verse.dev`) are installed.
- Both apps are stopped. Do not reseed an open database.

Steps:

1. Stop both apps.
2. Run the dry run. Read the plan.

   ```sh
   python3 scripts/native/source-fixtures/l25/l25_fixture.py seed --udid 37D1870B-F16D-488A-8F20-959201F970D9
   ```

3. Apply the fixture. The script saves every replaced file to the report folder first. Use a new report folder each time.

   ```sh
   python3 scripts/native/source-fixtures/l25/l25_fixture.py seed --udid 37D1870B-F16D-488A-8F20-959201F970D9 \
     --apply --confirm-apps-stopped --report-dir build/native-evidence/L25/capture-seed-01
   ```

4. Run the byte check before the first launch. It must exit 0.

   ```sh
   python3 scripts/native/source-fixtures/l25/l25_fixture.py verify --udid 37D1870B-F16D-488A-8F20-959201F970D9
   ```

5. Record the `manifest.json` hash and `seed-report.json` in the run record.
6. Set the capture inputs. Use `L25_SEED_ID=l25-capture-fixture-01` and the manifest hash from step 5. Suggested `L25_SEED_STATE`: "WEB-CE; Reader John 1 saved at top; bookmark, gold highlight, and note on John 1:1; Medium, Comfortable, Serif, Paragraphs; appearance System".
7. Do not pass `-L14FeatureDate` or `-L14FeatureTimeZone` to the native app.
8. Run the old-app capture, then the native capture.
9. Seed both apps again before each method pair. A method pair is one baseline test method and the matching native test method. Repeat steps 1 to 5 with a new report folder.

What the script does in step 3:

- It checks that each data root belongs to the right bundle ID. It reads the container metadata plist for this.
- It removes the stale `user-library.db-wal`, `-shm`, and `-journal` files from both containers.
- It removes the stale native `native-state-v1.previous.json`.
- It copies each fixture file by temporary file and rename. It sets the manifest mode.
- It makes read-only folders on the path writable.
- It leaves the stale native files in the old container. It prints a note.

Without `--udid`, pass `--old-data-root` and `--native-data-root`. Add `--only old` or `--only native` to seed one app.

## Verify after the copy

1. Run `verify` (step 4) before the first launch. Every row must show `OK`. No stale file may remain. After a launch, the MMKV bytes and the envelope change, so `verify` then reports a difference. That is normal.
2. After the first launch and a stop, copy both containers.
3. Run the logical check on the copies. Pass the native group plist only if you copied it.

   ```sh
   python3 scripts/native/source-fixtures/l25/l25_fixture.py check \
     --old-data <copy of old data container> --native-data <copy of native data container>
   ```

4. Expect `MATCH` for every row. The first launch can change the Reader location time stamp. That is allowed. A changed `scrollY` is not allowed at the start of a run.
5. Look at both apps. The old Reader opens John 1 with a gold fill on verse 1. The native Saved tab shows 1 bookmark, 1 highlight, and 1 note. Do this only as part of the capture run.

## Limits

- Source did not run the apps. The check proves bytes and logical values. It does not prove how each app displays them.
- The real MMKV reader and the real `JohnCore` decoder accepted the old and native files on the host. The app launch is not tested.
- The native widget scalar values are not seeded. They are equal now. The native app writes them from its state. Compare them after launch only if the group container is reachable.
- This fixture does not cover Dark mode, Extra large text, small iPhone, or iPad. It does not set a fixed date.
- This fixture has one saved Reader location. This is an accepted L25 exception. See `ReaderParity-README.md` and Decisions, item 1.

## Decisions

The coordinator answered the open questions on 6 October 2026.

1. Reader start state: keep the saved John 1 location in both apps. Do not re-encode the MMKV file. This is an explicit exception to `ReaderParity-README.md`. That README asks for no saved Reader location and a book-list start. Both helpers return to the book list through the visible Back controls (`Back to John chapters`, then `Back to books`). `ReaderParity-README.md` now states this exception.
2. Seed MMKV: use the frozen L00 MMKV (location time stamp 1791228309419). Confirmed.
3. Date and time: use the real device clock in both apps. Capture both apps on the same local date and on the same side of 17:00 Toronto time. Main records the host time zone and time for each run.
4. Search DB: keep the 33 MB copy. The script skips it when the container copy is identical.
5. Modes: the handoff "0400" note was about a task copy, not the frozen L00 fixture. The current L00 modes are 0600, 0644, and 0700. Source records them and changes nothing.

Sol reviews the fixture now. Do not change fixture bytes unless Sol asks.
