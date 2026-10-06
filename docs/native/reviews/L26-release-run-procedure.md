# L26 Release offline and performance run procedure

Date: 6 October 2026.
Author: Source.
Status: source preparation only. No simulator was started. Main owns every simulator step. No result is accepted by this file.

## 1. Scope and limits

This file tells Main how to run the L26 helper on a Release simulator build with networking unavailable for the app only.

- The helper is `native/John/SimulatorSupport/ReleasePerformanceUITests.swift`. Its accepted source is in `L26-release-measurement-source-review.md` (commit `e906108`). This procedure does not change it.
- Simulator numbers are not physical-device budgets. They include UI automation, typing, debounce, and accessibility polling. "Cold" means a new app process. It does not mean a cold OS or a cold file cache.
- The proposed targets (median 1 s, p95 1.5 s, query 150 ms) are physical-device proposals. Do not use them as simulator pass or fail limits. Do not write "meets budget" in the report.
- Memory values are host values for simulator processes. They do not prove device peak memory.
- Keep migration out of these samples. First-run setup is a separate record.
- Do not stop, reset, or change the network of any other project's simulator or of the host.

## 2. Rulings (Sol, `L26-L28-preparation-review.md`)

| ID | Ruling |
| --- | --- |
| R1 | Offline method M1 is accepted with conditions. Use the conditions in sections 3.3 and 3.4. If any control step fails, M1 is not valid for that run. |
| R2 | L26 device: `John iOS 26.0 Floor iPhone 17 Pro` (`56AAEED9-CA66-4584-A217-4312910F6E80`). Do not use `37D1870B-F16D-488A-8F20-959201F970D9` (it has `com.nrsv.verse` and holds L25 and L27 evidence). Do not use the SE 3 or iPad devices. Record runtime iOS 26.0 (23A343) in every L26 record. Do not compare these numbers with iOS 26.5 numbers. Order: L26 first. Then disable the shim, shut down, boot, and confirm empty values (3.4). Then run the deployment-floor smoke check (L28 F7) with the network available. The floor smoke check uses the same task-only copy `com.nrsv.verse.l26`. Never install `com.nrsv.verse` on this device. After both checks, Main may uninstall `com.nrsv.verse.l26`. Do not delete or erase the device. |
| R3 | The task-only bundle ID rewrite does not invalidate the measurement. The rewrite rules are in section 5, step 3. |

Report statement when M1 passes (use these words): "In-process IP networking was unavailable to the L26 app and widget processes of device UDID (method M1, shim SHA-256 ____). Daemons started before the setting were not affected. The host and other devices were not changed."

Fallback statement when M1 fails (use these words): "Networking was not made unavailable. No network use was observed." This fallback proves that the package links no network framework and has no network symbols, that the bundled URLs are outbound links that open other apps, and that the host saw zero bytes for the sampled PIDs at the sampled times. It does not prove that the app works when no network exists, that a network attempt fails gracefully, or that system frameworks in the process made no attempt between samples. The full offline proof then moves to S02 (Airplane Mode on a physical device). Do not turn host networking off.

Use the explicit UDID in every command. Never use `booted`. Boot one John device at a time. Run tests with `-parallel-testing-enabled NO`. Do not create or delete a simulator. `l26_offline_ctl.sh` accepts only the four John-owned UDIDs: `37D1870B-F16D-488A-8F20-959201F970D9`, `5FC2D286-6774-4428-A7F8-9B43A9076B6C`, `E76B006D-2F32-4D49-98D4-9DC1F15B7EB3`, and `56AAEED9-CA66-4584-A217-4312910F6E80`.

## 3. Offline method for the app only

### 3.1 Findings

The simulator shares the host network stack. `simctl` has no per-device network switch. These methods were checked on paper:

| Method | Scope | Verdict |
| --- | --- | --- |
| Network Link Conditioner, macOS Wi-Fi off, `pf`, or a proxy | Whole host | Not safe. It breaks other projects. Do not use. |
| macOS application firewall | Incoming connections only. Needs a host setting change. | Does not apply. Do not use. |
| `simctl status_bar` Wi-Fi icon | Picture only | Does not block anything. Do not use. |
| App launch flag for offline mode | App code | The app has no such flag. Adding one needs an app change and would not match Release behavior. |
| Wrap the app with `sandbox-exec` | Per process | Not possible. `launchd_sim` starts the app, and XCUITest launches it. |
| **M1: per-device interpose shim** (this file) | One simulator device | Candidate. Not run in a simulator yet. See 3.2. |
| **M2: static surface check** | Package | Supporting evidence only. It shows what code can reach the network. |
| **M3: host observation with `nettop`** | Read only | Supporting evidence only. It shows bytes sent by the processes. It blocks nothing. |

M1 does not change the host network. It sets two environment values in the launchd domain of one simulator device. It affects only processes that start in that device after the setting. The values are removed after the run.

### 3.2 M1 details

Source files (all under `scripts/native/perf/offline-shim/`):

- `offline_shim.c`: a dyld interpose library. It fails `connect`, `connectx`, `sendto`, and `sendmsg` for IPv4 and IPv6 targets (loopback too). It fails `getaddrinfo` for any host name. Local sockets, XPC, and Mach ports keep working. It writes one line for each blocked call, and one `loaded` line for each process that loads it, to the file named by `OFFLINE_SHIM_LOG`.
- `offline_probe.m`: a positive control. `raw HOST PORT` uses a BSD socket. `url URL` uses `NSURLSession`. It prints `REACHED` (exit 0) or `BLOCKED` (exit 3).
- `build.sh sim|host OUTPUT_DIR`: builds both for the iOS 26.0 simulator or for macOS. The output folder must not exist.
- `l26_offline_ctl.sh status|enable|disable --udid UDID ...`: dry run by default. It needs `--apply` to run `simctl spawn UDID launchctl setenv` or `unsetenv`. It rejects any UDID that is not one of the four John-owned devices (for `enable` and `disable`). It refuses `enable` unless the device is `Booted` and `vtool -show-build` reports the shim as `IOSSIMULATOR`. It prints the shim SHA-256.

What Source proved on 6 October 2026 (host only, loopback only, no simulator): the `sim` build compiles for `arm64-apple-ios26.0-simulator` (`vtool`: platform IOSSIMULATOR, minos 26.0). The `host` build of the same source blocks a BSD socket connect and an `NSURLSession` request to a local listener on `127.0.0.1`, and blocks name lookup for `localhost`. Without the shim, both reach the listener. No external host was contacted.

What M1 does not block: the private batch call `sendmsg_x` (Network.framework UDP and QUIC), and network work done by a daemon that started before the setting. Name lookups through `DNSServiceGetAddrInfo` go to mDNSResponder, but the later `connect` is still blocked. The static surface (M2) shows that the app and widget link no network framework. Limit every claim to in-process IP networking. The shim acts only in processes that the device's `launchd_sim` starts after the setting. SpringBoard and system daemons that already run do not load it.

What Source did not prove:

- That the iOS simulator runtime honors `DYLD_INSERT_LIBRARIES` from the launchd environment for the Release app, the widget extension, and the XCUITest-launched app.
- That interposing works for the iOS simulator `CFNetwork` and `Network.framework` paths. It works for `NSURLSession` on macOS. The iOS simulator runtime is not the same code.
- That `simctl spawn` passes the launchd environment to the probe. If it does not, pass `SIMCTL_CHILD_DYLD_INSERT_LIBRARIES` for the probe only.

Main must pass the positive control in 3.3 before any measurement. If any control step fails, M1 is not valid. Stop. Go to 3.5.

### 3.3 Positive control (before measurement)

Use device `56AAEED9-CA66-4584-A217-4312910F6E80` (R2). Boot only this John device.

1. Build the simulator shim: `scripts/native/perf/offline-shim/build.sh sim build/native-evidence/L26/offline-shim-01`. Record the SHA-256 values that the script prints.
2. Start a local listener on the host with a request log: `python3 -m http.server 18765 --bind 127.0.0.1 2> listener.log` in an empty folder. Use a free port. The log shows each request path.
3. Control without the shim. Do both parts:
   1. Probe: `xcrun simctl spawn UDID build/native-evidence/L26/offline-shim-01/offline_probe raw 127.0.0.1 18765` and the `url` form. Expect `REACHED` for both.
   2. Launchd-started URL stack: run `xcrun simctl openurl UDID http://127.0.0.1:18765/l26-control-off`. Expect exactly one request for `/l26-control-off` in the listener log. Then terminate MobileSafari: `xcrun simctl terminate UDID com.apple.mobilesafari`.
4. Enable the shim. The log stays inside the device data folder: `l26_offline_ctl.sh enable --udid UDID --shim <abs path>/offline_shim.dylib --log "$HOME/Library/Developer/CoreSimulator/Devices/UDID/data/tmp/l26-offline.log" --apply`. The script prints the shim SHA-256. Record it.
5. Control with the shim. Do both parts:
   1. Probe: run the `raw` and `url` forms again. Expect `BLOCKED`. The log must show `connect-blocked` or `connectx-blocked`. Record whether the probe ran through the launchd environment or through `SIMCTL_CHILD_DYLD_INSERT_LIBRARIES` (the second form is allowed only if `simctl spawn` does not pass the launchd environment). If it needed `SIMCTL_CHILD_`, say so in the report.
   2. Launchd-started URL stack: terminate MobileSafari, then run `xcrun simctl openurl UDID http://127.0.0.1:18765/l26-control-on`. Expect no request for `/l26-control-on` in the listener log. Expect a `*-blocked` line in the shim log from a Safari or WebKit process. If either result is different, M1 is not valid.
6. Launch the L26 Release app once: `xcrun simctl launch UDID com.nrsv.verse.l26`. The shim log must show `event=loaded` with `proc=John`. Terminate the app.
7. During the run, every app and widget PID that the sampler records must have its own `loaded` line (same `pid=` value) in the shim log. A recorded PID without a `loaded` line makes the run invalid for that PID. The analysis step lists these checks. Check them with `grep 'event=loaded' l26-offline.log` and the sampler CSV. Add the widget later (section 7).
8. Stop the listener. Record all outputs in the run folder.

A `loaded` line for each sampled PID proves the shim ran in that process. A zero count of `*-blocked` lines then means that process did not try to use an IP network. The positive control proves the block works for a probe process and for the launchd-started URL stack in the same device.

### 3.4 Disable, shut down, and prove the setting is gone

1. After the last sample, run `l26_offline_ctl.sh disable --udid UDID --apply`.
2. Shut the device down: `xcrun simctl shutdown UDID`. A shutdown is the reliable removal. Do not erase the device.
3. Boot it again: `xcrun simctl boot UDID`.
4. Run `l26_offline_ctl.sh status --udid UDID`. Both `DYLD_INSERT_LIBRARIES` and `OFFLINE_SHIM_LOG` must be empty. Record the output.
5. Start the listener again. Run `offline_probe raw 127.0.0.1 PORT` once more. Expect `REACHED`. Stop the listener.
6. Only then use the device for any other check. The floor smoke check (L28 F7) comes after this step.
7. Main may delete the log file in the device data folder. Do not touch other devices.

### 3.5 If M1 fails or Sol rejects it

No other per-app method is safe. Say this in the report. Use the fallback statement in section 2. Then use M2 and M3 only. These are the options for the user:

1. Accept observation-only evidence. Label every result "no network use observed". This is weaker than the plan wording.
2. The user chooses a time window and turns host networking off by hand while other projects are idle. The user owns this choice. Source does not advise it. It affects every project on the host.
3. Repeat offline checks on a physical device with Airplane Mode in S02.

### 3.6 Supporting evidence (always collect)

M2, static surface. Run on the Release `John.app`:

`python3 scripts/native/perf/l26_static_network_surface.py --app PATH/John.app --out NEW/network-surface.json`

It lists linked frameworks, network symbols, URL strings, and the domains in bundled JSON. On the preserved native build (`build/native-evidence/L25/preserve-prod-native-before-baseline-01/John.app`, an earlier build) the app and widget link no network framework. They have no network symbols. The bundled JSON has outbound links only (for example `www.youtube.com`, `www.ewtn.com`, `www.usccb.org`). The app opens these in another app. Repeat the check on the L26 build.

M3, host observation. While the samples run, record per-process traffic in another shell. Use `nettop -P -L 1 -p PID` once for each app PID before and after each workload. Record bytes in and out. This needs no privilege. If it shows nonzero bytes for John, record the PID and time. It blocks nothing.

## 4. Inputs

| Item | Rule |
| --- | --- |
| Source commit | Record `git rev-parse HEAD` and `git status --short`. |
| Toolchain | Record `xcodebuild -version` and the runtime build (iOS 26.5 is 23F77 on this Mac). |
| Device | Record model, runtime, and UDID. Record the host model and load (`uptime`, `pmset -g batt`, and the running simulator list). |
| Evidence folder | `build/native-evidence/L26/run-NN/`. Use a new folder for each run. |
| Task seed | A fresh install of the task-only app with no saved Works position. Record the seed ID, for example `l26-fresh-install-01`. Confirm WEB-CE is selected with one Settings screenshot. |
| Clock | Real device clock. Record date and time zone. |

Close other heavy work on the host during the 20-sample run. Record any that cannot be closed.

## 5. Build the Release package

1. Build Release for the simulator with a new DerivedData folder:

```sh
xcodebuild build -project native/John/John.xcodeproj -scheme 'John Update' -configuration Release \
  -destination "platform=iOS Simulator,id=UDID" -derivedDataPath build/native-evidence/L26/run-NN/DerivedData-release \
  ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO
```

2. Run the Release exclusion and package checks on this product before you change anything. These are the L28 checks in `L28-gate-e-checklist.md`, section 4, with `--stage unsigned --platform simulator`. Item C13 and C14 must pass.
3. Make the task-only copy. The project sets one bundle ID for each target. A command-line `PRODUCT_BUNDLE_IDENTIFIER` would change the widget too. Edit the copy instead:

```sh
cp -R .../Release-iphonesimulator/John.app build/native-evidence/L26/run-NN/John-l26.app
plutil -replace CFBundleIdentifier -string com.nrsv.verse.l26 build/native-evidence/L26/run-NN/John-l26.app/Info.plist
plutil -replace CFBundleIdentifier -string com.nrsv.verse.l26.widget build/native-evidence/L26/run-NN/John-l26.app/PlugIns/JohnWidget.appex/Info.plist
```

Rewrite rules (R3):

1. Change only `CFBundleIdentifier` in the app and widget `Info.plist` files. Keep `AppGroupIdentifier`. The app code reads no hard-coded bundle ID.
2. The executable code must not change. Record the SHA-256 of `John` and `JohnWidget` before and after the rewrite. If a re-sign is needed, also record the hash after `codesign --remove-signature` on a temporary copy of each executable. It must equal the same value for the unmodified product.
3. Do not use `--deep`. If a re-sign is needed, sign `PlugIns/JohnWidget.appex` first. Then sign `John.app`. Use `codesign --force --sign -` for each. Record the commands.
4. Run the L28 package checks on the unmodified product (`--stage unsigned --platform simulator`). After the rewrite, run C13 and C14 again on the copy, so the installed bytes are covered. Put both reports in the run folder.
5. `L26_APP_BINARY_SHA256` is the hash of the installed executable.

A change of bundle ID changes container paths only. Launch, chapter, search, and paging code is the same.

4. Record SHA-256 of `John`, `PlugIns/JohnWidget.appex/JohnWidget`, and every `Info.plist` change (see the rules above).
5. Build the UI tests (the app under test is chosen by bundle ID, so the Debug scheme is the right host for the test bundle):

```sh
xcodebuild build-for-testing -project native/John/John.xcodeproj -scheme 'John Development' \
  -destination "platform=iOS Simulator,id=UDID" -derivedDataPath build/native-evidence/L26/run-NN/DerivedData-tests \
  ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO
```

`ReleasePerformanceUITests.swift` is already in the `JohnUITests` list of the generator. Do not install the Debug app that this build makes into the L26 device. Install only the task-only Release copy.

6. Install on the L26 device: `xcrun simctl install UDID build/native-evidence/L26/run-NN/John-l26.app`.
7. Settle the install. Launch once with `simctl launch`, wait until Today shows, take one screenshot, and terminate. Record the time as "first run, not measured".

## 6. Run order

Start the offline control (section 3.3 and 3.4) first. Do every step below with it enabled.

For each of the two stages, set `STAGE_COUNT` to `3` (preflight) or `20` (recorded). Do the preflight first. Do the recorded stage only if the preflight has no setup failure. Set the test environment with the `TEST_RUNNER_` prefix:

```sh
export TEST_RUNNER_L26_RELEASE_BUNDLE_ID=com.nrsv.verse.l26
export TEST_RUNNER_L26_TASK_SEED_ID=l26-fresh-install-01
export TEST_RUNNER_L26_BUILD_CONFIGURATION=Release
export TEST_RUNNER_L26_APP_BINARY_SHA256=<John executable SHA-256>
export TEST_RUNNER_L26_SEED_TRANSLATION_ID=web-ce
export TEST_RUNNER_L26_SEED_HAS_WORKS_POSITION=false
export TEST_RUNNER_L26_SAMPLE_COUNT=$STAGE_COUNT
```

For each test, take these steps in order:

1. Start the device log capture in the background: `xcrun simctl spawn UDID log stream --style compact --predicate 'eventMessage CONTAINS "L26_"' > logs/STAGE-TEST.log`.
2. Start the sampler (section 7) in the background.
3. Run the test with `xcodebuild test-without-building -xctestrun <the .xctestrun file> -destination "platform=iOS Simulator,id=UDID" -parallel-testing-enabled NO -only-testing:JohnUITests/ReleasePerformanceUITests/TEST -resultBundlePath xcresult/STAGE-TEST.xcresult`.
4. Stop the sampler and the log capture.
5. Copy the shim log lines for this test into the run folder.

| Test | Sample method | Stage count |
| --- | --- | --- |
| `testL26ColdProcessLaunchShowsUsefulTodayContent` | The helper loops inside one run. | 3, then 20 |
| `testL26ChapterAndSearchActionLatency` | The helper loops inside one run. It excludes one warm-up for each workload. | 3, then 20 |
| `testL26LongReaderScrollAndWorksPageProgression` | The helper does one journey for each run. Add `-test-iterations STAGE_COUNT`. | 3, then 20 |

For the long test, `L26_SAMPLE_COUNT` only has to be valid. It does not change the number of journeys. The iteration count does.

If a test fails, keep its log and `.xcresult`. Do not drop a sample to improve a number. Record the failure, fix the cause with Sol, and run the whole stage again in a new folder.

## 7. Metrics

| Metric | Source of data | Samples | Notes |
| --- | --- | --- | --- |
| Cold useful-content launch | `L26_LAUNCH_SAMPLE`, `L26_SUMMARY` | 3, then 20 | Time from `launch()` to Today title, readings card, prayer action, and nonempty verse text. The log also shows if the verse is hittable. |
| Chapter open (John 1) | `L26_CHAPTER_SAMPLE` | 3, then 20, after 1 excluded warm-up | From the chapter 1 tap to the John 1 title, canonical John 1:1, and edition attribution. |
| Reference query (John 3:16) | `L26_SEARCH_SAMPLE kind=reference` | same | Includes typing and debounce. Not repository time. |
| Ordinary full-text query (`faith`) | `L26_SEARCH_SAMPLE kind=ordinary-fts` | same | Same notes. |
| Long Scripture scroll (Psalm 119) | `L26_LONG_READER` and log time stamps | 3, then 20 journeys | Counts swipes up to 24. Reports the wall time to verse 176. It is not a frame rate. |
| Long Works paging (Homily 10) | `L26_LONG_WORK` and log time stamps | same | Page 1 to page 2 with changed text. Not a frame rate. |
| Memory, app | `l26_resource_sampler.py` | one row each second | Footprint and peak footprint of each app PID. Host values. |
| Memory, widget extension | the same sampler | during the widget check | Report separately. Do not add to the app. |
| Installed size | `l26_installed_size.py` | once after the run | App bundle, extension, duplicate content, data container, App Group container. |
| Offline evidence | shim log, `nettop` notes | whole run | Count of blocked calls. Expected zero. |

The long-text helper does not log elapsed time. The analysis script takes it from the device log time stamps. They have millisecond precision and include the launch and navigation. They are a coarse wall time. They are not a frame-rate measure. Section 11 lists an optional helper change.

Memory sampler command:

`python3 scripts/native/perf/l26_resource_sampler.py --udid UDID --out build/native-evidence/L26/run-NN/memory-STAGE-TEST.csv --interval 1 --stop-file build/native-evidence/L26/run-NN/stop-sampler`

Create the stop file to stop it. The sampler reads host processes whose path is inside the named device. It finds a new PID after each app restart. Record the PID list for the report.

Widget extension use (resource sample): the extension runs only when a widget is on the Home Screen. Main adds the three widgets by hand on the dedicated John device (Step 7 ruling 3, `Step7-remaining-feature-checks-review.md`). Run the sampler for 120 seconds with the widgets visible and again after the app writes new state. Record the `JohnWidget` PID, peak footprint, and the time. Say which widget kinds were visible. The Step 7 widget tests read the Release widget text only if the bundle ID in their environment is the task-only one. Do not claim a widget timeline reload time from the simulator.

Installed size command:

`python3 scripts/native/perf/l26_installed_size.py --app build/native-evidence/L26/run-NN/John-l26.app --data-dir "$(xcrun simctl get_app_container UDID com.nrsv.verse.l26 data)" --group-dir "$(xcrun simctl get_app_container UDID com.nrsv.verse.l26 groups | head -1 | awk '{print $NF}')" --out build/native-evidence/L26/run-NN/size.json`

Check the `groups` output format before you use it. It may print a different layout.

Known size fact: on the preserved native build, the app and the widget each contain a copy of the rotation data (`App/Rotation/web-ce.dat` and `PlugIns/JohnWidget.appex/Widget/web-ce.dat`, 5,754,565 bytes; the Douay-Rheims files are 5,829,261 bytes). That is 17,690,463 bytes of duplicate content in total. The plan says to avoid duplicated corpora. Sol must decide if the widget needs its own copy. The script reports this value for the L26 build.

## 8. Analysis

Run the analysis for each stage with one device log for each test run:

```sh
python3 scripts/native/perf/l26_analyze.py \
  --log logs/recorded-launch.log --log logs/recorded-chapter-search.log --log logs/recorded-long.log \
  --resources memory-recorded-launch.csv --size size.json --out-dir analysis-recorded
```

Use one log file for each test invocation. If you pass two logs of the same invocation, the script counts the run twice.

The script:

- reads `L26_CONFIG`, the sample lines, and `L26_SUMMARY`;
- drops warm-up samples and exact duplicate lines;
- computes n, min, median, mean, p90, p95, p99, max, standard deviation, and IQR;
- uses nearest-rank percentiles: sorted values, index `ceil(p*n)-1`. For n = 20, p95 is the 19th value and p99 is the maximum. For n = 3 the tail has no meaning, and the report marks the stage "preflight only";
- compares its median and p95 with the helper's own `L26_SUMMARY` and lists any difference as a problem;
- reports a problem if the sample count is not 3 or 20, or if a long-text journey did not report a visible verse and changed text;
- writes `analysis.json` and `analysis.md`. Exit code 1 means problems exist.

It applies no performance budget.

## 9. Pass rules for the run record

The run record is complete when all of these are true. This is a record check, not a performance judgment.

1. The positive control passed before the run and the shim log shows `loaded` for the John process.
2. The sample counts are 3 (preflight) and 20 (recorded) for each timed workload, and 3 and 20 journeys for the long test.
3. Every helper assertion passed. No sample was removed by hand.
4. The analysis script reports no problem.
5. The report names the toolchain, device, runtime, source commit, binary hashes, seed ID, date, time zone, PID list, host load, and the offline method.
6. The report states that simulator numbers are not physical-device budgets.

Performance faults (for example a slow chapter open or a launch tail with large outliers) go to Sol with the raw samples. Source can then propose a cause and a fix. Do not tune the helper to pass.

## 10. Report template

Copy this to `build/native-evidence/L26/run-NN/REPORT.md` and fill every field.

```markdown
# L26 Release offline and performance report

Run: run-NN. Date and time zone: ____. Prepared by: ____.
Source commit: ____. Working tree clean: yes / no (list changes).
Toolchain: Xcode ____ (build ____). Runtime: iOS 26.0 (23A343). Device: John iOS 26.0 Floor iPhone 17 Pro (56AAEED9-CA66-4584-A217-4312910F6E80). Host: ____.
Host load during run: ____. Other simulators running: ____.

## Build identity
| Item | Value |
| --- | --- |
| Configuration | Release |
| App bundle ID / widget bundle ID | com.nrsv.verse.l26 / com.nrsv.verse.l26.widget |
| `John` executable SHA-256 (before / after any re-sign) | ____ / ____ |
| `JohnWidget` executable SHA-256 | ____ |
| Package check report (C-items) | path, result |
| Seed ID and WEB-CE screenshot | ____ |

## Offline method
Method: M1 shim / none (observation only). Shim SHA-256: ____. Positive control, before enable: raw ____, url ____, Safari `/l26-control-off` requests ____ (expect 1). After enable: raw ____, url ____, Safari `/l26-control-on` requests ____ (expect 0), Safari or WebKit `*-blocked` line ____. Probe environment: launchd / SIMCTL_CHILD_. After disable, shutdown and boot: status values ____ (expect empty), raw probe ____ (expect REACHED).
`loaded` line for each sampled PID (list app and widget PIDs): ____.
Blocked calls during the run: ____ (list host names if any).
Static surface (M2): ____. Traffic observation (M3): ____.
Statement (copy one exactly from section 2): M1 passed statement / fallback statement.

## Timed workloads (simulator, seconds)
| Workload | Stage | n | min | median | p90 | p95 | p99 | max |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Cold useful-content launch | preflight | 3 | | | n/a | n/a | n/a | |
| Cold useful-content launch | recorded | 20 | | | | | | |
| Chapter open (John 1) | preflight / recorded | 3 / 20 | | | | | | |
| Reference query (John 3:16) | | | | | | | | |
| Full-text query (faith) | | | | | | | | |
| Long Scripture journey | | | | | | | | |
| Long Works journey | | | | | | | | |

Raw samples: logs/____. Analysis: analysis-recorded/analysis.md. Problems listed by the script: ____.

## Memory (host values)
| Role | PIDs | Peak footprint (MiB) | Worst RSS (MiB) | Moment |
| --- | --- | --- | --- | --- |
| App | | | | |
| Widget extension (kinds visible: ____) | | | | |

## Installed size (simulator build)
App bundle ____ bytes. Extension ____ bytes. Duplicate content ____ bytes (list). App data container ____. App Group container ____.

## Observations and faults
List each outlier, failure, and fix request. State "none" if there is none.

## Limits (copy exactly)
These are simulator numbers. They include UI automation, typing, debounce, and accessibility polling. A new app process does not mean a cold OS or file cache. They are not physical-device budgets. The proposed physical-device targets are not applied. Host memory values do not prove device peak memory. The simulator size is not an archive size. Offline, performance, memory, and extension gates remain open until Sol accepts this record.
```

## 11. Gaps and optional changes

1. M1 is accepted by Sol with conditions (R1). It is still unproven in an iOS simulator. The controls in 3.3 decide.
2. The long-text helper reports no elapsed time or swipe count. The analysis uses log time stamps. An optional helper change would log `swipes=` and elapsed seconds inside the test. That change would alter the accepted file hash. Do it only if Sol asks. Source can prepare the diff in a docs file first.
3. The helper does not measure frame rate or hitches. Frame measurement needs Instruments on a device. Do not claim it.
4. The widget extension's real resource use needs the widgets on the Home Screen. The simulator cannot prove timeline reload timing.
5. Memory values are footprint of host processes. They are not device peak memory.
6. The L26 device is the iOS 26.0 floor device (R2). Its numbers are not comparable with iOS 26.5 numbers.
7. An archive-size and thinned-install size needs a signed export from the user's team (see L28).
