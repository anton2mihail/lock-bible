# L27 source update fixture

This folder exports source expectations for the full same-ID update check. It does not make MMKV files or a SQLite file. Main owns the real old-app fixture and the simulator update.

Run the exporter with Bun. Pass a new output path below `build/native-evidence/L27/`:

```sh
bun scripts/native/source-fixtures/l27/prepare-source-expectations.ts \
  build/native-evidence/L27/source-preparation/run-02
```

The script stops if the output path exists. It writes `source-expectations.json`, `legacy-values.tsv`, and `fixture-manifest.json`. The TSV keeps the L04 format: each line has a hex-encoded key and value. Main can use it to build a synthetic copy. Main must use real old-app actions for the production-ID update fixture.

`source-expectations.json` records the complete native state shape. It includes all persisted MMKV key families, 27 novena keys, two Sunday reflections, real prayer IDs, two real Works positions, the imported reminder ID, and the App Group widget scalar types. The old Reader location has no native anchor, so the expected imported anchor is null. A second Works position and one unknown legacy key test state preservation.

The SQLite rows come from the existing source repository functions. The exporter uses a fixed `Date.now` sequence and an in-memory database. It applies overlapping highlights in order and exports the final raw rows plus the saved-item grouping. It includes JHN 1 verses from WEB-CE, Douay–Rheims, and the Vulgate. It closes the in-memory database before it writes output.

The manifest records the exact source hashes, row counts, encoded output hashes, and generator version. The hashes include the source Bible preference getters, reader preference getters, companion favorite/reflection loaders, calendar and Rosary reminder loaders, Works position loader, the native legacy normalizer, and the persistent-state inventory.

The SQLite expectations are direct outputs from the executed source repository functions. The absent and malformed preference cases are a reviewed reconstruction of `LegacyStateNormalizer.swift`; the exporter does not call the old app's getters with a synthetic MMKV store. The output records this difference. The Works anchor is checked against paragraph 2 in source Homily 10. The paragraph has 976 UTF-16 code units, so offset 57 is in range.

Every output has `runtimeBehaviorObserved: false`. These values describe source behavior. They do not prove the installed app's stored bytes or update behavior.

## Main's actual update fixture

Main must create a separate, test-owned old-app container. Main must preserve and record these files before and after the update:

- `user-library.db`, `user-library.db-wal`, and `user-library.db-shm`;
- MMKV `data` and `crc` files;
- the native state envelope and the validated recovery backup.

Main must export exact DB rows, all MMKV key/value hashes, App Group scalar names and types, and pending notification request identifiers, triggers, and payloads. Main must record the app bundle ID, version, build, process ID, App Group entitlement, MMKV root, and recovery backup schema and row counts. Main must not overwrite any L04 or Gate A fixture. Main must keep its old-app export separate from this source-generated output.

The source exporter cannot provide real container paths, signed entitlements, actual pending requests, old-app binary bytes, or an installed app version. Main must collect that evidence during the release update run.

## Full old-app fixture (L27 rehearsal)

`l27_fixture.py` builds the real old-app data: MMKV files, `user-library.db` with a committed WAL, and the App Group widget plist. `build-full-fixture-data.ts` writes the data with the executed old source functions. `host-importer/` runs the real `JohnCore` importer on macOS against copies. See `docs/native/reviews/L27-full-fixture-preparation.md`.

```sh
python3 scripts/native/source-fixtures/l27/l27_fixture.py prepare          # build/native-evidence/L27/full-fixture-01
python3 scripts/native/source-fixtures/l27/l27_fixture.py host-run --out build/native-evidence/L27/full-fixture-01-host-check
python3 scripts/native/source-fixtures/l27/l27_fixture.py seed --udid <UDID>    # dry run; add --apply ... to copy
```

