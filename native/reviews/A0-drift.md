# A0: buttons "drifting in"

## Result
The UITest could NOT see drift. The root cause is not proven. I have source-based suspects only.

## What I did
New test: `native/John/SimulatorSupport/ButtonDriftUITests.swift` (added to the project file). Run: `-only-testing:JohnUITests/ButtonDriftUITests` on the own simulator. It passed.
Screens: Today (cold launch), Read, Saved, Pray, Settings, Rosary, Novena, Lectio.

Two attempts:
1. Button frames from `app.snapshot()` every 0.05 s. First sample came 2.5–4.4 s after the tap. Zero buttons moved.
2. Rapid `XCUIScreen.screenshot()` with the tap on a background queue. First screenshot still came 2.6–6 s after the tap. Zero changes.

Why: XCUITest waits for the app to be idle before every tap, snapshot, and screenshot. Any animation shorter than the idle wait is finished before the first sample. So "0 drift" here means "not measurable", not "no drift". Note: a tap that needs 2.5–4 s to go idle shows the app stays busy after a tab change. That is a hint of work after appear (loading).

## Needed to measure it
Record video: `xcrun simctl io 1BA50F09-ECBB-4811-A5B2-D4B591206970 recordVideo out.mov` while a test taps. Then extract frames with `ffmpeg`. Or add a debug-only frame logger in the app (needs an app source change, so not done).

## Likely causes (from source, not measured)
No `.transition`, `withAnimation`, or entrance animation exists in Today, Prayer Home, Rosary Home, Settings, or tab setup. So the drift is not an explicit entrance animation. Suspects, most likely first:
1. **Content load after first frame.** `.task { await loadCatalog() }` in `PrayerHomeView.swift:121` and `RosaryHomeView.swift:128`, `.task { await loadInformation() }` in `FullSettingsView.swift:125`, `.task(id: filter)` in `SavedView.swift:80`. The view first shows empty or placeholder content. Then state changes and the layout moves. Under an enclosing animation transaction (tab switch, navigation push), buttons then slide to their final place.
2. **Tab bar / safe area change.** `JohnApp.swift:141` sets `.tabBarMinimizeBehavior` depending on the selected tab (`.read` only). Switching tabs changes the bottom inset, so bottom buttons resize or move.
3. **Startup state.** `JohnApp.swift` shows `ProgressView(runtime.startupStatus)` until `runtime.start()` ends, then swaps the root. Today buttons appear after that swap.
4. **System navigation transition** for Rosary/Novena/Lectio (push). This is allowed by the project rule.
5. **Reduce Motion:** only `NumericChangeModifier` and `SavedView` check it. Others have no custom animation, so Reduce Motion is not the cause.

## Next step
Record video of the 8 screens on the own simulator, then check frames. If cause 1 is true, fix by giving the first frame its final size (stable placeholder) or by disabling animation for the load (`Transaction.disablesAnimations`).
