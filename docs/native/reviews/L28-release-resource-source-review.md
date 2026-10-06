# Release resource source review

Date: 6 October 2026.
Owner: GPT-6.1 Sol.
Status: Corrected resource preparation accepted. The README command correction is pending. Archive acceptance remains open.

The initial stage has 31 resource rows. Each output SHA-256 matches its manifest. Each copied output matches its source SHA-256. The tree has no missing or unexpected resource file. The generator hash is `6b1962f1d7cebe13307a7a70b282e68c6c8db434ae2b2f81c0dcdb7f859002ff`. The manifest hash is `8458b76dcb719930cf26508fffaa768289ed91f79cb1c875497ab5c298f4b33c`.

## Privacy reasons

Both targets use App Group `UserDefaults`. Reason `1C8F.1` matches this use. The app adapter and MMKV Core use `stat` and `fstat` for container file metadata. Reason `C617.1` matches this use. The native source audit found no direct boot-time, disk-capacity, or active-keyboard API call. Do not copy those extra categories from the old Expo manifest. Apple describes these categories and reasons in its [required API documentation](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).

The widget links `JohnCore`. The current widget source does not call the audited library file-metadata paths. The initial README incorrectly says the widget does not link Core. Source must correct that claim. Main must inspect the final linked code and each target's privacy report before archive acceptance.

## Assets and notices

The stage preserves the old iOS asset-catalog PNGs and launch color exactly. The icon PNG bytes differ from the current `assets/artwork/john-icon` variants. Source must label the old iOS baseline and report whether decoded pixels match. Do not substitute an icon during this review.

The stage preserves exact Lora and Space Grotesk OFL notices, the vendored MMKV notice, calendar/readings notices, artwork credits, and three Bible attribution files. Existing Works metadata contains collection attribution. The README reports the separate devotional license gap without inventing a license.

The current `Feather-MIT.txt` has the Joel Arvidsson vector-icons notice. Source must also include the exact upstream Feather icon notice for Cole Bemis, with a pinned source revision and hash. Keep both notices. The primary [Feather license](https://github.com/feathericons/feather/blob/main/LICENSE) identifies Cole Bemis.

## Required corrections and integration

1. Stage the exact old `SplashScreen.storyboard`. The image and color files alone do not preserve launch geometry.
2. Correct widget linkage and font-path documentation. `Feather.ttf` is staged under `App/Fonts`, while current `UIAppFonts` names the bundle-root file. Main must select one path and matching registration. Do not add duplicate L03 and release font resources.
3. Add the upstream Feather icon notice beside the wrapper notice.
4. Support a fresh output directory and validate the exact expected tree and hashes. Compare two fresh stages from the same frozen inputs. Keep unexpected existing files intact when validation fails.

Main owns asset compilation, launch Info configuration, root privacy-manifest membership, font membership, license membership, signing, and archive builds. Resource preparation does not prove runtime entitlement access or archive acceptance. Main must keep DEBUG comparison helpers, sample media, short test notification triggers, and diagnostic paths out of Release.

The current machine has iOS 26.5. An iOS 26.0 runtime check remains open. Paired phones may permit later limited device evidence. Do not operate a phone before the simulator gates and explicit device selection.

## Corrected stage checkpoint

The corrected generator stages 33 rows under `native/John/Resources/Release/Resources`. The exact old storyboard and both Feather notices are present. The pinned upstream notice is from revision `3dc050d97405062eba78aa57115c0a15c63abdaa`, with SHA-256 `308028e93fcf84972523cdf6e616f73168546b4953895f516d01287f16fe7bee`.

Sol compared the default output with fresh `L28/resources-e` and `resources-f` trees. All files and manifests match byte for byte. All 33 copied/generated row hashes pass. The manifest hash is `197839eb9aafb3c9f2a8ba101c2f55016afdf8765515ae249fdcba6897b2bc40`. The generator hash is `7e5251b2500924ece35b5b858a48d283fecce00bd7fa116dceff9a92d3e6a7c6`. Source reports matching decoded 1024 by 1024 RGBA pixels for the three icon pairs. The stage keeps the old iOS PNG encoding.

The generator now verifies a temporary tree before publication. It rejects an existing nonempty output and preserves it. Source must correct the README example to `--fresh-output --output-root PATH`; the first option is a flag. Main must copy the staged Feather file as one bundle-root file or update its registration path. Keep the generated Resources subtree ignored and the generator, pinned notice, and README tracked. Final target membership and archive checks remain open.
