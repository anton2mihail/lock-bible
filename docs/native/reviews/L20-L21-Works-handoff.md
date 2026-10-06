# Works implementation handoff

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Status: ready for Source after its content UI batch. Runtime acceptance remains open.

Use ADR 0004 and the accepted ReaderProof mechanism. Do not make another renderer prototype. Source owns new `Features/Works/` files and a new Works-only platform renderer file. Main owns Runtime, router, project membership, shared typography, and all simulator actions. Do not edit Main's Scripture renderer.

## Routes and view boundary

Source defines a `WorksRoute: Hashable, Sendable` with library, collection ID, work ID with optional requested section, and chapter-commentary identity. Commentary carries book code, chapter, and the captured Bible display name. It reads the catalog only. Main maps these routes into AppRoute and supplies close/navigation callbacks.

Use the four source screens under `src/screens/works/`. Preserve their own SpaceGrotesk headings and layouts. They do not use the companion Lora Page title. Keep source collection/work order, nine kind groups, plural labels, reading-length labels, attribution, and missing-author/work/chapter states. The current catalog has 26 collections and 271 works. Derive visible counts from the catalog.

Library and collection browsing must not open the Works database or decode paragraphs. The Reader shows the source first-three commentary links and the complete chapter-commentary destination. Group the complete list by author in source insertion order. A commentary link opens its exact work and section. Invalid routes show the source fallback.

## Existing repository

Use the shared `SQLiteWorksRepository`. Its initializer stores roots only. `catalog()` reads `App/Catalogs/works-catalog.json`. `section(workID:index:)` queries one row from `App/Databases/works.db`. It accepts bounded zlib BLOB and plain JSON TEXT. The decoded limit is 400,000 bytes. Keep the tested read-only database and schema-2 boundary.

Main exposes the existing repository to the new views. Do not create a second database owner. The only required Core API addition is `sectionSummaries(workID:)`, with an immutable index/title/words result. Use the source query `SELECT idx, title, words FROM sections WHERE work_id = ? ORDER BY idx`. Do not read paragraphs for Contents. Coordinate this small Core change before Main builds.

## Renderer and state

The renderer takes the current immutable section paragraphs, section identity, reading preferences, system text scale, and actual content viewport. It returns page count, page changes, and a `WorksAnchor`. Keep original paragraph and UTF-16 ranges. Measurement and rendering use the same width, font, and line height. The source paragraph gap is 14 points. Charge it once between paragraphs. Do not copy the prototype's half-line gap. A continued paragraph starts a page without an extra gap.

Use complete line boxes. A viewport smaller than one line must still terminate. Preserve exact text across all page runs. Use the source horizontal page gesture, page indicator, section arrows, Contents sheet, close button, translation footer, and accessibility labels. Source chrome caps at 1.5 system scale; the close glyph caps at 1.4. The Scripture body still follows the actual system scale.

An explicit section starts that section at page zero. Without one, use the saved section and page hint. Clamp safely to the loaded work and actual pages. Prefer a valid native text anchor after repagination. A changed width, typeface, line spacing, or system text size restores the same paragraph/UTF-16 text anchor. Page number alone is insufficient.

Read positions from `committedNativeState.worksPositions`. Save through `applyWithResult(.setWorksPosition(workID:value:))`. Preserve legacy `workId`, `sectionIndex`, `pageIndex`, and millisecond `updatedAt` fields. Add an `anchor` object with sectionIndex, paragraphIndex, and utf16Offset for native resume. Preserve unrelated fields. No MMKV write or new state store is permitted. A save failure keeps the readable page and existing capability warning.

Capture work, section, and load generation before awaits. Clear old section text at load start. Discard late section or Contents responses after navigation. A stale page callback must not save a position for the new section. Use the latest committed snapshot for Continue. Preserve the source latest-position tie behavior.

## Focused simulator evidence

1. Open library and one collection offline. Check counts, source kind order, and catalog-only loading. Open a Reader commentary link and its complete author-grouped list.
2. Read the existing Chrysostom John section used in L01. Turn pages in both directions. Check exact text continuity and paragraph boundaries. Open Contents at the current section and jump near the last section of a large work.
3. Use the largest real decoded section identified by the L01 storage sweep. Record decode/layout time and memory. Check no page clipping or missing/duplicate text. Reuse the accepted TEXT/BLOB/error repository cases; do not run another full host sweep.
4. At a known text anchor, change text settings and width. Use one iPad or rotation check and one large system text size. Check the same anchor, readable chrome, and safe tiny-viewport termination.
5. Save a page, terminate, and relaunch in a new process. Check the work, section, and text anchor. Deliver an explicit section and confirm page zero. Delay one section load, then change section or close; confirm no stale content or position write.

Capture matched old/native Works library, collection, commentary, Reader, and Contents states in the coherent feature batch. Repository builds and parse checks do not close L20/L21 or Gate D.
