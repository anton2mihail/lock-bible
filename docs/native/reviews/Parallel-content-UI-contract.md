# Parallel content implementation

Sol permits L13–L19 implementation while Gate B remains open. Gate A stays accepted at `df8cc9b`. This permission does not accept unobserved screens.

## File ownership

Main owns L06–L12. Main also owns `Runtime.swift`, `AppRouter.swift`, `SecondaryRootView.swift`, the Xcode project and generator, the design system, and all simulator operations.

Source owns new files under `Features/Companion/`, `Features/Calendar/`, `Features/Prayers/`, `Features/Guides/`, and `Features/Sharing/`. Source owns the reviewed content models, lazy repository, and pure selectors in JohnCore. Source must coordinate a stable Core source boundary before Main builds. Source must not edit Main's shared files.

## State and navigation

Main exposes `committedNativeState: NativePersistentState?` as an observable read-only snapshot. Startup and successful updates project this snapshot from the accepted envelope. The existing revision guard also applies to this snapshot.

Main adds `applyWithResult(_:) async -> Bool`. A true result means this call committed durably. An unavailable store or a failed save returns false and keeps the existing warning behavior. The existing `apply(_:)` can call this method and discard its result. Features must not create a second state store.

Main exposes the lazy `companionRepository`. Its initializer does no resource I/O. Missing resources remain a readable error.

Source defines `CompanionRoute: Hashable, Sendable`. It has prayer home, dated daily readings, Sunday preparation, citation context, prayer library/detail, teaching library/detail, novena detail, Rosary home/guide, Lectio, Confession, and Scripture card destinations. Daily routes carry a date key. Citation context carries the original reference. Lectio carries an optional `PassageSelection`. Scripture card carries a `PassageSelection`.

Source views receive an `onNavigate(CompanionRoute)` callback. Main adds the companion destination to `AppRoute` and maps existing external routes at the shared router. Citation context remains distinct from a selected passage. It uses the source WEB-CE whole-chapter mapping policy.

## Save and lifecycle rules

Use the committed snapshot for favorites, reflections, and novena progress. Serialize saves within each feature. Derive each new value from the latest committed state. Await a true save result before a success action, reset, or return navigation. Keep the draft and show the source error state after a false result. Do not overwrite unsaved drafts when another state field changes.

Confession notes and guide session positions remain temporary. Clear Confession notes on leave and on each loss of active scene state. Lectio uses a deadline and the source five-step behavior. It does not resume a temporary session after relaunch.

## Implementation order and evidence

Source first supplies a compilable L13–L16 Core and view boundary. Source then completes L17–L19 in its assigned files. Preserve exact source text, IDs, ordering, artwork, links, empty states, and error states. Do not add placeholder actions.

Main adds target membership and runs the focused simulator flows. Source supplies exact source hashes and expected values. Sol reviews the changed source and matched old/native images. Full Gate C acceptance still requires these observations. Source-only builds and host comparisons do not prove UI parity.

The preliminary Toronto host comparison passes 13 checks. It reports 858 reading reference entries, 324 novena transition steps, seven callback steps, and 893 Today cases. The draft simulator build has a sysroot warning. Source must report or correct its SDK command before SDK acceptance.

Disk capacity is available. The prior disk hold is removed. Use existing build paths where practical. Do not repeat accepted Gate A flows unless a relevant change creates a new concern.
