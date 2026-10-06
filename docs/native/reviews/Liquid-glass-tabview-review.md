# Liquid Glass TabView review

Date: 6 October 2026.
Reviewer: Sol (architecture, review, and acceptance).
Status: **Accepted with fixes.** The design follows the owner decision. Simulator acceptance is open. Required fix 1 must be in the build before any deep-link or notification-tap evidence.

## Reviewed boundary

Commit `56d6a17` ("Use the system Liquid Glass TabView for the five root tabs"): `JohnApp.swift`, `AppRouter.swift`, `FeatherIcon.swift`, `Theme.swift`, `ReaderView.swift`, `DestinationView.swift`, the generator and project, and the ADR 0006 amendment. `FlatTabBar.swift` is removed. Context: `docs/native/reviews/UI-polish-ios26-audit.md` (owner approvals: group A all; B1–B11, not B12).

Sol did not build, run, or use a simulator. The commit has no build record.

## Design checks

| Item | Result |
| --- | --- |
| Owner decisions | System `TabView` with five iOS 26 `Tab` values, system glass back button, no iPad sidebar (`.tabViewStyle(.tabBarOnly)`). The ADR amendment records them and lists the invalidated parity checks. Accepted. |
| Selection ownership | `selectedTab` is `private(set)`. `select(_:)` is the only writer. All former writers (`openReader`, `openReaderChapterList`, `receive`, `DestinationView.openBibleRoot`) use it. No other writer remains. |
| Per-tab stacks | One `NavigationStack` per `Tab`, bound to `router.path(for:)` / `setPath(_:for:)`. Tab content now stays alive between tab changes. This is closer to the old Expo tabs. `SavedView` still reloads on Saved entry (`onChange(of: router.selectedTab)`). |
| Reader lifecycle | `readEntryID` changes on each move into Read, and the Read root uses `.id(readEntryID)`. Each Read entry creates a new `ReaderView`, as before. The commit `9d3753c` request path stays valid. If the old (hidden) Reader also sees the request, `ReaderScreenModel.receive` drops a second delivery through `handledRequestID`. |
| External request while Read is not visible | `openReader…` calls `select(.read)`. That gives a new `readEntryID`, and the new `ReaderView` `.task` reads `latestPassageRequest` / `latestChapterRequest`. When Read is already visible, `select` does nothing and the live `ReaderView` gets the change, as before. Correct in source. Simulator check 3 must prove it. |
| Swift 6 isolation | `AppRouter` is `@MainActor`. The tab binding closures run on the main actor. `tabImages` and `readerMinimizeBehavior` are static stored properties of a SwiftUI `View`, so they are main-actor isolated. `AppTab` is `Sendable`. Sol found no isolation fault. The Debug and Release build records must confirm it (fix 4). |
| Release exclusion | `-JohnTabBarMinimize` is read only inside `#if DEBUG`. Add it to the C15 list (fix 4). |
| Icons | Feather glyphs drawn as 25 pt template images, with an SF Symbol fallback. The tint is the brand tint. The system draws the unselected color (the `tintInactive` parity value is gone, by owner decision). |
| iPad | `.tabBarOnly` puts the tab bar at the top of the window on iPadOS 26. The ADR says so. This is a visible difference from the old bottom bar. Record it as an owner-accepted exception in E2. |

### Re-tap pop risk

`TabView(selection:)` uses `Binding(get: { router.selectedTab }, set: { router.selectFromTabBar($0) })`. For a user re-tap, SwiftUI calls `set` with the same value. `selectFromTabBar` then clears that tab's path.

The risk is real in source. The code does not tell a user re-tap from a binding write that SwiftUI makes for its own reasons. Examples: a write-back after a programmatic selection change, after the first layout, or when a minimized bar expands. The deep-link code changes the path right after `select`:

- `receive(.daily)`: `select(.today)`, then `paths[.today].append(.daily(key))`.
- `receive(.rosary)`: `select(.pray)`, then `paths[.pray] = [.companion(.rosaryHome)]`.

The notification delegate routes Daily and Rosary taps the same way. If SwiftUI writes the new selection back through `set` after the append, `selectFromTabBar` sees `tab == selectedTab` and sets `paths[tab] = []`. The Daily or Rosary page then disappears without a message.

Sol cannot prove from source that SwiftUI on iOS 26.5 makes that write. The pop has no guard, so a guard is required (fix 1). The simulator checks then prove both cases.

### Bottom controls and the floating bar

The scroll content now runs under the glass bar. Fixed bottom content (Works lower controls, the Reader selection toolbar, Scripture card buttons, Lectio controls) gets the tab bar safe area inset from SwiftUI. It should stay above the bar. In the Read tab, the bar minimizes on scroll, so the bottom inset changes size while the user reads. A control that is placed against the bottom safe area moves when that happens. The Reader mask now goes into the bottom safe area. Only the text should pass under the glass, not a control. Simulator checks 5 and 6 cover this.

The test helpers that compute the visible viewport with `tabTop` (the top of the tab buttons) now measure to the glass buttons. The bar surface starts a few points above them, so a tap near the bottom of that viewport can land on the bar. See fix 3.

## Required fixes

1. **Echo-safe re-tap pop (`AppRouter.swift`).** Only a real tab-bar re-tap may clear a path:
   - Each code path that changes the selection or a tab path (`select` from code, `receive`, `openReader…`, `openReaderChapterList`, the notification route) records the affected tab as recently routed by code, with a short lifetime (for example until 1 s has passed, measured with a main-actor `Task.sleep`).
   - `selectFromTabBar(tab)` with `tab == selectedTab` does not clear the path while that record is set. It clears the record and returns.
   - A write of a different tab clears the record.
   - Add a DEBUG `NSLog` in `selectFromTabBar`: tab, whether it equals the current tab, the path count before, and whether it popped. Simulator check 2 can then show whether SwiftUI makes echo writes.

   A real user re-tap within that short time after a deep link is ignored. That is acceptable.

2. **Tests: full bar for parity and geometry.** Add the launch arguments `-JohnTabBarMinimize never` in every native Debug UI test that scrolls in the Read tab (Reader, Works, commentary, search, selection) and then taps a tab, or that measures bottom geometry. That is: `ReaderParityUITests`, `ReaderSelectionActionsUITests`, `ScriptureCardUITests`, `SearchNoteUITests`, `WorksSettingsUITests`, `LectioTimerUITests`, `ContentFlowUITests`, `NativeSmokeUITests`, and the native variant of `AllRouteCaptureUITests`. The old app has no minimized bar, so L25 parity captures need the full bar. Put the argument in one shared launch helper for each file. Do not add it to tests of the minimize behavior itself (check 4).

3. **Test viewport helpers.** In every `tabTop` helper (`AllRouteCaptureUITests`, `CalendarBoundaryUITests`, `LectioTimerUITests`, `NativeSmokeUITests`, `PositiveNoticeUITests`, and others that compute a viewport), use `app.tabBars.firstMatch.frame.minY` when the tab bar element exists. Otherwise subtract 12 pt from the top of the tab buttons. Record the tab bar frame in the L25 manifest. In `AllRouteCaptureUITests.worksExtra`, compute `aboveTabs` against the same edge.

4. **Build and exclusion record.** Build Debug (build-for-testing) and Release at `56d6a17` plus fixes 1–3. Record the hashes. Add `-JohnTabBarMinimize` to the C15 DEBUG-argument check (it is found from source, so confirm that the Release package has no hit).

5. **Release-only flows that scroll in Read.** `ReleasePerformanceUITests` (long Psalm 119 scroll, then Works) and `StoreScreenshotUITests` run on Release, where the flag does not exist. Before any tab tap after a Reader scroll, the helper must expand the bar (scroll up once, or tap the minimized bar) and check that the target tab button is hittable. For L26 this change alters the accepted helper hash. Prepare it as a reviewed diff before the L26 run.

## Simulator check list for Main

Run on `37D1870B-F16D-488A-8F20-959201F970D9` (iPhone 17 Pro, iOS 26.5) with fixes 1–4. Run the iPad check on `E76B006D-2F32-4D49-98D4-9DC1F15B7EB3`. Use the explicit UDID. Run with `-parallel-testing-enabled NO`.

1. **Identifiers.** `app.buttons["tab-today"]` … `["tab-settings"]` exist and are hittable on the tab bar. Each one selects its tab. Record each label (expect `Today`, `Read`, `Saved`, `Pray`, `Settings`) and its frame. If `.accessibilityIdentifier` on `Tab` does not reach the bar button, stop. Every test selector depends on it.
2. **Re-tap and echo.** Push a page in each tab (for example Pray → Rosary → Joyful). Tap the same tab: the stack pops to root. Tap a different tab and back: the pushed page stays. Read the `selectFromTabBar` DEBUG log for every write. Record any write that the user did not make.
3. **Deep links and notification routes.** Each case runs from three start tabs (the same tab, another tab, and Read with a pushed page). The destination must stay visible for 10 s, with no pop:
   - `nrsv://daily?date=<today>`;
   - `nrsv://daily` (fallback);
   - `nrsv://pray/rosary`;
   - `nrsv://read?book=JHN&chapter=3&verse=16`;
   - the Step 7 `url-fallbacks` test;
   - one Daily and one Rosary notification-response route (DEBUG-injected or real delivery, as available).
4. **Minimize behavior.** Read tab: scroll down in John 1. The bar minimizes. Tap the minimized bar: it expands. Tap Saved: Saved opens. The other tabs never minimize. Do this without `-JohnTabBarMinimize never`. Then check once that the argument keeps the full bar.
5. **Bottom controls.** With the full bar and with the minimized bar, check that these stay above the glass and are hittable: the Reader selection toolbar (select John 1:1), the Works lower controls (`assertWorksFooter`, Homily 10 page 1 → 2), the Scripture card buttons, the Lectio controls, the Saved Undo banner, and the Search field with the keyboard (the bar must stay below the keyboard, audit A1).
6. **Reader mask.** John 1 at the top and at the chapter end: the text passes under the glass. The top clip is unchanged. No text shows above the top safe area. Capture `end-text` and `end-footer` again (ReaderParity) with the full bar.
7. **Reader request lifecycle (`9d3753c`).** From Today, open Verse Moment → Read in context; from Saved, open a saved item; and use a cold-start `nrsv://read` URL. Each opens the requested passage once with the right selection or context.
8. **Tab state.** Scroll Today, switch to Pray and back: the Today scroll position is kept. Save a bookmark in Read, open Saved: the new row shows.
9. **iPad.** The tab bar is at the top with five tabs and no sidebar. One screenshot each of Today, Read, and Settings. Record it as an owner-accepted exception.
10. **Accessibility.** VoiceOver tree for the bar: five buttons, each with a label and selected state. At the largest accessibility text size, a long press on a tab shows the Large Content Viewer (audit claim).

## Invalidated or repeated evidence

- **All native L25 images** captured before `56d6a17` (tab region). Capture them again with fix 2. Native images from series that ran on earlier builds do not count for parity.
- **ReaderParity `end-text` and `end-footer`**, the Works lower-control check, and Reader selection captures (bottom geometry).
- **L01 shell comparison** (`04-shell-comparison.png`): it no longer describes the native shell (ADR).
- **Accepted Reader mask item** ("duplicate mask inset removed"): run check 6 again.
- **Step 7** `url-fallbacks` and any notification-route evidence (selection logic changed): check 3.
- **Not invalidated:** library, search results, Reader text and metrics, Works pagination text, notices and pending requests (L22 runtime acceptance stays for its binary), L27, and data-only evidence. Repeat their UI journeys only when a check above fails.
