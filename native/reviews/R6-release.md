# R6 release: 2.0.1 (25), submitted for App Review

Submitted 12 October 2026, about 11:40 AM. Status: Waiting for Review. Release: manual.

Before this submission, 2.0.0 (24) was approved (Pending Developer Release). The owner chose to release 2.0.0 (24) first and ship the content fix as 2.0.1. 2.0.0 is Ready for Distribution.

## What changed since build 24
Content rule from the owner: show only direct quotations of an existing source (Scripture, the Catechism, popes, saints, Doctors of the Church, traditional prayers). Remove everything the app wrote itself.

- Prayers (`src/services/companion/prayers.ts`): removed the four app-written prayers (morning offering, evening examen, for someone suffering, anxious moment). `morning` is now the Apostleship of Prayer Morning Offering. `evening` is now Night Prayer (Compline collect, Bute 1879). Added a "Prayers of the saints" category and new traditional prayers. 12 prayers became 28. Each prayer names its source and translation.
- Novenas: the 21 "expanded" novenas were app-written and are removed. The six remaining novenas now match their stated sources word for word (source placeholders such as "(make your request here)" are kept). Added the Divine Mercy novena from the Diary of St. Faustina, 476. App-written "about" text is removed. 27 novenas became 7.
- Teachings: the summary is now the verbatim CCC paragraph (1324, 1440, 971, 1505, 2708). The reflection questions are removed.
- Confession guide: steps quote CCC 1454, 1422, 1456, 1451, 1449. The examination is the CCC traditional formula of the Ten Commandments, Matthew 22:37, 39, and the Beatitudes (Matthew 5:3–10, WEB-CE).
- Lectio divina: step text is Verbum Domini 87 (Benedict XVI).
- Rosary: the "fruit of the mystery" lines are removed. Set descriptions quote Rosarium Virginis Mariae 20–23. The Servite prayers match their sources. The app-written completion blessings and the "Pause and bring this mystery before God" line are removed.
- Calendar: the app-written Sunday reading guides and reflection prompts are removed.
- Settings credit line updated.

Kept on purpose: headings, button labels, and brand lines such as "A little closer to God."

Text verification: every new or changed quotation was checked against a fetched source page (vatican.va, EWTN, Raccolta 1910 and Lasance 1904 scans on archive.org, CCEL, Gutenberg, the Shrine of Fatima, littleflower.org). Not used because a reliable source was not found: the St. Gertrude prayer, the St. Richard of Chichester prayer, Hopkins' "Adoro te devote".

## Build notes
- A clean checkout also needs `python3 scripts/native/release/prepare-release-resources.py`. That script reads `ios/LockBible/...`. `expo prebuild -p ios` now makes `ios/John11`, so a temporary link `ios/LockBible -> John11` was used. The generated `ios/` folder was then removed.
- Expected catalog counts are now 7 novenas, 28 prayers, 5 teachings (`stage-resources.py`, `ContentModels.swift`).

## Checks
- Jest (novena, rosary, companion): 47 passed. `tsc` reports no errors under `src/`.
- JohnCore `swift test`: 35 passed.
- UI tests on iPhone 17 Pro Max (`3F2B0C7C`): CalendarBoundaryUITests (3), ContentFlowUITests (8 passed, 4 skipped by design), LectioTimerUITests (1) passed. testL18 passed after its expected last-step title was updated to "Absolution".
- Archive: "Uploaded John Update", EXPORT SUCCEEDED. Catalog in the archive: 7 novenas, 28 prayers.

## Not done
- The legacy React Native screens under `src/screens` still contain the old confession questions in `src/services/companion/confession.ts`. They are not in the native app.
