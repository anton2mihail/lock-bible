# Library source fixture

This fixture calls the current TypeScript library repository functions. It uses an in-memory SQLite database and a fixed millisecond clock. It does not read or change the user's library database.

Run from the repository root:

```sh
bun scripts/native/source-fixtures/library/library-sequence.ts build/native-evidence/L10-L11/library-sequence.json
```

The output records the bookmark add/remove/add sequence; four highlight colors and batch IDs; note trim, empty delete, and save; all Saved filters and order; and a highlight delete/undo sequence. Each output row includes exact IDs, verse labels, verse indexes, batch IDs, and timestamps.

The generator was run twice with the same command. Both output files had the same SHA-256: `1d26c5f2a65681b59085a0425a585d3767841edb32533b65169844c3cbf4623f`.

The generator calls `toggleBookmark`, `applyHighlight`, `saveNote`, `listSavedItems`, `deleteSavedItem`, `restoreSavedItem`, and `groupHighlightRows` from `src/services/library/libraryRepository.ts`. The screen-level loading and callback sequence is described in the output. `SavedScreen` and `NoteEditorScreen` tests use mocks for repository calls, so the fixture does not claim to execute those screen tests.

The current source action tests are listed in the generated `provenance.sourceTestActions` field. The JSON records SHA-256 for the library service, types, selection helper, schema creator, screens, and screen tests. The fixture is source evidence. It is not a native simulator result. Keep output in ignored `build/native-evidence/L10-L11/`.

## Main simulator handoff

Use the `request` selection fields as the inputs for the native repository scenario. Compare the native results to the matching `snapshots` fields. Check each bookmark toggle result. Check the highlight rows and grouped `SavedItem` values, including batch IDs. Check that whitespace-only note save removes the note. Check the four Saved filter outputs and their order. Delete the gold highlight group, then restore it. Compare the restored rows byte-for-byte at the field level with `snapshots.restoredHighlightRows`.

The generator sets `Date.now` to `1800000000000`. Each source call to `Date.now` increments the value. Actions that do not read the clock do not increment it. Native checks must inject or otherwise control time to compare exact timestamps and batch IDs. Do not use this fixture as a request to add a test target.

The screen contract is separate from the repository sequence. Saved deletion removes the row from the visible list only after the repository call succeeds. A failed delete keeps the item visible. The undo action remains available for 10 seconds. A failed restore keeps the deleted item and undo action visible. A successful note save or note delete returns to the prior screen. A failed note save keeps the draft in the editor. The source Saved note route omits the translation parameter. The fixture keeps `web-ce` passage identity. The native route must preserve the selected edition under the approved contract.

## JavaScript trim probes

The generator also records two source-only edge cases. JavaScript `String.trim()` removes U+FEFF, so a BOM-only value deletes the note. It does not remove U+0085, so a NEL-only value saves one note. Native note code must match the JavaScript result. Do not use Foundation trimming rules without checking these outputs.

Run the follow-up into a new ignored output path:

```sh
bun scripts/native/source-fixtures/library/library-sequence.ts build/native-evidence/L10-L11/library-sequence-unicode-trim.json
```

Compare `snapshots.noteAfterBOMOnlySave` and `snapshots.noteAfterNELOnlySave`. The first value must be null. The second value must contain U+0085. The earlier action sequence remains in the same fixture output.
