# ADR 0005: exact resources and indexed rotation

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Status: ACCEPTED resource boundary. Full S01 approval and production integration remain pending.

## Decision

Stage canonical resources with deterministic scripts. Keep generated output under build directories. Do not commit duplicate large databases or paragraph corpora. Keep the app and widget resource lists separate.

The app and widget use the existing indexed rotation format from `scripts/widget-data-format.mjs`. Each edition has `.dat`, `.offsets`, `.ot`, `.nt`, and `.meta.json` files. App resources use `Rotation/`. Widget basenames remain unchanged.

Keep `widgetVerses.json` as the source authority for each edition. Do not ship these full JSON arrays. Preserve their exact row order and scope order. Verify each indexed row against all five source fields: reference, book code, chapter, verse label, and text. Verify OT and NT maps against source group membership. OT includes deuterocanonical books.

Native `RotationCorpus` maps `.dat` on demand. It reads bounded little-endian UInt32 offsets and scoped row maps. It decodes only selected records. It validates metadata, offset bounds, and record shape. The shared rotation math consumes the exact pool count. It does not decode a full Bible or rotation pool at startup.

Ship the rotation corpus once, in `JohnSharedResources.framework` (6 October 2026, user decision on L26–L28 finding F3). The app embeds the framework in `John.app/Frameworks`. The widget extension links it without a second copy. At run time it loads the framework from the containing app's `Frameworks` folder through `@rpath` `@executable_path/../../Frameworks`. Both targets find `Rotation/` through `SharedResources.rotationDirectory`, which uses `Bundle(for:)` on the framework. Do not depend on a widget opening its host app's bundle path. Do not copy public content into the App Group as a startup requirement. The group retains its existing preference scalar contract.

The staged tree still holds the corpus twice (`App/Rotation/` and `Widget/`). That tree is frozen evidence. The generator copies each staged App subfolder except `Rotation`, and only the widget `daily-readings-*.json` files. Built target lists therefore hold no rotation file outside the framework. The `Widget/` basenames from the staging contract remain valid for the staged tree only.

## Evidence and reason

Sol read `targets/widget/VerseWidget.swift`, the indexed builder, and the existing verifier. The widget already uses mapped data with random record access. Its positional records preserve the fields needed for Read navigation and sharing. The scoped indexes preserve source pool order.

The three full JSON pools total approximately 21.4 MiB. The existing indexed files use less space and avoid allocating an entire array. Sharing the format also keeps app and widget selection on the same data contract.

This choice permits exact source packaging without an extra app-only rotation format. It does not change the rotation algorithm, source text, or pool order.

## Acceptance conditions

1. The staging verifier checks all record fields, scoped indexes, metadata counts, and source hashes.
2. Two separate staging trees match in every byte.
3. Built target lists contain no full rotation JSON or Works paragraph JSON. The app and the widget contain no rotation `.dat`, `.offsets`, `.ot`, `.nt`, or `.meta.json` file. The framework holds the only copy.
4. Simulator app and widget scenarios use the same JohnCore math and corpus reader.
5. The 792 source rotation fixtures match native outputs before L12 acceptance.
6. Runtime diagnostics prove that app startup does not decode the full corpus.

Resource packaging does not approve renderer, importer, chrome, or all-route parity. Those retain their own gates.
