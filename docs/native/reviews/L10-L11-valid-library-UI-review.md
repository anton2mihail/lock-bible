# Valid-library Saved UI review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: bounded actions observed. Undo and binary provenance remain open.

The first run uses `com.nrsv.verse.dev` with schema 1 and seeded rows 2/1/1. `build/native-evidence/L06/valid-saved-crud-run-01.log` records app PID 61555. It reaches John 1, each Saved filter, the existing John 1:1 note, note edit and save, note reopen, note delete, empty Notes, and deletion of the John 3:16 bookmark. The observed row counts are All 4, Bookmarks 2, Highlights 1, and Notes 1 before deletion.

Sol checked the preserved database read-only. Its SHA-256 matches the report: `0473a7742fb12cc95e42918c1690dd1874335f4db0d0015bdc38dc5cd8a8c5c1`. Schema is 1 and integrity is `ok`. The remaining rows are the WEB-CE John 1:1 bookmark and gold highlight. No note remains. The failure copy is under `valid-saved-crud/run-01-failure/`.

The test fails at Undo lookup. The accessibility hierarchy exposes a button with identifier `saved-undo-banner` and label `Undo`. The parent HStack identifier replaces the intended `saved-undo-button`. The current source moves the status identifier to Text and leaves the Undo identifier on its Button. This is the required source correction. Main will preserve the changed fixture before one fresh-seed rerun.

The Main source identifier audit found leaf control/status identifiers and named Reader ScrollViews. The tested Reader child controls retain separate identifiers. Do not remove working ScrollView identifiers without evidence. Do not add identifiers to HStack or VStack containers that contain interactive children.

Before bounded runtime acceptance, record matching product and installed executable/dylib hashes and the relevant source hashes. The rerun must prove that Undo restores the deleted exact bookmark row. A count of two alone is insufficient. Keep note creation, failed action behavior, ten-second expiry, non-WEB edition identity, complete visual parity, and remaining Reader/Aa checks open. This run edits an existing note; it does not create a new note.

Gate A remains accepted. Gate B remains open. No new migration run is required for this UI correction.

## Run 02 diagnosis

Reviewed on 6 October 2026. App PID is 63341. The leaf identifier is now exposed, but Undo produces hit point `{-1, -1}`. The later screen and hierarchy show Settings. Undo remains unaccepted.

The note-delete screenshot at 22.36 seconds shows the sheet partway down during dismissal. The deletion tap starts at 21.61 seconds. The log then confirms Bookmarks selected and two rows at 23.04–23.17 seconds. It reaches the John 3:16 Delete action at 24.42 seconds. This evidence does not establish a sheet that stays open at the later Undo tap at 25.94 seconds.

The Boolean sheet binding supplies `SavedNoteEditor`. Its success callbacks reload and call `dismiss()`. Add bounded waits for the editor to disappear and the next control to become hittable. These waits are not a proven fix for the Undo position. Before another full run, perform a short delete/Undo check. Record the actual Undo frame, hittability, tab-bar frames, and screenshot. Check the nested bottom safe-area insets in Saved and the root. If the banner overlaps the tab bar, reserve layout height above the bar. Do not tap a stale or invalid coordinate.

## Direct Undo geometry

`saved-undo-geometry-01.log` confirms the layout defect. Undo has frame `{{348.33,809},{35.67,18}}` and is not hittable. The Settings tab has frame `{{321.67,791},{80.33,49}}`. Undo overlaps that tab.

The source now places the banner after the list or empty state in the normal Saved VStack. This is the correct layout boundary. It reserves space above the root tab bar. Restore the source bar and button metrics in the same change: bar height at least 52, horizontal margins 16, bottom margin 8, radius 12, border, left/right padding 16/8, and a 56 by 44 minimum Undo button. The corrected short probe must check that the Undo bottom is above the tab top, confirm hittability, tap it, and verify the exact deleted ID returns. Corrected geometry and restore remain open until observed.
