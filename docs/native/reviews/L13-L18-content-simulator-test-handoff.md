# Content simulator test handoff

Date: 6 October 2026.
Reviewer: GPT-6.1 Sol.
Status: test source assigned. Runtime acceptance remains open.

Source owns the new `native/John/SimulatorSupport/ContentFlowUITests.swift` file. Main owns project membership, task-only seeds, Runtime/router integration, and every simulator operation. This work uses simulator UI tests. It does not add a unit-test target.

Use three independently selectable journeys. Stop a journey on its first failed assertion. Use current leaf identifiers or exact accessible control labels. Wait for visible, hittable controls and complete sheet dismissal. Never put an identifier on an interactive parent.

1. Check persistent content with a fixed date and zone. Favorite a known prayer. Save exact before/after Sunday reflections. Save one known novena intention and complete one day. Terminate and relaunch once. Check the same prayer, Sunday date key, novena ID, intention, and completed day. Log those expected durable identities for Main's envelope inspection.
2. Check dated routes and guides. Assert daily/Sunday date and citation identity. Check a teaching route. Check all four Rosary set entries and Seven Sorrows. Check one guide's back, completion, and reset sequence. Check Lectio timer start and stop.
3. Check temporary Confession state. Enter a unique note. Background and activate the same app process. Check that the note clears. Then check route exit/re-entry and Finish & clear notes. Do not substitute a process relaunch for the background check.

Use `-L14FeatureDate` and `-L14FeatureTimeZone` for dated content. Start from Main's fresh task-only development seed. Do not clear unrelated state or touch the production same-ID fixture. Choose the exact IDs and expected values from the accepted source fixtures. Preserve source text. Do not open external media or official links in this journey.

Current leaf controls include `prayer-favorite`, `prayer-search`, and `content-back`. Input labels include `Before Mass reflection`, `After Mass reflection`, `Your novena intention`, and `Temporary confession notes`. Source must confirm the current route title before each action. New leaf IDs in Source-owned feature files are permitted only when they are needed for a stable test. Send each changed file and hash to Main before its build.

Use a current public route for invalid IDs or missing citations. If no such entry exists, record that limit. Do not add a test-only product route. Keep Reader selection geometry, accepted Saved operations, and Gate A checks outside this test file.

Send Main the test names, launch arguments, exact seed conditions, expected durable fields, and source hashes. Main will run the journeys in batch 4 of `Remaining-gate-runtime-order.md`. Main will preserve product/installed hashes, actual process records, screenshots, result files, and a read-only envelope inspection. Passing this helper does not complete all-route visual parity.

## Accepted test source

Commit `30caf1ef1544359fa8e2b4e84de99f9b446459af` completes the focused selector corrections after `fcb58e2`. The test file SHA-256 is `21f698bc3904f82c1a26d42a9a13a0129195147d7130e23da81c791ef0f57848`. Source reports a passing Swift 6 arm64 simulator SDK type-check with XCTest. This accepts source inclusion only.

The file has four independently selectable tests. Three check persistence, dated routes/Lectio start-stop, and Confession clearing. The separate Rosary test uses the exact 80-action Joyful source count. It checks initial and back progress, the actual completion title/controls, and zero progress after reset. Completion has no Progress element. Guide headers use the source short titles. Novena detail uses its actual title Text, rather than the generic page-title identifier.

Main must supply WEB-CE, no `morning` favorite, no reflection at `2026-09-13`, and default `st-padre-pio` progress. The fixed app date is `2026-09-13T16:00:00Z` in `America/Toronto`. The persistent journey checks those same identities after one relaunch. Timer start/stop is covered in source; natural Lectio countdown expiry remains untested. Source continues the separate `WorksSettingsUITests.swift` preparation. Main retains target membership and runtime control.
