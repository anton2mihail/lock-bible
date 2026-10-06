# Action audit: 2026-10-06

This review checks connected actions in the current native source. Runtime and visual acceptance remain separate.

## Current source verdict

The four initial findings are corrected at source. Their runtime and visual checks remain open.

1. Reader now shows up to three chapter commentary entries in catalog order before Previous/Next. It opens the full commentary route when more entries exist.
2. Verse Moment clears its old passage and metadata before it changes the displayed verse. It checks the request ID, verse, and edition after both asynchronous lookups. Rotation and boundary math use one captured `featureNow()` value.
3. Prayer Home and Rosary routes receive the shared feature clock and time zone. Lectio retains its live timer clock.
4. CitationContext invalidates its load generation on route exit. The completed verse lookup checks that generation before it opens Lectio. This scope is committed at `cbc459e`.

The reviewed hashes are ReaderView `364413f20f87bf604043d901c4122c4b26fb9d90147c02b433bd6556a4f5cafd`, DestinationView `c4a0620b1e3bad2a092d75effb4067031e5617941214bbcda2dee60f0804a696`, SecondaryRootView `6d9b008e2e7dfc7345693732c1d217f4f29b786d2963934b7ee26f3cac93dca1`, and CitationContextView `83dfeeb61c6b5e30721044cc340d8dae7937cfb9186ce3be7ea7485dfd9d8312`.

Reader selection actions are integrated under `L08-L10-selection-action-contract.md`. Source owns the pure toolbar. Main owns Reader integration, storage commands, note routing, and simulator checks. A successful highlight write updates the captured visible chapter even if the user changes the selected range. Feedback still requires the original selection. Actual action runtime acceptance remains open.

## Content run classification

Evidence: `build/native-evidence/L22/source-content-flow-20261006/`.

The exported manifest has SHA-256 `2331c412ed82d56cb2e239aef80a63e7be6ef1fa41f0a56037e71f06bee43067`. The result has three failed content tests and one passed disabled-notification test. The disabled result proves visible feedback only. It does not prove system permission, delivery, or request removal.

L15 failed an exact `60s of quiet` lookup. The exported hierarchy `7FA90257-5CC4-404B-9E9F-AF80CF2A5BAE.txt` records app PID 23516. It shows Lectio step 4, `55s of quiet`, and `End the timer`. The timer started and progressed. The exact 60-second lookup is a test timing error. Source must check a positive countdown and an observed decrease before it stops the timer. Natural expiry remains untested.

L14 failed before it typed the second Sunday reflection. L18 failed before Continue after it typed temporary notes. Static frames `frames/L14-02-05-31.png` and `frames/L18-02-08-24.png` show the keyboard open. The targets are below the visible content. The test helper uses `app.swipeUp`, which can start inside the keyboard. Source must use gestures inside the visible ScrollView area, above the keyboard and tab bar. It must record target movement. These failures do not establish a product keyboard defect.

Main added provenance to `content-disabled-run-01/run.txt`. Product and installed executable hashes match at `7feceee97d31c0c07c9735dccf0b2e765f63370063b417fcfaaef139aa3b7660`. The debug library hashes match at `390136ee0acb054908b0e221c5c02fa4ac6dc9504087384e6e1bf7a68f1c1fe8`. The post-run envelope has revision 118 and both notification settings disabled. The library DB, SHM, and WAL hashes match the seed. The visible disabled-save feedback is accepted on this binary. System permission, delivery, and cancellation remain open.

L14 saved the `morning` favorite. The post-run envelope contains that ID. Reflections and novena progress remain empty because the test stopped before their save actions. This run does not prove their persistence or the planned restart journey.

The helper corrections above are now committed at `6f83b790`. The accepted ContentFlow hash is `2fbfdda90ed5d74eee49a5411182e5e7a0bd80288e4d74405bfdb01dbe0dba4d`. Scroll gestures stay inside the visible viewport, above the keyboard and tab bar. The helper checks target or keyboard movement. The timer test requires a numerical decrease. Its runtime rerun remains open.

## Search test boundary

`SearchNoteUITests.swift` contains Search journeys and a new Vulgate note journey. Each Search test selects WEB-CE. The Latin case selects Vulgate and resets scope to All. The repeated-result case opens the second result before it checks Cancel separately.

Source added a committed-selection wait after each edition tap. The accepted test is committed at `ee8747f`, with hash `cc1d394b5b639b7927c3e67716c4b926b2939131b8d008bf57e5959876033a89`. Swift 6 simulator type-check passed. Main must use a task-only schema-1 seed without a note for Vulgate JHN 3:16. The note journey sets verse layout, waits for `IOHANNEM 3:16`, creates the note through Reader, changes to WEB-CE, and checks exact row `saved-row-note:vulgate:JHN:3:16:16` before and after one restart. Runtime acceptance remains open.

## Shared icon finding

The recorded Lectio image shows lines beside Back. Main corrected the glyph map to the pinned Expo Feather codes: `arrow-left = 61712`, `x = 61974`, `share = 61908`, and `more-horizontal = 61864`. It removed the unsupported `bookmark-plus` entry and added the source toolbar glyphs. The reviewed FeatherIcon hash is `c5c6828683d5632ccefa66118e4d0596b824126f44ce6d6a2543cad362454b70`. Runtime icon acceptance remains open.
