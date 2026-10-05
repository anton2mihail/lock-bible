# L00 source fixtures

These commands export source data. Run them from the repository root:

```sh
bunx tsx scripts/native/source-fixtures/catalog-fixtures.ts
bunx tsx scripts/native/source-fixtures/rotation-fixtures.ts
```

The baseline source commit is `b64e1fc3cfc6a78f508b41d74b71dddfe9ff7697`. The scripts write JSON under `build/native-evidence/L00-source/`. They add no dependency. They do not copy either SQLite database.

`catalog-fixtures.json` preserves source values for the three Bible editions, their ordered books and widget pools, daily readings, celebrations, works catalog, novenas, prayer library, teachings, Rosary sets, Seven Sorrows, full guide sessions with group labels, guide steps, and media entries. Source strings stay unchanged. The fixture records hashes for its input files.

`rotation-fixtures.json` calls the existing rotation functions. It covers all three editions, all three scopes, all eight cadence values, and eleven clock cases. The cases include a negative epoch slot, both daylight-saving transitions in Toronto, Kathmandu's 5:45 offset, and one instant in Los Angeles and Kathmandu. The output contains 792 selections, the selected verse, pool index, local offset, and next rotation instant. Pool reference order and input hashes are recorded.

The expected values are source-derived. They do not prove Swift parity or simulator behavior. Native production resource schema remains undecided.
