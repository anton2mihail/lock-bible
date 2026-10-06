# Today source contract fixture

This fixture records current TypeScript outputs for the Today and readings screens. It calls the source calendar selectors, Rosary weekday selector, novena catalog, and novena progress normalizer. It uses synthetic novena progress. It does not read app storage or change app data.

Run from the repository root with the target local time zone:

```sh
TZ=America/Toronto bun scripts/native/source-fixtures/content/today-source-contract.ts build/native-evidence/L10-L11/today-source-contract.json
```

The output records all 858 dates in the current offline readings file, with exact titles and reading references. It records the internal coverage gap 2025-09-18. It also records local Sunday selection, prayer choices at 16:59 and 17:00 on daylight-saving and ordinary dates, Rosary choices across all seven local weekdays, and a local midnight transition.

The output records missing-reading behavior before, inside, and after the coverage range. Today uses the celebration title when readings are missing. It uses the season title when readings and celebrations are both missing. The readings screen shows its offline message when readings are missing.

The novena output preserves catalog order. It calls `normalizeNovenaProgress` with synthetic progress states. It records the Today screen filter and next-day subtitle rules. It maps the screen's catalog iteration and filter. It does not call `loadNovenaProgress`, because that function reads private app storage.

The output contains SHA-256 hashes for the screen sources, selectors, source tests, catalog data, and generator. I ran the generator twice with the same time zone. Both output files had SHA-256 `82518ffd6877290ce0c4c58fcedadd4feb592d8a6cd7f9f0562bcc147ab28545`. This is source evidence. It is not simulator evidence. Keep the JSON in ignored `build/native-evidence/L10-L11/`.

## Main simulator handoff

Compare the native Today screen with the fixture values for the process local time zone. Check the 16:59 and 17:00 prayer choices. Check that Sunday returns the same date. Check the Rosary selector at each local weekday and at midnight. Check the finite coverage dates, the internal gap, and the missing-reading title fallbacks. Check the active novena order and subtitles with the fixture's synthetic progress states.

Keep the active translation ID when the Today verse opens in context. Do not use this fixture as a request to add a test target.
