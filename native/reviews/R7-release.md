# R7 release: iOS 2.0.2 (26) and Android 1.0.1 (2), submitted for review

Submitted 16–17 October 2026. Both stores: waiting for review. iOS release: manual.

## Before this release
- iOS 2.0.1 (25), the quotes-only content release (R6), was approved and is live.
- Android 1.0.0 (1) was in review since 13 October.

## What changed
- Paged Bible reader on both platforms (Apple Books / Play Books style). Pages is
  the default; Scroll is a choice in Aa and in Settings. See the commits
  00ab68a, dda4b08, 58b1240 (iOS) and 378476f, 492e31d, 103937b (Android).
- iPad: page text no longer runs under the floating sidebar (ae9b991).
- All AI-generated images are replaced with photographs of public-domain
  paintings (552d0a9). The icon is a crop of the Sinai Christ Pantocrator.
- New store screenshots, paged reader first (712f174, 516f357).

## Checks
- iOS: ReaderPagesUITests 10/10, reader, smoke, read-aloud, content and calendar
  suites pass (skips by design only). JohnCore 38 tests pass. The iPad sidebar fix
  was checked by hand on an iPad 13" simulator; the full iPad UI test run hung and
  was stopped.
- Android: 15 JVM tests, 22 device tests pass (1 skip by design). Lint 0 errors.
- iOS archive: "Uploaded John Update", EXPORT SUCCEEDED (2.0.2, 26).
- Android bundle: verified by build-bundle.py (1.0.1, code 2).

## Store changes
- App Store Connect: version 2.0.2 with build 26, new What's New and review notes,
  6 iPhone 6.9" and 4 iPad 13" screenshots from `marketing/screenshots/framed-2.0.2`.
- Google Play: see `docs/android-play/submission-status.md`.

## Build notes
- `prepare-release-resources.py` still reads `ios/LockBible`; a clean prebuild makes
  `ios/John11`. Link `ios/LockBible -> John11`, run the script, then remove `ios/`.
- The Play bundle is 86 MB; it must be uploaded in Play Console by hand or with a
  Play API service account that has access to John 1:1.
