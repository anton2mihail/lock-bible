# L22 system notice snapshot review

Date: 6 October 2026.
Reviewer: Sol (architecture, review, and acceptance).
Status: **Accepted with fixes.** Source inclusion is accepted after the three required fixes below. Runtime evidence remains open.

## Reviewed boundary

Sol reviewed the files at HEAD `f135454` with these working-tree changes. Sol did not build the app, run a test, or use a simulator. Sol did not change product code.

| File | State | SHA-256 |
| --- | --- | --- |
| `native/John/App/Runtime.swift` | Modified | `cfc1f7589ea2896c82e17eaad9ea8ea0eb48cf5e37007c44182f3259aabcdc56` |
| `scripts/native/source-fixtures/notifications/SystemNoticeSnapshot.swift` | Untracked | `3ed1fffc6235eeda26022bac7e315f7312188f59685439139326c88737ae4cb7` |
| `scripts/native/source-fixtures/notifications/SystemNoticeSnapshot-README.md` | Untracked | `df1a7c15ed026ccece7c15e37f6ebd0f1cd3aba2a5c4909c1f5697c954f24767` |

These three hashes match the stop-state hashes in `docs/native/handoff-2026-10-06.md`.

Main changed these files in parallel during the review. Sol read them for context only. They are not accepted by this document.

| File | SHA-256 at read time |
| --- | --- |
| `scripts/native/project/generate-xcodeproj.py` | `9949492f6e00cf57cd12093aa1a9484f7fb760d578c0b0d4a8a7ff908a9a800b` |
| `native/John/SimulatorSupport/PositiveNoticeUITests.swift` | `91c56f497ae00ab217ff87618483c73016fa82519552af7f2615f75de76f4803` |
| `native/John/SimulatorSupport/PositiveNoticeUITests-README.md` | `09151e4dcfe7b61dbfbaf2b9ec5c3caf40f19d30f7e240040881496f8ef94e39` |

## Type checks

Toolchain: Apple Swift 6.3.3 (`swiftlang-6.3.3.1.3`). Simulator SDK: 26.5.

Command 1, with DEBUG:

```text
xcrun --sdk iphonesimulator swiftc -typecheck -swift-version 6 -target arm64-apple-ios26.0-simulator -D DEBUG scripts/native/source-fixtures/notifications/SystemNoticeSnapshot.swift
```

Result: exit 0. Two warnings, no errors:

```text
SystemNoticeSnapshot.swift:187:39: warning: 'summaryArgument' was deprecated in iOS 15.0: summaryArgument is ignored [#DeprecatedDeclaration]
SystemNoticeSnapshot.swift:188:44: warning: 'summaryArgumentCount' was deprecated in iOS 15.0: summaryArgumentCount is ignored [#DeprecatedDeclaration]
```

Command 2, without DEBUG (same command without `-D DEBUG`): exit 0. No output. The file compiles to no declarations.

Swift 6 language mode enables complete strict-concurrency checks. The project also sets `SWIFT_STRICT_CONCURRENCY = complete` and `SWIFT_VERSION = 6.0`. The project does not set default MainActor isolation. The check flags therefore match the app target.

Sol did not type-check `Runtime.swift`. It depends on JohnCore and on the full app target. Main's Debug build and a Release build are the compile checks for it.

Sol ran a separate macOS probe of the `TypedValue` enum (copied lines 363–462). Results:

- `true` encodes as `bool`. `42` and `-5` encode as `integer`. `UInt64.max` encodes as `unsigned`. `1.5` and a `Float` encode as `number`.
- `Double.nan` and `+infinity` encode as `unavailable` with reason `Non-finite number is not valid JSON`.
- `Date`, `Data`, and a dictionary with `Int` keys encode as `unavailable` with their source type.
- Nested arrays, objects, and `NSNull` encode correctly. A binary property-list integer encodes as `integer`.
- Every sample decodes back to an equal value.
- `String(reflecting: type(of: trigger))` gives `UNCalendarNotificationTrigger` for a calendar trigger.

## Contract check

| Requirement | Result |
| --- | --- |
| `try await SystemNoticeSnapshot.capture()` | Present. `@MainActor`, `async throws`, returns `Report`. |
| `try SystemNoticeSnapshot.encode(report)` | Present. Sorted keys, pretty print, no slash escapes. |
| Reads the actual center | Yes. `UNUserNotificationCenter.current()`, `notificationSettings()`, `pendingNotificationRequests()`. |
| No permission request or request change | Yes. The file has no `requestAuthorization`, `add`, `remove…`, category, badge, or delegate call. |
| Settings fields | Authorization and 14 settings, each as a named string. Unknown raw values stay visible. |
| Pending request fields | Identifier, content, typed `userInfo`, badge, sound kind, attachments, trigger kind, trigger class, repeats, date components, interval, region, and next date. Requests sort by identifier. |
| All code under `#if DEBUG` | Yes. Lines 1 and 471 wrap the full file. |
| No normal-screen export button | Yes. No view code calls the helper. |
| No Release hook | Yes. See "Release exclusion". |

### Earlier corrections

1. **Actual trigger class: applied.** Line 250 sets `triggerClassName` from the dynamic type of the trigger. `kind` stays a logical name. A subclass of a known trigger keeps the logical kind and shows its real class. An unknown trigger uses its class name as `kind` and lists `unrecognizedTriggerPublicFields`.
2. **Neutral archive-unavailable text: applied.** Lines 131–143 store the raw archive error and the field name `secureArchive`. The text does not state that the request is invalid. README line 18 limits the archive to evidence only when it succeeds. Public-field gaps stay in the content and trigger lists.
3. **Explicit non-finite numbers: applied for `userInfo` and badge.** Line 388 maps a non-finite `NSNumber` to `unavailable`. The probe above confirms this. Other `Double` fields have no guard. See optional note 2.

## Runtime integration check

| Item | Result |
| --- | --- |
| Launch argument | `-L22NoticeSnapshotRelativePath <value>`, lines 285–288. No argument means no work. |
| Path confinement | `debugScenarioURL` (line 685) rejects an empty path, a leading `/`, and any `..` component. It then requires the resolved path to be inside the resolved Documents folder. This is the accepted L04 helper. |
| Ordering | `noticeSnapshotSequence` increments on the MainActor before any suspension (line 290). Each new `Task` waits for the previous task (lines 292–303). Each caller waits for its own task. Order is correct. |
| Atomic stage write | Line 356 uses `.atomic`. A partial file cannot appear. Same-name replacement is possible. See required fix 1. |
| Envelope path | `Application Support/John/native-state-v1.json` (line 322). This matches `NativeStateStore.primaryURL`. |
| Envelope linkage | The envelope read (line 327) and the `committedStateRevision` read (line 340) have no suspension point between them. The stage stores the raw bytes as Base64 and their SHA-256. It does not store the decoded envelope revision. See integration requirement 6. |
| Startup stage | Line 189. Only after a successful envelope load. It runs before `refreshLocalNotifications()`. It therefore shows the pre-refresh pending set. |
| Calendar save stages | Lines 887–901. `success` after return. `failure` after a throw, then the error is thrown again. |
| Rosary save stages | Lines 903–917. Same pattern. |
| Missing service | The `guard let noticeService` throw comes before the `do` block. It writes no stage. The system center does not change in this case. This is acceptable. |
| Release exclusion | `CryptoKit` import (lines 6–8), the two stored properties (66–69), the startup call (188–190), the stage type and two methods (inside 266–737), and the four save-path calls (891–898, 907–914) are all under `#if DEBUG`. No other line refers to the new members. |
| Concurrency | `JohnRuntime` is `@MainActor`. The task closure is `@MainActor` and captures only `Sendable` values and `weak self`. `Report` and all nested types are `Codable` and `Sendable` value types. `SystemNoticeRuntimeStage` is encoded on the MainActor. Sol found no isolation fault. |

## Required fixes

1. **`native/John/App/Runtime.swift`, lines 354–356. Do not replace an earlier stage file.**
   The sequence starts at 1 in each process. A second launch with the same relative path writes `001-startup-loaded.json` again. The `.atomic` write then replaces the earlier evidence without an error. Put the process ID in the name. Refuse an existing file. Replace lines 354–356 with:

   ```swift
   let filename = String(format: "%03llu-%@-%@-p%d.json", sequence, safePhase, safeOutcome, getpid())
   let outputURL = outputRoot.appendingPathComponent(filename, isDirectory: false)
   guard !FileManager.default.fileExists(atPath: outputURL.path) else {
       throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: outputURL.path])
   }
   try data.write(to: outputURL, options: .atomic)
   ```

   The existing `catch` at line 359 logs the refusal. Keep `.atomic`. Do not combine it with `.withoutOverwriting`; Foundation does not permit that pair.

2. **`scripts/native/source-fixtures/notifications/SystemNoticeSnapshot.swift`, lines 291–330. Record all `DateComponents` fields.**
   README line 16 states "all `DateComponents` fields". The iOS 26 SDK also has `dayOfYear` and `isRepeatedDay`. Sol confirmed both with a type check at `arm64-apple-ios26.0-simulator`. Add:
   - after line 296: `let dayOfYear: Int?`
   - after line 306: `let isRepeatedDay: Bool?`
   - after line 316: `dayOfYear = value.dayOfYear`
   - after line 326: `isRepeatedDay = value.isRepeatedDay`

   Keep `schemaVersion` 1. No stage file exists yet.

3. **`scripts/native/source-fixtures/notifications/SystemNoticeSnapshot-README.md`, line 12. Document the actual stage-file contract.**
   `PositiveNoticeUITests-README.md` sends the reader to this README "for the file contract". Line 12 does not describe the Runtime output. It says Main saves `data` and writes the hash beside it. Runtime instead embeds `Report` in a stage file. Replace line 12 with a section "Runtime stage files" that states:
   - Runtime embeds `Report` as `systemSnapshot` in one stage file. It does not call `encode(_:)`.
   - Activation: the launch argument pair `-L22NoticeSnapshotRelativePath <relative path>`, in DEBUG builds only.
   - Location: `<app Documents>/<relative path>/`. A rejected path writes no file.
   - File name: `NNN-<phase>-<outcome>-p<PID>.json`. `NNN` is the zero-padded in-process sequence. A file that exists is not replaced.
   - Phases and outcomes: `startup-loaded` (before the startup notification refresh), `calendar-save-success`, `calendar-save-failure`, `rosary-save-success`, `rosary-save-failure`.
   - Stage fields: `schemaVersion`, `bundleIdentifier`, `processIdentifier`, `sequence`, `phase`, `outcome`, `capturedAtUTC`, `committedStateRevision`, `nativeEnvelopeBase64`, `nativeEnvelopeSHA256`, `nativeEnvelopeError`, `systemSnapshot`, `systemSnapshotError`.
   - The envelope is the primary file `Application Support/John/native-state-v1.json`. The SHA-256 is over those exact bytes.
   - The stage file does not prove delivery, a user tap, or durable success by itself.

After these fixes, Source sends the new SHA-256 values and repeats both type-check commands. Sol then checks the three changes only.

## Optional notes

1. Runtime can decode the envelope `revision` from the bytes it read and store `nativeEnvelopeRevision`. This makes the linkage visible without an offline decode. Integration requirement 6 covers the same check offline.
2. `relevanceScore`, `timeIntervalSeconds`, `centerLatitude`, `centerLongitude`, and `radiusMeters` have no non-finite guard. `JSONEncoder` throws on such a value. The full stage file, with the envelope, is then lost. The app does not create such values. A small `finite(_:)` helper can map them to `nil` and add a field name to `unavailableFields`.
3. Runtime lines 318, 329, and 361 use `error.localizedDescription`. `String(describing: error)` keeps the error domain and code. The helper already uses that form.
4. Runtime line 312 uses `ISO8601DateFormatter()` without fractional seconds. The helper uses fractional seconds. The same format makes the times easier to compare.
5. The startup-failure branches (lines 161–177) write no stage. A post-refresh `startup-refresh` stage would also show the result of the startup refresh. Neither is necessary for the two current journeys.
6. Lines 285–288 return without a log when the path is rejected. One `NSLog` line would make a lost-evidence cause visible. The L04 probe already logs a rejection.
7. Lines 187–188 have a `#endif` and `#if DEBUG` next to each other. They can merge. The new directives are at column 0. Nearby directives are indented.
8. The two deprecation warnings are harmless. The project does not treat warnings as errors. The fields record values that iOS ignores. Keep them or remove them; both are acceptable.
9. `TypedValue.unavailable` writes the source type under the JSON key `value`. A key such as `sourceType` is clearer. Change it only together with a schema version change.
10. The generator adds the file reference without a `PBXGroup`. The L09 and L10/L11 fixtures use the same pattern. This has no build effect.
11. A save stage is captured after the save returns. It is not atomic with the save. A lifecycle refresh can run between them. Use the stage time and the app log order when a result is unexpected.

## Integration requirements for Main

1. **Target membership.** Add `SystemNoticeSnapshot.swift` to the `John` app target Sources phase only. Do not add it to `JohnWidget`, `JohnLegacyAdapter`, or the UI test target. Use the existing source-fixture pattern in `scripts/native/project/generate-xcodeproj.py` (a `SOURCE_ROOT` reference to `../../scripts/native/source-fixtures/notifications/SystemNoticeSnapshot.swift`, plus `app_source_builds.extend`). Main's in-flight generator and `project.pbxproj` changes follow this pattern. The build file is in the app Sources phase `BFF3D44AAF6E7DB1D3C8B0E4`. Regenerate the project from the generator. Do not hand-edit only the `.pbxproj`.
2. **Release exclusion method.** Use the same method as the L04, L09, and L10/L11 fixtures. The file stays in the target for both configurations. The whole file is inside `#if DEBUG`. Only the Debug configurations set `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)"`. Do not add `DEBUG` to any Release configuration. At the next Release build, confirm that the Release executable contains no `SystemNoticeSnapshot`, `L22NoticeSnapshotRelativePath`, or `John L22 system notice snapshot` string. Record that check under Gate E Debug exclusion.
3. **Compile checks.** Build Debug with all three required fixes present. Also build Release once before acceptance of the boundary. Record the Runtime, helper, app executable, Debug dylib, and UI test executable hashes.
4. **Launch argument in the UI test.** Keep `L22_NOTICE_SNAPSHOT_RELATIVE_PATH` as a required test environment value. Append `["-L22NoticeSnapshotRelativePath", value]` to `launchArguments` before `app.launch()`. Use a fresh relative path for each test method, for example `L22/system-notice/<run-id>/<method>`. The value must not be empty. It must not start with `/`. It must not contain a `..` component.
5. **Expected output files.** With required fix 1, each method writes these files in the snapshot folder. `<PID>` is the app process ID.
   - `testAuthorizedCalendarAndRosaryNoticeSettings` (six files):
     - `001-startup-loaded-p<PID>.json`
     - `002-calendar-save-success-p<PID>.json` (Calendar on at 09:15)
     - `003-rosary-save-success-p<PID>.json` (weekly Monday 08:30)
     - `004-rosary-save-success-p<PID>.json` (daily 08:35)
     - `005-rosary-save-success-p<PID>.json` (Rosary off)
     - `006-calendar-save-success-p<PID>.json` (Calendar off)
   - `testFreshUndeterminedCalendarPermissionDenialKeepsSettingOff` (two files):
     - `001-startup-loaded-p<PID>.json`
     - `002-calendar-save-failure-p<PID>.json`

   A missing, extra, or out-of-order file fails the evidence check. All files of one method must have the same `processIdentifier` and `bundleIdentifier`.
6. **Envelope linkage check.** For each stage, decode `nativeEnvelopeBase64`. Recompute its SHA-256 and compare it with `nativeEnvelopeSHA256`. Read the `revision` field and compare it with `committedStateRevision`. A difference fails that stage. A `nativeEnvelopeError` or `systemSnapshotError` also fails that stage unless the test expects it.
7. **Export.** Copy the snapshot folder out of the app data container after each method. Do this before any reset, uninstall, or reinstall. Record the SHA-256 of each copied file and the launch record.
8. **Limits.** These files prove pending requests and settings at capture time only. They do not prove delivery, a warm or cold tap, or permission persistence outside the tested process. Those checks remain open.

## Fix re-check

Date: 6 October 2026. Sol re-checked only the three required fixes and Main's integration diff. Sol did not build, run, or change product code.

| File | SHA-256 |
| --- | --- |
| `native/John/App/Runtime.swift` | `284001b3028d867bf5b27d00d29728496ab79c8201a3edd0776dc1cb38469ed0` |
| `scripts/native/source-fixtures/notifications/SystemNoticeSnapshot.swift` | `33eba36e3fadf2b65493dadf407edc423a41836c0ccb3f6a2dc95da704eb362d` |
| `scripts/native/source-fixtures/notifications/SystemNoticeSnapshot-README.md` | `513fb6e2bfc973df3f2b2da05d78fc9b9619cd86b9c4ad262e0be9b63122fb27` |

The measured hashes match the hashes that the coordinator sent.

1. **Fix 1: accepted.** Runtime line 354 uses `"%03llu-%@-%@-p%d.json"` with `getpid()`. Lines 356–358 throw `CocoaError(.fileWriteFileExists)` when the file exists. Line 359 keeps the `.atomic` write. The existing `catch` logs the refusal. The Runtime diff grew from +132 to +135 lines. No other Runtime line changed.
2. **Fix 2: accepted.** `ComponentsSnapshot` declares and assigns `dayOfYear` and `isRepeatedDay`. The file has 475 lines (471 + 4).
3. **Fix 3: accepted.** README line 12 now states that Runtime does not call `encode(_:)`. The new "Runtime stage files" section gives the activation argument, location, rejection rule, file name, no-replace rule, phases, stage fields, envelope path, limits, and the export rule.

Sol repeated both type checks on the new helper:

- With `-D DEBUG`: exit 0. Only the two known warnings at lines 187 and 188 (`summaryArgument`, `summaryArgumentCount`).
- Without DEBUG: exit 0. No output.

**Fix verdict: Accepted.**

### Integration review

| File | SHA-256 | Result |
| --- | --- | --- |
| `scripts/native/project/generate-xcodeproj.py` | `9949492f6e00cf57cd12093aa1a9484f7fb760d578c0b0d4a8a7ff908a9a800b` | Accepted. Adds one `SOURCE_ROOT` reference and one app build file. Uses the L09 and L10/L11 pattern. |
| `native/John/John.xcodeproj/project.pbxproj` | `779203719c38f0571969792ad577a892a6ee3df050abfc10c764f6b44cc4cf97` | Accepted. Build file `2B5865736DF15360F76164A8` is in the John app Sources phase `BFF3D44AAF6E7DB1D3C8B0E4` only. No other target changes. |
| `native/John/SimulatorSupport/PositiveNoticeUITests.swift` | `91c56f497ae00ab217ff87618483c73016fa82519552af7f2615f75de76f4803` | Accepted. `L22_NOTICE_SNAPSHOT_RELATIVE_PATH` is required. `requiredEnvironment` rejects a missing or empty value. The test appends the argument pair before `app.launch()` and logs the path. |
| `native/John/SimulatorSupport/PositiveNoticeUITests-README.md` | `09151e4dcfe7b61dbfbaf2b9ec5c3caf40f19d30f7e240040881496f8ef94e39` | Accepted. It states the value, the fresh path for each method, and the preflight failure. |

Build record `build/native-evidence/L22/DerivedData-notice-snapshot-01/build-record.txt` (SHA-256 `43be0430ed99ff00e2e1679d9e9ce59183b91cd623d3aafdf958a24908842f56`):

- The record lists the pre-fix hashes `cfc1f758…` and `3ed1fffc…`. Its binaries do not contain the three fixes. They cannot be used for runtime evidence.
- Debug build-for-testing and Release build both succeeded. The Debug log shows only the two known helper warnings for the reviewed files.
- Sol checked the Release executable independently. Its SHA-256 `9811092e9b164cc8365df4930d39a3dec36f71e77ed28423b7489d61808c84b8` matches the record. `strings -a` over all bundle files finds 0 matches for `John L22 system notice snapshot`, `SystemNoticeSnapshot`, `L22NoticeSnapshotRelativePath`, and `nativeEnvelopeSHA256`.
- The Release executable links `CryptoKit.framework`. This is not caused by this change. `LegacyAdapter/LegacyMMKVReader.swift` and JohnCore `SQLitePrivateReadCopy.swift` import CryptoKit outside DEBUG.

**Integration verdict: Accepted.** No source change is required.

Conditions for the rebuild:

1. Rebuild Debug and Release from the post-fix hashes above. Write a new build record. Do not overwrite `DerivedData-notice-snapshot-01`.
2. Repeat the Release exclusion check. Add the string `John L22 system notice snapshot` to the checked list. Keep the Debug positive control.
3. Use only the new binaries for the two notice methods. Then apply integration requirements 4–8 above.

Optional: README line 22 says "Do not add this source to a Release target". The file is in the single app target for both configurations. It compiles to nothing in Release. A clearer form is "Do not define `DEBUG` in a Release configuration".
