# Reader selection action checks

`ReaderSelectionActionsUITests.swift` contains three separate UI methods. Main owns target membership, test seed creation, simulator run, screenshots, and post-run database checks. Source does not operate a simulator.

Use a new task-only development container for each method. Set WEB-CE and verse-by-verse layout. Start the Reader with no active selection. The tests use visible Read, book, chapter, and verse controls. They do not use a test-only route.

| Method | Required seed state | UI result |
|---|---|---|
| `testRemoveExistingVerseBookmark` | One bookmark for WEB-CE JHN 1:1 | Select JHN 1:1 and remove the bookmark. The toolbar changes to `Not selected`. |
| `testClearMixedRangeHighlights` | Gold highlight on JHN 1:1 and sage highlight on JHN 1:2 | Select JHN 1:1–2 and tap `Remove highlight`. The mixed-clear control disappears and all four swatches report `Not selected`. |
| `testCopySelectedVerseText` | WEB-CE JHN 1:1; no required saved row | Select JHN 1:1 and tap Copy. The app reports `Passage copied`. |

The canonical JHN 1:1 verse text is `In the beginning was the Word, and the Word was with God, and the Word was God.` The native copy payload contract is `1 <verse text>\nJohn 1:1 (WEB-CE)`. Main must inspect the simulator pasteboard from the simulator process after the copy method. The UI test does not claim that the test runner can read the app's pasteboard.

Main must use a fresh database for each mutation method. Main must inspect the saved row after bookmark removal and both highlight removals. Keep the source database and the app-side postconditions in separate evidence records.
