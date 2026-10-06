# L22 positive notice runtime review (6 October 2026)

Date: 6 October 2026.
Reviewer: Sol (architecture, review, and acceptance).
Status: **Accepted for the items in "Accepted" below.** The items in "Open" stay open. The helper fixes are accepted.

## Reviewed evidence

Sol did not build, run, or use a simulator. Sol read the evidence copies and decoded them with Sol's own script. Sol did not use `analyze-notice-stages.py` for any result below.

| Item | SHA-256 |
| --- | --- |
| `native/John/SimulatorSupport/PositiveNoticeUITests.swift` (working tree) | `89dd7bf0e4d817628033e96e7d8fd7342f129e784c6673d3348b1d6a512fa1f8` |
| `positive-notice-snapshot-14/PositiveNoticeUITests-helper-fixes.patch` | `9b33e9e05b69971fb17b6e84340f64bcce18ca6c3f1de3f17a077b535ab9768d` |
| `analyze-notice-stages.py` (Main's decoder, not used) | `ee3e2b5990672249bbbc2637413f9b4a5f4078bb50ad892cd394562693ee05e1` |
| `DerivedData-notice-snapshot-02/build-record.txt` | `fbb4c9a4f21fe306e0074d9cbad9d7644a456a996b2f8773e7979c4fecab2be3` |

Paths are below `build/native-evidence/L22/`.

**App source boundary.** HEAD `2dfdae4`. `Runtime.swift` is `284001b3…` and `SystemNoticeSnapshot.swift` is `33eba36e…`. These are the accepted post-fix hashes. No app, platform, feature, widget, or package source changed between `2dfdae4` and `2ce1700`.

**Binaries used by the runs.** The run record names `DerivedData-notice-snapshot-08`. Sol measured: app `993f337f…`, Debug dylib `1dbc7da9…`, runner `7e36729d…`, `JohnUITests` `dbe806a3…`. These match the run record. The `-02` Debug hashes differ (`e38e853f…`). Debug binaries hold build paths, so a second DerivedData folder gives other bytes. The source boundary is the same.

**Release exclusion.** `DerivedData-notice-snapshot-release-02` (Release `John` `cdfd29cb…`) is built from `2dfdae4`. It has 0 matches for `SystemNoticeSnapshot`, `L22NoticeSnapshotRelativePath`, `John L22 system notice snapshot`, `L22NoticeSnapshot`, and `nativeEnvelopeSHA256`. The Debug positive control has matches. Accepted.

## Helper fixes

| Fault | Change | Effect on evidence |
| --- | --- | --- |
| `adjust(toPickerWheelValue:)` accepts only the wheel data value | `wheelTargetValue` returns the zero-padded number (`"8"`, `"35"`) | No effect on readback. The hour and minute wheels are still found by their observed suffix (`o’clock`, `minutes`), one wheel each. `waitWheel` reads the full accessibility value back and compares its number. The meridiem is compared exactly (`AM`/`PM`). |
| The page drag hit the inline Calendar spinner | The scroll drag starts 14 pt from the left edge of the viewport | It changes only where the page drag starts. It cannot set a time. |
| The Rosary compact picker center tap missed the time pill | Tap at 80 % of the picker frame width | It opens the same system control. The test then waits for real `PickerWheel` elements. |
| The alert-dismiss check was too short | Wait up to 10 s for `exists == false` | Stricter, not weaker. |

The semantic proof does not depend on the wheel readback alone. The system notification center, captured by the snapshot helper, shows the saved times independently (below). **Accepted.** These fixes close the separate-review item in `L25-helper-and-run-plan-review.md` ("Out of scope") and `Step7-remaining-feature-checks-review.md`.

## Independent decode

Sol checked every stage file against its recorded SHA-256 list: 8 of 8 match. For each stage, Sol decoded `nativeEnvelopeBase64`, recomputed SHA-256, and read `revision`.

### Clean authorized run (`positive-notice-snapshot-13`, app PID 9116, 233.9 s)

| Stage | Envelope revision = committed | SHA match | Authorization | Pending | Envelope Calendar / Rosary |
| --- | --- | --- | --- | --- | --- |
| 001 startup loaded | 1 = 1 | yes | notDetermined | 0 | off 08:00 / off daily 20:00 |
| 002 calendar save success | 2 = 2 | yes | authorized | 30 | on 09:15 / off |
| 003 rosary save success | 3 = 3 | yes | authorized | 31 | on 09:15 / weekly Mon 08:30, `john-rosary:reminder` |
| 004 rosary save success | 4 = 4 | yes | authorized | 31 | on 09:15 / daily 08:35, same ID |
| 005 rosary save success | 5 = 5 | yes | authorized | 30 | on 09:15 / off |
| 006 calendar save success | 6 = 6 | yes | authorized | 0 | off 09:15 / off |

All stages have the same PID and bundle `com.nrsv.verse.dev`, with no envelope error and no snapshot error.

**Calendar requests (stages 002–005).** Sol ran the old source plan (`src/services/companion/calendarNotifications.ts:30–51`, with `celebrationFor`, `readingsFor`, and `addDays` from `calendar.ts`) under `TZ=America/Toronto` at the stage 002 capture instant `2026-10-06T12:48:48Z` (08:48 local). It gives 30 requests. The 30 pending calendar requests are equal to it in all four stages: identifier, title, body, and `userInfo.url`.

- IDs `john-calendar:<ms>`. Each ID equals its trigger's next date in milliseconds (0 mismatches).
- Trigger class `UNCalendarNotificationTrigger`, `repeats` false, hour 9, minute 15, component time zone `America/Toronto`, Gregorian calendar.
- Days 2026-10-06 to 2026-11-04, 30 consecutive days. Today is included because 09:15 was still ahead.
- Next dates from `13:15Z` (EDT) to `14:15Z` after the 1 November 2026 change to EST.
- Example: `Saint Bruno, Priest`, "Today’s Gospel: Luke 10:38-42. Open your daily readings.", `/daily?date=2026-10-06`, sound `default`, interruption `active`.
- The calendar set is identical across stages 002–005. Rosary saves did not change it.

**Rosary request.**

- Stage 003: `john-rosary:reminder`, `UNCalendarNotificationTrigger`, `repeats` true, weekday 2, 08:30, `America/Toronto`. The next date is `2026-10-12T12:30Z`, Monday 08:30 EDT (6 October 2026 is a Tuesday).
- Stage 004: same ID, weekday absent, 08:35, `repeats` true. The next date is `2026-10-07T12:35Z`, because 08:35 had passed at 08:50 local.
- Content matches `src/services/rosary/reminders.ts:122–129`: "A quiet moment for the Rosary", the same body, sound `default`, URL `/pray/rosary`.
- Stage 005: the Rosary request is gone. The 30 calendar requests remain.
- Stage 006: 0 pending requests.

### Fresh denial run (`positive-notice-snapshot-14`, app PID 14676, 43.4 s)

| Stage | Revision | Envelope SHA-256 | Authorization | Pending |
| --- | --- | --- | --- | --- |
| 001 startup loaded | 1 | `8adb3abc3fa4…` | notDetermined | 0 |
| 002 calendar save failure | 1 | `8adb3abc3fa4…` | denied | 0 |

The envelope bytes after the denied save equal the startup bytes. Calendar stays off at 08:00. The test checks the visible permission error and the off state after re-entry.

## Accepted

1. Real first permission prompt, **Allow** path: `notDetermined` to `authorized` through the system alert. The save then succeeds.
2. Calendar enable at 09:15: exactly 30 requests. IDs, titles, bodies, URLs, triggers, and DST next dates equal the old source plan.
3. Rosary weekly Monday 08:30, then a change to daily 08:35. The owned ID stays the same. The trigger is replaced. The next dates are correct.
4. Owned-set separation: Rosary changes leave the calendar set unchanged. Rosary off removes only the Rosary request. Calendar off removes all calendar requests.
5. Durable linkage: each successful save gives revision +1, and the committed revision equals the envelope revision with a matching hash.
6. Real first permission prompt, **Don't Allow** path: the save fails, no request is added, and the envelope bytes do not change.
7. DEBUG snapshot helper and Runtime stages: runtime-proven in Debug and excluded from Release.

## Open

1. An imported legacy Rosary ID with a real OS request after an update (L27 run B).
2. Preservation of unrelated (non-owned) pending requests. No foreign request existed in these runs.
3. Delivery on the real clock, and warm and cold notification taps with route checks.
4. Refresh on foreground, active hour, significant time change, and time-zone change against the real center.
5. Partial scheduling failure and rollback against the real center. This is accepted only with the injected center.
6. Permission changed later in system Settings (denied to allowed, and allowed to denied), with persistence across process restarts.
7. A real DST crossing at delivery time. The planned next dates are accepted; delivery is not.
8. iPad and Release-configuration runtime of these screens.
9. Lock-screen and banner behavior on a locked physical device (S02).

## Notes

1. The run record names the binaries but not the `-08` build command. Add a short build record for `DerivedData-notice-snapshot-08` (command, HEAD, source hashes) beside the run record.
2. The UI test bundle compiles every `SimulatorSupport` file. Record the test-source hashes of the other files that were in the working tree at build time. `JohnUITests` `dbe806a3…` includes them.
