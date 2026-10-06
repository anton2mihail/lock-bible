# Calendar and novena source fixtures

This generator exports the current calendar and novena behavior from the TypeScript source. It does not export Bible text or novena prayer text. The calendar output contains dates, labels, reading references, coverage, season results, and local-time cases. The novena output contains progress state changes for every catalog ID.

Run the generator from the repository root. It creates parent folders when needed.

```sh
bun scripts/native/source-fixtures/content/calendar-novena-fixtures.ts \
  build/native-evidence/L13-content/calendar-novena-toronto.json America/Toronto
bun scripts/native/source-fixtures/content/calendar-novena-fixtures.ts \
  build/native-evidence/L13-content/calendar-novena-utc.json UTC
```

The output records the time zone, UTC instants, local dates, and offset minutes. The Toronto cases include spring and fall daylight-saving transitions. The output also records SHA-256 hashes for the selector, catalog, progress model, screen, and source data files.

The calendar map preserves each source date and each reading label and reference. The selector cases cover daily and Sunday defaults, valid and invalid dates, and a date outside calendar coverage. The novena cases preserve the source catalog IDs and storage keys. They call the source `normalizeNovenaProgress` function for initial state, intention change, each of nine completion steps, reset, and malformed-state normalization. The source screen does not export its select, complete, or reset callbacks. The `callbackSequence` field maps those exact `NovenaScreen.tsx` callbacks. It checks selecting day 5, completing it, repeating an already completed day, selecting and completing day 9, and resetting. The JSON labels this source mapping. It does not claim that these callbacks are direct function calls.

The JSON output is source evidence. It does not prove native behavior. Keep the generated JSON under ignored `build/native-evidence/`.
