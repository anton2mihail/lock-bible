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

Optional values include `L25_NATIVE_ARTIFACT` and `L25_JS_SOURCE_VERSION`. This capture file supports Light or Dark app appearance and Default or Extra large reader text size. It keeps WEB-CE, Comfortable, Serif, and Verse by verse fixed. It applies the requested preferences through visible Settings controls. `L25_APPEARANCE` accepts the existing lowercase `light` or `dark` values and normalizes them to `Light` or `Dark` in the manifest. `L25_TEXT_SIZE` accepts `Default` or `Extra large`. Main must also supply `L25_EFFECTIVE_DEVICE_APPEARANCE` as `light` or `dark`. The manifest records this caller-supplied device setting separately from the app appearance preference. The manifest also records the measured app window width and height in points. A different preference profile skips the test. `L25_STATUS_BAR_PROFILE` records Main's status-bar setup. `L25_LOCAL_DATE` and `L25_TIME_ZONE` are comparison metadata only. The manifest records the actual device date and time zone. The test does not change app time or device time zone.

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
