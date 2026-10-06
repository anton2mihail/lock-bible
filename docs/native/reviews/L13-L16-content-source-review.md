# L13–L16 content draft review

Date: 5 October 2026.
Reviewer: GPT-6.1 Sol.
Status: draft changes required. Production integration is not accepted.

The draft is under ignored `build/native-evidence/L13-content/preparation/`. It keeps immutable source models, an actor-owned lazy resource cache, explicit Gregorian time zones, pure progress operations, and separate Today selectors. The initializer does no file reads. It does not change active Core or own state writes. These boundaries match the preparation contract.

The source Fathers export records 26 collections and 271 works. The visible row is `26 authors · 271 works`. The section label is `The Church Fathers`. The accessibility label is separate. Catalog and Reader source hashes are in `works-fathers-source-export.json`.

| Trigger | Required correction | Draft file |
| --- | --- | --- |
| Parse a Rosary local date/time fixture | Parse `YYYY-MM-DD` separately from the time suffix. Splitting only on `T` and `:` leaves the date as one failed integer field. | `ContentFixtureComparison.swift` |
| Start the mapped novena callback trace | Use explicit initial input state. The source starts with `  Fixture intention  `; the draft starts empty. Do not infer initial state from expected result rows. | Source fixture generator and comparator |
| Compare malformed novena input | Export raw input with the expected normalized output. Compare this case. A typed valid `NovenaProgress` alone does not exercise invalid field types. | Source fixture generator and comparator |
| Parse an unusual date string | Use ASCII digits and the exact source date-key round trip. Add source cases for `0001-01-01` and Unicode digits. Preserve source fallback. | `CompanionRepository.swift`; source fixture generator |
| A date has no readings | Compare the source-shaped null title and empty reference array. Keep the repository's missing entry distinct from an empty successful entry. Handle nil and JSON null explicitly. | `ContentFixtureComparison.swift` |
| A comparison fixture is incomplete | Reject missing or empty required case sets. Report exact expected and observed counts. | `ContentFixtureComparison.swift` |

Source may run a bounded host comparison to find draft fixture-shape errors. Label it preliminary source evidence. Main must run the stable code and exact fixtures in the simulator before runtime acceptance. A source build or host comparison does not close L13–L16 or Gate C.
