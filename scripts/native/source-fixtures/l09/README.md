# L09 source search fixtures

This fixture exports expected results from the current TypeScript search code. It does not change or test the app.

## Generate the fixture

Install the repository dependencies with `bun install --frozen-lockfile` if they are not installed. Keep `assets/bible/bible-search.db` in place. Do not copy or modify this database.

Run this command from the repository root:

```sh
bun scripts/native/source-fixtures/l09/search-fixtures.ts build/native-evidence/L09/source-preparation/search-fixtures-final.json
```

The script creates the output directory. It opens the search database in read-only mode. It writes JSON results for reference parsing, edition and testament scopes, FTS queries, correction behavior, and SQL calls. It records SHA-256 hashes for the parser, search service, search builder, fixture generator, database, and edition manifests and metadata.

## Fixture coverage

The fixture contains exact source outputs for 41 search requests and 19 parsed-reference requests. It includes all three editions and all three search scopes. It includes reversed numeric verse ranges, suffix numeric casts, aliases, invalid chapters, default and requested limits, FTS ordering, quoted phrases, typo correction after zero original results, and no-match correction. Dotted text and phrase cases verify that punctuation splits search tokens. Parser cases cover fuzzy-name lengths below 4, at 4, at 7, and at 8 characters. They also compare composed and decomposed accented forms through source normalization.

The `sourceRules` field records the source behavior used by the native comparison. Correction examines up to 300 same-first-letter vocabulary entries. It uses edit distance over UTF-16 code units. Quoted input skips correction. Search results use the source SQL order. The `sqlTrace` values show the prepared SQL text and bound arguments for each request.

## Native DEBUG comparison

`L09FixtureComparison.swift` provides `L09FixtureComparison.run(fixtureURL:appRoot:databaseURL:outputURL:)`. Add this file to the app target as a DEBUG-only source. Call it from Main's existing scenario runner. Pass the staged `App` directory, the bundled `bible-search.db`, and a new output JSON path. The function checks all 41 searches, 57 reference results, four normalization probes, three UTF-16 probes, and six FTS probes. The FTS probes include quoted input with U+2028 and U+2029. It writes a structured report with every mismatch and actual result. It does not change the app UI or request cancellation.

Keep the fixture JSON in ignored evidence. Do not add verse text from the fixture to the app bundle. Run the source command above before the simulator comparison. Record the fixture hash and the two Core source hashes with the simulator output.

## Local checks

Build JohnCore for the host and the iOS Simulator SDK with separate scratch paths:

```sh
swift build --package-path native/John/Packages/JohnCore --scratch-path build/native-evidence/L09/core-check/host
swift build --package-path native/John/Packages/JohnCore --scratch-path build/native-evidence/L09/core-check/ios-simulator-sdk --triple arm64-apple-ios26.0-simulator --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)"
```

Type-check the DEBUG comparison against that simulator module:

```sh
xcrun --sdk iphonesimulator swiftc -typecheck -D DEBUG -swift-version 6 -target arm64-apple-ios26.0-simulator -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -I build/native-evidence/L09/core-check/ios-simulator-sdk/arm64-apple-ios-simulator/debug/Modules -I native/John/Packages/JohnCore/Sources/CSQLite -I native/John/Packages/JohnCore/Sources/CZlib -Xcc -fmodule-map-file=native/John/Packages/JohnCore/Sources/CSQLite/module.modulemap -Xcc -fmodule-map-file=native/John/Packages/JohnCore/Sources/CZlib/module.modulemap scripts/native/source-fixtures/l09/L09FixtureComparison.swift
```

## Limits

These values are source-generated expectations. They are not simulator results. They do not prove that the native parser or SQLite build returns the same values. The fixture includes source verse text, so keep it in ignored build evidence and do not add it to the app bundle.
