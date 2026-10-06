# Step 7 remaining feature checks review

Date: 6 October 2026.
Reviewer: Sol (architecture, review, and acceptance).
Status: **Accepted with fixes.** The plan, the test helpers, and the host tools are accepted after the required fixes below. Two findings are parity faults in app code. One finding needs a product decision from the user.

## Reviewed boundary

Sol did not build, run a test, or use a simulator. Sol read the diffs against HEAD `2ce1700`. `PositiveNoticeUITests.swift` is out of scope.

| File | SHA-256 |
| --- | --- |
| `docs/native/reviews/Step7-remaining-feature-checks-plan.md` | `7123e59a09b360dfc77cb3233ce533f08db4bc83bf52d0bfa2d2d9e7ad764dfe` |
| `native/John/SimulatorSupport/ContentFlowUITests.swift` | `25d9fa0ada2d0a15cd9e86eaaafc37d21a9ec44f91f3d392de3921179290d54a` |
| `native/John/SimulatorSupport/ScriptureCardUITests.swift` | `d6cb656e7ba0732e5ed97e5f8ff131c0f4d92df8567fff91ce8a83a3973e8b4d` |
| `native/John/SimulatorSupport/MediaNotificationUITests.swift` | `e0f431fdbe4a5128d1309ba19f4f26476f86df990cf16b064c74769f323d9b54` |
| `native/John/SimulatorSupport/WidgetHomeScreenUITests.swift` (new) | `d6ce4966f957cd16ef81841a75f3a89f63938254dcadd908b9853c91e511a48a` |
| `scripts/native/source-fixtures/step7/inject_bundle_fault.py` | `195ef3c1ecd25f955ff1b9fd01e3190bf88000af241807a2a8742359236809f1` |
| `scripts/native/source-fixtures/step7/check_media_package.py` | `375739aede4c1c9376774a0b028331281a524cbab90702ba6b51579858045b08` |
| `scripts/native/source-fixtures/step7/widget-expected.ts` | `f3b4ed99a15a8966bcc79ac9c231ac2e8416e5822863a9a9f56dab121a71a69c` |
| `scripts/native/source-fixtures/step7/find-unresolved-citations.ts` | `3807d29ee208d05a03118192dbf45f0d68267a970764a8667f7fd31d2e498c80` |

## Type check

Sol type-checked all 13 `SimulatorSupport/*.swift` files together with Swift 6.3.3, `-swift-version 6`, `-target arm64-apple-ios26.0-simulator`, and the XCTest search paths. Both runs exit 0: with `-DDEBUG` and without it. The only warning is the existing one at `WorksSettingsUITests.swift:184`.

## Default behavior

- Every new Step 7 method calls `requireStep7(_:)` first. It throws `XCTSkip` unless `STEP7_CASES` lists the case. This applies to all three changed files and to the new widget file.
- The iPad card journey still skips without `STEP7_IPAD_WORD_POINTS`.
- `openLongWebPassage`, `setReadingProfile`, and `tapOwnedWord` keep their earlier defaults: the Psalms 2 points (88, 19) and (96, 28), the Default text size, and the 402 pt iPhone assertions.
- The Release media method is under `#if !DEBUG`. The Debug media methods are under `#if DEBUG`.

Default runs are unchanged.

## Owned-glyph rule

- The new iPad path taps measured offsets only. It turns off the 402 pt assertion only when points are supplied.
- `testStep7MeasureOwnedWordPointsForCurrentDevice` taps a grid. It counts a point when `reader-selection-summary` appears. A tap on blank space does not select, so a blank point is not counted. **Gap:** the method does not check which verse was selected. See required fix 4.
- Verse Moment "Read in context" and the widget tap check a selection that the app makes. They tap no text.

## Expected values and source lines

Sol opened these cited lines. All match: `bibleService.ts:63` (`getCurrentVerse`), `verseOfDay.ts:112` (`formatVerseForShare`), `VerseOfDayScreen.tsx:21`, `:29`, `:55`, `:115`, `:118`, `catalog.ts:190`, `:233`, `ShareCardScreen.tsx:43–46`, `:63`, `:105`, `:134`, old `VerseWidget.swift:191`, `:341`, old `DailyReadingWidget.swift:47`, `Runtime.swift:1001`, and native `ScriptureCardView.swift:71`, `:150`.

The fault expectations match the native validators. `RosaryCatalogModels.swift:9–18` requires the six episode IDs, so an empty `mediaEpisodes` fails. `DevotionalCatalog.validate()` requires 12 prayers, so an empty `prayers` fails. The second fault makes the whole devotional catalog invalid, not only the prayer list. Record that in the evidence.

## Fault injection tool

| Check | Result |
| --- | --- |
| Dev bundle only | Yes. `CFBundleIdentifier` must be `com.nrsv.verse.dev`, on both apply and restore. |
| Dry run by default | Yes. Apply needs `--apply --confirm-app-stopped`. |
| Backup | Each changed file is copied to a new folder below `build/native-evidence`, with SHA-256 before and after. |
| Restore | The backup hash is checked before the copy. **Gap:** a hash mismatch after the copy prints `MISMATCH` but the exit code stays 0. See required fix 3. |
| Target path | **Gap:** `--app-bundle` accepts any `.dev` bundle, also a DerivedData build product. A fault there would change the evidence binary for later installs. See required fix 3. |
| `simctl` | Only `get_app_container … app` with `--udid`. No boot, install, launch, or stop. |

## Simulator and S02 split

Section 4 of the plan is accepted. It sends these to the S02 physical-device list: lock-screen families and taps, device-signed App Group access and widget continuity after an update, the WidgetKit reload budget, real share targets, audio routes, interruptions and background audio, locked-device notices, VoiceOver speech and the real Reduce Motion setting, and renderer memory. Add one item: the App Group probe result on a device (D2 proves the simulator entitlement only).

## Rulings

### Ruling 1: new test file `WidgetHomeScreenUITests.swift`

**Accepted.** Add it only to the `SimulatorSupport` list of the UI test target in `scripts/native/project/generate-xcodeproj.py`. Regenerate the project. Do not add it to the app or widget target. All three methods are gated by `STEP7_CASES`. The file never adds or removes a widget.

### Ruling 2: DEBUG diffs D1 and D2

**D1 accepted as written.** Both hunks are inside the existing `#if DEBUG` blocks of `RosaryMediaModel.swift`. The Release branch of `configurePlayer()` does not change.

**D2 accepted with three changes** (required fix 5). The probe writes `l29-widget-probe.json` and the defaults key `l29.widgetProbe` only in the Debug group (`$(APP_GROUP_IDENTIFIER)` = `group.com.nrsv.verse.dev`). The Release widget code reads neither name. The Release group is a separate container. With the changes below, D2 cannot change Release widget behavior.

Release exclusion check after the build: the Release `John` executable and `JohnWidget.appex` executable must contain no `-L29MediaFailureURI`, `-L29SharedProbeRelativePath`, `l29-widget-probe`, `l29.widgetProbe`, or `recordProbe` string. Keep a Debug positive control.

### Ruling 3: widgets added by hand with the Simulator tool

**Accepted, on the dedicated John device only.** XCUITest cannot add widgets reliably. Main adds them through SpringBoard with tap and swipe. Required evidence for each session:

1. The device UDID, the installed dev app and widget executable hashes, and the host time and time zone.
2. A screenshot of the home screen before the edit.
3. For each instance: a screenshot of the widget gallery entry with its name and size, and a screenshot after placement. Record kind, size, page, and slot.
4. A final home-screen screenshot and the `widget-render` label dump.
5. The `widget-expected.ts` output for the capture instant, with the command line.
6. After a reinstall (needed to clear widget faults), check again that each instance still exists, or add it again with the same evidence.
7. Do not move or remove other home-screen items. Do not add widgets of other apps.

### Ruling 5: faulted dev bundle as evidence for error states

**Accepted, with labeling and limits.** Each fault record must state "fault-injected: bundle file removed or changed; task-only dev build; not a natural failure". Required with each result:

1. The fault name, the changed files, and their SHA-256 before and after.
2. The app executable hash, unchanged by the fault.
3. A restore that exits 0 with all hashes equal (after required fix 3).
4. A control launch after the restore that shows the normal state.

The result proves the visible error copy and the recovery path for that code path. It does not prove how the app detects natural corruption. It does not prove Release behavior. Never apply a fault to `com.nrsv.verse`. Use the same label for the `tmp` `chmod 555` PNG fault. Record the folder mode before, during, and after (755).

## Item 4: classification of findings

| Finding | Old app (source) | Native | Classification |
| --- | --- | --- | --- |
| F1a PNG failure copy | `ShareCardScreen.tsx:63`: "The card could not be shared. Please try again, or share the text." | `ScriptureCardView.swift:150`: "The Scripture card could not be saved for sharing. You can share the words instead." | **Parity fault.** Required fix 1. |
| F1b Share-sheet error | `ShareCardScreen.tsx:134`: "The share sheet could not be opened." when `Share.share` rejects | System `ShareLink` | **Accepted.** `ShareLink` gives no failure result. No equivalent failure exists to report. |
| F2 Saved item that cannot open | `SavedScreen.tsx:61–84` pushes `/read`. The Reader switches to the Read tab. An unknown book leaves the Reader as it was (`ReaderScreen.tsx:289`). A bad chapter shows the book's chapter list (`:302–307`). No message. | `AppRouter.openSavedItem` returns. The Saved tab stays. No message. | **Product decision.** See below. |
| F3 Invalid `nrsv://` URLs | Expo Router opens the route. `daily` with a missing or bad date shows today's readings (`calendar.ts:13–18`). `read` uses only `book`, `chapter`, `verse`, `endVerse` and ignores `translation`. | `ExternalRouteParser` rejects all nine test URLs. The app does not move. | **Parity fault.** Required fix 2. ADR 0002 also asks for "a recoverable destination". |
| F4 Widget tap has no edition | Old `VerseWidget.swift:191` has no `translation`. | Same. The app uses the current edition. | **Accepted source-matching behavior.** |
| F5 Release media reaches only the weekday episode | `rosary-home-screen.tsx:46–52`: Release opens the suggested episode's official URL. Intro episodes have no Release entry. The "More from the series" link opens wordonfire.org. | `RosaryHomeView.swift:205–243`: same gate, same labels, same link. | **Accepted source-matching behavior.** Optional: add an accessibility ID to "Watch on the official site". |

**F2 recommendation.** Saved rows keep their saved edition in the native app (accepted correction). Bundled data does not change, so a saved item fails to open only when local data is damaged. Two choices:

- (a) Copy the old fallback: select the Read tab. Show the chapter list when the book exists in that edition.
- (b) Stay on Saved and show one line: "This passage could not be opened."

Sol recommends (b). The old fallback gives the user no reason for the jump. A short message is clearer. The user decides. Until then, the current no-op stays, and the plan records it as open.

## Required fixes

1. **`native/John/Features/Sharing/ScriptureCardView.swift`, line 150.** Set `shareError` to `"The card could not be shared. Please try again, or share the text."`. Update `ScriptureCardUITests.swift` (`testStep7CardPNGWriteFailureShowsMessageAndKeepsTextShare`, the `XCTAssertEqual(error.label, …)` line) and plan item C2 to the same text.

2. **`native/John/Platform/Navigation/ExternalRouteParser.swift` and `AppRouter.receive`.** Match the old route results:
   - `daily` with no `date`, or a date that fails the old `parseDate` check: open Daily for today in the current time zone.
   - `read` without `verse`: open the chapter at its top with no selection.
   - `read` with an empty `endVerse`: treat it as absent.
   - `read` with an unknown `translation`: ignore the value and use the current edition. Keep the native support for a valid value.
   - `read` with a known book and a chapter out of range: select the Read tab and show that book's chapter list.
   - `read` with an unknown book or a non-number chapter: select the Read tab. Change nothing else.
   - A URL with another scheme or host: ignore it (unchanged).

   Rewrite `ContentFlowUITests.testStep7InvalidExternalURLsAreIgnored` to check these results. Rename it, for example `testStep7ExternalURLFallbacksMatchSource`. Keep the final valid-URL check.

3. **`scripts/native/source-fixtures/step7/inject_bundle_fault.py`.**
   - In `cmd_restore`, count a post-copy hash mismatch as a problem, so the exit code is 1.
   - In `resolve_app`, require the resolved path to contain `/CoreSimulator/Devices/` and `/data/Containers/Bundle/Application/`. With `--udid`, also require `/Devices/<UDID>/`. Add `--allow-noninstalled-bundle` for host tests only. Refuse it together with `--udid`.

4. **`ScriptureCardUITests.swift`, `probeOwnedWordPoints`.** Pass the expected verse number. Count a point only when `reader-selection-summary` has the label `Selected: verses N–N` for that verse. Log any other selection as `wrong-verse` and do not count it. Use N = 1 for John 1:1, 1 for Psalms 2:1, and 12 for Psalms 2:12.

5. **D2, before Main applies it.**
   - Widget and app side: read `AppGroupIdentifier` from Info.plist only. If it is missing or empty, record `"appGroup": "missing"` and write nothing. Do not fall back to `group.com.nrsv.verse`.
   - App side: use `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)` and the existing `debugScenarioURL(_:under:)` for confinement. Refuse an existing output file.
   - Put every `recordProbe(kind:)` call and the `exportSharedContainerProbe()` call inside `#if DEBUG`.

6. **Plan updates.**
   - Section 8: record the classifications above.
   - W5: run the `shared-probe` launch twice. Pass only if both records show the same non-nil container path, `fileWrite` is `ok`, and the second record's widget probe time is later than the first record's `appTime`.
   - Section 5: add the Release exclusion string list from ruling 2.
   - Section 2.4: add the fault label from ruling 5 and the note that `prayer-catalog-invalid` makes the whole devotional catalog invalid.
   - Section 4: add the device App Group probe.

## Optional notes

1. In Debug, the old Rosary home shows "›" for the in-app player and "↗" for the external link. The native app shows "↗" in both builds. Release matches.
2. The widget tap test uses the real clock. Record the capture instant with each widget result, because the verse slot depends on it.
