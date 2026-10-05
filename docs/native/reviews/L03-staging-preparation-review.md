# L03 staging preparation review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Verdict: ACCEPTED preparation. Built-bundle and runtime integration remain open.
Reviewed commit: `3e84efa9a7a4851a264b77fcdc17144cb53cd79e`.

Sol read all four tracked staging files and the final run-9/run-10 evidence. The source checker passed. The two fresh output trees contain 377 matching files each: 374 resources and three manifest/target-list files.

Manifest SHA-256: `dc108b37a9d3cca837b931026add9db619642a9a395c231cc98b8ea487fe6ebc`.

| Target | Resources | Bytes |
| --- | --- | --- |
| App | 351 | 132,783,642 |
| Widget | 23 | 18,164,087 |

Replacing shipped app JSON pools with indexed files reduces staged app content by 4,665,507 bytes. The full JSON pools total approximately 21.4 MiB, but the replacement corpus also uses space. Do not describe 21.4 MiB as the net saving.

## Accepted properties

The app stages exactly 15 files under `App/Rotation/`. It ships no full `widgetVerses.json`. The verifier checks every positional record field, complete OT/NT maps, offset ranges/endpoints, metadata counts, declared output hashes, and unexpected files. It rejects two identical verification directories.

Each edition has 73 Bible books. Rotation pool counts are 35,379 WEB-CE, 35,811 Douay–Rheims, and 35,809 Vulgate. The staged catalogs preserve 27 novenas, 12 prayers, five teachings, four mystery sets, six media entries, and 26 Works collections. Rosary guides and full sessions include group labels. The calendar includes 858 readings and 2,922 celebrations.

Search and Works databases appear once each in the app. Works source paragraphs are excluded. Widget files keep their original names and bytes. Fonts, artwork, credits, and source provenance are present. Output paths are resolved and restricted to a new generated directory. The script does not remove existing output.

## Integration conditions

1. Main Luna integrates target lists without flattening app subdirectories.
2. L03 verifies the built app/widget files, hashes, target membership, and font registration.
3. Verify current source bytes for each copied resource during final integration. The preparation verifier directly checks the source-provenance map; the copied-file manifest also records hashes but not every source file is in that map.
4. The native rotation reader maps and decodes selected records only. Prove bounded startup work in the simulator.
5. Native rotation outputs must match all 792 source fixtures before L12 acceptance.

This preparation does not prove renderer parity, importer safety, widget memory limits, or complete feature behavior.
