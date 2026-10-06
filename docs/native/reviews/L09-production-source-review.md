# L09 production source review

Date: 5 October 2026
Reviewer: GPT-6.1 Sol
Scope: Search Core and its DEBUG fixture comparison

## Source boundary

The Release update build uses these complete files:

| File | SHA-256 |
| --- | --- |
| `ReferenceParser.swift` | `0236f9239a3d50a980b5880538447b49dfa80f95f11238cca6f36f9eaab1ec6c` |
| `SearchRepository.swift` | `f2920a1f26ad9925cb4be56df460290c56ea4ec3b61c985f940560e7aad23ab2` |

Source must keep Core unchanged during that build. The storage files remain at the accepted repository runtime boundary. Search source acceptance does not close the same-ID Release update gate.

## Accepted source choices

`SQLiteSearchRepository` is an actor. Its initializer stores paths only. Its first required query opens the read-only database. A blank query returns without opening SQLite. The actor owns the connection and edition manifest cache.

Each request carries its query, edition, scope, limit, and request ID. Each response returns that request ID. Main must reject stale responses in the Search UI. Main must apply debounce and cancellation at that UI boundary.

Reference parsing uses the source aliases and chapter bounds. Fuzzy book matching uses UTF-16 code units. It rejects names below four code units. Its maximum distance is one below eight code units and two from eight code units. Equal-distance matches keep source book order.

Text tokens use compatibility decomposition, mark removal, and English lowercase. Punctuation remains a token boundary. Reference normalization removes periods separately. Quoted phrases and prefix terms use the source FTS format. FTS means full-text search.

Reference SQL keeps numeric verse casts, normalized range bounds, edition and testament scope, and verse order. Text SQL keeps `bm25`, book order, chapter, and verse order. OT includes Deuterocanon. The default limit is 60.

Correction runs only after zero original results. Quoted input skips correction. Correction uses at most 300 candidates with the same first letter. It keeps source distance, frequency, and tie order. Text-word correction uses a maximum distance of two from five code units. This threshold is separate from fuzzy book matching.

## Required source correction

Trigger: a quoted query contains U+2028 or U+2029.

The source phrase regex rejects these line separators. Native `buildFTSQuery` currently rejects only newline and carriage return. Native therefore emits a phrase where the source emits prefix terms.

After the Release build ends, Source must use the same phrase condition. Source must add exact FTS probes for both separators. The DEBUG comparison must require the final probe counts. Keep the search-case count at 41 and the parsed-reference count at 19.

## Corrected source acceptance

The phrase correction is accepted. Native now rejects U+2028 and U+2029 as phrase content. The source fixture includes both probes. Source reports passing host and arm64 simulator SDK builds. The DEBUG comparator type-check passes with Swift 6. Source did not run the simulator.

| Item | Final SHA-256 |
| --- | --- |
| `ReferenceParser.swift` | `0236f9239a3d50a980b5880538447b49dfa80f95f11238cca6f36f9eaab1ec6c` |
| `SearchRepository.swift` | `abcaadb8c88da954698f65f807d2beffeba9ade41c31fd5192a00d64d013f887` |
| Source fixture JSON | `2b489648b2c454b624d5d43e5cdb431b0bee04fc30ef66b6a76ff23e8c5d2a6b` |
| DEBUG comparator | `ce2527182b9ad9cd3236f80ee480dede983dda34562301ebf7c4a2247444a7cb` |

Source must commit the two Core files and L09 scripts as one scoped source handoff. Runtime acceptance remains open.

## Runtime handoff

The DEBUG comparison must check all 41 search responses and 57 edition-specific reference outputs. It must compare exact result fields, order, corrected query, reference status, and request ID. It must also check four normalization probes, three UTF-16 distance probes, and six FTS probes. Release must exclude this helper.

Main must record the current Core hashes, fixture hash, installed binary hashes, process ID, and process-derived paths with the simulator result. A passing host build or source fixture does not prove simulator Search parity.

## Open work

The simulator comparison, Search UI, highlighted result text, result navigation, and stale-response checks remain open. No complete L09 or Gate B acceptance is given by this source review.
