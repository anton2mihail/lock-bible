# Architecture

A Catholic Bible reader with a daily/rotating **verse-of-the-moment** that
appears on the iOS **lock screen** (and home screen) via a WidgetKit widget.

Built on the Ignite (Infinite Red) stack already in this repo: Expo SDK 55,
Expo Router, MMKV storage, the themed `Text`/`Screen`/`Button`/`ListItem`
components, and Continuous Native Generation (prebuild).

## The big idea: deterministic verse selection

The verse shown is a **pure function of the device clock** — no background
tasks, no network, no shared mutable state required:

```
slot = floor(localMinutesSinceEpoch / intervalMinutes)
index = (slot * coprimeStride + offset) % scopedVerseCount
```

The stride is chosen to be coprime with the scoped pool size, making this a
full-cycle permutation: every verse in the selected edition is shown exactly
once before any reference repeats. The JS app (`src/services/bible/verseOfDay.ts`) and the
native Swift widget (`targets/widget/VerseWidget.swift`) compute this
**identically**, so the lock screen and the in-app "Today" tab always agree. The
widget builds a WidgetKit
`Timeline` with one entry per rotation boundary and `reloadPolicy: .atEnd`, so
iOS rotates the verse on schedule even if the app is never opened — well within
the OS widget refresh budget.

Two preferences shape the pool, both mirrored to the widget via the App Group:
**rotation cadence** (every 10 / 15 / 30 min, 1 / 3 / 6 / 12 h, or daily) and
**verse scope** (full Bible / Old Testament / New Testament). Cadence is measured
in minutes end-to-end. Scope selects the matching prebuilt positional index on
the native side and filters the same source pool in JS, so the lock screen and
app still agree; the Old Testament scope includes the deuterocanon. The
countdown widget pre-supplies one timeline entry per upcoming boundary so even a
10-minute cadence stays within WidgetKit's refresh budget.

## Layers

```
scripts/build-bible-data.mjs   Parses three public-domain Catholic USFX sources
                               into normalized JSON. Output is committed.
        │
        ▼
src/services/bible/
  data/<translation-id>/       Generated: one <BOOK>.json per book, manifest.json,
                               meta.json, widget payload, and static-require index.
  types.ts                     Translation-agnostic shapes.
  translations.ts              Registry — the ONE seam where editions plug in.
  bibleData.ts (bibleService)  Active-translation facade, memoized book loads.
  verseOfDay.ts                Deterministic selection (mirrored in Swift).
  preferences.ts               Translation + rotation cadence (MMKV).
  referenceParser.ts           Local reference and light typo parser.
  searchService.ts             FTS5 queries over the bundled search database.

assets/bible/bible-search.db   Prebuilt, read-only SQLite FTS5 index containing
                               every verse from every bundled edition.

src/services/database/        Nested Expo SQLite providers and local migrations.
src/services/library/         On-device bookmarks, highlights, and private notes.
src/services/novena/          Searchable offline catalog, sourced prayer content,
                               and per-novena nine-day progress/intention storage.

src/services/widget/widgetBridge.ts
                               Pushes prefs to the App Group and reloads only
                               when they change. No-op off-iOS / before prebuild.

src/screens/                   Today, reader/search, Pray, Saved, notes, settings.
src/app/(tabs)/                Expo Router tabs: Today / Read / Pray / Saved / Settings.

targets/widget/                iOS WidgetKit extension (added via @bacons/apple-targets):
  expo-target.config.js        Target config + App Group entitlement.
  VerseWidget.swift            TimelineProvider + accessory/system views.
  <translation-id>.*           Random-access corpus and indexes per edition.
```

## Offline novena library

The Pray tab contains 27 sourced Catholic novenas. Each entry includes a short
devotional background, patronage and searchable needs, traditional dates when
applicable, an offline prayer, and a link to its Catholic source. Prayer wording
in `expandedNovenas.ts` is an original adaptation of traditional devotions; the
source links establish the devotion, feast, and background rather than implying
that copyrighted page text was reproduced.

All novenas share the same on-device progress model: a private intention,
selected day, and completed-day set. Search indexes the title, subtitle,
background, patronage, and explicit search terms, so broad needs such as mental
health, conversion, protection, lost things, or family life can return more than
one relevant devotion.

## Rosary and local reminders

The Pray tab also contains a first-class Rosary experience under
`src/services/rosary/` and `src/screens/rosary/`. The four mystery sets, their
customary weekday schedule, Scripture references, traditional prayers, and the
full five-decade guided sequence are bundled with the app and work offline.

Rosary reminders use `expo-notifications` repeating daily or weekly calendar
triggers. The operating system stores and delivers the schedule locally; the
app does not obtain a push token and does not require a notification server.
Tapping a reminder deep-links to `/pray/rosary`.

The Bishop Barron / Word on Fire catalog includes the six episode titles and
official links. `expo-video` and `expo-audio` power separate native players.
Development builds use clearly labelled open test clips to exercise both
players; release builds leave playback disabled until approved direct
`videoUri` and `audioUri` values are added to `src/services/rosary/catalog.ts`.
This is intentional because Word on Fire requires explicit permission for
third-party distribution and its standard permission terms restrict archived
on-demand audio/video.

## Bundled Bible editions

The app ships three complete, offline, public-domain Catholic editions:

- **World English Bible — Catholic Edition (WEB-CE)** — modern English.
- **Douay–Rheims 1899 American Edition (DRB)** — traditional English.
- **Clementine Vulgate 1598 (VUL)** — Latin.

Each source is normalized to the Catholic 73-book canon. The selected edition
controls the reader, full-text search, rotating verse, and iOS widget.

The originally requested **NRSVCE is copyrighted** and not available via any API;
it requires a negotiated license from the NCC. See
[`nrsvce-licensing-inquiry.md`](./nrsvce-licensing-inquiry.md) for a ready-to-send
inquiry and the swap steps. The text layer is deliberately pluggable so NRSVCE
(or any edition) is a **data + attribution drop-in**, not a rewrite.

### Regenerating / swapping the translation

```bash
node scripts/build-bible-data.mjs
```

Reuses cached USFX files under `scripts/.cache/` or downloads them from
eBible.org (needs `curl` + `unzip`). To add another translation, point a new
config block at its USFX source, emit under a new id, and register it in
`translations.ts`. The verse screen / reader / settings already render each
translation's `attribution` and `copyrightNotice`.

## iOS widget setup

The widget is added through [`@bacons/apple-targets`](https://github.com/EvanBacon/expo-apple-targets),
which keeps the Swift outside the generated `ios/` dir and injects the WidgetKit
target on every prebuild.

Requirements: **Xcode 16+, CocoaPods 1.16.2+**. The widget targets **iOS 16.1+**
(lock-screen accessory widgets need iOS 16).

```bash
npx expo prebuild -p ios     # generates the widget target into ios/
npm run ios                  # or: eas build --profile development --platform ios
```

EAS Build registers the App Group (`group.com.nrsv.verse`) and handles signing.
For local signed builds, set your Apple Team ID in EAS credentials.

**App Group** `group.com.nrsv.verse` is declared in three places that must stay
in sync: `app.config.ts` (main app entitlement),
`targets/widget/expo-target.config.js` (widget entitlement), and
`src/services/widget/widgetBridge.ts` (`APP_GROUP`).

Two widgets ship in the bundle (`targets/widget/VerseWidget.swift`):

- **Daily Verse** (`VerseWidget`) — the rotating verse. Rectangular = full text
  (heavy rounded font, auto-shrinks to 3 lines), inline = reference, circular =
  reference.
- **Verse Countdown** (`VerseTimerWidget`) — a live timer to the next verse
  change, using `Text(_:style:.timer)` / `ProgressView(timerInterval:)`. These
  tick on their own, so it costs **zero** refresh budget; the timeline reloads
  only once, at the moment the verse actually changes (`.after(nextChange)`).

**Adding it on device:** lock screen → long-press → Customize → tap the box under
the clock → choose this app → add **Daily Verse** and/or **Verse Countdown**.
(These instructions are also shown in the app's Settings tab.)

## Data flow to the widget

1. The widget **bundles** one compact random-access corpus per translation plus
   positional and testament indexes, so it works before the app is ever opened
   (defaults to WEB-CE and daily rotation) without decoding a whole Bible into memory.
2. Once at app startup and on any Settings change, `widgetBridge.syncWidget()`
   writes the current translation id, rotation interval, abbreviation, and scope to
   the App Group. It reloads timelines only when one of those values changed.
3. Each timeline decodes at most its 48 scheduled verses; the corpus file is
   memory-mapped and each selected row is decoded on demand. The complete pool is
   generated from the same source as the reader and bundled into both targets.

## Branding assets

App icon, Android adaptive icon, web favicon, and splash mark are a gold
`mdi:bible` glyph (Material Design Icons, Apache-2.0) on a brand gradient.
Regenerate or swap via `scripts/build-app-icons.py`. The splash reuses the
Android adaptive foreground on `#191015` (see `app.json` → expo-splash-screen).
Provenance and license: [`assets/CREDITS.md`](../assets/CREDITS.md).

## Tests

The Jest suite pins the full-cycle rotation contract and covers reference and
phrase search, typo correction, translation/reading preferences, contiguous verse
selection, bookmarks, four-color highlights, notes, delete/undo, and navigation
back into reading context. The bundled database verifier checks all three
73-book editions and their verses are present and queryable. A Maestro flow exercises the complete
search-to-save workflow on an installed native build.

```bash
npm test
bun run verify:bible-search
bun run verify:widget-data
bun run test:maestro
```
