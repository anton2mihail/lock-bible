# Release resource preparation

This folder contains source-prepared resources for the app and widget. Main owns target membership, signing, asset compilation, and archive checks.

Run `python3 scripts/native/release/prepare-release-resources.py` from the repository root. The command copies the canonical icon, launch mark, launch storyboard, fonts, licenses, and attribution files. It writes `resource-manifest.json` with source paths and SHA-256 hashes. The command does not copy Bible chapters or Works text. Use `--fresh-output --output-root PATH` for a new staged tree. The generator builds and verifies a temporary sibling, then publishes only if every expected file and hash passes. Use `--verify PATH` to check an existing tree. The default output must be empty.

The generated app target resources are under `Resources/App/PrivacyInfo.xcprivacy`, `Resources/Assets.xcassets`, `Resources/App/Fonts/`, `Resources/App/Feather.ttf`, `Resources/Launch/SplashScreen.storyboard`, and `Resources/Legal/`. The widget target resource is `Resources/Widget/PrivacyInfo.xcprivacy`. Main must add these paths to the correct targets. The asset catalog preserves the three old iOS icon PNGs and all three old iOS launch-mark PNGs byte for byte. It also preserves the old storyboard. The launch color asset preserves the existing source color values, including plum `#371026`.

## Privacy API audit

| Target | Source API | Reason | Evidence |
| --- | --- | --- | --- |
| App | `UserDefaults(suiteName:)` for App Group state | `1C8F.1` | `native/John/App/Runtime.swift`; Apple states this reason covers preferences shared by members of the same App Group. |
| Widget extension | `UserDefaults(suiteName:)` for shared widget state | `1C8F.1` | `native/John/Widget/JohnWidget.swift`; same App Group store. |
| App | `stat` in Core and MMKV to read app-container file metadata | `C617.1` | `native/John/Packages/JohnCore/Sources/JohnCore/SQLiteSupport.swift`, `native/John/LegacyAdapter/LegacyMMKVAdapter.mm`, and linked `Vendor/MMKVCore/MemoryFile.cpp`. |

The current source audit found no native call to system boot-time or disk-space APIs. The Debug-only SQLite probe also calls `stat`; the app manifest covers that call when the Debug source is linked. The widget source calls shared UserDefaults and does not call the audited file-metadata APIs. Main must record the final linked API audit for each archive target. The old Expo manifest is not used because it declares reasons for APIs that this native source audit did not find and it does not declare the App Group reason.

Apple references: [privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) and [required reason API categories and reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).

## Fonts and notices

The seven font resource names match `native/John/App/Info.plist`. Feather is staged at `Resources/App/Feather.ttf`. Main must copy this one file to the app bundle root or change `UIAppFonts` to `App/Feather.ttf`. Do not add a second font copy. The PostScript names are `Lora-Regular`, `Lora-Medium`, `SpaceGrotesk-Light`, `SpaceGrotesk-Regular`, `SpaceGrotesk-Medium`, `SpaceGrotesk-SemiBold`, `SpaceGrotesk-Bold`, and `Feather`. The Lora and Space Grotesk files use SIL Open Font License 1.1. Feather's icon notice comes from `https://github.com/feathericons/feather/blob/3dc050d97405062eba78aa57115c0a15c63abdaa/LICENSE` (revision `3dc050d97405062eba78aa57115c0a15c63abdaa`, SHA-256 `308028e93fcf84972523cdf6e616f73168546b4953895f516d01287f16fe7bee`). The existing `Feather-LICENSE.txt` is a separate MIT notice for its React Native wrapper and remains included. MMKV Core uses its vendored license. Calendar/readings source notices and artwork credits are copied without edits.

The old iOS icon images and current artwork icon variants have different file hashes but identical decoded 1024×1024 RGBA pixels in all three light/dark/tinted pairs. The manifest keeps the old iOS asset-catalog PNG bytes as the release baseline. It does not re-encode or redraw them.

The bundled Bible metadata keeps the exact WEB-CE, Douay–Rheims, and Clementine Vulgate attribution strings. The source declares these editions public domain. The devotional catalog has no separate license file in the repository. This preparation preserves the catalog attribution/credit sources but does not claim a new license for catalog prose. All artwork is public domain; see `assets/CREDITS.md`.

The provenance manifest is `Resources/resource-manifest.json`. It covers copied source bytes. Generated privacy and asset metadata are listed with their own output hashes. Main must validate the compiled assets and each target's final privacy report. This preparation does not prove target inclusion, signing, runtime entitlement access, or archive acceptance.
