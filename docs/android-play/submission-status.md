# Android Play submission status

Updated 2026-10-13. This is an execution record, not a claim of store approval.

## Confirmed settings

- New app in North Boutique Studios Ltd. organization account.
- App: John 1:1. Package: `com.john.bible`.
- Free. No ads or purchases. Support: `contact@north.boutique`.
- First version: 1.0.0 (1). Minimum API 26. Target API 36.

## Console record

[App dashboard](https://play.google.com/console/u/0/developers/4990621206072144809/app/4976176755710508736/app-dashboard).

The owner approved the policy and US export declarations before app creation.
The app was created. Its privacy policy URL was saved. Dashboard showed 1 of 11
setup tasks complete after this save. App access was then saved as unrestricted; the dashboard showed 2 of 11 tasks complete.

## Website

[Public support](https://anton2mihail.github.io/lock-bible/).
[Public policy](https://anton2mihail.github.io/lock-bible/privacy.html).

Commit `48425a2` contains only the two website pages. The Pages deployment
[passed](https://github.com/anton2mihail/lock-bible/actions/runs/38417009971).
An HTTP check returned 200 and confirmed the October 13 John policy, publisher,
offline voice disclosure, backup disclosure, and support email.

## Verified release files

Final signed bundle: `~/.local/share/john-android/releases/com.john.bible-1-65d62be1d2dd.aab`.
The matching `.json` report contains no passwords.
SHA-256: `65d62be1d2ddf99737cb67744f6174d0d2d2712d9af369c57af8d1319455d3ef`.
Size: 88,855,245 bytes. All 497 content entries passed signature checks.
Bundletool accepted the file. API levels are 26/36. All four packaged native
libraries meet 16 KB alignment. The catalog matches its pinned SHA-256.

Nine JVM unit tests passed. Release lint has zero errors. Release, debug, and
instrumentation APK builds passed. The updated device checks have not passed:
the existing emulator's Android framework crashed before instrumentation began.
Earlier development tests passed 14 device tests before the release privacy
changes. Do not use that result as verification of the final release behavior.

## Pending execution
- Real store screenshots and foreground media service video.
- App content forms, rating, audience, and listing.
- Internal test upload and Play pre-launch report.
- Production submission and Google review.

Private signing files are outside the repository in
`~/.local/share/john-android/`. Do not commit or upload them as store assets.
The owner must keep a secure backup of the upload key and its configuration.
