# S02 physical-device evidence checklist

Date: 6 October 2026.
Author: Source.
Status: plan only. Source ran nothing on a phone. No result in this file is accepted. Sol reviews the evidence after the session.

This file is handoff step 11 and the S02 row of `Remaining-gate-runtime-order.md`. It collects every item that a review marked as needing a physical device. It groups them into one session for one iPhone. The core session takes about 100 minutes. Optional blocks add about 40 minutes.

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
2. **Backup.** Make an encrypted Finder backup of the phone. The same-ID update (D03) cannot be undone. A TestFlight build cannot be replaced by an older build, and the Expo 1.5.0 app cannot be put back. If a spare phone with the live app and real data is available, use it. The user decides.
3. **Live app.** The phone has the live App Store app 1.5.0 (18), `com.nrsv.verse`, with some real data: a few saved items, a reader position, a novena in progress, and at least one old widget on the home screen. The old app's notification permission can be on or off. Record which.
4. **Build R (Release, signed, same ID).** `com.nrsv.verse`, widget `com.nrsv.verse.widget`, group `group.com.nrsv.verse`, team `QZ44N522NQ`. Preferred source: a TestFlight build from the signed archive (`L28-gate-e-checklist.md` section 6; the user owns U1, U2, and U4). TestFlight processing can take 30 to 60 minutes after upload, so upload it the day before. Alternative: a development-signed Release install from Xcode over the live app. Source did not verify that iOS keeps the data in that case. Test it on a spare phone first. Record which source was used.
5. **Build D (Debug, signed, dev ID).** `com.nrsv.verse.dev`, widget `com.nrsv.verse.dev.widget`, group `group.com.nrsv.verse.dev`. Build for `iphoneos` with `-allowProvisioningUpdates DEVELOPMENT_TEAM=QZ44N522NQ`. It installs next to the live app and keeps its data. It has the DEBUG hooks D1 (`-L29MediaFailureURI`) and D2 (`-L29SharedProbeRelativePath`) and the sample audio URLs. It is needed only for the optional blocks D12 and D13. Never install Build D over `com.nrsv.verse`.
6. **Mac.** Xcode 26.6. The phone appears in `xcrun devicectl list devices`. Record its device identifier (no personal data in the report). Make the folder `build/native-evidence/S02/session-01/` with the sub folders `video`, `photos`, `logs`, `probe`, `notes`.
7. **Expected values.** On the Mac, compute the expected widget text for the session instant with `TZ=<zone> bun scripts/native/source-fixtures/step7/widget-expected.ts <instant> <zone> <edition> <scope> <interval>`. Run it again at each widget check (D10), because the verse slot depends on the real clock.
8. **Package check.** Run `l28_inspect_package.py --stage export` on the build that goes on the phone, if the IPA is available. It must show no FAIL (see `L28-gate-e-checklist.md` section 4).
9. **Sound.** A quiet room. Headphones (wired or Bluetooth) for D13 only.

## 4. Evidence methods (common to all items)

| Need | How |
| --- | --- |
| Screen recording | Control Center, Screen Recording. Long press the button and turn the microphone on when the item needs sound. Stop with the red status bar. Send the video to the Mac with AirDrop. File it in `video/`. |
| Screenshot | Side button and volume up together. Send to the Mac with AirDrop. File in `photos/`. Name each file `D<item>-<step>.png`. |
| Time stamp | Show the status-bar clock in every recording. Say or write the time at each event in `notes/session-log.md`. |
| Live log (Mac) | Open Console.app. Select the phone in the left bar. Press Start. Type `process:John` in the search field. Save the selection to `logs/` after each item. For the Debug build, use `xcrun devicectl device process launch --device <id> --terminate-existing --console com.nrsv.verse.dev` to stream the app output. Check `xcrun devicectl device process launch --help` for the exact options on your Xcode. |
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
| 8 | Set a Rosary notice again, quit the app, wait, tap the banner (cold tap). Add widgets while you wait | D05, D10 | R | user | 14 |
| 9 | Largest text sizes | D08 | R | user | 8 |
| 10 | VoiceOver speech and Reduce Motion | D09 | R | user | 20 |
| 11 | Wrap up: move the evidence, write the notes | D15 | none | user, Mac helper | 6 |
| | **Core total** | | | | **100** |
| 12 | Optional: App Group probe on the signed Debug build | D12 | D | user, Mac helper | 12 |
| 13 | Optional: media lifecycle and audio routes | D13 | D | user | 18 |
| 14 | Conditional: Airplane Mode offline proof, only if M1 failed | D14 | R | user | 10 |
| | **With all optional blocks** | | | | **140** |

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
4. Close the app from the app switcher.

Evidence: screenshots in `photos/D02-*.png`, and `notes/D02-before.md` with the saved rows, the reader position, and the widget list.
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
7. Settings, Notifications: if the live app had a Rosary reminder, check that it is still on with the same time (this is the imported legacy ID, `L22` open item 1). Do not change it yet.

Evidence: screenshots of each step, a recording of steps 3 to 6 (about 3 minutes, no sound), the Mac helper's expected values, and a Console.app extract for the first launch.
Pass: the data in step 3 equals the D02 record; each old widget instance survives and renders the expected text; the taps open the right destination; the scope change shows in the widget. Fail if any saved item is missing or duplicated, or a widget instance is gone.
Note: a pass shows effective App Group access for the signed build in practice. It does not by itself prove the entitlement text. The Mac helper also reads the entitlement from the IPA (`l28_inspect_package.py --stage export`, check C09).

### D04. Notification delivery and warm tap (5 min to set, 6 min to deliver; user)

Reason: `L22` open items 3, 4, and 9; plan item 5; Step 7 plan 2.5. The simulator cannot show a locked phone or a banner.

Build: R. No DEBUG hook is needed. The delivery uses a time a few minutes ahead.

Set (block 4):
1. Settings in John 1:1, Calendar notifications. Turn on. If the permission prompt appears, allow it. Set the delivery time to the current time plus 10 minutes. Save. A saved message must show.
2. Pray, Rosary, Reminder. Turn on. Choose Daily. Set the time to the current time plus 10 minutes. Save.
3. Write both set times and the current time in the log. Screenshot both screens.
4. Put the app in the background (swipe up to the home screen). Do not close it.

Deliver (block 7):
5. Two minutes before the set time, lock the phone. Leave it on the lock screen. Record the screen with the status clock visible.
6. At the set time, check that two banners arrive on the lock screen. Check the title and body. The Calendar banner shows the day's celebration as the title and "Today's Gospel: <reference>. Open your daily readings." as the body when the day has a Gospel. The Rosary banner shows "A quiet moment for the Rosary".
7. Unlock with Face ID or the passcode through the Calendar banner (tap it). This is the warm tap, because the app was in the background. The app must open the daily readings for today's date.
8. Press Home. Open the notification list. Find the Rosary banner. Tap it. The app must open the Rosary home.
9. Settings, Notifications, John 1:1: screenshot the banner style and the sound setting.

Evidence: recording of steps 5 to 8, screenshots, the Console.app extract with `usernoted` and `John` lines for the two minutes around the delivery.
Pass: both banners arrive within 1 minute of the set time; the text equals the source (`reviews/L22-positive-notice-runtime-20261006.md`); each tap opens the stated destination; after the tap, Back returns to a normal tab. Fail if a banner is missing, late by more than 1 minute, or opens the wrong screen.
Limit: this proves two deliveries and two warm taps. It does not prove all 30 calendar notices, the daily rhythm over days, or a real DST change.

### D05. Cold tap (6 min, user; overlaps D10)

Reason: `L22` open item 3. A cold tap launches the app from the notification.

1. Set the Rosary reminder (daily) to the current time plus 8 minutes. Save. Screenshot.
2. Open the app switcher and close John 1:1 by swiping it up. Check that it is gone from the switcher.
3. Lock the phone. At the set time, check the banner arrives. Tap it.
4. The app must launch straight to the Rosary home. Count the seconds from the tap to the Rosary home.
5. Back must return to Today or the Pray tab without a blank screen.

Evidence: recording, screenshot, log extract.
Pass: the banner arrives within 1 minute; the cold launch shows the Rosary home with no wrong screen between; Back works. The launch time is an observation. It is not a budget.
Optional follow-up with no session time: the Calendar notice repeats the next morning at the set time. If the app is closed, tap it and record the result.

### D06. Native sharing (8 min, user)

Reason: plan item 9; Step 7 plan section 4 item 4 and item 8. The simulator opens the panel and cancels. It cannot show real targets.

Build: R.

1. Reader, John 1:1, select verse 1, Create card. Choose the ivory background. Start a stopwatch when the preview shows. Share the image to Messages (send it to yourself) and to Save Image. Open the saved image in Photos. Check the pixel size (Photos, Info) is 1080 by 1440.
2. Repeat with the plum background and the Share to Files target (Save to Files).
3. Share text instead: share the text to Messages (to yourself). Check the text equals `<text>`, a blank line, `<reference> (<edition>)`, and `John 1:1 · Scripture & Prayer`.
4. Long card: Psalm 2, select verses 1 to 12, create a card. Share the image to Save Image. The image must be 1080 by 4171 and contain all 12 verses and the right reference and edition. Note how long the preview takes. Watch for a slow screen, heat, or a crash.
5. Verse Moment (Today, Verse & lock screen widget): Share. Check the text equals `“<text>”` then `— <reference> (<abbreviation>)`.
6. Copy: tap Copy on a selection. Paste in Notes. Check the exact text.
7. Check that no crash or "low memory" restart happened (Settings, Privacy & Security, Analytics & Improvements, Analytics Data: look for a new `JetsamEvent` or `John` crash file; screenshot the list).

Evidence: recording, the saved images (AirDrop to the Mac, `photos/`), the pixel sizes, the Analytics Data screenshot.
Pass: every share target receives the right content; the image sizes are exact; the long card completes without a crash or a restart; the pasted text is exact. The card renderer memory and heat are observations only. Report if the phone was warm or the preview took longer than 10 seconds.

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

### D10. Lock-screen and home-screen widgets, taps, and refresh (8 min, user, plus passive watching)

Reason: Step 7 plan W1, W2, W3, W6; `L12-widget-source-review.md`. The simulator cannot edit the lock screen and cannot show the real refresh budget.

Build: R. Do it while you wait in D05.

1. Lock screen: press and hold, Customize, choose Lock Screen. Add these: Daily Verse (rectangular), Daily Reading (rectangular), Verse Countdown (circular), Daily Verse (inline). Screenshot the lock screen.
2. Home screen: add Daily Verse small and medium, Daily Reading small and medium, Verse Countdown small. Screenshot the home screen.
3. For each instance, compare the text with `widget-expected.ts` for the capture instant. Use the Mac helper.
4. Tap each widget that has a link. The Verse widget opens the Reader at the verse (`nrsv://read?book=…&chapter=…&verse=…`). The Daily Reading widget opens `nrsv://daily?date=<today>`. The lock-screen tap needs an unlock. Record the result.
5. Refresh budget: in the app set Settings, Verse rotation to every 10 minutes. Take a screenshot of the widget now. Take another at each 10-minute boundary for the next 30 minutes, whenever you pass the phone. Note the time of each change. WidgetKit decides the real reload time. This is an observation. It is not a pass limit.
6. Set the rotation back to its previous value.

Evidence: the screenshots with time stamps, the Mac helper's expected values, a recording of the taps.
Pass: each instance renders the expected text for its capture instant; the taps open the stated destination; the widget changes to a new verse after a boundary at least once in 30 minutes. Fail if a widget shows "unable to load", or its text differs from the expected value without a time-slot explanation. Report any delay of more than 15 minutes after a boundary to Sol as an observation.

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
3. On the Mac, run the first probe: `xcrun devicectl device process launch --device <id> --terminate-existing --console com.nrsv.verse.dev -L29SharedProbeRelativePath probe-1.json`. Wait for the app to start.
4. Copy the record: `xcrun devicectl device copy from --device <id> --domain-type appDataContainer --domain-identifier com.nrsv.verse.dev --source Documents/probe-1.json --destination build/native-evidence/S02/session-01/probe/`.
5. Wait 2 minutes. Change a dev setting (Verse pool) on the phone. Wait 1 minute. Run the probe again with `probe-2.json`. Copy it.
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

### D15. Wrap up (6 min, user and Mac helper)

1. Send all media to the Mac. File it in `build/native-evidence/S02/session-01/`.
2. Hash every file. Write `notes/hashes.txt`.
3. Fill the session record (section 8).
4. Do not delete anything from the phone until Sol has reviewed the evidence.
5. Remove Build D from the phone if you installed it. Do not remove Build R.

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

1. **The same-ID update cannot be undone.** After D03 the phone has the native app. Use a spare phone or a backup. This is the largest risk.
2. **TestFlight timing.** Processing can take an hour. Upload the day before.
3. **Notification permission.** If the live app already allowed notices, no prompt shows. The Allow prompt on the device then has no evidence. The simulator already proves it.
4. **Real data.** Use test words only in new notes and intentions. Do not photograph personal data. Crop or blur before sharing the evidence.
5. **Widget timing.** WidgetKit can delay a reload. A late widget is an observation, not a fail, unless it never changes.
6. **Debug build.** Build D shows development controls. Do not use it for the Release checks. Do not use its results for Release behavior.
7. **Dev-signed install over the live app.** Source did not verify that iOS keeps the data. Test it on a spare phone first, or use TestFlight.
8. **Commands.** The `devicectl` options in this file come from Source's knowledge of Xcode 26. Source did not run them. Check `--help` before the session. The Mac helper fixes any change.

## 10. Time estimate

| Part | Minutes |
| --- | --- |
| Core session (D01 to D11 and D15) | 100 |
| Optional: App Group probe (D12) | 12 |
| Optional: media lifecycle (D13) | 18 |
| Conditional: Airplane Mode (D14) | 10 |
| Total with all optional and conditional blocks | 140 |

The core time includes waits that overlap with other work. A first-time user needs about 20 percent more.
