# Wave 3 assignment

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Status: bounded Reader preparation is authorized. Full Wave 3 integration waits for Gate A.

## Main Luna

Finish and commit the L02/L05 foundation first. Connect the reviewed L04 state store and adapter. Run the Gate A simulator matrix. Main owns the project, runtime composition, routing, shared theme, widget target, and all simulator controls.

For L06 and L07, use `native/John/Features/Reader/` and `native/John/Platform/Text/`. Port source book browsing, chapter selection, Continue reading, previous/next, Go to, and the original Reader header. Replace the one-verse shell card with the accepted chapter renderer. Keep source headings, paragraph types, poetry, verse labels, and exact text. The range reducer and UTF-16 anchors use the accepted contracts.

Evidence must include simulator navigation and real verse taps. Capture John prose, Psalm poetry, Song speaker labels, headings, active selection, and saved highlights separately. Prove the 10, 12, 8, 8, 8 tap sequence. Prove repeated equal URLs and reader reuse. Large text, edition changes, and reliable location writes remain L08. Full library actions remain L10.

After Gate A, Main continues Reader UI, Search UI, Saved and Note UI, and Verse Moment/widget integration. It uses the Source worker's reviewed Search repository. Each ticket has its own commit and evidence.

## Source Luna

Finish L04 corrections and the scoped storage commit first. Supply public API and simulator harness instructions. Main runs the harness.

After this review accepts the storage boundary, Source may implement the L09 Search repository in JohnCore. Use separate `ReferenceParser.swift`, `SearchRepository.swift`, and `SQLiteSearchRepository.swift` files. Preserve the source parser, aliases, normalization, correction limits, scopes, SQL ordering, and empty-result behavior. Return the caller's request ID. Open the existing search database read-only. Use immutable Sendable results and actor-owned handles. Main owns query debounce, cancellation, loading state, marks, and result navigation.

Source must read `src/services/bible/referenceParser.ts` and `searchService.ts` before implementation. Existing source fixtures define expected results. Do not add a unit test target. Provide simulator fixture inputs and expected outputs for Main to run through the production package.

## Shared files

Only Main writes the Xcode project, app composition, router, theme, and widget files. Only Source writes Core repository internals and resource scripts. Sol writes review decisions and acceptance contracts. A worker requests a shared-file change through its owner. The full plan remains required through S02.
