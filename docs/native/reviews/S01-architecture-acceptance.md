# S01 architecture acceptance

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: ACCEPTED. Start L02–L05 in the assigned file scopes.

## Decision and evidence

| Boundary | Decision | Reviewed evidence |
| --- | --- | --- |
| Modules and state | Swift 6 JohnCore package; actor-owned storage; immutable shared values | ADR 0001 and accepted bounded Core commit `2aaef1d67c28d54ec0841feb83d6029f01cfcf51` |
| Routes and identity | Typed router; request IDs; reuse Read; saved edition takes priority | ADR 0002, exact source routes and stored keys |
| Legacy storage | Keep schema-1 SQLite library; read MMKV Core v2.0.0 without writes | Copied-byte simulator run and live same-ID read |
| Native state | One actor commits a versioned JSON envelope with its completion marker | ADR 0003; implementation and interruption checks remain L04 |
| Scripture and Works | SwiftUI host with UIKit attributed text; paragraph-aware Works pages | Real John 1 capture and corrected Works page capture |
| Resources | Deterministic staging; indexed rotation reader shared by app/widget | L03 commit `3e84efa9a7a4851a264b77fcdc17144cb53cd79e`; two matching 377-file outputs |
| iOS 26 chrome | Custom flat SwiftUI tab bar with source forms and labels | Clean L00 captures and native standard/custom comparison |

## Same-ID read

The old Release app had bundle ID `com.nrsv.verse`. Main Luna installed the reviewed native harness over that ID without an uninstall. Only the copied harness bundle ID changed. Its executable SHA-256 remained `e547c6b0ef9526030bdc4b4f89855206f055cecdfaba7d59368c5e44b0cefe63`.

The data container changed from UUID `7FA0CAAF-5F22-4446-854C-C902C7EBBE21` to `36CDBC98-CD3F-4994-8CC3-67320EEBC043`. Library DB/WAL, search DB, and MMKV data/CRC hashes matched. The SHM hash changed. SHM is SQLite coordination state. It is not the stored user payload.

The native process opened the retained live MMKV files in read-only mode. It read the requested text-size key, ran three-edition FTS5, and decoded one real Works row. The run returned exit 0. Evidence is under `build/native-evidence/L01/same-id-read-01/`. The raw final sentence about no simulator is inherited host wording. The actual simulator launch and process result are recorded separately.

Sol read `row-comparison.txt`. The pre-install live rows, consistent backup, post-install live rows, and copied fixture match field-for-field. Each contains one bookmark, one highlight, and one note. The consistent backup passed `integrity_check`.

This proves the narrow retained-data read. It does not prove a complete importer. The binary did not report the normalized preference value. Equal MMKV bytes and the old app's medium text-size observation support retention. L04 must compare typed values and all feature state.

## Open conditions

Gate A requires a tracked Swift 6 app/widget project, built-bundle resource checks, simulator repository runs, complete native-state migration, killed/repeated import checks, and the shell behavior checks. Keep full route baseline captures in the ledger. Do not wait for those captures before independent approved code.

L07/L08/L21 retain exact typography, poetry/speaker blocks, the full range sequence, wrapped taps, active selection fills, unselected anchor restoration, and long-section checks. L25–L27 retain full visual comparison, limited device checks, and complete supported release update rehearsals.

The initial source fixture, full-corpus host sweep, SDK-only package build, and narrow native harness are evidence for their stated boundaries. They do not establish 1:1 simulator parity or final release readiness.

## Ownership

Main Luna owns the Xcode project, app/widget target settings, resource integration, app entry points, router, shell, design components, platform text UI, features, simulator controls, and UI verification. Source Luna owns JohnCore, the narrow legacy adapter and pinned dependency, native state/import code, and resource scripts. Sol owns ADRs and review decisions.

Use `Wave-2-assignment-draft.md` as the accepted Wave 2 assignment. Its filename is retained for existing references.
