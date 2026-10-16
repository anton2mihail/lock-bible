# L25 all-route capture

`AllRouteCaptureUITests.swift` contains 29 separate UI tests. Each test opens one route through visible app controls. The test saves one screenshot and one JSON manifest as XCTest attachments. It hashes the exact PNG bytes that it attaches.

Main owns project membership, app installation, seed creation, status-bar setup, test execution, attachment export, and image review. This source preparation does not access a live app container and does not operate a simulator.

## Required launch environment

Set these values for each test run:

| Name | Required value |
|---|---|
| `L25_VARIANT` | `baseline` or `native` |
| `L25_APP_BUNDLE_ID` | The bundle ID of the app that the test must launch |
| `L25_APP_VERSION` | The version verified from the installed app |
| `L25_APP_BUILD` | The build verified from the installed app |
| `L25_SOURCE_VERSION` | Source commit or source artifact identity |
| `L25_SEED_ID` | Unique seed identity and manifest/hash reference |
| `L25_SEED_STATE` | Saved-row and initial Reader state summary |
| `L25_SEED_MANIFEST_SHA256` | SHA-256 of Main's seed manifest |
| `L25_EFFECTIVE_DEVICE_APPEARANCE` | Main-verified simulator appearance: `light` or `dark` |

Optional values include `L25_NATIVE_ARTIFACT` and `L25_JS_SOURCE_VERSION`. This capture file supports Light, Dark, or System app appearance and Default or Extra large reader text size. It keeps WEB-CE, Comfortable, and Serif fixed. The layout is Verse by verse unless `L25_LAYOUT=Paragraphs` is set. A missing value keeps the earlier profile (Light, Default, Verse by verse). It applies the requested preferences through visible Settings controls. `L25_APPEARANCE` accepts the lowercase `light` or `dark` values and, new, `system`. It normalizes them to `Light`, `Dark`, or `System` in the manifest. `L25_EFFECTIVE_DEVICE_APPEARANCE` stays `light` or `dark`. With `L25_APPEARANCE=system` and `L25_LAYOUT=Paragraphs`, the helper changes no fixture preference. Routes 8, 13, and 19 then record `unresolved`, because Paragraph layout has no verse controls. `L25_TEXT_SIZE` accepts `Default` or `Extra large`. Main must also supply `L25_EFFECTIVE_DEVICE_APPEARANCE` as `light` or `dark`. The manifest records this caller-supplied device setting separately from the app appearance preference. The manifest also records the measured app window width and height in points. A different preference profile skips the test. `L25_STATUS_BAR_PROFILE` records Main's status-bar setup. `L25_LOCAL_DATE` and `L25_TIME_ZONE` are comparison metadata only. The manifest records the actual device date and time zone. The test does not change app time or device time zone.

Run each route test once against the baseline and once against the native app. Use the same device model, measured window dimensions, orientation, status-bar profile, effective device appearance, requested app appearance, text size, other preferences, source identity, and logical seed. The manifest records requested appearance and text size, selected-state observations, and effective device appearance as separate facts. For baseline controls with no selected-state evidence, the manifest marks the preference unresolved. A route that needs a selected-passage tap is marked unresolved when text size is Extra large or window width is not the observed 402-point profile. The test does not reuse Default/402-point tap points for another profile. Record any mismatch in the test manifest or run notes. Do not run this capture profile on the production-ID update fixture.

The historic Release archive is native `1.2.2 (15)` with JavaScript metadata `1.5.0 (18)`. Do not report `1.5.0` as the native app version. Main must supply the installed app's actual bundle ID, version, and build. Task-only bundle IDs are valid.

## Seed requirements

Use a fresh task-only development seed. Keep Main's protected app data and L00/L04 fixtures unchanged. For the Scripture Card test, start Reader at the book list with no saved Reader location. If Main uses a chapter seed, the test returns to the book list through the visible Reader back controls. The seed must include:

| Data | Required identity |
|---|---|
| Reader | WEB-CE, JHN 1:1 text; start at the book list when a test enters Works through Reader back controls |
| Saved library | Valid schema-1 database, FTS available, and at least one known saved row |
| Calendar | A local installed reading so the Today and Passage routes have content |
| Prayer | `morning` |
| Teaching | `eucharist` |
| Novena | `st-padre-pio` |
| Rosary | named set `joyful` |
| Works collection | `augustine` |
| Work | `augustine.the-confessions` |
| Commentary | JHN 1, with 30 indexed readings |

The Reader, Settings, Saved, and route state must match between the baseline and native runs. Main records the exact seed file hashes and the saved-row identities. The tests do not create or change seed data.

## Route tests and real entry paths

Each method name ends in the route number from `docs/native/inventory/route-state-inventory.md`.

| Test | Route | Entry path |
|---|---|---|
| `testL25Route01Today` | `/` | Today tab |
| `testL25Route02Reader` | `/read` | Read tab; seed identifies JHN 1. The old app opens John 1 with its visible `Continue reading John chapter 1` button |
| `testL25Route03Saved` | `/saved` | Saved tab |
| `testL25Route04PrayerHome` | `/pray` | Pray tab |
| `testL25Route05Settings` | `/settings` | Settings tab; set and verify the common preference profile |
| `testL25Route06GoTo` | `/go-to` | Read JHN 1, then tap the Reader chapter title |
| `testL25Route07Search` | `/search` | Read, then Search Scripture |
| `testL25Route08NoteEditor` | `/note` | Read JHN 1:1, select verse 1, then Add note |
| `testL25Route09VerseMoment` | `/verse` | Today, then Verse & lock screen widget |
| `testL25Route10DailyReadings` | `/daily?date=…` | Today readings card; use the actual local date |
| `testL25Route11SundayPreparation` | `/sunday` | Today, then Come ready for Sunday |
| `testL25Route12PassageContext` | `/passage?reference=…` | Today readings, then the caller-supplied `L25_READING_REFERENCE` row |
| `testL25Route13Lectio` | `/lectio` | Read JHN 1:1, select verse 1, then Pray with this passage |
| `testL25Route14PrayerLibrary` | `/prayers` | Pray, then Everyday prayers |
| `testL25Route15PrayerDetail` | `/prayer?id=…` | Prayer library, then Morning Offering (`morning`) |
| `testL25Route16TeachingLibrary` | `/learn` | Today, then Explore the Catholic faith |
| `testL25Route17TeachingDetail` | `/teaching?id=…` | Teaching library, then The Eucharist (`eucharist`) |
| `testL25Route18Confession` | `/confession` | Today, then Prepare for Confession |
| `testL25Route19ScriptureCard` | `/share-card` | Read JHN 1:1, select verse 1, then Share Scripture card |
| `testL25Route20CalendarNotifications` | `/calendar-notifications` | Settings, then the Calendar notifications row (old app row title: `Saints, feasts & daily readings`) |
| `testL25Route21NovenaDetail` | `/pray/[id]` | Pray, then St. Padre Pio Novena (`st-padre-pio`) |
| `testL25Route22RosaryHome` | `/pray/rosary` | Pray, then Pray the Rosary |
| `testL25Route23RosaryGuide` | `/pray/rosary-guide?set=…` | Rosary home, then the named Joyful set |
| `testL25Route24RosaryReminder` | `/pray/rosary-reminder` | Rosary home, then Reminders |
| `testL25Route25RosaryMedia` | `/pray/rosary-media?episode=…` | Rosary home; open media only if the visible row is an in-app control |
| `testL25Route26WorksLibrary` | `/works` | Reader JHN 1; use Back to chapters, then Back to books |
| `testL25Route27WorksCollection` | `/works/author/[id]` | Reader back controls, then Augustine collection (`augustine`) |
| `testL25Route28WorkReader` | `/works/[id]?section=…` | Augustine collection, then The Confessions (`augustine.the-confessions`), section 0 |
| `testL25Route29ChapterCommentary` | `/commentary/[book]/[chapter]` | Reader JHN 1, then All 30 readings on this chapter |

The Reader commentary preview row opens WorkReader. It does not enter Chapter Commentary. Use `All 30 readings on this chapter` for JHN 1. The Works Library path starts from Reader because the app has no direct route link in this capture contract.

The baseline test selects controls by visible labels. The native test uses native leaf identifiers. The baseline test must not query native-only identifiers. If a control is not available in a release build, record the route as unresolved. Do not open external links to reach another screen. In particular, do not open the Release Rosary media website link. If Release has no in-app `why-pray` button, the Rosary home screenshot is the safe capture and the manifest must say that the Media route was unresolved.

## Screenshot and manifest evidence

Every route test adds one `public.png` attachment and one `public.json` attachment. The manifest includes the route key, resolved identity, baseline/native variant, app and source identity, seed ID, common preference profile, device model, OS version, date and time-zone origins, status-bar profile, PNG attachment name, byte count, capture time, and SHA-256 digest.

Main must export the attachment bytes from the `.xcresult`. Main must hash the exported PNG bytes and compare that hash with the JSON manifest. Do not re-render, crop, recompress, or substitute another screenshot before this check. Main must inspect each paired image only after the metadata match is complete.

The capture tests provide source and native route images. They do not prove visual parity, route data parity, player cleanup, notification delivery, or persistence. Main records those results in the separate runtime report.

## Optional capture values

All values below are optional. A missing value keeps the earlier behavior. The manifest records each value as a caller-supplied fact. The test does not set or prove the device setting.

| Name | Value | Effect |
|---|---|---|
| `L25_LAYOUT` | `Verse by verse` (default) or `Paragraphs` | Layout choice that the helper selects in Settings. |
| `L25_AX_TREE` | `1` | Attaches `XCUIApplication.debugDescription` as `L25-<slug>-<variant>-ax.txt`. The manifest `axTree` has its SHA-256 and byte count. |
| `L25_A11Y_AUDIT` | `1` | Runs `performAccessibilityAudit`. It ignores each issue and attaches the list as `-audit.txt`. It never fails the test. |
| `L25_KEYBOARD` | `1` | For routes 7, 8, 18, and 21, tap the first text input that exists and wait up to 4 s for a software keyboard. It never fails the test. The manifest `keyboard` has the status, the input, `softwareKeyboardVisible`, the frame, and the inputs that report `hasFocus`. A connected hardware keyboard can hide the software keyboard. The setting is host-wide. The helper does not change it. |
| `L25_HARDWARE_KEYBOARD` | Any text | Main records whether a hardware keyboard is connected. |
| `L25_CONTENT_SIZE` | Text, for example `accessibility-extra-extra-extra-large` | Records the value that Main set with `simctl ui <udid> content_size`. |
| `L25_REDUCE_MOTION`, `L25_INCREASE_CONTRAST` | Text | Record what Main set. |
| `L25_VERSE1_TAP_OFFSET` | `dx,dy` in points | Native tap point for verse 1, from the verse 1 frame origin. Main measures it per profile. Without it, the native helper taps the frame center. |
| `L25_SELECTED_PASSAGE_PROFILE_MEASURED` | `1` | Lifts the skip for routes 8, 13, and 19 at Extra large or at a width other than 402 pt. Set it only after Main measures the tap point for that profile. The old app uses a center tap. The native helper also needs `L25_VERSE1_TAP_OFFSET`. Without it, the route stays `unresolved`. |

The manifest also has `selectedPassageTap` (`center`, `offset dx,dy`, `skipped`, or `not-applicable`) and `runnerReadback`. `runnerReadback` holds the content-size category and the Reduce Motion flag that the UI test runner process reports. They are not proof of the app setting. Main must prove Reduce Motion and content size with its own read back.

Route 1 now names its files `L25-today-<variant>.png` and `.json`. The earlier name had an empty slug.

## Native-only supplements

Three methods run after the matched initial images exist. Each one skips unless `L25_ENABLE_SUPPLEMENTS=1` and the variant is `native`. Run one method at a time with `-only-testing`. A class run starts them only when `L25_ENABLE_SUPPLEMENTS=1` is set. Never set it in a route-series `.xctestrun`.

| Method | What it does | What Main does |
|---|---|---|
| `testL25Supplement01LectioNaturalExpiry` | Selects JHN 1:1, opens Lectio, goes to the quiet step, starts the 60-second timer, and waits up to 90 s for the countdown to end by itself. It does not tap `End the timer`. It captures the running state and the end state. The manifest records the elapsed seconds, whether `A moment of stillness` is visible, and the visible button labels. | Start after the matched route 13 images. Do not pass `-L14FeatureDate`. |
| `testL25Supplement02aWorksMiddlePage` | Opens `augustine.the-confessions` and pages to the middle page (`Page N of M`, at least 3 pages). It captures the initial page and the middle page with a body fingerprint and the lower controls. | Start after the matched route 28 images. Copy the stopped-app envelope after the test to record `worksPositions`. |
| `testL25Supplement02bWorksResumeAndWidthChange` | Relaunches, taps `works-continue`, captures the resumed page, rotates to landscape (width change), captures, rotates back, and captures. The manifest records the page labels and whether the restored label equals the resumed label. | Do not reseed between 02a and 02b. Copy the envelope after it. Reseed both apps before another profile. |

The old app is portrait-only, so these supplements have no baseline pair. Native `Info.plist` allows landscape. The helper restores portrait in a teardown block.


## Baseline selector rules (route series B1 fixes)

The first old-app route series passed 14 of 29 routes. The 15 failures came from baseline selector and scroll faults. Each rule below cites the old source. The native selectors did not change.

| Routes | Fault | Rule now |
|---|---|---|
| 2, 6, 7, 8, 13, 26, 28, 29 | `openJohnOne` could not scroll the virtualized Read book list to `John, 21 chapters`. | The old Read screen shows a `Continue reading` button with the label `Continue reading <book> chapter <n>` (`src/screens/ReaderScreen.tsx:607-620`). `continueReading` opens that chapter at the saved `scrollY` (`ReaderScreen.tsx:354-357`). The fixture saves John 1 with `scrollY` 0 (`L25-capture-fixture-alignment.md`). The helper taps the exact label `Continue reading John chapter 1` and checks that the Reader title button is `John 1`. It then checks the natural top: the first verse (button label `Verse 1. <text>`, `src/components/ChapterText.tsx:308`, or a paragraph that starts with `1 In the beginning`) must be hittable in the top half of the visible scroll area. If it is not, the helper goes back to the book list and uses the chapter grid with the scroll rule below. It logs `L25_OPEN_JOHN1 baseline path=chapter-grid reason=not-at-top`. If the Continue reading button is absent, it logs the same line with `reason=no-continue-reading-button`. The manifest field `baselineOpenJohnPath` records `continue-reading` or `chapter-grid` (`not-used` for routes that do not open John 1 through this path, and `already-open` if the Reader already showed John 1). Reseed both apps before a run, because a moved `scrollY` changes the opened position. |
| 16, 19, 27 | The first Settings tab tap was lost and the Today screen stayed. | `openTab("settings")` now checks the Settings title (native `settings-title`, `FullSettingsView.swift:26`; old heading `Settings`, `SettingsScreen.tsx:72`). It waits 10 s, taps the tab once more if the title is missing (log line `L25_RETRY`), then waits up to 30 s. |
| 4 | The old Pray card label is longer than the title. | For the baseline, the expected content is matched with `label CONTAINS "Pray the Rosary"`. Native keeps the exact `label IN` match. |
| 5 | The old text size choices are `Other` elements, not buttons. | For the baseline, the helper finds `otherElements` with the label `Text size, <size>` (`src/components/PreferencePicker.tsx:36-41`). It requires the exact value `radio button, checked`. `selectionState` keeps exact equality, so `radio button, unchecked` never counts as checked. |
| 20 | The old row title is `Saints, feasts & daily readings`. | The old row is an `ActionRow` under the `Calendar notifications` section header (`SettingsScreen.tsx:151-153`). Its label is `<title>. <subtitle>` (`src/components/companion/Companion.tsx:135`). The baseline matches the title. The old destination title is `A day in the Church` (`CalendarNotificationsScreen.tsx:43`). Native uses `settings-calendar-notifications`. |
| 25 | The Pray card was visible, but `isHittable` was false. The helper then dragged at the top of the list, and the "must move" assertion failed. | The log shows the card frame inside the viewport (`L25_SCROLL ... target={{24, 236}, {354, 290}} direction=down`). For the baseline, a control that is visible but not hittable is polled for 5 s. If it stays not hittable, the helper taps the center of its visible frame and logs `L25_COORDINATE_TAP`. The native "must move" assertion is unchanged. Each coordinate tap is recorded (see below). |

Baseline scroll rule: the old lists are virtualized React Native lists. The old-app `tap` drags up to 40 times with drags from 85 percent to 15 percent of the viewport. It compares a signature of the first visible buttons and texts before and after each drag. It stops after two drags that change nothing. If the target does not exist yet, it reverses the direction once. If the control is still missing, it fails with `Expected a route control`. The baseline launch wait (90 s for `Today, tab`) and the 30 s waits from the earlier fix stay.

### Old-app coordinate taps

The coordinate fallback applies to every old-app tap, not only route 25. It never applies to the native app. It runs only when the control exists, lies inside the scroll viewport, and stays not hittable for 5 s. The tap goes to the center of the control's own frame.

The helper stores each coordinate tap in the capture context (label, frame, route). The manifest field `baselineCoordinateTaps` lists them (an empty list when there is none). When the list is not empty and the route is otherwise captured, `routeStatus` is `passed-with-baseline-coordinate-tap`. A route that is already `unresolved` keeps that status.

A pair whose old capture has a coordinate tap counts only if its destination check passed. Sol reviews each such pair with the images. The tap is evidence of the old app's visible control only. It is not evidence about the hit-testing of that control.
