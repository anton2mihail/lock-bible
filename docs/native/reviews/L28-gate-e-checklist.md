# L28 and Gate E checklist, scripts, and release instructions

Date: 6 October 2026.
Author: Source.
Status: source preparation only. No simulator was started. Nothing was signed, archived, uploaded, submitted, or published. Main runs the build and archive steps. The user does every step marked USER.

Scope: Gate E review items, the L28 package checks, a reproducible archive method, the media gate, the store screenshot plan, and release instructions. This file accepts no gate.

## 1. User-gated items

Source cannot do these. They need the user's Apple account, signing identity, or App Store Connect.

| ID | Item | Why it is gated |
| --- | --- | --- |
| U1 | Signed archive and signed export with team `QZ44N522NQ` ("North Boutique Studios Ltd"). | It needs a distribution identity and an App Store profile for `com.nrsv.verse`, `com.nrsv.verse.widget`, and `group.com.nrsv.verse`. See 6.1. |
| U2 | The version and build number for the native release. | The store record decides what is allowed. See 9.2. |
| U3 | Confirm the export compliance answer (`ITSAppUsesNonExemptEncryption`). | **Decided: false (the user confirmed).** Main may add the key to `native/John/App/Info.plist` (app only). See 10, finding F1. |
| U4 | App Store Connect: upload, TestFlight, metadata, screenshots, privacy answers, review submission, release. | Source and Main must not submit or publish. |
| U5 | A physical device for S02 checks (VoiceOver speech, signed widget continuity across an update, notification delivery and tap, lifecycle clearing, native sharing). | The simulator cannot prove them. |
| U6 | Simulator devices for the 6.9 inch iPhone and the 13 inch iPad screenshot sizes. | **Decided.** The owner made two store devices, both iOS 26.5: `John Store iPhone 17 Pro Max` (`016FCB90-F837-4EC1-9B63-2EE6DE93A873`, 1320x2868) and `John Store iPad Pro 13-inch (M5)` (`8A573DAB-C3EB-4C66-8D9C-EB0F47494E0F`, 2064x2752). See 8.2. |
| U7 | Accept the iOS 26.0 minimum. The live app (1.5.0, build 18) has minimum iOS 15.1. | **Decided: accepted (the user).** The store text and release notes must say it. See 10, finding F6. |

## 2. Baseline facts read from the signed Expo builds

Source read the local signed builds `build-1790194947387.ipa` (1.5.0, build 18), `build-1789946178491.ipa` (1.3.0, build 16), and `build-1782493545296.ipa` (1.0.0, build 3). Source used `codesign` and `unzip` only. All three agree:

| Item | Value |
| --- | --- |
| App ID / application-identifier | `com.nrsv.verse` / `QZ44N522NQ.com.nrsv.verse` |
| Widget ID / application-identifier | `com.nrsv.verse.widget` / `QZ44N522NQ.com.nrsv.verse.widget` |
| App Group (app and widget) | `group.com.nrsv.verse` |
| Team | `QZ44N522NQ` |
| Distribution identity | `iPhone Distribution: North Boutique Studios Ltd (QZ44N522NQ)` |
| `get-task-allow` | false |
| URL schemes in the app | `nrsv`, `com.nrsv.verse`, `exp+nrsv` |
| `MinimumOSVersion` app / widget (1.5.0, build 18) | 15.1 / 16.1 |
| iPad | `UIRequiresFullScreen` false, all four orientations |

The profile in the 1.5.0 build is an Expo-managed App Store profile. It expires on 10 October 2026. The new native release does not use it. Xcode makes its own profile.

The local keychain (read with `security find-identity`) holds two "Apple Development" identities and one "Developer ID Application: North Boutique Studios Ltd (QZ44N522NQ)" identity. It holds no distribution identity. Xcode lists team `QZ44N522NQ` (company type) and a personal team. For the App Store build, Xcode must create or fetch a distribution certificate. That needs a role in the company account that allows it (U1).

## 3. Gate E review checklist (Sol)

Gate E needs all items below. The owner column shows who supplies the evidence. Evidence stays in `build/native-evidence/`. Do not repeat accepted checks without a code change or a named fault.

| # | Item | Evidence needed | Owner | Source of the rule |
| --- | --- | --- | --- | --- |
| E1 | All 29 routes present with no placeholder flow. | The L25 paired captures for each route and state in `docs/native/parity-matrix.md`. Source grep on 6 October 2026 (commit `e6c550f`) found no "placeholder", "TODO", "FIXME", "not implemented", "coming soon", or "lorem" text in `native/John` app, feature, platform, widget, design-system, or core sources. The only matches are SwiftUI `placeholder` APIs and one unsupported `init(coder:)`. Repeat the grep at the final commit. | Main, Sol | Plan section 12, item 1 |
| E2 | Visual parity and accepted exceptions. | L25 pairs for dark, largest text, small iPhone (`John L25 Small iPhone SE 3`), iPad (`John L25 iPad A16`), keyboard, accessibility tree and focus, Reduce Motion. A written list of each approved divergence. | Main, Sol | Plan items 7, 8 |
| E3 | Content counts, hashes, and attribution match the frozen baseline. | `scripts/native/resources/verify-staging.py` report. Bible, Works, rotation, and catalog counts. Edition attribution strings. | Main | Plan item 2 |
| E4 | Reader, Fathers pagination, selection, highlights. | L06 to L10 and L20 records. | Sol | Plan item 7 |
| E5 | Step 7 features: widgets (three kinds), media, share fallback and errors, iPad share, Reader error states. | `Step7-remaining-feature-checks-plan.md` runs. | Main | Handoff step 7 |
| E6 | Offline behavior. | An L26 report accepted by Sol (see `L26-release-run-procedure.md`). | Main | Plan item 4 |
| E7 | Complete same-ID update preservation. | L27 report from the full fixture: first import, native-wins restart, repeat update, interruption boundaries. The comparator output for each. | Main | Plan items 5, 6 |
| E8 | Notices. | L22 records: enable, deny, change, disable, pending fields, imported ID, preservation of unrelated requests. | Main | Handoff step 6 |
| E9 | Privacy and dependency review. | Section 4 items C11 and C12, the Xcode Privacy Report (USER, Organizer), and `native/John/Resources/Release/README.md` audit. | Main, Sol, USER | Plan item 10 |
| E10 | Release media availability. | Section 7. | Main | Plan item 11 |
| E11 | Fresh store screenshots. | Section 8. | Main, USER | Plan item 12 |
| E12 | Reproducible archive and signed package facts. | Sections 4, 5, 6. | Main, USER | Plan item 3 |
| E13 | A list of accepted exceptions and open limits for the S02 report. | One file. Each item names its evidence. | Sol | Plan item 12 |

S02 adds the physical-device items (U5). Do not claim them from simulator images.

## 4. Package checks

Run these on the same package at each stage. Use a new output folder for each run. The scripts refuse an existing output folder.

### 4.1 Commands

Set `APP` to the `John.app` folder. For an archive it is `PATH/John.xcarchive/Products/Applications/John.app`. For an export, unzip the IPA and use `Payload/John.app`.

```sh
# New checks (this task). Exit code 1 if any FAIL.
python3 scripts/native/release/l28/l28_inspect_package.py --app "$APP" \
  --out-dir build/native-evidence/L28/inspect-STAGE-NN --stage unsigned|archive|export \
  --platform device|simulator --expect-version V --expect-build B --extended-debug-args

# Existing accepted checks.
python3 scripts/native/release/verify-release-package.py --app "$APP" \
  --widget "$APP/PlugIns/JohnWidget.appex" \
  --manifest native/John/Resources/Release/Resources/resource-manifest.json \
  --evidence-dir build/native-evidence/L28/resources-STAGE-NN
python3 scripts/native/source-fixtures/step7/check_media_package.py --app "$APP" \
  --evidence-dir build/native-evidence/L28/media-STAGE-NN
shasum -a 256 native/John/Resources/Release/Resources/resource-manifest.json   # expect 197839eb9aafb3c9f2a8ba101c2f55016afdf8765515ae249fdcba6897b2bc40
```

Use `--stage unsigned --platform simulator` for the Release simulator build. Use `--stage unsigned --platform device` for an unsigned device build. Use `archive` for the signed archive and `export` for the signed export.

### 4.2 What the inspection script checks

| ID | Check | Pass rule |
| --- | --- | --- |
| C00 | One embedded widget extension | exactly one `.appex` in `PlugIns` |
| C01, C02 | App and widget bundle IDs | `com.nrsv.verse` and `com.nrsv.verse.widget` |
| C03 | Version and build | equal in app, widget, and every embedded framework (`JohnSharedResources.framework`), and equal to `--expect-version` and `--expect-build` if given |
| C04 | Deployment floor | `MinimumOSVersion` 26.0 in the app, widget, and framework Info files, `LC_BUILD_VERSION` minos 26.0 in each Mach-O file (app, widget, and framework executables), platform `IOS` (device) or `IOSSIMULATOR` |
| C05 | Architecture | arm64 |
| C06 | URL scheme | only `nrsv` |
| C07 | `AppGroupIdentifier` Info value | `group.com.nrsv.verse` in both |
| C08 | Source Release entitlement files | both list only `group.com.nrsv.verse` |
| C09 | Signed IDs and App Group | USER-GATED for `unsigned`. For `archive` and `export`: signed groups equal `group.com.nrsv.verse`. `application-identifier` equals `QZ44N522NQ.` plus the bundle ID. Team is `QZ44N522NQ`. The signature is not ad hoc. `codesign --verify --deep --strict` passes. For `export`, `get-task-allow` must be absent or false. |
| C10 | Provisioning profile summary | REVIEW. It prints team, expiry, groups, `get-task-allow`, and the count of provisioned devices. It prints no device ID and no profile UUID. |
| C11 | Privacy manifests | present in the app root and the widget root. No tracking. No tracking domains. No collected data types. It prints the declared categories and reasons. |
| C12 | Required-reason API hints | REVIEW. For each Mach-O file it builds the set of exact undefined-symbol names from `nm -u` (a `$INODE64`-style suffix is removed). It compares each `_` hint by equality, so `_stat` does not match `_statfs` or `_fstat`. Names without `_` are found by byte search. It lists the hits for each file and flags a category that has a hit and no declaration. A hint is not proof of use. |
| C13 | Debug exclusion strings | none of `-L29MediaFailureURI`, `-L29SharedProbeRelativePath`, `l29-widget-probe`, `l29.widgetProbe`, and the two sample URLs (`commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4`, `www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3`) in any file of the bundle |
| C14 | Debug files | no `*.debug.dylib`, `__preview.dylib`, `*.xctest`, `*.dSYM`, XCTest frameworks, or `*.swiftmodule` in the bundle |
| C15 | Extended DEBUG argument names | REVIEW. It reads every `"-L##Name"` literal outside `SimulatorSupport` and looks for it in the package. Expect no hit in Release. |
| C16 | Icon | `CFBundleIconName` is `AppIcon` and `Assets.car` exists. Use `verify-release-package.py` for the three renditions. |
| C17 | Launch | `UILaunchStoryboardName` is `SplashScreen` and the compiled storyboard exists |
| C18 | Export compliance key | `ITSAppUsesNonExemptEncryption` is `false` |
| C19 | Device family and orientations | REVIEW |

C13 weakness (Sol review): `l29.widgetProbe` is exactly 15 bytes. In an optimized build, Swift can store a literal of 15 bytes or less inside the code and not as text. A zero for that one string is weak evidence. The other C13 strings are 16 bytes or more. They come from the same `#if DEBUG` code, so they remain valid evidence.

The C13 list follows Sol's ruling 2 in `Step7-remaining-feature-checks-review.md`, with the correction in `Step7-app-side-review.md`: `recordProbe` is not in the list because Swift mangles symbol names. Keep a Debug positive control. On 6 October 2026 Source ran the script on `build/native-evidence/L28/mapped-debug-build-01/John.app` as a negative control. It reported FAIL for C13 (the two sample URLs inside `John.debug.dylib`), C14 (debug dylibs), C01, C02, C07, and C18, as expected. The preserved earlier native build `build/native-evidence/L25/preserve-prod-native-before-baseline-01/John.app` passed C13 and C14. It is not a Release acceptance record.

### 4.3 Licenses and attribution

`verify-release-package.py` checks each legal file by name and SHA-256 against the 33-row manifest. The accepted resource manifest hash is `197839eb9aafb3c9f2a8ba101c2f55016afdf8765515ae249fdcba6897b2bc40`. The check must pass on the archive. In addition, Sol checks these by eye on the archive: the MMKV notice, the Lora and Space Grotesk OFL notices, both Feather notices, the calendar and readings notices, the artwork credits, and the three Bible attribution files. The devotional catalog still has no separate license file. That is an open source gap, not a package fault. The user must decide if it needs a statement.

## 5. Reproducible archive

Reproducible means: two archives from the same commit give the same app and extension code. Signature blobs and a few time stamps may differ.

### 5.1 Rules

1. Use a clean working tree at one commit. Record `git rev-parse HEAD` and `git status --short`.
2. Use the same Xcode, the same macOS, the same time zone, and the same environment for both builds. Record them.
3. Use the same absolute `-derivedDataPath` for both builds. Swift and Clang can write build paths into binaries and debug files. Delete that folder between the two builds. Use different `-archivePath` values.
4. Set `SOURCE_DATE_EPOCH` to the commit time and `ZERO_AR_DATE=1`.
5. Use the same version and build number in both builds.
6. Close other work that edits the tree during the builds.

### 5.2 Unsigned archives (Main can run now)

An unsigned device archive proves code reproducibility. It does not prove signing.

```sh
export SOURCE_DATE_EPOCH=$(git log -1 --format=%ct) ZERO_AR_DATE=1
for N in a b; do
  rm -rf build/native-evidence/L28/archive-DD
  xcodebuild archive -project native/John/John.xcodeproj -scheme 'John Update' -configuration Release \
    -destination 'generic/platform=iOS' -archivePath build/native-evidence/L28/archive-$N/John.xcarchive \
    -derivedDataPath build/native-evidence/L28/archive-DD CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO \
    | tee build/native-evidence/L28/archive-$N.log
done
python3 scripts/native/release/l28/l28_compare_archives.py \
  --a build/native-evidence/L28/archive-a/John.xcarchive --b build/native-evidence/L28/archive-b/John.xcarchive \
  --out-dir build/native-evidence/L28/compare-ab
```

The `John Update` scheme archives with the Release configuration. If Xcode refuses an unsigned device archive, Main records the exact error. Then Main uses `xcodebuild build -sdk iphoneos -configuration Release` for both builds and compares the two `Release-iphoneos/John.app` folders. Record that this changes the proof from "archive" to "build product".

Delete the shared DerivedData folder only inside your own task folder. Keep the two archives.

### 5.3 What the comparison reports

`l28_compare_archives.py` lists each file as identical, signature-only (same after the code signature is removed from a temporary copy), different, only in A, or only in B. It lists the archive `Info.plist`, `_CodeSignature` files, and `embedded.mobileprovision` apart as time-dependent. It prints `LC_UUID` for Mach-O files that differ. It exits 1 if any file is different or missing in one side. dSYM files are in the same comparison. Source tested the script on a copy of a built app with one changed resource and one re-signed binary. It reported the changed file as different and the re-signed binary as signature-only.

Pass rule: no "different", no "only in" entries, and all Mach-O `LC_UUID` values equal in both archives. Explain every "different" file. A known cause can be an embedded absolute path. Do not accept an unexplained difference.

### 5.4 Signed archives (USER-gated)

After U1, repeat 5.2 with signing on (`-allowProvisioningUpdates DEVELOPMENT_TEAM=QZ44N522NQ`, no `CODE_SIGNING_ALLOWED=NO`). Signature blobs and the profile can differ between two signed builds. Expect "signature-only" entries. The code must still be identical.

## 6. Signed archive, export, and signed package facts

### 6.1 Prerequisites (USER)

1. Xcode is signed in to an Apple ID with a role in team `QZ44N522NQ` that can create or use a distribution certificate and App Store profiles.
2. The App ID `com.nrsv.verse`, the extension ID `com.nrsv.verse.widget`, and the App Group `group.com.nrsv.verse` exist. They exist for the live app. The native project has no `DEVELOPMENT_TEAM` setting and uses automatic signing. Main passes `DEVELOPMENT_TEAM=QZ44N522NQ` on the command line. Main must not edit the project file for this without Sol.
3. The user decides U2 before the archive. The build number goes into the archive.

### 6.2 Commands (Main runs after the user confirms 6.1)

```sh
xcodebuild archive -project native/John/John.xcodeproj -scheme 'John Update' -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/native-evidence/L28/signed-01/John.xcarchive \
  -derivedDataPath build/native-evidence/L28/signed-01/DerivedData -allowProvisioningUpdates DEVELOPMENT_TEAM=QZ44N522NQ
```

Create `ExportOptions.plist` in the run folder with these keys: `method` = `app-store-connect`, `destination` = `export`, `teamID` = `QZ44N522NQ`, `signingStyle` = `automatic`, `uploadSymbols` = true, `thinning` = `<thin-for-all-variants>`. The value `export` writes an IPA to disk. Do not use `upload`. Upload is a submit action (U4).

```sh
xcodebuild -exportArchive -archivePath build/native-evidence/L28/signed-01/John.xcarchive \
  -exportOptionsPlist build/native-evidence/L28/signed-01/ExportOptions.plist \
  -exportPath build/native-evidence/L28/signed-01/export -allowProvisioningUpdates
```

### 6.3 Checks on the signed package

1. Run section 4.1 with `--stage archive` on the archive app and `--stage export` on the unzipped IPA.
2. Compare the facts with section 2. The IDs, group, and team must match the baseline. The distribution identity name should match. If it differs, the user must explain why.
3. Keep full profiles, profile UUIDs, certificates, and device IDs out of reports. The script prints none.
4. The export contains `App Thinning Size Report.txt`. Record the install and download sizes for the target devices. This is the archive-size record that L26 cannot give.
5. Save the Xcode Privacy Report (Organizer, "Generate Privacy Report") with the evidence (USER).
6. Check the signed widget extension has the same group. A simulator package cannot prove effective container access. Only a signed device test can (S02).

## 7. Media gate and the six official links

1. Run `check_media_package.py` on the Release package (section 4.1). It compares the bundled Rosary catalog with `ROSARY_MEDIA_EPISODES` in `src/services/rosary/catalog.ts`. It must report no problem, no approved direct media URI, and no entry marked approved. It also scans the app, the extension, and the catalog for the two sample URLs.
2. Check the six official links by value. Each is a `https://www.youtube.com/watch?v=ID` link:

| Episode | ID |
| --- | --- |
| Why pray the Rosary | `vE247jOt4AA` |
| How to pray the Rosary | `HXcWknfC0vI` |
| Joyful mysteries | `ckUJRg04jyg` |
| Sorrowful mysteries | `ry7FbjkN-p0` |
| Glorious mysteries | `WoJ1hQTVdSo` |
| Luminous mysteries | `b2EjBt2PFpc` |

3. Check the player behavior on the Release simulator build: no sample player, no sample URL, official link opens outside the app (Step 7 media checks).
4. Optional host check of link availability: one `curl -sI` request for each URL from the host. This sends a request from the host and not from the app. Run it only if the user agrees. A page that loads today does not prove approval.
5. C13 covers the sample URLs. A missing sample string is package evidence. It does not prove that no sample player code exists. Main also shows the Release player state in the simulator.

## 8. Store screenshots

### 8.1 Sizes (read 6 October 2026)

Source read Apple's "Screenshot specifications" page. The page changes. The user must confirm the sizes in the App Store Connect upload screen before submission.

| Class | Portrait sizes | Rule from the page |
| --- | --- | --- |
| iPhone 6.9 inch (Dynamic Island, large) | 1260x2736, 1290x2796, 1320x2868 | Scaled by the store if not provided |
| iPhone 6.3 inch (Dynamic Island, medium) | 1179x2556, 1206x2622 | The page marks this class as required |
| iPad 13 inch | 2064x2752, 2048x2732 | Required if the app runs on iPad. The app targets iPad (`TARGETED_DEVICE_FAMILY` 1,2). |

Other rules: 1 to 10 screenshots for each class, PNG or JPEG, no alpha channel.

The page text conflicts with the older rule that 6.9 inch is the required iPhone size. Provide both iPhone sizes. The 1.5 set in `marketing/screenshots/framed/` already has 6.9, 6.7, and 6.5 inch sets and two 13 inch sets.

### 8.2 Devices

| Need | Device in this checkout | Gap |
| --- | --- | --- |
| iPhone 6.3 inch, 1206x2622 | `John 1.5 Baseline` iPhone 17 Pro (`37D1870B-F16D-488A-8F20-959201F970D9`) or `John iOS 26.0 Floor` iPhone 17 Pro (`56AAEED9-CA66-4584-A217-4312910F6E80`) | None. But see 8.3 about the production-ID app. |
| iPhone 6.9 inch, 1320x2868 | `John Store iPhone 17 Pro Max` (`016FCB90-F837-4EC1-9B63-2EE6DE93A873`), iOS 26.5, 440x956 points at 3x | None. Use only this device. The device `3F2B0C7C-EF14-4590-9F20-ECA395131E5C` and the `Layr Store Shots 17 Pro Max` device are not John devices. |
| iPad 13 inch, 2064x2752 | `John Store iPad Pro 13-inch (M5)` (`8A573DAB-C3EB-4C66-8D9C-EB0F47494E0F`), iOS 26.5, 1032x1376 points at 2x | None. `John L25 iPad A16` is an 11 inch class device (1640x2360 portrait). Do not use it for the store set. |

Do not scale or crop an image to fake a size. Do not use another project's device.

### 8.3 Capture plan

1. Use the Release build of the same commit as the archive, built for the simulator (section 5.2 of L26 uses the same build step). The device archive does not run in a simulator.
2. Use a device with a fresh install and a fixed state: WEB-CE selected, no personal notes, no saved items, no Works position, Toronto time zone, and a known date. Today content depends on the date. Choose one date and record it. The 1.5 set used real Today content.
3. If the device already has the production-ID app, use the task-only bundle ID (L26 section 5) so the production data stays intact. The store images show the same UI. The bundle ID does not appear in the UI.
4. Set the status bar before each session: `xcrun simctl status_bar UDID override --time 9:41 --batteryState charged --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3`. Use the explicit UDID. Clear it after (`status_bar UDID clear`).
5. Screens, in the order of the 1.5 slides (`marketing/frame-screenshots.py`): iPhone: lock screen with widgets (real device or hand-set up; USER), Today, Daily readings, Pray, Reader (John 1), Settings. iPad: Today, Reader, Pray, Settings. Add a Works or Scripture Card slide only if the user asks.
6. The old capture flow `marketing/capture-screenshots.yaml` uses Maestro and the old app's test IDs and texts (for example "Make room for prayer"). It does not match the native accessibility identifiers. Do not reuse it as is. Maestro also collides with other sessions on this Mac. Source wrote `native/John/SimulatorSupport/StoreScreenshotUITests.swift` (F8). It uses visible controls only, has no DEBUG hook, and chooses the app by bundle ID. Main must add it to the `SimulatorSupport` list of the generator. Sol reviews it before use. Its README, `StoreScreenshotUITests-README.md`, has the environment contract and the seed it needs.
7. Frame with `marketing/frame-screenshots.py` (it writes the three iPhone and two iPad size folders). Then run:

```sh
python3 scripts/native/release/l28/l28_check_screenshots.py \
  --iphone marketing/screenshots/framed/iphone-6.9_1320x2868 [more folders] \
  --ipad marketing/screenshots/framed/ipad-13_2064x2752 --out build/native-evidence/L28/screenshots-check-01.json
```

The script checks the format, the accepted size, no alpha, and 1 to 10 images for each class. On 6 October 2026 it passed for the 1.5 set (6 iPhone 6.9 inch images and 4 iPad 13 inch images). Those images show the old app. The release notes of 1.5.0 say the store images show the old reader. They must be replaced.

8. Source reads each image for stale text, wrong date, personal data, or Debug UI. Sol reviews the final set.
9. The user uploads them (U4). Nobody uploads from this task.

## 9. Release instructions (draft for the user)

These steps are for the person who owns the account. Main and Source do not run steps marked USER.

### 9.1 Before the build

1. Sol accepts Gate E (section 3). S02 physical-device evidence is complete or the exceptions are written down.
2. Main applies the open fixes in section 10 that Sol accepts (F1 to F5).
3. The branch is merged. The release commit is tagged. The working tree is clean.

### 9.2 Version and build (USER, U2)

The live app is 1.5.0 build 18 (App Store Connect status must be checked by the user; the earlier release notes record a submission and do not prove the current state). The native project has 1.5.0 build 19. App Store Connect accepts a higher build for a version that has not been approved. If 1.5.0 is approved, the new release needs a higher version string. The user decides the version and the build. Main then changes `CFBundleShortVersionString` and `CFBundleVersion` in three Info files: `native/John/App/Info.plist`, `native/John/Widget/Info.plist`, and `native/John/SharedResources/Info.plist` (the app, the widget, and `JohnSharedResources.framework` must match).

### 9.3 Build and verify (Main, then USER for signing)

1. Run section 5.2 (unsigned reproducibility) and section 4 on the unsigned package.
2. USER completes 6.1. Main runs 6.2 and 6.3.
3. Main sends the evidence folder to Sol. Sol checks sections 4 to 7.

### 9.4 Device checks (USER, S02)

Install the signed build on a physical device that has the live app (1.5.0, build 18) with real data. The device must receive it as an update of the same ID. The way to receive it is a TestFlight build (USER uploads it, U4) or a development-signed install. A development-signed install over an App Store install keeps the data only if iOS accepts it as an update. Check this on a spare device first. Then run the S02 list: VoiceOver speech, installed widget before and after the update, notification delivery and tap, lifecycle clearing, native sharing.

### 9.5 App Store Connect (USER)

1. Upload the signed IPA (Xcode Organizer, Transporter, or `xcrun altool`/`xcodebuild -exportArchive` with `destination upload`). This is a submit step. Do it only after the user decides.
2. Set the version, build, "What's New", screenshots (section 8), and keywords.
3. Answer App Privacy to match the privacy manifests: no tracking, no collected data. The app keeps its data on the device. Compare the answers with the live record.
4. Answer export compliance (F1).
5. Review notes. State that Rosary media opens official links and that the app needs no account.
6. Choose manual or automatic release. Choose phased release if wanted.
7. Submit for review. USER only.

### 9.6 After release

Keep the archive, the dSYMs, and the evidence folder. Record the final commit, build, App Store Connect build ID, and the Sol final report with the accepted exceptions.

## 10. Findings, rulings, and gaps

Sol's rulings are from `L26-L28-preparation-review.md` (6 October 2026).

| ID | Finding and evidence | Ruling and action |
| --- | --- | --- |
| F1 | The native `Info.plist` has no `ITSAppUsesNonExemptEncryption`. The Expo app declared `usesNonExemptEncryption: false` (`app.json`) and its built Info files show `False`. | **Decided: false (the user confirmed U3).** Main adds `<key>ITSAppUsesNonExemptEncryption</key><false/>` to `native/John/App/Info.plist` only. The native app uses hashing (CryptoKit SHA-256) and reads unencrypted MMKV with no key. It does no network encryption. This matches the earlier answer. C18 then passes. Source does not edit the file. |
| F2 | The mapped Debug widget links `JohnCore`. After the exact-name fix in C12, the widget still has an undefined `_stat` (in `JohnWidget.debug.dylib`). The widget manifest declares only `1C8F.1`. In `JohnCore`, both `stat` calls (`SQLiteSupport.swift:14` and `SQLiteOpenProbe.swift:200`) are inside `#if DEBUG`. | **Ruling (Sol, fix re-check).** The Debug `_stat` comes from `#if DEBUG` code. Declare `C617.1` in the widget manifest only if the Release widget executable (or the signed archive's widget) references a file-timestamp symbol. Use C12 with exact names (`--stage unsigned` on the Release build, and again on the signed archive). If it does, add the declaration through `prepare-release-resources.py` before the archive. If it does not, keep the C12 output as evidence and add nothing. The app keeps `C617.1`, because its SQLite code references `stat` and `fstat`. Keep `1C8F.1` for the widget. Other hit categories use their own correct reasons (for example `35F9.1` for `mach_absolute_time`). Check the Xcode Privacy Report (user step). |
| F3 | The app and the widget each hold a copy of the rotation data: 17,690,463 bytes of duplicate content in the preserved build. | **Decided: shared framework (the user). In progress in a separate worktree.** One embedded framework (for example `JohnSharedResources.framework` in `John.app/Frameworks`), linked by the app and the widget, holds the `.dat` files. Both read through that framework's bundle. Do not read the containing app bundle by path from the extension. Do not copy into the App Group at first launch, because a widget can render before the app first runs. Sol reviews that worktree separately. The change needs a repeat of the Step 7 widget checks W1 to W4. After it lands, run `l26_installed_size.py` again. The duplicate content must be 0 bytes. Run C12, C13, C14, and the resource check again on the new package. The new framework is a new Mach-O file in the bundle. |
| F4 | The old app registered `nrsv`, `com.nrsv.verse`, and `exp+nrsv`. The native app registers only `nrsv`. | **Accepted.** `exp+nrsv` is the Expo development-client scheme. `com.nrsv.verse` is the scheme that Expo adds from the bundle ID. The old `src/` and `targets/` use neither. Old widgets build `nrsv://` URLs. Old notifications store relative paths. The native delegate validates those (L22). C06 stays "only `nrsv`". |
| F5 | The Release configuration has no `DEVELOPMENT_TEAM`. | **Accepted on the command line.** `DEVELOPMENT_TEAM=QZ44N522NQ` applies to both targets and keeps the project file and the unsigned reproducibility builds unchanged. Record the full command in each signed record. |
| F6 | The minimum OS rises from 15.1 (app) and 16.1 (widget) to 26.0. | User decision (U7). The store text and release notes must say it. |
| F7 | The 26.0 runtime check is open. | **L26 device order (Sol ruling 2).** L26 runs on `John iOS 26.0 Floor iPhone 17 Pro` (`56AAEED9-CA66-4584-A217-4312910F6E80`). Order: L26 first; then disable the shim, shut down, boot, and confirm empty values; then the deployment-floor smoke check with the network available (launch, Today, Reader, Search, Works, widget), using the same task-only copy `com.nrsv.verse.l26`. Never install `com.nrsv.verse` on this device. Do not use `37D1870B-F16D-488A-8F20-959201F970D9`. Record runtime iOS 26.0 (23A343). Main may uninstall `com.nrsv.verse.l26` afterward. Do not delete or erase the device. |
| F8 | No native store-screenshot helper existed. The Maestro flow uses old identifiers and collides with other sessions. | **Yes, write it.** Done: `StoreScreenshotUITests.swift`. Rules met: gated by `STORE_CASES`; app chosen by bundle ID; visible controls only; no DEBUG hook or launch argument; PNG attachments with SHA-256 and a JSON manifest (device, size, date, time zone, status-bar profile). Main adds it to the generator. Sol reviews it before use. The lock-screen widget slide stays a user step. |
| F9 | A 6.9 inch iPhone device and a 13 inch iPad device did not exist for John. | **Decided (U6).** `John Store iPhone 17 Pro Max` (`016FCB90-F837-4EC1-9B63-2EE6DE93A873`, 1320x2868) and `John Store iPad Pro 13-inch (M5)` (`8A573DAB-C3EB-4C66-8D9C-EB0F47494E0F`, 2064x2752). Both are iOS 26.5. The helper, `l28_check_screenshots.py`, and section 8.1 accept these sizes. |
| F10 | The 1.5 profile expires 10 October 2026. The EAS-managed distribution identity is not in the local keychain. | The user chooses how to get a distribution identity (U1). The old profile does not matter for the native build. |

Consolidated user-gated items (Sol): U1 distribution identity and team role; U2 version and build; U4 every App Store Connect action; U5 physical device for S02 (including offline under Airplane Mode if M1 fails). Decided since the review: U3 (false), U6 (two store devices), U7 (iOS 26.0 accepted), F3 (shared framework); the Xcode Privacy Report; optionally one host `curl -sI` request for each of the six links; the devotional catalog license decision; the lock-screen widget slide; and, only if M1 fails and the user chooses it, a host network-off window (Sol does not advise it).

## 11. Scripts delivered

| File | Purpose |
| --- | --- |
| `scripts/native/release/l28/l28_inspect_package.py` | Checks C00 to C19 on one package. Read only. |
| `scripts/native/release/l28/l28_compare_archives.py` | Compares two archives or apps. Read only. |
| `scripts/native/release/l28/l28_check_screenshots.py` | Checks screenshot format, size, alpha, and count. Read only. Needs Pillow (record the version). |
| `native/John/SimulatorSupport/StoreScreenshotUITests.swift` | Native store-screenshot capture helper (F8). Main adds it to the generator. |
| `scripts/native/perf/` | L26 analysis, sampler, size, network surface, and offline shim. See `L26-release-run-procedure.md`. |

Each script writes only to a new path that it creates. Source tested them on host files and copies only. No simulator was used.

## 12. Evidence record template

Fill one record for each package stage.

```markdown
# L28 package record: STAGE-NN
Date and time zone: ____. Source commit: ____. Tree clean: yes / no.
Toolchain: Xcode ____ (build ____), macOS ____.
Package path and SHA-256 of `John` and `JohnWidget`: ____.
Commands and output folders: inspect ____; resources ____; media ____; compare ____.
Result by check (C00 to C19): ____. Failures and explanations: ____.
User-gated items open: ____.
Reviewer: ____. Verdict: ____.
```
