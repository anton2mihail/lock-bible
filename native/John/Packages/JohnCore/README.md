# JohnCore startup and storage API

`NativeStateStore` owns the native state envelope and the first import from MMKV. Create one store for the app process. Pass the Application Support URL, the original `Documents/SQLite/user-library.db` URL, the staged `App` resource root, and the app-only `LegacyMMKVReading` adapter.

Call `loadOrImport()` before feature views read saved state. It returns `StartupState`. Check `nativeStateCapability` and `libraryCapability` separately. A library failure does not remove safe native state. The first import creates the schema-1 library only when no legacy MMKV files prove this is an update and no SQLite recovery sidecars exist. If a supported library already exists, the store makes and validates a new consistent backup before it commits the first state envelope.

Call `update(_:)` with one `NativeStateMutation` for each user action. It applies the action to the actor's latest state. It returns the durable envelope with its new revision. Do not pass a complete UI snapshot. Use the individual reader mutations when a user changes text size, line spacing, typeface, or layout. A failed state replacement after the primary rename blocks later writes in this process and reports an uncertain result.

`SQLiteLibraryRepository` reads and writes the original schema-1 database. Its transactions are synchronous. It does not create a missing database. The startup store owns fresh schema creation. The repository validates a new backup before its first library write. Keep `recoveryDirectory` under `Library/Application Support/John/recovery`.

In Debug, the store accepts a checkpoint callback and a failure injector. Checkpoints include `beforeStaging`, `beforeDurableCommit`, `afterPrimaryRename`, `afterDurableCommit`, `afterFreshLibraryTransaction`, `beforeFreshLibraryPublish`, and `afterFreshLibraryPublish`. The failure injector can return `true` for `afterPrimaryRename` to test an uncertain replacement. If startup recovers from the previous envelope after it finds a damaged primary, the first update saves the damaged bytes under a unique file in `recovery` before it replaces the primary. Do not log saved values.

The app-only MMKV adapter is in `../../LegacyAdapter/`. Link it only to the app target. Do not link MMKV or JSI to JohnCore or the widget. Main Luna owns Xcode project integration and all simulator runs.
