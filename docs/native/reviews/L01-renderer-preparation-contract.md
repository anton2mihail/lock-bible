# L01 renderer preparation contract

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Assigned worker: GPT-6 Luna runtime/implementation worker.
Status: preparation and limited runtime checks are allowed. S00 core baseline passed its staged review. Full L00 route capture remains open.

## Write scope

Use `native/Prototypes/ReaderProof/` for a small tracked proof app. Use `build/native-evidence/L01/renderer-proof/` for its build output and captures. Keep reproducible proof scripts in the prototype folder. Keep the main parity matrix and work ledger current.

Do not create `native/John/` yet. Do not build the 29 production screens. Do not change canonical content, existing app source, schemas, or release behavior. The source/resource worker owns the separate storage proof. Keep simulator actions serialized with baseline capture.

## Renderer preparation

Use the L01-R and L01-W scope in `S00-preparation.md`. This preparation can define local proof-only types. Final types remain an S01 decision. Keep domain layout separate from platform layout so approved code can later move into the native app.

1. Port the source Scripture layout rules with UTF-16 offsets, exact break and heading order, verse labels, and zero-based indices.
2. Host an attributed UIKit text renderer in SwiftUI. Prepare verse hit testing for wrapped lines. Do not enable editing or unrelated text selection menus.
3. Preserve the exact selection transition in `S00-source-discrepancies.md`. Keep all four saved highlight fills visible under active selection.
4. Load real source chapters for prose, headings/poetry, speaker headings, and an edition without paragraph markers. Keep a separate synthetic Unicode fixture.
5. Prepare a paragraph/page renderer for real works sections. The source/resource worker will supply its zlib/TEXT compatibility proof. Do not decode the whole works corpus.
6. Prepare live style/width changes and anchor restoration. Keep the exact source base font and line-height rules. Do not scale text twice.
7. Prepare accessible verse elements, heading traits, selected state, page announcements, and debug-only selected-ID diagnostics.

## Shell preparation

Prepare the standard iOS 26 `TabView` and custom flat five-tab comparison from L01-C. Use exact source colors, Feather forms, and labels. Keep custom controls on public APIs. Do not choose the production chrome before Sol reviews matched images and accessibility evidence.

## Runtime gate

Preparation can continue while the release app builds. Do not claim the proof passes from compilation. Before full L01 review, capture the clean current-source Today and Reader baseline. Record actual SQLite/MMKV paths. Run the proof on the pinned iOS 26 simulator. Perform real verse taps and page actions. Record the evidence from the running production-compatible code.

Return code paths, source SHA/hashes, build result, observed scenarios, screenshots, accessibility inspection, timings, and unresolved limits. Sol will review the full proof diff and evidence before publishing S01. All broad app implementation remains blocked on that decision.
