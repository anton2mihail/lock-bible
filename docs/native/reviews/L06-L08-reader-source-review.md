# L06–L08 Reader source review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: preparation only. Gate A storage checks have priority.

The Reader files are not accepted as complete tickets. Main owns their implementation and simulator checks. The current source supplies book/chapter navigation, the source selection reducer, and a TextKit view. These findings must be resolved before full Reader acceptance.

| Trigger | Required result | File and source evidence |
| --- | --- | --- |
| Serif Scripture is active | Use Georgia on iOS. The current Lora body changes glyphs and wrapping. | `Platform/Text/ScriptureTextView.swift`; `src/theme/useReaderTypography.ts` |
| Text size changes | Keep the source verse-number base size from the `xs` token. Do not derive it as 0.67 times the body size. Scale it once for Dynamic Type in L08. | `Platform/Text/ScriptureTextView.swift`; `VerseNumber` in `src/components/ChapterText.tsx` |
| A block needs a paragraph or stanza gap | Apply the gap before the current block. Current `paragraphSpacing` applies it after that block. | `Platform/Text/ScriptureTextView.swift`; source `ParagraphChapter` uses `marginTop` |
| A Psalm title or speaker/major heading appears | Preserve source font, case, color, tracking, line height, and first-heading gaps for each kind. Psalm titles use dim italic body text. Speaker labels use italic accent text. Major headings use uppercase accent text. | `Platform/Text/ScriptureTextView.swift`; source `ChapterHeading` and its styles |
| A context request overlaps a saved highlight | Keep the saved fill. Apply the context fill only when no saved fill exists. Current context application replaces the saved background. | `Platform/Text/ScriptureTextView.swift`; source `useVerseAppearance` and `ParagraphChapter` |
| Verses layout is active | Render the source verse layout. The current view always uses block layout. This is L08 work. | `ReaderView.swift`; `ScriptureTextView.swift`; source `ChapterText` |
| Two requests load different editions | Discard a stale manifest or chapter response before it changes the Reader. Current chapter loads have an ID guard; manifest requests also need one. | `ReaderScreenModel.swift` |
| Back or another book action occurs during a chapter load | Invalidate the pending chapter load before the navigation change. A later response must not fill the new screen or change Continue reading. Current Back and openBook actions keep the old load ID active. | `ReaderScreenModel.swift` |
| A repeated passage request arrives | Reposition from the new request ID after layout. A context fill alone does not prove positioning. | `ReaderView.swift`; `ScriptureTextView.swift`; ADR 0004 |

Use matched simulator captures for John prose, Psalm poetry, and Song speaker labels. Use real taps for the 10, 12, 8, 8, 8 selection sequence. Check a wrapped continuation and blank layout space. Check saved fills together with active selection and context. Preserve unselected text anchors through style changes in L08. Keep all findings in the full ticket queue; they do not change the accepted TextKit mechanism.
