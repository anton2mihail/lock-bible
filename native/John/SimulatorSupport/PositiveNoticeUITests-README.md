# Positive notice UI checks

This file prepares two UI journeys for Main. Main owns the test target, task-only app seeds, system notification permission, request snapshots, and all simulator runs. This file does not prove scheduled requests, delivery, taps, or durable storage.

## Required launch environment

Main must pass these values to the test process:

- `L22_NOTICE_BUNDLE_ID`: the explicit task-only app bundle ID.
- `L22_NOTICE_DENY_BUNDLE_ID`: optional task-only bundle override for the denial journey.
- `L22_NOTICE_SEED_ID`: the task-only authorized journey seed.
- `L22_NOTICE_DENY_SEED_ID`: an independent task-only seed for the denial journey.
- `L22_NOTICE_INITIAL_AUTHORIZATION`: `authorized` for the first journey, or `notDetermined` when the first save will show the real Allow alert. Use `notDetermined` for the denial journey.

Do not use the preserved production-ID update fixture. Do not assume the current simulator authorization state. Main must create and verify the declared task-only seed before each method. Main must verify a fresh `notDetermined` permission state before the denial method. Main may use the same task-only bundle after it resets or reinstalls the app, or it may pass the optional denial bundle override. The launched denial bundle must not be `com.nrsv.verse`. Missing setup values fail test preflight. They do not skip a test.

## Journeys

`testAuthorizedCalendarAndRosaryNoticeSettings` saves Calendar at local 09:15, verifies re-entry, saves a weekly Monday Rosary reminder at 08:30, verifies re-entry, changes it to daily at 08:35, verifies the time and frequency after re-entry, then turns both features off. Monday is raw weekday 2. The test accepts an already-authorized seed or a declared `notDetermined` seed followed by a real Allow tap.

`testFreshUndeterminedCalendarPermissionDenialKeepsSettingOff` requires a fresh `notDetermined` seed. It enables Calendar, saves, taps the actual system Don't Allow action, checks the exact visible permission error, and checks that Calendar remains off after re-entry.

After each successful on/change/off state, the test emits `NOTICE_STAGE_READY <name>` and holds the screen for eight seconds. Main can capture same-process pending requests and the committed-state envelope during this interval. The visible message proves UI feedback only. Main must verify request identifiers, times, triggers, imported and unrelated request preservation, durable values, and denial rollback separately.

## Picker preflight

The helper locates hour and minute wheels by their observed accessibility labels. It sets each value and checks the displayed numeric value. If a picker exposes AM/PM, it checks that field too. It does not select a wheel by index. Main must inspect the first UI hierarchy and confirm that the current iOS version exposes semantic hour/minute labels for both the spinner and compact picker. If it does not, stop the run and update the test from the observed hierarchy. Do not infer a time from a button label alone.

The denial method requires a real system alert with a `Don't Allow` button. The authorized method requires a real `Allow` button only when the declared initial state is `notDetermined`. The test does not open system Settings or external links.

Notification delivery, pending-request fields, warm/cold taps, permission persistence outside the tested process, midnight/DST behavior, player lifecycle, and exact committed storage remain open for Main's separate checks.
