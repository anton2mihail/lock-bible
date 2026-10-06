# S02 physical-device evidence checklist

Date: 6 October 2026.
Author: Source.
Status: plan only. Sol accepted it with seven fixes (`S02-physical-device-checklist-review.md`); this version applies them. Source ran nothing on a phone. No result in this file is accepted. Sol reviews the evidence after the session.

This file is handoff step 11 and the S02 row of `Remaining-gate-runtime-order.md`. It collects every item that a review marked as needing a physical device. It groups them into one session for one iPhone. The core session takes about 110 minutes of active work. Optional blocks add about 40 minutes. Book one 3-hour window for the core, the optional blocks, the passive waits, and the restore steps. Upload the TestFlight build the day before.

Do not claim any item below from simulator images. Do not submit, upload, or publish anything in this session. Uploading a build to TestFlight is a separate user step (U4 in `L28-gate-e-checklist.md`).

## 1. Sources of the list

| Source | Items it sends to the device |
| --- | --- |
| Plan section 12, "Small physical-device check set" | actual VoiceOver speech, installed widgets across a signed update, notification delivery under real OS conditions, signing and entitlements |
| `Step7-remaining-feature-checks-plan.md` section 4 and `Step7-remaining-feature-checks-review.md` | lock-screen widget families and taps, device-signed App Group access and continuity after an update, the WidgetKit refresh budget, real share targets, audio route changes, interruptions and background audio, locked-device notices and banner style, real Reduce Motion, renderer memory and heat, the App Group probe on a device |
| `L22-positive-notice-runtime-20261006.md`, open items 1, 3, 4, 6, 7, 9 | an imported legacy Rosary request after an update, delivery on the real clock, warm and cold taps, foreground and time-zone refresh, later permission changes, a real DST crossing, lock-screen and banner behavior |
| `L26-L28-preparation-review.md`, `L26-release-run-procedure.md` | Airplane Mode offline proof, only if method M1 fails; physical-device performance (not in this session) |
| `L28-gate-e-checklist.md` section 9.4, U5 | same-ID signed update on a phone that has the live 1.5.0 (18) app with real data |
| `L25-paired-capture-run-plan.md` | VoiceOver speech; Dynamic Type at the largest sizes |
| `Remaining-gate-runtime-order.md` S02 row | final readiness, VoiceOver speech, signed widget continuity, notification delivery and tap, lifecycle clearing, native sharing |

## 2. Who does what

No tool in this workspace can touch the phone. Claude has simulator tools (Simulator MCP, `simctl`) and Mac desktop tools. None of them reaches a physical iPhone. Source did not test iPhone Mirroring. It needs a locked phone and does not show VoiceOver speech, banners, or lock-screen widgets, so do not plan on it.

| Role | Work |
| --- | --- |
| **User** (phone in hand) | Every tap, every setting change, every screen recording, every screenshot, every physical action (lock, headphones, Airplane Mode). Items D01 to D15. |
| **Claude or Main** (Mac, remote) | Before the session: build, sign, and list the device (`xcrun devicectl`). During the session: run Mac commands that the user starts, for example `devicectl` launch and file copy for the Debug build, and `widget-expected.ts`. After the session: hash and file the evidence, decode the probe records, write the S02 report draft for Sol. Claude cannot see the phone screen. |
| **Sol** | Reviews the evidence and writes the S02 verdict. |

## 3. Before the session (not counted in the time)

1. **Phone.** One iPhone on iOS 26.0 or later. Record the model, iOS version and build (Settings, General, About), and the time zone. Developer Mode on. Trusted by the Mac. Charged above 50 percent. Do Not Disturb and Focus modes off for the session.
2. **Spare phone or backup (safety).** Treat D03 as one-way. A return to the App Store build keeps the data container, but that path is not tested. The native-only state (`Application Support/John`) stays in the container. Rulings from Sol:
   - **Preferred:** a spare iPhone with the live 1.5.0 (18) app, signed in to the same Apple account, with copied real-looking data.
   - **If only the user's own phone exists:** an encrypted Finder backup is required before D03. It is not optional. Write the backup date in the session record. The user confirms in writing that he accepts the risk.
   - **Build D** (`com.nrsv.verse.dev`) can live next to the live app or Build R. It has its own bundle ID, its own data container, and its own group (`group.com.nrsv.verse.dev`). It needs Developer Mode and a device that is registered in the team's development profile (automatic signing registers it). It cannot change the `com.nrsv.verse` data. Never install a build signed for development with the ID `com.nrsv.verse`.
3. **Live app.** The phone has the live App Store app 1.5.0 (18), `com.nrsv.verse`, with some real data: a few saved items, a reader position, a novena in progress, and at least one old widget on the home screen. The old app's notification permission can be on or off. Record which.
4. **Build R (Release, signed, same ID).** `com.nrsv.verse`, widget `com.nrsv.verse.widget`, group `group.com.nrsv.verse`, team `QZ44N522NQ`. Signing rules (Sol):
   - **TestFlight is required for the D03 claims.** It uses the distribution signature and the App Store profile (no `get-task-allow`). That is the signature class of the release. It is also the documented way to install over an App Store build and keep the data. The user owns U1, U2, and U4 (`L28-gate-e-checklist.md` section 6). Upload the build the day before, because processing can take 30 to 60 minutes.
   - An **Ad Hoc** build (distribution certificate, Ad Hoc profile that lists the phone) is acceptable if the user does not want to upload yet. Label every result "Ad Hoc distribution signature".
   - A **development-signed** Release install is acceptable only for D04 to D11 and D14, and only on a spare phone. It must never be used to claim D03 (signed update and widget continuity). Label every result "development signature".
   Record which source was used.
5. **Build D (Debug, signed, dev ID).** `com.nrsv.verse.dev`, widget `com.nrsv.verse.dev.widget`, group `group.com.nrsv.verse.dev`. Build for `iphoneos` with `-allowProvisioningUpdates DEVELOPMENT_TEAM=QZ44N522NQ`. It installs next to the live app and keeps its data. It has the DEBUG hooks D1 (`-L29MediaFailureURI`) and D2 (`-L29SharedProbeRelativePath`) and the sample audio URLs. It is needed only for the optional blocks D12 and D13. Never install Build D over `com.nrsv.verse`.
6. **Mac.** Xcode 26.6. The phone appears in `xcrun devicectl list devices`. Record its device identifier (no personal data in the report). Make the folder `build/native-evidence/S02/session-01/` with the sub folders `video`, `photos`, `logs`, `probe`, `notes`.
7. **Expected values.** On the Mac, compute the expected widget text for the session instant with `TZ=<zone> bun scripts/native/source-fixtures/step7/widget-expected.ts <instant> <zone> <edition> <scope> <interval>`. Run it again at each widget check (D10), because the verse slot depends on the real clock.
8. **Package check.** Run `l28_inspect_package.py --stage export` on the build that goes on the phone, if the IPA is available. It must show no FAIL (see `L28-gate-e-checklist.md` section 4).
9. **Sound.** A quiet room. Headphones (wired or Bluetooth) for D13 only.
10. **Expected notice text.** Compute the expected Calendar title and body for the session date and for the set times, from the old source plan: `calendarNotificationPlan` in `src/services/companion/calendarNotifications.ts:30-51` with `TZ` set to the phone's time zone and `now` set to the session instant. The Calendar title is `readings?.title ?? celebration.title`. The body is "Today’s Gospel: <reference>. Open your daily readings." when the day has a Gospel, and "Take a moment with today’s Catholic calendar and readings." otherwise. The URL is `/daily?date=<yyyy-MM-dd>`. The Rosary request has the title "A quiet moment for the Rosary" and the URL `/pray/rosary` (`src/services/rosary/reminders.ts:122-129`). Write the expected values in `notes/expected-notices.md`. Use `bun scripts/native/source-fixtures/notifications/notice-expected.ts --now <session UTC> --tz <phone zone> --calendar <HH:MM> --rosary <off|daily|weekly> [--rosary-weekday N] [--rosary-time HH:MM] --md notes/expected-notices.md`. It calls the old planning functions and reproduces the accepted 6 October run exactly. Do not use the L22 review values for another date.
11. **Command test.** With the phone connected, run the exact `devicectl` commands of D12 once during the preparation (install, launch with arguments after `--`, copy). Fix any option change before the session day.

## 4. Evidence methods (common to all items)

| Need | How |
| --- | --- |
| Screen recording | Control Center, Screen Recording. Long press the button and turn the microphone on when the item needs sound. Stop with the red status bar. Send the video to the Mac with AirDrop. File it in `video/`. |
| Screenshot | Side button and volume up together. Send to the Mac with AirDrop. File in `photos/`. Name each file `D<item>-<step>.png`. |
| Time stamp | Show the status-bar clock in every recording. Say or write the time at each event in `notes/session-log.md`. |
| Live log (Mac) | Open Console.app. Select the phone in the left bar. Press Start. Type `process:John` in the search field. Save the selection to `logs/` after each item. Do not use `--console` with `devicectl` for the Debug build. With `--console`, `devicectl` waits until the app ends. Use Console.app instead. |
| Crash files (Mac) | `xcrun devicectl device copy from --device <id> --domain-type systemCrashLogs --source <file name> --destination build/native-evidence/S02/session-01/logs/`. The Analytics Data list on the phone shows files only when the phone shares analytics, so use the Mac path first. |
| Notification log | In Console.app, search `usernoted` and `John`. Save the lines around each delivery. |
| sysdiagnose (only after a crash or hang) | Press both volume buttons and the side button together for about 1.5 seconds. Wait 10 minutes. On the phone open Settings, Privacy & Security, Analytics & Improvements, Analytics Data. Share the newest `sysdiagnose_` file to the Mac. File in `logs/`. It is large. Do not collect it for a pass. |
| App files (Debug build only) | `xcrun devicectl device copy from --device <id> --domain-type appDataContainer --domain-identifier com.nrsv.verse.dev --source <path> --destination build/native-evidence/S02/session-01/probe/`. This works only for a development-signed build. It does not work for the TestFlight build. |
| VoiceOver speech text | Settings, Accessibility, VoiceOver, Caption Panel. It shows the spoken text on screen. Record the screen with the microphone on. The recording shows the captions. The microphone also catches the speaker output. |
| Hash | On the Mac: `shasum -a 256 <file>` for every video, photo, and log. Put the list in `notes/hashes.txt`. |

Rules for all items: do not repeat a check that passed. If a check fails, write what you saw, keep the recording, and go on. Do not tune the app or the build during the session. Do not enter real personal data in notes, saved items, or intentions. Use short test words.

## 5. Session plan

The time counts only the active work. Waits for notices overlap with other blocks.

| Order | Block | Items | Build | Who | Minutes |
| --- | --- | --- | --- | --- | --- |
| 1 | Record the device and the starting state | D01 | live app | user | 5 |
| 2 | Capture the live app before the update | D02 | live 1.5.0 (18) | user | 8 |
| 3 | Install Build R over the live app. Check the data and the old widgets | D03 | R | user, Mac helper | 12 |
| 4 | Set the two notices for a delivery about 10 minutes ahead | D04 (set) | R | user | 5 |
| 5 | Share text and image. Open the external Rosary link | D06, D11 | R | user | 11 |
| 6 | Check that Confession notes clear | D07 | R | user | 5 |
| 7 | Lock the phone. Watch the two banners. Tap one with the app in the background (warm tap) | D04 (deliver) | R | user | 6 |
| 8 | Set a Rosary notice again, quit the app, wait, tap the banner (cold tap). Add widgets while you wait | D05, D10 | R | user | 18 |
| 9 | Largest text sizes | D08 | R | user | 8 |
| 10 | VoiceOver speech and Reduce Motion | D09 | R | user | 20 |
| 11 | Restore the settings. Move the evidence. Write the notes | D15 | none | user, Mac helper | 10 |
| | **Core total** | | | | **108** |
| 12 | Optional: App Group probe on the signed Debug build | D12 | D | user, Mac helper | 12 |
| 13 | Optional: media lifecycle and audio routes | D13 | D | user | 18 |
| 14 | Conditional: Airplane Mode offline proof, only if M1 failed | D14 | R | user | 10 |
| | **With all optional blocks** | | | | **148** |

Order matters. D03 must come first. It changes the app and the data. D04 (set) must come before D06 to D07, so the delivery falls in the waiting time. D08 and D09 come last, because they change the system settings.

## 6. Items

Each item gives the reason, the procedure, the evidence, and the pass rule. A pass needs the evidence. Write "fail" and the reason if a pass rule is not met.

### D01. Record the device and the starting state (5 min, user)

Reason: every record needs the device, the OS, the build, and the time.

1. Settings, General, About: screenshot the model, iOS version, and build.
2. Settings, General, Date & Time: screenshot the time zone and the 24-hour setting.
3. Settings, Notifications, John 1:1: screenshot the current permission state of the live app.
4. Open TestFlight (or note the Xcode install) and record the Build R version and build number.
5. Start Console.app on the Mac and the session log.

Pass: all four screenshots exist and the log is running.

### D02. Capture the live app before the update (8 min, user)

Reason: the update test needs a "before" record (L28 section 9.4; plan item 5).

1. Open the live app 1.5.0 (18). Photograph Today, Read (note the saved chapter), Saved (list the rows), Pray (note any novena in progress), and Settings (edition, text size).
2. Home screen: screenshot every old widget instance (home and lock screen). Note the kind, size, and page. The old kinds are `VerseWidget`, `VerseTimerWidget`, and `DailyReadingWidget`. Record what text each one shows and the time.
3. If the app has no saved items, add one bookmark and one note now with test words, so D03 can check them.
4. Notices: Settings, Calendar notifications: record on or off and the time. Pray, Rosary, Reminder: record on or off, daily or weekly, the weekday, and the time. Screenshot both screens. This is the "before" value for the imported Rosary reminder (`L22` open item 1) and the restore value for D15. Also record the Settings values that later steps change: text size, verse pool, and verse rotation.
5. Close the app from the app switcher.

Evidence: screenshots in `photos/D02-*.png`, and `notes/D02-before.md` with the saved rows, the reader position, the widget list, the Rosary reminder (day and time), the Calendar notice setting, and the Settings values.
Pass: the record is complete. A missing old widget is a limit. Write it down. It means D03 cannot test continuity for that widget.

### D03. Same-ID signed update, imported data, and widget continuity (12 min, user, Mac helper)

Reason: plan items 5 and 6 and the physical-device set require "installed widgets across a signed update". `L22` open item 1 needs an imported legacy Rosary request. The simulator proves only the embedded entitlement (`L12-simulator-entitlement-boundary.md`).

Build: R, over the live app. Do not delete the live app.

1. Install Build R (TestFlight "Update", or the Xcode install). Note the exact time.
2. Open the app once. Wait until Today shows. Time the wait with a stopwatch. This is the first-run import time. It is not a performance budget.
3. Check the imported data against `notes/D02-before.md`: the Reader opens at the saved chapter (Read tab, Continue reading), the bookmark and note are in Saved, the novena progress is the same, and Settings shows the same edition and text size.
4. Go to the home screen and the lock screen. Check each old widget instance from D02. It must still be there. It must show text and not "unable to load". The text must equal the `widget-expected.ts` value for that instant, edition, scope, and interval. The Mac helper computes it.
5. Tap each widget once. The Verse widget opens the Reader at the verse. The Daily Reading widget opens that day's readings. The Countdown widget has no link and opens the app.
6. In the app, change Settings, Verse pool (scope) to Old Testament. Return to the home screen. Check that the widget changes to a verse from the Old Testament pool within about 2 minutes. Change it back. This shows that the app and the widget share the signed group `group.com.nrsv.verse` on the device. If the widget does not change within 5 minutes, remove it and add it again, and write what happened.
7. Pray, Rosary, Reminder: if D02 recorded a Rosary reminder, record its state after the update. It must be on with the same frequency, weekday, and time. This is the imported legacy reminder (`L22` open item 1). Screenshot it. Do not change it yet. D04 replaces it, so its legacy request ID is gone after D04. See the delivery rule in D04.

Evidence: screenshots of each step, a recording of steps 3 to 6 (about 3 minutes, no sound), the Mac helper's expected values, and a Console.app extract for the first launch.
Pass: the data in step 3 equals the D02 record; each old widget instance survives and renders the expected text; the taps open the right destination; the scope change shows in the widget. Fail if any saved item is missing or duplicated, or a widget instance is gone.
Note: a pass shows effective App Group access for the signed build in practice. It does not by itself prove the entitlement text. The Mac helper also reads the entitlement from the IPA (`l28_inspect_package.py --stage export`, check C09).

### D04. Notification delivery and warm tap (5 min to set, 6 min to deliver; user)

Reason: `L22` open items 3, 4, and 9; plan item 5; Step 7 plan 2.5. The simulator cannot show a locked phone or a banner.

Build: R. No DEBUG hook is needed. The delivery uses a time a few minutes ahead.

Imported reminder (L22 open item 1): if the imported Rosary reminder from D02 and D03 has a next delivery inside the session window, do not change the Rosary reminder yet. Lock the phone, wait for that delivery, and record the banner, its time, and the tap result. This is device evidence for the imported request. If its next delivery is outside the window, write: "imported request: setting kept; delivery not observed". The ID match stays with L27 run B.

Set (block 4):
1. Settings in John 1:1, Calendar notifications. Turn on. If the permission prompt appears, allow it. Set the delivery time to the current time plus 10 minutes. Save. A saved message must show.
2. Pray, Rosary, Reminder. Turn on. Choose Daily. Set the time to the current time plus 10 minutes. Save.
3. Write both set times and the current time in the log. Screenshot both screens.
4. Put the app in the background (swipe up to the home screen). Do not close it.

Deliver (block 7):
5. Two minutes before the set time, lock the phone. Leave it on the lock screen. Record the screen with the status clock visible.
6. At the set time, check that two banners arrive on the lock screen. Check the title and body against `notes/expected-notices.md` (prerequisite 10). The expected Calendar title and body come from `calendarNotificationPlan` for the session date. The expected Rosary banner is "A quiet moment for the Rosary".
7. Unlock with Face ID or the passcode through the Calendar banner (tap it). This is the warm tap, because the app was in the background. The app must open the daily readings for today's date.
8. Press Home. Open the notification list. Find the Rosary banner. Tap it. The app must open the Rosary home.
9. Settings, Notifications, John 1:1: screenshot the banner style and the sound setting.

Evidence: recording of steps 5 to 8, screenshots, the Console.app extract with `usernoted` and `John` lines for the two minutes around the delivery.
Pass: both banners arrive within 1 minute of the set time; the title and body equal the values computed for the session date from `calendarNotificationPlan` (`notes/expected-notices.md`); each tap opens the stated destination; after the tap, Back returns to a normal tab. Fail if a banner is missing, late by more than 1 minute, or opens the wrong screen.
Limit: this proves two deliveries and two warm taps. It does not prove all 30 calendar notices, the daily rhythm over days, or a real DST change.

### D05. Cold tap (6 min, user; overlaps D10)

Reason: `L22` open item 3. A cold tap launches the app from the notification.

1. Set the Rosary reminder (daily) to the current time plus 8 minutes. Save. Screenshot.
2. Open the app switcher and close John 1:1 by swiping it up. Check that it is gone from the switcher.
3. Lock the phone. At the set time, check the banner arrives and that its title and body equal `notes/expected-notices.md`. Tap it.
4. The app must launch straight to the Rosary home. Count the seconds from the tap to the Rosary home.
5. Back must return to Today or the Pray tab without a blank screen.

Evidence: recording, screenshot, log extract.
Pass: the banner arrives within 1 minute with the expected text; the cold launch shows the Rosary home with no wrong screen between; Back works. The launch time is an observation. It is not a budget.
Optional follow-up with no session time: the Calendar notice repeats the next morning at the set time. If the app is closed, tap it and record the result. Compute the expected text for that date first (`calendarNotificationPlan` for the next day, prerequisite 10).

### D06. Native sharing (8 min, user)

Reason: plan item 9; Step 7 plan section 4 item 4 and item 8. The simulator opens the panel and cancels. It cannot show real targets.

Build: R.

1. Reader, John 1:1, select verse 1, Create card. Choose the ivory background. Start a stopwatch when the preview shows. Share the image to Messages (send it to yourself) and to Save Image. Open the saved image in Photos. Check the pixel size (Photos, Info) is 1080 by 1440. Also share it once by AirDrop to the Mac (a common real target) and check that it opens.
2. Repeat with the plum background and the Share to Files target (Save to Files).
3. Share text instead: share the text to Messages (to yourself). Check the text equals `<text>`, a blank line, `<reference> (<edition>)`, and `John 1:1 · Scripture & Prayer`.
4. Long card: Psalm 2, select verses 1 to 12, create a card. Share the image to Save Image. The image width must be exactly 1080. It must contain all 12 verses and the right reference and edition. The height depends on the phone's width (`renderer.scale = 1080 / previewWidth`, `ScriptureCardView.swift:130`). The value 1080 by 4171 was measured on a 402-point iPhone 17 Pro. Record the phone's screen width in points (Display Zoom changes it). Compare the height with 4171 only on a 402-point phone. Note how long the preview takes. Watch for a slow screen, heat, or a crash.
5. Verse Moment (Today, Verse & lock screen widget): Share. Check the text equals `“<text>”` then `— <reference> (<abbreviation>)`.
6. Copy: tap Copy on a selection. Paste in Notes. Check the exact text.
7. Check that no crash or "low memory" restart happened (Settings, Privacy & Security, Analytics & Improvements, Analytics Data: look for a new `JetsamEvent` or `John` crash file; screenshot the list).

Evidence: recording, the saved images (AirDrop to the Mac, `photos/`), the pixel sizes, the Analytics Data screenshot.
Pass: every share target receives the right content; the short card is exactly 1080 by 1440; the long card has width 1080, all 12 verses, and the right reference and edition (height 4171 only on a 402-point phone); the long card completes without a crash or a restart; the pasted text is exact. The card renderer memory and heat are observations only. Report if the phone was warm or the preview took longer than 10 seconds.

### D07. Lifecycle clearing: Confession notes (5 min, user)

Reason: plan section on Confession (notes clear on leaving, on background, and on loss of active state; `ConfessionView.swift` uses `scenePhase`). The simulator proves background and exit. The device adds the lock button, the notification shade, and the app switcher.

Build: R. Use short test words only.

1. Pray, Prepare for Confession. In the notes field type `test one`.
2. Press the side button to lock the phone. Unlock. The notes field must be empty.
3. Type `test two`. Pull down the notification shade (swipe from the top) and close it. Record if the notes stay or clear (the old app clears on loss of the active state; compare with the source: `src/screens/companion/ConfessionScreen.tsx`).
4. Type `test three`. Open the app switcher by swiping up and holding, then return. Record the result.
5. Type `test four`. Go to the next step. The notes must stay (internal steps keep them).
6. Press Home, wait 10 seconds, return. The notes must be empty.
7. Type `test five`. Open a link that leaves the app, if any, and return. Record.

Evidence: one recording with the notes visible at each step.
Pass: the notes clear after lock, after background, and after leaving the guide, and they stay across internal steps. Steps 3, 4, and 7 are observations. Compare them with the old app source before judging. A difference from the old behavior goes to Sol. Nothing may appear in the app switcher snapshot (screenshot the switcher once while the notes are on screen: the preview must not show the notes text if the old app hid it; record what it shows).

### D08. Largest system text sizes (8 min, user)

Reason: plan item 8; `L25-paired-capture-run-plan.md`. The simulator can only set a content size. The device shows real layout and the real tab bar.

Build: R.

1. Settings, Accessibility, Display & Text Size, Larger Text. Turn on Larger Accessibility Sizes. Drag the slider to the largest size.
2. Open John 1:1. Screenshot Today, Read (book list), a Reader chapter (John 1), Saved, Pray, Rosary home, the Rosary guide, Settings, and the share card screen.
3. In Reader, open Aa and set the app text size to Extra large too. Screenshot John 1 again.
4. Check each screen: no clipped words, no overlap, each button reachable by scrolling, and the tab bar still shows five tabs with labels.
5. Set the size back to the default after the check (VoiceOver block D09 comes next and needs a normal size).

Evidence: the nine screenshots, a short recording of scrolling Today.
Pass: every control can be read and used at the largest size. Report each clipped or overlapped element with its screenshot. Layout differences from the old app are a Sol decision.

### D09. VoiceOver speech and Reduce Motion (20 min, user)

Reason: plan item 9; the physical-device set; `L25-paired-capture-run-plan.md` line 146; Step 7 section 4 item 7. The simulator checks the accessibility tree and focus. It cannot show the real speech.

Build: R. The Mac is not needed except to receive the recording.

Set up (3 min):
1. Settings, Accessibility, VoiceOver, turn on. Settings, Accessibility, VoiceOver, Caption Panel, turn on. Set the speech rate to a rate that you can follow.
2. Start a screen recording with the microphone on.

Walk through (14 min). For each screen, swipe right to move through the elements. Check that the spoken text is clear, in a logical order, and that every control has a name and a role. Write each spoken text that is wrong or missing.
3. Today: the tab bar (spoken name, "tab", position such as "2 of 5", selected state), the readings card, the prayer rows, the verse, the Verse & lock screen widget row.
4. Read: the book list, a chapter list, John 1. The verse buttons must speak "Verse 1." and the verse text. Double-tap a verse. The selection summary and the toolbar (Note, Pray, Card, Copy, bookmark, highlight colors) must be spoken. Check the hint text. With VoiceOver on the reader must go verse by verse (as the old app says).
5. Search: type a query. Check that the result count and the first result are spoken.
6. Saved: filters (selected state), a row, delete, and Undo (spoken status).
7. Pray: a novena day (selected state), the Rosary guide (bead progress is announced as the user moves on), Lectio (the timer text), and Confession.
8. Settings: each choice speaks its value and "selected" state (radio-like choices).
9. Scripture card: the busy, error, and share states.
10. Widgets on the home screen: focus each one. Check the spoken text.

Reduce Motion (3 min):
11. Turn VoiceOver off with a triple-click or ask Siri. Settings, Accessibility, Motion, Reduce Motion on. Open Today, then the Rosary guide, then back. Check that the screens change without a crash and without large motion. Turn it off again.

Evidence: the recording with captions and sound; `notes/D09-voiceover.md` with a table of screen, spoken text, and defect.
Pass: no control without a name or role; selected states are spoken; the Reader verse-by-verse behavior holds; no crash. Each defect goes to Sol with the recording time. The old app's speech is the reference. If the old app is gone from the phone, use the source labels in `src/`.

### D10. Lock-screen and home-screen widgets, taps, and refresh (12 min, user, plus passive watching)

Reason: Step 7 plan W1, W2, W3, W6; `L12-widget-source-review.md`. The simulator cannot edit the lock screen and cannot show the real refresh budget.

Build: R. Do it while you wait in D05.

1. Lock screen. Cover every accessory family that `JohnWidget.swift` declares: Daily Verse (rectangular, inline, circular), Verse Countdown (rectangular, inline, circular), and Daily Reading (rectangular, inline). A lock screen holds one inline widget and a few slots, so use several lock screens (press and hold, Customize, add a new lock screen) or several rounds:
   - Lock screen A: Daily Verse inline, Daily Verse rectangular.
   - Lock screen B: Daily Reading inline, Daily Reading rectangular.
   - Lock screen C: Verse Countdown inline, Verse Countdown rectangular.
   - Lock screen D: Daily Verse circular and Verse Countdown circular.
   Screenshot each lock screen. Record each family as "rendered and tapped" or "not reachable", with the reason.
2. Home screen: add Daily Verse small and medium, Daily Reading small and medium, Verse Countdown small. Screenshot the home screen.
3. For each instance, compare the text with `widget-expected.ts` for the capture instant. Use the Mac helper.
4. Tap each widget that has a link. The Verse widget opens the Reader at the verse (`nrsv://read?book=…&chapter=…&verse=…`). The Daily Reading widget opens `nrsv://daily?date=<today>`. The lock-screen tap needs an unlock. Record the result.
5. Refresh budget: in the app set Settings, Verse rotation to every 10 minutes. Take a screenshot of the widget now. Take another at each 10-minute boundary for the next 30 minutes, whenever you pass the phone. Note the time of each change. WidgetKit decides the real reload time. This is an observation. It is not a pass limit.
6. Set the rotation back to the value recorded in D02. Switch back to the normal lock screen.

Evidence: the screenshots with time stamps, the Mac helper's expected values, a recording of the taps.
Pass: every declared lock-screen family is rendered or has a written reason; each instance renders the expected text for its capture instant; the taps open the stated destination; the widget changes to a new verse after a boundary at least once in 30 minutes. Fail if a widget shows "unable to load", or its text differs from the expected value without a time-slot explanation. Report any delay of more than 15 minutes after a boundary to Sol as an observation.

### D11. External Rosary link (3 min, user)

Reason: Release media gate (`L28-gate-e-checklist.md` section 7; Step 7 M3). The simulator never taps the external action.

Build: R.

1. Pray, Rosary home. Find the one external action (the suggested weekday episode). Screenshot the row. It must say that it opens on YouTube.
2. Tap it. It opens YouTube or Safari. Screenshot the page. The title must match the official episode for the weekday (Sunday glorious, Monday joyful, Tuesday sorrowful, Wednesday glorious, Thursday luminous, Friday sorrowful, Saturday joyful).
3. Return to John 1:1 with the app switcher or the status-bar back link. The Rosary home must be unchanged.

Evidence: screenshots.
Pass: the external page is the official page for the weekday and no in-app player appears. Do not play the video.

### D12. App Group probe on a signed device build (optional, 12 min, user and Mac helper)

Reason: Step 7 W5 and section 4 item 9. The simulator checks only the embedded entitlement.

Build: D (`com.nrsv.verse.dev`). It installs next to the live app. It needs the DEBUG probe (D2).

1. On the Mac: `xcrun devicectl device install app --device <id> <path to Build D John.app>`.
2. On the phone, add one dev Daily Verse widget to the home screen. Wait 2 minutes for it to render.
3. On the Mac, run the first probe. Put the app arguments after `--`, so `devicectl` does not read them as its own options. Do not use `--console`:
   `xcrun devicectl device process launch --device <id> --terminate-existing com.nrsv.verse.dev -- -L29SharedProbeRelativePath probe-1.json`
   Wait 10 seconds.
4. Copy the app record: `xcrun devicectl device copy from --device <id> --domain-type appDataContainer --domain-identifier com.nrsv.verse.dev --source Documents/probe-1.json --destination build/native-evidence/S02/session-01/probe/`. Copy the widget's own probe file from the group container: `xcrun devicectl device copy from --device <id> --domain-type appGroupDataContainer --domain-identifier group.com.nrsv.verse.dev --source l29-widget-probe.json --destination build/native-evidence/S02/session-01/probe/`. If a crash happens, copy the files with `--domain-type systemCrashLogs`.
5. Wait 2 minutes. Change a dev setting (Verse pool) on the phone. Wait 1 minute. Run the probe again with `probe-2.json` (same command, new file name). Wait 10 seconds. Copy both files again (rename the widget file copy to `l29-widget-probe-2.json` first).
6. Decode both files on the Mac. Hash them.

Evidence: both JSON files, the command output, the hashes, and the screenshot of the dev widget.
Pass (rule from Step 7 W5): both records show the same non-nil `containerPath`; `appGroup` is `group.com.nrsv.verse.dev`; the widget file shows a write by the widget; the second record's widget probe time is later than the first record's `appTime`; the values that the widget read equal the values that the app wrote. A record with `appGroup` equal to `missing`, or a nil container, is a fail.
If `devicectl` cannot copy the container on this Xcode, use Window, Devices and Simulators, select the app, and download the container. Record which method you used.

### D13. Media lifecycle and audio routes (optional, 18 min, user)

Reason: Step 7 M1 and section 4 item 5. The simulator cannot show real audio routes, interruptions, or background audio.

Build: D. The Release build has no in-app player. The Debug build has sample audio and video. It needs a network. Use headphones.

1. Pray, Rosary, Media (Debug). Choose audio. Play. Confirm the sound comes from the speaker.
2. Connect the headphones. The sound moves to them. Disconnect them. The audio must pause (the usual iOS rule). Record what happens.
3. Press Home. The audio must pause or stop (the app has no background audio mode). Return. The app must not resume by itself.
4. Play again. Lock the phone. Record whether the audio stops.
5. Play again. Make a call, set a timer, or use Siri to cause an interruption. Record the app state after the interruption ends. Resume must need a user action.
6. Switch to the video mode. Play. Press Home and return. Record the state.
7. Leave the media route (Back). The player must stop and the sound must end. Open Settings, Control Center, and the lock screen. No "now playing" item of John 1:1 may remain.
8. Check the failure state: turn on Airplane Mode and play. The button must show `Audio unavailable` and be disabled, or another readable error. Turn Airplane Mode off.

Evidence: a recording with sound for steps 1 to 4 and 7; notes for step 5.
Pass: no playback after leaving the route or locking the phone; no stuck "now playing" item; failure state readable. The old app used no background audio (`app.json` has `enableBackgroundPlayback` false). A difference goes to Sol.

### D14. Airplane Mode offline proof (conditional, 10 min, user)

Reason: `L26-L28-preparation-review.md` fallback: "The full offline proof then moves to S02 (Airplane Mode on a physical device)". Run it only if the offline method M1 failed or Sol rejected it. If M1 passed, Sol decides if this item is still needed.

Build: R.

1. Open Control Center. Turn on Airplane Mode. Turn off Wi-Fi and Bluetooth if they came back on. Screenshot the status bar.
2. Force quit John 1:1. Open it. Time to the Today title and readings card, with a stopwatch. Open John 1, Search for `faith`, open a Work page (The Confessions), the Rosary guide, Saved, and Settings. Each must work.
3. Open the Rosary home. The external action may open a page that fails to load. That is expected. The app must stay usable.
4. Turn Airplane Mode off.

Evidence: recording with the Airplane Mode status icon visible.
Pass: every core journey works with no network and no error about the network. Report timings as observations.

### D15. Restore and wrap up (10 min, user and Mac helper)

Restore first (the user does this on the phone before leaving):
1. Restore the Calendar notice and the Rosary reminder to the values recorded in D02 (on or off, time, daily or weekly, weekday). D04 and D05 replaced them.
2. Restore the app text size that D08 step 3 changed (Extra large) to the D02 value. Check that the system text size is the default.
3. Restore the verse pool (D03) and the verse rotation (D10) to the D02 values, if a step failed before its own restore.
4. Optional (user choice): remove the D02 test bookmark and note.
5. Turn off VoiceOver, Reduce Motion, and Airplane Mode if they are on. Remove the extra lock screens and test widgets if you do not want them.
6. Screenshot the restored Settings, Notifications, and Rosary reminder screens.

Wrap up:
7. Send all media to the Mac. File it in `build/native-evidence/S02/session-01/`.
8. Hash every file. Write `notes/hashes.txt`.
9. Fill the session record (section 8).
10. Do not delete anything from the phone until Sol has reviewed the evidence.
11. Remove Build D from the phone if you installed it. Do not remove Build R.

Evidence: the restored-settings screenshots and `notes/hashes.txt`.
Pass: the restored values equal the D02 record.

## 7. Items that stay outside this session

| Item | Reason | Where it goes |
| --- | --- | --- |
| Physical-device performance (launch, chapter, query, scroll, memory, thermal) | The plan names a reference device and Instruments. This needs Xcode attached to the phone and many runs. | A later task, if Sol asks. Do not use simulator numbers for it. |
| Foreground, significant-time, and time-zone refresh of the notice schedule against the real center | It needs the pending-request view (DEBUG snapshot, Build D) and several settings changes. It can start in the Debug build (`SystemNoticeSnapshot`) on the phone. | Add to a second session if Sol asks (`L22` open item 4). |
| Permission changed later in system Settings, and a real DST crossing at delivery time | Needs days or a date change. | `L22` open items 6 and 7. |
| The 30 calendar notices over many days | Time. | Observe passively after release. |
| iPad on a physical device | No iPad is in the plan for S02. | None. |

## 8. Session record for Sol

Copy this to `build/native-evidence/S02/session-01/notes/session-record.md`.

```markdown
# S02 physical-device session record
Date and time zone: ____. Prepared by: ____.
Phone: model ____, iOS ____ (build ____). Device identifier (not the serial number): ____.
Build R: TestFlight / dev-signed Release; version ____ build ____; source commit ____.
Build D (if used): commit ____; signed with team QZ44N522NQ.
Live app before the update: 1.5.0 (18) yes / no. Backup made: yes / no.

| Item | Done | Result (pass / fail / observation) | Evidence files (names and SHA-256 in hashes.txt) | Notes |
| --- | --- | --- | --- | --- |
| D01 Device and starting state | | | | |
| D02 Live app before update | | | | |
| D03 Same-ID update, data, widgets | | | | |
| D04 Notices and warm tap | | | | |
| D05 Cold tap | | | | |
| D06 Sharing | | | | |
| D07 Confession clearing | | | | |
| D08 Largest text | | | | |
| D09 VoiceOver and Reduce Motion | | | | |
| D10 Widgets and refresh | | | | |
| D11 External Rosary link | | | | |
| D12 App Group probe (optional) | | | | |
| D13 Media lifecycle (optional) | | | | |
| D14 Airplane Mode (conditional) | | | | |

Defects: list each one with the item, the time in the recording, and the file.
Limits: list each item that was not run and why.
Statement: These results are from one phone with one iOS version and one network. They do not prove other devices. Simulator evidence is not part of this record.
```

## 9. Risks

1. **Same-ID update (largest risk).** A return to the App Store build keeps the container, but it is not tested. Treat D03 as one-way. A spare phone is preferred. If only the user's phone exists, an encrypted backup is required before D03, and the user accepts the risk in writing.
2. **TestFlight timing and rules.** Processing can take an hour. Upload the day before. TestFlight is required for the D03 claims. Ad Hoc needs a label. A development signature is only for the other items, on a spare phone.
3. **Notification permission.** If the live app already allowed notices, no prompt shows. The Allow prompt on the device then has no evidence. The simulator already proves it.
4. **Real data.** Use test words only in new notes and intentions. Do not photograph personal data. Crop or blur before sharing the evidence.
5. **Widget timing.** WidgetKit can delay a reload. A late widget is an observation, not a fail, unless it never changes.
6. **Debug build.** Build D shows development controls. Do not use it for the Release checks. Do not use its results for Release behavior.
7. **Development-signed install over the live app.** Do not use it for D03. Use it only for D04 to D11 and D14 on a spare phone, and label the results "development signature".
8. **Commands.** Sol checked the `devicectl` syntax against the help pages of `devicectl` 518.33. Nobody has run the commands with a phone. Run them once during the preparation (prerequisite 11).
9. **Personal data in evidence.** Do not record the phone name if it contains a person's name. Use the `devicectl` device identifier only.

## 10. Time estimate

| Part | Minutes |
| --- | --- |
| Core session (D01 to D11 and D15) | 108 |
| Optional: App Group probe (D12) | 12 |
| Optional: media lifecycle (D13) | 18 |
| Conditional: Airplane Mode (D14) | 10 |
| Total with all optional and conditional blocks | 148 |

The core time includes waits that overlap with other work. A first-time user needs about 20 percent more. The D10 refresh watch needs a 30-minute passive window. Book one 3-hour window for the core, the optional blocks, the passive waits, and the restore steps. Keep the TestFlight upload on the day before.
