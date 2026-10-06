# S02 physical-device checklist review

Date: 6 October 2026.
Reviewer: Sol (architecture, review, and acceptance).
Status: **Accepted with fixes.** The checklist is complete for the S02 scope after the required fixes. No device result is accepted here.

## Reviewed file

| File | SHA-256 | Commit |
| --- | --- | --- |
| `docs/native/reviews/S02-physical-device-checklist.md` | `f1d23dbac34979048cc789af0d32575accaf1e7a2196b56689972bb38c1252b2` | draft `fc1d888` |

Sol checked the `devicectl` syntax with the help pages of this Mac only (`xcrun devicectl --version`: `518.33`). Sol connected no device and ran no device command.

## 1. Completeness

| Device item from the reviews | Checklist item | Result |
| --- | --- | --- |
| VoiceOver speech | D09 | Covered |
| Real Reduce Motion | D09 step 11 | Covered |
| Largest Dynamic Type | D08 | Covered |
| Signed same-ID update, imported data, installed widget continuity | D03 | Covered |
| Device-signed App Group access | D03 step 6 (production group, behavior); D12 (dev group, probe) | Covered. D12 can stay optional, because D03 step 6 tests the production group. |
| Notification delivery on a locked phone, banner, warm and cold tap | D04, D05 | Covered |
| Imported legacy Rosary request (L22 open item 1) | D03 step 7 | **Partly covered.** See required fix 4. |
| Lock-screen widget families and taps | D10 | **Not all families.** See required fix 3. |
| WidgetKit refresh budget | D10 step 5 (observation) | Covered |
| Real share targets; renderer memory and heat | D06 | Covered (pass rule fix 5) |
| Lifecycle clearing (Confession) | D07 | Covered |
| Audio routes, interruptions, background audio | D13 (optional, Debug) | Covered as optional. The Release build has no in-app player, so Release behavior does not depend on it. |
| Offline under Airplane Mode | D14 (conditional on M1) | Covered |
| Release media gate on device | D11 | Covered |
| Signing and entitlements | Section 3 item 8 (`--stage export`, C09) | Covered |
| Foreground, time-zone, and significant-time refresh; later permission change; real DST; 30 notices over days; device performance | Section 7 (outside the session) | Recorded as open. Accepted. |

## 2. Safety of the same-ID update

The main risk is the user's real data on a real phone. The facts:

- The native app reads the old MMKV and the old library and does not change them during the import (L27 host evidence: main file, WAL, and MMKV stay byte-identical). Later native writes (new bookmarks, highlights, notes) go into the same `user-library.db`.
- The App Store build can be installed again over a TestFlight build. iOS keeps the data container. The old app would then see its own data plus any rows that the native app added. A return is therefore possible, but it is not a tested path. Native-only state (`Application Support/John`) stays in the container.
- An encrypted Finder backup is a full restore path, but it restores the whole phone.

Ruling:

1. **Preferred:** a spare iPhone with the live 1.5.0 (18) app, signed in to the same Apple account, with copied real-looking data.
2. **If only the user's own phone exists:** an encrypted Finder backup is required before D03, not optional. Record the backup date in the session record. The user confirms in writing that he accepts the risk.
3. **Build D (`com.nrsv.verse.dev`)** can live next to the live app or Build R. It has a different bundle ID, its own data container, and its own group (`group.com.nrsv.verse.dev`). It needs Developer Mode and a device registered in the team's development profile (automatic signing registers it). It cannot change the `com.nrsv.verse` data. Never install a `.dev`-signed build with the ID `com.nrsv.verse`.

## 3. TestFlight versus other signing for Build R

**Ruling: TestFlight is required for the D03 claims.** TestFlight uses the distribution signature and the App Store profile (no `get-task-allow`). That is the signature class of the release. It is also the documented way to install over an App Store build and keep the data.

- An **Ad Hoc** build (distribution certificate, Ad Hoc profile that lists the phone) is acceptable if the user does not want to upload yet. Label it "Ad Hoc distribution signature".
- A **development-signed** Release install is acceptable only for D04–D11 and D14, and only on a spare phone. It must never be used to claim D03 (signed update and widget continuity). Label every result "development signature".
- The TestFlight upload is user step U4. Upload the day before.

## 4. `devicectl` commands (checked against this Mac)

| Command in the checklist | Help page | Result |
| --- | --- | --- |
| `xcrun devicectl list devices` | exists | Correct |
| `xcrun devicectl device install app --device <id> <path>` | `USAGE: devicectl device install app --device … <path>` | Correct |
| `xcrun devicectl device copy from --device <id> --domain-type appDataContainer --domain-identifier <bundle> --source <path> --destination <dir>` | Valid domain types: `temporary`, `appDataContainer`, `appGroupDataContainer`, `systemCrashLogs` | Correct |
| `xcrun devicectl device process launch --device <id> --terminate-existing --console <bundle> <args>` | `USAGE: … process launch [<options>] --device … <bundle-identifier-or-path> [<command-line-arguments> ...]`. `--console` "attaches … and waits for it to exit". | Options are valid. Two problems: see required fix 1. |

## 5. Pass rules

The rules are measurable and source-based. Four need changes (required fixes 4, 5, 6, and 7). "Within 1 minute" for delivery and "change within 30 minutes" for the widget are reasonable. A late widget remains an observation, as the checklist says.

## 6. Time estimate

The 100-minute core is tight but possible. D09 (20 minutes for nine screens with VoiceOver) and D03 (12 minutes, including the TestFlight update and two widget waits) are the tightest blocks. The D10 refresh watch also needs a 30-minute passive window. **Book one 3-hour window** for the core, the optional blocks, the passive waits, and the restore steps (required fix 2). Keep the TestFlight upload on the day before.

## Required fixes

1. **`devicectl` launch with app arguments (section 4 and D12).**
   - Put the app arguments after a `--` separator, so `devicectl` does not read `-L29SharedProbeRelativePath` as its own option: `xcrun devicectl device process launch --device <id> --terminate-existing com.nrsv.verse.dev -- -L29SharedProbeRelativePath probe-1.json`.
   - Do not use `--console` in D12. With `--console`, `devicectl` waits until the app ends. Launch without it. Wait 10 seconds. Then copy the file.
   - Test the exact command once during the preparation, with the phone connected, before the session.
   - Add a direct copy of the widget probe file: `xcrun devicectl device copy from --device <id> --domain-type appGroupDataContainer --domain-identifier group.com.nrsv.verse.dev --source l29-widget-probe.json --destination build/native-evidence/S02/session-01/probe/`.
   - For crash files, add `--domain-type systemCrashLogs` as the Mac path. The Analytics Data list on the phone shows files only when the phone shares analytics.

2. **Restore step in D15.** Before the user leaves, restore:
   - the Calendar notices and the Rosary reminder to the values of D02;
   - the app text size changed in D08 step 3 (Extra large) to the D02 value;
   - the verse pool (D03) and rotation (D10) to the D02 values, if any step failed before its own restore;
   - optionally, remove the D02 test bookmark and note (user choice).

   Screenshot the restored Settings.

3. **D10 lock-screen families.** Cover every accessory family that `JohnWidget.swift` declares:
   - Daily Verse: rectangular, inline, circular.
   - Verse Countdown: rectangular, inline, circular.
   - Daily Reading: rectangular, inline.

   A lock screen holds one inline widget and a few slots. Use two or three lock-screen pages (Customize, new lock screen) or several rounds. Record each family as rendered and tapped, or as not reachable, with the reason.

4. **D03 step 7 and D04 (imported Rosary request).**
   - D04 and D05 replace the imported Rosary reminder, so its legacy request ID is gone after D04.
   - If the live app has a Rosary reminder, record its day and time in D02. Then in D03 step 7, record the setting after the update.
   - If its next delivery falls inside the session window, wait for that delivery before D04 changes the reminder, and record it. That is device evidence for L22 open item 1.
   - Otherwise state: "imported request: setting kept; delivery not observed". The ID match stays with L27 run B.

5. **D06 image sizes.**
   - The short card is 1080 × 1440 (`work-ledger.md`).
   - The long card height depends on the device width (`renderer.scale = 1080 / previewWidth`, `ScriptureCardView.swift:130`). The 1080 × 4171 value was measured on a 402-point iPhone 17 Pro. The pass rule for the long card: width exactly 1080, all 12 verses, and the right reference and edition. Compare the height with 4171 only on a 402-point phone. Record the device width.

6. **D04 pass rule for banner text.** Compute the expected Calendar title and body for that date from the old source plan (`calendarNotificationPlan`, `src/services/companion/calendarNotifications.ts:30–51`) on the Mac before the session. "Equals the L22 review" is not exact for another date. Do the same for D05 and the optional morning repeat.

7. **Safety wording (sections 3 and 9).** Use the rulings in sections 2 and 3:
   - A spare phone is preferred. If only the user's phone exists, an encrypted backup is required before D03.
   - TestFlight is required for the D03 claims. Ad Hoc is acceptable with a label. A development signature is only for the other items, on a spare phone.
   - Replace "cannot be undone" with this text: "A return to the App Store build keeps the container, but it is not tested. Treat D03 as one-way."

## Optional notes

1. Add AirDrop as one D06 share target, because it is a common real target. The current set (Messages, Save Image, Files, Copy) is sufficient.
2. Keep evidence free of personal data. The checklist already says to crop and blur. Also do not record the phone name if it contains a person's name. Use the `devicectl` device identifier only.
