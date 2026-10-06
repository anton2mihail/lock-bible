# Reader selection action contract

Date: 6 October 2026.
Reviewer: GPT-6.1 Sol.
Status: implementation required. Simulator acceptance remains open.

## Ownership and interface

Source owns only the new `Features/Reader/ReaderSelectionToolbar.swift`, after its Search test handoff. Main owns Reader integration, Runtime storage methods, editor routing, project membership, and simulator execution. Do not create a second note editor. Generalize the current editor to accept an immutable `PassageSelection`, an optional existing item, and success/cancel callbacks. Preserve the existing Saved editor behavior.

The toolbar receives an immutable passage, a display reference, bookmark state, the shared highlight color, whether any verse has a highlight, feedback, operation state, and synchronous callbacks. Callbacks are `onClose`, `onBookmark`, `onHighlight(HighlightColor)`, `onClearHighlight`, `onNote`, `onCopy`, `onShare`, `onPray`, and `onCard`. Main starts asynchronous work from these callbacks. The view must not read Runtime, repositories, current edition, clipboard, or presentation state.

## Source behavior

Use `src/components/SelectionToolbar.tsx`, `src/screens/ReaderScreen.tsx`, `src/screens/NoteEditorScreen.tsx`, and `src/services/library/selection.ts` as the source contract. A tap selects one verse. A second tap extends the range. A tap on the only selected verse clears it. Keep the accepted reducer and owned-text hit behavior.

Construct the passage from the current loaded chapter and captured edition. Preserve source verse labels, indexes, book order, reference, and text. Do not reconstruct it from a later preference value. Clear the toolbar and old feedback on selection clear or chapter replacement. Deferred responses can change visible state only when passage identity and chapter request still match. A durable operation can finish for its captured passage after route exit.

The toolbar sits below the chapter and above the shared tab bar. It must reserve layout height. Do not put it behind the tabs or over status icons. Match source reference/close row, four swatches, and six actions in this order: Bookmark, Note, Copy, Share, Pray, Card. Use a 1.5 maximum text scale for toolbar labels. Action minimum height is 56 points; the close target is 44 × 44; swatch targets are 48 × 44; swatches are 30 × 30. Actions wrap at larger text sizes and align with the Reader column on iPad. Use the source Feather icons, colors, spacing, and border.

## Storage and feedback

Read bookmark state through `SQLiteLibraryRepository.isBookmarked`. Toggle the exact passage through `toggleBookmark`. Show `Saved` and selected state only after success. Feedback is `Bookmark saved`, `Bookmark removed`, or `Bookmark could not be updated`.

Swatch order is gold, sage, rose, blue. Source light fills are `#F4D89A`, `#C8D6C0`, `#E6C5C8`, and `#C6D5E6`. Saved verse fills use the same RGB values at 0.24 alpha in dark mode. Toolbar swatch circles use the light fills in both themes, as specified in `SelectionToolbar.tsx`. A swatch is active only when every selected verse has that same color. Tapping the active swatch clears highlights for the whole selected range. If colors are mixed and any verse is highlighted, show the separate `Remove highlight` control. Applying a color uses `applyHighlight`; clearing uses `clearHighlight`. Update visible fills only after success. Selection remains an outline or underline, so it does not hide the saved fill. Preserve context-fill precedence.

Highlight feedback is `<Color> highlight applied`, `Highlight removed`, or `Highlight could not be updated`. Keep the selection after bookmark, highlight, copy, or share. Show action feedback and send a UIKit accessibility announcement after completion. Failed writes must not change saved appearance. Serialize toolbar mutations or disable mutation controls while a mutation runs. Do not silently treat a failed bookmark lookup as a confirmed unsaved state.

## Note, copy, and routes

Note opens the existing editor with the captured passage. Load its existing text, if any. Save through the accepted `saveNote` operation. Empty source-trimmed text deletes the note. Keep exact JavaScript trim compatibility already implemented in Core. Successful save/delete returns to the previous route. Failed save retains the draft and shows `Your note could not be saved. It is still visible here so you can try again.` Failed delete shows `Your note could not be deleted. Try again.` Disable Save during loading or saving. Preserve source Cancel, Save, scripture preview, private-note placeholder, and conditional Delete note. The editor must work for a passage with no saved item.

Copy and Share use the exact payload `scriptureText + "\n" + reference + " (" + abbreviation + ")"`. Use the captured edition's abbreviation. Copy uses the system clipboard and reports `Passage copied` or `Passage could not be copied`. Share uses the native activity sheet and reports `Share sheet could not be opened` only on failure. Pray and Card route the complete captured passage to the existing Lectio and Scripture Card views. Keep those routes independent of later selected-edition changes.

## Accessibility and runtime checks

Put identifiers on leaf controls. Use `reader-selection-close`, `reader-selection-bookmark`, `reader-selection-note`, `reader-selection-copy`, `reader-selection-share`, `reader-selection-pray`, `reader-selection-card`, `reader-highlight-<color>`, and `reader-highlight-clear`. Expose selected state and `Selected`/`Not selected` values where applicable. Preserve the source spoken action plus reference and swatch Apply/Remove labels. Do not attach a shared identifier to the interactive toolbar container.

Main must observe bookmark add/remove, all four colors, mixed-color clearing, saved fill under selection, and a new note created from a Vulgate passage. Change the current edition, reopen that saved passage, and check its original edition and text. Restart once and inspect exact rows. Verify copy payload, native sharing, Pray/Card passage identity, visible error/draft retention, largest-text controls, and small-screen toolbar placement. These checks are part of Gate B. Accepted existing Saved editing and Undo tests do not replace them.

## First implementation review

The first toolbar and Reader integration need these corrections before acceptance:

1. Main must construct `ReaderSharePayload(text:)`. The first implementation assigns a String to this struct's optional property.
2. If an existing-note lookup fails, Main must keep Save and Delete disabled. A blank draft must not replace an unknown existing note. Cancel remains available. Main must guard the save handlers with successful load readiness.
3. Main must separate unknown bookmark state from mutation activity. Source must disable Bookmark while its state is unknown. Copy, Share, Pray, and Card must remain available after a lookup error. Unknown state must not claim that a bookmark is absent.
4. Source must match the toolbar's actual source metrics. Use horizontal padding 12, top padding 4, bottom padding 8, and content gap 4. Use a 14-point semibold reference and a 20-point close icon. Use zero gaps between swatch targets. Use a 48 × 44 slash swatch for mixed-range removal. Use 36-point action icon circles and 20-point Feather icons. Action basis is `56 * min(max(1, fontScale), 1.5)`. Labels remain on one line and can shrink to 0.8. Feedback is centered and uses the tint color.
5. Main must align toolbar controls with the Reader column on iPad. The toolbar background can span the screen.

The corrected ContentFlow helper uses gestures inside the visible ScrollView area. It excludes the keyboard, tab bar, and navigation area. It records target movement. Its scroll direction must use the target's tap center, so a partly clipped target above the viewport is not moved farther upward. Runtime acceptance remains open.

## Source handoff acceptance

The toolbar source is accepted at SHA-256 `621a6b71b8b92153676eba620c4395fc5fe8204b329587f232bb7c5bd3b0927b`. Its capped text uses `Font.custom(fixedSize:)`, so `@ScaledMetric` does not apply a second scale. It keeps unknown bookmark state separate from mutation activity. It uses source action order, icons, swatches, row distribution, and synchronous callbacks. Swift 6 arm64 simulator type-check passed. Small-screen and large-text runtime acceptance remain open.

The corrected ContentFlow source is accepted at SHA-256 `2fbfdda90ed5d74eee49a5411182e5e7a0bd80288e4d74405bfdb01dbe0dba4d`, commit `6f83b790ff5c964c7975f205707208978c571df9`. A scroll can make progress by moving the target or changing the keyboard. The timer check requires a numerical decrease. Natural timer expiry remains untested.

Main's exact-note lookup and delete boundary, successful-load readiness, duplicate-write guards, captured share payload and error callback, and separate bookmark-known state are accepted for source integration. Reviewed `SavedView.swift` hash: `d0541ade730eb4e84f9ff2e4d040cc07ec9e8393b8beb29b4981e286b42021c0`. Reviewed `ReaderView.swift` hash: `24108f01792ccb217655d197589bc1837129b4c19c25e2ee54361149d3b61826`. The new note and selection runtime checks remain open.

Main corrected the pinned Feather codes and added the toolbar icons. Reviewed `FeatherIcon.swift` hash: `c5c6828683d5632ccefa66118e4d0596b824126f44ce6d6a2543cad362454b70`. The Reader commentary preview now has connected work and chapter-list actions. Visual parity remains open. Verse Moment async identity and content-clock injection still require their queued corrections.
