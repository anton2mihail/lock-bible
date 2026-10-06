# Search, Saved, and note UI source review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: source present; focused corrections and runtime evidence required.

The accepted L09 and L10 repository evidence remains valid. The corrected L10 comparator is committed at `18c9306`. Main has added Search and Saved views. Main can finish its current compile before applying these UI corrections. Do not repeat Gate A or the Reader range setup.

Search must use the source root heading “Search Scripture” and Cancel action. Use 24-point sides and equal-width, 44-point scope buttons with radius 10. Keep the previous results during debounce. Put the searching indicator in the input row. Preserve exact source empty text, curly-quoted correction, and singular/plural result count. Use complete Georgia 17/26 result text with matched-token fills. Remove the four-line truncation and added edition tag. Keep request and edition identity across navigation.

Saved must use its source 36/44 heading and equal-width, 44-point filters. Each row has a four-point colored marker, a 128-point minimum, and a visible Delete action. Preserve source empty, error, and reference-specific undo text. Use Georgia 16/23 excerpts and source highlight labels. A swipe-only action does not preserve the source flow.

The note editor needs the source Cancel/reference/Save header, explicit Delete note action, Georgia 17/27 excerpt with an eight-line limit, and an 18/28 editor. Preserve the private-note placeholder. A failed save keeps the draft. A successful save or delete returns to the caller. Preserve the saved item's edition.

The first undo timer checks only the item ID. A repeated delete of the same restored item can let an old timer remove the new undo action. Use an operation token or cancel the old timer. After a restore awaits, clear only its captured undo token. An older restore must not remove a newer undo action.

Run one coherent Search, Saved, and note simulator batch. Check debounce and stale requests, correction, scopes, result return, four Saved filters, note save/delete, visible Delete, ten-second undo, and failed writes with preserved visible state. Keep full visual acceptance open until matched old/native images are observed.

## First target compile

`build/native-evidence/L06/search-saved-build-04.log` reports TEST BUILD SUCCEEDED for the Debug arm64 simulator target. The source now captures query, scope, and edition before awaiting. Its attributed result renderer preserves source regex order and theme fills. Saved has visible Delete, a note action, and an undo token. This is sufficient for the first short Search-to-Reader and Saved-filter observation.

The first focused UI run stopped before entering a query because the screen identifier replaced the field identifier. Main removes that screen-level identifier and preserves the failed run. This correction does not establish source parity. Only the new run that reaches the query, result, Reader, and filters can establish that limited runtime scope.

Remaining source guards include generation-owned loading cleanup and stale reload invalidation after a mutation commits. Selected scope/filter text uses the theme card color, not white. Delete and error text use the source theme error color. Full note/delete/undo runtime and matched screen images remain open.

## Second focused runtime

`L06/search-saved-ui-02.log` records app PID 36575. The run entered a query, found results, tapped result 1, reached Reader verse 1, and entered Saved. This is bounded navigation evidence. The assertion does not establish the exact tapped result reference or Reader chapter. Both filter assertions failed. The accessibility tree gave All, Bookmarks, Highlights, and Notes the same `saved-screen` identifier. No filter action is accepted.

The process was stopped after its failure summary. The result bundle is incomplete and remains preserved. Main applies the identifier correction in the next coherent content build. Put identifiers on actual controls and static status text. Remove broad identifiers from interactive lists and the Undo banner. The next short flow must record the result reference, matching Reader coordinates, and one actual Notes filter selection. Do not repeat the long Reader range setup.

## Short corrected run

`L06/content-widget-search-saved-01.log` reports TEST EXECUTE SUCCEEDED. One test passed with no failures in 21.048 seconds on the pinned simulator. It entered “in the beginning”, found results, opened Reader, entered Saved, tapped Notes, and checked its selected state. Accept this bounded navigation and Notes-filter behavior. The prior identifier failure is corrected.

The current Reader assertion compares only the first reference word with the Reader title. Exact chapter and verse identity remain open. The Notes content check permits either an empty state or a row, so it does not prove the note record identity. All four filters, note save/delete, visible deletion, undo, failed writes, screenshots, and complete UI parity remain open. Main collects those observations in the current extended journey. No repeat of the accepted Notes path is needed.
