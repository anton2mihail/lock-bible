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

The script writes the input below `input/`. It writes the expected normalized state at `expected-state.json`. Do not use fixture files as app resource files. The current generator makes damaged MMKV files by truncating data below its four-byte length header, truncating the CRC file below `MMKVMetaInfo`, and flipping a byte in the `m_crcDigest` field. The manifest records the active length, metadata size, corruption offset, sizes, and hashes. Older fixture trees use changes in unused padding. Keep them as valid-padding controls. Use a newly generated tree for corruption checks.

For the unsupported-schema case, use a fresh fixture tree from the current generator. The current schema-77 file has no SHM sidecar. The earlier `gate-a-synthetic` tree has a schema-77 database plus an orphan SHM file. Keep that earlier tree as the separate orphan-SHM diagnostic input. Do not use it to test the expected `unsupportedSchema(77)` result.

## Add the runner to a debug app build

Add `L04ScenarioRunner.swift` to the John app target in a DEBUG-only source phase. Do not add a unit-test target. The runner uses JohnCore and receives the app-only MMKV reader from the app.

Copy the fixture inputs into the app container after install. Pass `-L04FixtureRelativePath` and `-L04OutputRelativePath` as process arguments. Both values must be relative to the app's own Documents directory. The app must derive the paths from `NSHomeDirectory()`. It must reject a path that escapes Documents. Give every run a new output path. For example:

```swift
let documents = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    .appendingPathComponent("Documents", isDirectory: true).standardizedFileURL
let fixtureRoot = documents.appendingPathComponent("L04Fixtures/gate-a-synthetic", isDirectory: true)
let outputRoot = documents.appendingPathComponent("L04Outputs/valid-import-01", isDirectory: true)
let result = try await L04ScenarioRunner.runRecording(
    .validLegacyImport,
    fixtureRoot: fixtureRoot,
    outputRoot: outputRoot,
    roots: runtimeResourceRoots,
    legacyReaderFactory: { LegacyMMKVReader(rootURL: $0) }
)
```

Use a new suffix for each output path. Do not use a host filesystem path as an app launch argument. The host can copy the fixture files into the container that it discovers after install.

`runRecording` writes one `scenario-result.json`. It records checkpoint names and catches thrown errors. It does not catch a process crash. Main must record process exit status and console output.

For each scenario, use a different new output directory. The runner copies synthetic database files into that output directory. It does not change the fixture source. It writes `scenario-result.json` with pass status, revision, capability messages, row counts, and hashes.

Available scenarios are `validLegacyImport`, `invalidLegacyField`, `concurrentStartupAndMutation`, `freshInstall`, `freshBootstrapFailureThenRetry`, `missingLibraryWithState`, `unsupportedLibrary`, `damagedLibrary`, `damagedMMKVData`, `damagedMMKVCRC`, `wrongMMKVCRC`, `backupFailureThenRetry`, and `afterRenameFailure`.

For `afterRenameFailure`, the runner creates revision 1 first. Then pass a failure injector that returns `true` for `.afterPrimaryRename`. It checks the failed first mutation, blocked next mutation, and revision 2 after a new store reads the durable file. For checkpoint interruption cases, pass a checkpoint closure. The app runner does not kill or relaunch the app. Main owns those simulator actions and records each checkpoint result.

`L04RecoveryScenarios` provides three copied-root checks: unsupported envelope, damaged primary with valid previous file, and both state files damaged. Each run needs a new output path. It checks that unsupported or damaged bytes stay unchanged. It checks that a recovered update archives the damaged primary before replacement. `resumeExistingRoot` performs one bounded read of a test-owned root after Main relaunches the app when a state file already exists. `resumeBeforeCommit` performs one import retry after Main relaunches with no state files, the copied library, and the injected reader. Each helper writes a result file in a separate new output path. Main must kill and relaunch the app. These helpers do not simulate process termination.

`freshInstall` checks that the database file exists, schema inspection returns schema 1 and zero row counts, and a new store actor reads the same revision. The result records a post-run inspection error when inspection fails. This is an in-process restart check. It does not replace Main's app terminate/relaunch check. Fresh setup runs `integrity_check` before publication. Later schema inspection checks schema fields and row counts. It does not run `integrity_check`.

For the SQLite open diagnostic, copy an existing fixture database into the process-owned Documents test folder. Call `SQLiteOpenProbe.run(url: copiedDatabase, mode: .readOnly)`. Call `.deleteModeControl` only with a new control path under the output folder. The control probe rejects an existing file. Save both `SQLiteOpenProbeResult` values. Do not pass the live library.

## Run repository checks

Create the small Bible expected-output file and use the accepted source rotation fixture:

```sh
bun scripts/native/source-fixtures/l04/bible-repository-fixtures.ts \
  build/native-evidence/L04/repository/bible-fixtures.json
```

The Bible generator exports nine exact source cases. It covers John 1, Psalm 23, and Song of Songs 1 for all three editions. It records manifest and book-file hashes. It does not copy a complete Bible edition.

Add `L04RepositoryRunner.swift` to the DEBUG-only app source phase. Call its async `run` method after Main copies all inputs into the app container. Use these arguments:

```swift
try await L04RepositoryRunner.run(
    roots: runtimeResourceRoots,
    databaseURL: outputRoot.appendingPathComponent("closed-source/user-library.db"),
    expectedClosedSourceSHA256: "8d78ca482d4720783ecabfcd17f88e72d5d2393eabc358ef03c5398f2cd43ed9",
    recoveryDirectory: outputRoot.appendingPathComponent("recovery", isDirectory: true),
    bibleFixtureURL: documents.appendingPathComponent("L04Fixtures/bible-fixtures.json"),
    rotationFixtureURL: documents.appendingPathComponent("L04Fixtures/rotation-fixtures.json"),
    unsupportedSchemaURL: documents.appendingPathComponent("L04Fixtures/schema77/user-library.db"),
    expectedUnsupportedSchemaSHA256: "bac7204a9fac7818b4ae8b8c51692827a9b0af80cbc7b095d3ea643c82f60605",
    damagedDatabaseURL: documents.appendingPathComponent("L04Fixtures/damaged/user-library.db"),
    expectedDamagedDatabaseSHA256: "a0e6cc8d5e829bc4926a3bef982be9c7449325c99f34894681e208b06dd44a8a",
    outputURL: outputRoot.appendingPathComponent("repository-result.json")
)
```

Main must copy the closed schema-1 file from `build/native-evidence/L04/private-copy-proof-03/closed-source/user-library.db`. Its SHA-256 is `8d78ca482d4720783ecabfcd17f88e72d5d2393eabc358ef03c5398f2cd43ed9`. The source proof is `build/native-evidence/L04/private-copy-proof-03/proof.json`. Keep that source file unchanged. Copy the schema-77 database from a clean fixture tree without sidecars. Its expected hash is `bac7204a9fac7818b4ae8b8c51692827a9b0af80cbc7b095d3ea643c82f60605`. Copy only the 49-byte damaged main file for the closed-file check. Do not copy its synthetic WAL sidecar. Its expected hash is `a0e6cc8d5e829bc4926a3bef982be9c7449325c99f34894681e208b06dd44a8a`. The runner rejects other hashes and sidecars. It compares each input again after inspection.

The runner checks exact Bible chapter and passage results. It checks all 792 rotation rows against app and widget indexed resources. It checks selected records and rotation math. It reads the closed database, then writes only its app-container copy. It checks the original note, the new note, the validated pre-write backup rows, the source hashes, and owned private-read workspace cleanup. It creates a small Works database under the new output tree. That database covers a real zlib BLOB decode, a TEXT JSON decode, invalid TEXT, oversized TEXT, invalid zlib data, and a missing row. It does not modify the bundled Works database.

The result JSON records the SQLite and zlib versions from the app process. The runner is DEBUG-only. It does not control simulator installation, launch, or process termination. Main owns those actions.

## Verify the runner source

Build JohnCore for host and iOS Simulator. Then type-check the app runner against the simulator module:

```sh
swift build --package-path native/John/Packages/JohnCore
xcodebuild -project native/John/John.xcodeproj \
  -scheme JohnCore \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/native-evidence/L04/runner-clean-sdk/ios \
  build
xcrun --sdk iphonesimulator swiftc -typecheck \
  -D DEBUG \
  -swift-version 6 \
  -target arm64-apple-ios26.0-simulator \
  -I build/native-evidence/L04/runner-clean-sdk/ios/Build/Products/Debug-iphonesimulator \
  -Xcc -fmodule-map-file=native/John/Packages/JohnCore/Sources/CSQLite/module.modulemap \
  -Xcc -fmodule-map-file=native/John/Packages/JohnCore/Sources/CZlib/module.modulemap \
  -Xcc -Inative/John/Packages/JohnCore/Sources/CSQLite \
  -Xcc -Inative/John/Packages/JohnCore/Sources/CZlib \
  scripts/native/source-fixtures/l04/L04ScenarioRunner.swift \
  scripts/native/source-fixtures/l04/L04RecoveryScenarios.swift \
  scripts/native/source-fixtures/l04/L04RepositoryRunner.swift
```

The simulator type-check loads JohnCore from the fresh `Debug-iphonesimulator` product path. The two module maps support the Core C targets. This check does not launch a simulator.

This source check does not prove app integration or simulator behavior. Main owns those checks.
