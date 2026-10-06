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
| `testL25Route02Reader` | `/read` | Read tab; seed identifies JHN 1 |
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
| `testL25Route15PrayerDetail` | `/prayer?id=…` | Prayer library, then Morning offering (`morning`) |
| `testL25Route16TeachingLibrary` | `/learn` | Today, then Explore the Catholic faith |
| `testL25Route17TeachingDetail` | `/teaching?id=…` | Teaching library, then The Eucharist (`eucharist`) |
| `testL25Route18Confession` | `/confession` | Today, then Prepare for Confession |
| `testL25Route19ScriptureCard` | `/share-card` | Read JHN 1:1, select verse 1, then Share Scripture card |
| `testL25Route20CalendarNotifications` | `/calendar-notifications` | Settings, then Calendar notifications |
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

