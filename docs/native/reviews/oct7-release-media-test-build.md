# Release media UI test build evidence, 7 October 2026

Owner: Luna. This is a build-for-testing record. No simulator test ran in this task.

## Release build-for-testing

The Release-only external-media test is inside `#if !DEBUG` in `native/John/SimulatorSupport/MediaNotificationUITests.swift`. The `John Update` scheme does not include the UI test target. The `John Development` scheme does include it. Therefore the build used `John Development` with `-configuration Release` and selected only the requested method.

```sh
xcodebuild build-for-testing -project native/John/John.xcodeproj \
  -scheme 'John Development' -configuration Release \
  -destination 'platform=iOS Simulator,id=37D1870B-F16D-488A-8F20-959201F970D9' \
  -derivedDataPath build/native-evidence/L28/release-ui-bft-oct7-02/DerivedData \
  '-only-testing:JohnUITests/MediaNotificationUITests/testReleaseUnapprovedMediaUsesExternalFallback' \
  ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO
```

Result: `** TEST BUILD SUCCEEDED **`. The build used the assigned iPhone 17 Pro simulator destination. It did not launch a simulator test. It did not use another device. The first build attempt used a wrong destination and stopped before tests; the successful build above uses the assigned destination and a fresh DerivedData directory.

The Release UI test binary contains the selected Release-only method (`strings -a` check). The test source SHA-256 was `9ace5910648b64f8e6e6407727838862f81c421037b596b27ed2a93a732f0c08`.

| Evidence | SHA-256 |
| --- | --- |
| Build log: `build/native-evidence/L28/release-ui-bft-oct7-02/build-for-testing.log` | `0dfa2528d8fe19df48d54e4edffb68dd6cdcb54541d5abce970ade4194b64a5d` |
| Release app executable | `9df40359e8fbf867b142888acfed527c9f5256be165801415a627075b8c140c6` |
| Release UI test executable | `0070436d15dbcb3e342aaf5035954251c59267b0e8b3364ebbf39cf6d4a44054` |
| `.xctestrun` file | `3e38e9a5108434e55124aebb363230b8d067246bf4a2b5f71df29c57811af1e9` |

Products are in `build/native-evidence/L28/release-ui-bft-oct7-02/DerivedData/Build/Products/Release-iphonesimulator/`. The runner can execute the method from the saved `.xctestrun` or repeat the exact command. Runtime result is still pending.

## Existing runtime coverage for R14 and R17

R14 requires Today daily readings, Rosary guide, and Sunday journeys with Reduce Motion off and on. Existing journeys are `AllRouteCaptureUITests.testL25Route10DailyReadings`, `testL25Route23RosaryGuide`, and `testL25Route11SundayPreparation`. The capture records `L25_REDUCE_MOTION` and a runner readback. These tests do not set the system Reduce Motion preference. The runner must set the preference and verify it in Settings and in the runner readback before treating either profile as evidence. The plan marks that mechanism as unproven (`docs/native/reviews/L25-paired-capture-run-plan.md`, G6). Do not count a capture as a Reduce Motion check until that setup is proven.

The existing UI tests that map to R17's ten TabView checks are:

| R17 check | Existing runnable coverage | Remaining evidence |
| --- | --- | --- |
| 1. Tab identifiers and selection | `NativeSmokeUITests.testPrimaryTabsAndSharedReaderAppearance` | Run and record all five labels, frames, and selection. |
| 2. Re-tap and selection echo | No focused test found | Run the review steps and record `selectFromTabBar` logs. |
| 3. Deep links and notification routes | `NativeSmokeUITests.testColdAndRepeatedURLsAndDurableReadingSize`, `testSameProcessRepeatedReadyURLs`, `ContentFlowUITests.testStep7ExternalURLFallbacksMatchSource`; Release media fallback has `MediaNotificationUITests.testReleaseUnapprovedMediaUsesExternalFallback` | The review also requires Daily and Rosary notification-response routes from multiple starting tabs. Check these separately; the listed tests do not prove all of them. |
| 4. Minimize behavior | No focused test found | Exercise minimize, expand, tab selection, and the `-JohnTabBarMinimize never` comparison. |
| 5. Bottom controls | `NativeSmokeUITests.testReaderAnchorReflowRestartAndLowerControls`, `testWorksReaderFooter`, `testScriptureCardExportsPNG`, `LectioTimerUITests.testPrayerHomeLectioTimerStartsDecreasesAndEnds`, `NativeSmokeUITests.testSavedUndoGeometryProbe`, `testSearchResultsAndSavedFilters` | Review asks for full and minimized bar geometry. Run the applicable journeys in both states. |
| 6. Reader mask | `ReaderParityUITests.testBaselineNavigationControlsReconnaissance`; `NativeSmokeUITests.testReaderAnchorReflowRestartAndLowerControls` | Capture the accepted full-bar `end-text` and `end-footer` states. |
| 7. Reader request lifecycle | `NativeSmokeUITests.testColdAndRepeatedURLsAndDurableReadingSize`, `testSameProcessRepeatedReadyURLs`, `ContentFlowUITests.testStep7VerseMomentControlsGuideShareCardAndContext` | Confirm cold `nrsv://read`, Today, and Saved request paths open the expected passage once. |
| 8. Tab state | `NativeSmokeUITests.testPrimaryTabsAndSharedReaderAppearance` | Confirm Today scroll retention and a new bookmark in Saved. |
| 9. iPad | `ScriptureCardUITests.testLongCardSharePresentationOnIPadWhereSupported` tests iPad share support, not TabView layout | Capture Today, Read, and Settings on the assigned iPad; record the accepted top bar and no sidebar. |
| 10. Accessibility | `NativeSmokeUITests.testReaderAppearanceAccessibilityValues` covers Reader appearance values, not TabView VoiceOver or Large Content Viewer | Inspect five tab labels and selected states with VoiceOver, then test the Large Content Viewer at the largest text size. |

R14 and R17 definitions are in `docs/native/reviews/UI-polish-batches-review.md` and `docs/native/reviews/Liquid-glass-tabview-review.md`. This inventory adds no tests. It identifies runnable methods and the checks that still need separate evidence.
