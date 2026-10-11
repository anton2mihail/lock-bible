# R5 release: 2.0.0 (24), submitted for App Review

Submitted 11 October 2026, about 3:05 PM. Status: Waiting for Review. Release: manual. The owner releases it in App Store Connect after approval.

## What changed since build 23
- Batch 4 merged to main with `--ff-only` (B4a App Intents, Focus filter, dictation, PencilKit, Spanish strings; B4b widgets, controls, Live Activity, notification actions; B4c Handoff, iCloud sync code).
- B4d: the Works (Fathers and Doctors) reader turns pages like Apple Books. `UIPageViewController` (slide), the page follows the finger, a tap on the left or right 30% turns the page, and a turn past the last page goes into the next section. Neighbor sections are paginated ahead. The first tap after a text selection only clears it. VoiceOver three-finger swipe turns the page.
- B4e: no iCloud in this build. The owner chose to ship without it. The iCloud and `aps-environment` entitlements and the `remote-notification` background mode are removed. `JohnCloudSyncAvailable = false` in the app Info.plist hides Settings > iCloud sync and keeps CloudKit untouched. To turn sync on later: create the containers, restore the entitlements, set the key to true.

## Checks
- Simulator: iPhone 17 Pro Max (existing device `3F2B0C7C`; the John simulators listed in older notes no longer exist).
- Manual: edge taps, slow drag follows the finger and snaps back, swipe back from Homily 2 page 1 lands on Homily 1 page 45, tap forward returns to Homily 2 page 1, long-press selection works and the next tap clears it without a page turn.
- UI tests passed: WorksSettingsUITests (5), NativeSmokeUITests testWorksReaderFooter and testVerseMomentReaderAndWorksFooter, SyncHandoffB4cUITests (2 passed, the sync toggle test skips because sync is hidden). ReleasePerformanceUITests needs the L26 Release setup and did not run, as in R3 and R4.
- JohnCore `swift test`: 35 tests passed.
- Signed archive: entitlements are app group and time-sensitive notifications only. `xcodebuild -exportArchive` printed "Uploaded John Update" and "EXPORT SUCCEEDED".

## App Store Connect
- New version 2.0.0, build 24, What's New and reviewer notes rewritten for the native app (read aloud is the reason for `UIBackgroundModes = audio`; microphone and speech permission for dictated notes).
- Screenshots replaced: iPhone 6.9-inch (6) and iPad 13-inch (4) from `marketing/screenshots/framed-2.0`. The lock-screen slide is the 1.5 image. The old images remain in the Asset Library.

## Not tested
- Nothing in batch 4 ran on a physical device: widgets, Live Activity, Dynamic Island, notification actions, Control Center controls, dictation, Pencil, Siri. Test build 24 from TestFlight on a phone before you press Release.
- Update over a real 1.5.0 install with real data was not repeated for this build.
