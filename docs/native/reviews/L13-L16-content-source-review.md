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

## Follow-up checkpoint

The revised Toronto host report passes 13 checks with no mismatches. It reports 858 reading reference entries, 324 transition steps, seven callback steps, and 893 Today cases. The date parser now uses ASCII digits and matches the unusual source date probes. Source supplied explicit callback input and handled missing-reading values.

The malformed-input check uses a comparator-only raw normalizer. It does not verify a production selector. Treat that result as source-shape evidence. The other 12 checks support the content contract. Do not add a second production raw normalizer for this check.

Sol permits parallel content implementation under `Parallel-content-UI-contract.md`. Final production source hashes and SDK selection remain required. The draft simulator log has a MacOSX sysroot warning. Source must report or correct the SDK command before SDK acceptance. Feature runtime and visual parity remain open.

## Bounded promotion acceptance

Source corrected the SDK command to build only `ContentPreparation`, with `--triple arm64-apple-ios26.0-simulator` and the explicit iPhoneSimulator26.5 SDK. The revised target-only log passes without the sysroot warning. Sol accepts this SDK build for preparation.

Sol permits production promotion of `ContentModels.swift` at SHA-256 `5bfb8a6e59b214f7c7b0899011310fbf0c12d371cc0aa0ed38341c233bb2be0b` and `CompanionRepository.swift` at `45a0a645fd5e944eb875a1b670be0ebc53182309a4f98a407904fb8c099708be`. Remove the preparation-only import of JohnCore when these files enter that same module. Keep the comparator outside production package sources. Source must send the final promoted hashes and scoped commit before Main's next shared build.

The repository includes a date-based prayer selector. It derives the local hour with the supplied time zone and calls the hour-based selector. The malformed-input result is now labeled `sourceFixture.malformedInputExpected`. It remains source fixture evidence. The latest saved report before the final relabel has 900 Today observations, including the new date-edge checks. Source must align the final report with the comparator.

The Core and view implementation can proceed while the corrected Reader UI check runs. No content UI parity or simulator selector acceptance is claimed by this decision.

## Production commit boundary

Source committed the three Core files at `d1b045a2f926af16eb7aae137ba42b338bc318cc`. Sol accepts the promoted models and repository for implementation. Their hashes are `3d52aced1a9618bc55ca33671466954c5f9d48f7e21b3c35df903b4b7bb92804` and `fc12082addbfcdd0dc1757449e8b8da7fdf43e932ef1bbd4061fea27b438d689`.

The citation helper at `4bf433cd35f6fc1afcbeed2c627a1c5583bd919519130ec92eb77e60a810e89b` remains provisional. The preparation copy has the corrected ASCII-digit pattern, but the committed copy still has `\d`. The eight-case host comparison calls the preparation module's helper. It does not yet check the committed helper. Source must fix that production pattern in a separate small commit and call the JohnCore symbol in the comparison.

The current package can build for Reader, Search, and library checks. New content views can proceed. Do not hold these tasks for the narrow citation follow-up. Citation runtime and full content acceptance remain open.
