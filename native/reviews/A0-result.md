# A0 result: buttons "drifting in"

## Evidence
- Video before: `A0-video/before/run.mov` (simulator 1BA50F09, driven by `ButtonDriftUITests`). Motion list: `before/motion.txt`. Frame sheets: `before/sheet_*.png`.
- Video after: `A0-video/after/run.mov`, `after/motion.txt`, `after/*.png`.
- Tool: `A0-video/analyze.py` (ffmpeg at 30 fps, frame difference).

## Causes confirmed (before video)
1. Saved tab: a "Loading saved items" spinner showed first. The list cross-faded in after it.
2. Rosary guide: a spinner showed first. Content, and the "+" button in the Suggested card, came in later.
3. Pray home, Rosary home, Novena: spinner first, then content after an async catalog load. Novena set `catalog = nil` on each open, so a spinner showed each time.

## Fix
- `App/Runtime.swift`: read the devotional catalog, Rosary home data, Rosary sessions, and art credits once in `start()`. Screens read them in the first frame.
- `Features/Guides/RosaryGuideView.swift`, `RosaryHomeView.swift`, `Prayers/PrayerHomeView.swift`, `Guides/NovenaView.swift`: use the warm data first. A blank placeholder of fixed height replaces the spinner. Novena no longer clears the catalog. The three Rosary guide types are no longer `private` (the runtime stores them).
- `Features/Secondary/SavedView.swift`: blank placeholder replaces the spinner. Animation is off for load and list-count changes. Undo bar animation is kept.

## Result (after video)
Rosary, Pray, Novena, and Saved show all content and buttons in their first frame. The remaining motion is the system tab cross-fade (about 0.15 s) and the system push transition. Both are allowed.

## Tests (each class alone, 600 s limit)
- `LectioTimerUITests`: pass.
- `ContentFlowUITests`: 4 fail. `NativeSmokeUITests`: 6 fail. The baseline `reviews/T0-baseline.md` shows the same failures, except below.
- `NativeSmokeUITests.testReaderAppearanceAccessibilityValues`: passed in baseline, fails now (twice). It tests Reader appearance. No file I changed touches it. Cause not found.

## Remaining issues
- Saved first visit after a cold start still shows an empty area until the list loads. Data is async.
- Settings information section (`loadInformation`) was not changed. It sits below the fold. Not shown in video as drift.
- Today cold-launch root swap (`ProgressView(startupStatus)` in `JohnApp.swift`) is not changed.
- Reader appearance test regression needs a check.
