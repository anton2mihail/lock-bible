# First Works source review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: complete source files are present. Target compilation and runtime remain open.

Source has added Works route, shared controls, library, collection, chapter commentary, and reader files. The repository adds title-only section summaries. Main can continue the compiled content/widget runtime while Source fixes these concrete defects. No new prototype is required.

| Trigger | Required correction | File |
| --- | --- | --- |
| Compile the route helper | Import JohnCore for `WorkReadingPosition`. | `WorksRoute.swift` |
| Compile the paginator | Use the explicit empty-string attributed-string initializer. | `WorkReaderView.swift` |
| Open the first section | Measure the prose viewport before pages exist. The current GeometryReader requires pages, while page creation requires that reader's measurement. | `WorkReaderView.swift` |
| Fit a line near the page bottom | Fit the complete line rectangle. Do not group solely by `floor(minY / height)`. Ensure progress for a tiny viewport. Reuse the accepted fit mechanism. | `WorkReaderView.swift` |
| Read in dark appearance | Apply the current theme foreground color to attributed prose. | `WorkReaderView.swift` |
| Change typography after paging | Capture and restore the current page anchor. Do not reuse only the startup anchor. Clear old work/section anchors. | `WorkReaderView.swift` |
| Tap pages quickly | Serialize durable position saves. Preserve existing position fields and reject stale feedback. | `WorkReaderView.swift` |
| Continue a saved work | Resume the saved page/anchor. An explicit section route starts at zero. The current Continue callback passes an explicit section and loses resume behavior. | `WorksLibraryView.swift`, `WorkReaderView.swift` |
| Show a shelf or commentary heading | Use source SpaceGrotesk 36/44. The current title helper supplies Lora. | Library, Collection, ChapterCommentary |
| Open an autobiography | Use “book” as the section noun. | `WorksRoute.swift` |
| Return from a nested Works page | Show one source back action. The shared page and nested view currently add two. | `WorksSupport.swift`, nested views |
| Select the most recent work with tied times | Preserve the source insertion-order tie result. Do not depend on unordered dictionary iteration. | `WorksLibraryView.swift` |

Source sends stable files and hashes after these corrections. Main adds target membership and typed route callbacks. The required runtime cases remain the five bounded cases in `L20-L21-Works-handoff.md`. A source parse cannot establish Swift 6 cross-file compilation, complete pagination, durable anchors, or visual parity.
