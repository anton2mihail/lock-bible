# Calendar boundary runtime review

Date: 6 October 2026.
Reviewer: GPT-6.1 Sol.
Verdict: accept the three bounded simulator journeys. Full calendar visual parity remains open.

## Result and source

The actual result bundle reports three passes, no failures, and 69.089 seconds of test time. Sol read its summary, test tree, and Joel/Esther activity records. Evidence is `build/native-evidence/L20/calendar-boundaries-metric-02/run.txt`. Result bundle: `build/native-evidence/L04/DerivedData-gate-a-ui-arm64-01/Logs/Test/Test-John Development-2026.10.06_05-07-41--0400.xcresult`.

The test source hash is `f5a020ae968d1f499e10b07eefcd76f9225bf514afd7f7e5d9d98ec742854d44`. It uses the real Today cards and reading rows. Destination checks require the exact page title and identifier. The previous run stopped at a case-sensitive date predicate. This corrected run completes the routes. That earlier failure does not prove a calendar product fault.

## Accepted bounds

- On 13 September 2026 in Toronto, 16:59 opens Morning offering. At 17:00, it opens Evening examen. Each launch uses its declared DEBUG date and time zone.
- On 1 January 2028, Today opens Daily readings. The page shows `Jan 1, 2028` and the exact message that the reading references are not in the offline library.
- On 11 October 2025, the real `Joel 4:12-21` reading row opens Joel 3. Its original reference remains visible.
- On 26 February 2026, the real `Esther C:12, 14-16, 23-25` row opens Esther 4. Its original reference remains visible.
- Both context routes show `WEB-CE · Complete chapter`.

## Provenance and limits

Device: iPhone 17 Pro simulator, iOS 26.5, ID `37D1870B-F16D-488A-8F20-959201F970D9`. Bundle: `com.nrsv.verse.dev`. Builder PID6366; runner PID6463. The run record lists app launches6512, 6606, 6850, and6930; the last live app PID is unavailable. The test contains five launches. The listed process records do not identify every launch separately.

Product and installed executable hashes match `3ce06ddc08433b83ac227a5fa81233fa0b7afcf70be4546ff5eabf10dee52d08`. Debug dylib hashes match `eda4e03e6e2f3647e3ff17000c10313c359e912348f4c664bf5d64da7f6ba918`. Sol independently hashed both product files. The xctestrun hash is `5b962ea07b42fc96b0e035b9213b5ddb86d83fa2378215532b8294c5de651e40`.

The run record's initial date summary omitted the two citation dates. Main must correct that summary and preserve the successful label log without another run. No new persistent-data or pixel-parity claim follows from these tests. Invalid citation fallback, arbitrary dates and zones, real notification delivery, matched old/native images, and deployment-floor runtime remain separate checks.
