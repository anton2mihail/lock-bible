# L01 minimum runtime review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: ACCEPTED for S01 decisions. Full production acceptance remains open.

## Observed evidence

The storage compatibility run passed on the pinned iOS 26.5 simulator. See `L01-storage-runtime-review.md` for its exact limits.

Sol read the ReaderProof build log. It reports `BUILD SUCCEEDED`. Sol inspected `build/native-evidence/L01/renderer-proof/test-display-1.png`. It shows real WEB-CE John 1 flowing paragraphs and four saved highlight fills in a UIKit attributed renderer.

The main worker reports a real text tap selected `web-ce:JHN:1:3`. The inspected image predates that tap and shows no active selection. Record the tap diagnostic as separate evidence.

`01-reader-john.png` is blank because the screenshot command selected the wrong display. It is invalid for Reader evidence. Keep the raw file. Use the active display for later captures.

The prototype project currently sets Swift 5. Production L02 must use Swift 6 and strict concurrency. Its compiler checks remain required.

Sol inspected `03-works-page-2.png`. The corrected page fits and is readable. Its diagnostic reports continuous content, 20 pages, layout 9.94 ms, and UTF-16 anchor 734. The preceding clipped page is failed-fit evidence.

Sol inspected `04-shell-comparison.png`. The standard TabView surface is floating and rounded. The custom comparison preserves the flat border and Feather forms. ADR 0006 selects custom chrome. ADR 0004 accepts the text/paging mechanism. Their detailed production checks remain open.

## Minimum remaining decision evidence

The small same-ID legacy read passed. See `S01-architecture-acceptance.md`. Its library DB/WAL and MMKV data/CRC hashes match. The process read the retained live MMKV files and returned exit 0. The container UUID changed. Its stored payload remained equal.

The observed Scripture, corrected Works, storage, and shell proofs are sufficient to choose their mechanisms. Freeze S01 after the same-ID read. Full poetry/speaker comparison, the complete tap/range sequence, active selection fills, live anchor restoration, exact font/geometry adjustment, all style combinations, full route captures, and device speech remain production-ticket work. Do not build all features inside the proof.
