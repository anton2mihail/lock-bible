# L04 storage code review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: fixes required. Main can integrate the API and build boundary.

## Reviewed code

Sol read `NativeStateStore.swift`, `NativeState.swift`, `LegacyStateNormalizer.swift`, `SQLiteLibraryRepository.swift`, `LibraryBoundary.swift`, the adapter header/Objective-C++/Swift sources, and the build report.

The importer keeps the raw theme path separate. Known JSON values use one parse. Reading controls have individual mutations. Library operations use prepared values and synchronous transactions. Highlight grouping and undo retain source keys, batches, and timestamps. The adapter uses pinned MMKV Core v2.0.0, read-only mode, and `getString(..., false)`.

The fresh host and simulator SDK builds pass. Vendored bytes match 74 pinned Core files. The host rotation comparison matches all 792 fixture rows after the next-boundary offset correction. These are preliminary source/build checks. Production runtime acceptance remains open.

## Required corrections

| Trigger | File | Required result | Simulator evidence |
| --- | --- | --- | --- |
| Two startup calls await separate adapter reads | `LegacyMMKVReader.swift`, `LegacyMMKVAdapter.mm`, `NativeStateStore.swift` | Serialize native open/read/close. Share or serialize import work. A closed cached MMKV pointer cannot be used by another read. | Concurrent startup, then a native mutation, retains the newest revision without a crash or re-import. |
| Completed state contains invalid cadence, edition, reminder time, or novena day | `NativeStateStore.swift`, `NativeState.swift` | Validate semantic state before accepting an envelope and before replacement. Preserve invalid existing files and return an error. | Invalid semantic payload does not become accepted completed state. |
| Fresh setup stops during its schema script | `LibraryBoundary.swift` | Create schema in one transaction at a new temporary path. Validate and publish without replacing an existing library. Committed schema pages must be in the published file. | Kill/relaunch during fresh setup completes safely. |
| Library DB is missing but sidecars or completed native state remain | `LibraryBoundary.swift`, `SQLiteLibraryRepository.swift`, `NativeStateStore.swift` | Return a library capability error. Do not create an empty replacement. Repository reads cannot independently create a library. | Missing DB with retained recovery evidence stays missing and reports the error. |
| Durable replacement fails after primary rename | `NativeStateStore.swift` | Reconcile the validated primary or block further writes. Do not continue from an old cached revision. | An injected failure after rename cannot cause the next action to overwrite newer primary state with stale state. |
| Legacy MMKV data or CRC is truncated or has an invalid CRC | `LegacyMMKVAdapter.mm` | Check minimum file lengths before the static CRC check. Reject damaged bytes before opening the store. Preserve both files and report an import capability error. | Truncated data, truncated CRC, and wrong CRC cannot become successful empty imports. All source hashes remain unchanged. |

Main owns simulator controls. Source owns each implementation correction. Both workers use `L04-runtime-acceptance-contract.md` for the remaining matrix.

## Integration limits

The observed legacy root is `Documents/mmkv`. The adapter accepts an injected root URL. Its App Group initializer is a supported alternate path. It is not evidence that this simulator baseline used an App Group MMKV root.

Keep the adapter and MMKV dependency outside the widget-linked JohnCore target. The current compiled Objective-C++ object is not proof that the Swift bridge and final app dependency graph compile together.
