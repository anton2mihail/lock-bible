# System notification snapshot

`SystemNoticeSnapshot.swift` is a DEBUG-only, read-only evidence helper. It calls the system notification center to read current notification settings and pending requests. It does not request permission. It does not add, remove, or change a request.

The public entry point for the DEBUG helper is:

```swift
let report = try await SystemNoticeSnapshot.capture()
let data = try SystemNoticeSnapshot.encode(report)
```

This helper does not read the app's durable state or a container. `encode(_:)` is for standalone use. Runtime does not call it.

## Runtime stage files

Runtime puts `Report` as `systemSnapshot` inside one stage file. Runtime adds the committed envelope beside it.

- Activation: pass the launch argument pair `-L22NoticeSnapshotRelativePath <relative path>`. Only DEBUG builds read it.
- Location: `<app Documents>/<relative path>/`. Runtime rejects a path that leaves Documents. A rejected path writes no file.
- File name: `NNN-<phase>-<outcome>-p<PID>.json`. `NNN` is the zero-padded sequence in the process. Runtime does not replace a file that exists. It logs the refusal.
- Phases and outcomes: `startup-loaded`, `calendar-save-success`, `calendar-save-failure`, `rosary-save-success`, and `rosary-save-failure`. Runtime writes `startup-loaded` before the startup notification refresh.
- Stage fields: `schemaVersion`, `bundleIdentifier`, `processIdentifier`, `sequence`, `phase`, `outcome`, `capturedAtUTC`, `committedStateRevision`, `nativeEnvelopeBase64`, `nativeEnvelopeSHA256`, `nativeEnvelopeError`, `systemSnapshot`, and `systemSnapshotError`.
- Envelope: Runtime reads the primary file `Application Support/John/native-state-v1.json`. The SHA-256 is over those exact bytes.
- Limits: a stage file does not prove delivery, a user tap, or durable success by itself.

Main must copy the stage folder out of the container before a reset or reinstall.

The report records the UTC capture interval and the local time-zone identifiers. It records authorization, alert, sound, badge, lock-screen, notification-center, CarPlay, preview, critical-alert, announcement, time-sensitive, scheduled-delivery, and direct-message settings.

Each pending request records its identifier and the public content fields needed for comparison. It preserves typed user-info values. It records the logical trigger kind and actual trigger class, repeat flag, all `DateComponents` fields, the component calendar and time zones, the current time zone, and the next trigger date when the trigger type exposes one. It records attachment identifiers, types, and URLs. It stores a secure keyed archive of the original `UNNotificationRequest` when the system can create one. It lists fields that the public projection cannot read. Archive availability and archive errors are reported separately from public-field availability.

Unsupported user-info values stay marked as unavailable values with their source type and reason. Non-finite numbers are not encoded as JSON numbers. Custom sound names and non-circular location geometry are marked as unavailable when the public API does not expose them. The secure archive is evidence only when the archive operation succeeds.

The report is an observation of pending requests and settings at capture time. A pending request does not prove delivery. The report does not prove that a user saw or opened a notice. It does not return a pass or fail verdict.

Main owns project membership, simulator setup, permission state, test stages, and all runtime captures. Do not define `DEBUG` in a Release configuration. Type-check this file with Swift 6, the arm64 iOS Simulator SDK, and `DEBUG` defined before Main adds it to the test build.
