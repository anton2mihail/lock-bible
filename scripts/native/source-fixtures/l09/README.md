# L09 source search fixtures

This fixture exports expected results from the current TypeScript search code. It does not change or test the app.

## Generate the fixture

Install the repository dependencies with `bun install --frozen-lockfile` if they are not installed. Keep `assets/bible/bible-search.db` in place. Do not copy or modify this database.

Run this command from the repository root:

```sh
bun scripts/native/source-fixtures/l09/search-fixtures.ts build/native-evidence/L09/source-preparation/search-fixtures.json
```

The script creates the output directory. It opens the search database in read-only mode. It writes JSON results for reference parsing, edition and testament scopes, FTS queries, correction behavior, and SQL calls. It records SHA-256 hashes for the parser, search service, search builder, fixture generator, database, and edition manifests and metadata.

## Fixture coverage

The fixture contains exact source outputs for 39 search requests and 19 parsed-reference requests. It includes all three editions and all three search scopes. It includes reversed numeric verse ranges, suffix numeric casts, aliases, invalid chapters, default and requested limits, FTS ordering, quoted phrases, typo correction after zero original results, and no-match correction. Parser cases cover fuzzy-name lengths below 4, at 4, at 7, and at 8 characters. They also compare composed and decomposed accented forms through source normalization.

The `sourceRules` field records the source behavior used by the native comparison. Correction examines up to 300 same-first-letter vocabulary entries. It uses edit distance over UTF-16 code units. Quoted input skips correction. Search results use the source SQL order. The `sqlTrace` values show the prepared SQL text and bound arguments for each request.

## Limits

These values are source-generated expectations. They are not simulator results. They do not prove that the native parser or SQLite build returns the same values. The fixture includes source verse text, so keep it in ignored build evidence and do not add it to the app bundle.
