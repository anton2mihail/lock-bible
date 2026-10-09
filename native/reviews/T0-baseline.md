# T0 baseline

- Device: QA-Own-iPhone17Pro, iOS 26.5, UDID `1BA50F09-ECBB-4811-A5B2-D4B591206970`
- Build: PASS for scheme "John Development" (app + JohnWidget), Swift 6.0, derivedData `/tmp/qa-dd2`.
- First build without `ONLY_ACTIVE_ARCH=YES` FAILED: JohnWidget, x86_64, "unable to resolve module dependency: 'JohnCore'". Command: `xcodebuild build-for-testing ... ONLY_ACTIVE_ARCH=YES` passes.
- Test run: INCOMPLETE. `xcodebuild test-without-building -only-testing:JohnUITests` hit the 3000 s limit and I stopped it.
  Stuck in ReaderParityUITests.testBibleRepositoryCasesAcrossEditions (689 s, failed). Later classes did not run.
- Logs: `/tmp/qa-build.log`, `/tmp/qa-build2.log`, `/tmp/qa-test.log`

## Per-test result (tests that finished)

```
CalendarBoundaryUITests testJoelAndEstherCitationsKeepOriginalIdentityAndMapChapter passed (52.099 seconds).
CalendarBoundaryUITests testOutOfCoverageDateShowsOfflineMissingReadings passed (14.222 seconds).
CalendarBoundaryUITests testPrayerChoiceOnBothSidesOfLocalSeventeenHundred passed (17.131 seconds).
ContentFlowUITests testL14PersistentContentSurvivesOneRelaunch failed (41.493 seconds).
ContentFlowUITests testL15DatedRoutesGuidesAndLectioTimer failed (72.522 seconds).
ContentFlowUITests testL15PrayerHomeRosarySetsSevenSorrowsAndLectioTimer passed (82.080 seconds).
ContentFlowUITests testL17RosaryGuideBackCompletionAndReset passed (242.042 seconds).
ContentFlowUITests testL18ConfessionNotesClearOnBackgroundAndFinish failed (78.258 seconds).
ContentFlowUITests testL25PadrePioCompletedNovenaCancelAndReset failed (109.215 seconds).
ContentFlowUITests testL25PadrePioNovenaProgressAndResetConfirmation passed (456.931 seconds).
LectioTimerUITests testPrayerHomeLectioTimerStartsDecreasesAndEnds passed (35.871 seconds).
MediaNotificationUITests testDebugMediaModeEpisodeAndRouteReturnAfterActivation passed (65.942 seconds).
MediaNotificationUITests testNotificationScreensShowDisabledSaveFeedback passed (64.596 seconds).
NativeSmokeUITests testColdAndRepeatedURLsAndDurableReadingSize passed (80.950 seconds).
NativeSmokeUITests testPrimaryTabsAndSharedReaderAppearance failed (47.367 seconds).
NativeSmokeUITests testPsalmTwoLoadedVerseGeometryDiagnostic passed (21.980 seconds).
NativeSmokeUITests testPsalmTwoVerseTwelveGeometryDiagnostic passed (27.011 seconds).
NativeSmokeUITests testReaderAnchorReflowRestartAndLowerControls passed (76.811 seconds).
NativeSmokeUITests testReaderAppearanceAccessibilityValues passed (23.192 seconds).
NativeSmokeUITests testReaderChapterGridGoToAndAaReachableAtSystemXXXL failed (61.780 seconds).
NativeSmokeUITests testReaderRealVisibleVerseTapRange failed (41.205 seconds).
NativeSmokeUITests testReaderSelectionBookmarkAndAllHighlightColors passed (37.920 seconds).
NativeSmokeUITests testReaderSourceNavigationRangeAndVerseLayout failed (74.984 seconds).
NativeSmokeUITests testReaderTopSafeAreaAndSmallScrollProbe passed (17.179 seconds).
NativeSmokeUITests testReaderVerseWordPointDiagnostic passed (38.802 seconds).
NativeSmokeUITests testSameIDReleasePreferenceSurvivesFreshProcess failed (0.073 seconds).
NativeSmokeUITests testSameProcessRepeatedReadyURLs failed (60.653 seconds).
NativeSmokeUITests testSavedUndoGeometryProbe failed (20.694 seconds).
NativeSmokeUITests testScriptureCardExportsPNG passed (13.860 seconds).
NativeSmokeUITests testSearchResultsAndSavedFilters passed (18.033 seconds).
NativeSmokeUITests testValidLibrarySavedFiltersNoteEditDeleteAndUndo failed (51.865 seconds).
NativeSmokeUITests testVerseMomentReaderAndWorksFooter passed (14.874 seconds).
NativeSmokeUITests testWorksReaderFooter passed (15.918 seconds).
PositiveNoticeUITests testAuthorizedCalendarAndRosaryNoticeSettings failed (0.043 seconds).
PositiveNoticeUITests testFreshUndeterminedCalendarPermissionDenialKeepsSettingOff failed (0.040 seconds).
PositiveNoticeUITests testSimulatedNotificationResponsesRouteAcrossTabs failed (0.040 seconds).
ReaderParityUITests testBaselineNavigationControlsReconnaissance failed (0.040 seconds).
ReaderParityUITests testBibleRepositoryCasesAcrossEditions failed (689.432 seconds).
ReaderParityUITests testGoToExpandsCurrentChapterAndReturnsThroughVisibleControls passed (127.396 seconds).
```

## Failure messages (file:line)

```
ContentFlowUITests.swift:114: error: ContentFlowUITests testL15DatedRoutesGuidesAndLectioTimer] : XCTAssertTrue failed - The parent screen must appear after Back
ContentFlowUITests.swift:266: error: ContentFlowUITests testL25PadrePioCompletedNovenaCancelAndReset] : Failed to get matching snapshot: No matches found for Elements matching predicate '"Day 9, complete" IN identifiers' from input {(
ContentFlowUITests.swift:357: error: ContentFlowUITests testL18ConfessionNotesClearOnBackgroundAndFinish] : XCTAssertTrue failed
ContentFlowUITests.swift:865: error: ContentFlowUITests testL14PersistentContentSurvivesOneRelaunch] : XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Target and keyboard did not move after the gesture
NativeSmokeUITests.swift:108: error: NativeSmokeUITests testSavedUndoGeometryProbe] : XCTAssertEqual failed: ("1") is not equal to ("2") - Expected 2 Saved rows, found 1
NativeSmokeUITests.swift:1112: error: NativeSmokeUITests testPrimaryTabsAndSharedReaderAppearance] : XCTAssertTrue failed - Missing root: page-title-pray
NativeSmokeUITests.swift:1112: error: NativeSmokeUITests testPrimaryTabsAndSharedReaderAppearance] : XCTAssertTrue failed - Missing root: page-title-saved
NativeSmokeUITests.swift:1154: error: NativeSmokeUITests testSameIDReleasePreferenceSurvivesFreshProcess] : Failed to launch com.nrsv.verse: The request to open "com.nrsv.verse" failed. (Underlying Error: The operation couldn’t be completed. Application info provider (FBSApplicationLibrary) returned
NativeSmokeUITests.swift:1187: error: NativeSmokeUITests testSameProcessRepeatedReadyURLs] : XCTAssertTrue failed - Host must send the first URL to the running app
NativeSmokeUITests.swift:1189: error: NativeSmokeUITests testSameProcessRepeatedReadyURLs] : XCTAssertTrue failed
NativeSmokeUITests.swift:1190: error: NativeSmokeUITests testSameProcessRepeatedReadyURLs] : Failed to get matching snapshot: No matches found for Elements matching predicate '"reader-title" IN identifiers' from input {(
NativeSmokeUITests.swift:136: error: NativeSmokeUITests testValidLibrarySavedFiltersNoteEditDeleteAndUndo] : XCTAssertEqual failed: ("1") is not equal to ("4") - Expected 4 Saved rows, found 1
NativeSmokeUITests.swift:142: error: NativeSmokeUITests testValidLibrarySavedFiltersNoteEditDeleteAndUndo] : XCTAssertEqual failed: ("0") is not equal to ("1") - Expected 1 Saved rows, found 0
NativeSmokeUITests.swift:142: error: NativeSmokeUITests testValidLibrarySavedFiltersNoteEditDeleteAndUndo] : XCTAssertEqual failed: ("1") is not equal to ("2") - Expected 2 Saved rows, found 1
NativeSmokeUITests.swift:146: error: NativeSmokeUITests testValidLibrarySavedFiltersNoteEditDeleteAndUndo] : Failed to get matching snapshot: No matches found for first query match sequence: `Descendants matching type Button` -> `Elements matching predicate 'identifier BEGINSWITH "saved-row-"'`, giv
NativeSmokeUITests.swift:403: error: NativeSmokeUITests testReaderSourceNavigationRangeAndVerseLayout] : XCTAssertTrue failed
NativeSmokeUITests.swift:405: error: NativeSmokeUITests testReaderSourceNavigationRangeAndVerseLayout] : Failed to get matching snapshot: No matches found for Elements matching predicate '"reader-chapter-149" IN identifiers' from input {(
NativeSmokeUITests.swift:473: error: NativeSmokeUITests testReaderRealVisibleVerseTapRange] : Failed to get matching snapshot: No matches found for Elements matching predicate '"reader-selection-summary" IN identifiers' from input {(
NativeSmokeUITests.swift:680: error: NativeSmokeUITests testReaderChapterGridGoToAndAaReachableAtSystemXXXL] : XCTAssertEqual failed: ("nil") is not equal to ("Optional("accessibility-extra-extra-extra-large")")
NativeSmokeUITests.swift:680: error: NativeSmokeUITests testReaderChapterGridGoToAndAaReachableAtSystemXXXL] : XCTAssertEqual failed: ("UIContentSizeCategory(_rawValue: UICTContentSizeCategoryL)") is not equal to ("UIContentSizeCategory(_rawValue: UICTContentSizeCategoryAccessibilityXXXL)") - The UI
PositiveNoticeUITests.swift:470: error: PositiveNoticeUITests testAuthorizedCalendarAndRosaryNoticeSettings] : failed - Main must provide explicit task-only environment value L22_NOTICE_SEED_ID
PositiveNoticeUITests.swift:470: error: PositiveNoticeUITests testFreshUndeterminedCalendarPermissionDenialKeepsSettingOff] : failed - Main must provide explicit task-only environment value L22_NOTICE_DENY_SEED_ID
PositiveNoticeUITests.swift:470: error: PositiveNoticeUITests testSimulatedNotificationResponsesRouteAcrossTabs] : failed - Main must provide explicit task-only environment value L22_NOTICE_INITIAL_AUTHORIZATION
ReaderParityUITests.swift:13: error: ReaderParityUITests testBaselineNavigationControlsReconnaissance] : failed - Reconnaissance requires an explicit baseline bundle ID
ReaderParityUITests.swift:308: error: ReaderParityUITests testBibleRepositoryCasesAcrossEditions] : XCTAssertTrue failed
```

## Notes
- Three PositiveNotice tests and ReaderParity reconnaissance fail at once (0.04 s). They need env values or a baseline bundle ID. These are setup failures.

---

# T0b: per-class results (added)

Simulator `1BA50F09-ECBB-4811-A5B2-D4B591206970` only. Each new class ran alone, `timeout 600`, `-only-testing:JohnUITests/<Class>`. Before this run I had to re-create `build/native-evidence/L03/staged/run-10/{App,Widget}` from `/tmp/qa-dd2` build products. The folder was missing and the build failed on `CpResource Rotation`. No app source changed.
Classes before ReaderRegression: results come from the first run above (not re-run alone).

| Class | Result |
|---|---|
| CalendarBoundary | 3/3 pass (first run) |
| ContentFlow | 4 pass, 4 fail (first run) |
| LectioTimer | 1/1 pass |
| MediaNotification | 2 pass (first run; 3 Step7 tests not seen) |
| NativeSmoke | many pass, 9 fail (first run) |
| PositiveNotice | setup-blocked: L22_NOTICE_* env |
| ReaderParity | Reconnaissance setup-blocked (baseline bundle ID); Repository skipped by order; GoTo pass |
| AllRouteCapture | 38/38 skipped (needs capture env) – setup-blocked |
| ReaderRegression | 6 pass, 1 fail (`testSavedAnchor50Offset85SurvivesLargeReflowAndRestart`, line 199, "target did not move") |
| ReaderSelectionActions | 1 pass, 2 fail (`testRemoveExistingVerseBookmark` line 18 "Expected committed accessibility value: Selected"; `testClearMixedRangeHighlights` line 37 "Different saved colors must expose Remove highlight") |
| ReleasePerformance | 3/3 setup-blocked: "Missing required L26 configuration: explicit task-only Release bundle ID" |
| ScriptureCard | 1 pass, 4 skipped (iPad / step7 gating) |
| SearchNote | 3 pass, 1 fail (`testSearchScopesEditionAndLatinText` line 55 "The parent screen must appear after Back") |
| StoreScreenshot | 5/5 skipped – setup-blocked |
| SystemAccessibility | setup-blocked: needs JOHN_SYSTEM_ACCESSIBILITY_{SETTING,VALUE,PHASE} |
| TabViewRegression | 3 pass, 1 skipped (iPad), 1 fail (`testReaderTabMinimizesExpandsAndKeepsSelectionAboveBar` line 61: no `tab-today` button) |
| WidgetHomeScreen | 3/3 skipped – setup-blocked |
| WorksSettings | 4 pass, 1 fail (`testWorksContentsFooterStyleAnchorAndResume` line 119 "Use a fresh task-only seed with no saved position") |
| ButtonDrift (new, A0) | pass (investigation test, see A0-drift.md) |

## Root-cause guesses for failing tests

| Test | Guess | Reason |
|---|---|---|
| WorksSettings…FooterStyleAnchorAndResume | env | Test asks for a fresh seed. Simulator keeps saved position. Uninstall app first. |
| SystemAccessibility, ReleasePerformance, PositiveNotice, ReaderParity recon, AllRoute/Store/Widget skips | env | Missing env or bundle ID. |
| NativeSmoke…SameIDReleasePreferenceSurvivesFreshProcess | env | `com.nrsv.verse` is not installed. |
| NativeSmoke…PrimaryTabsAndSharedReaderAppearance ("Missing root: page-title-pray / -saved") | test bug | Tab titles probably changed to nav titles or ids moved. Test needs new ids. |
| TabViewRegression…ReaderTabMinimizes… (`tab-today` not found) | test bug | Tab bar is minimized in Read tab. Test looks up the Today button by id. Use label fallback like other helpers. |
| SearchNote / ContentFlow L15 ("parent screen must appear after Back") | test bug or app bug | Back-button lookup after navigation. Likely the nav title changed (uncommitted Search/Rosary edits). Needs one manual look. |
| NativeSmoke Saved rows count (1 vs 2/4), SavedUndoGeometry | app bug (likely) | `SavedView.swift` has uncommitted changes. Rows seed found 1 row. Could also be env seed. |
| ReaderRegression Anchor50, ContentFlow L14, ReaderSelectionActions bookmark | app bug (likely) | "Target and keyboard did not move" / selected value never committed. Uncommitted `ReaderView`/`ReaderScreenModel` changes. |
| ReaderSelectionActions ClearMixedRange | app bug (likely) | "Remove highlight" action missing for mixed colors. |
| ContentFlow L18, L25 PadrePio "Day 9, complete" | test bug or app bug | Unclear. Needs manual check. |
| ReaderParity BibleRepositoryCases | env/perf | 689 s. Skipped by request. |

These are guesses. I did not open each failure screenshot.
