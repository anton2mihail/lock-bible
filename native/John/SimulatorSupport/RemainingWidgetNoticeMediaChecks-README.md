# Remaining widget, notice, and Release media checks

Main owns all target changes, simulator actions, live app state, and runtime evidence. This note avoids new test routes. Use the accepted `L22ServiceComparison` helper and `MediaNotificationUITests` methods.

## Widget

Use a task-only development install with the reviewed bundle and App Group IDs. Record app and widget executable hashes, extension bundle ID, installed families, and current shared-state revision.

1. Add the Daily Reading widget and the Daily Verse widget on one simulator home screen.
2. Confirm the date and verse text match the app's current calendar and translation settings.
3. Change the shared translation and reading scope in Settings. Return to the home screen and record the next rendered values and refresh time.
4. Check each widget family that the app supports. Record the family and rendered size.
5. Check the timeline after the shared translation and reading scope change. Record the next refresh time and displayed values.
6. Tap the displayed verse. Confirm the app opens the same edition, book, chapter, and verse.
7. Record any App Group read or write failure. Do not claim shared access only from a valid suite URL.

Keep the old installed widget continuity check separate from a fresh development install. Do not use the production-ID update fixture for test-only data.

## Operating-system notices

The accepted service comparison checks plans, ordering, rollback, and injected failure behavior. The disabled-save UI check proves visible feedback only. It does not prove operating-system permission, pending requests, delivery, or taps.

For the real system check, Main must record the initial authorization state. Main must use a fresh task-only install. Preserve one unrelated pending request. Enable one local notice through its Settings control. If the operating system asks for permission, record the user's choice. Read pending requests through the system center. Record exact IDs, local trigger components, payload, and unrelated-request preservation. Then disable the feature and verify that only its own requests are removed. Keep the real device clock. Do not infer delivery from a pending request. Delivery and tap checks remain open. Check one warm-app tap and one cold-launch tap. Confirm that each tap opens the expected local date or Rosary destination. Record the request identifier and resolved destination.

## Release media

Run `testReleaseUnapprovedMediaUsesExternalFallback` on a Release build with the reviewed Rosary catalog that has no approved direct media URI. Confirm that no player-mode buttons exist and that the external action remains visible. Do not open the external link. The test proves the visible fallback only. It does not prove player release or playback.

Use the Debug media test for the in-app mode, episode, activation, and return checks. Keep those results separate from Release evidence.
