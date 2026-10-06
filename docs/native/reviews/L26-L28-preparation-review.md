# L26 and L28 preparation review

Date: 6 October 2026.
Reviewer: Sol (architecture, review, and acceptance).
Status: **L26 procedure: accepted with fixes. Offline method M1: accepted with conditions. L28 checklist and scripts: accepted with fixes.** No run result is accepted here. `AllRouteCaptureUITests.swift` (modified by Main during L25) is not part of this review.

## Reviewed files

| File | SHA-256 |
| --- | --- |
| `docs/native/reviews/L26-release-run-procedure.md` | `694ad632af550ff2eb57f5e904a28ef7ce04d177e6284e040212d2ec9c0d26ed` |
| `docs/native/reviews/L28-gate-e-checklist.md` | `9f8c4c25a0e0bd2e0241d81279956c88513f1ff7099096285b40ca9e7181d583` |
| `scripts/native/perf/offline-shim/offline_shim.c` | `03229e2c84f8a148f7fc2093dc4dfef53f0e70717008a99f0bfd3666a1c2cc7b` |
| `scripts/native/perf/offline-shim/offline_probe.m` | `23d21dac4362922e0ca888d2a918f9129d01fcaaa3523196592fddf6bea46be2` |
| `scripts/native/perf/offline-shim/build.sh` | `e918f3ba60fa3d1d984f6d4b9bb0b0fea0e13dfe96d967d49fe1541947c351cc` |
| `scripts/native/perf/offline-shim/l26_offline_ctl.sh` | `23b68cecf9a93192cde67afe504c24faadd2df555fe56b9bbdd31e9745222d46` |
| `scripts/native/perf/l26_analyze.py` | `630524243d172db9bfb93c8ebdc64a93b40d279361482e2ac7891bb93dce0c5a` |
| `scripts/native/perf/l26_resource_sampler.py` | `34451e8aa84b20167a5e60cf84a0f6194cf45df7fd7969174c5398ac91fb19ac` |
| `scripts/native/perf/l26_installed_size.py` | `fd5c085958f572b704da7ce028e0f328550b4df88f9f6e50547b475bb7ed592c` |
| `scripts/native/perf/l26_static_network_surface.py` | `435b9c6fcd850efb8802e15d4fb43bcab633828d3d3d8c1a5dd9262f9881bf1c` |
| `scripts/native/release/l28/l28_inspect_package.py` | `76f86aa2ce1d2a6edd5b40c19f1c9f790e70a065d01e967e51bde853ab5b5d6d` |
| `scripts/native/release/l28/l28_compare_archives.py` | `d86e761c70ddf44a34c75faaa405a736866b21f7e45f7408561c4b7ece192db4` |
| `scripts/native/release/l28/l28_check_screenshots.py` | `e23e18429ff94955712869bc17c852702ff0fb4eb3ceddc26eb7813bc5a2f924` |

Sol read the sources only. Sol ran no script, no build, and no simulator command.

## 1. Offline method M1

### Scope and safety

- `simctl spawn UDID launchctl setenv` writes to the `launchd_sim` of that one device. The host `launchd` and the other devices each have their own domain. The shim changes no host network setting, no `pf` rule, no proxy, and no interface.
- The shim acts only in processes that load it: processes that the device's `launchd_sim` starts after `setenv`. Processes that run before `setenv` (for example SpringBoard and system daemons) do not load it.
- It cannot reach another project's device unless the operator passes that device's UDID. The control script checks only the UDID form. See required fix 1.
- The environment value stays until `unsetenv` or until the device shuts down. A shutdown is the reliable removal. See required fix 2.

M1 is safe for the host and for other projects under required fixes 1 and 2.

### What M1 blocks and what it does not

- In each process that loaded it: `connect`, `connectx`, `sendto`, and `sendmsg` to any IPv4 or IPv6 address (loopback too), and `getaddrinfo` for any name. Network.framework TCP uses `connectx`. Source's host test blocked `NSURLSession` this way.
- Not blocked: the private batch call `sendmsg_x` (Network.framework UDP and QUIC), and network work done by a daemon that started before `setenv`. Name lookups through `DNSServiceGetAddrInfo` go to mDNSResponder. The later `connect` is still blocked.
- The static surface (M2) shows that the app and widget link no network framework and have no network symbols. With M2, the `sendmsg_x` gap cannot carry app traffic. Keep the claim limited to in-process IP networking (see the statement below).

### Positive control

The planned control proves two things:

- The probe shows that the interpose blocks a BSD connect and `NSURLSession` in the iOS 26 simulator runtime.
- The `event=loaded proc=John` line shows that the real app loaded the shim.

It does not yet prove that a launchd-started app that uses the system URL stack is blocked. It does not prove that the setting is gone after the run. See required fix 2 for the added steps.

### Ruling

**M1 accepted, with required fixes 1 and 2.** If any control step fails, M1 is invalid for that run.

Report statement when M1 passes: "In-process IP networking was unavailable to the L26 app and widget processes of device UDID (method M1, shim SHA-256 ____). Daemons started before the setting were not affected. The host and other devices were not changed."

**Fallback if M1 fails:** M2 (static surface) plus M3 (`nettop` per PID), with the statement "Networking was not made unavailable. No network use was observed."

- What the fallback proves: the package links no network framework and has no network symbols; the bundled URLs are outbound links that open other apps; the host saw zero bytes for the sampled PIDs at the sampled times.
- What it does not prove: that the app works when no network exists; that a network attempt fails gracefully; that system frameworks inside the process made no attempt between samples.

The full offline proof then moves to S02 (Airplane Mode on a physical device). Do not turn host networking off. That is a user-only choice that affects every project.

## 2. L26 device

**Ruling: use `John iOS 26.0 Floor iPhone 17 Pro` (`56AAEED9-CA66-4584-A217-4312910F6E80`).**

- `37D1870B…` has `com.nrsv.verse` and holds L25 and L27 evidence. The L26 copy keeps `group.com.nrsv.verse`, so it would share that group container. Do not use it.
- The SE 3 and iPad devices have other form factors and can hold the old app for L25 batches B6 and B7. Do not use them for L26.
- The floor device is the same model as the reference device. It has no production-ID app.

Conditions:

1. Record runtime iOS 26.0 (23A343) in every L26 record. Do not compare these numbers with iOS 26.5 numbers.
2. Order: L26 first. Then disable the shim, shut down, boot, and confirm empty values (required fix 2). Then run the deployment-floor smoke check (L28 F7) with the network available.
3. The floor smoke check uses the same task-only copy (`com.nrsv.verse.l26`). The OS floor does not depend on the bundle ID. Never install `com.nrsv.verse` on this device. Then no production-ID app shares its group container.
4. After both checks, Main may uninstall `com.nrsv.verse.l26` (task-only). Do not delete or erase the device.

## 3. Task-only bundle ID on a Release copy

**Ruling: it does not invalidate the measurement.** Conditions:

1. Change only `CFBundleIdentifier` in the app and widget `Info.plist` files. Keep `AppGroupIdentifier`. The app code reads no hard-coded bundle ID. Sol found `com.nrsv.verse` only as the `CFBundleURLName` and in log lines that print `Bundle.main.bundleIdentifier`.
2. The executable code must not change. Record the `John` and `JohnWidget` SHA-256 before and after. If a re-sign is needed, record also the hash after `codesign --remove-signature` on a temporary copy of each executable. It must equal the same value for the unmodified product.
3. Do not use `--deep`. If a re-sign is needed, sign `PlugIns/JohnWidget.appex` first and then `John.app`, each with `codesign --force --sign -`. Record the command.
4. Run the L28 package checks on the unmodified product (`--stage unsigned --platform simulator`). Then run C13 and C14 again on the copy, so the installed bytes are covered.
5. `L26_APP_BINARY_SHA256` is the hash of the executable that is installed.

A change of bundle ID changes container paths only. Launch, chapter, search, and paging code is the same.

## 4. L28 scripts

| Script | Result |
| --- | --- |
| `l28_inspect_package.py` | Accepted after required fix 3. C00–C11 and C13–C19 follow the checklist. C09 checks the signed group, `application-identifier`, team, non-ad-hoc signature, `codesign --verify --deep --strict`, and `get-task-allow` for export. C10 prints no device ID or profile UUID. C14 file patterns are correct. |
| `l28_compare_archives.py` | Accepted. Classes and pass rule are correct. Stripped-signature comparison uses temporary copies. The volatile list has only the archive root `Info.plist`, `_CodeSignature`, and the profile. Any `Assets.car` or path difference must be explained, as the checklist says. |
| `l28_check_screenshots.py` | Accepted. It checks size in both orientations, the alpha mode and `transparency`, and 1–10 images for each class. It needs Pillow on the host. Record the version. |
| L26 scripts | Accepted. The nearest-rank percentile (`ceil(p*n)-1`) matches the text. The sampler reads only `ps` and `footprint` for processes whose path contains `/Devices/<UDID>/`. |

Defect in C12 (required fix 3): the script joins all `nm -u` output into one string and tests `h in symbols`. So `_stat` matches `_statfs`, `_fstat`, and `_statvfs`, and `_fstat` matches `_fstatfs`. C12 then gives false file-timestamp hits. It only reports REVIEW, but F2 depends on it.

Note for C13: `l29.widgetProbe` is exactly 15 bytes. In an optimized build, Swift can store a literal of 15 bytes or less inside the code, not as text. A zero for that one string is weak evidence. The other C13 strings are 16 bytes or more. They come from the same `#if DEBUG` code, so they remain valid evidence.

## 5. Findings

| ID | Ruling |
| --- | --- |
| F1 `ITSAppUsesNonExemptEncryption` | **Accept the change, user-gated.** After the user confirms the answer (U3), add `<key>ITSAppUsesNonExemptEncryption</key><false/>` to `native/John/App/Info.plist` only. The old app declared `false`. The native app uses hashing (CryptoKit SHA-256) and reads unencrypted MMKV with no key. It does no network encryption. This matches the earlier answer. C18 then passes. |
| F2 widget `_stat` | **Required rule.** After fix 3, run C12 on the Release widget executable. If `nm -u` lists `_stat`, `_fstat`, `_lstat`, `_fstatat`, `_getattrlist`, or `_fgetattrlist` (with or without the `$INODE64` suffix), add `NSPrivacyAccessedAPICategoryFileTimestamp` with reason `C617.1` to the widget manifest through `prepare-release-resources.py`. `C617.1` covers metadata of files in the app or app group container. Apple's upload scan works on symbol references, so dead code does not help. Do the same for any other hit category with its correct reason (for example `35F9.1` for `mach_absolute_time`). Keep `1C8F.1` for the widget's App Group defaults. Check the Xcode Privacy Report (user step). |
| F3 duplicate rotation data | **Plan conformance requires one copy, unless the user waives it.** The plan says to avoid duplicated corpora. Recommended fix: one embedded framework (for example `JohnSharedResources.framework` in `John.app/Frameworks`), linked by the app and the widget, that holds the `.dat` files. Both read through that framework's bundle. Do not read the containing app bundle by path from the extension. Do not copy into the App Group at first launch, because a widget can render before the app first runs. This is an app and project change. It needs a new review and a repeat of the Step 7 widget checks W1–W4. Alternative (user-gated): keep both copies for this release as a recorded exception, with the App Thinning install and download sizes from the export. |
| F4 dropped URL schemes | **Accepted.** `exp+nrsv` is the Expo development-client scheme. `com.nrsv.verse` is the scheme that Expo adds from the bundle ID. The old `src/` and `targets/` use neither: no `com.nrsv.verse://`, no `exp+nrsv`, no `Linking.createURL`, no auth session. Old widgets build `nrsv://` URLs (`VerseWidget.swift:191`, `DailyReadingWidget.swift:47`). Old notifications store relative paths (`/daily?date=…`, `/pray/rosary`). The native delegate validates those (L22). C06 stays "only `nrsv`". |
| F5 `DEVELOPMENT_TEAM` | **Accepted on the command line.** It applies to both targets and keeps the project file and the unsigned reproducibility builds unchanged. Record the full command in each signed record. |
| F8 store-screenshot helper | **Yes, write it.** The Maestro flow uses old identifiers and collides with other sessions. Source writes `StoreScreenshotUITests.swift` under these rules: gated by an env case list (no default run); the app chosen by bundle ID (task-only Release copy allowed); navigation by visible controls only; no DEBUG hook or launch argument; PNG attachments with SHA-256 and a JSON manifest (device, size, date, time zone, status-bar profile). Main adds it to the UI test list in the generator. Sol reviews it before use. The lock-screen widget slide stays a user step. |

## Required fixes

1. **`scripts/native/perf/offline-shim/l26_offline_ctl.sh`.**
   - Add an allow-list: `37D1870B-F16D-488A-8F20-959201F970D9`, `5FC2D286-6774-4428-A7F8-9B43A9076B6C`, `E76B006D-2F32-4D49-98D4-9DC1F15B7EB3`, `56AAEED9-CA66-4584-A217-4312910F6E80`. Refuse any other UDID for `enable` and `disable`.
   - Refuse `enable` unless `simctl list devices` shows the device as `Booted`.
   - Refuse `enable` unless `vtool -show-build` on the shim shows platform `IOSSIMULATOR`. Print the shim SHA-256.

2. **`L26-release-run-procedure.md`, sections 3.3 and 3.4.**
   - After step 5, add a launchd-started URL-stack control:
     1. With the shim set, terminate MobileSafari.
     2. Run `xcrun simctl openurl UDID http://127.0.0.1:PORT/l26-control-on`.
     3. Expect no request for that path in the listener log, and a `*-blocked` line from a Safari or WebKit process in the shim log.
     4. Before enable, do the same with `/l26-control-off`. Expect one request in the listener log.
   - Require a `loaded` line for every app PID that the sampler records in the run. Record whether the probe ran through the launchd environment or through `SIMCTL_CHILD_`.
   - Section 3.4: after `disable`, shut down the device, boot it again, and run `status`. Both values must be empty. Run the `raw` probe once more and expect `REACHED`. Only then use the device for any other check.

3. **`scripts/native/release/l28/l28_inspect_package.py`, C12.** Build a set of exact undefined-symbol names for each Mach-O file: first token after `nm -u`, with a `$…` suffix removed. Compare each `_` hint to that set by equality. Keep the byte search only for the non-underscore names. Report hits for each file.

4. **`L28-gate-e-checklist.md`.** Record rulings F1–F5 and F8 from this review in section 10. Add the C13 note on the 15-byte string. Add the L26 device order from ruling 2 to F7.

## Consolidated user-gated items

1. **U1:** a distribution identity and a role in team `QZ44N522NQ` for the signed archive and export.
2. **U2:** the native release version and build number.
3. **U3 / F1:** confirm the export-compliance answer (`ITSAppUsesNonExemptEncryption` = false) before Main adds the key.
4. **U4:** every App Store Connect action: upload, TestFlight, metadata, privacy answers, export compliance, submission, and release.
5. **U5:** a physical device for S02. This covers VoiceOver speech, signed widget continuity across the update, notification delivery and tap, lifecycle, native sharing, and offline under Airplane Mode if M1 fails.
6. **U6:** a 6.9-inch iPhone device and a 13-inch iPad device for store screenshots. No simulator may be created without the owner's decision. Do not use another project's device.
7. **U7:** accept the iOS 26.0 minimum (from 15.1 / 16.1). The store text and release notes must say it.
8. **F3:** keep the duplicate rotation data as an exception, or approve the shared-framework change.
9. **Privacy Report:** generate the Xcode Privacy Report in Organizer and keep it with the evidence.
10. **Optional:** allow one host `curl -sI` request for each of the six official links.
11. **Devotional catalog license:** decide whether it needs its own license or source statement.
12. **Lock-screen widget slide:** set it up on a real device, or by hand in a simulator.
13. **Only if M1 fails and the user chooses it:** a host network-off window. This affects every project on the host. Sol does not advise it.

## Fix re-check

Date: 6 October 2026. Sol re-checked fixes 1–5, the F8 helper, and the F2 rule. Sol ran no simulator command.

| File | SHA-256 |
| --- | --- |
| `docs/native/reviews/L26-release-run-procedure.md` | `6d4af2fd24f3584cf96c2cec4bf1aaf959133c2012014c7436dee1d33f77b90d` |
| `docs/native/reviews/L28-gate-e-checklist.md` | `17459e2e3d3e6e5fc9bd5cc6caa4ed09fd1cf9e222ed21323354c4a998ae4762` |
| `scripts/native/perf/offline-shim/l26_offline_ctl.sh` | `4c5cdab06c361a7ec375a61c4d38dcf85af607dd1a73dc352a2cf47d566d9eac` |
| `scripts/native/release/l28/l28_inspect_package.py` | `585403abcfd5fdf1cd43393a3357c0fec8b387496edd2f211880de193b342bcc` |
| `native/John/SimulatorSupport/StoreScreenshotUITests.swift` | `a2175172dfc91fd56a249c4c5cd58211bfede042d1841913f3147707e73c845b` |
| `native/John/SimulatorSupport/StoreScreenshotUITests-README.md` | `63cb093ddd922d2a08aa0dbedd3e441c9af82bc46c234f03a417b9fa5d7251ed` |

1. **Fix 1: accepted.** The script has the four-UDID allow-list for `enable` and `disable`. It refuses `enable` unless the device is `Booted`. It refuses a shim that `vtool` does not report as `IOSSIMULATOR`, and it prints the shim SHA-256. `disable` prints the shutdown, boot, `status`, and probe steps.
2. **Fix 2: accepted.** Section 3.3 has the Safari `openurl` control before and after enable, a `loaded` line for every sampled PID, and a record of how the probe ran. Section 3.4 has the shutdown, boot, empty `status`, and probe `REACHED`.
3. **Fix 3: accepted.** `undefined_symbol_set` gives exact names for each file, with a `$…` suffix removed. `_` hints use set equality. Other names use the byte search. Hits are reported for each file. A Swift or Objective-C symbol cut at `$` gives no false hit, because no `_` hint has that form.
4. **Fix 4: accepted, with one stale part.** Section 10 has rulings F1–F5, F7, and F8, and the C13 note. Sections 8.2 and U6 still say that no 6.9-inch or 13-inch device exists. See required fix B.
5. **F2 ruling.** The Debug `_stat` comes from DEBUG-only code (`SQLiteSupport.swift:13–20` is inside `#if DEBUG`). **Declare `C617.1` in the widget manifest only if the Release widget executable references a file-timestamp symbol** (C12 with exact names, `--stage unsigned` on the Release build). If it does, add the declaration before the archive. If it does not, keep the C12 output as evidence and add nothing. Run the same check again on the signed archive. The app keeps `C617.1`, because its SQLite code references `stat` and `fstat`.
6. **User decisions recorded.** F1: false. Main can now add the key to `native/John/App/Info.plist` (app only). F3: shared framework (Sol reviews that worktree separately). U6: `John Store iPhone 17 Pro Max` (`016FCB90-F837-4EC1-9B63-2EE6DE93A873`) and `John Store iPad Pro 13-inch (M5)` (`8A573DAB-C3EB-4C66-8D9C-EB0F47494E0F`), iOS 26.5. U7: the iOS 26.0 minimum is accepted.

### Store screenshot helper (F8)

- Type check: all 14 `SimulatorSupport` files pass with Swift 6 on `arm64-apple-ios26.0-simulator` (exit 0). The only warning is the existing one in `WorksSettingsUITests.swift:184`.
- Gating and rules are met: every case skips without `STORE_CASES`; all values are required; Debug and UI-test bundle IDs are refused; no launch argument or environment is set; the date and time-zone checks run before capture; the full screen is captured and saved as an opaque PNG; the pixel size is checked; a JSON manifest is written.
- Pixel sizes against the devices:

  | Device | Points × scale | Pixels | Class in helper and checklist |
  | --- | --- | --- | --- |
  | iPhone 17 Pro Max (`016FCB90…`) | 440 × 956 @3x | 1320 × 2868 | iPhone 6.9 inch |
  | iPhone 17 Pro (`37D1870B…` or `56AAEED9…`) | 402 × 874 @3x | 1206 × 2622 | iPhone 6.3 inch |
  | iPad Pro 13-inch (M5) (`8A573DAB…`) | 1032 × 1376 @2x | 2064 × 2752 | iPad 13 inch |

  All three sizes are in the helper table, in `l28_check_screenshots.py`, and in checklist section 8.1. That section lists the 6.3-inch class as required and the 13-inch class as required for an iPad app. Capture both iPhone classes, as the checklist says. The user confirms the sizes in App Store Connect before upload.
- **Defect: three identifiers do not exist in the Today and Pray screens.** The Today tab root is `CompanionTodayView` (`JohnApp.swift:146`). The helper waits for `app.buttons["today-readings-card"]`. That identifier exists only in `Features/Today/TodayView.swift:65`, and no screen uses that view. The helper also waits for `app.buttons["prayer-home-rosary"]`, which no app source defines. As written, the `today`, `daily`, and `pray` cases will fail. See required fix A. (`app.staticTexts["today-verse-card"]` is valid: `CompanionTodayView.swift:82`, the same query as the accepted L26 helper.)

**Verdict: fixes 1–5 accepted. F8 helper accepted after required fix A.**

### Required fixes

A. **`StoreScreenshotUITests.swift`.**
   - Lines 87 and 104: replace `app.buttons["today-readings-card"]` with `app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Today’s readings")).firstMatch`. This is the query of the accepted `ReleasePerformanceUITests.waitForUsefulToday`.
   - Line 91: replace `app.buttons["prayer-home-rosary"]` with a label query for `"Pray the Rosary"` (`PrayerHomeView.swift:41`).
   - Update the README identifier list to match.

B. **`L28-gate-e-checklist.md`.** Sections 1 (U6), 8.2, and 10 (F9): name the two new store devices and their sizes from the table above. Mark U6 and U7 as decided. Record the F1 and F3 user decisions in section 10.

C. **Step 7 helpers (found during this check; outside this file set).** `ContentFlowUITests.swift:583` uses `app.buttons["today-readings-card"]`. `ContentFlowUITests.swift:284`, `:344`, `:533` and `ScriptureCardUITests.swift:78` tap `app.buttons["today-verse-card"]`. That identifier is a `Text` in `CompanionTodayView`, not a button. Before Step 7 batches P1 and P2:
   - Open Verse Moment with the "Verse & lock screen widget" row (label query), as AllRoute route 9 does through its label fallback.
   - Open the readings with the label query from fix A.

   `AllRouteCaptureUITests` is not affected, because its `button(_:nativeID:baselineLabel:)` falls back to the label. `Features/Today/TodayView.swift` looks unused. Record it for a later dead-code removal.
