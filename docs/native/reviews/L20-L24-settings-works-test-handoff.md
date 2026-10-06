# Settings and Works simulator test handoff

Date: 6 October 2026.
Reviewer: GPT-6.1 Sol.
Status: corrected source accepted for target inclusion. Runtime remains open.

Main owns target membership, seeds, simulator operation, and result capture. Source owns `SimulatorSupport/WorksSettingsUITests.swift` and the separate Media/Notification test file. No new unit-test target is required.

## Accepted source

| File | SHA-256 |
| --- | --- |
| WorksSettingsUITests.swift | `d7212de69ce955ffce0e678427927f1af88aa0bffa8eedcec337fb82ff7579d0` |
| FullSettingsView.swift | `4e4128510427d1cca4a9c90f3958908519b1964ad6120a24eec7d42724a536fb` |
| RosaryMediaView.swift | `f3fa01189b33c4d81967fedba8686283ea5f2c3648ad3e5f20115a28c72ef261` |

The Settings and Media choice Buttons now expose their own identifiers and explicit `Selected` or `Not selected` values. They retain selected traits. They no longer create the extra accessibility element used in the failed Settings hierarchy. Main proved that the prior Large tap saved native revision 86 with `textSize=large`. The prior missing selected trait did not prove a failed save. Record the corrected actual hierarchy before using the new values as runtime evidence.

The Works test requires a fresh task-only seed with no Works position. It waits for `Contents, section 1 of 88`, then selects `Homily 10`. The source catalog identifies this work as commentary. The source database confirms section index 9, title `Homily 10`, and first paragraph `Homily 10 on the Gospel of John`. Keep the exact section labels.

The test checks page movement, footer geometry, text-size reflow, and one restart. Its final log confirms visible section/page state. Main must inspect the committed work ID, section, page, and anchor fields separately before accepting exact durable anchor preservation. A visible text marker alone does not prove those fields.

Source reports a passing strict Swift 6 arm64 simulator SDK/XCTest type-check. This does not prove route operation or visual parity.

## Next isolated test scope

Source will prepare only `SimulatorSupport/MediaNotificationUITests.swift`. Use current source leaf identifiers and meaningful episode/mode/route state checks. Keep Debug sample playback and Release approval gating as distinct conditions. Do not infer player destruction from a changed title alone. Main retains actual lifecycle/player evidence and simulator operation.

Notification UI tests may use the existing settings callbacks and current save/status controls. Main owns OS permission setup, actual pending-request inspection, delivery, and warm/cold response checks. The accepted 25-observation injected-center result does not replace these system checks.
