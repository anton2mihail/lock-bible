# L10 and L11 source fixture review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: source fixture accepted. Native repository and screen behavior remain open.

Commit `ee6ca10` contains the generator and handoff under `scripts/native/source-fixtures/library/`. It calls the existing library repository with in-memory SQLite. It controls each `Date.now` call. It does not read a user database or run screen tests.

The sequence covers bookmark add, remove, and add again. It applies all four highlight colors and records exact groups and per-verse batch values. It saves a trimmed note, deletes it with whitespace-only input, and saves a final note. It records all four Saved filters in source order. It deletes and restores the gold highlight group with its original IDs, indexes, labels, batch IDs, and millisecond times. The source output hash is `1d26c5f2a65681b59085a0425a585d3767841edb32533b65169844c3cbf4623f`. Source reports two equal outputs.

The screen contract is separate. Undo lasts 10 seconds. A failed delete keeps the item visible. A failed restore keeps undo available. A failed note save keeps the draft. Successful note save or delete returns to the prior screen. Main must show these behaviors in the simulator. Use the exact source fixture for repository comparisons and real Scripture for screen flows. Do not substitute synthetic verse text into the product UI.

The old Saved note route omits the edition parameter. The approved native route preserves the saved passage's edition. This is an intentional identity correction. Keep the same passage and edition when opening or saving its note. This follows the plan's upgrade and cross-screen requirements.
