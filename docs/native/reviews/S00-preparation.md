# S00 preparation

Date: 5 October 2026.
Owner: GPT-6.1 Sol. Role: architecture and review.
Status: core baseline accepted in `S00-staged-acceptance.md`. Full L00 evidence remains open.

## Review scope

The approved rebuild plan controls the scope. The current Expo app is the visual and behavior reference. All 29 routes remain in scope. Existing marketing files remain outside this work.

Use the simulator for almost all checks. Do not add a unit-test suite. A build proves compilation only. A screenshot proves only the visible state shown in that image. Device-only checks remain release conditions. They do not block source review or early prototype work.

The source baseline in the plan is `b64e1fc`. Luna must report the actual build source SHA. If it differs, review the affected source before freezing the baseline. Keep baseline images unchanged after acceptance.

`RTK.md` was not found in the project or the searched Codex instruction paths. Apply the supplied `AGENTS.md` language rules. Do not infer missing RTK rules.

## L00 evidence needed

1. List all 29 routes and their initial, loading, empty, error, and return states where applicable.
2. Record each capture path with its source SHA, device, OS, app configuration, date, theme, and text size.
3. Report which states were observed in the running app. Mark source-only states separately.
4. Compare Today and Reader with the current source. Do not use old store images as Reader acceptance evidence.
5. Record actual app ID, widget ID, App Group, URL scheme, and entitlements from the built binary.
6. Record the actual SQLite and MMKV paths in the baseline container.
7. Record MMKV version, instance ID, configuration, and encryption state. Do not log private values.
8. Create a synthetic state fixture. Include multi-edition notes, overlapping highlight batches, timestamps, settings, progress, favorites, reflections, locations, and reminders.
9. Preserve the seeded old app container for same-ID update checks. Record WAL handling and the fixture inventory.
10. Name each missing capture and the reason. Missing device-only evidence is an open release condition.

## Source findings and questions for S01

| Area | Source finding | Decision proof needed |
| --- | --- | --- |
| Scripture structure | `chapterLayout.ts` merges verse spans into blocks. It orders inline headings before breaks at equal offsets. Its string offsets use UTF-16. | Can an attributed native renderer preserve these ranges, line breaks, verse labels, and wrapped-line taps? |
| Selection | `PassageSelection` carries both verse labels and zero-based indices. Saved passage keys use labels. | Keep identity independent of layout. Prove that a bridge label and split verse map to one verse action. |
| Highlight | `ChapterText.tsx` draws active selection as an outline or underline. Saved fills remain visible. | Prove all four fills under active selection in light and dark appearance. |
| Reader position | Explicit context requests override resume. A new `contextRequest` repeats the same positioning action. Legacy resume stores raw `scrollY`. | Use a request identity and a verse/text anchor. Treat old `scrollY` as a one-time approximate input. |
| Text settings | Source preferences publish live updates. Reader defaults are medium, comfortable, serif, paragraphs. | Prove live restyling with the sheet open. Avoid double Dynamic Type scaling. |
| Works | `PaginatedProse` packs measured paragraph lines. Pages can end inside a paragraph. `worksService.ts` decodes one zlib section. | Prove native page calculation with real paragraphs. Keep paragraph gaps and content across page boundaries. |
| Works resume | Old positions use section index, page index, and milliseconds since epoch. Page index is a hint. | Add a paragraph and UTF-16 text anchor. Prove position retention after width or text changes. |
| Legacy storage | Default MMKV is created without custom config. `load` parses JSON and otherwise returns the raw string. Theme uses a raw string. | Prove compatible native reads from the actual baseline files. Do not hand-parse MMKV. |
| SQLite | Library keys encode translation, book, chapter, and verse labels. Search uses FTS5 and `bm25`. | Prove read-only bundled FTS queries and consistent backup of a live WAL library. |
| Tab chrome | Expo uses a flat background, top border, five Feather icons, and fixed tab order. | Compare standard iOS 26 `TabView` with custom flat chrome. Choose from matched screenshots and accessibility checks. |

## L01 scope after S00

L01 is a proof ticket. It is not permission to start all screens. Luna can use `native/Prototypes/` for the native proof project. Luna owns prototype code, scripts, build files, simulator work, and evidence. Sol owns decisions in `docs/native/adr/` and reviews in `docs/native/reviews/`.

Create three proof areas in one small app. Use production-compatible dependencies and real source data. Keep scenario controls in debug builds. Do not change the old app's content, schema, IDs, release behavior, or existing resources.

### L01-R: Scripture renderer

Use `src/services/bible/types.ts`, `chapterLayout.ts`, `src/components/ChapterText.tsx`, `src/screens/ReaderScreen.tsx`, and `src/services/library/selection.ts` as exact references.

1. Render WEB-CE prose, Psalm headings/poetry, Song of Songs speakers, and an edition without paragraph markers.
2. Include real accented Latin text. Add a separate synthetic fixture with a combining mark and a non-BMP character at a break boundary.
3. Tap the first line and wrapped continuation of a verse. Extend a range. Repeat a context request for the same verse.
4. Show each saved highlight color under active selection in light and dark appearance.
5. Change text size and width. Keep the passage identity and an anchor in the same verse.
6. Show verse-by-verse accessibility elements with selected state and heading semantics. Record simulator accessibility inspection. Reserve actual speech for the device check.
7. Record build output, tapped verse IDs, screenshots, long-chapter layout time, and the affected SHA.

### L01-W: Works pagination and data

Use `src/components/PaginatedProse.tsx`, `src/services/works/worksService.ts`, `types.ts`, the works catalog, and `assets/works/works.db` as exact references.

1. Decode real zlib BLOB rows with a compatible zlib decoder.
2. Decode a separate synthetic legacy TEXT row. Do not modify the bundled database.
3. Load one real long section. Prove that unrelated sections are not decoded.
4. Page through a paragraph boundary and a page boundary inside a paragraph.
5. Change text size, line spacing, typeface, and width. Restore a text anchor in the same section.
6. Show contents at the current section. Show missing-row and damaged-data recovery states.
7. Record paragraph counts, page ranges, screenshots, measured decode/layout work, and the affected SHA.

### L01-M: Same-ID storage read

Use `src/utils/storage/index.ts`, all feature state loaders, `src/services/library/`, the installed MMKV implementation, and the actual L00 container as exact references.

1. Use a compatible native MMKV adapter. Read its version and configuration from the installed source.
2. Install the prototype over the seeded old app with `com.nrsv.verse`. Do not uninstall first.
3. Read the actual legacy SQLite library and MMKV values. Compare them with the synthetic fixture inventory.
4. Preserve library keys, note text, highlight batch IDs, timestamps, progress, favorites, reflections, reader/works hints, reminder settings, and shared widget preferences.
5. Use the SQLite backup API for a live WAL database. Verify recent committed rows in the backup.
6. Demonstrate fresh install and invalid MMKV payload handling. Do not replace unreadable legacy files with an empty store.
7. Prove a real FTS5 query with the bundled database on the simulator runtime.
8. Record binary IDs, adapter version, container paths, fixture comparison results, build output, and the affected SHA. Exclude private values from logs.

L01 proves the read path and backup method. L04 proves the full versioned importer, interruption recovery, and completion marker. L27 repeats release-mode updates.

### L01-C: Shell comparison

The plan also requires an early chrome proof. Include a small standard `TabView` and a flat custom tab bar in the proof app. Use the old tab tokens and Feather shapes. Capture both beside the L00 Today and Reader reference on the same device and text size. Check five tab labels, selected state, touch targets, safe areas, keyboard behavior, and an iPad width. Do not choose chrome from an unobserved assumption.

## Acceptance rule

Sol will publish S00 after reviewing L00. Sol can accept S00 in stages when core Reader, storage, and shell evidence is sufficient for L01. Less critical route captures can continue during independent prototype work. List each missing state and its later acceptance condition. This staged acceptance does not prove all-route parity.

Sol will publish S01 after reviewing L01 source and evidence. Unobserved parity remains open. If a proof fails, Sol will request a focused correction with a trigger, expected behavior, file, and simulator check.
