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

At submission, the icon, feature graphic, Today image, and Prayer image were
labeled for generated artwork. The repository now has no generated artwork. The
icon is a public-domain Sinai icon of Christ, and the feature graphic is a plain
crop of a public-domain painting (see `assets/CREDITS.md`). Upload the new
`assets/play-store/icon-512.png` and `feature-1024x500.png` and remove the
generated-artwork labels at the next listing update. [Google declaration
guidance](https://support.google.com/googleplay/android-developer/answer/17262077?hl=en).

On 16 October 2026 the six phone screenshots were made again. They show the
paged Bible reader (Pages mode, the default) and only public-domain paintings.
The new order is: John 1 first page in Pages mode, Today, Bible library, Prayer,
Saved, and Settings. Upload the six files in `assets/play-store/screenshots/`
in that order at the next listing update, and remove the old images.
`provenance.json` records how each file was made.

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

## Update 2026-10-17: version 1.0.1 (2)

- Signed bundle: `~/.local/share/john-android/releases/com.john.bible-2-e4cd468a5d0a.aab`
  (version code 2, version name 1.0.1). `build-bundle.py` verified it.
- Content: the paged Bible reader (Pages / Scroll choice), real public-domain
  paintings only, and the new icon (a detail of the 6th-century Christ
  Pantocrator at Sinai).
- Store listing: new icon, the plain Bloemaert feature graphic (no text), and the
  six screenshots in `assets/play-store/screenshots/` in file order (paged reader
  first). AI asset declaration: "Don't label assets".
- The owner dragged the bundle into Play Console. Four changes were sent:
  production 2 (1.0.1) full rollout, app icon, phone screenshots, feature graphic.
  This restarted the review that started on 2026-10-13, so 1.0.1 replaces 1.0.0.
- Warning shown (not blocking): no native debug symbols, as for 1.0.0.

## Update 2026-10-25: version 1.1.0 (5) — the Fathers and Doctors unlock

Parity with iOS 2.1.0 (approved by Apple). Branch `android/1.1.0`.

- One Google Play in-app product, non-consumable: `com.nrsv.verse.fathers` (same ID as iOS), US$9.99.
  Play Billing 8.3.0 (`platform/FathersBilling.kt`): purchase, restore (owned purchases), acknowledgement,
  price from Play, offline cache. A locked section is never read from the database (`WorkReader`).
- Free without the purchase: the first section of every work, all of the Apostolic Fathers, and the Confessions.
- Grandfathering: decided once on first launch of 1.1.0 and stored. If the app was installed before
  (PackageInfo first install time earlier than last update time), the library stays free. A reinstall loses it.
- Purchase places: the reader in place of a locked section, the library "Free to start" card, and the top of Settings.
- Rating prompt: Google Play In-App Review 2.0.2 after a finished Rosary or novena day, same rule as iOS. Off in debug builds.
- Debug-only switch: `adb shell am start -n com.john.bible/.MainActivity --es johnFathersAccess locked|purchased|grandfathered`.
- Checks: 36 JVM unit tests pass (15 new, each mapped to a written failure list). Debug lint: 0 errors.
  Emulator (Pixel 8, Android 16): locked section shows the unlock page; purchased reads section 2; normal launch
  without Google Play billing shows the locked state and does not crash. A real purchase was not tested:
  the emulator has no Play account.
- Signed bundle: `~/.local/share/john-android/releases/com.john.bible-5-64a5ecccedf3.aab` (91,188,242 bytes),
  verified by `build-bundle.py`. Manifest has `com.android.vending.BILLING`, version code 5, name 1.1.0.

To do in Play Console: upload the bundle (internal testing first), then create the in-app product
`com.nrsv.verse.fathers` (Play allows products only after a bundle with the billing permission is uploaded),
test a purchase with a license-tester account, then promote to production.

2026-10-25 (later): bundle 5 (1.1.0) is in the bundle library and in a saved internal-testing release draft
(not rolled out). Play Console still blocks one-time products ("add the BILLING permission") although the
bundle manifest has `com.android.vending.BILLING`: Play checks only bundles in a rolled-out release.
Next: roll out the internal-testing draft (the track has no testers, so nobody receives it), then create
`com.nrsv.verse.fathers` at US$9.99.

## Update 2026-10-25: version 1.2.0 (6) — Advent with the Fathers, sent to production

- Bundle `com.john.bible-6-7d45f92acab3.aab` uploaded by Anton. It includes everything in 1.1.0 (5).
- Internal testing: the 1.1.0 draft was replaced with 6 (1.2.0) and published, with no testers. This only
  made Play accept the BILLING permission, so the one-time product could be created.
- Production: release "6 (1.2.0) — Advent with the Fathers", full rollout, sent for review on 25 Oct together
  with the five search-keyword custom listings (50% audience each). Managed publishing is off, so the release
  goes live when Google approves it.
- One-time product `com.nrsv.verse.fathers` ("The Fathers and Doctors"): **active** since 25 Oct (Anton pressed
  Activate). Purchase option `buy`, backwards compatible (the app reads `oneTimePurchaseOfferDetails`), active in
  174 countries and regions; US$9.99, CA$13.99, £8.99.
