# Isolated simulator run contract

Date: 6 October 2026.
Reviewer: GPT-6.1 Sol.
Status: conditional run boundary. No second simulator is authorized to start now.

## Current constraint

The machine has 16 GiB of memory and 12 logical CPUs. The read-only check reports 21% free memory and 22,842 MiB of swap in use. Free disk does not remove this memory load. Keep one simulator active. Main keeps the current simulator, shared project, generator, build directory, and Reader work. Source continues independent source and test preparation.

## Conditional isolated run

If Main and Source agree on a later runtime slot, Main must stop its simulator and app build before Source starts a new task-owned simulator. Source must use a new synthetic seed and the existing development bundle ID. Source must not read or change Main's simulator, old-app fixture, or production container.

Main must first publish a complete, frozen `build-for-testing` product. Copy the product directory and its `.xctestrun` file to a Source-owned evidence directory. Keep relative `__TESTROOT__` paths valid. Hash the app, widget, test runner, test bundle, and test-run file before and after the copy. Do not copy an active build output. Source must use `test-without-building`, its own result path, and its own destination UUID. Source must not regenerate the project, compile shared files, or write to Main's DerivedData.

Source can run only the agreed source-reviewed content, Settings/Works, or Media/Notification test method. Run one test process at a time. Preserve failed results and seed snapshots. Record the actual process, simulator UUID/runtime, launch arguments, input hashes, installed product hashes, and final persistent-state fields. Reset only the synthetic container on Source's simulator between independent journeys.

Before the slot, check current memory pressure. If memory pressure increases or launch becomes slow, stop the test at a safe boundary and return the runtime slot to Main. Do not stop unrelated apps or services. Main remains the owner of final build, archive, signing, and production update evidence.

## Next independent Source scope

Source owns a new `native/John/SimulatorSupport/SearchNoteUITests.swift` file. Cover the remaining Search interface behavior and a newly created note with a non-WEB edition identity. Use source-generated search fixtures for expected references and correction text. Keep the existing Saved edit/delete/Undo and short ivory sharing tests unchanged.

Use actual leaf controls. Check reference, quoted phrase, correction, zero results, scope changes, and the final result after rapid query replacement. For note creation, use the Reader's owned visible text or verse layout. Do not select blank space or a verse union-frame center. Create a note on a passage that has no note in the synthetic seed. Open the saved passage after a different current edition is selected. Check the saved edition, passage ID, exact text, and note draft. Use one process restart to check persistence. Main must later inspect exact database rows. Test source and SDK type-check are separate from simulator acceptance.

The source review confirms a missing Reader action boundary. `ReaderView` currently shows the selected range but has no bookmark, highlight, or Add note action panel. Main must implement the planned source actions. Existing Saved-note editing does not replace new note creation. Source will prepare Search tests first. The new-note journey waits for Main's actual action/editor controls. Do not use a seeded note or a Debug state mutation to substitute for this feature.
