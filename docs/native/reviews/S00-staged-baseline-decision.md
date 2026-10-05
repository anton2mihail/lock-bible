# S00 staged baseline decision

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Verdict: current-source Debug capture is allowed. Full L00 acceptance remains open.

## Version discrepancy

Root reported that the existing simulator app built successfully. Its generated Debug Info.plist is `1.2.2 (15)`. The current JavaScript source, app config, and reported IPA are `1.5.0 (18)`.

Use the built Debug app with the current Metro bundle for staged Reader and shell capture. This is sufficient to start independent L01 renderer and chrome proofs after launch and capture evidence is present. A stale native version label does not by itself change the current JavaScript screen layout.

Record the native version and JavaScript source version separately. Label these images as current-source Debug captures. Record the source SHA, Metro bundle provenance, configuration, binary IDs, simulator runtime, device, date, appearance, and text size. Do not label this binary as a verified `1.5.0 (18)` release app.

## Allowed progression

1. Confirm that the running app loads the current source and displays the five current tabs.
2. Capture current Today and representative Reader states on the pinned simulator.
3. Record actual SQLite/MMKV paths and a small baseline fixture. A real synthetic bookmark, note, and preference are sufficient for the first adapter proof.
4. Send this partial evidence to Sol.
5. After Sol reviews it, start the independent L01 proofs. Complete remaining route captures in the same evidence stream.

The renderer and shell proofs can use current-source Debug images. The storage proof must read the real baseline MMKV/SQLite format. A small Debug seed can prove adapter compatibility. It cannot satisfy release-mode update acceptance. The full release-mode fixture remains required for Gate A and Gate E. Missing route captures remain open in the matrix.

## Conditions still open

- Build and launch a release-mode old app with a bundled current JavaScript source.
- Verify the release binary IDs, App Group, URL scheme, entitlements, and version.
- Preserve a release-mode synthetic seed for same-ID update tests.
- Complete all route/state captures and the missing device checks.
- Perform the required release-mode same-ID update rehearsals in L04 and L27.

Release-mode migration evidence remains required. Do not use current-source Debug captures as proof of release-only media behavior, signed update retention, or installed widget continuity.

## Image review

Sol inspected `build/native-evidence/L00/02-today.png` and `06-after-dismiss.png`. Current Today content is visible. The latter image shows all five tabs in the approved order. It shows a flat background and top border. This tab region is useful for the L01 chrome comparison. A debug gear still covers part of the Today title. The full Today image is not a clean frozen comparison baseline.

Sol also inspected `05-reader-open.png`. It shows the debug error screen, not Reader. Its filename does not establish a Reader capture. The error states that `expo-notifications` failed to read persisted server registration information because Keychain access lacked a required entitlement. Record this as a baseline simulator/build finding. Do not copy a push-registration path into the native local-notification service.

The main worker is building a current-source release-mode simulator app for clean capture. Preparatory L01 code is allowed under the separate renderer and storage proof contracts. Runtime acceptance remains open.
