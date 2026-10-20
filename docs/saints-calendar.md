# Saints and feast days

The native iOS and Android apps bundle two annual calendars. Users can open
**Today → Saints & feast days**, choose a date, or search names across the year.
The daily readings page also shows both calendars.

## Sources and scope

- [Vatican News, Saint of the Day](https://www.vaticannews.va/en/saints.html):
  696 entries from the English calendar, including groups, blesseds, and other
  observances. All 365 ordinary dates were checked. The English February 29 page
  is absent. February 24, June 20, and July 7 have no entries. November 1 and 2 use
  Vatican News' dedicated All Saints and All Souls pages because the daily pages
  return 404.
- [Metropolitan Cantor Institute, Menaion](https://mci.archpitt.org/menaion/index.html):
  635 entries from its index and day accounts. All 366 dates were checked. This
  is the Ruthenian Byzantine Catholic calendar used in the United States, with
  Gregorian dates. It is not a combined calendar for every Byzantine Catholic
  Church. The importer includes index entries omitted from day introductions,
  and available day accounts whose links are missing from the index.

These are devotional commemorations, not a complete liturgical scheduling engine.
The Menaion can list a saint on both a nominal date and a transferred service
date. The app preserves those source entries. Movable feasts, local calendars,
and service rules can differ. Cassian appears on February 28 in non-leap years,
as directed by the MCI for Compline.

Calendar dates come from the selected calendar, even when a linked biography
uses another date. For example, the English Vatican calendar lists Schuster on
August 31; the Italian account is on August 30. Separate source and calendar
links make this distinction visible.

## English accounts

Vatican entries contain 247 short English source excerpts and 448 original
English summaries. Most summaries use the Italian Vatican account; some use
English Vatican News or Holy See pages, and one uses German Vatican News.
The UI labels summaries and the source language. They are not official Vatican
translations. One Vatican entry, “Saint Ementiana,” has no verified life account.
The app keeps that source entry without inventing a biography or merging it
with the separately listed Emerentiana.

The Menaion provides 521 English excerpts. Its other 114 entries include
seasonal observances and saints for which the available source gives only a
name. The app states when a short account is unavailable.

Each source URL contributes at most 24 quoted excerpt words across its catalog.
Longer accounts remain at the linked source. Summaries preserve uncertainty in
traditional accounts and omit clearly conflicting incidental details.

## Notifications

The existing calendar notification setting controls one daily notice. Its body
includes all entries for that local date from both calendars. The existing Roman
Rite Gospel reference remains when available. Tapping opens that date's saints
and readings. System previews can shorten long text.

iOS retains its rolling schedule of up to one month and its pending-request
capacity rules. Opening the app refreshes the schedule and replaces older
calendar notice bodies. Android reads the bundled calendars when its existing
daily alarm fires. Neither platform requires a network request for daily content.

## Update and validation

Run from the repository root:

```sh
python3 scripts/build-saints-calendar.py --cache /tmp/john-saints-vatican
python3 scripts/build-saints-calendar.py --tradition byzantine --cache /tmp/john-saints-mci
python3 scripts/test-saints-calendar.py
```

The importer writes `src/services/companion/data/saints-{tradition}.json`.
Reviewed summaries live in `scripts/saints-vatican-summaries.json`. The importer
checks matched Italian headings and source-text hashes before reusing those
summaries. Review changed sources before updating a hash. Use a fresh cache for
a new source review. Remove temporary source caches after use.

Both native resource staging scripts include the catalogs. Swift package tests
check the real catalogs, local dates, leap years, source languages, notification
names, and dates beyond the finite readings catalog. Android unit tests check
leap years and notification names. The iOS calendar UI test checks search,
English attribution, and switching to the Byzantine calendar.

Validation on 2026-10-20: 44 Swift package tests, 17 Android unit tests,
5 importer tests, and the iOS saints UI test passed. Android Kotlin compilation
and iOS simulator compilation passed. The UI test used a separate app identifier
and one existing simulator.

Release validation on 2026-10-20: iOS 2.0.3 (27) archived with the full project.
The release resource script now uses the tracked canonical artwork and native
launch layout. It does not require a generated Expo `ios/` folder. The package
check verified all three icon variants, the compiled launch screen, fonts,
licenses, and privacy manifests. Signature verification passed. Both bundled
saints catalogs match their source bytes.

Android 1.0.2 (3) passed the signed bundle checks, 17 release unit tests, and
release lint (zero errors). Both saints catalogs match their source bytes in
the bundle. The verifier checked the package ID, version, SDK levels, upload
signature, and 16 KB native library alignment.
