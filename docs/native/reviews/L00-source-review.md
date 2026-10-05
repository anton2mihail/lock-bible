# L00 source inventory review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Worker: GPT-6 Luna source/resource worker.
Verdict: ACCEPTED for source inventory and reference fixtures only.
Reviewed baseline source: `b64e1fc3cfc6a78f508b41d74b71dddfe9ff7697`.
Accepted artifact commit: `7aaede8ca9e05a44f64fff0a04d7c7c23c0c59c1`.
Accepted fixture-generation correction: `07287f98510f2cb4f4aafd058fae3f05f7d72a2a`.

## Reviewed scope

- `docs/native/inventory/`: all 29 route mappings, source state notes, storage keys, normalization, SQLite schemas, resource counts, and known runtime limits.
- `scripts/native/source-fixtures/catalog-fixtures.ts`: direct export of existing catalogs. It includes exact Rosary media entries, guides, and complete sessions with group labels.
- `scripts/native/source-fixtures/rotation-fixtures.ts`: calls the existing rotation functions with the original pool order. It records source/pool hashes and 792 expected outcomes.
- `scripts/native/source-fixtures/README.md`: records the source fixture commands and their limits.
- `build/native-evidence/L00-source/`: source metadata, resource manifest, catalog exports, route inventory, and rotation outputs.

The worker fixed missing route states, clarified single JSON decoding, added the third widget identity, recorded widget scalar types, and added font metadata. The worker added source hashes for the eight novena modules. The worker added negative-slot, fractional time-zone, and travel cases. The Rosary media fallback now matches source.

## Accepted findings

All three edition IDs and their corpus counts match the approved source audit. The works counts and zlib/schema metadata match it. Readings and celebration coverage remain separate. The catalog fixture preserves source strings and ordering. Fonts have file hashes and PostScript names. Native staging must use the seven source-loaded aliases.

The route/state document uses source-derived labels. It marks runtime behavior unobserved. It does not replace the simulator parity matrix. The source discrepancies in `S00-source-discrepancies.md` remain part of the native contract.

## Limits and next checks

No simulator, binary, container, signing, archive, accessibility speech, or update-retention acceptance is included in this verdict. No unit tests were requested or run for this source inventory.

The runtime worker must verify actual resource loading and source behavior. It must capture clean Reader/Today states and inspect actual SQLite/MMKV paths. Release-mode old-app seeding and same-ID updates remain required. The native app and widget must consume the rotation fixtures through production Swift code in L12.

The source/resource worker can now prepare the narrow L01 storage proof. The contract is `L01-storage-proof-contract.md`. Full S00 and S01 acceptance remain open.

## Follow-up reproduction fix

The initial scripts assumed that `build/native-evidence/L00-source/` existed. Luna added recursive directory creation in both scripts. Sol reviewed the complete correction diff. Luna ran both README commands. Reported output: 27 novenas, 12 prayers, five teachings, four mystery sets, and 792 rotation outcomes. This correction is accepted at `07287f98510f2cb4f4aafd058fae3f05f7d72a2a`. It changes output preparation only.
