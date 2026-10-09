# Release package evidence, 7 October 2026

Owner: Luna. Base commit: `d9b1b1049940d7f8e77a08671982b2f3e775fb37`. The build used the existing working tree. No source files changed during this run.

## Build

The unsigned Release simulator app was built with this command:

```sh
xcodebuild -project native/John/John.xcodeproj -scheme "John Update" -configuration Release \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath build/native-evidence/L25/DerivedData-oct7-release-01 \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES build
```

Result: `** BUILD SUCCEEDED **`. The build log is `build/native-evidence/L28/oct7-release-01/release-build.log`, SHA-256 `70c0eaae473777c6b7ffd59b49456eac708333bf80d2990727d13da030635074`. Xcode 26.6, build 17F113, used the iOS Simulator 26.5 SDK. The generic destination did not launch a simulator.

App: `build/native-evidence/L25/DerivedData-oct7-release-01/Build/Products/Release-iphonesimulator/John.app`.

| File | SHA-256 |
| --- | --- |
| `John.app/John` | `9f175ac8bd1bebcaeb64da776a63c84a1a239cfbdaccbfceb97f46fb2637f521` |
| `John.app/PlugIns/JohnWidget.appex/JohnWidget` | `8cb6f918d59fea42e1f7325efbd34e849c20fd1896439ef3422277e04fe3c47b` |
| `native/John/Resources/Release/Resources/resource-manifest.json` | `197839eb9aafb3c9f2a8ba101c2f55016afdf8765515ae249fdcba6897b2bc40` |

## Source hashes

These file hashes record the exact source files used by the build. Diff hashes are SHA-256 of `git diff --binary -- <path>`.

| File | File SHA-256 | Diff SHA-256 |
| --- | --- | --- |
| `native/John/Features/Reader/ReaderScreenModel.swift` | `2be729f7bfa58b922ce683367482de860c88596f0dcbd743ab38627fb2ec948b` | `34f318890eb104a9b81c5b303fcff74c3ee14c2a9e83be33e25fae9ab86e0a33` |
| `native/John/Features/Reader/ReaderView.swift` | `26f04d123093942e09040b025dabe10ef9397fa553e72853753483514eb709b7` | `edc802aef659b89f34e4cc35b27aa742bd901bae5344a0cdeae5d7731c241566` |
| `native/John/Platform/Text/ScriptureTextView.swift` | `a98add3009670a606b829d05d3337a43acd340e8dd718ba7a3053ea3f722d4a2` | `ec1aabbf4e4cc94dd8389512b09d52b0abe93aabb03de029d8c1e8f03b835cf1` |
| `native/John/John.xcodeproj/project.pbxproj` | `bc1703200a37ca6b1ffa621dac089040f09346f8d161f0d2362c98a055c7fc09` | `eb760a8305c5be3aa0596ce272d5ce8b3aacba24ef2fd3864a99a3f5e383af0f` |

## Package checks

The L28 inspector ran with `--stage unsigned --platform simulator --expect-version 1.5.0 --expect-build 19 --extended-debug-args`. It reported 16 PASS, 0 FAIL, 2 REVIEW, and 1 USER-GATED. Its report is `build/native-evidence/L28/inspect-oct7-release-01/report.md` and `report.json`.

| Check | Result |
| --- | --- |
| C04 deployment floor and platform | PASS. App, widget, and framework use minimum OS 26.0 and simulator platform. |
| C12 required-reason API hints | PASS. App hits `_stat` and `_fstat`, covered by `C617.1`. Widget has no undeclared hit. These are symbol hints. |
| C13 debug exclusion strings | PASS. No listed string was found. |
| C14 debug files | PASS. No forbidden debug library, test bundle, or Swift module was found. |
| C15 extended debug argument names | PASS. The source list included `-JohnTabBarMinimize`; no listed argument was found in the Release package. |

C05 remains REVIEW because the simulator app, widget, and framework contain both `arm64` and `x86_64`. C19 remains REVIEW for device families and orientations. C09 is USER-GATED because this package is unsigned.

`verify-release-package.py` passed with 0 errors. Its report is `build/native-evidence/L28/resources-oct7-release-01/report.json`, SHA-256 `43e1da764359ca09924778490271e47d531180c3ab659f82c6a96a941197ed76`. It verified the staged resources, privacy manifests, app icons, and launch storyboard.

`check_media_package.py` exited 0. Its report is `build/native-evidence/L28/media-oct7-release-01/media-package-report.json`, SHA-256 `fd1b8a2e34ab2cd7fce7e94136cf32c44e513d83bd20f0136a548e99a8cbead2`. All six Rosary entries match source. No direct media URI, approved entry, or sample URL was found.

## Signing boundary

John archive/export signing was not tested in this review; signing readiness remains unverified. This unsigned simulator app is not a TestFlight artifact. Do not upload it. No archive or export for John was created, and no upload occurred.

The signing audit selected Xcode 26.6 (`17F113`) at `/Applications/Xcode.app`. The keychain search list included the login keychain and two temporary EAS build keychains. `security find-identity -v -p codesigning` returned one Developer ID Application identity and two Apple Development identities for North Boutique Studios Ltd (team `QZ44N522NQ`). This result covers the current listed keychains. It does not prove that Xcode automatic or cloud-managed signing cannot provide a distribution identity.

The `John Update` scheme archives the Release configuration. The John Release target uses automatic signing, but the examined project and resolved build settings have no `DEVELOPMENT_TEAM`. The audit found no installed Store profile for John bundle ID `com.nrsv.verse` or widget ID `com.nrsv.verse.widget`. It found an installed Store profile for `app.layr.mobile` under team `QZ44N522NQ` at `~/Library/Developer/Xcode/UserData/Provisioning Profiles/ab358e11-83cb-4924-99d1-329b5cc2a5b7.mobileprovision`. The profile expires 2027-10-05, has `beta-reports-active=true` and `get-task-allow=false`, and contains an Apple Distribution certificate with SHA-256 fingerprint `21:15:67:00:E2:0B:79:1B:7C:BF:99:9B:BE:DC:FF:2E:9E:4D:78:D4:0E:6A:41:04:8A:84:B3:99:F5:E4:18:96`. This profile is not for John.

Four recent Layr archives show distribution signing for the same team: `~/Library/Developer/Xcode/Archives/2026-10-05/Layr 2026-10-05 09.31.03.xcarchive` (build 46), `~/Library/Developer/Xcode/Archives/2026-10-05/Layr 2026-10-05 11.41.24.xcarchive` (build 48), `~/Library/Developer/Xcode/Archives/2026-10-05/Layr 2026-10-05 14.30.37.xcarchive` (build 49), and `~/Library/Developer/Xcode/Archives/2026-10-05/Layr 2026-10-05 15.14.10.xcarchive` (build 50). Their archive metadata and code signatures identify `iPhone Distribution: North Boutique Studios Ltd (QZ44N522NQ)` and App Store profiles. The latest archive embeds profile UUID `244c125b-97c1-4182-9a57-e1bb983ad924`, which expires 2027-09-27 and includes a distribution certificate with SHA-256 fingerprint `C0:61:2F:7D:63:C3:65:98:18:5E:38:AB:EB:62:8E:99:C6:5B:66:01:5E:15:41:4C:7D:78:6E:90:71:A0:9A:F2`. This proves recent signing for Layr. It does not prove that John can archive or export now.

The prior user-step note `pre-testflight-user-steps-20261006.md` remains a checklist for John archive/export validation. Agents must not upload.

## Later update, 7 October 2026

The signing state above was recorded before the John archive run. Xcode later created the John archive and a local App Store Connect export with automatic signing for team `QZ44N522NQ`. The export passed the signed package checks. Runtime validation is still in progress, and no upload occurred. See `oct7-signed-archive-export-evidence.md` for the artifact, hashes, and reports.
