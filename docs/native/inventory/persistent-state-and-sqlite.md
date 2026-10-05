# L00 persistent state inventory

Baseline commit: `b64e1fc3cfc6a78f508b41d74b71dddfe9ff7697`. Runtime paths and values were not inspected.

The default MMKV instance is created with `new MMKV()` in `src/utils/storage/index.ts`. The source uses no explicit ID, encryption key, custom path, or group ID. `react-native-mmkv` is 3.3.3. Its MMKV Core is v2.0.0. The wrapper reads the `AppGroup` field from `Info.plist` when `path` is absent. The app declares App Group `group.com.nrsv.verse`, but the generated app Info.plist value and actual baseline file path remain unobserved.

| Key | Stored value | Loader normalization |
|---|---|---|
| `ignite.themeScheme` | raw string via useMMKVString | No normalization is shown in theme context. Invalid/system handling must be checked in runtime. |
| `bible.translationId` | JSON string | Only IDs in TRANSLATIONS are accepted. Otherwise default is `web-ce`. |
| `bible.rotationInterval` | JSON number | Only 10, 15, 30, 60, 180, 360, 720, 1440 are accepted. Otherwise default 1440. |
| `bible.verseScope` | JSON string | Only `full`, `ot`, `nt` are accepted. Otherwise default `full`. |
| `bible.reader.location` | JSON object | Requires string book, integer chapter >= 1, finite numeric scrollY. Clamp scrollY to >= 0. updatedAt defaults to 0. |
| `bible.reader.textSize` | JSON string | Accept `small`, `medium`, `large`, `extraLarge`. Otherwise `medium`. |
| `bible.reader.lineSpacing` | JSON string | Accept `compact`, `comfortable`, `relaxed`. Otherwise `comfortable`. |
| `bible.reader.typeface` | JSON string | Accept `sans`, `serif`. Otherwise `serif`. |
| `bible.reader.layout` | JSON string | Accept `paragraphs`, `verses`. Otherwise `paragraphs`. |
| `bible.widgetGuideDismissed` | JSON boolean | True only when stored value parses to true. |
| `bible.reader.selectionHintDismissed` | JSON boolean | True only when stored value parses to true. |
| `vesper.sunday.<YYYY-MM-DD>` | one JSON object encoded in an MMKV string | Keep before/after only when each is a string; otherwise empty strings. |
| `vesper.prayer.favorites` | one JSON array encoded in an MMKV string | Keep string IDs in original order; discard non-string array items. |
| `john.calendar-notifications.v1` | one JSON object encoded in an MMKV string | enabled true only; hour integer 0..23 else 8; minute integer 0..59 else 0. |
| `rosary.reminder.v1` | JSON object | enabled true only; frequency weekly only when exactly `weekly`, else daily; hour/minute/weekday ranges else defaults 20/0/2; retain notificationId only if string. |
| `works.position.v1` | JSON object keyed by work ID | Accept object; get position when sectionIndex is number. Preserve extra fields. pageIndex and updatedAt are source hints. |

Other source key families:

- `novena.<novenaId>.progress.v1`: JSON object. `completedDays` keeps unique integer days from 1 through the novena day count and sorts them. `selectedDay` must be an in-range integer or becomes 1. `intention` must be a string or becomes empty.
- `src/services/widget/widgetBridge.ts` uses App Group `group.com.nrsv.verse`. It stores `widgetSchemaVersion`, `intervalMinutes`, `scope`, `translationId`, `abbreviation`, and `attribution`. It removes legacy `verses` when schema is not `2`. This is shared widget state, not default MMKV.

The generic `load` function reads a string, runs `JSON.parse`, and returns the raw string when parsing fails. The theme hook reads a raw string. Do not assume every stored value is valid JSON. `save` JSON-encodes its value. `saveString` stores text as supplied.

## SQLite source schemas

`user-library.db` is opened by Expo SQLite and initialized with `PRAGMA journal_mode = WAL` and `PRAGMA foreign_keys = ON`. The source schema version is 1. The database name is source-observed. The runtime container path, live journal files, IDs, and rows are unobserved.

```sql
CREATE TABLE bookmarks (passage_key TEXT PRIMARY KEY NOT NULL, translation_id TEXT NOT NULL, book_code TEXT NOT NULL, book_name TEXT NOT NULL, book_order INTEGER NOT NULL, chapter INTEGER NOT NULL, start_verse TEXT NOT NULL, end_verse TEXT NOT NULL, start_index INTEGER NOT NULL, end_index INTEGER NOT NULL, scripture_text TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
CREATE INDEX bookmarks_updated_idx ON bookmarks(updated_at DESC);
CREATE TABLE highlights (verse_key TEXT PRIMARY KEY NOT NULL, batch_id TEXT NOT NULL, translation_id TEXT NOT NULL, book_code TEXT NOT NULL, book_name TEXT NOT NULL, book_order INTEGER NOT NULL, chapter INTEGER NOT NULL, verse TEXT NOT NULL, verse_index INTEGER NOT NULL, verse_text TEXT NOT NULL, color TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
CREATE INDEX highlights_reference_idx ON highlights(translation_id, book_code, chapter, verse_index);
CREATE INDEX highlights_updated_idx ON highlights(updated_at DESC);
CREATE TABLE notes (passage_key TEXT PRIMARY KEY NOT NULL, translation_id TEXT NOT NULL, book_code TEXT NOT NULL, book_name TEXT NOT NULL, book_order INTEGER NOT NULL, chapter INTEGER NOT NULL, start_verse TEXT NOT NULL, end_verse TEXT NOT NULL, start_index INTEGER NOT NULL, end_index INTEGER NOT NULL, scripture_text TEXT NOT NULL, note_text TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
CREATE INDEX notes_updated_idx ON notes(updated_at DESC);
```

`bible-search.db` is a bundled read-only source with FTS5 virtual table `verse_search`, external content `verses`, and tokenizer `unicode61 remove_diacritics 2`. Search source uses `bm25`. It has tables `metadata`, `books`, `verses`, `vocabulary`, and FTS5 support tables. Exact DDL, metadata, counts, hashes, and bytes are in `build/native-evidence/L00-source/resource-manifest.json`.

`works.db` has `metadata` and `sections`; `sections` uses `(work_id, idx)` as its primary key and stores `paragraphs BLOB NOT NULL`. Metadata says schema 2 and `zlib-json`. Exact DDL and counts are in the resource manifest.

## Shared widget state

The app writes shared scalar values through `ExtensionStorage` in App Group UserDefaults. `widgetSchemaVersion` is the string `"2"`. `intervalMinutes` is numeric. `scope`, `translationId`, `abbreviation`, and `attribution` are strings. The app removes the old `verses` value when it upgrades the widget schema. The actual shared container values were not read.
