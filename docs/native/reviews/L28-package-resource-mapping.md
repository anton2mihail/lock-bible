# L28 package resource mapping

Date: 6 October 2026.
Reviewer: GPT-6.1 Sol.
Verdict: mapping and revised Debug resource package accepted. Release package and archive checks remain open.

The frozen development inventory report is `build/native-evidence/L28/resource-inventory-report-01/report.json`, SHA-256 `635410cbe70daca76859b3e8d8090f714cb44325d066d9efcd1daa56b0619a30`. It reports 16 errors. All eight registered fonts match. App privacy, 12 legal files, widget privacy, compiled assets and compiled launch resources are missing. This is a development-package observation.

Use the accepted 33-row source resource manifest, SHA-256 `197839eb9aafb3c9f2a8ba101c2f55016afdf8765515ae249fdcba6897b2bc40`.

| Staged resource | Target | Final package action |
| --- | --- | --- |
| `Assets.xcassets` | App only | Compile the catalog. Set `ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon`. Preserve AppIcon light/dark/tinted, SplashScreenLogo and SplashScreenBackground. |
| `Launch/SplashScreen.storyboard` | App only | Compile the exact source storyboard. Set `UILaunchStoryboardName=SplashScreen`. |
| `App/PrivacyInfo.xcprivacy` | App only | Copy to the app bundle root. |
| All 12 `Legal/*` files | App only | Copy exact manifest bytes into the bundle `Legal/` directory. |
| `Widget/PrivacyInfo.xcprivacy` | Widget only | Copy to the extension bundle root. |
| Eight fonts | App only | Keep current verified paths and `UIAppFonts`. Do not add duplicate copies. |

Keep the existing L03 corpus membership, bundle IDs, build-configured groups, URL scheme and minimum OS. Main owns project generation and build/signing actions. Source may run the accepted read-only verifier against the frozen revised app and embedded extension.

The inventory observes empty signed App Group lists in this development package. That does not prove effective container access or a Release archive fault. Resource verification does not accept signing, archive reproducibility, compiled asset pixels, installed-widget continuity or release readiness.

The revised frozen Debug report is `build/native-evidence/L28/resource-inventory-mapped-debug-02/report.json`, SHA-256 `bc62c4f5baa6e04d044c25fc1f7908f445ff45d47070f8bbcb266a60601e364e`. It passes with no resource errors. All 22 copied resource rows match. AppIcon light/dark/tinted renditions and the compiled SplashScreen controller nib are present. The project generator places assets, launch, legal files and app privacy in the app resource phase. It places widget privacy in the widget resource phase. Existing font paths remain valid.

Observed IDs are the development IDs. The package reports version 1.5.0 build 19, minimum OS 26.0 and URL scheme `nrsv`. Signed App Group lists are empty in this package. Accept this as Debug resource membership and byte verification only. Do not repeat this inventory without a resource change. Inspect the final Release package and archive separately.

The later read-only binary review finds the correct development group in both simulator `__TEXT,__entitlements` sections. This is separate from the empty signed dictionary. See `L12-simulator-entitlement-boundary.md`. Effective shared-container access and device/archive signed entitlements remain open.
