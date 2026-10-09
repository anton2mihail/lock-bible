# John archive and export evidence, 7 October 2026

Owner: Luna. Candidate 06 is the current provisional signed Release archive and local App Store export. It contains the approved Works metadata/footer and landscape glyph fix and the Reader Go-to accessibility detent fix. Its L28, resource, media, and signature checks passed. It remains provisional until the remaining runtime queue is complete. Candidate 05 and earlier candidates are preserved as historical evidence. No upload occurred.

Update, 7 October 2026: Candidate 03 is superseded because it does not include the Reader book-list fix. Candidate 04 below includes that Reader fix and passed the r9 SE XXXL reach/header check. Candidate 04 does not include the later approved Works fix.

Update, 7 October 2026: Candidate 01 is superseded by candidate 02 below. Candidate 02 includes the approved Works semantic-anchor retention fix in `native/John/Features/Works/WorkReaderView.swift` and the approved Search title scaling fix in `native/John/Features/Secondary/SearchView.swift`. Runtime validation continues. Do not upload either IPA.

## Candidate 06 archive and export

Candidate 06 was archived and exported locally on 7 October 2026 after the focused SE R8 check passed and root accepted the Go-to and Aa captures. It includes the Reader Go-to accessibility detent fix. The release version is `1.5.0 (19)`; bundle IDs are `com.nrsv.verse` and `com.nrsv.verse.widget`; the App Group is `group.com.nrsv.verse`. No upload occurred.

Archive: `build/native-evidence/L28/signed-oct7-06/John.xcarchive`. Export: `build/native-evidence/L28/signed-oct7-06/export/John 1:1.ipa`. IPA SHA-256: `48ef6c52b5d4f73ceece25930d1a1321e7a1797684f642461d411f8aa495a6de`; size: 85,766,847 bytes.

The archive used the same approved command, scheme, team, and flags as Candidate 05, with `signed-oct7-06` archive and DerivedData paths. The archive succeeded. Its app and widget use Apple Development signing for team `QZ44N522NQ`; both profiles have the expected IDs and App Group, `get-task-allow=true`, two registered devices, and expiry 7 October 2027. Export used the unchanged `ExportOptions.plist`: `method=app-store-connect`, `destination=export`, `teamID=QZ44N522NQ`, `signingStyle=automatic`, `manageAppVersionAndBuildNumber=false`, and `uploadSymbols=false`. It does not set thinning.

The export succeeded with Cloud Managed Apple Distribution signing for North Boutique Studios Ltd (team `QZ44N522NQ`). App and widget Store profiles use the expected bundle IDs and App Group, `get-task-allow=false`, no provisioned devices, and expiry 5 October 2027. `codesign --verify --deep --strict` passed for the archive app, archive widget, exported app, and exported widget. Executable SHA-256 values are archive app `2ac3d59196073842b098cd2d271630c95a0a54ca18f90e70800539b930df96f3`, archive widget `63c111ba0d8058c84e5422f64be78fb7c7873f5244448c72aefc616d08973c2e`, export app `84bd86d9e7e228eb6b24290b822915478799013089c589991ffe69c20c8056dd`, and export widget `ef75bfcd48b8eecac9ce47070cb4df0a4f8e3df4b453ee612ea3d87e57183956`.

The archive and export L28 inspections each report 18 PASS, 0 FAIL, 2 REVIEW, and 0 USER-GATED. The extended debug-argument check ran. C10 remains profile review, and the direct profile inspection confirms the facts above. C19 remains review for device family and orientation facts. `verify-release-package.py` passed with 0 errors on archive and export. `check_media_package.py` passed on both; all six Rosary entries match source, and no media URI or sample URL was found. These are package checks. They do not prove media playback.

The 28-file source manifests captured before archive, after archive, and after all package checks are identical. Each manifest SHA-256 is `668253c84b8bee50a1150cfda9a707139abc913ba81c36b7bd7c265a600ec2a9`. Current app-source hashes are ReaderView `9a3db688a4193bd79925636b3769f970942c66d5d2e5ba90a47e4bd09db9995f` and WorkReaderView `46c797fc40f15855a1d6e04e317a35bef1e138a86161f73f701f2408ae4755ee`.

Reports and checks:

- L28: `build/native-evidence/L28/inspect-oct7-archive-06-final/` and `build/native-evidence/L28/inspect-oct7-export-06-final/`.
- Resources: `build/native-evidence/L28/resources-oct7-archive-06/report.json` and `build/native-evidence/L28/resources-oct7-export-06/report.json`.
- Media: `build/native-evidence/L28/media-oct7-archive-06/media-package-report.json` and `build/native-evidence/L28/media-oct7-export-06/media-package-report.json`.
- Source snapshots: `build/native-evidence/L28/signed-oct7-06/source-before-archive.sha256`, `source-after-archive.sha256`, and `source-after-checks.sha256`.
- Executable hashes: `build/native-evidence/L28/signed-oct7-06/executable-hashes.sha256`.
- Signature and profile facts: `build/native-evidence/L28/signed-oct7-06/signature-checks.log` and `profile-summary.txt`.
- Archive and export logs: `build/native-evidence/L28/signed-oct7-06/archive.log` and `export.log`.
- Archive log SHA-256: `5ef2f3538f8e32fb1c310356dfe8b5ed6f1cd26ebf1f6cf4b558f420a490677d`.
- Export log SHA-256: `cb0756f932881a348e4efaebe93710fed88fe538bf66d77ef64f80c55327afce`.
- Export options SHA-256: `63f7661fae650fcd0bbd69d82b266641f53c447976f1c28edcfc9995e0d86c1d`.

## Candidate 05 archive and export

Candidate 05 was archived and exported on 7 October 2026 from the source approved at that time. It includes the Works metadata/footer Dynamic Type cap at XXXL, full XXXL body text, and the SE landscape glyph-clipping fix. It does not include the later Reader Go-to accessibility detent fix. Candidate 05 is historical. No upload occurred. The release version is `1.5.0 (19)`; bundle IDs are `com.nrsv.verse` and `com.nrsv.verse.widget`; the App Group is `group.com.nrsv.verse`.

Archive: `build/native-evidence/L28/signed-oct7-05/John.xcarchive`. Export: `build/native-evidence/L28/signed-oct7-05/export/John 1:1.ipa`. IPA SHA-256: `69a6e666069955441c255eaa6464c9d5a002c562e824b75687a053680f7f2d7e`; size: 85,766,943 bytes.

The archive used the Candidate04 command with `signed-oct7-05` archive and DerivedData paths. It succeeded. Its app and widget use Apple Development signing for team `QZ44N522NQ`; both profiles have the expected IDs and App Group, `get-task-allow=true`, two registered devices, and expiry 7 October 2027. Export used the unchanged Candidate04 `ExportOptions.plist` settings: `method=app-store-connect`, `destination=export`, `teamID=QZ44N522NQ`, `signingStyle=automatic`, `manageAppVersionAndBuildNumber=false`, and `uploadSymbols=false`. It does not set thinning.

The export succeeded with Cloud Managed Apple Distribution signing for North Boutique Studios Ltd (team `QZ44N522NQ`). App and widget Store profiles use the expected bundle IDs and App Group, `get-task-allow=false`, no provisioned devices, and expiry 5 October 2027. `codesign --verify --deep --strict` passed for the archive app, archive widget, exported app, and exported widget. Executable SHA-256 values are archive app `d862039b7ad33fbf6519f91dfa2aa72d834e07e80666408c235615cd0584ef8d`, archive widget `6910ddf02a1935967d5dc73f109325b6cef17d16360603edf62d656806a7b876`, export app `ce426f82dfc05263b3d9e418bf946dd23f0b8a88fdc469e88ca007af389c9d23`, and export widget `402e93bea5372fb70c31e550219d0cb5e5da7ead6fbce6e9b2bd376c423c6ec0`.

The archive and export L28 inspections each report 18 PASS, 0 FAIL, 2 REVIEW, and 0 USER-GATED. C04 deployment/platform, C05 architecture, C09 signing IDs/group/team, C12 privacy API hints, and C13-C15 debug exclusions pass. C15 included `-JohnTabBarMinimize` in the source-name list and found no package hit. C10 remains profile review; direct profile inspection confirms the archive and Store facts above. C19 remains review for device family/orientations; the native landscape decision is accepted in `L25-helper-and-run-plan-review.md:65` and stable Pro/SE landscape captures are recorded in the runtime handoff.

`verify-release-package.py` passed with 0 errors on archive and export. `check_media_package.py` passed on both; all six Rosary entries match source, and no media URI or sample URL was found. These are package checks. They do not prove media playback.

The current-source hash manifest captured immediately after archive and the manifest captured after all package checks are identical. Both manifest SHA-256 values are `545d3990b855b1e848e8e650dbe47e3bd3b3d6097dc252d34bdad9070be3ca90`. The release-source hashes include ReaderView `4d974cd0d5b95637134de0137a8f5b58e80d9bebee33a276115cb115f1c26248` and WorkReaderView `46c797fc40f15855a1d6e04e317a35bef1e138a86161f73f701f2408ae4755ee`. The Release scheme archived the app and widget; it did not run simulator tests.

Reports and checks:

- L28: `build/native-evidence/L28/inspect-oct7-archive-05-final/` and `build/native-evidence/L28/inspect-oct7-export-05-final/`.
- Resources: `build/native-evidence/L28/resources-oct7-archive-05/report.json` and `build/native-evidence/L28/resources-oct7-export-05/report.json`.
- Media: `build/native-evidence/L28/media-oct7-archive-05/media-package-report.json` and `build/native-evidence/L28/media-oct7-export-05/media-package-report.json`.
- Source snapshots: `build/native-evidence/L28/signed-oct7-05/source-current-after-archive.sha256` and `source-current-after-checks.sha256`.
- Executable hashes: `build/native-evidence/L28/signed-oct7-05/executable-hashes.sha256`.
- Signature and profile facts: `build/native-evidence/L28/signed-oct7-05/signature-checks.log` and `profile-summary.txt`.
- Archive and export logs: `build/native-evidence/L28/signed-oct7-05/archive.log` and `export.log`.
- Archive log SHA-256: `eed9056f13f907c9cf9b534cbc6fd5d3e2fcdfa652d7309d14e764fdeb52b49d`.
- Export log SHA-256: `212a50f0812772f98bb50400514a920789c95f29b948d439713374f169d41f7c`.
- Export options SHA-256: `63f7661fae650fcd0bbd69d82b266641f53c447976f1c28edcfc9995e0d86c1d`.

## Candidate 04 archive and export

Candidate 04 was archived and exported on 7 October 2026 from the Reader/Works source before the later approved Works metadata/footer and landscape glyph fix. Its archive and export are local. No upload occurred. Candidate 04 remains useful historical evidence. Candidate 05 contains the later Works fix but not the Reader Go-to accessibility detent fix. Candidate 06 contains both changes and is the current provisional package.

The r9 SE XXXL check passed 1/1. The Reader book list had a 375 × 584 pt safe viewport. The test reached and opened the John row after 9 bounded drags, then captured the top verse. Result: `build/native-evidence/L25/r9-se-xxxl-reader-top/result.xcresult`. Screenshot: `build/native-evidence/L25/r9-se-xxxl-reader-top/attachments-full/505CE675-DE92-4940-8063-279E80516FEE.png`. AX tree: `build/native-evidence/L25/r9-se-xxxl-reader-top/attachments-full/B1CC3C65-8DC2-46E5-8C53-8FE50DF52C35.txt`.

Archive: `build/native-evidence/L28/signed-oct7-04/John.xcarchive`. Export: `build/native-evidence/L28/signed-oct7-04/export/John 1:1.ipa`. IPA SHA-256: `97651909e15ef9095d91c78e72092165d7a265a365ccfcf022bb10b3cb625b18`; size: 85,765,857 bytes. Version/build: `1.5.0 (19)`. Bundle IDs: `com.nrsv.verse` and `com.nrsv.verse.widget`. App Group: `group.com.nrsv.verse`.

Archive command:

```sh
xcodebuild archive -project native/John/John.xcodeproj -scheme 'John Update' -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/native-evidence/L28/signed-oct7-04/John.xcarchive \
  -derivedDataPath build/native-evidence/L28/signed-oct7-04/DerivedData \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=QZ44N522NQ
```

The archive succeeded. Its app and widget use Apple Development signing for team `QZ44N522NQ`, with two registered devices in each development profile. Export used `build/native-evidence/L28/signed-oct7-04/ExportOptions.plist`: `method=app-store-connect`, `destination=export`, `teamID=QZ44N522NQ`, `signingStyle=automatic`, `manageAppVersionAndBuildNumber=false`, and `uploadSymbols=false`. It does not set thinning.

```sh
xcodebuild -exportArchive \
  -archivePath build/native-evidence/L28/signed-oct7-04/John.xcarchive \
  -exportOptionsPlist build/native-evidence/L28/signed-oct7-04/ExportOptions.plist \
  -exportPath build/native-evidence/L28/signed-oct7-04/export \
  -allowProvisioningUpdates
```

The export succeeded with Apple Distribution signing for North Boutique Studios Ltd (team `QZ44N522NQ`). App and widget Store profiles use the expected bundle IDs and App Group, `get-task-allow=false`, no provisioned devices, and expire 5 October 2027. Archive app and widget profiles use the expected IDs and group, `get-task-allow=true`, two devices, and expire 7 October 2027. `codesign --verify --deep --strict` passed for the archive app, archive widget, exported app, and exported widget.

Archive app and widget executable SHA-256 values are `8e59a8f403f88018ce0ef5abe6a9e5ec5cb5d45f9868f225ffc7a8dddbb2f617` and `cfded611c1e53ce9e60f6472eabb59474610c8bd83b7afa2a89c4ed199daeef8`. Export app and widget executable hashes are `0ba018e30706cde73b90cddf405e7cf24599b4a845a2ca2909ff581d8235299a` and `935b13aef4683f9e536e61812c1f3b4998bf41ab9a224381774deeeb092786f0`.

Source SHA-256 manifests cover 28 release-relevant files: `build/native-evidence/L28/signed-oct7-04/source-before.sha256` and `source-after.sha256`. Their own SHA-256 hashes are `fad2a397131f506dc27755e87709144a9f8dfbdd22f3cc82c743e54611884016` and `50e0c57574917b407fbc12741182a06d835d26ea723f7311de30b5e78515c9e6`. The only difference is test-only `native/John/SimulatorSupport/PositiveNoticeUITests.swift`, which changed during the archive window. The `John Update` scheme builds only `John` and `JohnWidget`; its `TestAction` has no test target. The archive log also has no `JohnUITests` or `SystemAccessibilityUITests` target. This test-source edit is not part of the signed Release app or widget. The release app source hashes are ReaderView `4d974cd0d5b95637134de0137a8f5b58e80d9bebee33a276115cb115f1c26248` and WorkReaderView `f45877e84e7144de67a7fe3a82c2935048517995c25515314fc440f3eb1ba884`.

Archive and export L28 inspections each report 18 PASS, 0 FAIL, 2 REVIEW, and 0 USER-GATED. C04 deployment floor/platform, C05 architecture, C09 signed IDs/group/team, C12 privacy API hints, and C13-C15 debug exclusions pass. C15 includes `-JohnTabBarMinimize` in the source-name list and found no package hit. C10 remains profile review; direct inspection confirms the archive and Store profile facts above. C19 remains review for device families/orientations; native landscape support was accepted in `L25-helper-and-run-plan-review.md:65`.

`verify-release-package.py` passed with 0 errors on archive and export. `check_media_package.py` passed on both. All six Rosary entries match source. No media URI or sample URL was found. These are package checks. They do not prove media playback.

Reports and checks:

- L28: `build/native-evidence/L28/inspect-oct7-archive-04-final/` and `build/native-evidence/L28/inspect-oct7-export-04-final/`.
- Resources: `build/native-evidence/L28/resources-oct7-archive-04-final/report.json` and `build/native-evidence/L28/resources-oct7-export-04-final/report.json`.
- Media: `build/native-evidence/L28/media-oct7-archive-04-final/media-package-report.json` and `build/native-evidence/L28/media-oct7-export-04-final/media-package-report.json`.
- Archive log SHA-256: `9159374adfecc50b3c50bf3143e859d084486448f4c1d078315ed2bb6e46b15a`.
- Export log SHA-256: `2e9b5d09f5fcf91aad682337b22dcea559326fe491569106b3c780d5095ca439`.
- Export options SHA-256: `63f7661fae650fcd0bbd69d82b266641f53c447976f1c28edcfc9995e0d86c1d`.
- Signature verification details: `build/native-evidence/L28/signed-oct7-04/signature-checks.log` (SHA-256 `b334b7cc1645d18c5be83d6ca8da1a3bdadabbebc47eff65dd23bfb6051832ab`).
- Test-only source exclusion proof: `build/native-evidence/L28/signed-oct7-04/release-test-source-exclusion.txt`.

## Candidate 03 archive and export

Candidate 03 was archived and exported on 7 October 2026 from the approved compact Reader/Works source. The archive and export are local. No upload occurred. Runtime validation is still in progress, so this IPA remains provisional.

Archive: `build/native-evidence/L28/signed-oct7-03/John.xcarchive`. Export: `build/native-evidence/L28/signed-oct7-03/export/John 1:1.ipa`. IPA SHA-256: `681801fec7d443bd5594719c680ad18b1dbd202c3c4e92fd301ce60c8d7211be`; size: 85,763,963 bytes. App version/build: `1.5.0 (19)`. Bundle IDs: `com.nrsv.verse` and `com.nrsv.verse.widget`. App Group: `group.com.nrsv.verse`.

Archive command:

```sh
xcodebuild archive -project native/John/John.xcodeproj -scheme 'John Update' -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/native-evidence/L28/signed-oct7-03/John.xcarchive \
  -derivedDataPath build/native-evidence/L28/signed-oct7-03/DerivedData \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=QZ44N522NQ
```

The archive succeeded. Its app and widget use Apple Development signing for team `QZ44N522NQ`, with matching development profiles and two registered devices. Export used `build/native-evidence/L28/signed-oct7-03/ExportOptions.plist`: `method=app-store-connect`, `destination=export`, `teamID=QZ44N522NQ`, `signingStyle=automatic`, `manageAppVersionAndBuildNumber=false`, and `uploadSymbols=false`. It does not set thinning.

```sh
xcodebuild -exportArchive \
  -archivePath build/native-evidence/L28/signed-oct7-03/John.xcarchive \
  -exportOptionsPlist build/native-evidence/L28/signed-oct7-03/ExportOptions.plist \
  -exportPath build/native-evidence/L28/signed-oct7-03/export \
  -allowProvisioningUpdates
```

The export succeeded with Apple Distribution signing for North Boutique Studios Ltd (team `QZ44N522NQ`). Exported app and widget profiles have the expected bundle IDs and App Group, `get-task-allow=false`, no provisioned-device list, and expire 5 October 2027. The archive app and widget profiles have `get-task-allow=true`, two provisioned devices, and expire 7 October 2027.

Archive app and widget executable SHA-256 values are `267f179fd086d7c88a9a083a3aabfd0f22682aeded61629caacff4cd64a93d72` and `6628e7c7e30ae51f6a2c142832e590581c73ed204beb744e87e7e33209b0f40d`. Export app and widget executable hashes are `529a1caf2c0357f2c9a11f37042ec66c905ee8ae1a2aaa526e7ac9bbbed95039` and `d5a4a4131be0c17ea0310143b7878e6ac826b4377bb77080d9d6b54a043d4e54`.

`codesign --verify --deep --strict` passed for the archive app, archive widget, exported app, and exported widget. Source SHA-256 hashes for 27 changed or release-relevant `native/John` files are in `build/native-evidence/L28/signed-oct7-03/source-before.sha256` and `source-after.sha256`. Both manifest files have SHA-256 `4d0c456488cd85ef0c7b3a3804f724dbce63a8232ef22ef840642eb3329630c4`, and the after-check reports all 27 files unchanged. Current compact Reader and Works source hashes are `b3a91597f7cda1988c5eea8fac9f74abb561b5ec6f86f44af5de9a4009662863` and `f45877e84e7144de67a7fe3a82c2935048517995c25515314fc440f3eb1ba884`.

The L28 archive and export inspections each report 18 PASS, 0 FAIL, 2 REVIEW, and 0 USER-GATED. C04 deployment/platform, C05 architecture, C09 signing IDs/group/team, C12 API hints, and C13-C15 debug exclusions pass. The extended argument scan included `-JohnTabBarMinimize` in the source-name list and found no package hit. C10 is REVIEW for expected archive/store profile facts. C19 remains REVIEW; the package supports iPhone and iPad and all four orientations. The existing native landscape decision remains accepted at `L25-helper-and-run-plan-review.md:65`.

`verify-release-package.py` passed with 0 errors on archive and export. `check_media_package.py` passed on both. All six Rosary entries match source. No direct media URI or sample URL was found. These are package checks. They do not prove media playback.

Reports and checks:

- L28 reports: `build/native-evidence/L28/inspect-oct7-archive-03-final/` and `build/native-evidence/L28/inspect-oct7-export-03-final/`.
- Resource reports: `build/native-evidence/L28/resources-oct7-archive-03-final/report.json` and `build/native-evidence/L28/resources-oct7-export-03-final/report.json`.
- Media reports: `build/native-evidence/L28/media-oct7-archive-03-final/media-package-report.json` and `build/native-evidence/L28/media-oct7-export-03-final/media-package-report.json`.
- Archive log SHA-256: `de9301036d43b3b196db4c2e1be976d1891990d8f629bffc17bb46c5c1ac22b3`.
- Export log SHA-256: `900162ac84e777f60303327c25491b655435c5972541c47900bd5db29983b4fc`.
- Export options SHA-256: `63f7661fae650fcd0bbd69d82b266641f53c447976f1c28edcfc9995e0d86c1d`.
- Signature verification details: `build/native-evidence/L28/signed-oct7-03/signature-checks.log`.

## Candidate 02 archive and export

The archive used this command. It set the team on the command line. It did not change Xcode project signing settings.

```sh
xcodebuild archive -project native/John/John.xcodeproj -scheme 'John Update' -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/native-evidence/L28/signed-oct7-02/John.xcarchive \
  -derivedDataPath build/native-evidence/L28/signed-oct7-02/DerivedData \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=QZ44N522NQ
```

Result: `** ARCHIVE SUCCEEDED **`. The archive uses Apple Development signing. The matching app and widget profiles have `get-task-allow=true` and two provisioned devices. Candidate02 archive app and widget signatures pass `codesign --verify --deep --strict`.

The export used `build/native-evidence/L28/signed-oct7-02/ExportOptions.plist`. It sets `method=app-store-connect`, `destination=export`, `teamID=QZ44N522NQ`, `signingStyle=automatic`, `manageAppVersionAndBuildNumber=false`, and `uploadSymbols=false`. It does not set thinning.

```sh
xcodebuild -exportArchive \
  -archivePath build/native-evidence/L28/signed-oct7-02/John.xcarchive \
  -exportOptionsPlist build/native-evidence/L28/signed-oct7-02/ExportOptions.plist \
  -exportPath build/native-evidence/L28/signed-oct7-02/export \
  -allowProvisioningUpdates
```

Result: `** EXPORT SUCCEEDED **`. Xcode signed the app and widget with Cloud Managed Apple Distribution for team `QZ44N522NQ`. The profiles use the expected app IDs and App Group. They have `get-task-allow=false`, no provisioned-device list, and expire 5 October 2027. Archive and export app/widget signatures all pass `codesign --verify --deep --strict`.

The IPA is `build/native-evidence/L28/signed-oct7-02/export/John 1:1.ipa`. Its SHA-256 is `0b47de9cba0bb3d871cc826f32ab485664c884e99d6e69349304844d3295d3cc`. It is 82 MB. The archive is `build/native-evidence/L28/signed-oct7-02/John.xcarchive`. The export was local and did not upload. App and widget signatures use `Apple Distribution: North Boutique Studios Ltd (QZ44N522NQ)`.

The app is version `1.5.0`, build `19`. The Release app executable SHA-256 in the archive is `02e57152127e1e219edbc1b76c5f2bd876ceafdfef63d533188bfdf1a464aaea`; its widget executable is `42d90893febd68d6f3804adc44e1e4c3f69775957ec8dfb3844e31081dfa9a6d`. The exported app executable SHA-256 is `77e964a2e5320444a048cc32ef0b02792ff956026ed0425ebf7e8fb26047f746`; its widget executable is `5cff9fdb304b684ce79eb84a1457d749f329f6e789530794eaf704509d12c304`.

Both archive and export package-inspection reports have 18 PASS, 0 FAIL, 2 REVIEW, and 0 USER-GATED. C04 deployment floor, C05 architecture, C09 signed IDs/group/team/signature, C12 API hints, and C13-C15 debug exclusions pass. C15 includes `-JohnTabBarMinimize` in the inspected source-name list and found no package hit. C10 is expected profile review. C19 is accepted by the existing L25 landscape decision described below. `verify-release-package.py` passed with 0 errors on archive and export. The media package check passed on both. All six Rosary entries match source. No direct media URI, approved entry, or sample URL was found.

Reports:

- Inspector: `build/native-evidence/L28/inspect-oct7-archive-02/report.md` and `build/native-evidence/L28/inspect-oct7-export-02/report.md`.
- Resources: `build/native-evidence/L28/resources-oct7-archive-02/report.json` and `build/native-evidence/L28/resources-oct7-export-02/report.json`.
- Media: `build/native-evidence/L28/media-oct7-archive-02/report.json` and `build/native-evidence/L28/media-oct7-export-02/report.json`.
- Archive log SHA-256: `97103c0fb3878f9e9eec2f1967a20ae1e764cff20f549aeda854067a70d1c945`.
- Export log SHA-256: `dd11b3ddcb6e2b7cdd1dc99a76063bfde9e06a8b7debb40855e6637626a5889f`.
- Export options SHA-256: `63f7661fae650fcd0bbd69d82b266641f53c447976f1c28edcfc9995e0d86c1d`.

The resource manifest SHA-256 is `197839eb9aafb3c9f2a8ba101c2f55016afdf8765515ae249fdcba6897b2bc40`. It records source commit `3a1d69d9dc46f06f0be2c9f5b714c2e63022aa95`.

Source boundary base commit: `d9b1b1049940d7f8e77a08671982b2f3e775fb37`. These file hashes were checked before and after the archive. Each diff hash is SHA-256 of `git diff --binary -- <path>`.

| App source file | File SHA-256 | Diff SHA-256 |
| --- | --- | --- |
| `native/John/Features/Guides/RosaryGuideView.swift` | `353006c7b07cecc6c5e79744842dd472fa1ce96593342a921b51ca2a86a64d87` | `de9aeb86afaf767e9c2e728b4bbac2d8e8c06d9fa4448fcbf57bd57060b52066` |
| `native/John/Features/Guides/RosaryHomeView.swift` | `93723f5e219e1daca7fe75da9809096de0345ea430af602dac6edaffcb8e565a` | `31044b5f7006531e12e7442102cab286b86806965137444c1c9033bca606a7b7` |
| `native/John/Features/Reader/GoToView.swift` | `ac24772ab506e346d66135d5fcdd4b91d9be108e539d172603a076e5eee918bf` | `e4ce0885a163699573f5c45e2bb4ced9c26e2d3322d714b46bad27c1f2de838a` |
| `native/John/Features/Reader/ReaderScreenModel.swift` | `2be729f7bfa58b922ce683367482de860c88596f0dcbd743ab38627fb2ec948b` | `34f318890eb104a9b81c5b303fcff74c3ee14c2a9e83be33e25fae9ab86e0a33` |
| `native/John/Features/Reader/ReaderView.swift` | `26f04d123093942e09040b025dabe10ef9397fa553e72853753483514eb709b7` | `edc802aef659b89f34e4cc35b27aa742bd901bae5344a0cdeae5d7731c241566` |
| `native/John/Features/Secondary/SavedView.swift` | `9a381e5c594ab5e73b0be515053ce57a847373c17ea26819b0e86110356d02d3` | `d866998318f45d8f11f555802b500bb2def3eebb5b5a3e24257c526971b28fb8` |
| `native/John/Features/Secondary/SearchView.swift` | `48ccd73d2276845b09877397569ee0c48c962bf4e1cdfe2f68258941193a5c37` | `15ae9d483ab65de67239cbcf759703db1cc0e7707d6c03ecc53369d16597f8a8` |
| `native/John/Features/Settings/FullSettingsView.swift` | `97c5dd76ca51a8b089a381dace52d1eb96ea8606949e354dbacdf8052f0228a5` | `d4ac84b3f64eeabe64826116dee6b0054687da7a9ad665572252591d8d09363c` |
| `native/John/Features/Works/WorkReaderView.swift` | `7763e6be1b871b0f0256a8fffd311bd71d3301feaa6e4d8b77c3be90e199ae15` | `9c45c9f5baacccaeef140bbfe778b8f845314ac9fd9d1fd9d3f92197c628f78a` |
| `native/John/Platform/Text/ScriptureTextView.swift` | `a98add3009670a606b829d05d3337a43acd340e8dd718ba7a3053ea3f722d4a2` | `ec1aabbf4e4cc94dd8389512b09d52b0abe93aabb03de029d8c1e8f03b835cf1` |

## Candidate 01 archive and export (superseded)

The archive used this command. It set the team on the command line. It did not change the Xcode project signing settings.

```sh
xcodebuild archive -project native/John/John.xcodeproj -scheme 'John Update' -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/native-evidence/L28/signed-oct7-01/John.xcarchive \
  -derivedDataPath build/native-evidence/L28/signed-oct7-01/DerivedData \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=QZ44N522NQ
```

Result: `** ARCHIVE SUCCEEDED **`. Xcode signed the archive with Apple Development. It created matching development profiles for the app and widget. The archive has app ID `com.nrsv.verse`, widget ID `com.nrsv.verse.widget`, and App Group `group.com.nrsv.verse`. `get-task-allow` is true in this development archive.

The local export used `build/native-evidence/L28/signed-oct7-01/ExportOptions.plist`. The plist sets `method=app-store-connect`, `destination=export`, `teamID=QZ44N522NQ`, `signingStyle=automatic`, `manageAppVersionAndBuildNumber=false`, and `uploadSymbols=false`. It does not set thinning.

```sh
xcodebuild -exportArchive \
  -archivePath build/native-evidence/L28/signed-oct7-01/John.xcarchive \
  -exportOptionsPlist build/native-evidence/L28/signed-oct7-01/ExportOptions.plist \
  -exportPath build/native-evidence/L28/signed-oct7-01/export \
  -allowProvisioningUpdates
```

Result: `** EXPORT SUCCEEDED **`. Xcode signed the exported app and widget with Cloud Managed Apple Distribution for team `QZ44N522NQ`. Both have `get-task-allow=false`, the expected bundle IDs, and the expected App Group. The exported profiles expire 5 October 2027. The archive keeps dSYMs for the app, widget, and shared resource framework. The IPA does not include symbols because `uploadSymbols=false`.

The IPA is `build/native-evidence/L28/signed-oct7-01/export/John 1:1.ipa`. Its SHA-256 is `5d4528ae333fb8775d1e708c7aaed50219ba125c367954bf4be4f1b1fe2ced26`. Its size is about 82 MB. The archive is `build/native-evidence/L28/signed-oct7-01/John.xcarchive`. The export path is local. It did not upload the IPA.

The app is version `1.5.0`, build `19`. The resource manifest SHA-256 is `197839eb9aafb3c9f2a8ba101c2f55016afdf8765515ae249fdcba6897b2bc40`. The manifest records source commit `3a1d69d9dc46f06f0be2c9f5b714c2e63022aa95`.

## Candidate 01 package checks (superseded)

`l28_inspect_package.py` ran on both the archive and the exported app with `--extended-debug-args`. Each report has 18 PASS, 0 FAIL, 2 REVIEW, and 0 USER-GATED.

| Check | Archive | Export |
| --- | --- | --- |
| C04 deployment floor and platform | PASS: iOS 26.0 | PASS: iOS 26.0 |
| C05 architecture | PASS: arm64 | PASS: arm64 |
| C09 signed IDs, group, team, signature | PASS | PASS |
| C10 embedded profile summary | REVIEW: development profile; `get-task-allow=true`; 2 devices | REVIEW: Store profiles; `get-task-allow=false`; no device list |
| C12 required-reason API hints | PASS | PASS |
| C13 debug exclusion strings | PASS | PASS |
| C14 debug files | PASS | PASS |
| C15 extended debug arguments | PASS; includes `-JohnTabBarMinimize`, no package hit | PASS; includes `-JohnTabBarMinimize`, no package hit |
| C19 device family and orientations | REVIEW: iPhone and iPad; shared portrait and landscape | REVIEW: iPhone and iPad; shared portrait and landscape |

`verify-release-package.py` passed with 0 errors on both packages. `check_media_package.py` exited 0 on both packages. All six Rosary entries match source. No direct media URI, approved entry, or sample URL was found. `codesign --verify --deep --strict` passed for the exported app and widget.

The archive inspector report is `build/native-evidence/L28/inspect-oct7-archive-01/report.md`. The export inspector report is `build/native-evidence/L28/inspect-oct7-export-01/report.md`. Resource reports are in `build/native-evidence/L28/resources-oct7-archive-01/` and `build/native-evidence/L28/resources-oct7-export-01/`. Media reports are in `build/native-evidence/L28/media-oct7-archive-01/` and `build/native-evidence/L28/media-oct7-export-01/`.


## Inspector and privacy review

C10 is expected for these package stages. Candidate 02 has an Apple Development archive profile with `get-task-allow=true` and two provisioned devices. Its exported app and widget use Store profiles for team `QZ44N522NQ`, with the expected application IDs and App Group, `get-task-allow=false`, no provisioned-device list, and expiry 5 October 2027. The `REVIEW` label asks for inspection; it is not a package failure.

C19 is accepted. Both packages target device families `[1, 2]`. `UIRequiresFullScreen` is absent, so iPad multitasking remains enabled. The package supports portrait, upside-down portrait, and both landscape orientations. The native landscape behavior was accepted in `docs/native/reviews/L25-helper-and-run-plan-review.md:65`. The Works width-change supplement was intentionally native-only because the old app is portrait-only (`docs/native/reviews/L25-paired-capture-run-plan.md:232`). No orientation change is needed.

The Xcode Organizer archive list showed the selected candidate 01 archive as John Update, version 1.5.0 (19), created 7 October at 11:20 AM. I generated the Xcode Privacy Report twice. After confirming that archive was selected and loaded, the retry again produced a blank one-page PDF. The retry file is `build/native-evidence/L28/signed-oct7-01/John-PrivacyReport-retry-20261007.pdf`, SHA-256 `372c5b1c5923cf7844a70e32f19c33d913aff506683ab5f86a760879a6a951a9`. It is 805 bytes, and text extraction returns no report content. The first file has the same 805-byte blank output. The report remains unverified because Xcode generated no readable content.

I inspected every embedded `PrivacyInfo.xcprivacy` file in candidate 01 and candidate 02. The app declares UserDefaults reason `1C8F.1` and File Timestamp reason `C617.1`. The widget declares UserDefaults reason `1C8F.1`. Both declare no tracking, no tracking domains, and no collected data types. These declarations agree with C11 and C12. Each archive contains only these two privacy manifests. The local checklist requires an Organizer report and marks it USER in `docs/native/reviews/L28-gate-e-checklist.md:57,198`; the attempted action did not produce a usable report. This does not count as a privacy-report pass.

On 7 October 2026, I checked John 1:1 - Lock Bible in App Store Connect, app ID `6784763639`. The Distribution page showed version 1.5.0 as Ready for Distribution with build 18. The TestFlight page also showed build 18 and no build 19 in its Build Uploads list. This read-only check found build 19 unused at that time. Recheck before upload because App Store Connect can change. No upload occurred.

## Candidate 01 source hashes (superseded)

Base commit: `d9b1b1049940d7f8e77a08671982b2f3e775fb37`. The rows below record the app Swift source at the archive boundary. Each diff hash is SHA-256 of `git diff --binary -- <path>`.

| App source file | File SHA-256 | Diff SHA-256 |
| --- | --- | --- |
| `native/John/Features/Guides/RosaryGuideView.swift` | `353006c7b07cecc6c5e79744842dd472fa1ce96593342a921b51ca2a86a64d87` | `de9aeb86afaf767e9c2e728b4bbac2d8e8c06d9fa4448fcbf57bd57060b52066` |
| `native/John/Features/Guides/RosaryHomeView.swift` | `93723f5e219e1daca7fe75da9809096de0345ea430af602dac6edaffcb8e565a` | `31044b5f7006531e12e7442102cab286b86806965137444c1c9033bca606a7b7` |
| `native/John/Features/Reader/GoToView.swift` | `ac24772ab506e346d66135d5fcdd4b91d9be108e539d172603a076e5eee918bf` | `e4ce0885a163699573f5c45e2bb4ced9c26e2d3322d714b46bad27c1f2de838a` |
| `native/John/Features/Reader/ReaderScreenModel.swift` | `2be729f7bfa58b922ce683367482de860c88596f0dcbd743ab38627fb2ec948b` | `34f318890eb104a9b81c5b303fcff74c3ee14c2a9e83be33e25fae9ab86e0a33` |
| `native/John/Features/Reader/ReaderView.swift` | `26f04d123093942e09040b025dabe10ef9397fa553e72853753483514eb709b7` | `edc802aef659b89f34e4cc35b27aa742bd901bae5344a0cdeae5d7731c241566` |
| `native/John/Features/Secondary/SavedView.swift` | `9a381e5c594ab5e73b0be515053ce57a847373c17ea26819b0e86110356d02d3` | `d866998318f45d8f11f555802b500bb2def3eebb5b5a3e24257c526971b28fb8` |
| `native/John/Features/Secondary/SearchView.swift` | `eee5b67afac2e94e8996e5cd4fb73407ba845525b6f5d0ff5659ec76e5803a6f` | `8243804bbe6895e9935f21db5c8d4b498be6236966117b23edf6d3e26edd81ae` |
| `native/John/Features/Settings/FullSettingsView.swift` | `97c5dd76ca51a8b089a381dace52d1eb96ea8606949e354dbacdf8052f0228a5` | `d4ac84b3f64eeabe64826116dee6b0054687da7a9ad665572252591d8d09363c` |
| `native/John/Features/Works/WorkReaderView.swift` | `354a50e38e4a5742ad69404d904221ddced1febf91fe8f4439afc41022b4acc8` | `4bb5ab7ce357690d91ca385583fe02e1f5e8a982c89f9ed91fbf9e0f264cfe0f` |
| `native/John/Platform/Text/ScriptureTextView.swift` | `a98add3009670a606b829d05d3337a43acd340e8dd718ba7a3053ea3f722d4a2` | `ec1aabbf4e4cc94dd8389512b09d52b0abe93aabb03de029d8c1e8f03b835cf1` |

The Release app executable SHA-256 in the archive is `380eb23cc27f7ed410c968fe09e21d3c8c599c933a697a704a3f914d4fbe5d78`. The widget executable SHA-256 is `4f13796ed78673dcee553f723d2eae316d64d1f0deefb09911639e46a87d1cbd`. The exported app executable SHA-256 is `3f96931060e6ae4a17a26b339e0cc81f1a9bd0315d4c5dda77ac99636c7f6009`; the widget executable SHA-256 is `2747a4ea708f4a1839634bd6155de2a9147d46c5bfa2f316fce8e5bdea1e5448`.

## Remaining checks

The export proves that Xcode can sign John for team `QZ44N522NQ` and create matching Store profiles. The read-only App Store Connect check found build `19` unused on 7 October; recheck before upload. Runtime validation is still in progress. The earlier Works width-change run returned to Page 31 after resuming at Page 32, and its body hash changed. Candidate 02 contains the approved semantic-anchor fix. The runtime owner added a round-trip body check; its result is pending. Keep the IPA provisional until runtime validation is complete. The Xcode Privacy Report remains unverified because both generated PDFs are blank. Agents did not upload the IPA.
