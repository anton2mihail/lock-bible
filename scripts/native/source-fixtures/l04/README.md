# L04 source fixtures and app runner

This folder contains synthetic inputs for the L04 import scenarios. The fixtures do not contain user data. The host preparation script builds MMKV Core from the pinned source and writes new fixture files. It does not read or change the app-created legacy fixture.

## Requirements

Install the repository dependencies with the existing Bun lockfile. Use Xcode command-line tools. The host fixture builder needs the macOS SDK and `clang++` with C++20 support. The app runner needs the app-only legacy adapter and JohnCore.

## Create fixture inputs

Pass a new output path. The script stops if the path already exists.

```sh
bash scripts/native/source-fixtures/l04/prepare-fixtures.sh build/native-evidence/L04/fixtures/gate-a-synthetic
```

The default output is `build/native-evidence/L04/fixtures/gate-a-synthetic`. The manifest records hashes and byte counts. It records 44 legacy keys, 27 novena values, a schema-1 database, and a committed WAL. The database has two bookmark rows, one highlight row, and one note row. The fixture also has unsupported and damaged database files and three MMKV damage cases.

The script writes the input below `input/`. It writes the expected normalized state at `expected-state.json`. Do not use fixture files as app resource files.

## Add the runner to a debug app build

Add `L04ScenarioRunner.swift` to the John app target in a DEBUG-only source phase. Do not add a unit-test target. The runner uses JohnCore and receives the app-only MMKV reader from the app.

Call one scenario at a time. Give every run a new output directory. For example:

```swift
let fixtureRoot = URL(fileURLWithPath: "/absolute/path/build/native-evidence/L04/fixtures/gate-a-synthetic")
let outputRoot = URL(fileURLWithPath: "/absolute/path/build/native-evidence/L04/runs/valid-import")
let result = try await L04ScenarioRunner.run(
    .validLegacyImport,
    fixtureRoot: fixtureRoot,
    outputRoot: outputRoot,
    roots: runtimeResourceRoots,
    legacyReaderFactory: { LegacyMMKVReader(rootURL: $0) }
)
try L04ScenarioRunner.write(result, to: outputRoot)
```

For each scenario, use a different new output directory. The runner copies synthetic database files into that output directory. It does not change the fixture source. It writes `scenario-result.json` with pass status, revision, capability messages, row counts, and hashes.

Available scenarios are `validLegacyImport`, `invalidLegacyField`, `concurrentStartupAndMutation`, `freshInstall`, `freshBootstrapFailureThenRetry`, `missingLibraryWithState`, `unsupportedLibrary`, `damagedLibrary`, `damagedMMKVData`, `damagedMMKVCRC`, `wrongMMKVCRC`, `backupFailureThenRetry`, and `afterRenameFailure`.

For `afterRenameFailure`, the runner creates revision 1 first. Then pass a failure injector that returns `true` for `.afterPrimaryRename`. It checks the failed first mutation, blocked next mutation, and revision 2 after a new store reads the durable file. For checkpoint interruption cases, pass a checkpoint closure. The app runner does not kill or relaunch the app. Main owns those simulator actions and records each checkpoint result.

`freshInstall` checks that the database file exists, schema inspection returns schema 1 and zero row counts, and a second load returns the same revision. The fresh setup path performs its SQLite integrity check before it publishes the database. Schema inspection checks schema fields and row counts. It does not run `integrity_check`.

## Verify the runner source

Build the package first, then type-check the runner with the simulator SDK:

```sh
swift build --package-path native/John/Packages/JohnCore
xcrun --sdk iphonesimulator swiftc -typecheck \
  -target arm64-apple-ios26.0-simulator \
  -I native/John/Packages/JohnCore/.build/arm64-apple-ios-simulator/debug/Modules \
  scripts/native/source-fixtures/l04/L04ScenarioRunner.swift
```

This source check does not prove app integration or simulator behavior. Main owns those checks.
