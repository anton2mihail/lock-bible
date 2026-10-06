# L25 paired-capture run plan

Date: 6 October 2026.
Owner: Source.
Status: plan, plus source helper changes (type-checked only). Source ran nothing on a simulator and booted no device.

This plan covers handoff steps 5 and 6. Main owns every simulator action. Use the matched fixture in `build/native-evidence/L25/capture-fixture-01/` (see `L25-capture-fixture-alignment.md`). Do not use it for L27.

## Summary

- The Reader helper has nine cases. The route helper has 29 tests. Both have a baseline (old app) adapter in source. No baseline route test has run yet. Expect selector fixes after the first old-app pass.
- Reseed both apps before each unit. See Sol's ruling 1 in `L25-helper-and-run-plan-review.md`.
- The coordinator approved three new John simulators (small iPhone SE 3, iPad A16, iOS 26.0 floor iPhone 17 Pro). They are shut down and empty. See "Device inventory".
- The old Expo build supports iPad (`UIDeviceFamily` 1 and 2). The iPad baseline is the tablet layout of the same build.
- Helper gaps G1, G2, G4, G5, G7, G8, G9, G10, and G12 are now source changes. G3 and G6 have hooks only. G11 stays for Main's first run. See section 6.
- Dark and Extra large profiles cover all 29 routes plus Reader cases `web-ce-JHN-1`, `web-ce-PSA-23`, and `vulgate-JHN-1` (coordinator decision).

## 1. Reader cases

Test: `ReaderParityUITests/testBibleRepositoryCasesAcrossEditions`. One launch runs all nine cases in this order. Set `READER_PARITY_CASE` to one key to run one case.

Common seed state: the L25 fixture (WEB-CE, John 1 saved at the top, 1 bookmark, 1 gold highlight, 1 note). Common start: the test opens Settings, applies Default, Comfortable, Serif, Paragraphs, and the case edition. It returns to Read and uses the Back controls to reach the book list. Then it opens the book and the chapter.

Capture names (per case): `reader-parity-<variant>-<key>-top`, `-end-text`, `-end-footer`. That is 27 images per variant.

| # | Case key | Edition | Book and chapter | First and last verse |
| --- | --- | --- | --- | --- |
| 1 | `web-ce-JHN-1` | WEB-CE | John 1 | 1 and 51 |
| 2 | `web-ce-PSA-23` | WEB-CE | Psalms 23 | 1 and 6 |
| 3 | `web-ce-SNG-1` | WEB-CE | Song of Solomon 1 | 1 and 17 |
| 4 | `douay-rheims-JHN-1` | Douay–Rheims | John 1 | 1 and 51 |
| 5 | `douay-rheims-PSA-23` | Douay–Rheims | Psalms 23 | 1 and 10 |
| 6 | `douay-rheims-SNG-1` | Douay–Rheims | Song of Solomon 1 | 1 and 16 |
| 7 | `vulgate-JHN-1` | Vulgate | IOHANNEM 1 | 1 and 51 |
| 8 | `vulgate-PSA-23` | Vulgate | PSALMORUM 23 | 1 and 10 |
| 9 | `vulgate-SNG-1` | Vulgate | CANTICUM CANTICORUM 1 | 1 and 16 |

Baseline adapter: it exists in source (`READER_PARITY_VARIANT=baseline`). It uses observed labels. A previous baseline run (`baseline-john1-parity-01`) passed up to the old end-guard step. The split `end-text` and `end-footer` code is not built or run yet.

What a run changes in old-app data:

- MMKV `bible.translationId` and the group prefs `translationId` change at each edition switch. The run ends with `vulgate`.
- MMKV `bible.reader.location` gets new entries. The last one is near the chapter end.
- Preferences stay at Default, Comfortable, Serif, Paragraphs. The test does not change appearance.

The native app changes the same fields in the envelope (`translationID`, `readerLocation`, `revision`). Reseed both apps after the run.

The other two Reader tests (`testGoTo...`, `testVerseLayoutRange...`) are native-only and already accepted. They are not paired captures.

## 2. Routes

Test: `AllRouteCaptureUITests`, 29 methods named `testL25RouteNN<Name>`. Each method launches the app, applies the common profile through Settings, enters the route, and attaches one PNG and one JSON.

Capture names: `L25-<slug>-<variant>.png` and `.json`. Route 1 now uses the slug `today`, so its name is `L25-today-<variant>.png`.

Common seed state: the L25 fixture. All route catalog IDs (prayer `morning`, teaching `eucharist`, novena `st-padre-pio`, Rosary `joyful`, work `augustine.the-confessions`, commentary John 1 with 30 readings) are bundled content. They need no saved state.

Profile writes (first test of a series): the helper taps Settings choices that are not yet selected. With the fixture it changes Layout from Paragraphs to Verse by verse. It changes Appearance from System to Light or Dark. It changes Text size only for Extra large. The same writes happen in both apps. Later tests in the series find the choices selected and write nothing.

Code letters in the "Old-app writes" column:

- L = every launch and every Reader visit appends a `bible.reader.location` entry (seen in the baseline recon).
- W = the Works position `works.position.v1` is written when the work opens (`onPageChange` in `work-reader-screen.tsx`).
- None = source shows no write on open. Main must still compare MMKV after the run.

| # | Route key | Slug | Required state | Start navigation | Baseline adapter | Old-app writes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `/` | `today` | Fixture | Today tab; title "A little closer to God." | Source only | L |
| 2 | `/read` | `read` | Fixture (John 1 saved) | Read tab; Back controls to book list; John; chapter 1 | Source only | L |
| 3 | `/saved` | `saved` | Fixture rows | Saved tab | Source only | L |
| 4 | `/pray` | `pray` | Fixture | Pray tab | Source only | L |
| 5 | `/settings` | `settings` | Fixture | Settings tab; common profile | Source only; AX shows radio values | L |
| 6 | `/go-to` | `go-to` | Fixture | Read John 1; tap chapter title | Source only | L |
| 7 | `/search` | `search` | Fixture | Read John 1; tap Search Scripture | Source only | L |
| 8 | `/note` | `note` | Fixture; 402 pt, Default | Read John 1; select verse 1; Note | Source only | L; no note saved |
| 9 | `/verse` | `verse` | Real clock | Today; Verse & lock screen widget | Source only | L |
| 10 | `/daily?date=…` | `daily-date` | Real clock | Today; readings card | Source only | L |
| 11 | `/sunday` | `sunday` | Real clock | Today; Come ready for Sunday | Source only | L |
| 12 | `/passage?reference=…` | `passage-reference` | `L25_READING_REFERENCE` from Today | Today; readings; reference row | Source only | L |
| 13 | `/lectio` | `lectio` | Fixture; 402 pt, Default | Read John 1; verse 1; Pray with this passage | Source only | L |
| 14 | `/prayers` | `prayers` | Fixture | Pray; Everyday prayers | Source only | L |
| 15 | `/prayer?id=…` | `prayer-id` | Fixture; `morning` | Pray; Everyday prayers; Morning offering | Source only | L |
| 16 | `/learn` | `learn` | Fixture | Today; Explore the Catholic faith | Source only | L |
| 17 | `/teaching?id=…` | `teaching-id` | Fixture; `eucharist` | Today; Explore; The Eucharist | Source only | L |
| 18 | `/confession` | `confession` | Fixture | Today; Prepare for Confession | Source only | L; temporary note not saved |
| 19 | `/share-card` | `share-card` | Fixture; 402 pt, Default | Read John 1; verse 1; Create card | Source only | L |
| 20 | `/calendar-notifications` | `calendar-notifications` | Fixture | Settings; Calendar notifications | Source only | L; no save |
| 21 | `/pray/[id]` | `pray-id` | Fixture; `st-padre-pio` | Pray; St. Padre Pio Novena | Source only | L; no progress write on open |
| 22 | `/pray/rosary` | `pray-rosary` | Fixture | Pray; Pray the Rosary | Source only | L |
| 23 | `/pray/rosary-guide?set=…` | `pray-rosary-guide-set` | Fixture; `joyful` | Rosary; Joyful Mysteries | Source only | L |
| 24 | `/pray/rosary-reminder` | `pray-rosary-reminder` | Fixture | Rosary; Rosary reminder | Source only | L; no schedule |
| 25 | `/pray/rosary-media?episode=…` | `pray-rosary-media-episode` | Fixture | Rosary; the media entry if in-app | Source only; expected `unresolved` | L |
| 26 | `/works` | `works` | Fixture; no Works position | Read John 1; Back; Back; Fathers and Doctors | Source only | L |
| 27 | `/works/author/[id]` | `works-author-id` | Same | Works; Augustine | Source only | L |
| 28 | `/works/[id]?section=…` | `works-id-section` | Same | Works; Augustine; The Confessions | Source only | L, W |
| 29 | `/commentary/[book]/[chapter]` | `commentary-book-chapter` | Fixture | Read John 1; All 30 readings | Source only | L |

Notes:

- "Source only" means the selectors come from source and the recon. No baseline route test has run. The recon observed tab labels (`Today, tab`), Settings radio values, Back controls, and Reader labels.
- Route 25: the Release old app shows an external link. The test records `unresolved` and does not open it. The native app can differ. Record this as an accepted exception.
- Routes 8, 13, and 19 skip the entry and record `unresolved` when the text size is Extra large or the window width is not 402 pt.
- Routes 10 and 11 use the real date. Route 12 needs one reading reference that both apps show. Main reads it from Today before the run.
- XCTest runs the methods in name order. Route 26 runs before route 28. A fresh seed makes route 26 show no resume card. A later series without reseed would show one.

The native app writes the same state classes into the envelope: `readerLocation`, `readingPreferences`, `themeScheme`, and (route 28) `worksPositions`. It writes no library row in these routes.

## 3. Profiles

Environment values for every run: `L25_VARIANT`, `L25_APP_BUNDLE_ID` (`com.nrsv.verse` or `com.nrsv.verse.dev`), `L25_APP_VERSION`, `L25_APP_BUILD`, `L25_SOURCE_VERSION`, `L25_SEED_ID` (`l25-capture-fixture-01`), `L25_SEED_STATE`, `L25_SEED_MANIFEST_SHA256` (`aee48b2c6b09cfa509e8242776914468a2a0fb8d9ea18082d634af5970c2ba58`), `L25_EFFECTIVE_DEVICE_APPEARANCE`. Put them in the `EnvironmentVariables` of a copied `.xctestrun`. Keep the copy beside the original in `DerivedData/Build/Products` so `__TESTROOT__` resolves. Do not pass `-L14FeatureDate` or `-L14FeatureTimeZone`.

Run command shape (no parallel clones):

```sh
xcodebuild test-without-building -xctestrun <copied .xctestrun> \
  -destination 'platform=iOS Simulator,id=<UDID>' -parallel-testing-enabled NO \
  -only-testing:JohnUITests/AllRouteCaptureUITests -resultBundlePath <new .xcresult>
```

Preference mode (Sol's ruling 2). Every profile batch uses `L25_APPEARANCE=system` and `L25_LAYOUT=Verse by verse`.

- With `L25_APPEARANCE=system` the helper finds System already selected in both apps and writes nothing. The Reader helper leaves the appearance unchanged.
- Set the effective appearance with `xcrun simctl ui <UDID> appearance light|dark` while both apps are stopped. Read it back before and after each series. Set `L25_EFFECTIVE_DEVICE_APPEARANCE` and `READER_PARITY_EFFECTIVE_APPEARANCE` to the read-back value. Both apps follow the system scheme when no preference is saved (old app: `themeScheme || systemColorScheme`, `src/theme/context.tsx`).
- The first route method writes Layout (Verse by verse) in both apps. Routes 8, 13, and 19 stay capturable at 402 pt and Default.
- Paragraphs coverage comes from the Reader cases: nine cases at Default, and `web-ce-JHN-1,web-ce-PSA-23,vulgate-JHN-1` at Dark and Extra large.
- Fixture-state mode (`L25_APPEARANCE=system`, `L25_LAYOUT=Paragraphs`) is optional. It is not required for L25 acceptance.
- Check the first image of each series for the expected light or dark rendering in both apps before you continue.

| Profile | Mechanism | Helper support now | What Main must do or measure |
| --- | --- | --- | --- |
| Default light | `xcrun simctl ui <UDID> appearance light`. Status bar: `xcrun simctl status_bar <UDID> override --time 9:41 --wifiBars 3 --cellularBars 4 --batteryState charged --batteryLevel 100`. Env `L25_APPEARANCE=system`, `L25_EFFECTIVE_DEVICE_APPEARANCE=light`, `L25_LAYOUT=Verse by verse`, `L25_TEXT_SIZE=Default`. Read back `simctl ui <UDID> appearance` before and after the series. | Full. | Nothing. |
| Dark | `xcrun simctl ui <UDID> appearance dark`. Env `L25_APPEARANCE=system`, `L25_EFFECTIVE_DEVICE_APPEARANCE=dark`, `L25_LAYOUT=Verse by verse`. Set the device appearance while both apps are stopped. Reader cases: leave the preference at System; the device appearance drives it. | Full (route and Reader helper). | Nothing. |
| Extra large (app text size) | Env `L25_TEXT_SIZE="Extra large"` (route helper). `READER_PARITY_TEXT_SIZE="Extra large"` (Reader helper). | Done (G7). Routes 8, 13, and 19 stay `unresolved` until the profile is measured. | G3: measure the verse 1 owned-word point. Then pass `L25_VERSE1_TAP_OFFSET=dx,dy` and `L25_SELECTED_PASSAGE_PROFILE_MEASURED=1`. The native helper needs both. Without the offset the route stays `unresolved`. |
| Extra large (system text) | `xcrun simctl ui <UDID> content_size accessibility-extra-extra-extra-large`. Restore with `content_size large`. Read back with `simctl ui <UDID> content_size`. | Records `L25_CONTENT_SIZE` and the runner readback. | Set `L25_CONTENT_SIZE` to the same value. Check the app layout in the first image. |
| Small iPhone | Device `John L25 Small iPhone SE 3` (375 pt width, home-button iPhone). | Manifest records window points. Routes 8, 13, and 19 are `unresolved` until measured. | G3 measurement at 375 pt. See "Device inventory". |
| iPad | Device `John L25 iPad A16`. | Same as small iPhone. The tab bar and layout are unverified. | G3 measurement. First run is also a selector recon for the tab bar. |
| iOS 26.0 floor | Device `John iOS 26.0 Floor iPhone 17 Pro`. | Not an L25 pair. It belongs to the deployment-floor check (handoff step 11). | See "Device inventory". |
| Keyboard | Env `L25_KEYBOARD=1` for routes 7, 8, 18, and 21. The helper uses the current host keyboard state. Search focuses itself on appear. | Done (G5). It records `softwareKeyboardVisible`, the frame, the status, and the inputs that report `hasFocus`. It never fails the test and never changes the host setting. | Record `L25_HARDWARE_KEYBOARD`. On the first run, confirm that `hasFocus` is true for a tapped field. Routes 18 and 21 use "first text view or field" and can report `input-not-found`. |
| Accessibility focus and tree | Env `L25_AX_TREE=1` (route helper) and `READER_PARITY_AX_TREE=1` (Reader helper). Optional `L25_A11Y_AUDIT=1`. | Done (G1). | Nothing. VoiceOver speech is not testable here. |
| Reduce Motion | No `simctl ui` option exists. Candidate: `xcrun simctl spawn <UDID> defaults write com.apple.Accessibility ReduceMotionEnabled -bool YES`, then restart the apps. Second candidate: the Settings app switch (Accessibility, Motion). Neither is proven on iOS 26.5. | Plumbing only (G6). Env `L25_REDUCE_MOTION` is recorded. `runnerReadback.reduceMotionEnabled` shows what the runner process reports. | Prove the toggle took effect before any image counts. Compare `runnerReadback` and the Settings switch. The native app has no Reduce Motion code, so images may not change. |

Notes:

- `simctl ui` also supports `increase_contrast enabled|disabled`. The plan does not request it.
- Restore the device after each profile: `appearance light`, `content_size large`, Reduce Motion off. Record each read back.
- VoiceOver speech needs physical-device evidence (S02).
- The Simulator keyboard setting is host-wide. Main does not change it. The helper records what appears.

## 4. Device inventory

Source ran `xcrun simctl list devices`, `list devices available`, `list runtimes`, and `list devicetypes`. Nothing else. Source did not boot any device and created none. The coordinator reports that the user approved three new John simulators.

| Device | UDID | State | Owner | Use |
| --- | --- | --- | --- | --- |
| John 1.5 Baseline iPhone 17 Pro | `37D1870B-F16D-488A-8F20-959201F970D9` | Booted | John task device (402 × 874 pt, iOS 26.5) | Default, Dark, Extra large, keyboard, AX, Reduce Motion |
| John L25 Small iPhone SE 3 | `5FC2D286-6774-4428-A7F8-9B43A9076B6C` | Shutdown | John (new) | Small iPhone profile (iOS 26.5, 375 pt wide) |
| John L25 iPad A16 | `E76B006D-2F32-4D49-98D4-9DC1F15B7EB3` | Shutdown | John (new) | iPad profile (iOS 26.5) |
| John iOS 26.0 Floor iPhone 17 Pro | `56AAEED9-CA66-4584-A217-4312910F6E80` | Shutdown | John (new) | iOS 26.0 floor check (runtime 23A343) |
| iPhone 17 Pro Max | `3F2B0C7C-EF14-4590-9F20-ECA395131E5C` | Booted | Unknown. Default name. | Do not use |
| HB P2 iPhone 17 Pro | `38A034BB-6A52-4E67-BFA9-E09F453144D4` | Booted | Other project | Do not use |
| HB P1 iPhone 17 Pro | `0B24E76E-7898-4B09-8277-6DE9A9F84B34` | Shutdown | Other project | Do not use |
| ByDay Audit iPhone 17 Pro | `D16071A4-5896-4128-9C9C-71832F98375B` | Shutdown | Other project | Do not use |
| Layr Store Shots 17 Pro Max | `FD8399C7-6D22-486B-B09B-9C5302ED5AA5` | Booted | Layr project | Do not use |

Notes for the new devices:

- Boot only one John device at a time (Sol's ruling 3). Shut down the John device that is not in use before you boot the next one. Other projects already have three booted devices. Do not boot, shut down, erase, or change them.
- Pass the explicit UDID to every `simctl` and `xcodebuild` command. Never use `booted`. Use only the three new John devices and `37D1870B…`. Create no other simulator. Run tests with `-parallel-testing-enabled NO`, so XCTest makes no clone devices.
- Set and read back the status bar, the appearance, and the content size on each device before its first series. These settings belong to each device.
- The three new devices have no John app and no data. For each device Main must install the apps, then seed. The seed tool needs the data container, which exists after the install (`simctl get_app_container … data`). The tool creates missing `Documents` folders. It copies `bible-search.db` when the container has none. Source did not test this on a fresh container. Main checks the dry run first.
- The old Expo build `John11.app` supports iPad. Its Info.plist has `UIDeviceFamily` 1 and 2. `app.json` has `supportsTablet: true`. Its iPad orientations include landscape. Its iPhone orientations are portrait only. Its minimum iOS is 15.1. Its simulator slice is arm64. Version 1.2.2 (15).
- Paired iPad baseline: the old app runs as a native iPad app (tablet layout), not as a scaled iPhone app. Capture it in portrait first. A landscape pair is possible, because both apps allow iPad landscape.
- Paired small iPhone baseline: the same `John11.app` runs on the SE device.
- The iOS 26.0 floor device needs only the native app. The old app can install there (minimum 15.1) but no pair is needed.
- Window sizes to expect: SE 3 is 375 × 667 pt. iPad (A16) is 820 × 1180 pt in portrait (expected values; Main confirms them from the manifest `windowPoints`).

## 5. Run batches

One simulator owner. Times are estimates. Basis from evidence logs:

- Native one-case Reader run: 86.8 s (a second passing run: 133.5 s).
- Old-app navigation recon: 126.9 s.
- Native route-sized tests: 13 to 31 s each.
- Settings profile loop: about 12 s (preflight log).
- Works tail: 88.3 s. Go to: 95.2 s. Range: 112.8 s.

Rules for every batch (from `L25-capture-fixture-review.md`, "Seeding preconditions"): confirm the three hashes. Stop both apps and check with `launchctl list`. Dry run. Apply with a new report folder. Run `verify` before the first launch. Record host date, time, and time zone at the start and end. Both apps of one pair use the same local date and the same side of 17:00 Toronto time. If a pair crosses 17:00 or midnight, discard it, reseed, and repeat.

Reseed unit (Sol's ruling 1). A series is one ordered list of test methods in one `xcodebuild` run. A baseline series and a native series form one unit when all of these are true:

1. Both series start from a seed that passed `seed --apply` and `verify` (exit 0) with a new report folder.
2. Both series use the same `-only-testing` list, the same order (XCTest name order), and the same environment values except `L25_VARIANT`, `L25_APP_BUNDLE_ID`, and the app identity values.
3. Every method in both series ends with the same status (pass, skip, or `unresolved` reason). A failure, an interruption, or a retry in either series ends the unit at that method. Captures before that method stay valid. Reseed both apps before the rest.
4. No route capture depends on state that the two apps keep with different rules. In the full 29-route order the writes are the Settings profile at the first method, Reader location appends (John 1 near the top in both apps), and the Works position at route 28. Routes 26 and 27 run before route 28. The Reader is never scrolled away from the top before route 29.
5. After each unit, Main stops both apps, copies both containers, and runs `check`. Expected differences: Reader location `updatedAt`, `scrollY`, and native `anchor`; Works positions after route 28 (both present, for `augustine.the-confessions`). Any other difference makes the unit invalid from the first method that can write that category.

Isolated reseed is required in these cases. Otherwise reseed per method pair:

- Any subset run (B2k, B5, a retry, or a single route). Reseed both apps before the subset.
- Routes 26, 27, and 28 when they run outside the full ordered series. They need a seed with no Works position.
- Route 2 when it runs outside the full series after any Reader visit. It captures the restored John 1 position.
- Supplement S2a. It needs a native seed with empty `worksPositions`. S2b follows S2a with no reseed. Reseed both apps after S2b.
- The Reader nine-case method is one method and its own unit. Reseed before it and after it (it ends on Vulgate).

| Batch | Device | Content | Estimated time |
| --- | --- | --- | --- |
| B0 | 17 Pro | Environment: `appearance light`, status bar, `content_size large`. Read back each. Record bundle versions, UDID, hashes. Read Today in the old app and pick `L25_READING_REFERENCE`. Seed acceptance (precondition 9). | 10 min |
| B1 | 17 Pro | Reader nine cases, Default light. Seed both. Old run 10 to 15 min. Native run 10 to 13 min. | 25 to 30 min |
| B2 | 17 Pro | AllRoute 29 methods, Default light (`L25_APPEARANCE=system`, `L25_EFFECTIVE_DEVICE_APPEARANCE=light`, `L25_LAYOUT=Verse by verse`), with `L25_AX_TREE=1`. Old first (find selector faults early). Then native. Reseed both first. | 40 to 55 min |
| B2k | 17 Pro | Keyboard: routes 7, 8, 18, 21 with `L25_KEYBOARD=1` and `L25_AX_TREE=1`. Use `-only-testing` for four methods. Reseed both. | 6 to 8 min |
| B2n | 17 Pro | Native-only supplements (`L25_ENABLE_SUPPLEMENTS=1`): S1 Lectio expiry. S2a Works middle page, then copy the envelope. S2b resume and width change. Before S2a, confirm that the native envelope has empty `worksPositions`, or reseed the native app. Reseed both after S2b. | S1 2 min. S2a 2 to 3 min. S2b 3 to 4 min |
| B3 | 17 Pro | Dark (`simctl ui … appearance dark` while both apps are stopped; `L25_APPEARANCE=system`; `L25_EFFECTIVE_DEVICE_APPEARANCE=dark`): all 29 routes plus Reader cases `web-ce-JHN-1,web-ce-PSA-23,vulgate-JHN-1` (one `READER_PARITY_CASE` list). Reseed both. | 55 to 75 min |
| B4 | 17 Pro | Extra large (app text size): all 29 routes plus the same three cases. Needs the G3 measurement for routes 8, 13, 19. Reseed both. | 55 to 75 min |
| B4s | 17 Pro | System text size (`content_size`), 29 routes. Reseed both. | 40 to 55 min |
| B5 | 17 Pro | Reduce Motion: routes 1, 2, 13, 22, 23, 28. Needs the proven mechanism (G6). Restore Reduce Motion off. | 8 to 12 min |
| B6 | SE 3 | Install both apps. Measure G3 at 375 pt. Run B2 content (29 routes) plus the three Reader cases. | 80 to 100 min |
| B7 | iPad A16 | Install both apps. Measure G3. Run B2 content plus the three Reader cases. Landscape is an optional second pass. | 80 to 100 min |
| B8 | iOS 26.0 floor | Native only. Deployment-floor check (handoff step 11). Not an L25 pair. | Separate plan |

Order reasons:

- B1 runs first because it changes the edition. Reseed ends that drift.
- B2 includes the AX tree. This removes an extra pass.
- S1 and S2 run only after the matched images of routes 13 and 28 exist. S2a changes the Works position. Reseed both apps before B3. The old app wrote its own Works position at route 28.
- Run all 17 Pro batches before B6 and B7, so the G3 method is proven on one device first.
- Total for the 17 Pro batches: about 5 to 6 hours of run time. B6 and B7 add about 3 hours.

Native-only supplements (now source methods):

- S1 `testL25Supplement01LectioNaturalExpiry`. Do not tap End. The manifest has the elapsed seconds.
- S2a `testL25Supplement02aWorksMiddlePage`. Copy the stopped-app envelope after it.
- S2b `testL25Supplement02bWorksResumeAndWidthChange`. Do not reseed between S2a and S2b. The old app is portrait-only, so there is no baseline pair.

## 6. Helper gaps

Status after the source change. The test files type-check (see the change list in the coordinator reply). Nothing was built or run.

| Gap | Status | Where |
| --- | --- | --- |
| G1 AX tree and focus | Done. Optional `L25_AX_TREE=1`, `L25_A11Y_AUDIT=1`, `READER_PARITY_AX_TREE=1`. The manifest has `axTree`, `keyboard`, `accessibilityAudit`. | `AllRouteCaptureUITests.swift`, `ReaderParityUITests.swift` |
| G2, G4 Caller facts | Done. `L25_CONTENT_SIZE`, `L25_REDUCE_MOTION`, `L25_INCREASE_CONTRAST`, `L25_HARDWARE_KEYBOARD` in `callerFacts`. `runnerReadback` has the runner values. | `AllRouteCaptureUITests.swift` |
| G3 Selected-passage entry at other profiles | Hooks only. `L25_VERSE1_TAP_OFFSET=dx,dy` and `L25_SELECTED_PASSAGE_PROFILE_MEASURED=1`. Main must measure. | `AllRouteCaptureUITests.swift` |
| G5 Keyboard capture | Done. `L25_KEYBOARD=1`. It records what appears. It does not change the host setting. | `AllRouteCaptureUITests.swift` |
| G6 Reduce Motion | Hooks only. Recorded value and runner readback. The mechanism needs proof by Main. | `AllRouteCaptureUITests.swift` |
| G7 Reader helper | Done. Case list, `READER_PARITY_TEXT_SIZE`, AX tree. | `ReaderParityUITests.swift` |
| G8 Natural Lectio expiry | Done as a native-only method. | `AllRouteCaptureUITests.swift` |
| G9 Works middle page and width change | Done as two native-only methods (02a, 02b). | `AllRouteCaptureUITests.swift` |
| G10 Route 1 slug | Done. The slug is `today`. | `AllRouteCaptureUITests.swift` |
| G11 Unrun baseline selectors | Open. Main's first old-app pass proves them. | none |
| G12 Appearance and layout coverage | Done. `L25_APPEARANCE=system` and `L25_LAYOUT=Paragraphs` are accepted. | `AllRouteCaptureUITests.swift` |

What Main must measure for G3 on each new profile (Extra large at 402 pt, SE 3 at 375 pt, iPad A16):

1. Run one route capture with `L25_AX_TREE=1`. Read the frame of `reader-verse-1` from the tree.
2. Find a point that lies on a glyph of verse 1 (the first word). Use the screenshot. The earlier measured points (20, 14) and (30, 14) were for verses 2, 8, 10, 11, and 12 at 402 pt and Default.
3. Prove the point: tap it and read `reader-selection-summary` (`Selected: verses 1–1`). Then tap again to clear.
4. Pass the point as `L25_VERSE1_TAP_OFFSET=dx,dy` and set `L25_SELECTED_PASSAGE_PROFILE_MEASURED=1`. Check the manifest field `selectedPassageTap`.
5. Record the device, the window points, and the text size with the measured point.

What Main must prove for G6: a before and after read back of the Reduce Motion setting that does not rely on the runner process alone. Do not accept any Reduce Motion image without it.
