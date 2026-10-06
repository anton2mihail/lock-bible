# L13–L16 content preparation contract

Date: 5 October 2026.
Owner: GPT-6.1 Sol.
Status: independent preparation is authorized. Production integration and simulator acceptance remain open.

Source owns this preparation. Main continues Reader and Gate B UI work. Keep drafts under ignored `build/native-evidence/L13-content/preparation/` until source review accepts the public API. Do not change active Core during Main's app build. Main owns project membership and all simulator actions.

## Resources and models

Use the existing staged `App/Catalogs/devotional-catalogs.json`, `App/Calendar/readings-us.json`, and `App/Calendar/celebrations-us.json`. Preserve exact text, IDs, catalog order, optional fields, and source labels. The catalog format is version 1. Validate 27 novenas, 12 prayers, and 5 teaching topics. Novenas have nine progress days. Their prayer sections are independent of these nine days. Do not infer nine distinct prayer sections.

Prepare immutable `Codable` and `Sendable` models. Keep prayer category values, teaching artwork values, novena source URLs, opening text, section titles, paragraphs, and responses. Return missing IDs as missing values. Preserve the source fallback decisions at the selector or screen boundary. Do not replace missing resources with an empty successful catalog.

Prepare a lazy actor-owned bundled repository. Inject resource roots. Keep one bounded cache for each small catalog or calendar file. Do not open SQLite or decode Bible/Works text. Do not decode devotional resources during app startup. First send the public API and source-shape plan for review.

## Calendar behavior

Inject the current instant and time zone. Use the Gregorian calendar with the specified local time zone. Construct dates at local noon. Add calendar days through date components. Do not add fixed 86,400-second intervals across daylight-saving changes.

Preserve strict `YYYY-MM-DD` parsing and local-noon fallback. Reject rolled dates. Preserve the source Easter algorithm and season boundaries. `upcomingSunday` returns the current Sunday when the current date is Sunday. Preserve each source label, reading reference, celebration field, coverage boundary, and USCCB URL format.

Readings are a finite offline map. The current map has 858 dates and an internal gap at `2025-09-18`. Return a missing entry for gaps and out-of-coverage dates. Do not create readings from adjacent dates. Keep readings and celebrations as separate maps.

## Progress and Today selectors

Reuse the accepted `NovenaProgress` and native state types. Prepare pure state operations for intention change, day selection, completion, and reset. Match the source screen callback sequence from the fixture. Keep completed days unique and sorted within 1–9. Preserve intention text. Do not move the selected day through a rule absent from the source.

Return values or accepted state mutations. The repository must not own state writes. Main uses `NativeStateStore` and projects values after a successful durable write. A failed save keeps the current user input available.

Today uses local hour 17 for the morning/evening prayer choice. This rule does not move Sunday to the next week. Preserve the source local-weekday Rosary choice. Preserve catalog order for ongoing novenas. The source keeps unfinished novenas with completed days or a nonempty trimmed intention. Use the first incomplete day for the subtitle. Completed novenas do not appear in this list.

## Evidence and handoff

Use the accepted calendar/novena fixtures from `1439075` and Today fixtures from `67158cf` and `123ce62`. Prepare a DEBUG-only comparison that checks exact fields and ordering. Include UTC, Toronto, daylight-saving boundaries, 16:59/17:00, current Sunday, finite coverage, missing dates, and the novena callback sequence. Main runs the comparator later in a fresh simulator process.

Return public types and methods, file hashes, resource paths, build results, fixture hash, and comparison counts. Host or SDK build success is source evidence. It does not prove runtime behavior. Do not add a unit-test target, notification requests, timers, media access, UI, or new generated resource copies.

Source can also export exact Works catalog counts and the Reader Fathers row label. This export is source evidence. It must not change Works production APIs or add hardcoded UI counts.
