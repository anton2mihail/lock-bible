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

The next source revision uses Georgia, fixed 14-point verse labels, before-block gaps, typed heading styles, and saved-fill precedence. Manifest responses now have an ID guard. Main added chapter-load cancellation on Back and book navigation. One request case remains: those navigation actions must also cancel a pending manifest response. A new edition or deep-link manifest request must cancel the older chapter response before it waits. Otherwise, a late response can reopen a page after Back or update Continue reading for the old request. Full runtime acceptance remains open.

The current model now clears pending manifest IDs on Back and book selection. New edition and passage manifest requests clear an old chapter ID before waiting. These source corrections are present. Main must still show their navigation behavior on the simulator.

## Next production corrections

| Trigger | Required result | Source and native file |
| --- | --- | --- |
| Reader opens a chapter | Use the source icon-only Back control. Keep its full accessibility label. The header must scroll with the chapter. | Source `ReaderHeader` in `src/screens/ReaderScreen.tsx`; native `ReaderView.swift` |
| Reader or GoTo shows its heading | Use SpaceGrotesk-Bold at the source 36/44 base size. The native Lora title and 32-point chapter title differ. Keep companion Page titles on their separate source style. | `src/components/Text.tsx`, `src/theme/typography.ts`; native Reader and GoTo headings |
| Previous or Next is shown | Include the target book and chapter. Include the edition attribution below navigation. | Source chapter navigation; native `ReaderView.swift` |
| Chapter grid width changes | Wrap 52-point chips to available width. Use the source gaps and current marker. Do not force five columns. GoTo must not add visible chapter-count text absent from source. | `src/components/ChapterGrid.tsx`, `src/screens/GoToScreen.tsx`; native `ReaderView.swift`, `GoToView.swift` |
| Back or GoTo opens from Psalm 149 | Retain the current chapter marker. Reveal that cell. Do not reveal the center of the whole grid. | Source currentChapter/ref/layout callbacks; native `ReaderScreenModel.swift`, `GoToView.swift` |
| The book list scrolls | Keep the source title, Continue reading, and Fathers area above the scrolling list. Use exact catalog author/work counts in the Fathers row. | Source book-list mode; native `ReaderView.swift` |
| Verse layout is selected | Render the source verse rows and headings. The current paragraph-only view ignores this setting. | Source `VerseChapter`; native `ScriptureTextView.swift` |
| A saved highlight or requested context is active | Supply actual chapter highlights. Reveal the requested verse after layout. The current Reader supplies an empty highlight map and no scroll request. | Native `ReaderView.swift`, `ReaderScreenModel.swift`; ADR 0004 |
| Style, edition, or system text size changes | Preserve the source text anchor and selection. Apply Dynamic Type once. Persist location through the state actor. | L08 contract; native Reader model and text view |
| An iPad or large text changes the reading column | Use the source 34-em measure. Its outer cap is `round(base fontSize * system fontScale * 34 + horizontal padding * 2)`. The current fixed 740-point cap changes wrapping. Scale text once and use the same measure for later daily passages. Check matched iPad wrapping and a large-text anchor. | `src/theme/useReaderTypography.ts`; native `ReaderView.swift` and shared text layout |
| Next, Previous, or another chapter starts a pending load | Clear the prior chapter/layout at load start, or render only text with the active load identity. The current model changes the header coordinates before it awaits, but keeps the old tappable text. Check one navigation with a bounded DEBUG load delay. | `ReaderScreenModel.openChapter`; `ReaderView.chapterReader` |

These findings stay within the approved full scope. The current Reader commit can record preparation, but it cannot close L06–L08. Main keeps storage builds stable first. Use matched John, Psalm, and Song captures, real range taps, late-Psalm navigation, and one large-text anchor check for production acceptance.
