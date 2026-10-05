# S01 contract questions

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Status: proposed. L01 evidence is required before approval.

## Domain identity

Keep translation IDs exactly: `web-ce`, `douay-rheims`, `vulgate`. Keep book codes and verse labels from the bundled data. A verse label is a string. A verse index is its zero-based position in a chapter. Do not convert a label such as `1-2` into an integer.

`PassageID` includes translation, book, chapter, first verse label, and last verse label. Its legacy database key is the exact colon-separated source key. `PassageSelection` also carries ordered verse indices and the exact selected verse text. Build selection from validated chapter data. Keep headings out of the copied Scripture text.

Keep stored timestamps as milliseconds since epoch. Use `Int64` for database timestamps. Convert them explicitly when an Apple API needs seconds. Keep old batch IDs unchanged during import and undo.

For native reading anchors, use the verse label and an offset in UTF-16. For works anchors, use the section index, paragraph index, and an offset in UTF-16. An anchor is independent of font and viewport size. Legacy scroll and page values remain approximate hints until a native anchor is saved.

Question: Can the L01 renderer report a stable anchor at the visible reading position without selecting a different verse?

## Route and request ownership

`AppRouter` owns the selected tab, pushed destinations, and presented sheets. Each feature model owns its content and transient controls. Reader selection stays in the Reader model. One observable preference store supplies both Settings and Aa.

Keep Search above the original tab screen. Closing Search restores that screen. Selecting a result returns to the existing Read tab and sends a passage request. Do not create a second Reader model for each search result.

Each passage request has a new request ID. The request can include an explicit translation. Repeated requests for the same passage still reposition the existing Reader. If a saved item has an edition, that edition takes precedence over the current global setting. A changed translation must not replay an old request.

Decode external URLs at one boundary. Validate route, book, chapter, verse labels, dates, and catalog IDs. Keep accepted legacy URL fields. Queue a cold-start request until migration and preferences are ready. Consume each request once. Keep the order of requests that arrive during startup.

Question: Does the baseline clear the full root push stack when a Search result opens Read? Confirm the observed return behavior before freezing the route contract.

## Data and concurrency

Keep data models immutable and `Sendable`. Keep UI models on `@MainActor`. Use one actor for each writable SQLite handle. Use read-only handles for bundled search and works data.

A library transaction must not suspend between `BEGIN` and `COMMIT`. Swift actors can run other actor work at a suspension point. Use synchronous prepared operations inside one actor call. On error, roll back the full operation. Keep statements inside their actor. Finalize them on every exit path.

If an existing database has a newer unsupported schema, report it. Do not lower `user_version`. If an existing library is unreadable, keep its files and backup. Do not create an empty replacement at that path.

`BibleRepository` returns metadata and one requested chapter or book. `SearchRepository` accepts a translation, scope, and immutable query request. It returns reference/text results and an optional correction. The UI tracks the request ID. Discard an old response after typing, scope change, or edition change.

`WorksRepository` returns catalog data without opening its database. Section loading reads one row. Contents loading reads titles and counts only. Return a distinct missing-section result. Check decompression size and JSON shape before showing text.

Question: Do simulator FTS5 and zlib proofs support the small system-library wrapper without another database dependency?

## Preferences and import

Keep the legacy SQLite library schema and path. Direct use of this database avoids a second row-copy migration. Make a consistent backup before native library writes.

The installed `react-native-mmkv` package is version `3.3.3`. Its bundled MMKV Core declares `v2.0.0`. Source config creates a default unencrypted instance. The installed wrapper can select an App Group path from Info.plist. The runtime container decides the actual import path.

Use a narrow adapter over a compatible MMKV library. Open legacy state read-only. Do not embed React Native or Hermes for import. Preserve unknown keys and legacy files. Use each feature loader's normalization rules. Most keys contain JSON strings. Theme also permits a raw string.

Theme is a key-specific raw-string path. In `src/theme/context.tsx`, absent or empty saved theme follows the system. The exact raw string `dark` selects dark. The exact raw string `light` selects light. A different nonempty string selects light in the current source. Do not apply the generic JSON parser to this key and change its meaning silently.

A migration completion marker must not become durable before the imported payload. Design one versioned native state envelope or a recoverable journal. If multiple UserDefaults keys are used, do not assume they commit atomically. Prove each interruption point in L04.

Existing valid native values take precedence after a successful import. A retry must not overwrite changes made by the user after migration. A damaged legacy payload affects that capability only. Keep the raw legacy value in recovery storage. Do not expose private values in diagnostics.

Question: Which adapter build preserves MMKV v2 compatibility with the smallest reviewed dependency surface?

Question: Which native payload and journal structure makes killed migration retries safe without importing over newer native changes?

## Rendering and shell

Keep pure Scripture structure calculation in `JohnCore`. Keep platform text layout and hit testing in `Platform/TextRendering`. A SwiftUI view hosts the approved UIKit renderer. The renderer receives immutable text, selection, highlights, and style values. It sends verse actions and anchors back to the feature model.

Rebuild attributed ranges after typography or geometry changes. Keep the domain selection unchanged. Map break/heading offsets through UTF-16. Keep four highlight fills visible under selection. Keep source line-height rounding for verse numbers.

Works keep pages. Page calculation must retain exact text and paragraph gaps. An empty or too-small viewport must terminate safely. Do not repeat or omit text at a page boundary. Changing width or type restyles the same section at the same text anchor.

Choose tab chrome from L01 comparison. Preserve flat app-owned surfaces, top border, Feather geometry, and five-tab order. Use public APIs. Standard system dialogs and share sheets use OS presentation.

Question: Which native renderer gives the closest observed baseline line breaks and reliable verse hit testing?

Question: Does a standard iOS 26 `TabView` meet the baseline geometry? If it does not, select custom flat SwiftUI chrome and review its accessibility and safe areas.

## Resource and build boundary

Keep the native project under `native/John/`. Keep `/ios` as the old generated reference. Stage existing canonical resources with a deterministic script. Do not commit duplicate large databases.

The resource manifest records hashes, counts, schema, edition IDs, and calendar coverage. App and widget bundles have separate resource lists. Widgets receive the small corpus/index/calendar resources they use. They do not receive the private library or the works database.

Keep CI and local builds on the pinned Xcode toolchain. Use iOS/iPadOS 26.0 deployment targets and Swift 6 checks. Exclude fixture controls and development media from release archives. Keep a separate side-by-side development ID. Keep a production-ID update scheme.

Question: Can the prototype build stage exact resources and the selected importer dependency from a clean checkout with a pinned lockfile?

## S01 approval output

After L01 review, publish ADRs for modules, route/state ownership, storage/import, text rendering/pagination, resource packaging, and iOS 26 chrome. Publish contracts with exact field names and failure behavior. Dispatch L02 first. Then dispatch L03, L04, and L05 in dependency order. Keep one writer for shared project files, router, theme, schemas, and manifest.
