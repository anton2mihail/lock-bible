# Store screenshot helper (L28)

Main owns target membership (add `StoreScreenshotUITests.swift` to the `SimulatorSupport` list of the generator), the build, the seed, the device, and every run. This file defines captures only. It uses visible controls only. It has no launch argument, no launch environment, and no DEBUG hook. It does not change the app, the status bar, the appearance, the date, or the device.

## Cases

Each case is one test method. It skips unless `STORE_CASES` lists it (comma list, or `all`). The app is relaunched for each case, so no case leaks state to the next one.

| Case | Test method | Output number | Output slug |
| --- | --- | --- | --- |
| `today` | `testStoreToday` | 02 | `today` |
| `daily` | `testStoreDailyReadings` | 03 | `daily-readings` |
| `pray` | `testStorePray` | 04 | `pray` |
| `read` | `testStoreReadJohnOne` | 05 | `read-john-1` |
| `settings` | `testStoreSettings` | 06 | `settings` |

Number 01 is free for the lock-screen widget slide. The user sets that slide up by hand. Run `read` last on a fresh seed, so Today shows no Continue reading card.

## Environment (all are required)

| Name | Rule |
| --- | --- |
| `STORE_CASES` | Case list or `all`. |
| `STORE_BUNDLE_ID` | The installed Release app, for example `com.nrsv.verse.l26`. It must not end with `.dev` or `.uitests`. |
| `STORE_BUILD_CONFIGURATION` | `Release`. |
| `STORE_APP_BINARY_SHA256` | SHA-256 of the installed `John` executable. Recorded only. |
| `STORE_SEED_ID` | Identity of the fresh seed. Recorded only. |
| `STORE_EXPECTED_DATE` | Local date `yyyy-MM-dd`. The run fails if the device date differs. |
| `STORE_TIME_ZONE` | For example `America/Toronto`. The run fails if the device zone differs. |
| `STORE_STATUS_BAR_PROFILE` | Text that names the `simctl status_bar override` values. Recorded only. |
| `STORE_APPEARANCE` | `light` or `dark`. Set it with `simctl ui appearance` first. Recorded only. |

Pass them with the `TEST_RUNNER_` prefix (for example `TEST_RUNNER_STORE_CASES=today`) or in the `.xctestrun`.

## Seed the helper needs

A fresh install of the Release app (task-only bundle ID allowed), launched at least once. WEB-CE selected. Light or dark as named by `STORE_APPEARANCE`. Default text size. No bookmarks, highlights, notes, saved reading position, Works position, or favorites. No notification permission prompt pending. A date with ordinary Today content (the user chooses it before the run).

## Output

For each case the helper attaches two items, both `keepAlways`:

- `store-<iphone|ipad>-<W>x<H>-<NN>-<slug>.png`. A full-screen, opaque (no alpha) PNG. The name carries the device idiom, the pixel size, and the order number. Example: `store-iphone-1206x2622-02-today.png`.
- The same name with `.json`. It records device name, system version, pixel and point size, size class, SHA-256, byte count, bundle ID, binary hash, seed ID, capture time, local date, time zone, status-bar profile, appearance, and runner readbacks.

The test fails if the pixel size is not an accepted portrait App Store size (table in the source), if the PNG has alpha, or if the date or zone differ. The log line `STORE_CAPTURE name=... sha256=...` repeats the key facts.

Extract the files from the result bundle: `xcrun xcresulttool export attachments --path RESULT.xcresult --output-path OUT_DIR`. Then run `scripts/native/release/l28/l28_check_screenshots.py` on the PNG files. Then frame them with `marketing/frame-screenshots.py` if needed.

## Limits

The helper cannot prove the status-bar override, the appearance, or the seed. It records what the caller states. The navigation uses the native accessibility identifiers (`tab-*`, `today-title`, `today-verse-card` as a static text, `reader-*`, `settings-title`) and two label queries: the readings card (`label CONTAINS "Today’s readings"`, from `CompanionTodayView.swift:49` through `ContentArtCard`) and the Rosary card on Prayer home (`label CONTAINS "Pray the Rosary"`, `PrayerHomeView.swift:41`). If an identifier or label changes, the case fails with a named message. The iPad layout has not been run. Sol reviews the helper before use.
