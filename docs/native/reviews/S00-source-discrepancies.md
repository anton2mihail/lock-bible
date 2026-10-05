# S00 source discrepancies

Date: 5 October 2026.
Reviewed source: `b64e1fc3cfc6a78f508b41d74b71dddfe9ff7697`.
Owner: GPT-6.1 Sol.

These findings come from source review. Simulator confirmation is still open. They do not establish visual parity.

## Saved-item edition

Finding: `src/screens/SavedScreen.tsx` stores the item's edition in its row model. `openItem` does not pass that edition to `/read` or `/note`. `src/screens/NoteEditorScreen.tsx` builds its selection with `getActiveTranslationMeta().id`. The rebuild plan requires the saved edition to control saved context.

Trigger: save a note or bookmark in one edition. Change the active edition. Open the saved item.

Expected native behavior: open the same saved passage in its original edition. Load or save the note against its original passage key. Keep later Reader save operations consistent with the displayed edition.

Decision: the native route contract will include the saved edition. This is an approved-plan correctness requirement. It preserves the saved row's identity. It can differ from defective old-app behavior. Luna must confirm the baseline result in the simulator and record this exception in the parity matrix.

Verification: use WEB-CE and Vulgate notes at the same book/chapter/verse. Give each a distinct synthetic note. Switch editions before opening each Saved row. Verify the exact note, text, and stored passage key after relaunch.

## Search stack

Finding: `src/screens/SearchScreen.tsx` uses `router.dismissTo` for a result. Source comments explicitly require the existing tab navigator. Closing Search uses `back`, or `replace('/read')` if no back destination exists.

Decision: native Search stays on the root push stack. A result returns to the existing Read tab. Do not push another tab shell. Confirm the observed full-stack dismissal behavior in the baseline.

## Selection range

Finding: `ReaderScreen.tsx` uses the current range's first index as the next range origin. Tapping a selected single verse clears it. A multi-verse selection can shrink on the next tap.

Decision: preserve the exact transition function. Do not assume that every tap extends the current endpoints.

Reference sequence with zero-based indices:

1. Tap `10`: selection becomes `[10, 10]`.
2. Tap `12`: selection becomes `[10, 12]`.
3. Tap `8`: selection becomes `[8, 10]`.
4. Tap `8`: selection becomes `[8, 8]`.
5. Tap `8`: selection clears.

Verification: run this sequence on real verses in L01. Record selected verse labels and screenshots. Keep saved highlight fills visible at each step.

## Database version

Finding: `src/services/database/libraryDatabase.ts` sets `PRAGMA user_version = 1` after setup without rejecting a higher version.

Decision: do not copy this behavior into the native importer. If an existing schema is newer than the native code supports, preserve the database. Show a recoverable capability error. Do not lower its version or create an empty replacement.

Verification: use a separate synthetic database with a higher `user_version`. Launch the native migration scenario. Verify the error and unchanged database bytes. Include this in L04.
