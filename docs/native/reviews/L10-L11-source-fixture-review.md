# L10 and L11 source fixture review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: source fixture and narrow note-trim correction accepted. Simulator comparison and screen behavior remain open.

Commit `ee6ca10` contains the generator and handoff under `scripts/native/source-fixtures/library/`. It calls the existing library repository with in-memory SQLite. It controls each `Date.now` call. It does not read a user database or run screen tests.

The sequence covers bookmark add, remove, and add again. It applies all four highlight colors and records exact groups and per-verse batch values. It saves a trimmed note, deletes it with whitespace-only input, and saves a final note. It records all four Saved filters in source order. It deletes and restores the gold highlight group with its original IDs, indexes, labels, batch IDs, and millisecond times. The source output hash is `1d26c5f2a65681b59085a0425a585d3767841edb32533b65169844c3cbf4623f`. Source reports two equal outputs.

The screen contract is separate. Undo lasts 10 seconds. A failed delete keeps the item visible. A failed restore keeps undo available. A failed note save keeps the draft. Successful note save or delete returns to the prior screen. Main must show these behaviors in the simulator. Use the exact source fixture for repository comparisons and real Scripture for screen flows. Do not substitute synthetic verse text into the product UI.

The old Saved note route omits the edition parameter. The approved native route preserves the saved passage's edition. This is an intentional identity correction. Keep the same passage and edition when opening or saving its note. This follows the plan's upgrade and cross-screen requirements.

## Unicode note trimming

The source follow-up calls the actual `saveNote` function with U+FEFF-only and U+0085-only input. U+FEFF deletes the note. U+0085 saves that character as the note text, with created/updated time `1800000000008`. Two generated outputs match. The output SHA-256 is `9a34df2dd4196d2c64ceee878d2dfd1050a1738901b95e288bfd4dccfc5975de`.

The earlier native `saveNote` used Foundation whitespace trimming. It kept U+FEFF and removed U+0085. The latter case could delete text that the source saves. Commit `d6d5c00638e6d44f2838c4baf43de7c938011e6a` uses the exact JavaScript trim whitespace set for note text. Importer and state normalization stay unchanged. This correction belongs to L10. It does not change the accepted same-ID import binary. The separate Unicode source fixture is committed at `cb355d44d04ab6215c2cc5e0b6bc37f894588ea3`.

The host package build, arm64 iOS Simulator SDK build, and DEBUG comparator type-check pass. See `build/native-evidence/L10-L11/core-check/REPORT.md`. Core repository SHA-256 is `7bfca25948aba5bc491f685c04d2d579f46e00d966a60b5388b1078c873bba3e`. Comparator SHA-256 is `664d134f1dab71687f49b01557997ea0ffe0a0e7ee74254f9db47ff040a61e24`. The comparator requires 19 source snapshots and 19 native observations. These checks do not prove simulator results.

Source supplies a DEBUG-only comparison of the complete action fixture with an injected clock. Main runs it on the simulator. Compare all original fields, timestamps, batches, grouping, filters, and delete/restore payloads. Include both Unicode trim probes. Keep UI save failure and undo behavior in the separate Main screen checks. Native L10/L11 acceptance remains open.
