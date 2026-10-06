# Notification view source review

Date: 6 October 2026.
Reviewer: GPT-6.1 Sol.
Status: callback boundary accepted. Target compilation, scheduling, and runtime remain open.

Source added `CalendarNotificationsView`, `RosaryReminderView`, and `FeatureTimePicker` under `Features/Notifications/`. The views use injected save callbacks. They do not call the notification center or request permission. Main retains those operations and durable state publication.

Calendar keeps its draft after an error. Rosary reloads committed settings after an error. Successful callbacks return committed settings. Weekdays remain Sunday 1 through Saturday 7. The Rosary picker uses a five-minute interval. Editing is disabled during saves. Route generations suppress save feedback after exit. These boundaries match the frozen handoff.

Required corrections are limited to these files. Update the time-picker coordinator with the current representable on every update. Apply the enabled environment to the native picker. Capture route generation before the Calendar system-settings callback. Hide the Calendar Toggle's visual label while preserving its accessibility label. Add the Rosary Toggle's leaf identifier. Restore source Calendar page spacing, Delivery time row metrics, reveal behavior, and bordered system-settings button. Restore the Rosary segmented, weekday, privacy-rule, success, and error styles.

Parse passes are source checks only. Main must compile the complete target. Permission denial, owned request reconciliation, concurrency, rollback, actual delivery, and cold/warm tap evidence remain the L22 runtime requirements. No new prototype or unit-test target is required.
