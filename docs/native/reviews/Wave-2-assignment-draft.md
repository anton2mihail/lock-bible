# Wave 2 assignment draft

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Status: ACCEPTED after S01. The filename is retained for existing references.

## File ownership

| Worker | Sole write scope |
| --- | --- |
| Main Luna | `native/John/John.xcodeproj/`, schemes, app and widget target configuration, `App/`, `DesignSystem/`, `Features/`, platform text UI, `Widget/`, `SimulatorSupport/`, UI automation, shared work ledger and parity matrix |
| Source Luna | `native/John/Packages/JohnCore/`, reviewed legacy adapter source, pinned dependency source and license, deterministic staging scripts, generated resource manifests, repository/import evidence |
| Sol | `docs/native/adr/` and `docs/native/reviews/` |

Main Luna alone edits Xcode project resource lists, build phases, settings, target dependencies, and entry points. Source Luna returns file lists and build requirements. Main Luna integrates them. Only main Luna controls the pinned simulator. Source Luna can build without changing that simulator.

## L02: project boundary

Main Luna creates the tracked project at `native/John/John.xcodeproj`. Use Swift 6, strict concurrency, and iOS/iPadOS 26.0. Create app, widget, and UI automation targets. Do not add a unit-test target. Keep development and same-ID update schemes separate. Preserve production app/widget/group IDs and the `nrsv` URL scheme.

The local package path is `native/John/Packages/JohnCore/`. Source Luna owns its manifest and source. Main Luna owns its project reference. Use injected resource roots so app, widget, and simulator scenarios use the same reviewed repository code.

Evidence: clean checkout build, pinned toolchain, clean simulator launch, target IDs, scheme settings, entitlements, and absence of React Native/Hermes in the native executable.

## L03: resources

Source Luna completes the staging contract in `L03-staging-preparation-contract.md`. Main Luna integrates the generated app/widget lists. The build must keep subdirectories and must not flatten colliding Bible book names.

Evidence: twice-generated matching manifests, built-bundle paths and hashes, all edition counts, exact catalogs, font names, FTS5 results, one-section zlib/TEXT decoding, and widget resource limits. Main Luna supplies simulator font and bundle checks.

## L04: data and migration

Source Luna implements immutable domain types, repositories, injected clock, typed state normalization, and the versioned migration state machine. Main Luna supplies the app startup gate and diagnostic scenarios. The migration gate must finish before feature models consume persistent state.

Keep the schema-1 library at its original path. Make a consistent backup before native writes. Keep legacy MMKV read-only. Preserve unknown keys and recovery files. A successful retry must not overwrite later native changes. Keep an unsupported or unreadable database at its original path. Return a capability-specific error.

SQLite handles and statements stay with their actor. Transactions contain no suspension points. Database operations use prepared values. The Works repository loads one requested section. The Search repository returns a request identity so the UI can discard stale results.

Evidence: full synthetic release fixture, same-ID native install without uninstalling, recent WAL rows retained, killed/repeated migration, fresh install, damaged payload, unsupported schema, changed native value retained after retry, and exact saved IDs/timestamps/batches.

## L05: shell

Main Luna implements source theme tokens, registered fonts, approved tab chrome, typed push/sheet routes, URL parsing, cold-start request queue, and shared observable preferences. UI code uses package contracts. It does not issue SQL or read MMKV.

Evidence: matched Today/Reader chrome, five-tab labels and selected state, Search close/result return behavior, repeated passage requests, saved-edition priority, live Aa/Settings synchronization, invalid URL handling, keyboard avoidance, safe areas, and iPad width.

## Integration order

1. Sol approves S01 contracts.
2. Main Luna creates L02 target and package-reference boundaries.
3. Source Luna starts L03 integration and L04 Core code in its scope.
4. Main Luna integrates L03 output and starts L05 against frozen contracts.
5. Main Luna runs shared simulator scenarios after source integration.
6. Sol reviews each diff and evidence set.
7. Sol accepts Gate A before dependent feature work starts.

Missing baseline route captures and physical-device evidence stay in the ledger. They do not block independent code with approved contracts. They still block the applicable final parity or release verdict.
