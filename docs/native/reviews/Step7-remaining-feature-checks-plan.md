# Step 7 remaining feature checks plan

Date: 6 October 2026.
Owner: Source.
Status: plan, source tools, and env-gated test helpers. Updated after Sol's review (`Step7-remaining-feature-checks-review.md`). Source ran nothing on a simulator. Source changed no app code.

This is handoff step 7: widgets, media, share fallback, errors, iPad, and actual app and extension shared-container access. Main owns every simulator action and every app change.

## 1. Result

- Seven items have a complete helper path now. Six more need only a bundle fault from the new injector. Three need a small DEBUG hook in the app. The hooks are written as diffs in section 5. Source did not apply them.
- Source wrote three host tools (no simulator): a widget expectation tool from the old source, a Rosary media package check, and a bundle fault injector.
- Source added env-gated tests to `ContentFlowUITests`, `ScriptureCardUITests`, and `MediaNotificationUITests`. Source also added one new test file, `WidgetHomeScreenUITests.swift`. **Main must add the new file to the UI test target in the generator.** No other new test file exists.
- A default test run is unchanged. Every new test skips unless `STEP7_CASES` lists its case name.
- All changed files type-check with Swift 6 and the iOS 26.0 simulator target, with and without `-D DEBUG`.
- The package check ran on two existing builds. The Debug build (`com.nrsv.verse.dev`, 1.5.0 (19)) holds both sample URLs in `John.debug.dylib`. The preserved Release build (`com.nrsv.verse`, 1.5.0 (19)) holds neither. All six official URLs equal the old source in both builds.
- The old source finds 0 unresolved citations in 2,739 reading rows (2025 to 2032). The "reference could not be opened" state can appear only through a bundle fault.

## 2. Open items

Legend. "Helper" says what covers the item. "Cannot prove" is the part the simulator cannot show. Those parts go to the physical-device list (section 4).

### 2.1 Widgets and shared container

| ID | Remaining | Helper | Simulator mechanism | Cannot prove | Seed | Expected values (source) |
| --- | --- | --- | --- | --- | --- | --- |
| W1 | Rendered values and sizes of the three widgets on the home screen. | `WidgetHomeScreenUITests.testStep7WidgetRenderedTextOnHomeScreen` (new) and `widget-expected.ts` | Main adds the widgets by hand to the first home page. The test reads SpringBoard labels and frames. | Lock screen accessory families (no lock screen editing in the simulator is assumed; try it, else physical). Real WidgetKit refresh budget. | Native dev state: edition WEB-CE, scope full, interval 1440 (the L25 fixture values). | Run `TZ=<zone> bun scripts/native/source-fixtures/step7/widget-expected.ts <instant> <zone> <edition> <scope> <interval>`. It calls the old `getCurrentVerse` (`src/services/bible/bibleService.ts:63`) and reads the widget daily file (`targets/widget/daily-readings-YYYY.json`). Example at 2026-09-13T16:00Z Toronto: WEB-CE, full, 1440 gives John 19:27; Douay–Rheims, NT, 60 gives Ephesians 2:8; Vulgate, OT, 15 gives IUDICUM 19:2. Daily Gospel that day: Matthew 18:21-35. |
| W2 | Values after a Settings change. Next refresh time. Midnight and year fallback. | Same helper. The Settings change uses the existing Settings tests or Main's UI steps. | Change edition, scope, or interval in Settings. The app calls `reloadTimelines` for `VerseWidget` and `VerseTimerWidget` (`Runtime.swift:1001-1002`). Read the labels again. | The exact reload time (WidgetKit decides). The Daily Reading widget has no reload call. It refreshes at its own timeline end. | Same, plus a changed preference. | Verse timeline: up to 48 entries, first entry at `now`, policy `atEnd` (`JohnWidget.swift:81-109`; old `VerseWidget.swift:341`). Countdown: start of the current slot, end at the next slot (`JohnWidget.swift:111-134`). Daily: 8 entries, today to +7 days, fallback title `Today’s readings` with an empty reference (`JohnWidget.swift:136-148`). |
| W3 | Tap links. | `testStep7WidgetTapOpensExpectedDestination` | Tap the widget in SpringBoard. Check the app. Use `STEP7_WIDGET_COLD=1` for a cold launch. | Lock screen taps. | Same. | Verse: `nrsv://read?book=<code>&chapter=<n>&verse=<label>&contextRequest=<epoch>` (old `VerseWidget.swift:191`). Daily: `nrsv://daily?date=YYYY-MM-DD` (old `DailyReadingWidget.swift:47`). Countdown has no URL. The URL has no `translation` value, as in the old source. The app uses the current edition (`ExternalRouteParser.swift`, `AppRouter.receive`). |
| W4 | Widget fallbacks. | `inject_bundle_fault.py` faults `widget-corpus-missing`, `widget-daily-year-missing` | Remove one file from the widget bundle in the task-only dev app. Read the labels. | Nothing extra. | Dev app, task-only. | Verse fallback text `Open John 1:1 to begin.` and reference `John 1:1` (`JohnWidget.swift`, VerseWidgetView). Daily fallback: `DAILY READINGS` and `Tap to open today’s readings`. |
| W5 | Actual app and extension shared-container access. | `testStep7LaunchSharedContainerProbe` plus the DEBUG probe (diff D2, not applied) | Widget writes a probe value and a probe file into the group container on each timeline call. The app reads both and exports a JSON file. Main copies it. | Device-signed App Group access (the simulator checks only the embedded simulator entitlement). Do not claim signing from this. | Dev app with the probe. | Run the `shared-probe` launch twice. Pass only if both records show the same non-nil container path, `fileWrite` is `ok`, and the second record's widget probe time is later than the first record's `appTime`. The values that the widget read must equal the values that the app wrote (`Runtime.swift:985-1002`; `JohnWidget.swift:13-20`). The probe reads `AppGroupIdentifier` from Info.plist only. A missing value is recorded as `missing` and nothing is written. Entitlement boundary: `L12-simulator-entitlement-boundary.md`. |
| W6 | Lock screen (accessory) families. | None. | Try the lock screen editor in the simulator. | Everything, if the editor is missing. | None. | Families: Verse five (rectangular, inline, circular, small, medium), Countdown four (rectangular, inline, circular, small), Daily four (rectangular, inline, small, medium) (`JohnWidget.swift:313`, `:323`, `:333`). |

Widgets added by hand (Sol's ruling 3). Main uses the Simulator tool on the dedicated John device only. Evidence for each session:

1. The device UDID, the installed dev app and widget executable hashes, and the host time and time zone.
2. A screenshot of the home screen before the edit.
3. For each instance: a screenshot of the gallery entry with its name and size, and a screenshot after placement. Record kind, size, page, and slot.
4. A final home-screen screenshot and the `widget-render` label dump.
5. The `widget-expected.ts` output for the capture instant, with the command line. The widget tap test uses the real clock, so record the capture instant with each result.
6. After a reinstall (needed to clear widget faults), check again that each instance exists, or add it again with the same evidence.
7. Do not move or remove other home-screen items. Do not add widgets of other apps.

### 2.2 Verse Moment, share, and Scripture card

| ID | Remaining | Helper | Mechanism | Cannot prove | Seed | Expected values (source) |
| --- | --- | --- | --- | --- | --- | --- |
| V1 | Verse Moment controls: countdown wording, guide steps, durable dismissal, Share, card, Read in context. | `ContentFlowUITests.testStep7VerseMomentControlsGuideShareCardAndContext` | The test uses the fixed feature clock 2026-09-13T16:00Z Toronto. | Real share targets (the test opens the panel and cancels). | Native dev state with `widgetGuideDismissed` false. The test sets it true. Reseed before a repeat. | Countdown `New verse in <n> min`, `<h>h`, or `<h>h <m>m` (`DestinationView.swift:410-412`; `VerseOfDayScreen.tsx:21-29`). Steps text lines 1 to 4 (`VerseOfDayScreen.tsx:115-118`). Share text `“<text>”\n— <ref> (<abbr>)` (`verseOfDay.ts:112`). 30 s refresh (`VerseOfDayScreen.tsx:55`; `DestinationView.swift:416`). |
| C1 | Card text fallback. | `ScriptureCardUITests.testStep7CardShareTextFallbackAndImageStillWork` | `Share text instead` opens the system panel. The image share still opens after it. | The text that the panel carries (the panel shows only a preview). | Any. | Text format `<text>\n\n<ref> (<abbr>)\nJohn 1:1 · Scripture & Prayer` (`ScriptureCardView.swift`; `ShareCardScreen.tsx:43-46`). |
| C2 | PNG failure. | `testStep7CardPNGWriteFailureShowsMessageAndKeepsTextShare` | Main stops the app, then makes `<data container>/tmp` read-only (`chmod 555`). The PNG write fails. Restore with `chmod 755`. | Out-of-memory failure of the renderer. | Any. | Exact message `The card could not be shared. Please try again, or share the text.` (old `ShareCardScreen.tsx:63`). The native app must use this text after the app fix (review fix 1; native `ScriptureCardView.swift:150`). Label the result "fault-injected: tmp made read-only; task-only dev build; not a natural failure". |
| C3 | Artwork failure. | `ContentFlowUITests.testStep7BundleFaultMessage` with `artwork-ivory-missing` or `artwork-plum-missing` | Remove one card image from the dev bundle. | Nothing extra. | Any. | Message `Artwork could not load. You can still share the words on a plain background.` Same text in both apps (`ScriptureCardView.swift:71`; `ShareCardScreen.tsx:105`). |
| C4 | iPad share presentation. | `testLongCardSharePresentationOnIPadWhereSupported` (now env-gated), `testStep7CardShareTextFallbackAndImageStillWork`, and the Verse Moment test | Run on `E76B006D-2F32-4D49-98D4-9DC1F15B7EB3`. The tests log `popover=1`. | Real share targets. | Dev app on the iPad. | The share panel is a popover on iPad. Copy and Cancel work as on iPhone. |
| C5 | Owned-word points for iPad, Extra large, and the small iPhone. This also gives the L25 G3 value. | `testStep7MeasureOwnedWordPointsForCurrentDevice` | Taps a grid in each verse and logs where a selection starts. | Nothing. | Dev app. It changes Reader preferences. Reseed after. | The output gives `L25_VERSE1_TAP_OFFSET` (John 1:1) and `STEP7_IPAD_WORD_POINTS` (Psalms 2:1 and 2:12). |

### 2.3 Media

| ID | Remaining | Helper | Mechanism | Cannot prove | Seed | Expected values (source) |
| --- | --- | --- | --- | --- | --- | --- |
| M1 | Debug: inactive pause, resume, and route-exit cleanup. | `MediaNotificationUITests.testStep7DebugMediaInactiveAndRouteExitCleanup` | Needs network for the Debug sample audio (`STEP7_MEDIA_NETWORK=1`). Home, then activate. | Audio engine release, background audio, and audio route changes (physical device). | Any. | `RosaryMediaView.swift:43-51` pause on a phase change; `RosaryMediaModel.swift` `pause`, `deactivate`. Visible state only. |
| M2 | Debug: audio failure state. | `testStep7DebugMediaFailureStateWithInjectedURI` | Needs hook D1. | Real network failure types. | Any. | Button `Audio unavailable`, disabled (`RosaryMediaView.swift:168`). |
| M3 | Release: fallback UI. | `testStep7ReleaseHomeEpisodeIsExternalAndMatchesWeekday` and the existing `testReleaseUnapprovedMediaUsesExternalFallback` | Release build. Never tap the action. | Where the action goes (it opens an external site). | Any. | Exactly one external action on Rosary home: the suggested set for the weekday. Sunday glorious, Monday joyful, Tuesday sorrowful, Wednesday glorious, Thursday luminous, Friday sorrowful, Saturday joyful (`src/services/rosary/catalog.ts:233`). The two intro episodes are not reachable in Release. |
| M4 | Release: six official destinations, no sample player. | `check_media_package.py` (host) | Reads the built app. Compares the bundled catalog with `ROSARY_MEDIA_EPISODES` (`catalog.ts:190`). Searches the binaries for the two sample URLs. | That no sample player exists (a missing string is only package evidence). | Built Release app. | Six URLs: why-pray `vE247jOt4AA`, how-to-pray `HXcWknfC0vI`, joyful `ckUJRg04jyg`, sorrowful `ry7FbjkN-p0`, glorious `WoJ1hQTVdSo`, luminous `b2EjBt2PFpc`. No `videoUri` or `audioUri`. All `mediaApproved` false. |

### 2.4 Error and fallback states

All use the bundle fault injector on the task-only dev app. Run `testStep7BundleFaultMessage` with `STEP7_FAULT=<name>`. The test uses the fixed clock 2026-09-13T16:00Z Toronto.

| Fault | Expected text (source) |
| --- | --- |
| `chapter-missing` (`--edition web-ce --book JHN`) | `Chapter unavailable` and `This chapter is not available.` The Back control stays (`ReaderView.swift:676`; `ReaderScreenModel.swift:166`). |
| `rosary-catalog-invalid` | `The Rosary catalog is not available right now.` (`RosaryHomeView.swift:126`). |
| `prayer-catalog-invalid` | `The prayer library is not available.` (`PrayerHomeView.swift:118`). |
| `works-catalog-missing` | `The library could not be opened on this device.` (`WorksLibraryView.swift:75`). |
| `reading-reference-invalid` (`--date 2026-09-13`) | `This reference could not be opened. You can find the passage using Bible search.` and a `Search the Bible` button that opens Search (`CitationContextView.swift:99-100`). |
| `search-db-missing` | `Search could not be completed. Try a different phrase.` (`SearchView.swift:199`). Verify on the first run. |
| `artwork-*-missing`, `widget-*` | See C3 and W4. |

Fault labeling and evidence rules (Sol's ruling 5). Every fault result must say: "fault-injected: bundle file removed or changed; task-only dev build; not a natural failure". Record with each result:

1. The fault name, the changed files, and their SHA-256 before and after.
2. The app executable hash. The fault does not change it.
3. A `restore` that exits 0 with all hashes equal.
4. A control launch after the restore that shows the normal state.

The result proves the visible error copy and the recovery path for that code path. It does not prove how the app detects natural corruption. It does not prove Release behavior. Never apply a fault to `com.nrsv.verse`. The tool accepts only the installed copy of `com.nrsv.verse.dev` under `/CoreSimulator/Devices/<UDID>/data/Containers/Bundle/Application/`. For the PNG fault, record the `tmp` folder mode before, during (555), and after (755), with the same label.

Note: `prayer-catalog-invalid` empties `prayers`. The native validator then rejects the whole devotional catalog (`DevotionalCatalog.validate()` needs 12 prayers), so other prayer-based screens fail too. Record that in the evidence.

Other error states:

- **External URL fallbacks.** `testStep7ExternalURLFallbacksMatchSource` (case `url-fallbacks`) checks the old-app destinations (review fix 2; classification F3 below). It needs the app fix in the worktree. Fixed clock 2026-09-13, so today is Sep 13, 2026.
  - `daily` with a bad day (`2026-02-30`), a bad format (`2026-9-1`), or no date opens Today's readings for today (`src/services/companion/calendar.ts:13-18`).
  - `read` without `verse` opens the chapter at its top with no selection.
  - `read` with an empty `endVerse` selects one verse.
  - `read` with an unknown `translation` ignores that value and uses the current edition (the old route reads only `book`, `chapter`, `verse`, `endVerse`).
  - `read` with a known book and a chapter out of range (`999`, `0`), not a number (`abc`), or missing selects the Read tab and shows that book's chapter list (`src/screens/ReaderScreen.tsx:292-308`; `Number(NaN)` is invalid).
  - `read` with an unknown or missing book selects the Read tab and keeps the Reader state (`ReaderScreen.tsx:289`). The test checks the unknown book `ZZZ`.
  - An unknown host is ignored. A valid URL at the end still opens the verse.
- **Reader "passage not available in this edition"** (`ReaderScreenModel.swift:112`). No UI path creates this request with an invalid book or chapter. A saved item that cannot open does nothing (finding F2). No helper. Source only.
- **Internal invalid IDs** (prayer, novena, teaching, work, set). The app has no external route for them. Source only.
- **Saved and note load errors** (`SavedView.swift:157-466`). The Gate A damaged-library checks cover the storage side. No new helper.

### 2.5 Real notices (owned elsewhere)

`PositiveNoticeUITests`, `SystemNoticeSnapshot.swift`, and the Runtime hook belong to another agent. Source changed none of them. Items that remain, from `RemainingWidgetNoticeMediaChecks-README.md`: real permission choice, pending request fields, unrelated request preservation, disable removes only owned requests, warm tap, cold tap. The simulator can show local delivery on the real clock. It cannot show lock screen delivery or banner behavior on a locked physical device. Run these after the picker fix and the snapshot integration are accepted.

## 3. Helpers added

| File | Case name (`STEP7_CASES`) | Extra env |
| --- | --- | --- |
| `ContentFlowUITests.swift` | `verse-moment` | `STEP7_REAL_CLOCK`, `STEP7_VERSE_REFERENCE`, `STEP7_VERSE_TEXT_PREFIX`, `STEP7_VERSE_ABBREVIATION`, `STEP7_VERSE_READER_TITLE` |
| `ContentFlowUITests.swift` | `url-fallbacks` | `STEP7_REAL_CLOCK` |
| `ContentFlowUITests.swift` | `saved-open-failure` | `STEP7_SAVED_ROW_REFERENCE` (default `John 1:1`). The message is the Saved status line, identifier `saved-status` (app commit 090bf12). `STEP7_SAVED_NOTE_CASE=0` skips the note row part. |
| `ContentFlowUITests.swift` | `bundle-fault` | `STEP7_FAULT` (one name above), `STEP7_FAULT_BOOK`, `STEP7_FAULT_CHAPTER` |
| `ScriptureCardUITests.swift` | `card-text-fallback` | none |
| `ScriptureCardUITests.swift` | `card-png-fault` | none |
| `ScriptureCardUITests.swift` | `measure-word-points` | `STEP7_TEXT_SIZE="Extra large"` |
| `ScriptureCardUITests.swift` | (iPad journey, no case name) | `STEP7_IPAD_WORD_POINTS="x1,y1;x12,y12"` |
| `MediaNotificationUITests.swift` | `media-lifecycle` (Debug) | `STEP7_MEDIA_NETWORK=1` |
| `MediaNotificationUITests.swift` | `media-failure` (Debug) | `STEP7_MEDIA_HOOK_PRESENT=1` |
| `MediaNotificationUITests.swift` | `release-media-episode` (Release) | `STEP7_EXPECTED_EPISODE_TITLE` |
| `WidgetHomeScreenUITests.swift` (new) | `widget-render` | `STEP7_WIDGET_EXPECT` (strings joined by `||`), `STEP7_WIDGET_WAIT_SECONDS` |
| `WidgetHomeScreenUITests.swift` (new) | `widget-tap` | `STEP7_WIDGET_TAP_LABEL_CONTAINS`, `STEP7_WIDGET_COLD`, `STEP7_WIDGET_EXPECT_READER_TITLE`, `STEP7_WIDGET_EXPECT_VERSE`, `STEP7_WIDGET_EXPECT_DAILY_DATE` |
| `WidgetHomeScreenUITests.swift` (new) | `shared-probe` | `STEP7_PROBE_HOOK_PRESENT=1`, `STEP7_PROBE_RELATIVE_PATH` |

Existing behavior is unchanged. The iPad journey in `ScriptureCardUITests` still skips without the env value. The default `tapOwnedWord` and `openLongWebPassage` keep the 402 pt phone checks.

Host tools (`scripts/native/source-fixtures/step7/`):

- `widget-expected.ts`: expected widget values from the old source.
- `check_media_package.py --app <John.app> [--evidence-dir NEW]`: media package check. Exit 1 on a mismatch.
- `inject_bundle_fault.py list | apply | restore`: dry run by default. It accepts only `com.nrsv.verse.dev`. It needs `--apply --confirm-app-stopped` and a new backup folder below `build/native-evidence`. It saves each changed file with its SHA-256 and checks it again on restore. It uses `--udid` only for the read-only `simctl get_app_container` query. A new install also removes every fault. I tested it on a copy of the Debug app: five faults applied and restored, and the bundle was identical afterward.
- `find-unresolved-citations.ts`: lists readings that the old app cannot open. Result: none.

## 4. What the simulator cannot prove (physical-device list for S02)

1. Lock screen widget families and taps.
2. Device-signed App Group access, and widget continuity after a real update.
3. WidgetKit refresh budget and the time of a reload.
4. Real share targets (AirDrop, Messages, Files) and their results.
5. Audio route changes, interruptions, and background audio.
6. Notification delivery and tap on a locked device, and banner style.
7. VoiceOver speech, and the real Reduce Motion setting.
8. Memory and thermal behavior of the card renderer.
9. The App Group probe result on a physical device. D2 proves the simulator entitlement only.

## 5. Proposed app-side diffs (not applied)

### D1. Media failure hook (`native/John/Features/Media/RosaryMediaModel.swift`, DEBUG only)

```diff
     #if DEBUG
     private static let testVideoURI = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
     private static let testAudioURI = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"
+    /// Step 7: -L29MediaFailureURI <uri> replaces every media URI so the failure state can be observed.
+    private static let failureURIOverride: String? = {
+        let arguments = ProcessInfo.processInfo.arguments
+        guard let index = arguments.firstIndex(of: "-L29MediaFailureURI"), arguments.indices.contains(index + 1) else { return nil }
+        return arguments[index + 1]
+    }()
     #endif
@@ private func configurePlayer() {
         #if DEBUG
-        let uri: String? = directURI ?? (mode == .video ? Self.testVideoURI : Self.testAudioURI)
-        isTestSource = directURI == nil
+        let uri: String? = Self.failureURIOverride ?? directURI ?? (mode == .video ? Self.testVideoURI : Self.testAudioURI)
+        isTestSource = Self.failureURIOverride == nil && directURI == nil
         #else
```

### D2. Shared-container probe (DEBUG only)

Widget side, `native/John/Widget/JohnWidget.swift`. Call it from each `getTimeline` and `getSnapshot`.

```diff
 private enum WidgetSharedState {
     static let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? "group.com.nrsv.verse"
+    #if DEBUG
+    /// Step 7 probe. It records what the extension can reach: the group container, the shared defaults, and a file write.
+    static func recordProbe(kind: String) {
+        let defaults = UserDefaults(suiteName: appGroup)
+        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
+        var fileWrite = "no container"
+        var record: [String: String] = [
+            "kind": kind, "time": ISO8601DateFormatter().string(from: Date()), "appGroup": appGroup,
+            "defaultsAvailable": defaults == nil ? "false" : "true",
+            "containerPath": container?.path ?? "nil",
+            "translationId": defaults?.string(forKey: "translationId") ?? "nil",
+            "scope": defaults?.string(forKey: "scope") ?? "nil",
+            "intervalMinutes": String(defaults?.integer(forKey: "intervalMinutes") ?? -1),
+            "processID": String(ProcessInfo.processInfo.processIdentifier),
+        ]
+        if let container {
+            let target = container.appendingPathComponent("l29-widget-probe.json")
+            do {
+                record["fileWrite"] = "pending"
+                let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
+                try data.write(to: target, options: .atomic)
+                fileWrite = "ok"
+            } catch { fileWrite = "failed: \(error)" }
+        }
+        record["fileWrite"] = fileWrite
+        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]),
+           let text = String(data: data, encoding: .utf8) {
+            defaults?.set(text, forKey: "l29.widgetProbe")
+        }
+    }
+    #endif
```

App side, `native/John/App/Runtime.swift` (or `JohnApp.swift`). Run once after startup when the argument exists. The path must stay below Documents.

```diff
+#if DEBUG
+    /// Step 7: -L29SharedProbeRelativePath <path below Documents>. It writes one JSON file.
+    func exportSharedContainerProbe(arguments: [String] = ProcessInfo.processInfo.arguments) {
+        guard let index = arguments.firstIndex(of: "-L29SharedProbeRelativePath"), arguments.indices.contains(index + 1) else { return }
+        let relative = arguments[index + 1]
+        guard !relative.hasPrefix("/"), !relative.split(separator: "/").contains("..") else { return }
+        let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? "group.com.nrsv.verse"
+        let defaults = UserDefaults(suiteName: appGroup)
+        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
+        var widgetFile = "nil"
+        if let container, let data = try? Data(contentsOf: container.appendingPathComponent("l29-widget-probe.json")) {
+            widgetFile = String(data: data, encoding: .utf8) ?? "unreadable"
+        }
+        let record: [String: String] = [
+            "appGroup": appGroup, "defaultsAvailable": defaults == nil ? "false" : "true",
+            "containerPath": container?.path ?? "nil",
+            "translationId": defaults?.string(forKey: "translationId") ?? "nil",
+            "scope": defaults?.string(forKey: "scope") ?? "nil",
+            "intervalMinutes": String(defaults?.integer(forKey: "intervalMinutes") ?? -1),
+            "widgetProbeDefaults": defaults?.string(forKey: "l29.widgetProbe") ?? "nil",
+            "widgetProbeFile": widgetFile,
+            "appTime": ISO8601DateFormatter().string(from: Date()),
+        ]
+        let documents = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents", isDirectory: true)
+        let target = documents.appendingPathComponent(relative)
+        try? FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
+        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys, .prettyPrinted]) {
+            try? data.write(to: target, options: .atomic)
+        }
+    }
+#endif
```

Changes required by Sol's review (fix 5), to apply before Main takes the diff:

- Read `AppGroupIdentifier` from Info.plist only, in the widget and in the app. If it is missing or empty, record `"appGroup": "missing"` and write nothing. Do not fall back to `group.com.nrsv.verse`.
- App side: use `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)` and the existing `debugScenarioURL(_:under:)` for confinement. Refuse an existing output file.
- Put every `recordProbe(kind:)` call and the `exportSharedContainerProbe()` call inside `#if DEBUG`. Add no screen button.

The probe uses the Debug group (`group.com.nrsv.verse.dev`) and the names `l29-widget-probe.json` and `l29.widgetProbe`. The Release group is a separate container. The Release widget code reads neither name.

Release exclusion check (Sol's ruling 2). After the Release build, the `John` executable and the `JohnWidget.appex` executable must contain none of these strings: `-L29MediaFailureURI`, `-L29SharedProbeRelativePath`, `l29-widget-probe`, `l29.widgetProbe`, `recordProbe`. Keep a Debug positive control (the Debug build must contain them). `check_media_package.py` already searches the two sample URLs the same way. Use the same method for this list.

Read the result like this: the probe passes when `containerPath` is not `nil` in both app and widget record, the paths are equal, `widgetProbeDefaults` and `widgetProbeFile` carry the same time and values, and `fileWrite` is `ok`. A valid suite object alone proves nothing (README rule).

## 6. Seeds and state effects

| Check | Seed | State changed |
| --- | --- | --- |
| Verse Moment | Native dev, `widgetGuideDismissed` false (L25 native fixture) | Sets `widgetGuideDismissed` true. |
| URL fallbacks | Any | Opens the Reader at several chapters. Last: John 1:1. |
| Bundle faults | Any | Bundle files only. Restore after each. |
| Card checks | Any | None. |
| Word points | L25 native fixture | Text size, line spacing, typeface, layout. Reseed after. |
| Media | Any | None. |
| Widgets | L25 native fixture | Edition, scope, and interval if Main changes them. Reseed after. |

Seed the dev app with `python3 scripts/native/source-fixtures/l25/l25_fixture.py seed --only native …` (accepted tool, dry run first). Run only when Main stops the dev app. Do not seed the iPad or any other device with the old-app files.

## 7. Run order

Devices: `37D1870B-F16D-488A-8F20-959201F970D9` (iPhone 17 Pro) and `E76B006D-2F32-4D49-98D4-9DC1F15B7EB3` (iPad A16). Boot one John device at a time. Pass the explicit UDID to every command. Run tests with `-parallel-testing-enabled NO`. Times are estimates from earlier runs (route tests 13 to 31 s each; Works tail 88 s).

| Batch | Device | Content | Estimate |
| --- | --- | --- | --- |
| H1 | none (host) | `check_media_package.py` on the built Release app and the Debug app. `widget-expected.ts` for the planned instants. Record all hashes. | 10 min |
| P1 | iPhone | Seed native. `verse-moment`. `url-fallbacks` (after the app fix). `card-text-fallback`. | 10 min |
| P2 | iPhone | Faults, one at a time (run `saved-open-failure` while the `chapter-missing` JHN fault is applied): apply, run `bundle-fault`, restore. Order: `chapter-missing`, `rosary-catalog-invalid`, `prayer-catalog-invalid`, `works-catalog-missing`, `reading-reference-invalid`, `search-db-missing`, `artwork-ivory-missing`, `artwork-plum-missing`. The Scripture card still works after each restore. | 25 to 30 min |
| P3 | iPhone | `card-png-fault`: stop the app, `chmod 555` the container `tmp`, run, restore `chmod 755`. | 5 min |
| P4 | iPhone | Debug media: `media-lifecycle` (network needed). | 5 min |
| P5 | iPhone | Widgets: add the five widget instances by hand (small and medium Daily Verse, small Countdown, small and medium Daily Reading). Run `widget-render` and `widget-tap` (warm and cold). Change the edition, scope, and interval in Settings. Run `widget-render` again. Faults `widget-corpus-missing` and `widget-daily-year-missing` need an app reinstall to clear. | 40 to 60 min |
| P6 | iPhone | Word points: `measure-word-points` at Default and at Extra large. Then reseed native. Pass the offsets to the L25 route batches. | 8 min plus reseed |
| P7 | iPhone | After diffs D1 and D2 are applied: `media-failure`, `shared-probe`, then export and read the probe file. | 15 min |
| R1 | iPhone | Release build: `release-media-episode`, `testReleaseUnapprovedMediaUsesExternalFallback`. Never tap the action. | 5 min |
| I1 | iPad | Install the dev app. Seed native. `measure-word-points` (portrait). Then `card-text-fallback`, `verse-moment`, and the iPad card journey with the measured points. | 25 min |
| N1 | iPhone | Real notices (other agent's helpers) after their acceptance. | Separate plan |

Reasons for the order: P1 runs first because the Verse Moment test needs a fresh guide. P2 and P3 do not change saved state. P6 changes preferences, so it comes after the card and Verse Moment checks. P5 changes shared preferences, so it comes after P1. Each fault is restored before the next one, so a failure never hides another.

## 8. Findings and classification

Sol's classification (review, item 4):

| Finding | Old app (source) | Native | Classification |
| --- | --- | --- | --- |
| F1a PNG failure copy | `ShareCardScreen.tsx:63`: "The card could not be shared. Please try again, or share the text." | `ScriptureCardView.swift:150`: "The Scripture card could not be saved for sharing. You can share the words instead." | **Parity fault.** Fix 1 (app, worktree). The test and C2 now use the old text. |
| F1b Share-sheet error | `ShareCardScreen.tsx:134`: "The share sheet could not be opened." when `Share.share` rejects. | System `ShareLink`. It gives no failure result. | **Accepted.** No equivalent failure exists to report. |
| F2 Saved item that cannot open | `SavedScreen.tsx:61-84` pushes `/read`. The Reader switches to the Read tab. An unknown book leaves the Reader as it was (`ReaderScreen.tsx:289`). A bad chapter shows the book's chapter list (`:302-307`). No message. | `AppRouter.openSavedItem` returns. The Saved tab stays. No message. | **Decided by the user: message.** A saved passage or note that cannot open stays on Saved and shows one line: "This passage could not be opened." The app-side agent implements it. See the F2 trigger below. |
| F3 Invalid `nrsv://` URLs | Expo Router opens the route. A missing or bad `daily` date shows today's readings (`calendar.ts:13-18`). `read` uses only `book`, `chapter`, `verse`, `endVerse`. | `ExternalRouteParser` rejects the URLs. The app does not move. | **Parity fault.** Fix 2 (app, worktree). `testStep7ExternalURLFallbacksMatchSource` checks the old destinations. |
| F4 Widget tap has no edition | Old `VerseWidget.swift:191` has no `translation`. | Same. The app uses the current edition. | **Accepted source-matching behavior.** |
| F5 Release media reaches only the weekday episode | `rosary-home-screen.tsx:46-52`: same gate. | `RosaryHomeView.swift:205-243`: same gate, labels, and link. | **Accepted source-matching behavior.** Optional: add an accessibility ID to `Watch on the official site`. |

F2 trigger and seed (test `testStep7SavedOpenFailureStaysOnSavedWithMessage`, case `saved-open-failure`):

- **Primary trigger (bundle fault, no app change).** Seed the dev app with the L25 native fixture. It holds a WEB-CE John 1:1 bookmark (`web-ce:JHN:1:1:1`). Stop the app. Run `inject_bundle_fault.py apply --fault chapter-missing --edition web-ce --book JHN`. The Saved row still lists from the stored text, but the passage cannot load, so opening it fails. Label the result as fault-injected (section 2.4). Restore afterward and make a control launch.
- **Alternative trigger (damaged seed row).** Copy the closed native DB from the L25 fixture to a new folder under `build/native-evidence`. Insert one bookmark with an unknown book code, for example `sqlite3 <copy> "INSERT INTO bookmarks VALUES ('web-ce:ZZZ:1:1:1','web-ce','ZZZ','Nonexistent',999,1,'1','1',0,0,'Damaged row for the Step 7 saved-open-failure check.',1791228400000,1791228400000)"`. With the app stopped, replace `Documents/SQLite/user-library.db` in the dev container and remove any `-wal`, `-shm`, and `-journal` file. Run the test with `STEP7_SAVED_ROW_REFERENCE="Nonexistent 1:1"`. Verify on the first run that the Saved list shows the row.
- **Assertions.** The `saved-status` label equals the exact text, and the text appears once. The Saved filter controls stay hittable. No Reader screen, no note editor, and no Today screen appears.
- **Note row.** A note row now checks that its passage loads before the editor opens. A broken note shows the same line. The L25 native fixture has a note on John 1:1, so the same `chapter-missing` fault breaks both rows, and the test checks the bookmark row and then the note row. A damaged note passage (the second trigger) needs a note row with an unknown book code. Insert it into the `notes` table with the same column order as the plan's bookmark example plus a note text before the two time stamps. Other note messages are unchanged (`SavedView.swift:417-466`).

Other notes:

- **F6 Citation data.** Every installed reading resolves in the old app. The fallback appears only by fault injection.
- Optional note: in Debug the old Rosary home shows "›" for the in-app player and "↗" for the external link. The native app shows "↗" in both builds. Release matches.

## 9. Questions

1. Main must add `WidgetHomeScreenUITests.swift` to the UI test target in the generator. Confirm that you accept one new test file.
2. Do you accept the DEBUG diffs D1 and D2? Main owns the app files.
3. Accept hand-added widgets (Main uses the Simulator tool) for P5? An XCUITest that adds widgets would be fragile, so Source did not write one.
4. F2 is decided (message). Main must give the accessibility identifier of the message to the test constant.
5. Is a faulted dev bundle acceptable evidence for error states? It uses no app change, but the state is not a natural failure.
