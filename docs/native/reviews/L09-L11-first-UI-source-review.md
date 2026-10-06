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
