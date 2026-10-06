# F3 shared rotation framework review

Date: 6 October 2026.
Reviewer: Sol (architecture, review, and acceptance).
Status: **Accepted with fixes.** The design and the source are accepted. The change is not accepted for a release boundary until the build facts in required fix 1 are recorded. The checks in "Repeat-check list" must run again on the new build.

## Reviewed boundary

Worktree `/Users/antonlachmaniucu/Documents/lock-bible/NRSV/.claude/worktrees/agent-a2dcb11ccc83fe814`, branch `worktree-agent-a2dcb11ccc83fe814`, diff `e6c550f..550298a`:

| Commit | Content |
| --- | --- |
| `f4c58ee` | `StoreScreenshotUITests.swift` in the UI test target. The file equals the primary checkout (`7c746d18…`, with fix A from `L26-L28-preparation-review.md`; no `today-readings-card` or `prayer-home-rosary`). |
| `68d0adf` | F1: `ITSAppUsesNonExemptEncryption` = `false` in `native/John/App/Info.plist` only (user decision). Accepted. |
| `550298a` | F3: `JohnSharedResources.framework` holds `Rotation/` once. |

Sol did not build, run, or use a simulator. The worktree has no build output or build record (`build/` holds only the staged L03 tree).

## Design checks

| Check | Result |
| --- | --- |
| One copy | The framework target's Resources phase copies the staged `App/Rotation` folder. The app copies the staged App subfolders `Artwork`, `Bible`, `Calendar`, `Catalogs`, `Databases`, and `Fonts` into `App/` (the full staged list minus `Rotation`; Sol listed the staged tree). The widget copies only `Widget/daily-readings-2025…2032.json`. No target copies `Widget/<edition>.*`. |
| Same bytes as before | All 15 staged files in `App/Rotation` (`.dat`, `.offsets`, `.ot`, `.nt`, `.meta.json` for three editions) equal the `Widget/` copies byte for byte. The widget now reads the same bytes that it read before. |
| No bundle-path read, no App Group copy | `SharedResources.rotationDirectory` uses `Bundle(for:)` on a class inside the framework. The widget no longer uses `Bundle.main.resourceURL/Widget` for rotation. Nothing copies content into the App Group. ADR 0005 states the rule. |
| Extension linking rule | The framework sets `APPLICATION_EXTENSION_API_ONLY = YES`, `MACH_O_TYPE = mh_dylib`, install name base `@rpath`, and `SKIP_INSTALL = YES`. The app links it and embeds it once (Embed Frameworks, `CodeSignOnCopy`, `RemoveHeadersOnCopy`). The widget links it and does not embed it. The widget run path includes `@executable_path/../../Frameworks`: `John.app/PlugIns/JohnWidget.appex/JohnWidget` → `John.app/Frameworks`. This is Apple's supported pattern for a framework that an app and its extension share. Xcode signs the framework when it embeds it. Both use the same team. |
| JohnCore | `RotationRepository.swift` still imports Foundation only. `IndexedRotationRepository` stays a public `actor` (Sendable). The public `RotationResourceRoot` enum is removed. Sol found no other use. `ResourceRoots.widgetResource` remains for other callers. |
| Framework source | Foundation only. One `public enum SharedResources` with two computed static properties and a private token class. There is no mutable global state, so it is safe under Swift 6. |
| Widget MMKV | None. The widget and the framework do not reference MMKV. |
| Bundle IDs | `com.nrsv.verse.sharedresources` (Release) and `com.nrsv.verse.dev.sharedresources` (Debug). A framework bundle ID needs no App ID record. |
| Version | The framework `Info.plist` has `1.5.0` / `19`, equal to the app and widget today. All three are literal values. See required fix 2. |
| Privacy | The framework code calls only `Bundle(for:)` and `URL` APIs. No required-reason API is expected. `l28_inspect_package.py` scans the framework binary under the app label, so a hit would show in C12. A framework needs its own `PrivacyInfo.xcprivacy` only if its own binary has a hit. |
| Release exclusion | No new DEBUG name. The `Runtime.swift` change at line 465 is inside the existing DEBUG L04 runner block. |
| Fault injector | `widget-corpus-missing` now moves `Frameworks/JohnSharedResources.framework/Rotation/<edition>.dat`. The other code is identical to the reviewed primary file (`5216b50c…`), including the installed-path check and the restore exit code. Consistent with Step 7 ruling 5. The fault now also removes the app's Today and Verse Moment verse for that edition. See required fix 3. |
| L04 runner | `rotationAppWidgetAndMath` becomes `rotationSharedCorpusAndMath`. The 792-row check of pool count, verse fields, slot, index, and boundary stays. Only the app-versus-widget record equality is removed. That equality is now true by construction (one directory, one reader). It does not weaken the accepted Gate A result for the earlier binary. A rerun on the new build needs a ledger record (required fix 4). |

## Required fixes

1. **Build facts (Main, before acceptance).** Build Debug (build-for-testing) and Release (simulator) at the branch head. Write a build record with source hashes. On each product, record:
   - `John.app/Frameworks/JohnSharedResources.framework/Rotation/` holds exactly 15 files, and each SHA-256 equals the staged `App/Rotation` file.
   - `find` over `John.app` and `PlugIns/JohnWidget.appex` finds no `*.dat`, `*.offsets`, `*.ot`, `*.nt`, or `*.meta.json` outside the framework.
   - `otool -L PlugIns/JohnWidget.appex/JohnWidget` lists `@rpath/JohnSharedResources.framework/JohnSharedResources`. `otool -l` shows an `LC_RPATH` of `@executable_path/../../Frameworks`. The appex holds no `Frameworks` folder.
   - The framework `Info.plist` has `MinimumOSVersion` 26.0. Its executable has platform and minos 26.0 (`vtool`).
   - The embedded framework has no `Headers` folder and no `*.swiftmodule`. If Xcode keeps `Modules/*.swiftmodule`, C14 fails. Then stop it from being copied, or ask Sol to rule on C14 for this folder.
   - Run `l28_inspect_package.py --stage unsigned --platform simulator` on the Release product. Record C04, C12, C13, and C14.

2. **Version and package checks.**
   - `L28-gate-e-checklist.md` section 9.2: name `native/John/SharedResources/Info.plist` as the third file to change with the version and build (U2).
   - `l28_inspect_package.py`: C03 must also compare the framework version and build. C04 and C05 must also check the framework executable (`Frameworks/*.framework/<CFBundleExecutable>`).

3. **Fault label and Step 7 plan.** In `Step7-remaining-feature-checks-plan.md` W4 and section 2.4, state that `widget-corpus-missing` also removes the verse for that edition from the app's Today and Verse Moment screens. The W4 record must show the widget fallback and the app result for the same fault. Restore and reinstall rules stay as before.

4. **Ledger record.** In `docs/native/work-ledger.md`, record that the L04 rotation check changed name and scope at `550298a` (`rotationAppWidgetAndMath` → `rotationSharedCorpusAndMath`, with the reason). Record that earlier Gate A results remain valid for their binaries.

## Optional notes

1. The widget daily-readings years (2025–2032) are a fixed list in the generator. If staging adds a year, the generator must change too. Reading the staged folder list would remove that step.
2. The app and widget size drop (about 17.7 MB) shows in `l26_installed_size.py` and in the App Thinning report. Record both values for F3.

## Repeat-check list

These accepted checks ran on binaries with two corpus copies. They must run again on the F3 build:

1. **L04 repository runner (Debug):** the 792-row rotation check (now `rotationSharedCorpusAndMath`) and the other runner checks in the same run.
2. **Today and Verse Moment verse in the app:** one fixed-clock check that the Today verse and the Verse Moment reference and text equal the source value (`widget-expected.ts` at the same instant, edition, scope, and interval). This includes the share text of Verse Moment.
3. **Step 7 widgets W1–W4:** rendered text and sizes (W1), values after a Settings change (W2), taps (W3), and fallbacks with the moved fault path (W4). W1 must equal `widget-expected.ts`. That proves that the widget loads the framework from the app's `Frameworks` folder.
4. **W5 shared-container probe:** unchanged code, but run it on the F3 build, because the widget binary changed.
5. **L28 resource inventory:** `verify-release-package.py` and the resource-inventory report on the new Debug and Release products (the accepted mapped Debug report covered the old layout). Add the build facts of fix 1.
6. **L28 package inspection:** C00–C19 on the new Release product (after fix 2).
7. **L26 installed size:** on the L26 task-only copy of the new build.

No other accepted check depends on the rotation layout: library, search, Reader, Works, notices, and L27 import do not read it. The L25 route images of Today stay valid, because the corpus bytes are the same. Check 2 covers the code path.
