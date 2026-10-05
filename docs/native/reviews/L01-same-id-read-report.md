# L01 same-ID read report

Date: 5 October 2026.
Owner: GPT-6 Luna.
Status: Runtime evidence ready for Sol review.

## Result

The reviewed read-only harness launched under `com.nrsv.verse` after an install over the seeded Release app. The install did not include an uninstall step. The harness read one MMKV string key, queried all three edition search indexes, and decoded the requested Works section. It returned exit status 0.

The app data-container UUID changed during install. The prior container path no longer exists. The new container has the same `user-library.db`, committed WAL, search database, MMKV data, and MMKV CRC bytes as the pre-install container. The bookmark, highlight, and note values also match the copied legacy fixture field-for-field. SQLite changed the volatile `user-library.db-shm` file. This does not change the database or WAL hashes.

The old app showed the reader size as Medium in the accepted L00 baseline. The harness found the expected `bible.reader.textSize` key and preserved its MMKV bytes. It did not decode or print the value. L04 must verify typed preference normalization.

## Simulator and app

- Device: iPhone 17 Pro, model `iPhone18,1`.
- Runtime: iOS 26.5, build `23F77`.
- UDID: `37D1870B-F16D-488A-8F20-959201F970D9`.
- Toolchain: Xcode 26.6, build `17F113`.
- Architecture: arm64.
- Prior app: `com.nrsv.verse`, executable `John11`, version `1.2.2 (15)`.
- Harness Info: `build/native-evidence/L01/same-id-read-01/installed-harness-info.txt`.
- Harness executable SHA-256: `e547c6b0ef9526030bdc4b4f89855206f055cecdfaba7d59368c5e44b0cefe63`.
- Harness app bundle: `build/native-evidence/L01/same-id-read-01/StorageProofHarnessSameID.app/`.

The harness copy changed only `CFBundleIdentifier` to `com.nrsv.verse`. Its executable hash matches the reviewed storage harness. The installed app is the harness until the next install. Do not use it as a production UI.

## Container and protected files

The seeded app used UUID `7FA0CAAF-5F22-4446-854C-C902C7EBBE21`. The same-ID harness install used UUID `36CDBC98-CD3F-4994-8CC3-67320EEBC043`. The new path was reported by `simctl get_app_container`. The prior directory is absent after install.

The following persistent file hashes matched before and after the install and read:

| File | Size | SHA-256 |
| --- | ---: | --- |
| `user-library.db` | 4,096 bytes | `f5cefc6b6bc0e57b30fddc25bdaf2fd848dea2b0dd25be8425cdb3a1bccd1efd` |
| `user-library.db-wal` | 123,632 bytes | `eff73256ef1892b400a8461aeb5bfd98d36ca7046afef55bc3544fe8b536a3eb` |
| `bible-search.db` | 34,607,104 bytes | `e2ee48c4edaeeaa5c6b340af35e32b228563c3191ca55453340dfd9b8fe1fd94` |
| `mmkv.default` | 16,384 bytes | `b22c40a4760ab7f93bd6d0b6944b8f618d515f52fe564917ae49be9d9df06848` |
| `mmkv.default.crc` | 16,384 bytes | `720977a3165477d16738a4fc1312d3c341e7eede2bf74d09e091cfa2cd6b1b9b` |

The `user-library.db-shm` hash changed from `2e2c4044c826fd22c3cfc40f7ab21072c9afac09bd54000f41f08144b7769459` to `05f84111cd351a843ffb86078ec379dd79ac5f19a32ae257cab1178eac6e12ef`. SQLite uses this file for WAL coordination. The live DB and WAL bytes stayed unchanged.

## Consistent backup and row comparison

Before install, SQLite's online backup API wrote `backup/user-library-consistent.db`. Its SHA-256 is `06d7f687b4d75efae64c29e4beb491253d7114641037ea90f0c16aa2d2ad15bb`. `PRAGMA integrity_check` returned `ok`. The backup has one row in each table.

Read-only queries compared all columns in the pre-install live database, the consistent backup, the post-install live database, and the copied legacy fixture. The bookmark, highlight, and note values matched. The rows contain:

- Bookmark: `web-ce:JHN:1:1:1`.
- Highlight: `web-ce:JHN:1:1`, color `gold`, batch `web-ce:JHN:1:1:1:1791228336690`.
- Note: `web-ce:JHN:1:1:1`, text `L00 synthetic migration fixture note.`.

Row snapshots are in `library-rows-before.json` and `library-rows-after.json`. `row-comparison.txt` records the comparison. Input hashes before install are in `live-before.txt`. Input hashes after the run are in `live-after.txt`. The backup is under `backup/`.

## Exact run

The proof used the reviewed executable. The output directory was new and separate from the inputs. Paths were resolved to physical paths. No symlink was used.

```sh
xcrun simctl install 37D1870B-F16D-488A-8F20-959201F970D9 build/native-evidence/L01/same-id-read-01/StorageProofHarnessSameID.app
xcrun simctl launch --console --arch=arm64 37D1870B-F16D-488A-8F20-959201F970D9 com.nrsv.verse legacy-read \
  /Users/antonlachmaniucu/Library/Developer/CoreSimulator/Devices/37D1870B-F16D-488A-8F20-959201F970D9/data/Containers/Data/Application/36CDBC98-CD3F-4994-8CC3-67320EEBC043/Documents/SQLite/bible-search.db \
  /Users/antonlachmaniucu/Documents/lock-bible/NRSV/build/native-evidence/L00/DerivedData/Build/Products/Release-iphonesimulator/John11.app/assets/assets/works/works.db \
  /Users/antonlachmaniucu/Documents/lock-bible/NRSV/build/native-evidence/L01/same-id-read-01/output \
  /Users/antonlachmaniucu/Library/Developer/CoreSimulator/Devices/37D1870B-F16D-488A-8F20-959201F970D9/data/Containers/Data/Application/36CDBC98-CD3F-4994-8CC3-67320EEBC043/Documents/mmkv \
  bible.reader.textSize chrysostom.homilies-on-the-gospel-of-john 0
```

The run output is `run.log`. It reports `keys=1`, FTS5 results for WEB-CE, Douay–Rheims, and Vulgate, one decoded Works row, and rejection of oversized or damaged data. `simctl launch` returned exit status 0. The harness output says “No simulator was opened.” That sentence is inaccurate for this simulator launch; use the command and exit status as runtime evidence.

## Limits

This run proves same-ID installation, retained legacy bytes at the new container path, read-only MMKV key presence, search access, Works decode, and library-row retention. It does not prove stable container UUID, typed MMKV value decoding, native writes, signed App Group behavior, complete migration, or release update behavior on a physical device.
