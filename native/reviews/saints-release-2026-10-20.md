# Saints calendar release — 2026-10-20

## Release inputs

- iOS: John 1:1, `com.nrsv.verse`, version **2.0.3 (27)**.
- Android: John 1:1, `com.john.bible`, version **1.0.2 (3)**.
- Feature: Vatican News and Ruthenian Byzantine Catholic calendars, English life accounts, source links, and saints in daily reminders.
- iOS icons now come from tracked `assets/artwork/john-icon*.png` files. The native launch layout is tracked under `native/John/Resources/Launch`. No generated Expo project is required.

## Validation

- Full Xcode Release archive passed with automatic signing.
- Compiled light, dark, and tinted icons, launch storyboard, fonts, licenses, and privacy manifests passed package checks.
- App and widget signature checks passed. Their production IDs, version, build, and App Group match.
- Both saints catalogs match the source bytes inside both release packages.
- Android signed bundle verification passed, including bundletool, upload signature, package metadata, and 16 KB library alignment.
- All 17 Android release unit tests passed. Release lint: 0 errors, 31 warnings, 7 hints.
- Earlier feature checks: 44 Swift tests, 17 Android debug tests, 5 importer tests, and the saints iOS UI test passed.
- Two fresh resource stages produced the same manifest while `ios/` was absent.
- Play reports a non-blocking missing native debug symbols warning for the bundled third-party library.

Public verification reports are in [evidence/saints-release-2026-10-20](evidence/saints-release-2026-10-20).

## Store status

Both packages uploaded successfully. Apple build processing and Google quick checks are pending. Final submission status will be recorded here after confirmation.

## Release policy

Keep the existing store settings: manual release after Apple approval; full Android rollout after Google approval, with managed publishing off.
