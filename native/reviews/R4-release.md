# R4 release: 2.0.0 (23)

- Branch codex/enhance-batch3 merged to main with --ff-only.
- Upload: "Uploaded John Update", EXPORT SUCCEEDED (scripts/native/release-testflight.sh 2.0.0 23).
- JohnCore `swift test`: 24 tests passed.
- UITests: each class run alone on QA-R4-iPhone17Pro. IPadB3d on QA-R4-iPad. All passed or skipped, except:
  - WorksSettings/testSettingsSaveEditionsRestoreAndReaderAppearanceAgree and ReaderParity/testBibleRepositoryCasesAcrossEditions failed 2 times each. Cause: the test drag started on the new read-aloud slider. Fix: drag starts at the left edge (UITest helper change). Both passed after the fix (simulator erased before each run).
  - ReleasePerformance (3 tests) did not run: needs an explicit Release bundle ID configuration. Not caused by batch 3. Not run.
  - Skips are test-controlled (task-only seeds, Release bundle).
- No flaky test found.
- Data safety (Development bundle): main build installed, seeded 1 bookmark, 1 highlight, 1 note in Documents/SQLite/user-library.db. Branch build installed over it. Counts stayed 1/1/1. Note text kept. App launched without error. The reading progress file was absent after install. It is created on first read. ReadingProgressB3cUITests passed and covers the creation.
- Simulators QA-R4-iPhone17Pro and QA-R4-iPad deleted.
