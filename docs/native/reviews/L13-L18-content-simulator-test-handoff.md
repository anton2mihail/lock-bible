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
