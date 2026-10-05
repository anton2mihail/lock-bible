# S00 staged acceptance

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Verdict: ACCEPTED for core baseline and limited L01 runtime proofs.
Full L00 route capture and release/update acceptance remain open.

## Reviewed baseline

Source baseline: `b64e1fc3cfc6a78f508b41d74b71dddfe9ff7697`.
Accepted source inventory: `7aaede8ca9e05a44f64fff0a04d7c7c23c0c59c1` and correction `07287f98510f2cb4f4aafd058fae3f05f7d72a2a`.
Toolchain: Xcode 26.6 (`17F113`), SDK 26.5.
Simulator: iPhone 17 Pro, iOS 26.5 (`23F77`).
Simulator UDID: `37D1870B-F16D-488A-8F20-959201F970D9`.
Configuration: Release, unsigned simulator app, bundled current source.
Native Info version: `1.2.2 (15)`. JavaScript source version: `1.5.0 (18)`.

Sol read the Release build result. It ends with `BUILD SUCCEEDED`. Sol inspected these images under `build/native-evidence/L00/`:

- `07-release-launch.png`: clean Today content and all five tabs.
- `08-reader-john-1.png`: clean WEB-CE John 1 paragraph rendering, verse labels, Reader chrome, and Read tab.
- `09-aas-live-large.png`: Large text selected in the open Aa sheet. The chapter has larger text behind it. Gold highlight and active selection underline remain visible.
- `10-reader-john-1-highlighted.png`: saved gold highlight with the normal Reader view.

These images replace the debug-overlay captures for the represented states. Preserve the files and record their hashes in the runtime evidence report. They do not prove the remaining routes or the native rebuild's parity.

## Storage evidence

The runtime worker reports data container UUID `7FA0CAAF-5F22-4446-854C-C902C7EBBE21` with these relative paths:

- `Documents/SQLite/user-library.db`, with WAL and SHM files.
- `Documents/SQLite/bible-search.db`.
- `Documents/mmkv/mmkv.default` and `mmkv.default.crc`.

The small app-created synthetic fixture is under `build/native-evidence/L00/synthetic-legacy-fixture/`. It includes one bookmark, one gold highlight, one note, and a medium text-size preference. Sol inspected the copied SQLite fixture read-only. It reports schema 1, WAL mode, and one row in each library table. The actual MMKV bytes have not yet been read with the reviewed adapter.

The unsigned app's App Group payload remains unverified. The copied preference plist is not proof of signed shared-container behavior. The full release-mode fixture and same-ID interrupted/repeated update checks remain required before Gate A/Gate E acceptance.

## L01 authorization

The main Luna worker can run ReaderProof's renderer, pagination, and shell proofs on the pinned simulator. Use `S00-preparation.md` and `L01-renderer-preparation-contract.md` for the exact scope. Keep baseline capture and prototype actions serialized.

The main worker can run the corrected storage proof only after Sol accepts its code for handoff. The initial destructive binary remains prohibited for actual fixture paths. Use actual app-derived copied MMKV bytes in legacy-read mode. Verify input hashes before and after. A copied fixture proves format compatibility. A later same-ID app install must prove container continuity and retained state.

No production project, broad screen work, or final architecture choice is authorized by this staged gate. S01 requires observed native proof results and code review.

## Open L00 conditions

1. Update the parity matrix with the observed core states and each missing state.
2. Update the ledger with this staged verdict and source/evidence revision.
3. Complete the remaining 29-route light/dark and required alternate-state captures.
4. Capture poetry, speaker headings, a non-paragraph edition, and long chapters for renderer comparison.
5. Verify the saved-edition discrepancy with multi-edition notes and saved context.
6. Add the complete release-mode synthetic fixture and consistent backup evidence.
7. Record actual binary IDs, scheme, entitlements, and App Group limitations.
8. Keep the iOS 26.0 deployment-floor check and limited device-only checks as release conditions.
