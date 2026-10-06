# L25 helper and run plan review

Date: 6 October 2026.
Reviewer: Sol (architecture, review, and acceptance).
Status: **Accepted with fixes.** Main can build after the required fixes below. No fix changes fixture bytes or the seed manifest.

## Reviewed boundary

Sol did not build, run a test, or use a simulator. Sol read the diffs against HEAD `2dfdae4` and type-checked the test sources.

| File | SHA-256 | Base |
| --- | --- | --- |
| `native/John/SimulatorSupport/AllRouteCaptureUITests.swift` | `b074878c77a4b8e568f23d468623e43ca0f2caf822a6a3694d65cc5d63c0dde3` | `261c0b9d…` (`a5d1dc7`) |
| `native/John/SimulatorSupport/ReaderParityUITests.swift` | `c9c226b7621f37508b29c64674bf62426cf0a680ae70b25a211760b40622837c` | `25d59326…` (`a5d1dc7`) |
| `native/John/SimulatorSupport/AllRouteCapture-README.md` | `cbf58af5d918bbf68267e05a60a26150088a91e84761df003aad9d06bfdadf0f` | HEAD |
| `native/John/SimulatorSupport/ReaderParity-README.md` | `c0a9bd1ed8d8a26daf1508e88bac6060b34af7bb0bbf4b6f586ace00cb605af7` | HEAD |
| `scripts/native/source-fixtures/l25/l25_fixture.py` | `36549ad8fc4fde6d7de6c8f30a387d526bf346d43611660c09f8e2f4db962d5c` | `b88623dc…` (reviewed) |
| `docs/native/reviews/L25-paired-capture-run-plan.md` | `ce129ff765361e205677556281d3588b08d934b288f0059c68471e65a818b668` | new |
| `docs/native/reviews/L25-capture-fixture-alignment.md` | `a3b3e1043cb07a37cba8781cb72ba6fa128d4186aa9ce3a0c1418118450846d7` | context |

`native/John/SimulatorSupport/PositiveNoticeUITests.swift` also differs from HEAD (`2c7d018e…`, HEAD `91c56f49…`). `wheelTargetValue` now returns only the numeric field. This file is not in this review. See "Out of scope".

## Type checks

Toolchain: Apple Swift 6.3.3. SDK: iOS Simulator 26.5. Flags: `-typecheck -swift-version 6 -target arm64-apple-ios26.0-simulator`, with the platform `Developer/Library/Frameworks` and `Developer/usr/lib` search paths for XCTest.

| Input | Result |
| --- | --- |
| `AllRouteCaptureUITests.swift` alone | exit 0, no diagnostics |
| `ReaderParityUITests.swift` alone | exit 0, no diagnostics |
| All 13 `SimulatorSupport/*.swift` files together | exit 0. One existing warning: `WorksSettingsUITests.swift:184` unused `resumedProse`. |

## Default behavior with no new values

| Item | Result |
| --- | --- |
| Appearance default | `light`. Same as before. `system` is accepted only for the app preference. `L25_EFFECTIVE_DEVICE_APPEARANCE` still accepts only `light` or `dark`. |
| Layout default | `Verse by verse`. The native ID stays `settings-layout-verse-by-verse`. The baseline label stays `Layout, Verse by verse`. |
| Text size, spacing, typeface, edition | Unchanged. |
| Skip rule for routes 8, 13, 19 | Unchanged at Extra large or a width other than 402 pt. Paragraphs also skips now. |
| Selected-passage tap | Native center tap, as before, when no offset is set. |
| Attachment names | Unchanged, except route 1: `L25--<variant>` is now `L25-today-<variant>` (G10). |
| Manifest | Same schema name. New keys only: `captureKind`, `callerFacts`, `runnerReadback`, `selectedPassageTap`, `keyboard`, `axTree`, `accessibilityAudit`. The screenshot is taken before the new queries. |
| Reader helper | `READER_PARITY_CASE` with one key works as before. Unset `READER_PARITY_TEXT_SIZE` keeps `settings-text-size-default` / `Text size, Default` and the log name `Medium`. No AX attachment without `READER_PARITY_AX_TREE=1`. |

Default behavior is unchanged except the accepted route 1 rename.

## Accepted selectors

The diff does not change these selectors:

- Baseline tab labels: `Today, tab`, `Read, tab`, `Saved, tab`, `Pray, tab`, `Settings, tab` with `BEGINSWITH[c]`. The Reader helper still uses `Read, tab` with `BEGINSWITH[c]`.
- Baseline Settings choices are `otherElements` with exact `label ==`. `selectionState` (line 802–803) compares the full values `radio button, checked` and `radio button, unchecked` with `==`. The `unchecked` trap stays closed.
- Back controls: baseline `Back to …`; native `reader-back`. Book-list titles `Read the Bible` and `reader-book-list-title`.
- Reader text: baseline paragraph `StaticText`; native `reader-verse-N` buttons in the native adapter only.

New choices use existing patterns. Native IDs come from `FullSettingsView.swift:219` (`settings-<label>-<option>`): `settings-layout-paragraphs`, `settings-appearance-system`, `settings-text-size-extra-large`. Old-app labels come from `src/components/ReadingSettings.tsx` (`Paragraphs`, `System`, `Extra large`).

## Supplements

- `requireSupplements()` runs first. It throws `XCTSkip` before any launch when `L25_ENABLE_SUPPLEMENTS` is not `1`.
- `makeContext(nativeOnly: true)` throws `XCTSkip` before `XCUIApplication` is created when the variant is not `native`.
- Method names sort after `testL25Route29…`. With the value unset, a class run skips them.
- Native IDs exist: `works-continue`, `collection-<id>`, `work-<id>`, `works-prose`, `reader-selection-pray`.
- The native `Info.plist` allows landscape. Part B adds `addTeardownBlock { XCUIDevice.shared.orientation = .portrait }` before the first rotation, and it rotates back in the body. Teardown restores portrait. Accepted.

## Owned-glyph rule

No new code taps blank space as a selection proof. The new offset path taps a point inside the verse 1 frame, but the point comes from Main's measurement. The plan requires a selection-summary proof for that point. A center tap on blank space in the native app cannot select a verse; the test then fails. It does not pass falsely.

One gap remains. With `L25_SELECTED_PASSAGE_PROFILE_MEASURED=1` and no `L25_VERSE1_TAP_OFFSET`, the native helper uses the Default/402 pt center tap on a new profile. This reuses an unmeasured point. See required fix 1.

## Fixture tool and manifest

Sol rebuilt the earlier text from the new file. Sol removed the two new comment lines and restored the four earlier fallback lines. The SHA-256 of the result is `b88623dcdb2aa1a55d9b7e1777ac90de41d8ef116d55c6d84a62734f558f2fa5`. This is the reviewed tool. The change is therefore limited to `describe_old` (edition, rotation, and scope now use the old-app source defaults `web-ce`, `1440`, `full`; see `src/services/bible/verseOfDay.ts` lines 23 and 29). `check` on the fixture still gives 22 `MATCH`, exit 0. The edition row now shows `web-ce (default)`.

**Manifest ruling: keep `aee48b2c…`. Do not make a new manifest.** The manifest `toolSha256` names the tool that prepared the fixture. The fixture files did not change. The new tool changes only the `check` logic. A new `prepare` run would change `createdUtc` and `expected/alignment.json`, and so the manifest hash and `L25_SEED_MANIFEST_SHA256`. That would add no value. Record the run-time tool hash beside the manifest instead (required fix 4). For seed, verify, and check runs, the tool hash in precondition 1 of `L25-capture-fixture-review.md` is now `36549ad8fc4fde6d7de6c8f30a387d526bf346d43611660c09f8e2f4db962d5c`.

## Rulings

### Ruling 1: reseed unit

**A series unit is allowed under these conditions. Otherwise reseed per method pair.**

A series is one ordered list of test methods in one `xcodebuild` run. A baseline series and a native series form one unit when all of these are true:

1. Both series start from a seed that passed `seed --apply` and `verify` (exit 0) with a new report folder.
2. Both series use the same `-only-testing` list, the same order (XCTest name order), and the same environment values except `L25_VARIANT`, `L25_APP_BUNDLE_ID`, and app identity values.
3. Every method in both series ends with the same status (pass, skip, or `unresolved` reason). A failure, an interruption, or a retry in either series ends the unit at that method. Captures before that method stay valid. Reseed both apps before you run the rest.
4. No route capture depends on state that the two apps keep with different rules. In the full 29-route order, the writes are: the Settings profile at the first method (the same choices in both apps), Reader location appends (John 1 near the top in both), and the Works position at route 28. Routes 26 and 27 run before route 28. The Reader is never scrolled away from the top before route 29. These writes affect no later capture differently in the two apps.
5. After each unit, Main stops both apps, copies both containers, and runs `check`. Expected differences: Reader location `updatedAt`, `scrollY`, and native `anchor`; Works positions after route 28 (both present, for `augustine.the-confessions`). Any other difference makes the unit invalid from the first method that can write that category.

Isolated reseed is required in these cases:

- Any subset run (B2k, B5, a retry, or a single route). Reseed both apps before the subset.
- Routes 26, 27, and 28 when they run outside the full ordered series. They need a seed with no Works position.
- Route 2 when it runs outside the full series after any Reader visit. It captures the restored John 1 position (`openJohnOne` returns at once when `John 1` is visible).
- Supplement S2a. It needs a native seed with empty `worksPositions`. S2b follows S2a with no reseed. Reseed both apps after S2b.
- The Reader nine-case method is one method. It is its own unit. Reseed before it and after it (it ends on Vulgate).

### Ruling 2: preference mode for profile batches

**Accepted, with amendments.**

1. Use `L25_APPEARANCE=system` for every route batch and leave the Reader helper appearance unchanged. The helper then finds `System` already selected and writes nothing.
2. Set the effective appearance with `xcrun simctl ui <UDID> appearance light|dark` while both apps are stopped. Read it back before and after each series. Set `L25_EFFECTIVE_DEVICE_APPEARANCE` and `READER_PARITY_EFFECTIVE_APPEARANCE` to the read-back value. Both apps follow the system scheme when no preference is saved: the old app uses `themeScheme || systemColorScheme` (`src/theme/context.tsx` line 83). The native app uses the System preference.
3. Use `L25_LAYOUT=Verse by verse` for the 29-route batches. The first method writes Layout in both apps. Routes 8, 13, and 19 stay capturable at 402 pt and Default.
4. Paragraphs coverage comes from the Reader cases: nine cases at Default, and `web-ce-JHN-1,web-ce-PSA-23,vulgate-JHN-1` at Dark and Extra large.
5. Fixture-state mode (`system` + `Paragraphs`) is optional. It is not required for L25 acceptance.
6. Check the first image of each series for the expected light or dark rendering in both apps before you continue.

### Ruling 3: one John device booted at a time

**Agreed, with amendments.**

1. Boot only one John device at a time. Shut down the John device that is not in use before you boot the next one.
2. Do not boot, shut down, erase, or change the other booted devices (`3F2B0C7C…`, `38A034BB…`, `FD8399C7…`) or the other shut-down project devices.
3. Several devices are booted at once. Always pass the explicit UDID to every `simctl` and `xcodebuild` command. Never use the `booted` alias.
4. Use only the three new John devices and `37D1870B…`. Create no other simulator. Run tests with `-parallel-testing-enabled NO`, so XCTest makes no clone devices.
5. Set and read back the status bar, appearance, and content size on each device before its first series. These settings belong to each device.

## Required fixes

1. **`native/John/SimulatorSupport/AllRouteCaptureUITests.swift`, line 395.** Replace

   ```swift
   if c.selectedPassageProfileMeasured { return true }
   ```

   with

   ```swift
   if c.selectedPassageProfileMeasured { return c.variant == .baseline || c.verse1TapOffset != nil }
   ```

   A measured profile must give a measured native point. Also update `AllRouteCapture-README.md` line 110: add "The native helper also needs `L25_VERSE1_TAP_OFFSET`. Without it, the route stays `unresolved`."

2. **`native/John/SimulatorSupport/AllRouteCapture-README.md`, line 118.** Replace "The full class run does not start them." with "A class run starts them only when `L25_ENABLE_SUPPLEMENTS=1` is set. Never set it in a route-series `.xctestrun`."

3. **`docs/native/reviews/L25-paired-capture-run-plan.md`.**
   - Line 12: replace the sentence with "Reseed both apps before each unit. See Sol's ruling 1 in `L25-helper-and-run-plan-review.md`."
   - Lines 120–125: state that every profile batch uses `L25_APPEARANCE=system` and `L25_LAYOUT=Verse by verse`, and that `simctl ui … appearance` sets the effective appearance (ruling 2).
   - Line 129: change `L25_APPEARANCE=light` to `L25_APPEARANCE=system`, and add `L25_EFFECTIVE_DEVICE_APPEARANCE=light`.
   - Line 130: change `L25_APPEARANCE=dark` to `L25_APPEARANCE=system`.
   - Line 165: add "Pass the explicit UDID to every command. Never use `booted`."
   - Line 185: replace "**Decision for the coordinator.**" with the ruling 1 conditions and the isolated-reseed list.
   - Line 193 (B2n): add "Before S2a, confirm that the native envelope has empty `worksPositions`, or reseed the native app."

4. **`docs/native/reviews/L25-capture-fixture-alignment.md`.**
   - Line 210 (Decisions, item 1): replace "The README stays unchanged until Main decides to edit it." with "`ReaderParity-README.md` now states this exception."
   - In the "Fixture" section, add: "The manifest `toolSha256` (`b88623dc…`) names the tool that prepared the fixture. Seed, verify, and check use `l25_fixture.py` `36549ad8fc4fde6d7de6c8f30a387d526bf346d43611660c09f8e2f4db962d5c`. It differs only in the old-app default fallbacks in `describe_old`. Record both hashes in each run record."

## Optional notes

1. `keyboardSnapshot` runs for every capture. It queries all text views and fields after the screenshot. It cannot change the image, but it adds time. Gate it behind `keyboardRequested` if the run time matters.
2. The manifest keeps `schema` `l25-route-capture-v1` with new keys. A reader that rejects unknown keys would fail. A `v2` name would be clearer.
3. `L25_VERSE1_TAP_OFFSET` is also used in the Default/402 pt profile when set. Set it only for a measured profile.
4. S1 records `stillnessTextVisible` and does not assert it. Main must read it before acceptance of the natural-expiry result.
5. The plan's Reduce Motion candidate writes a simulator accessibility default. Read the value back before and after, and restore it at the end of B5.

## Out of scope

`PositiveNoticeUITests.swift` changed after the accepted correction in `f135454` (`903b22b6…`). `wheelTargetValue` now returns the zero-padded number only. The readback check (`waitWheel`) is unchanged. Sol did not review this change here. It needs its own short review with the run evidence that shows `adjust` rejected the full value. Until then, do not count a notice result that used it as accepted evidence.

## Conditions for Main's build

1. Apply required fixes 1–4. Record the new file hashes.
2. Repeat the type check of all `SimulatorSupport` files.
3. Build one coherent target. Record source, app, test, and installed hashes.
4. Follow the seeding preconditions in `L25-capture-fixture-review.md`, with the tool hash from this review, and the three rulings above.
5. The first baseline route series is also a selector proof (G11). Treat a baseline selector failure as a helper fault. Do not count that pair.

## Old-app fault fixes re-check (route series B1)

Date: 6 October 2026. Sol read the diff of `AllRouteCaptureUITests.swift` (`8217aa641090c1f3e9c5503a910dd2ac83d19f03e1f1592ce5dae3bc3be2792d`) and `AllRouteCapture-README.md` (`ec748d7c1578b0c1e41272218c5872d18624f080336ae5f8fda892cd1d9f9f8c`) against HEAD `8938ec6`. The diff includes Main's earlier timeout increases. Sol ran no test.

**Native selectors: unchanged.** The native branches keep their identifiers and queries. Native behavior changes in two ways only:

- Longer waits (8–15 s to 30 s).
- One Settings-tab retry when `settings-title` does not appear in 10 s. A second tap on the selected tab returns to the Settings root. It cannot change the captured screen. It is logged as `L25_RETRY`.

Both are accepted.

| Change | Result |
| --- | --- |
| Settings title wait and one retry | Accepted. Old title `Settings` (`SettingsScreen.tsx:72`); native `settings-title`. |
| Route 4 `CONTAINS` (old app only) | Accepted. The visible title is part of a longer card label. |
| Route 5 exact `radio button, checked` on the `Other` element | Accepted. Exact equality; the `unchecked` trap stays closed. |
| Route 20 | Accepted. Old row title "Saints, feasts & daily readings" (`SettingsScreen.tsx:150–153`). Both apps show the destination title "A day in the Church": old `CalendarNotificationsScreen.tsx:43`, native `CalendarNotificationsView.swift:34` (`ContentPage(title: "A day in the Church", eyebrow: "Calendar notifications")`). |
| Old-app 90 s tab-bar wait after launch | Accepted. It waits; it does not change state. |

### Ruling (a): "Continue reading" as the old-app entry to John 1

**Accepted, with required fix 1.** Ruling 1 requires the same ordered methods, the same environment, and the same method status. It does not require the same control path inside a method. Each adapter already uses its own selectors.

The semantics differ in one way:

- The old control calls `openPassage(book, chapter, { scrollY: savedLocation.scrollY })` (`ReaderScreen.tsx:354–357`). It restores the saved scroll offset.
- The native series opens John 1 from the chapter grid at its natural top.

With the fixture (John 1, `scrollY` 0), both open at the top. Later in a series, the old saved offset can change. The Go To and Search images (routes 6 and 7) show the Reader behind a sheet. Routes 8, 13, and 19 need verse 1 in view. So the pair is valid only when the old Reader opens at the natural top. Both paths write the Reader location in the same way, so the saved-location rule does not change.

### Ruling (b): coordinate tap after "visible but not hittable"

**Accepted for the old app only, with required fix 2.** The fallback is not limited to route 25. `baselineTap` uses it for every old-app tap.

It is acceptable for three reasons:

- The element must exist, be inside the scroll viewport, and stay not hittable for 5 s.
- The tap goes to the center of the element's own frame.
- Each route still asserts its exact destination after the tap, so a tap that lands elsewhere fails the route.

It is evidence of the old app's visible control only. It is not evidence about the hit-testing of that control. It never applies to the native app.

### Required fixes

1. **`openJohnOne`, old-app "Continue reading" path.** After `John 1` appears, confirm the natural top: the first verse of John 1 (`Verse 1`, or the first paragraph text that starts with "1 In the beginning") must be hittable inside the top half of the scroll viewport. If it is not, go back to the book list and use the chapter-grid path. Log `L25_OPEN_JOHN1 baseline path=chapter-grid reason=not-at-top`. Record the path that was used (`continue-reading` or `chapter-grid`) in the route manifest, for example `extra["baselineOpenJohnPath"]`, not only in the log.

2. **Coordinate fallback labeling.**
   - Store each coordinate tap in the active capture context: element label, frame, and route.
   - Write it to the manifest as `baselineCoordinateTaps` (an empty list when none).
   - Set `routeStatus` to `passed-with-baseline-coordinate-tap` when the list is not empty.
   - State in `AllRouteCapture-README.md` that the fallback applies to every old-app tap, not only route 25, and that it never applies to the native app.
   - A pair whose old capture has a coordinate tap is valid only when its destination assertion passed. Sol reviews each such pair when it reviews the images.
