# Action audit: 2026-10-06

This review checks connected actions in the current native source. Runtime and visual acceptance remain separate.

## Open source findings

1. Reader does not show the chapter commentary preview. The source uses `COMMENTARY_PREVIEW = 3`. It shows the first three entries in catalog order. It shows the chapter commentary route when more entries exist. Main must add this preview before Previous/Next in `ReaderView.swift`.
2. Verse Moment can change its displayed verse before its passage load finishes. Read and Card can then use the previous passage. Main must clear or disable these actions during the load. Main must check the captured verse and edition before it publishes an async result.
3. Prayer Home and Rosary routes use their default clock and time zone. Main must pass the same content clock and time zone used by Today and Calendar. Lectio must keep a live clock for elapsed timer time.
4. CitationContext can finish a verse lookup after route exit. Source must invalidate its route generation on exit. It must check that generation before it opens Lectio.

The Reader selection actions remain open under `L08-L10-selection-action-contract.md`. Source owns the pure toolbar. Main owns Reader integration, storage commands, note routing, and simulator checks.

## Content run classification

Evidence: `build/native-evidence/L22/source-content-flow-20261006/`.

The exported manifest has SHA-256 `2331c412ed82d56cb2e239aef80a63e7be6ef1fa41f0a56037e71f06bee43067`. The result has three failed content tests and one passed disabled-notification test. The disabled result proves visible feedback only. It does not prove system permission, delivery, or request removal.

L15 failed an exact `60s of quiet` lookup. The exported hierarchy `7FA90257-5CC4-404B-9E9F-AF80CF2A5BAE.txt` records app PID 23516. It shows Lectio step 4, `55s of quiet`, and `End the timer`. The timer started and progressed. The exact 60-second lookup is a test timing error. Source must check a positive countdown and an observed decrease before it stops the timer. Natural expiry remains untested.

L14 failed before it typed the second Sunday reflection. L18 failed before Continue after it typed temporary notes. Their keyboard and control state require review of the recorded images. These failures do not yet establish a product defect.

Main added provenance to `content-disabled-run-01/run.txt`. Product and installed executable hashes match at `7feceee97d31c0c07c9735dccf0b2e765f63370063b417fcfaaef139aa3b7660`. The debug library hashes match at `390136ee0acb054908b0e221c5c02fa4ac6dc9504087384e6e1bf7a68f1c1fe8`. The post-run envelope has revision 118 and both notification settings disabled. The library DB, SHM, and WAL hashes match the seed. The visible disabled-save feedback is accepted on this binary. System permission, delivery, and cancellation remain open.

L14 saved the `morning` favorite. The post-run envelope contains that ID. Reflections and novena progress remain empty because the test stopped before their save actions. This run does not prove their persistence or the planned restart journey.

## Search test boundary

`SearchNoteUITests.swift` contains Search journeys only. Each test selects WEB-CE. The Latin case selects Vulgate and resets scope to All. The repeated-result case opens the second result before it checks Cancel separately.

Source added a committed-selection wait after each edition tap. The source handoff hash is `191b6dec699dce4a386e294ff39880a53404d71be3aaa6871337f095ace26f50`. Swift 6 simulator type-check passed. Main must use a fresh task-only development seed. Runtime acceptance remains open. New note creation requires the real Reader action and editor route.
