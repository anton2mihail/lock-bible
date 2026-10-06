# L27 full update fixture source contract

Date: 6 October 2026.
Reviewer: GPT-6.1 Sol.
Status: source expectation preparation authorized. Full update runtime remains open.

## Ownership

Source owns only `scripts/native/source-fixtures/l27/` and a new ignored output directory under `build/native-evidence/L27/`. Main owns the actual old-app fixture, export, simulator, project, native update, and interruption/restart actions. Source must not read or change a live container. Source must not create or copy MMKV binaries or the old-app database in this scope. Existing L00/L04 fixtures remain unchanged.

## Output contract

Generate `source-expectations.json` and usage instructions. Label each expectation as `sourceGenerated`. Record baseline commit and source module/catalog hashes. Use a fixed injected clock for reproducible source operations. Record exact legacy keys and encoded values. Keep the raw theme string separate from values encoded once as JSON. Keep widget scalar values and types separate from MMKV.

Use real catalog IDs and edition text. Cover translation, cadence, scope, every Reader preference, legacy Reader book/chapter/offset/time, guide and selection flags, ordered prayer favorites, multiple Sunday reflections, both notice settings, imported Rosary notification ID, and all 27 novena keys. Use a real Works ID and valid section/page/paragraph/UTF-16 position. Include an extra preserved Works field and an unknown legacy raw key. Legacy Reader location has no native Reader anchor.

Build library expectations through the existing source repository operations. Use WEB-CE, Douay–Rheims, and Vulgate John passages. Preserve exact edition, passage and verse IDs, labels, indexes, book order, text, creation/update times, and highlight batch IDs. Record the ordered overlap operations and final rows. A verse has one final highlight row; do not invent duplicate final verse rows. Include bookmarks and notes in each edition. Export schema 1, complete rows, and expected counts.

Record separate absent/malformed variants and the source loader defaults. Do not mix those variants into the valid full fixture. Temporary Confession notes and transient guide/timer/media state are not persistent fixture categories.

The output is a source comparison contract. It is not an app export or simulator result. Require a new output path. Do not overwrite a previous fixture. Compare fresh logical outputs and record source/output hashes before the scoped commit.

## Actual update authority

Main's actual pre-install export is the final authority for exact saved values and timestamps. Compare the native post-import state and library against that export. The fixed-clock source expectations do not replace it.

The actual export must record current bundle/version/build, source/binary hash, process, effective root, and App Group provenance. Record every present DB/WAL/SHM and MMKV/CRC file with size and hash. Make a consistent recovery backup. Export complete rows and raw known/unknown preference payloads. Record actual widget scalar types, notification request snapshots, and installed widget configuration when the simulator can expose it.

Main must start from the old Release app, install the same-ID native Release app without uninstalling, and record the import marker last. Verify exact values, recent WAL rows, recovery backup, native-wins restart, repeat update, and required interruption boundaries. Keep signed group access, installed-widget continuity, supported older baseline, and limited physical evidence explicit. Do not infer them from source JSON.

## Source acceptance

Commit `f0b943c840e4d74e3074e4191adfeb3738aeb99f` satisfies this preparation scope. Fresh runs 02 and 03 have identical JSON and manifests. The output records 45 MMKV keys, all 27 novena keys, three editions, three favorites, two reflections, two Works positions, and schema-1 library rows: three bookmarks, eight highlights, and three notes. Four source highlight operations include overlap. The 18 absent or malformed cases are marked as reviewed native-normalizer reconstructions. Executed old-source functions are listed separately.

The exporter checks the selected Homily 10 paragraph's UTF-16 length of 976 against offset 57. Loader, catalog, normalizer, inventory, and generator hashes establish the source boundary. Generator SHA-256 is `c62d787673d8723cc757b58f778a0b9eb477994d64e96be0595a208fdb011caf`. JSON SHA-256 is `276936992793f4c529e6d7d961f563230cb4706f28e2c04a3288763dd82db788`. This accepts source expectations only. Main's actual pre-install export remains the update authority.
