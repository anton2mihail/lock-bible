# John 1:1 for Android

Native Kotlin and Jetpack Compose app. The Swift iOS app remains in `native/John`.
Both apps use the Bible, Works, calendar, prayer, and artwork sources in this repo.
There is no JavaScript runtime in the Android app.

## Build

Required: JDK 17 or 21, Android SDK platform 36, Python 3.11 or later, Node.js,
and the repo's installed dependencies (`bun install --frozen-lockfile`).
Set `ANDROID_HOME` to your Android SDK path, or set `sdk.dir` in an untracked
`local.properties` file in this folder.

```sh
cd native/Android
./gradlew :app:assembleDebug
```

The APK is `app/build/outputs/apk/debug/app-debug.apk`.
Open `native/Android` in Android Studio to run or debug the app.
The Gradle wrapper pins Gradle 8.13, AGP 8.13.0, and Kotlin 2.2.20.

Before each build, `scripts/android/stage-assets.py` stages the shared sources
under `app/build/generated/john`. It creates the Android FTS4 search index from
the shared Bible database. Generated assets and fonts do not belong in Git.
Each edition contains 73 books. The search index contains 106,999 verses.
All 16,146 Works sections use the existing compressed SQLite corpus.

## Reviewed companion content

Android builds copy `content/companion.json`. This release input contains the
reviewed prayers, teachings, novenas, and Rosary guides. Normal builds do not
run the TypeScript catalog exporter. This preserves the release content when
the shared iOS source files have uncommitted edits.

`content/companion-provenance.json` records the catalog hash and the source
file hashes used to create it. Source hashes are records, not build conditions.
Staging and verification check the pinned catalog hash and exact output bytes.
The release contains 7 novenas, 28 prayers, and 5 teachings.

To compare later shared source changes without changing Android content, run:

```sh
python3 scripts/android/refresh-companion.py --check
```

To update the Android catalog on purpose, run from the repository root:

```sh
python3 scripts/android/refresh-companion.py --write
```

Review the diff in both content files before a release. Check the source
attribution and all changed prayers. If counts change, update the catalog
checks and device tests. Then rebuild and run shared resource verification.
Commit the reviewed catalog and provenance with the Android change. A refresh
does not edit or commit the shared TypeScript source files.

## Tests

```sh
./gradlew :app:testDebugUnitTest :app:lintDebug
./gradlew :app:connectedDebugAndroidTest
python3 ../../scripts/android/verify-assets.py --output app/build/generated/john
```

Use one existing emulator. Follow the root `AGENTS.md` device limits.
Do not create an emulator or run parallel device tests.
After tests, uninstall `com.john.bible.test` and any test installation of
`com.john.bible`. Remove build outputs and the local `.gradle` folder.

## Platform behavior

The five tabs and content match the Swift app. Local state includes bookmarks,
highlights, notes, favorites, reflections, reading progress, and novena progress.
Both platforms accept `nrsv://read?book=JHN&chapter=1&verse=1` links.
Android also accepts `john://` and `john11://`.

Android uses its own share sheet, speech service, notification permissions,
back navigation, and widget host. Home screen widgets replace WidgetKit widgets.
A media foreground service keeps read-aloud active in the background.
Android can delay local reminder delivery for battery management.
Apple services such as iCloud, Handoff, Siri, and Live Activities do not exist
on Android. Automatic cloud backup and device transfer are disabled. Use Saved export/import for a manual copy.

A release build needs the owner's signing key before store distribution.
No signing key or store credentials are stored in this repo.

## Bible reader pages

The Bible reader turns pages by default, as Google Play Books does.
Reading choices has a "Reading mode" choice: Pages or Scroll.
Scroll keeps the earlier chapter scroll view. The app saves the choice
with the other reading preferences.

In Pages mode, `PagedReader.kt` measures each chapter one time for the current
page size, text size, line spacing, typeface, verse numbers, and layout.
Measurement runs off the main thread. The pages draw clipped parts of one text
layout, so the line breaks are the same on each page. `PageMath.kt` holds the
page arithmetic. JVM tests check it.

- Tap the left third to go back one page. Tap the right third to go forward.
- Tap the middle third to show or hide the top and bottom bars.
- Swipe past the last page to open the next chapter or book. Swipe back to
  return to the last page of the previous chapter.
- Touch and hold a verse to select it. While a selection is active, tap a
  second verse to select a range.
- The saved position is a verse and a character offset in that verse. Thus a
  change of text size, screen size, or rotation keeps the same text visible.
- TalkBack reads each verse part on a page. Each verse has Select, Next page,
  and Previous page actions.
- Large landscape screens show two pages side by side.



On 2026-10-13, the debug APK passed 14 device tests on the existing API 36
emulator before the final release privacy changes. These cover all five tabs, passage links, bookmarks, written and drawn
notes, return from Search, offline editions, Latin and phrase search, saved data,
reading plans, favorites, novena progress, lectio, and the Rosary.
All 9 JVM unit tests passed. Debug and release builds passed. Android lint
reported no errors. Shared resource verification checked all 106,999 verses
and all 16,146 Works sections.

The signed release produced six verified store screenshots. Dictate Cancel
passed without launching the recognition provider. Exact pixel parity
across every iOS and Android screen has not been verified. The platform services
listed above use Android controls. The signed release bundle and current Play
submission checks are recorded in `docs/android-play/submission-status.md`.

Temporary APKs, build files, diagnostic screenshots, and emulator test installs
are removed after local validation, as required by the repo rules. Committed
store screenshots are kept. Rebuild the APK with the command above when you
need to install it.
