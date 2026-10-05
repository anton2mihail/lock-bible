# L02 and L05 simulator record

Date: 5 October 2026.

## Build and device

The development app and widget build passed with Swift 6 strict concurrency. Xcode was 26.6 (17F113). The build used the iOS 26.5 simulator SDK (23F81). The device was iPhone 17 Pro, iOS 26.5 (23F77), UDID `37D1870B-F16D-488A-8F20-959201F970D9`.

The app bundle is `com.nrsv.verse.dev`. The widget bundle is `com.nrsv.verse.dev.widget`. The development entitlement files name `group.com.nrsv.verse.dev`. The update entitlement files name `group.com.nrsv.verse`. The app Info.plist contains the `nrsv` URL scheme. The app and widget products were unsigned because the build used `CODE_SIGNING_ALLOWED=NO`. The bundle IDs and source entitlement files were checked. Effective signed entitlements and app-group access remain unverified.

The clean-checkout staging and build commands are in [build.md](build.md). Resource verification passed for runs 9 and 10. It checked 377 files in each run. All output hashes match. The manifest SHA-256 is `dc108b37a9d3cca837b931026add9db619642a9a395c231cc98b8ea487fe6ebc`. The app resource copy contains 351 files and 132,783,642 bytes. The widget copy contains 23 files and 18,164,087 bytes.

The app bundle preserves the `App` directory. The widget extension preserves the `Widget` directory. The seven Lora and Space Grotesk font files exist at the registered subfolder paths. Their PostScript names are `Lora-Regular`, `Lora-Medium`, `SpaceGrotesk-Light`, `SpaceGrotesk-Regular`, `SpaceGrotesk-Medium`, `SpaceGrotesk-SemiBold`, and `SpaceGrotesk-Bold`. The Feather font is present at the app bundle root. The Today screenshot shows its Feather icons and the registered Lora and Space Grotesk faces. The seven aliases are listed in the built app Info.plist.

## Simulator observations

The app launched under the development bundle ID. Today rendered its date, title, artwork, calendar label, prayer card, five tab buttons, and local resources. Read opened John 1:1 through the `nrsv` URL. The Settings tab showed the Large text value set in the Reader appearance sheet. The Reader passage changed its font size while that sheet was open. The same preference object drove both screens.

The simulator tree exposed these tab identifiers in order: `tab-today`, `tab-read`, `tab-saved`, `tab-pray`, and `tab-settings`. I opened each root. Today, Read, Saved, Pray, and Settings appeared. The Read screenshot includes one real WEB-CE verse from the staged Bible files. This is a shell proof. It does not accept the full reader or route implementation.

The expanded UI test passed on the same simulator. It checks all five tab roots. It opens John 1:1, changes the reader size to Large, closes the appearance sheet, and checks that Settings shows Large. The test log is `build/native-evidence/L02/xcodebuild-ui-test-strong-02.log`. The Xcode result bundle is `build/native-evidence/L02/John-Development-UI-02.xcresult`. The first expanded test exposed a missing way to close the appearance sheet. The app now has a Done button, and the rerun passed with zero failures.

| Capture | Observation | Pixels | SHA-256 |
| --- | --- | --- | --- |
| `01-today-shell-iphone17pro-ios26.5-light-default.png` | Today, light, default reader preference | 1206 × 2622 | `4faae7b65544fd632a165d1465ecdaea9f00400058f9152372c4c63f27c86e94` |
| `02-reader-john1-iphone17pro-ios26.5-light-default.png` | Read root with WEB-CE John 1:1 | 1206 × 2622 | `9e9bee00253c731be95bcb0175167ac858aef7c6695a26059367e9aa304509ef` |
| `03-reader-appearance-iphone17pro-ios26.5-light-default.png` | Reader appearance sheet | 1206 × 2622 | `cb3bd8d6a01eb9405cdfa8d94d1b50162984ae7cb9318108e8a676cee917ba4d` |
| `04-reader-large-live-restyle-iphone17pro-ios26.5-light.png` | Large size selection and live Reader restyle | 1206 × 2622 | `743daf3f5546087048d22ed28106e60f5e9c0fee11909eeb284a9c136b0101b4` |
| `05-reader-large-restyled-iphone17pro-ios26.5-light.png` | Reader after the sheet closed | 1206 × 2622 | `f8c6cd6ca9d514fcc1b6b3ff335a6ca8522562ea00bf903856e143b9e887c76c` |
| `06-settings-root-iphone17pro-ios26.5-light-large.png` | Settings shows the same Large value | 1206 × 2622 | `ffadb1a71d65abb79f6b316a25b6773808f1dbc942183ec032c09c329ba37f10` |
| `07-pray-root-iphone17pro-ios26.5-light-large.png` | Pray root | 1206 × 2622 | `a7a8753492aec4ddd8d20b7a07ad32893d5d27f846648c34fba73e5df11a9858` |
| `08-saved-root-iphone17pro-ios26.5-light-large.png` | Saved empty state in the clean development install | 1206 × 2622 | `c56132411805ed3d1cde0022b324bf8ef688c831e37f4b82cd8f8359916117b6` |

The `00-diagnostic-unresized-artwork.png` image records an early width defect. The app initially showed artwork at its source pixel width. I added resizing. The later Today capture shows the corrected layout. The settings-only diagnostic records the first preference picker before I connected the Reader text style.

## Open work

The development app uses an in-memory preference model at this stage. It does not run the migration API. The old app container was not installed over or changed. The native adapter target, startup gate, durable preference writes, and full migration proof remain open under L04. No signed app-group entitlement was tested.

Search accepts a Scripture reference only. It does not query the FTS5 database. The devotional screens are placeholders. These items remain open for their assigned later tickets. Other source routes remain open in the [parity matrix](parity-matrix.md).
