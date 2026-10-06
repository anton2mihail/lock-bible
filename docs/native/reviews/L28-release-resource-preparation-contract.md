# L28 release resource preparation contract

Date: 6 October 2026.
Reviewer: GPT-6.1 Sol.
Status: Source can prepare isolated resources now. Archive and signing acceptance remain open.

## Ownership and current gaps

Source owns new release resource files and preparation scripts. Use `native/John/Resources/Release/` and `scripts/native/release/` for this scope. Source must not edit Main's Info.plist, project/generator, build settings, shared app files, or simulator. Main owns target membership, signing, archive builds, and simulator checks.

The native app currently has an empty `UILaunchScreen`, no asset catalog, and no bundled privacy manifest. The resource stage does not package license files. Automatic signing is configured, but no development team is set. The repository's `app.json` declares team `QZ44N522NQ`. Main must verify that value against the available identity and signed baseline before using it. Missing project configuration does not prove that signing is unavailable.

## Required Source files

1. Prepare app and extension `PrivacyInfo.xcprivacy` files. Audit the native Release API use and linked MMKV Core. Do not copy the Expo manifest wholesale. Declare App Group UserDefaults reason `1C8F.1`. App container `stat`/`fstat` use fits file metadata reason `C617.1`. Include app-only UserDefaults, boot-time, or disk-space reasons only when the actual native target uses the API for that purpose. Keep a short file/API/reason table with provenance. Review third-party manifest requirements separately from the app declaration.
2. Prepare an asset catalog from canonical existing icon bytes. Include light, dark, and tinted John icons. Reuse the existing Chi Rho launch mark and plum `#371026` background. The old `ios/LockBible/SplashScreen.storyboard` and its named image/color resources are the baseline. Preserve source geometry and exact image bytes. Do not redraw or alter artwork.
3. Package exact license/notice files for MMKV Core, Lora, Space Grotesk, Feather, calendar/readings sources, and other shipped content as required by their source. Keep a source path or primary upstream URL and hash for every file. Preserve artwork credits and translation attribution/copyright. Do not invent a license when the source does not provide one. Report that specific gap.
4. Send Main a deterministic preparation command, full target/resource list, provenance manifest, and stable hashes. Small static metadata can be tracked. Keep generated resource copies reproducible. Do not add another copy of the full Bible or Works corpus.

Apple requires the privacy manifest in target resources. Its approved reasons distinguish app-private preferences from shared App Group preferences and include container file metadata. See [privacy manifest files](https://developer.apple.com/documentation/BundleResources/privacy-manifest-files) and [required API categories and reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).

## Main integration and evidence

The app and widget currently hardcode the production App Group in code, while Debug entitlements use `group.com.nrsv.verse.dev`. Main must provide one build-configured identifier in both targets and use it in the bridge writer/reader. Release remains `group.com.nrsv.verse`; Debug remains `group.com.nrsv.verse.dev`. Verify effective signed access and actual preference agreement.

Main adds asset compilation, the app icon name, launch resource/Info configuration, each privacy manifest, and license target membership. Then inspect the built resources and privacy report. Keep development scenarios, short notification triggers, sample media URLs, and diagnostic API paths out of Release.

For archive review, record toolchain, source SHA, archive command, app/extension IDs and versions, signing team, effective App Group entitlements, URL scheme, deployment floor, resource sizes, bundled notices, and Debug exclusions. Keep full profiles and device identifiers out of reports. Do not submit or publish. Signed-device and deployment-floor evidence remain in the final gate order.
