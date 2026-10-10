# R3 release: 2.0.0 (22)

- Branch codex/enhance-batch2 merged into main with `--ff-only`.
- Upload: `scripts/native/release-testflight.sh 2.0.0 22` printed "Uploaded John Update" and "EXPORT SUCCEEDED".
- JohnCore: `xcrun swift test` passed (20 tests).
- UI tests: all 24 classes in native/John/SimulatorSupport ran alone on simulator QA-R3-iPhone17Pro. 23 passed.
  The simulator was erased before and after SearchNoteUITests.
- ReleasePerformanceUITests (3 L26 tests) failed. They need L26_* env values for a task-only Release build (see ReleasePerformanceUITests-README.md). They did not run in the L26 setup. The failure is not caused by batch 2.
- Data safety: main build 21 (Development scheme) created a bookmark, a highlight, and a note on John 1:1. The branch build installed over it. Saved tab still showed all three.
