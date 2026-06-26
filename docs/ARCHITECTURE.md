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
index = floor(localMinutesSinceEpoch / intervalMinutes) % scopedVerseCount
```

The JS app (`src/services/bible/verseOfDay.ts`) and the native Swift widget
(`targets/widget/VerseWidget.swift`) compute this **identically**, so the lock
screen and the in-app "Today" tab always agree. The widget builds a WidgetKit
`Timeline` with one entry per rotation boundary and `reloadPolicy: .atEnd`, so
iOS rotates the verse on schedule even if the app is never opened — well within
the OS widget refresh budget.

Two preferences shape the pool, both mirrored to the widget via the App Group:
**rotation cadence** (every 10 / 15 / 30 min, 1 / 3 / 6 / 12 h, or daily) and
**verse scope** (full Bible / Old Testament / New Testament). Cadence is measured
in minutes end-to-end. Scope filters the pool *before* indexing, identically on
both sides (the JS `filterByScope` and the Swift `matches`), so the lock screen
and app still agree; the Old Testament scope includes the deuterocanon. The
countdown widget pre-supplies one timeline entry per upcoming boundary so even a
10-minute cadence stays within WidgetKit's refresh budget.

## Layers

```
scripts/build-bible-data.mjs   Parses a public-domain USFX source (WEB-CE) into
                               normalized JSON. Run offline; output is committed.
        │
        ▼
src/services/bible/
  data/web-ce/                 Generated: one <BOOK>.json per book, manifest.json,
                               meta.json, and a lazy static-require index.ts.
  types.ts                     Translation-agnostic shapes.
  translations.ts              Registry — the ONE seam where editions plug in.
  bibleData.ts (bibleService)  Active-translation facade, memoized book loads.
  verseOfDay.ts                Deterministic selection (mirrored in Swift).
  preferences.ts               Translation + rotation cadence (MMKV).

src/services/widget/widgetBridge.ts
                               Pushes prefs + verse pool to the App Group and
                               reloads the widget. No-op off-iOS / before prebuild.

src/screens/                   VerseOfDayScreen, ReaderScreen, SettingsScreen.
src/app/(tabs)/                Expo Router tabs: Today / Read / Settings.

targets/widget/                iOS WidgetKit extension (added via @bacons/apple-targets):
  expo-target.config.js        Target config + App Group entitlement.
  VerseWidget.swift            TimelineProvider + accessory/system views.
  widgetVerses.json            Bundled verse pool (copy of assets/bible/…).
```

## The Bible text (and the NRSVCE question)

Ships with the **World English Bible — Catholic Edition (WEB-CE)** — public
domain, full deuterocanon, modern English. It requires no license and is legal
to distribute today.

The originally requested **NRSVCE is copyrighted** and not available via any API;
it requires a negotiated license from the NCC. See
[`nrsvce-licensing-inquiry.md`](./nrsvce-licensing-inquiry.md) for a ready-to-send
inquiry and the swap steps. The text layer is deliberately pluggable so NRSVCE
(or any edition) is a **data + attribution drop-in**, not a rewrite.

### Regenerating / swapping the translation

```bash
node scripts/build-bible-data.mjs
```

Reuses a cached USFX file under `scripts/.cache/` or downloads WEB-CE from
ebible.org (needs `curl` + `unzip`). To add another translation, point a new
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

1. The widget **bundles** its own `widgetVerses.json`, so it works before the app
   is ever opened (defaults to daily rotation).
2. On the Today tab and on any Settings change, `widgetBridge.syncWidget()` writes
   the current rotation interval, translation abbreviation, and verse pool to the
   App Group and calls `ExtensionStorage.reloadWidget("VerseWidget")`.
3. The widget prefers the shared (OTA-updatable) pool, falling back to its bundled
   copy — so the curated verse list can be updated via an OTA update without a
   native rebuild.

## Branding assets

App icon, Android adaptive icon, web favicon, and splash mark are a gold
`mdi:bible` glyph (Material Design Icons, Apache-2.0) on a brand gradient.
Regenerate or swap via `scripts/build-app-icons.py`. The splash reuses the
Android adaptive foreground on `#191015` (see `app.json` → expo-splash-screen).
Provenance and license: [`assets/CREDITS.md`](../assets/CREDITS.md).

## Tests

`src/services/bible/verseOfDay.test.ts` pins the determinism contract (stable
within a window, advances one slot per interval, always in range). Run:

```bash
npm test
```
