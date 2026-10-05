# JohnCore

JohnCore is the Foundation-only content and storage package for the native app. It uses Swift 6 and supports iOS 26.0. The app target owns bundle lookup and passes resource URLs to the package.

## Build

Run these commands from the repository root:

```sh
cd native/John/Packages/JohnCore
swift build
swift build --triple arm64-apple-ios26.0-simulator --sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.5.sdk
```

The second command compiles for the simulator SDK. It does not launch a simulator.

## Public interfaces

- `ResourceRoots` receives the staged `App` directory URL and an optional `Widget` directory URL.
- `BundledBibleRepository` implements `BibleRepository`. It reads edition metadata and manifests, then reads one book file for a requested chapter. It caches only metadata and manifests.
- `SQLiteWorksRepository` implements `WorksRepository`. It reads the small catalog without opening the database. It reads one section row on request and validates its JSON paragraph array.
- `IndexedRotationRepository` implements `RotationRepository`. It maps the edition `.dat` file, reads the index maps, and decodes one requested record. Use `resourceRoot: .app` for `App/Rotation/`. Use `resourceRoot: .widget` for flat files under the staged `Widget/` directory. Both modes use the same parser.
- `SystemCoreClock` implements `CoreClock`. Callers can inject a fixed clock in application models.
- `SQLiteLibraryBoundary` provides schema-1 inspection and a consistent backup to a new path. It does not change library rows or migrate the database.

The app should resolve its bundle directory and then construct `ResourceRoots(app:widget:)`. The app should call repository methods from its feature model. The repositories own their SQLite handles and do not return handles or statements.

## Resource paths

The `app` URL points to the staged `App` directory. Bible paths use `Bible/<edition>/`. Works resources use `Catalogs/works-catalog.json` and `Databases/works.db`. Rotation resources use `Rotation/<edition>.dat`, `.offsets`, `.ot`, `.nt`, and `.meta.json`. The optional `widget` URL points to the staged `Widget` directory.

The staging manifest and target lists are under `build/native-evidence/L03/`. See `scripts/native/resources/README.md` for staging and verification commands.

## Limits

This package does not implement search, writable library operations, MMKV import, native state envelopes, UI, project configuration, or simulator scenario controls. A failed SQLite backup can leave a partial destination. A retry must use a new attempt path. Package build success does not prove runtime behavior or content parity. Main Luna owns project integration and simulator checks.
