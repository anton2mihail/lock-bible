# F3 report

Simulator: `1BA50F09-ECBB-4811-A5B2-D4B591206970`. Extra iPad simulator `QA-Own-iPad` (iPad Pro 13-inch M5): created, used, deleted.

## 1. Widget build

Cause: the project built the app targets for arm64 and x86_64. The JohnCore package built only arm64 for a concrete simulator destination. The widget could not find the x86_64 JohnCore module.
Fix: set `ONLY_ACTIVE_ARCH = YES` in the project Debug configuration (`John.xcodeproj/project.pbxproj`).

| Build (no ARCHS override) | Result |
| --- | --- |
| Debug, `id=` simulator | pass (failed before) |
| Debug, generic iOS Simulator | pass |
| Release, `id=` simulator | pass |
| Release, generic iOS Simulator | pass |
| Debug and Release, generic iOS device | pass with `CODE_SIGNING_ALLOWED=NO` |
| Generic iOS device with signing | fails: no development team. This is a signing setting. I did not change it. Set the team for the TestFlight archive. |

## 2. Test classes (each run alone with `scripts/native/run-tests.sh`)

| Class | Result |
| --- | --- |
| ButtonDrift | pass |
| CalendarBoundary | pass (3 tests). There is no class named "Calendar". |
| MediaNotification | pass 2, skip 2 (Step 7 tests need `STEP7_*` env) |
| ScriptureCard | pass 1. 4 skip (Step 7 or iPad-only). The one real test failed once in a class run and passed twice alone. Flaky. |
| SearchNote | pass (4) |
| WorksSettings | pass (5). One test failed once ("not safely hittable") and passed twice. Flaky. |
| ReaderParity | pass 2, skip 1 (baseline app needed). `testGoToExpands...` failed after the 14-minute repository test and passed alone. Flaky. |
| WidgetHomeScreen | skip 3 (Step 7 env and probe hook) |
| PositiveNotice | pass 3 of 3 (see below) |
| SystemAccessibility | pass: Reduce Motion on set and verify, Reduce Transparency on set. Then both set off. |

PositiveNotice used bundle `com.nrsv.verse.dev`, fresh install and `L22_NOTICE_*` values. Denial test: fresh install, `notDetermined`. Authorized test: fresh install. Route test: `run-simulated-notification-response-ui.sh` with an xctestrun file. It failed twice with "notification must be hittable". Fix: the test now finds a hittable match (`PositiveNoticeUITests.swift`). It passes.

## 3. Manual checks (new `F3QualityUITests`, screenshots in `/tmp/f3-shots`)

The test visits Today, Read, Saved, Pray, Settings, Rosary, Novena, Lectio, Calendar notifications, Reader John 1 and Go To. On each screen it checks that every button has a VoiceOver label. Reduce Motion was on for all runs.

| Check | Result |
| --- | --- |
| Dark mode | pass. Labels present. Screenshots read well. |
| Dynamic Type XXXL (accessibility-extra-extra-extra-large) | pass. Text wraps. No clipped button seen. |
| Accessibility size accessibility-large | pass |
| Reduce Motion on | pass. ButtonDrift shows no late motion. |
| Landscape iPhone | pass. Layout works. XCUI saves the screenshot unrotated. |
| iPad portrait and landscape | pass after fix |
| VoiceOver labels on every button | pass. No empty label on any screen. |
| Offline | Not run on a device. The app has no `URLSession` code. Only Media uses a remote audio URL. I did not cut the network. Media streaming offline is not tested. |

Defect found and fixed: on iPad, Read, Pray and Settings used the full screen width. Today and the Reader used a 740 pt column. The fix caps these pages at the same width and centers them (`ReaderView.swift`, `PrayerHomeView.swift`, `FullSettingsView.swift`). I checked after the fix with iPad screenshots.

## Not fixed or open

- Flaky tests above: they fail only in long runs.
- The "OFFSCREEN" lines in the screenshot test reports show partly scrolled rows. They are not defects.
- Archive signing needs a development team.
- Skipped tests that need extra env: Step 7 media, card, widget, baseline reader.

## Commits

1. `F3: build widget with active arch only so JohnCore resolves`
2. `F3: pick a hittable SpringBoard notice in notice route test`
3. `F3: cap Read, Pray and Settings width on iPad` (also adds `F3QualityUITests.swift`)
