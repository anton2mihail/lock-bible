# Gate B dispatch contract

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Status: ready for dispatch after Gate A acceptance.

Main owns app composition, routing, project files, UI, and every simulator action. Source owns Core repositories and source fixture scripts. Preserve this file split. Each accepted ticket needs its own scoped commit and simulator evidence. Use the existing source fixtures. Do not add a unit-test target.

1. Main completes L06 and L07 in `Features/Reader/` and `Platform/Text/`. Apply the findings in `L06-L08-reader-source-review.md`. Show book/chapter/GoTo navigation, previous/next, source prose and poetry, real selection taps, context reveal, and saved fills. Keep the source chrome and exact text.
2. Source implements L09 in separate Core parser and search repository files. Use the accepted `2429a8b` fixture contract. Preserve aliases, NFKD normalization, UTF-16 distance, fuzzy thresholds, CAST ranges, correction rules, scopes, 60-row limit, and stable ordering. Return request IDs with immutable results. Use an actor-owned read-only SQLite connection. Main owns debounce, cancellation, highlights, errors, and result navigation.
3. Main completes L08 with the accepted per-control state mutations. Connect Continue reading and location persistence. Preserve text anchors through style and edition changes. Show live Aa controls, durable restart, verse layout, and Dynamic Type.
4. Main completes L10 and L11 with the reviewed schema-1 repository. Show bookmark, all highlight colors, note trim/save/delete, Saved filters, context opening, delete/undo, and failure announcements. Source fixes Core defects when review identifies them. Keep original IDs, batches, and millisecond times.
5. Main completes L12 in the Verse Moment and widget target files. Use Core rotation and native shared preferences. Preserve all widget kinds, family lists, pool order, timeline boundaries, and URL behavior. Source supplies exact rotation/reference fixtures. Main records actual simulator widget behavior where available. Keep signed App Group and physical-device limits explicit.

Source may prepare Calendar and novena source fixtures in parallel after the storage and Search handoffs. Production devotional code begins only from reviewed content and state contracts. It must not change shared Reader or project files without Main.

Gate B requires an offline fresh and upgrade reading flow, the exact search fixtures, existing-user library actions, source route comparisons, and widget identity/URL evidence. Gate B does not close the later content, Works, fidelity, performance, release update, or signing gates.
