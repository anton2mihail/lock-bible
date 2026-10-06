# UI polish audit for iOS 26 (SwiftUI)

Date: 6 October 2026. Branch: `codex/swiftui-ios26-rebuild`. Scope: read-only review of `native/John/{App,DesignSystem,Features,Platform}` and native captures in `build/native-evidence/`. This review did not change source, simulators, or commits.

The Liquid Glass tab bar is out of scope. Another agent owns it. Section 1 lists the items that touch it.

Rules for this list:

- "Text/typography" means a change to visible copy or to Scripture reading typography. These changes need owner approval. Scripture text and reading typography are parity-locked.
- "Evidence" names the tests, selectors, or captures that a change can affect.
- Effort: S is less than half a day. M is one to two days. L is more.

## 1. Interactions with the Liquid Glass tab bar work

1. **One NavigationStack for all tabs.** `App/JohnApp.swift:41-53` swaps the root view and the path binding when the tab changes. Each tab switch destroys the root view state. For example, the Saved filter goes back to All, and Today, Pray, and Settings scroll back to the top. A path swap can also animate as a push or pop. Recommendation: the new bar should use `TabView` with one `NavigationStack` per `Tab`. `AppRouter.paths` already stores one path for each tab.
2. **Keyboard lifts the tab bar.** `FlatTabBar` is a plain `VStack` child (`JohnApp.swift:53`). On Search, the bar sits on top of the keyboard and uses about 50 pt of the result area (`L25/step7-fault-search-db-missing-01/run-bundle-fault/export/0229EFE6-….png`). A system `TabView` keeps its bar below the keyboard. If the custom bar stays, add `.ignoresSafeArea(.keyboard, edges: .bottom)` to the shell.
3. **Re-tap of the active tab does nothing** (`FlatTabBar.swift:30-32`). iOS users expect a re-tap to pop to the root and then scroll to the top. This is the "Pray stranding" item from the September review. A `TabView` selection with a re-tap handler can call `router.setPath([], for:)`.
4. **Tab labels do not scale** (`FlatTabBar.swift:36`, `.system(size: 10)`). Add `.accessibilityShowsLargeContentViewer()` if the custom bar stays. The system bar does this automatically.
5. **Scroll edge.** Content cuts hard at the top border of the bar. With a glass bar, keep the default `.scrollEdgeEffectStyle(.automatic, for: .bottom)`. Do not set `.hard` on reading screens.

## 2. UI bugs found

| ID | Screen | Bug | Source | Evidence seen |
| --- | --- | --- | --- | --- |
| BUG-1 | All pushed routes | Two back controls. The system glass back button floats at the top left, and the page also shows its own "← Back", "‹ Read", or "Cancel". Search has three exits. | `DestinationView.swift:12-83` does not hide the bar. `ContentPage.swift:19-34`, `WorksLibraryView.swift:32-42`, `SearchView.swift:30-34`, `GoToView.swift:27-31` | `L25/f3-today-verse-moment-01/verse-moment-top.png`, Search and Works fault exports |
| BUG-2 | Search | Tab bar rides on the keyboard (see 1.2). | `JohnApp.swift:40-55` | Search fault export |
| BUG-3 | Reader | Native-only line "Selected: verses 1–1" for one verse. The old app has no such line. | `ReaderView.swift:501-506` | `NativeSmokeUITests.swift:463` asserts "1–1" |
| BUG-4 | Reader | "The Fathers on this chapter" rows have no separator or gap. Each subtitle runs into the next title. | `ReaderView.swift:719-743` | `L25/native-john1-end-split-01/export/75B81E24-….png` |
| BUG-5 | Works contents sheet | Grey sheet margins show around a beige list. The title column moves right at "10." because the number column has no fixed width. | `WorkReaderView.swift:167-191` | `L20/works-aa-build-01/works-page-frame.png` |
| BUG-6 | Works library failure | The failure state still shows "0 authors · 0 works · 0k words · reads offline". | `WorksLibraryView.swift:49-51, 74-75` | `L25/step7-fault-works-catalog-missing-01/run-bundle-fault/export/C8A0C9EB-….png` |
| BUG-7 | Saved | Each return to the tab replaces the list with "Loading saved items…" for a moment, because `reload()` sets `loading = true` when rows already show. | `SavedView.swift:39-41, 82-85, 145-149` | Source only |
| BUG-8 | Verse Moment | `subtitle: ""` adds an empty text line and 8 pt of extra space under the title. | `DestinationView.swift:151-152`, `ContentPage.swift:52-58` | `verse-moment-top.png` |
| BUG-9 | Go to | Visible label "Cancel", accessibility label "Close". Voice Control "Tap Cancel" fails. | `GoToView.swift:27-31` | Source only |
| BUG-10 | Code health | Dead UI code: `AppRoute.passage` is never pushed, so `ReaderDestination` and its second Aa sheet cannot show (`DestinationView.swift:195-264`). `Features/Today/TodayView.swift` is never used. | — | Source only |

BUG-6 and BUG-8 change visible text. Compare them with the old app before you fix them.

## 3. Group A: safe polish to do now

No copy change. No Scripture typography change. Low test risk.

| ID | Screen | Current (file:line) | Proposed change | User benefit | Evidence risk | Effort |
| --- | --- | --- | --- | --- | --- | --- |
| A1 | Shell, Search | BUG-2 | Keep the tab bar under the keyboard (1.2). Coordinate with the tab bar agent. | About 50 pt more results while typing | `CalendarBoundaryUITests.swift:136-149` and similar helpers already clip the viewport by keyboard and tab tops. Low. | S |
| A2 | Reader chapter grid, Go to | Fixed 52 × 52 cells with scaling text (`ReaderView.swift:357-367`, `GoToView.swift:65-76`). "150" truncates at AX sizes. | `@ScaledMetric(relativeTo: .body) var cell = 52`. Use it for the frame and the `GridItem` minimum. | Readable chapter numbers at large text | The value is 52 at the default size, so default captures do not change. | S |
| A3 | Search scopes, Saved filters | Equal-width chips (`SearchView.swift:81-101`, `SavedView.swift:102-122`). They truncate at AX5 (September review). | Wrap the `HStack` in `ViewThatFits(in: .horizontal)`. The fallback is a two-column `Grid` or a vertical stack. | No mid-word breaks at large text | Default layout is the same. Identifiers are the same. | S |
| A4 | Saved | BUG-7 | Show the spinner only when `items.isEmpty`. Keep the rows during a refresh. | No flash on each visit | `saved-empty-state` and `saved-status` are unchanged. | S |
| A5 | Saved | Visible "Delete" only (`SavedView.swift:254-258`) | Keep the button. Add `.swipeActions(edge: .trailing) { Button(role: .destructive) … }` and `.contextMenu` with Open and Delete. Both call the same `delete(item)` and keep Undo. | Standard iOS gestures | Additive. Delete/Undo tests use the button identifiers. | S |
| A6 | Saved | Undo bar appears and goes without motion (`SavedView.swift:53-79`) | `.transition(.move(edge: .bottom).combined(with: .opacity))` and `.animation(reduceMotion ? nil : .snappy, value: undoItem?.id)`. | The user sees where Undo came from | Undo test waits for existence. Low. | S |
| A7 | Note editor (Saved sheet) | A swipe-down dismiss discards unsaved text (`SavedView.swift:86-94`, `354-419`). | `.interactiveDismissDisabled(draft != originalText)`. No new prompt text. | Data-loss net from the September review | `SearchNoteUITests` uses Cancel and Save buttons. Low. | S |
| A8 | Reader actions | Feedback is text and VoiceOver only (`ReaderView.swift:81-135`) | `.sensoryFeedback(.success, trigger: selectionFeedback)` for saved, applied, or copied. Use `.error` for "could not" messages. Add `.sensoryFeedback(.selection, trigger:)` to highlight swatches and Saved or Search chips. | Confirmation without a look at the toolbar | None. Haptics are not captured. | S |
| A9 | Lectio | The screen can auto-lock during the silent minute (`LectioView.swift:50, 141-152`). | Set `UIApplication.shared.isIdleTimerDisabled = true` while `deadline != nil`. Reset it in `onDisappear` and when the timer ends. | Silent prayer is not cut by the lock screen | `LectioTimerUITests` is unchanged. | S |
| A10 | Counters | Plain text changes: search count (`SearchView.swift:148`), Lectio seconds (`LectioView.swift:72`), Rosary percent (`RosaryGuideView.swift:98`), Works page (`WorkReaderView.swift:133`), novena "x of 9 prayed" (`NovenaView.swift:39`) | `.contentTransition(.numericText(countsDown:))` with `.monospacedDigit()`. Use `.identity` when Reduce Motion is on. | Calm, readable number changes | Final text is the same. Captures show the final frame. | S |
| A11 | Works contents sheet | BUG-5 | `.listStyle(.plain)` and `.scrollContentBackground(.hidden)`. Give the number a fixed `frame(minWidth:alignment: .trailing)` with `@ScaledMetric`. Let the sheet keep its iOS 26 glass background. Do not paint a flat fill. | Clean, aligned contents | Works contents tests use row titles. Low. | S |
| A12 | Reader commentary | BUG-4 | Add a 1 / displayScale separator between rows, as `ContentActionRow` does, and 8 pt vertical padding. | Each reading reads as one row | `reader-commentary-*` identifiers are the same. The end-split capture changes slightly. | S |
| A13 | Reader (VoiceOver) | Verse elements do not state highlight or bookmark state (`ScriptureTextView.swift:741-765`). | Set `accessibilityValue` to "Gold highlight", "Bookmarked", or both. Add `UIAccessibilityCustomRotor` items "Highlights" and "Headings" on the container. Do not change labels. | VoiceOver users can find their marks | Labels and identifiers are the same. Values are new. Medium code risk, because this file holds anchor logic. | M |
| A14 | Go to | BUG-9 | Remove `.accessibilityLabel("Close")` so the label equals "Cancel". | Voice Control works | `go-to-cancel` identifier is the same. | S |
| A15 | Code health | BUG-10 | Delete `ReaderDestination`, `AppRoute.passage`, and `TodayView.swift` after one `grep` and one build. | Less risk of a wrong second Aa sheet | Build only | S |

## 4. Group B: worthwhile, needs an owner decision

| ID | Screen | Current (file:line) | Proposed change | User benefit | Evidence risk | Effort | Text/typography |
| --- | --- | --- | --- | --- | --- | --- | --- |
| B1 | All pushed routes | BUG-1 | Choose one back control. **Option 1 (recommended for iOS 26):** keep the system glass back button. Remove the in-page "← Back", "‹ Read", and "Cancel" rows. Put screen actions in `.toolbar` items, with `ToolbarSpacer` between groups. **Option 2 (strict parity):** add `.toolbar(.hidden, for: .navigationBar)` in `DestinationView`. Then check that the edge swipe-back still works on iOS 26.0 and 26.5. | One clear way back. Option 1 also gives the free scroll edge effect and the full-width back swipe. | High. `content-back` is used 15 times (`ContentFlowUITests`, `PositiveNoticeUITests`, `MediaNotificationUITests`). `navBottom` viewport helpers change. All route captures change. | M | Option 1 removes visible "Back" text |
| B2 | Reader Aa sheet | Menu pickers in a medium sheet (`ReaderView.swift:191-205`, `SecondaryRootView.swift:57-140`). It adds a Bible picker. The old sheet used the same chip controls as Settings (`src/components/TextSettingsSheet.tsx:83-84`, `ReadingSettings.tsx`). | Reuse `SettingsChoiceGroup` from Settings. Use `.presentationDetents([.height(…), .medium])`, `.presentationBackgroundInteraction(.enabled(upThrough: .medium))`, and the default glass sheet background. Keep the chapter visible and scrollable behind it. Decide whether the Bible picker stays. | Live restyle in view, one-tap choices, parity with the old app | `WorksSettingsUITests.swift:100-112` uses the `settings-text-size` menu. The Aa capture changes. | M | No reading typography change. The control layout changes. |
| B3 | Reader selection toolbar | Flat card panel under the scroll view (`ReaderView.swift:619-654`, `ReaderSelectionToolbar.swift:90-94`) | Show it with `.safeAreaInset(edge: .bottom)`. Give it `.glassEffect(.regular, in: .rect(cornerRadius: 24))` and wrap the swatches and actions in one `GlassEffectContainer`. Scripture then scrolls under the glass. Use a solid fill when Reduce Transparency is on. | The action bar matches the new tab bar. The text column keeps its height. | Toolbar captures, `L08` anchor geometry (the visible viewport changes), and the selection tests that measure hit areas | M | No |
| B4 | Reader | BUG-3 | Hide the line from sight and keep it as an accessibility-only element. Or show "Verse 1" for one verse and "Verses 1–3" for a range. | No odd "1–1" text | `NativeSmokeUITests.swift:357-463` reads its label | S | Yes, visible copy |
| B5 | Reader top edge | A hard mask cuts lines under the status bar (`ReaderView.swift:229-231, 551`). See `L22/reader-anchor-safearea-10-attachments/05F4FC7E-….png`. | `.scrollEdgeEffectStyle(.soft, for: .top)`. Keep the mask math for anchors. | Text fades out under the status bar and does not cut through glyphs | `L08` and `L22` anchor and safe-area tests measure the top clip. Run them all again. | M | No |
| B6 | Go to | Full pushed page (`GoToView.swift:16-110`) | Show it as a sheet with `[.medium, .large]` detents and a glass background, from the title button. | The chapter stays in context. The sheet closes with a swipe. | Go to tests ("expansion, selection, Back") and the route capture. `router.sheet` gets a second case. | M | No |
| B7 | Today → Daily, Rosary, Sunday | Art cards push with the standard slide (`CompanionTodayView.swift:45-96`) | `.matchedTransitionSource(id:in:)` on the art and `.navigationTransition(.zoom(sourceID:in:))` on the destination. Use the standard push when Reduce Motion is on. | The card opens into its page | Route captures that are taken during the transition. Wait for idle first. | S | No |
| B8 | Novena | "Start the novena again" resets nine days and the intention at once (`NovenaView.swift:228-232`). | `.confirmationDialog` with a destructive Reset button. | Data-loss net from the September review | Novena reset test needs one more tap | S | Yes, new dialog copy |
| B9 | Saved, Search empty and error states | Centered muted text (`SavedView.swift:42-49`, `SearchView.swift:159-167`, `WorksLibraryView.swift:74-75`) | `ContentUnavailableView` with a Feather or SF Symbol and the same description text. Add a "Try again" action on load failures. | Clear, standard empty and error screens | `saved-empty-state` and `search-status` must stay on the description text. Captures change. | S | Adds a title and an icon |
| B10 | Rosary guide | No physical feedback per bead | `.sensoryFeedback(.selection, trigger: completedActions)` and `.impact(weight: .light)` at the end of each decade. Add a setting if the owner wants silence. | The user can pray without a look at the screen | None | S | No |
| B11 | Lectio | The silent minute ends with no signal (`LectioView.swift:141-152`) | One soft `.sensoryFeedback(.success)` when `seconds` reaches 0. | The user knows the minute ended with eyes closed | `LectioTimerUITests` is unchanged | S | No |
| B12 | iPad | Tab bar and content roots use phone layout. Reader width is capped (`ReaderView.swift:58-60`). Pages cap at 740 pt. | `.tabViewStyle(.sidebarAdaptable)` (with the tab bar work). On regular width, show Go to as a popover (`.presentationCompactAdaptation(.sheet)`). | Native iPad navigation | iPad captures | M | No |

## 5. Group C: not recommended

| ID | Idea | Reason |
| --- | --- | --- |
| C1 | `.glassEffect` on content cards, Scripture text, or the Today art cards | Glass over text and paintings lowers contrast and fights the paper look. Apple guidance keeps glass for controls and navigation. It also breaks parity captures for no user gain. |
| C2 | Replace the custom Search field with `.searchable` or a `Tab(role: .search)` | A search tab adds a sixth tab and breaks the five-tab rule (ADR 0006). `.searchable` changes the accepted Search form, focus, and scope behavior that three Build19 UI methods passed. |
| C3 | System fonts or Dynamic Type text styles for Scripture | Reading typography is parity-locked. The reader already scales with `systemTextScale` (`ReaderView.swift:33-49`). |
| C4 | Replace `ScriptureTextView` (UIKit) with SwiftUI `Text` | Selection, anchors, and range hits depend on TextKit geometry. The cost is high and the user sees no gain. |
| C5 | Replace the Reader share `UIActivityViewController` with `ShareLink` | The current path reports share errors and has accepted Step 7 evidence. `ShareLink` has no error callback. |
| C6 | Page-curl or `TabView(.page)` paging in the Works reader | Page slicing and anchor restore are accepted (`L20-works-tail-runtime-20261006.md`). A paging container rebuilds pages and puts anchors at risk. |
| C7 | Large navigation titles with `.navigationTitle` on root screens | The 36 pt Space Grotesk and Lora titles are part of parity. A system large title changes font and position on every root. |

## 6. Suggested order

1. A1, A4, A7, A9, A14: user-visible fixes that need almost no evidence work.
2. A2, A3, A11, A12: layout fixes at large text and in Works.
3. A5, A6, A8, A10: interaction polish.
4. A13 and A15, each with its own build and test run.
5. Ask the owner about B1 first. It decides how every pushed route looks next to the new glass tab bar. Then ask about B2 and B3.

Run the affected UI tests after each group. Use the approved simulators and `-parallel-testing-enabled NO`.
