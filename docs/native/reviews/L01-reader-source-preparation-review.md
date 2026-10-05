# L01 Reader source preparation review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: CHANGES REQUIRED. The source is incomplete. Runtime evidence is not available.

Sol read the initial `BibleModels.swift`, `ChapterLayout.swift`, sample generator, and sample manifest. Sol compared the layout port with `src/services/bible/chapterLayout.ts`.

## Required fixes

1. In `ChapterLayout.swift`, the current-block marker has type `Int?`. The flush function passes it as the text-block kind. Emit the stored String kind instead. Confirm compilation before runtime capture.
2. In `VerseTapState.tap`, calculate both endpoints from the old lower endpoint and the new tap. Do not retain the old upper endpoint. The required tap sequence is `10, 12, 8, 8, 8`. Its ranges are `[10,10]`, `[10,12]`, `[8,10]`, `[8,8]`, and nil. Record this sequence in the simulator.

## Review limits

The proof samples cover prose, poetry, speaker headings, and an edition with no paragraph markers. The generator keeps source hashes. The separate Unicode sample uses UTF-16 offsets. These are useful inputs. They do not prove verse hit testing, exact layout, highlight layers, paging, accessibility, or anchor restoration.

Review the complete renderer and its runtime evidence before S01. Keep the proof types local until that review passes.

## Full renderer preparation follow-up

Sol read the first `ScriptureTextView.swift`, `WorksPagination.swift`, `ContentView.swift`, and `ShellComparisonView.swift`. The worker fixed the initial block-kind and range-reducer defects. Sol sent these focused corrections before runtime evidence:

1. Keep every Scripture block separator. Adjacent poetry/list blocks with no added gap must still start separate lines.
2. Give accessible verse buttons a working activation action. Keep headings and verses in text order. Heading text must not trigger verse selection.
3. Apply the proposed text width once. The view and its fit measurement must use the same width.
4. Use the exact Pray tab label and source bar color tokens.
5. Use complete line bounds when a Works page fills. The next page starts at its actual first line.
6. Count one explicit source paragraph gap. A paragraph continuation starts a page without a new paragraph gap. Measure and display at identical width and typography.
7. Keep pre-verse headings in `VerseLayout.headings` only. Do not duplicate them in `VerseLayout.lines`.

These are proof-path defects. They are not requests to complete all routes before S01. The worker must return its final source hash and focused simulator evidence after the corrections.
