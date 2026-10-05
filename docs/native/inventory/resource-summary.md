# L00 content and resource inventory

Baseline commit: `b64e1fc3cfc6a78f508b41d74b71dddfe9ff7697`.

This evidence comes from source files and bundled resource metadata. Runtime loading, UI coverage, installed bundle contents, and binary identifiers remain unobserved. The full SHA-256 and byte list for files under `assets/` is in `build/native-evidence/L00-source/resource-manifest.json`.

| Resource | Source count or detail | Runtime status |
|---|---|---|
| Bible editions | `web-ce`, `douay-rheims`, `vulgate`; 73 books each | Unobserved |
| Bible search | 106,999 verses; WEB-CE 35,379; Douay–Rheims 35,811; Vulgate 35,809; FTS5 | Unobserved |
| Works | 26 collections; 271 works; 16,146 sections; 15,108,808 words; schema 2 `zlib-json` | Unobserved |
| Daily readings | 858 dated entries, 2025-08-25 through 2027-12-31 | Unobserved |
| Celebrations | 2,922 dated entries, 2025-01-01 through 2032-12-31 | Unobserved |
| Prayer catalogs | 27 novenas; 12 prayer entries; 5 teaching topics | Unobserved |
| Rosary | Four mystery sets; one Seven Sorrows devotion; source has media entries and distinct guide builders | Unobserved |
| Fonts | Installed Lora and Space Grotesk TTF files, package versions, SHA-256 values, and PostScript names are listed in the resource manifest. The source loads seven aliases from `src/theme/typography.ts`. The resource manifest lists those seven files for native staging. | Runtime registration unobserved |
| Icons | `assets/icons/`, app artwork icon files, image favicon; exact file list and hashes in resource manifest | Unobserved |
| Artwork credits | 32 source records in `assets/artwork/credits.json`; source notes in `docs/john/artwork-sources.md` | Screen-to-artwork coverage unobserved |
| Widget kinds | `VerseWidget`, `VerseTimerWidget`, `DailyReadingWidget`. Daily Reading supports accessory rectangular, accessory inline, system small, and system medium families. | Installed extension IDs and binary not inspected |

`build/native-evidence/L00-source/catalog-fixtures.json` contains exact source strings and catalog objects. `rotation-fixtures.json` contains source-generated expected selections for every edition, scope, and supported cadence. It includes a negative slot, spring and autumn daylight-saving transitions, a fractional time-zone offset, and two time zones for the same instant. These files are baseline evidence. They do not define the production native resource schema.

The app ID source value is `com.nrsv.verse`. The App Group is `group.com.nrsv.verse`. The source URL scheme is defined in app configuration. No built binary or simulator container was inspected in this task. The actual bundle identifiers, URL scheme registration, entitlements, SQLite location, and MMKV location remain runtime tasks for the runtime worker.
