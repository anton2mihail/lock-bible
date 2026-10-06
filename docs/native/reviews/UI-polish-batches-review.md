# UI polish batches review

Date: 6 October 2026.
Reviewer: Sol (architecture, review, and acceptance).
Status: **Accepted with fixes.** The approved audit items are implemented as the owner decided. Fix 1 and fix 2 must be in place before the regression run. The evidence in "Re-capture list" must be taken again on the final build.

## Reviewed boundary

`git diff 830ef84..3c9e330 -- native/John` (53 files) and these commits:

| Commits | Content |
| --- | --- |
| `56d6a17`, `e3ec800` | System TabView; re-tap echo guard and test adaptation (`Liquid-glass-tabview-review.md`) |
| `170b12e` merge (group A) | Dynamic Type grids and chips, Go to Cancel label, Saved row refresh, swipe and context actions, undo animation, note-editor dismiss guard, haptics, Lectio keep-awake, numeric digit transitions, Works contents and commentary rows, VoiceOver highlight values and rotors, dead-code removal (`TodayView`, `AppRoute.passage`). A13 ("Bookmarked" value) is skipped. |
| `2ec3733` merge (B1, B7–B10) | System glass back button (in-page back rows removed), `ContentUnavailableView` states, novena reset confirmation, Rosary bead haptic, Today zoom transitions. B11 (Lectio end haptic) removed at `55eeddd` by owner decision. |
| `1ac0bdc`, `2aa64b8`, `481c7ed`, `62248ed`, `a9345c9` | B2 Aa sheet, B3 floating selection panel, B4 accessibility-only summary, B5 top fade mask, B6 Go to sheet |

Sol did not build, run, or use a simulator. The latest build record is `build/native-evidence/L25/build-record-170b12e.txt`: Debug build-for-testing at `170b12e`, which is before the Reader commits. Sol type-checked all `SimulatorSupport` files at `3c9e330` with Swift 6 and `-DDEBUG`: exit 0. The only warning is the existing one at `WorksSettingsUITests.swift:184`.

## Checks

| Area | Result |
| --- | --- |
| Echo guard (`e3ec800`) | Correct. `select` marks the tab. `receive(.daily)` and `receive(.rosary)` mark the tab again after the path change. A same-tab write within 1 s is logged as `ignoredEcho` and does not pop. A different-tab write clears the mark. The DEBUG `JOHN_TABBAR_WRITE` log is present. This closes fix 1 of `Liquid-glass-tabview-review.md` in source. |
| Swift 6 | Nothing unsound found in source: the `@Entry` environment value, the `ViewModifier`s, the `Equatable` haptic trigger, `@ScaledMetric`, and the main-actor `UIView` rotor closures with `[weak self]`. Code after `170b12e` has no build record. See fix 3. |
| Owned-glyph hit testing with the floating panel | Intact. The panel takes all touches inside its own rounded shape (`contentShape(panelShape)`). It is a bottom safe-area inset, so the Scripture view underneath keeps its own hit test everywhere else. The accessibility-only summary uses `.allowsHitTesting(false)`. The test viewports in `ScriptureCardUITests`, `ReaderParityUITests`, and `NativeSmokeUITests` now end above `reader-selection-panel`. `ReaderSelectionActionsUITests` taps only verses 1 and 2 near the top, so the panel cannot cover them. |
| Hidden summary (B4) | Accepted. `reader-selection-summary` keeps its identifier and exact label. The text is clear, 1 pt high, and adds no layout height. VoiceOver reaches it after the chapter text and before the commentary. The selected verses also carry the `.selected` trait. The old app shows no such line. |
| Reduce Transparency | The panel switches to a solid card with a hairline. The top mask returns to the hard cut at the safe-area line. Sheets use the system fallback. Accepted. |
| Reduce Motion | The Today zoom is off. Numeric digit transitions use `.identity` and no animation. The Saved undo bar follows Reduce Motion (`69b00c2`). Accepted. |
| Dynamic Type | The chapter grids (Reader and Go to) use `@ScaledMetric` cells. Search scopes and Saved filters stack at large sizes. The Aa sheet scrolls. Accepted. Run check R8. |
| Identifiers | All kept: `tab-*`, `reader-back`, `reader-verse-*`, `reader-selection-*`, `reader-appearance-close`, `go-to-cancel`, `search-status`, `search-result-count`, `saved-status`, `saved-empty-state`, `settings-*`. The removed identifiers belong to the removed in-page back rows: `content-back`, `rosary-reminder-back`, and `search-cancel-button`. No test references them any more. |
| Saved-open failure (F2) | Kept. `open(_:)` sets "This passage could not be opened." in `saved-status`. The context menu "Open" and `editNote` use the same path. |
| Notice settings | Only the in-page close and back rows were removed (system back button). The save, permission, and picker code are unchanged. The L22 runtime acceptance stays valid for its binary. |
| Search | The prompt, no-result, and error texts are unchanged inside `ContentUnavailableView` descriptions with the `search-status` identifier. The visible Cancel is removed (system back). The result count has a numeric transition. |
| Lectio keep-awake | `isIdleTimerDisabled` is true only while the silent minute runs and the scene is active. It is reset on disappear. Accepted. |
| Go to sheet (B6) | Cancel and a chapter choice call `dismiss()`. The pushed `AppRoute.goTo` still works. Accepted. Run check R4. |
| Aa sheet (B2) | Title "Text settings" and the Settings choice buttons, as in the old `TextSettingsSheet.tsx:66`. No edition control, as in the old sheet. The audit (owner-approved) asks for background interaction up to the medium detent. **Hazard:** with the sheet open, a tap on a verse selects it behind the sheet. The panel's Share then tries a second sheet from the same view, and SwiftUI does not present it. The old app closes the sheet when the user taps the chapter (`TextSettingsSheet.tsx:55`). See fix 1. |

### Visible changes to record as owner-approved exceptions (Gate E, item E2)

- The system glass back button in place of the in-page back rows.
- `ContentUnavailableView` titles and icons that the old app did not show: "Find a passage", "No results", "Search failed", "Nothing saved", "Could not load Saved".
- The floating glass selection panel.
- The fade under the status bar in place of the hard cut.
- Go to as a sheet.
- Monospaced digits in counters.
- Rosary bead and Reader action haptics.
- The novena reset confirmation.
- Today zoom transitions.
- Saved swipe and context actions.

## Required fixes

1. **Aa sheet and verse taps (`ReaderView.swift`).** Keep the background scroll (owner-approved). While `router.sheet` is not nil, a tap on the chapter text must close the sheet and must not select. In `ScriptureTextView`'s `onTapVerse` path (or an overlay gesture on the scroll content), set `router.sheet = nil` and return before the selection code. This matches the old behavior: a tap on the chapter closes the sheet. It also prevents a second sheet from the selection panel.

2. **System back helper in the tests.** `systemBack(in:)` returns `app.navigationBars.buttons.firstMatch` in `ContentFlowUITests`, `PositiveNoticeUITests`, and the other copies. That can return a trailing bar button, or a button of another navigation bar. Change every copy to this:
   - Use `app.navigationBars.buttons["BackButton"]` when it exists.
   - Otherwise use the left-most hittable button of the front navigation bar.
   - Assert that the expected parent screen appears after each tap.

   Put it in one shared helper per file.

3. **Build and exclusion record at `3c9e330` (or the fix head).** Build Debug (build-for-testing) and Release for the simulator. Record the source and binary hashes. Run `l28_inspect_package.py --stage unsigned --platform simulator` on Release and record C04, C12, C13, C14, and C15. C15 must include `-JohnTabBarMinimize`.

4. **Status-bar fade on short safe areas (B5).** The clear part is 45 % of the top safe area. On the SE 3 (20 pt safe area), the fade then starts at 9 pt, inside the status-bar glyph band. Run check R3 on the SE device and on the iPhone 17 Pro. If faded text shows behind any status-bar glyph, change the mask so the fade covers only a fixed band of at most 12 pt at the bottom of the safe area. Clear everything above that band. On the SE that is 8 pt, so the clear zone is still 12 pt.

## Re-capture list

On the final build, with `-JohnTabBarMinimize never` for every native Debug test, on `37D1870B…` unless stated:

| ID | Evidence | Why |
| --- | --- | --- |
| R1 | All native L25 route and Reader images (all profiles) | Glass tab bar, system back button, the panel, and the fade |
| R2 | ReaderParity `top`, `end-text`, `end-footer` for the nine cases | Top fade and bottom geometry under the glass |
| R3 | Reader top edge at John 1 and after a scroll: light, dark, and Reduce Transparency, on the iPhone 17 Pro and the SE 3 (`5FC2D286…`) | B5 mask (fix 4) |
| R4 | Accepted Go to check (Psalms 23 via the sheet, then Reader Back controls) | B6 sheet |
| R5 | Accepted range check (10 → 10–12 → 8–10 → 8–11, repeat rules), the Psalms 2:1–12 long card, mixed gold and sage clear, the Copy payload, bookmark add and remove | Floating panel over the text |
| R6 | Current Aa capture (Medium, Comfortable, Serif, Paragraphs, then each choice once). Fix 1: a tap on the chapter closes the sheet. | B2. The handoff already asked for a current Aa capture. |
| R7 | Reader anchor `50:85` across Medium → Large and a restart | The shell, the safe areas, and the bottom inset changed |
| R8 | Dynamic Type at the largest accessibility size: Reader chapter grid, Go to grid, Search scopes, Saved filters, the Aa sheet | Group A layout |
| R9 | Search: the three accepted journeys, with the empty, no-result, and error states | `ContentUnavailableView`, system back |
| R10 | Saved: four filters, edit and reopen, delete and Undo, swipe delete, F2 open-failure message | Group A rows, B1 back |
| R11 | Works: Homily 10 contents, page 1 → 2 → 1, lower controls above the bar, commentary rows | Contents sheet, rows, back button |
| R12 | Lectio timer 60 → 59 and manual stop; the idle timer is reset after leaving (log or observation) | Keep-awake and digit transition |
| R13 | Rosary Joyful completion, back, and reset; novena (Padre Pio) progress, with the reset confirmation | B8, B9 |
| R14 | Today → daily readings, Rosary guide, and Sunday, with Reduce Motion off and on | B7 zoom |
| R15 | One PositiveNotice authorized method (smoke only) | Back control change in the helper |
| R16 | VoiceOver tree export for the Reader: verse values for highlights, the Headings and Highlights rotors, the summary after the text | Group A accessibility, B4 |
| R17 | The Tab checks 1–10 from `Liquid-glass-tabview-review.md` | Shell |

Library data, search ranking and results, Reader text and metrics, Works text, notice scheduling, L27 import, and widget data are not changed by these batches. They do not need new data evidence.
