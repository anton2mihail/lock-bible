# John UI test runbook

Simulator: `1BA50F09-ECBB-4811-A5B2-D4B591206970`. Build flags: `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`.

## Run

    scripts/native/run-tests.sh NativeSmokeUITests
    scripts/native/run-tests.sh --xxxl NativeSmokeUITests/testReaderChapterGridGoToAndAaReachableAtSystemXXXL

Run `NativeSmokeUITests` in chunks of about 7 tests. One long run can time out.

## Test isolation

- Pass `-JohnResetNativeState` at the first launch. In a DEBUG build the app then deletes the native state file. The test starts with default settings, no Reader location, no Works position, and no novena progress.
- Do not pass it again after `app.terminate()`. Remove it from `app.launchArguments` before the relaunch.
- Saved-library tests build their own rows with `resetSavedLibrary` in `NativeSmokeUITests`. They do not need a seed.
- `testSameProcessRepeatedReadyURLs` sends its own URLs with `app.open`. No host script is needed.

## Tests that skip without environment values

| Test | Needs | How to supply |
| --- | --- | --- |
| `testReaderChapterGridGoToAndAaReachableAtSystemXXXL` | Simulator at XXXL text size and `L25_CONTENT_SIZE` | `run-tests.sh --xxxl` |
| `testSameIDReleasePreferenceSurvivesFreshProcess` | Release build `com.nrsv.verse` installed | Install it. `run-tests.sh` sets `JOHN_RELEASE_BUNDLE_INSTALLED=1` |
| `PositiveNoticeUITests` (L22 notice) | `L22_NOTICE_SEED_ID`, `L22_NOTICE_BUNDLE_ID`, `L22_NOTICE_DENY_SEED_ID` | Set `TEST_RUNNER_<name>` before the script. Needs a task-only seed. |
| `SystemAccessibilityUITests` | `JOHN_SYSTEM_ACCESSIBILITY_SETTING`, `_VALUE`, `_PHASE` | Set `TEST_RUNNER_<name>` |
| `ReaderParityUITests.testBaselineNavigationControlsReconnaissance` | `READER_PARITY_BASELINE_BUNDLE_ID` | Install the baseline app and set `TEST_RUNNER_<name>` |
