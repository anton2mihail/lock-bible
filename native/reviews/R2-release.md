# R2 release: TestFlight upload

Result: pass. "Uploaded John Update", "EXPORT SUCCEEDED".

- Branch: codex/enhance-batch1, fast-forward merged to main.
- Version: 2.0.0, build 21. Output: build/native-release/2.0.0-21/
- Scheme: John Update, Release. Team QZ44N522NQ.
- Regression: all UITest classes pass. NativeSmoke, ContentFlow and ReaderParity ran in chunks.
- ReleasePerformanceUITests did not run. It needs the L26 Release bundle ID setting.
- Fixes: saved-undo-button identifier (SavedView), Debug builds hide tips unless -JohnShowTips (JohnTips).
- Open item: App Store Connect still processes the build.
