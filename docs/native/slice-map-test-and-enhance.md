# Slice map: full test and SwiftUI/mobile enhancement

Rules: one builder at a time. Dirty tree: use the current branch, no worktree.
Simulator: create a NEW device. Do not use any booted or existing device.
`xcrun simctl create "QA-Own-iPhone17Pro" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-5`
Delete it at the end. Source root: `native/John`. Tests: `native/John/SimulatorSupport`.

## Phase 1 - Test (no source edits except fixes)

| ID | Outcome | Files it may change | Acceptance | Blocked by |
|----|---------|---------------------|------------|-----------|
| T0 | Own simulator created. App + widget build (Swift 6). Baseline UI test run. | none | Build passes. Test log saved to `native/reviews/`. | - |
| T1 | Today, Calendar tabs tested | Features/Today, Features/Calendar | Today and Calendar UITests pass. Screenshots saved. | T0 |
| T2 | Reader tested: paging, selection, notes, highlight, Go To, search | Features/Reader | Reader UITests pass. Defects logged. | T0 |
| T3 | Saved tab tested: notes, filter, delete, undo | Features/Secondary | Saved flow passes. | T0 |
| T4 | Pray tab tested: prayers, Rosary, Lectio timer, guides | Features/Prayers, Features/Guides | Prayer and Lectio UITests pass. | T0 |
| T5 | Settings, Works, Media, Notifications tested | Features/Settings, Works, Media, Notifications | Settings and media UITests pass. | T0 |
| T6 | Widget, Dynamic Type, VoiceOver, dark mode, iPad, rotation, offline | Widget, Platform | Accessibility and widget UITests pass. | T1-T5 |
| T7 | Fix defects from T1-T6 (one fix slice for each feature area) | per defect | Failing check now passes. | T6 |
| T8 | Final test review through `native-review` | none | No open defect. | T7 |

## Phase 2 - Enhancement catalogue (candidates)

Each item becomes one slice after the user approves the list.

Reading
- E1 Text selection with a custom edit menu: highlight, note, share, copy verse.
- E2 Live Text-like verse sharing card with `ImageRenderer`.
- E3 `ShareLink` for verses and cards.
- E4 `ScrollView` position tracking with `scrollPosition` and `scrollTargetBehavior`.
- E5 Zoom navigation transition from list to Reader.
- E6 Pinch to change text size (`MagnifyGesture`).
- E7 Reading progress ring and reading plan.
- E8 Verse-by-verse text-to-speech (`AVSpeechSynthesizer`) with lock-screen controls.
- E9 Siri and `AppIntents`: "Read today's Gospel", "Open Rosary".
- E10 Spotlight indexing (`CoreSpotlight`) of notes and books.
- E11 Find in page using `searchable` with tokens and suggestions.

System surfaces
- E12 WidgetKit: lock-screen, StandBy, interactive widgets, Control Center control.
- E13 Live Activity for Rosary or Lectio timer (Dynamic Island).
- E14 App Shortcuts and Action Button.
- E15 Handoff and Universal Links to verses.
- E16 Focus filter (quiet mode for prayer).
- E17 `UserNotifications` time-sensitive and daily reading with rich actions.
- E18 Apple Watch companion app and complications.
- E19 CarPlay or audio-only Bible listening.
- E20 App Intents for Share Sheet and Writing Tools on notes.

Data
- E21 SwiftData and iCloud (CloudKit) sync for notes and highlights.
- E22 Export and import of notes (PDF, Markdown) with `FileExporter`.
- E23 Undo and redo with `UndoManager`.
- E24 Tags and smart folders for notes.

Interaction and feel
- E25 Haptics (`sensoryFeedback`) for rosary beads, saves.
- E26 Liquid Glass materials and `glassEffect` for toolbars and tab bar.
- E27 `TabView` search tab role, bottom accessory (`tabViewBottomAccessory`) for audio mini-player.
- E28 Mesh gradient background on Today. NO entrance animation (see rule below).
- E29 Context menus, swipe actions, drag and drop of verses.
- E30 Pointer, keyboard shortcuts, `Commands`, multiple windows, Stage Manager on iPad.
- E31 Split view (`NavigationSplitView`) on iPad and landscape.
- E32 Apple Pencil Scribble and handwriting notes (`PencilKit`).
- E33 Dictation and `Speech` for notes.
- E34 `TipKit` onboarding tips.
- E35 `StoreKit` review prompt and tip jar (only after the user confirms).

Quality
- E36 Full VoiceOver labels, rotor, Voice Control, Reduce Motion, Dynamic Type XXXL.
- E37 Localization with String Catalogs.
- E38 Swift Testing unit tests on JohnCore, plus performance tests with `XCTMetric`.
- E39 `#Preview` for every view and snapshot checks.
- E40 MetricKit and OSLog signposts for launch and scroll hangs.

## Order after approval
T0 -> T1..T5 (serial) -> T6 -> T7 -> T8 -> user approves E-list -> one slice per E item
(`native-build`, then `native-review` on each diff) -> final `code-review` via `native-review`.

GLOBAL RULE: never animate the entrance of buttons, text, or views. No entrance animation of any kind. Every builder and reviewer must obey it. See AGENTS.md.

New slice A0 (after T0, before T1): find and remove every existing entrance animation in native/John (`.transition`, `.onAppear`+`withAnimation`, `.animation(` tied to first appearance, `PhaseAnimator`, `KeyframeAnimator`, staggered delays). Acceptance: grep clean, UITests for affected screens pass.

T0 decision: run each UITest class alone with a short time limit. Skip `testBibleRepositoryCasesAcrossEditions` (689 s). Mark L22 and baseline-bundle tests as setup-blocked.

Stop rules: stop if a slice is blocked, needs a product decision, or one check fails 3 times.
