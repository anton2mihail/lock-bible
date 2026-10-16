# Calendar boundary UI checks

`CalendarBoundaryUITests.swift` has three short UI journeys. Main owns project membership, task-only seed creation, and simulator runs.

The tests use the existing `-L14FeatureDate` and `-L14FeatureTimeZone` launch arguments. They do not change the device clock or time zone. Each launch uses `America/Toronto` and opens routes through visible controls.

1. `testPrayerChoiceOnBothSidesOfLocalSeventeenHundred` launches at `2026-09-13T20:59:00Z` and `2026-09-13T21:00:00Z`. These instants are 16:59 and 17:00 local. It checks the Morning Offering and Night Prayer choices, then opens each prayer. This checks two fixed launches. It does not check a live clock transition.
2. `testOutOfCoverageDateShowsOfflineMissingReadings` launches at local noon on `2028-01-01`. The source calendar ends on `2027-12-31`. It opens Today’s readings and checks the exact offline missing-date message. It does not open the official website.
3. `testJoelAndEstherCitationsKeepOriginalIdentityAndMapChapter` launches for `2025-10-11` and `2026-02-26`. It opens `Joel 4:12-21` and `Esther C:12, 14-16, 23-25` from the visible reading list. It checks the original reading-reference subtitle, the whole-chapter target (`Joel 3` or `Esther 4`), and the WEB-CE whole-chapter notice.

Use a fresh task-only development install with the bundled calendar resources. The tests need Today to start without a saved location that hides its root controls. These journeys only read data. They do not require saved rows, favorites, reflections, or novena progress. Main must record the app build and exact test seed with the result.

The source contract reports 858 reading dates from `2025-08-25` through `2027-12-31`. The out-of-coverage case uses `2028-01-01`. The source fixture hash and native runtime result must be recorded separately. Invalid citation has no visible entry in the current UI, so this file does not claim that case.
