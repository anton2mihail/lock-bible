# L25 Oct 7 2026 handoff

Status at 10:38 EDT, 7 October 2026. The full XXXL route runs, matching route 12 recapture, native reach-helper retry, interaction supplements, and Reader reset checks are complete. No task test is active.

## Recovery state

- Target simulator: `37D1870B-F16D-488A-8F20-959201F970D9` (iOS 26.5, arm64). Use this exact UDID. Do not select a booted simulator. Keep tests serial.
- The full old-app largest-text run completed in `build/native-evidence/L25/paired-b1/oct7-full-baseline-content-size-routes/`.
- Fresh old-only seed was verified before the run. Seed report SHA-256: `9926aa853ed7d291491aa3c87489a15dec25f331eb5cb2e328b7fbc19ee0dca7`.
- Run uses the copied `.xctestrun` at `build/native-evidence/L25/DerivedData-final-reader-01/Build/Products/John Development_iphonesimulator26.5-arm64-oct7-full-baseline.xctestrun` and result bundle `build/native-evidence/L25/paired-b1/oct7-full-baseline-content-size-routes/result.xcresult`.
- Test log: `build/native-evidence/L25/paired-b1/oct7-full-baseline-content-size-routes/run.log`.
- The full baseline run executed 32 methods, skipped 3, and had 2 failures in 2,314.726 seconds. Routes 1–7 passed, route 8 failed, routes 9–11 passed, route 12 failed, and routes 13–29 passed. Route 8 is a known old-app note-editor layout fault. Route 12 used a stale caller passage (`Luke 10:38-42`); do not count it as a product fault or compare its diagnostic frame.
- The actual 7 October Today reading is `Luke 11:1-4`. Both `src/services/companion/data/readings-us.json` and `targets/widget/daily-readings-2026.json` confirm it. Native route 12 passed with that passage. Baseline route 12 was recaptured with the same passage and a fresh verified seed. The matching capture pair is now valid.
- Exported baseline images and route links are in `docs/native/reviews/oct7-baseline-route-review-index.md`. Export manifest SHA-256: `044feec161cda215eb4e0f9aa5ba779711a150beb89ce794559558022bd047ae`.
- Profile is `accessibility-extra-extra-extra-large` (XXXL), system appearance with effective light appearance, Default text, Verse by verse layout, actual date `2026-10-07`, Toronto. The seed-state record says Paragraphs; the test applies and verifies Verse by verse. Report these as separate seed and applied states.

## Built helper snapshot and current source

Current source `native/John/SimulatorSupport/AllRouteCaptureUITests.swift` SHA-256: `555bcd89a14fdec0be59decdf2a9d3d5d0c95cf7dcdf7a647f359075f3304ee2`. It includes parent-reviewed XXXL supplements and the bounded native reach retry. The full route runs used the compiled test bundle SHA-256 `40518d0f0c005dace623b97fba67d622337831f61cfa865d8f2cb463a33f9394`. The rebuilt `JohnUITests` binary SHA-256 is `00676473e84a0e832862d459fc27b1f65294eb11407f1cdcfbbd1f23fd1fc235`; `John.debug.dylib` remains `715acf45d3b3837b7257db80a92bffc9e1e83c03352eb53118e800979dc07810`. The retry `.xctestrun` SHA-256 is `9ab266b16f17badd59ef87e254f3dfeedde74ddffa1cbc542a4b267f45bc47df`.

The parent approved the native helper change after review. It uses a distance-based bound, a hard maximum of 180 drags, up to three consecutive no-motion gestures, and final frame and viewport diagnostics. Native taps still require `isHittable`. It checks that a target exists before it reads the target frame. The first build failed because the predicate needed explicit `self`; that syntax is fixed. The retry build passed with the same arm64 destination and `ONLY_ACTIVE_ARCH=YES`. Log: `build/native-evidence/L25/DerivedData-final-reader-01/build-for-testing-oct7-bounded-reach-r2.log`.

Three parent-reviewed supplemental native checks are in the same source file. Their results are below. The test source changed after the full pair; those route results use the compiled bundle noted above.

## Completed native full run

- Fresh native-only seed verified at `build/native-evidence/L25/capture-seed-oct7-full-native/seed-report.json`; SHA-256 `e75982722543c2221f6364b2e5b351e883bad859d138b7b7373172d629410860`. The seed touched only the native app.
- Readbacks before launch: appearance `light`, content size `accessibility-extra-extra-extra-large`. Status bar override: 9:41, Wi-Fi 3, cellular 4, battery charged 100. The old app was terminated after its test run. It was not uninstalled or reseeded.
- Native `.xctestrun`: `build/native-evidence/L25/DerivedData-final-reader-01/Build/Products/John Development_iphonesimulator26.5-arm64-oct7-full-native.xctestrun`; SHA-256 `b8858b25df6c9137c2de07b60b1eac0c09fb46abcdd271796cf41fca04fac5ee`.
- Native result and log: `build/native-evidence/L25/paired-b1/oct7-full-native-content-size-routes/result.xcresult` and `build/native-evidence/L25/paired-b1/oct7-full-native-content-size-routes/run.log`.
- The run executed 32 methods, skipped 3, and had 3 failures in 2,327.645 seconds. Routes 1–25 and 27 passed. Route 26 stopped on a transient no-motion assertion while reaching `reader-book-JHN`; routes 28 and 29 stopped at the old 24-drag limit. These failures did not tap offscreen controls. The native route 12 capture shows the correct `Luke 11:1-4` passage and was reviewed.
- Native route 26 target moved from y=3853 to y=3514 after one swipe, then did not move after the next swipe. Its viewport was `{{0,585.33},{402,205.67}}`.
- Native route 28 target `work-augustine.the-confessions` remained off-screen at y=5254.33 after 24 drags. Its viewport was y=116–791.
- Native route 29 target `reader-commentary-all` remained off-screen at y=54,855.33 after 24 drags. Its viewport was y=0–791.
- Full native route screenshots and AX links are in `docs/native/reviews/oct7-native-route-review-index.md`. Export manifest SHA-256: `527963eb3fa272719f4f1621a33398ed4b5b116e4c5a84ffe0d40b654985471f`.
- Exact command:

```sh
xcodebuild test-without-building -xctestrun 'build/native-evidence/L25/DerivedData-final-reader-01/Build/Products/John Development_iphonesimulator26.5-arm64-oct7-full-native.xctestrun' -destination 'platform=iOS Simulator,id=37D1870B-F16D-488A-8F20-959201F970D9' -derivedDataPath 'build/native-evidence/L25/DerivedData-final-reader-01' -only-testing:JohnUITests/AllRouteCaptureUITests -parallel-testing-enabled NO -resultBundlePath 'build/native-evidence/L25/paired-b1/oct7-full-native-content-size-routes/result.xcresult'
```

## Completed route 12 matching pair

The old route 12 recapture passed one test with no failures. Result: `build/native-evidence/L25/paired-b1/oct7-baseline-route12/result.xcresult`. Fresh baseline-only seed report: `build/native-evidence/L25/capture-seed-oct7-baseline-route12/seed-report.json`, SHA-256 `204177af0c773bc12dcaf7c3e8c3eddc7eb3c1ec95a2c64116146cdd87691aec`. Screenshot: `build/native-evidence/L25/paired-b1/oct7-baseline-route12/exported-attachments/89279F59-6DC5-485A-B63B-BBA01DEC519D.png`; SHA-256 `0dfc1346b83022a6cac72a7e636ca977b8f85b21c44d7bd1c792ef0783110607`. AX confirms `Luke 11:1-4`; its SHA-256 is `008abdb0c991a36b51254c0eca8913f13024010b7abd33902a9e5ca460885d8c`. The capture metadata SHA-256 is `4e2a154ebb8698aed2c48d7293336e89425acddc6a7052bb5ad9f089fdb00f61`.

## Native reach-helper retry

Routes 26, 28, and 29 passed with the rebuilt bounded native reach helper. The run executed 3 tests with 0 failures in 1,188.768 seconds. Result: `build/native-evidence/L25/paired-b1/oct7-native-retry-bounded-26-28-29/result.xcresult`. The run log and exported attachments are in the same folder. Review index: `docs/native/reviews/oct7-native-reach-retry-index.md`. The fresh native-only seed SHA is `fac5ddc555f5240f1ec34cc7e41d020677fc3fd05b18c8fb65a184833b62dacd`.

Route 26 scrolled from y=3,853 to the Works library destination. This confirms its earlier stop was a helper fault. Route 28 reached Augustine's *Confessions*, Book I. Route 29 reached the John 1 commentary destination and its `30 readings · 2 authors` count after a long but steady scroll. No offscreen tap occurred. The images still show XXXL layout limits.

## Next steps

All scheduled Oct 7 checks are complete. Do not upload or change app source during this handoff. Use the result and review indexes listed below to review open defects and visual limits.

## Aggregate Oct 7 results

- Baseline XXXL routes: 28 of 29 route methods pass after the corrected route 12 recapture. Route 8 remains a known old-app note-editor overlap fault. Route 25's test reaches the Glorious Mysteries landing page, but the expected media destination or external action remains unresolved. Full run: 32 methods, 3 skips, 2 failures; the route 12 failure used a stale passage. Corrected route 12: 1 pass.
- Native XXXL routes: all 29 route methods pass across the full run and bounded retries. Full run: 32 methods, 3 skips, 3 helper failures (routes 26, 28, 29); the targeted retries: 3 passes, 0 failures. Route 25 reaches the same Glorious Mysteries landing page and does not verify media playback or an external destination.
- Native XXXL interaction checks: 3 methods pass. Lectio Continue and Scripture Card share are usable in the checked state. The note edit test typed, saved, and reopened its marker. However, AX gives the keyboard-open `saved-note-editor` a zero-height frame. This is a confirmed P1 native XXXL editing-usability defect. See `docs/native/reviews/oct7-native-xxxl-supplements-index.md` and `native/John/Features/Secondary/SavedView.swift` lines 403–414. Root reviewed and confirmed the defect. App source remains unchanged.
- Reader reset checks: cold context, saved non-top context, and saved-position return each pass one test at system Large. These checks are not XXXL acceptance evidence. See `docs/native/reviews/oct7-reader-scroll-reset-regression-index.md`.
- Release: fresh unsigned Release checks C04, C12, C13, C14, and C15 pass. John archive/export signing was not tested in this review; signing readiness remains unverified. No archive upload occurred. See `docs/native/reviews/oct7-release-evidence.md` for the signing audit and recent distribution-signed Layr archives for team `QZ44N522NQ`.
- Final target simulator readback: `accessibility-extra-extra-extra-large`, appearance `light`, status bar 9:41, Wi-Fi 3, cellular 4, battery 100. No task test process is active. The unrelated Maestro `xcodebuild` remains on simulator `3F2B0C7C-EF14-4590-9F20-ECA395131E5C` and was not stopped.

## Focused results before the full pair

- Old route 6: one test passed. Result: `build/native-evidence/L25/paired-b1/oct7-baseline-content-size-route06-r1/result.xcresult`. Parent reviewed screenshot and confirmed correct John 1 navigation. The old Go To header clips at the right edge at XXXL.
- Old routes 28–29: two tests passed. Result: `build/native-evidence/L25/paired-b1/oct7-baseline-content-size-routes28-29-r1/result.xcresult`. Parent reviewed both screenshots and confirmed Confessions Book I page 1 and John 1 commentary. Huge type and clipped right content remain visible.
- Native route 2: one test passed. Result: `build/native-evidence/L25/paired-b1/oct7-native-content-size-route02-measurement-r1/result.xcresult`. Parent approved the word point `(125,176)` for this exact device/profile and image.
- Native routes 8, 13, and 19: three tests passed. Result: `build/native-evidence/L25/paired-b1/oct7-native-content-size-routes08-13-19-r1/result.xcresult`. Parent reviewed all three images. They prove correct destinations, but do not prove note editing, Lectio Continue, or card action reachability.
- Native routes 26, 28, and 29 pass on retry with the bounded reach helper. Screenshots, AX, hashes, and counts are in `docs/native/reviews/oct7-native-reach-retry-index.md`.
- Native XXXL note edit/save, Lectio Continue, and card share results are in `docs/native/reviews/oct7-native-xxxl-supplements-index.md`. The note editor is a confirmed P1 defect at XXXL because its accessibility frame is zero height with the keyboard open.
- Post-scroll-reset Reader runtime checks are in `docs/native/reviews/oct7-reader-scroll-reset-regression-index.md`. Each passed at system Large. They are not XXXL evidence.
- Native route 23 shortens mystery-step labels to fragments at XXXL. `native/John/Features/Guides/RosaryGuideView.swift` lines 110–133 use five equal-width columns and a two-line limit; this source needs an adaptive layout. Routes 24 and 27 show the expected reminder and Augustine destinations, but some titles split words. Route 25 shows the Glorious Mysteries landing page; media playback or an external destination remains unresolved.
- Debug build-for-testing succeeded with active arm64. Log: `build/native-evidence/L25/DerivedData-final-reader-01/build-for-testing-system-text-helpers-arm64-20261007.log`. App stub SHA-256 `6616ab52a0dba8da96c230355b1ef317e131059420e0bc7e7f0f924b4f6e8d90`; app debug library SHA-256 `715acf45d3b3837b7257db80a92bffc9e1e83c03352eb53118e800979dc07810`; XCTest SHA-256 `40518d0f0c005dace623b97fba67d622337831f61cfa865d8f2cb463a33f9394`; runner SHA-256 `7e36729d4fbf984e023e98952e7a2b878c735240c41c14f1f8a6b1544b20d233`.
- Fresh unsigned Release evidence passed checks C04, C12, C13, C14, and C15. John archive/export signing was not tested in this review; signing readiness remains unverified. See `docs/native/reviews/oct7-release-evidence.md`. Agents must not upload.

## Known limits

- The route 8 old-app layout fault is real and must remain visible in the paired report. Do not change its assertion or accept parity for this route.
- Route 25 ends on the Rosary landing page. The expected destination or external action remains unresolved. Do not report it as a verified media destination.
- A passing route proves the asserted navigation state. It does not prove clean visual layout or usable controls unless the image and AX evidence show that.
- Do not uninstall or remove the baseline app. If XCTest does not discover rebuilt methods after a later test rebuild, uninstall only the development XCTest runner as previously approved.
- Do not upload or distribute a build. Do not disturb the unrelated `3F2B0C7C...` simulator or its Maestro run.
