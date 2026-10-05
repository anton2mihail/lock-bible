# Native resource staging

These scripts copy the source resources for the native app and widget. They do not build the Xcode project. They do not run a simulator.

## Requirements

1. Use the repository's locked JavaScript dependencies. The catalog exporter uses the installed `tsx` command from `node_modules/.bin/tsx`.
2. Use Python 3 with its standard library. The stage script uses `sqlite3` from the Python standard library to read database metadata.
3. Run each command from the repository root.

## Stage and compare

Use a new output directory for every stage command. The script accepts only a new child of `build/native-evidence/L03/staged/`. It fails if the output exists. It does not remove files.

```sh
node scripts/verify-widget-data.mjs
python3 scripts/native/resources/stage-resources.py build/native-evidence/L03/staged/run-9
python3 scripts/native/resources/stage-resources.py build/native-evidence/L03/staged/run-10
python3 scripts/native/resources/verify-staging.py build/native-evidence/L03/staged/run-9 build/native-evidence/L03/staged/run-10
```

The verifier requires two different output directories. It checks source hashes and every resource hash against the manifest. It also fails if a resource is missing or if an unexpected file exists. It checks every indexed record field (`ref`, book code, chapter, verse label, and text), the complete OT/NT maps, offset bounds, and metadata counts. It then compares all output file hashes across both trees.

## Target integration paths

Use [app-target-files.json](../../../build/native-evidence/L03/app-target-files.json) for app resource paths. Use [widget-target-files.json](../../../build/native-evidence/L03/widget-target-files.json) for widget resource paths. The app paths use `App/Bible/<edition>/`, `App/Rotation/`, `App/Catalogs/`, `App/Calendar/`, `App/Databases/`, `App/Artwork/`, and `App/Fonts/`. The widget files stay flat under `Widget/` and keep their source basenames.

The script stages exact source Bible book JSON, manifests, and metadata. It stages the 15 indexed rotation files in both target directories. The three source `widgetVerses.json` files remain build authority and provenance. They do not enter either target. The search database and Works database appear once each in the app. The script stages the small Works catalog but does not stage Works source paragraphs. It exports prayer, novena, teaching, and Rosary source values and derived guide/session values from the existing TypeScript modules. It copies the calendar files, artwork, icons, images, and seven loaded font files as original bytes.

## Acceptance limits

The staging proof confirms source paths, expected counts, schemas, byte counts, hashes, and repeatable output. It does not confirm Xcode target membership, app bundle lookup, font registration or rendering, widget memory use, or simulator behavior. Main Luna owns project integration and simulator checks. Do not add production Core code until Sol accepts S01.
