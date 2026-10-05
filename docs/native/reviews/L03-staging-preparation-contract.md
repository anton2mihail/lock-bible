# L03 resource staging preparation

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Status: stable resource boundary. Preparation is allowed. Production project integration requires S01 and L02.

## Ownership

Source Luna owns staging and export scripts under `scripts/native/resources/`. Use `build/native-evidence/L03/staged/` for preparation output. Do not write the Xcode project, JohnCore, app UI, simulator state, or Sol review records during this task.

Main Luna owns project resource lists and build integration. Source Luna supplies the generated manifest and target lists. One worker must own each file.

## Resource boundary

| Target | Inputs |
| --- | --- |
| App | Canonical Bible book JSON for all three editions; edition manifests and metadata; existing indexed rotation corpus files; search DB; works DB; small works catalogs; calendar and readings data; exact devotional catalog exports; required artwork, icon assets, and seven loaded font aliases |
| Widget | Existing three-edition `.dat`, `.offsets`, `.ot`, `.nt`, and `.meta.json` files; existing `daily-readings-2025.json` through `daily-readings-2032.json` |

Keep widget resource basenames unchanged. Existing Swift widget code loads these names from its bundle. Do not stage the private library, MMKV state, works DB, or full Bible JSON into the widget.

Stage the works DB once in the app. Do not stage its source paragraph JSON as well. Stage the search DB once. Keep large generated resources out of tracked duplicate files. Keep original artwork and font bytes unchanged. Do not download or re-author content.

Use app subdirectories `Bible/<edition>/`, `Rotation/`, `Catalogs/`, `Calendar/`, `Databases/`, `Artwork/`, and `Fonts/`. Preserve source basenames within each directory. Catalog exports may use explicit unique names. Record their names and source-module hashes. The app resource resolver must use these subdirectories.

The app and widget use the same indexed rotation format. Stage the three-edition `.dat`, `.offsets`, `.ot`, `.nt`, and `.meta.json` files into `App/Rotation/` as well as the widget. Do not ship `widgetVerses.json` in either target. Keep those source JSON pools as the build authority. Verify every indexed record and scoped row against them. Native runtime code must map the record data and decode selected records only. See `docs/native/adr/0005-resource-packaging.md`.

## Deterministic output

1. Use sorted source and output paths.
2. Export the catalog from the existing source modules. Preserve exact strings, IDs, order, repetitions, media gates, and fallback data.
   Include the exact Rosary session results for all four sets and Seven Sorrows. Keep group labels and builder source provenance.
3. Write a manifest with schema version, relative output path, source path, target, byte count, SHA-256, and required content counts.
4. Keep build dates and absolute machine paths out of deterministic files.
5. Record edition IDs, font PostScript names, SQLite schema metadata, calendar coverage, and catalog counts.
6. Fail on missing resources, basename collisions, unexpected DB metadata, or changed expected source counts.
7. Run staging twice into separate new output directories. Compare manifests and all content hashes.
8. Save the command, results, manifest, and input provenance under `build/native-evidence/L03/`.

The script must remove files only inside its explicit generated output directory. Validate that directory before any removal. Prefer a new directory for preparation runs.

## Acceptance limits

This task proves reproducible source packaging. It does not prove bundle lookup, rendered fonts, widget memory use, or simulator app behavior. L03 integration must inspect the built app and widget bundles. Main Luna will run those checks after S01 and L02.
