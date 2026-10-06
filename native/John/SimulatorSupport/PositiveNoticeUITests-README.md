# Positive notice UI checks

This file prepares two UI journeys for Main. Main owns the test target, task-only app seeds, system notification permission, request snapshots, and all simulator runs. This file does not prove scheduled requests, delivery, taps, or durable storage.

## Required launch environment

Main must pass these values to the test process:

- `L22_NOTICE_BUNDLE_ID`: the explicit task-only app bundle ID.
- `L22_NOTICE_DENY_BUNDLE_ID`: optional task-only bundle override for the denial journey.
- `L22_NOTICE_SEED_ID`: the task-only authorized journey seed.
- `L22_NOTICE_DENY_SEED_ID`: an independent task-only seed for the denial journey.
- `L22_NOTICE_INITIAL_AUTHORIZATION`: `authorized` for the first journey, or `notDetermined` when the first save will show the real Allow alert. Use `notDetermined` for the denial journey.
- `L22_NOTICE_SNAPSHOT_RELATIVE_PATH`: the relative output folder under the app Documents directory for the DEBUG system notice snapshots. Use a fresh path for each method. The test passes it to the app as the launch argument pair `-L22NoticeSnapshotRelativePath <value>`. See `scripts/native/source-fixtures/notifications/SystemNoticeSnapshot-README.md` for the file contract.

Do not use the preserved production-ID update fixture. Do not assume the current simulator authorization state. Main must create and verify the declared task-only seed before each method. Main must verify a fresh `notDetermined` permission state before the denial method. Main may use the same task-only bundle after it resets or reinstalls the app, or it may pass the optional denial bundle override. The launched denial bundle must not be `com.nrsv.verse`. Missing setup values fail test preflight. They do not skip a test. This includes `L22_NOTICE_SNAPSHOT_RELATIVE_PATH`: the test does not launch the app without a snapshot path, so no run can lose its system notice evidence by mistake.

## Journeys

`testAuthorizedCalendarAndRosaryNoticeSettings` saves Calendar at local 09:15, verifies re-entry, saves a weekly Monday Rosary reminder at 08:30, verifies re-entry, changes it to daily at 08:35, verifies the time and frequency after re-entry, then turns both features off. Monday is raw weekday 2. The test accepts an already-authorized seed or a declared `notDetermined` seed followed by a real Allow tap.

`testFreshUndeterminedCalendarPermissionDenialKeepsSettingOff` requires a fresh `notDetermined` seed. It enables Calendar, saves, taps the actual system Don't Allow action, checks the exact visible permission error, and checks that Calendar remains off after re-entry.

After each successful on/change/off state, the test emits `NOTICE_STAGE_READY <name>` and holds the screen for eight seconds. Main can capture same-process pending requests and the committed-state envelope during this interval. The visible message proves UI feedback only. Main must verify request identifiers, times, triggers, imported and unrelated request preservation, durable values, and denial rollback separately.

## Picker preflight

The observed Calendar `DatePicker` uses identifier `calendar-notifications-time-picker`. It expands inline. Its child `PickerWheel` values are `8 o’clock`, `00 minutes`, and `AM`. The hour wheel has no accessibility label. The helper uses the visible `DatePicker`. It finds the hour, minute, and meridiem wheels from these value forms. It does not select a wheel by index.

The wheels accept only data values in `adjust(toPickerWheelValue:)`. For the hour, the data values are `1` to `12`. For the minute, the data values are the minute numbers, such as `15`. The helper does not send the full value, such as `9 o’clock`. The system rejects it. After the adjust, the helper reads back the full value, such as `9 o’clock` and `15 minutes`. It saves only after the readback matches.

The Rosary time control is a compact `DatePicker` with identifier `rosary-reminder-time`. Its observed frame is `{183, 715, 179, 76}`. Its accessibility value is the time, for example `8:00 PM`. The center of this frame misses the time button. The helper taps at 80 percent of the frame width. It then waits for a `PickerWheel` to appear. The compact picker shows the same three wheel values as the Calendar picker. This hierarchy is now confirmed. The wheels can appear outside the `DatePicker` element. The helper logs the tree in that case.

The helper scrolls the page with a drag in the left gutter, 14 points from the left edge of the scroll area. A drag from the center can start on the inline Calendar picker. That drag changes the time. Do not drag from the center of the screen.

After the helper taps `Allow`, it waits until the alert has `exists == false`, for up to 10 seconds. The denial method taps `Don't Allow` and then waits for the visible permission error. A call to `waitForExistence` does not prove that the alert closed. That call can return true for an alert that is still on screen.

The denial method requires a real system alert with a `Don't Allow` button. The authorized method requires a real `Allow` button only when the declared initial state is `notDetermined`. The test does not open system Settings or external links.

Notification delivery, pending-request fields, warm/cold taps, permission persistence outside the tested process, midnight/DST behavior, player lifecycle, and exact committed storage remain open for Main's separate checks.
