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
The app exists. The privacy policy, Books & Reference category, support email,
and HTTPS website are saved. The English listing text, icon, feature graphic,
and six real phone screenshots are saved. Play Console shows the default listing
as **Ready to send for review**. The screenshot order is Today, Bible library,
John 1, Prayer, Saved, and Settings. All files passed original-size visual review
and the RGB PNG 1080 × 1920 format check.

The icon, feature graphic, Today image, and Prayer image are labeled for their
existing generated artwork. Source: `assets/CREDITS.md`. The other four images
are unchanged device captures without generated artwork. [Google declaration
guidance](https://support.google.com/googleplay/android-developer/answer/17262077?hl=en).

The owner completed the app declarations, content rating, and audience settings.
The saved Data Safety answer is No collection/sharing. Audience and content
rating are owner-entered settings.

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

Clean checkout CI also passed: [run 38421094230](https://github.com/anton2mihail/lock-bible/actions/runs/38421094230), commit `0e22661`. The earlier CI run failed because the SDK setup action requested the removed `tools` package; the workflow now requests `platform-tools`.

Nine JVM unit tests passed. Release lint has zero errors. Release, debug, and
instrumentation APK builds passed. The final offline Bible test and five-tab UI
smoke passed on the existing API 36 emulator. The signed release APK installed
and opened with a cold launch time of 20,465 ms. A system ANR dialog covered the
rendered app. No new John crash or exit record was found. That frame was rejected.
The final capture run reached all six release routes after the existing emulator
returned to its saved four-core setting. A framework-only Android test avoided
AndroidX test-runner dependencies removed by R8. Captures use fresh app-window
and rendered-content checks. Source hashes are recorded in
`assets/play-store/screenshots/provenance.json`.

The final signed-release privacy UI check passed: Aa switched to Verse by verse,
Note opened Dictate, the notice and Continue control were present, and Cancel
returned to the note editor. John stayed active. The recognition monitor recorded
zero launches. Paragraph layout was restored. Broader runtime checks remain.

Earlier development tests passed 14 device tests before the release privacy
changes. Do not use that result as verification of the final release behavior.
The debug startup ANR trace showed ART DEX verification before Activity creation.
The debug APK has 24.3 times more DEX bytes than the release APK. Host memory
pressure and Android system failures limit the emulator measurements. They do
not prove an app-code cause.

The verified signed bundle was uploaded to the production draft. Google accepted
version 1 (1.0.0), API 26+, and target SDK 36. The release name and English notes
are set. Production targets all 178 country/region rows supported by Console.
Release validation has no errors. Its one nonblocking warning recommends native
debug symbols for the bundled native libraries. This is not a published release.

## Cleanup

Test images, test packages, and temporary harness files were removed. The original
1170 × 2532 display override and density 480 were restored. The emulator started
for this work is stopped. Local Android build output and project caches were
removed. The six approved screenshot files and their provenance are kept.

## Submission result

All 11 prepared changes were sent to Google. Publishing overview shows
**Changes in review** for production version 1.0.0 (1), the store listing, country
availability, and the saved declarations. Google's automatic checks were still
running when this record was saved. Managed publishing is off. The app is not
yet approved or live.

Submission proof: `assets/play-store/evidence/submitted-for-review.jpg`.

Google checks and review remain. No internal test track was created. The full
device suite and TTS playback were not rerun after the final privacy changes.
No foreground-service declaration video was requested in this submission flow.

Private signing files are outside the repository in
`~/.local/share/john-android/`. Do not commit or upload them as store assets.
The owner must keep a secure backup of the upload key and its configuration.
