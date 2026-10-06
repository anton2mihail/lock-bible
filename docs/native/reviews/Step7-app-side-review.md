# Step 7 app-side review

Date: 6 October 2026.
Reviewer: Sol (architecture, review, and acceptance).
Status: **Accepted with fixes.** Fix 1 below is a crash in the DEBUG probe. It blocks the W5 run. The other app changes are accepted.

## Reviewed boundary

Worktree `/Users/antonlachmaniucu/Documents/lock-bible/NRSV/.claude/worktrees/agent-abc59b37f1a128b9f`, branch `worktree-agent-abc59b37f1a128b9f`, diff `2ce1700..090bf12`:

| Commit | Content |
| --- | --- |
| `b3cbf01` | Fix 1 (card failure copy) and fix 2 (`nrsv://` fallbacks) |
| `f00d31c` | D1 (`-L29MediaFailureURI`) and D2 (shared-container probe) |
| `e28322c` | Generator and project: `WidgetHomeScreenUITests.swift` in the UI test target |
| `090bf12` | F2: a saved item that cannot open shows "This passage could not be opened." (present, reviewed) |

Sol did not build, run, or use a simulator. Sol read the worktree build logs and the built products.

The test-side Step 7 fixes are not in this branch. They are uncommitted in the primary checkout:

- `ContentFlowUITests.testStep7ExternalURLFallbacksMatchSource` (case `url-fallbacks`)
- the new card failure assertion in `ScriptureCardUITests`
- the verse check in `probeOwnedWordPoints`
- `inject_bundle_fault.py` `5216b50c…`

See integration requirement 1.

## Fix 1: card failure copy

`ScriptureCardView.swift:150` now sets "The card could not be shared. Please try again, or share the text." This equals `src/screens/companion/ShareCardScreen.tsx:63`. **Accepted.**

## Fix 2: `nrsv://` fallbacks

`ExternalRouteParser` no longer rejects a URL for a bad parameter. `AppRouter.receive` selects the fallback. Sol checked each case against the old source:

| URL case | Old source | Native | Result |
| --- | --- | --- | --- |
| `daily` with a missing or bad date | `calendar.ts:13–18`: `parseDate` falls back to today | `date ?? CompanionCalendar.dateKey(runtime.featureNow(), …)` | Match |
| `read` without `verse` | `ReaderScreen.tsx:129`, `:186–188`: no context range | chapter request with `verse` nil | Match |
| empty `endVerse` | `:189–191`: `"" ?? verse` stays `""`; no index is found | `nonEmpty` makes it absent. One verse is selected. | Same visible result |
| unknown `translation` | `:84–90` reads no `translation` | ignored; a valid value is still used | Match, plus the accepted native extension |
| known book, chapter out of range, missing, or not a number | `:291–307`: `Number(...)` is not a valid integer, so the chapter list shows | `openReaderChapterList` (chapter 0); `ReaderScreenModel.receive` calls `openBook` | Match (coordinator accepted the non-number case) |
| unknown or missing book | `:287–289` returns after the Read route opens | `selectedTab = .read` only | Match |
| other host or scheme | not routed | `nil` (unchanged) | Match |

Two small differences remain. A chapter with spaces (`" 1"`) is valid for `Number` but not for `Int`, so native shows the chapter list. With `read` and a valid `translation`, native opens that edition. Both are accepted.

`ReaderScreenModel` keeps "This passage is not available in this edition." only for an unknown book from other request sources. The new `NSLog` in `openReaderChapterList` is under `#if DEBUG`. **Accepted.**

## F2: saved item that cannot open

- `AppRouter.openSavedItem` now returns `Bool` (`@discardableResult`).
- `savedItemPassage` loads with the item's own edition (the accepted saved-edition rule).
- `SavedView.open` clears the status line, then tries to open the item. A note resolves its passage before the editor sheet opens.
- On failure, the existing `saved-status` line shows "This passage could not be opened.". `contentAnnouncement` announces it.
- The row action still calls `editNote` only for notes (`SavedView.swift:224`).

This implements the user's decision. **Accepted.**

## D1

`failureURIOverride` and its use are inside the existing `#if DEBUG` blocks of `RosaryMediaModel.swift`. The Release branch (`let uri = directURI`) does not change. **Accepted.**

## D2 against fix-5 conditions

| Condition | Result |
| --- | --- |
| Group only from `Info.plist`; no production fallback | Yes, on both sides. A missing group logs or records `missing` and writes nothing. |
| Documents URL from `FileManager` and `debugScenarioURL` confinement | Yes |
| Refuse an existing output file | **No. It crashes.** See required fix 1. |
| All call sites under `#if DEBUG` | Yes: the six provider calls in `JohnWidget.swift` and the call at `Runtime.swift:190`, inside the startup DEBUG block. The function is in the DEBUG region (lines 267–778). |

**Crash.** `Runtime.swift` writes with `options: [.atomic, .withoutOverwriting]`. Sol ran that exact call with Swift 6.3.3 Foundation on the host. The process stopped with `Fatal error: withoutOverwriting is not supported with atomic` (`Foundation/Data.swift:2608`). This is not a thrown error, so the `catch` does not run. Any DEBUG launch with `-L29SharedProbeRelativePath` would end. `L22-system-notice-snapshot-review.md` gave the same rule.

## Swift 6 concurrency

The project uses Swift 6 with complete strict concurrency.

- `debug-build2.log` (09:25:14, after the F2 edit) ends with `TEST BUILD SUCCEEDED`. Its only warning is the existing one at `DestinationView.swift:171`. No changed file has a warning.
- `ExternalRoute` stays `Sendable` with optional payloads.
- `AppRouter` and `SavedView` work stays on the MainActor.
- `WidgetSharedState.recordProbe` is a nonisolated static function with local state only.

**Accepted.**

## Release exclusion

No Release exclusion record exists for this branch. `DerivedData-release` (`John` written 08:47:54) predates the commits and F2. It does not contain "This passage could not be opened.". Sol checked it as a partial result:

| String | Release `John.app` (all files) | Debug positive control |
| --- | --- | --- |
| `-L29MediaFailureURI` | 0 | 2 |
| `-L29SharedProbeRelativePath` | 0 | 2 |
| `l29-widget-probe` | 0 | 4 |
| `l29.widgetProbe` | 0 | 4 |

Correction to the list in `Step7-remaining-feature-checks-review.md` ruling 2: remove `recordProbe`. Swift symbol names are mangled, so a plain string search is not valid for it (Debug also gives 0).

## Generator

`e28322c` adds `WidgetHomeScreenUITests.swift` to the `SimulatorSupport` list only. The regenerated project adds one file reference, one build file in the UI test Sources phase, and one group child. No app or widget target changes. **Accepted.**

## Required fixes

1. **`native/John/App/Runtime.swift`, `exportSharedContainerProbe`.** Replace

   ```swift
   try data.write(to: target, options: [.atomic, .withoutOverwriting])
   ```

   with

   ```swift
   guard !FileManager.default.fileExists(atPath: target.path) else {
       throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: target.path])
   }
   try data.write(to: target, options: .atomic)
   ```

   Fix the comment above it to match.

2. **Release exclusion record at the final commit.** After fix 1, build Release from the final branch head. Record the HEAD and the source hashes. Check `John` and `PlugIns/JohnWidget.appex/JohnWidget` with `strings -a` for `-L29MediaFailureURI`, `-L29SharedProbeRelativePath`, `l29-widget-probe`, and `l29.widgetProbe`, with a Debug positive control. Also confirm that "This passage could not be opened." and "The card could not be shared" are present in Release.

## Integration requirements for Main

1. Build one boundary that holds this branch (with fix 1) and the primary-checkout test fixes: `ContentFlowUITests`, `ScriptureCardUITests`, and `inject_bundle_fault.py` `5216b50c…`. Record every source hash. The test `testStep7ExternalURLFallbacksMatchSource` needs the app changes in this branch. The old `invalid-urls` expectation no longer applies.
2. W5 uses the two-launch rule in `Step7-remaining-feature-checks-review.md`. Give each launch a new `STEP7_PROBE_RELATIVE_PATH`, because the probe refuses an existing file.
3. Keep `PositiveNoticeUITests.swift` at the reviewed `89dd7bf0…` (`L22-positive-notice-runtime-20261006.md`).

## Fix re-check (6 October 2026)

**Required fix 1 (shared probe crash): accepted.** Commit `b5b2b14` is in HEAD. In `exportSharedContainerProbe`, it removes `[.atomic, .withoutOverwriting]`. It adds a guard that throws `CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: target.path])` when the file exists, then writes with `.atomic`. The existing `catch` logs the refusal. This is the exact change that this review required. It matches the L22 stage writer. The DEBUG launch with `-L29SharedProbeRelativePath` no longer stops the process.

**Required fix 2 (Release exclusion record): accepted for the F3 boundary.** `build/native-evidence/F3/F3-build-record.txt` (SHA-256 `d7d4b441fe6fdcf9e090cec25ab25c36bb3f58081ad985a5e48911db346440c4`) is built from `0928fb4`, which contains `b5b2b14`. On the Release product, `l28_inspect_package.py` gives C13 PASS: no `-L29MediaFailureURI`, `-L29SharedProbeRelativePath`, `l29-widget-probe`, `l29.widgetProbe`, or sample URL in any file. C14 is also PASS. Record a Debug positive control for C13 beside this record.

**F3 build facts (required fix 1 of `F3-shared-rotation-framework-review.md`): accepted.** The same record shows, for Release and Debug:

- The framework `Rotation/` holds 15 files whose hashes equal the staged files.
- No rotation file exists outside the framework.
- The widget links `@rpath/JohnSharedResources.framework` with the `@executable_path/../../Frameworks` run path and has no `Frameworks` folder of its own.
- The framework has minimum OS 26.0 (Info and Mach-O), ID `com.nrsv.verse.sharedresources`, version 1.5.0 (19), and no `Headers` or `.swiftmodule`.
- L28: 16 PASS, 0 FAIL. C03 and C04 now include the framework.
- C12: the Release widget has no file-timestamp symbol (only `NSUserDefaults`). **F2 therefore needs no widget manifest change.** Run C12 again on the signed archive.
- C05 REVIEW is expected for a generic simulator product, because the binaries are x86_64 and arm64. The device archive must show arm64 only.

The F3 repeat-check list (L04 runner, Today and Verse Moment verse, Step 7 W1–W5, L28 resource inventory, L26 size) stays open until Main runs it on this build.
