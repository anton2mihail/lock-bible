# L22–L24 platform and Settings handoff

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: ready for isolated implementation. Gate D acceptance remains open.

## Ownership

Main owns `Runtime.swift`, the router, app lifecycle, notification delegate installation, project files, the design system, widgets, and all simulator operations. Source owns Works and its current content files. A third Luna worker can own new files under `Platform/Notifications/`, `Platform/Media/`, `Features/Notifications/`, `Features/Media/`, and `Features/Settings/`. It must not edit shared files or JohnCore. Send Main the file list, public interfaces, callback list, and stable hashes at a build boundary. Main adds target membership and integration.

The third worker could not start. The two existing workers keep these scopes. Main owns L22 scheduling, lifecycle, delegate installation, and notification UI after widget and content integration. Source owns isolated L23 media and L24 complete Settings after Works. Main retains shared integration and simulator control. Source sends new file and callback lists at each stable boundary.

On 6 October, split L22 at the view boundary. Source now owns only new `Features/Notifications/` files for `CalendarNotificationsView`, `RosaryReminderView`, and a feature-local native time picker. Main keeps the scheduler, permission requests, lifecycle, delegate, Runtime, router, target membership, and simulator. This work can proceed while Main checks the Saved Undo position.

Each view receives `initialSettings` of the matching JohnCore settings type, `onClose: @MainActor () -> Void`, and `onSave: @MainActor (Settings) async throws -> Settings`. Here `Settings` means the corresponding concrete calendar or Rosary type. Main returns the committed setting only after schedule reconciliation and durable state success. Calendar also receives `onOpenSystemSettings: @MainActor () async throws -> Void`. Rosary receives `readCommittedSettings: @MainActor () -> RosaryReminderSettings`. Views do not call a permission API or the notification center.

Calendar retains its draft after a failed save. Rosary resets its draft from the committed reader after a failed save, as the source does. Disable editing during save. Suppress route feedback after exit, but let a queued service operation finish. Calendar reveals its spinner from Delivery time. Rosary uses a compact native picker with a five-minute interval. Weekdays remain Sunday 1 through Saturday 7. Use leaf identifiers. Source sends complete file and callback lists at the stable target boundary.

Use ADRs 0001–0006 and the accepted state store. Do not create another preference store, calendar decoder, media catalog, or router. Use injected services and immutable values. Keep app platform frameworks outside JohnCore.

## L22: local notices

Read `src/services/rosary/reminders.ts`, `src/services/companion/calendarNotifications.ts`, both notification settings screens, and `src/app/_layout.tsx`. Keep exact source text, local time semantics, payloads, and error states. Use `UNUserNotificationCenter`. No push service is required.

Provide one serialized scheduling service for both features. An actor alone does not prevent overlap across an `await`. Use a task queue or an equivalent operation queue so a settings change and foreground refresh cannot interleave. Inject the notification center boundary, clock, time zone, calendar repository, committed-state reader, and durable-save callback. Return a committed settings value or an error. A failed operation must not show success.

Rosary defaults are disabled, daily, 20:00, weekday 2. Weekdays use Sunday 1 through Saturday 7. Use a repeating calendar trigger for daily or weekly delivery. Preserve title “A quiet moment for the Rosary”, the source body, default sound, and `/pray/rosary` payload. Read the imported notification ID. Reconcile the existing owned request before creating a replacement. Disable removes only this feature's request and clears its stored ID. Do not remove unknown requests.

Calendar defaults are disabled at 08:00. Build the exact source plan for offsets 0 through 30. Exclude delivery times at or before now. Require a celebration. Use the readings title when present. Preserve source Gospel/body fallbacks. Keep identifiers `john-calendar:<epoch milliseconds>` and `/daily?date=YYYY-MM-DD` payloads. Limit the plan to 30. Capacity is `max(0, min(30, 62 - unrelatedPendingCount))`, where unrelated includes Rosary and every non-calendar request. Preserve unchanged requests. Cancel only obsolete owned calendar requests. On a partial failure or failed state save, remove new requests and restore removed future requests. Report rollback failure and reconcile from committed settings on the next refresh.

Request alert and sound permission only after the user enables a feature. Do not request badge permission. A disabled save needs no permission. Foreground refresh reads permission without requesting it. Preserve denial recovery and the system Settings link. Main calls refresh after startup, on foreground, on significant date/time-zone changes, and hourly while active. Keep one owned timer. No background replenishment is assumed.

Use `CalendarNotificationSettings`, `RosaryReminderSettings`, `.setCalendarNotifications`, and `.setRosaryReminder` from JohnCore. Read the latest committed state when a queued operation starts. Do not derive an update from an old view snapshot. Preserve imported legacy payload keys and IDs. Main converts a tap to a typed dated Daily or Rosary destination, queues it behind startup, and consumes the response once. Reject invalid dates and unrelated payloads.

Required simulator evidence: enable, deny, change, and disable each feature; exact pending request fields; one serialized concurrent refresh/save; unrelated request preservation; partial failure with rollback; legacy Rosary reconciliation; one actual short development delivery and warm/cold tap. The operating system uses its real clock. An injected app date proves planning only. Development delivery overrides must be excluded from Release.

## L23: media

Read `src/screens/rosary/rosary-media-screen.tsx` and the staged six-entry Rosary catalog. Missing or invalid episode IDs select `why-pray`. Keep every title, subtitle, official URL, episode order, rights link, pending state, and selected state.

Use AVKit/AVFoundation for separate video and audio states. The exact gate is development OR a nonempty approved video/audio URI. Current production catalog entries have no approved streams. Release must show official links. The source rights card is Debug-only. It must not create a sample player or include development sample URLs. Define sample URLs only under `#if DEBUG`. Do not treat an official webpage or YouTube watch URL as an approved direct stream.

The plan excludes background playback, microphone recording, and picture in picture. This is the frozen product boundary, even though the old implementation configures extra media capabilities. Do not add audio background modes or recording permission. Pause the other player on mode changes. Pause both players on episode changes and route exit. Remove observations and release player items. Handle load failure and interruptions. Do not resume automatically after leaving or after an interruption. Keep finite duration/progress formatting and source pending-mode states.

Provide a MainActor feature model and view with `episodeID`, the injected catalog, `onClose`, and external-link callback. The model owns its player lifecycle. Main adds the typed media route. Source Rosary home uses its existing `onOpenMedia` callback.

Required simulator evidence: Debug video/audio controls with the development notice; mode and episode change pause; exit cleanup; failed stream state; invalid-ID fallback; Release with no player or sample URLs; all six official links and rights links. Use system link presentation. Do not publish or request content rights.

## L24: complete Settings

Read `src/screens/SettingsScreen.tsx`, `src/components/ReadingSettings.tsx`, `PreferencePicker.tsx`, and `ListItem.tsx`. Build a new `FullSettingsView` in the isolated Settings folder. Main replaces the current Settings root after target compilation. Preserve the source SpaceGrotesk root, section order, row metrics, separators, text, and selected states. Do not keep the current companion-style placeholder page.

Include Reading, Translation, Verse pool, Verse rotation, Lock screen widgets, Calendar notifications, and John 1:1 information in source order. Reading includes all four text sizes, three line spacings, two typefaces, two layouts, and System/Light/Dark. Preserve “Default” for medium and the VoiceOver layout hint. Read the same shared preference projection used by Aa. Send state mutations through the accepted durable callback. Main can adopt new reusable controls in Aa; the worker must not edit the existing Reader files.

Translation uses all three full metadata names, attribution, and copyright notice. Scope uses full/ot/nt and keeps the deuterocanonical explanation. Rotation uses all eight intervals and exact source labels. Use the existing enum and state actions. Main reloads widget timelines only after a durable effective preference change. Do not add a second widget bridge.

Keep all four widget instruction steps and exact widget names. The Calendar notifications row calls a route callback. About includes actual installed reading coverage, United States Roman Rite limits, sacred artwork disclosure, editorial/source disclosure, calendar/reading MIT credits, local reflections, temporary Confession notes, and active-edition attribution/copyright. Read coverage and metadata from accepted repositories. Do not invent years or claim complete calendar coverage. Preserve packaged third-party license files and document their target membership. Main owns icon, launch, entitlement, and project changes.

Give controls leaf accessibility identifiers. Do not attach an identifier to a container with interactive descendants. Keep error feedback and draft state after failed writes. Avoid optimistic selected state that conflicts with the committed envelope.

Required simulator evidence: live Aa/Settings agreement for each reading control; selected translation, scope, and cadence; durable preference restart without repeating migration; notification route/return; actual coverage and each edition's attribution; dark, large text, iPad width, keyboard and VoiceOver focus. Matched old/native Settings images remain required. Build checks alone do not accept L24.

## Platform references

Use the installed iOS 26.5 SDK signatures. Apple documents calendar triggers at [UNCalendarNotificationTrigger](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger), pending request inspection at [getPendingNotificationRequests](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/getpendingnotificationrequests(completionhandler:)), and native video presentation at [VideoPlayer](https://developer.apple.com/documentation/avkit/videoplayer). These references support the platform choices. Exact product behavior comes from the approved plan and source files above.

Complete scoped source files first. Main compiles one coherent batch and owns its runtime evidence. Sol reviews the batch before gate acceptance. Do not add a unit-test target or operate the simulator in parallel with Main.
