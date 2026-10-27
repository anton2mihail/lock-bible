# iOS 2.3.0 / Android 1.3.0 — A Year with the Fathers, Lent, Holy Week, the Stations

**Status (27 Oct 2026, 14:13):** submitted to App Review on Anton's ask: iOS 2.3.0 (33) with the three In-App Events
below (4 items, release automatically after approval). Mac: compatibility verified in Pricing and Availability
(Anton: assume Mac tested). Version text: What's New as below, keywords with "stations" in place of "widget", three
new lines in the description (A Year with the Fathers; Lent and Holy Week; the Stations), reviewer notes for 2.3.0.

**Play (27 Oct 2026, 14:3x):** Anton uploaded the 1.3.0 (8) bundle; production release "8 (1.3.0) — A Year with the
Fathers and Lent" (full rollout) sent for review with the listing changes. This restarted the review: 1.2.0 (6) never
ships, 1.3.0 contains it. One warning only: no native debug symbols uploaded. Supported phones unchanged (11,471).

## In this release

1. **A Year with the Fathers** (built on main, 26–27 Oct): 365 readings for 2027, Today card, start screen, plan
   page, reminder, 7 free days. See `lent-holyweek-office-year-plan.md` §4.
2. **Lent** (`nrsv://lent`): the week of Lent, today's Gospel with the Fathers, the Collect of the day, St Leo's 14
   sermons on Lent and the Passion (free from Ash Wednesday to Easter Sunday), the Seven Penitential Psalms, the
   Stations, and a link to the USCCB rules on fasting.
3. **Holy Week** (`nrsv://holyweek`): Palm Sunday to Easter Sunday, today first: the Collects, the blessing of the
   palms, the Mandatum antiphons, the Solemn Prayers, the Reproaches, *Faithful Cross*, the Exsultet and
   *Victimae paschali*, from the 1926 Missal.
4. **The Stations of the Cross** (`nrsv://stations`): St Alphonsus Liguori, from *A Manual of Prayers* (Baltimore,
   1889), with Giandomenico Tiepolo's *Via Crucis* etchings (c. 1749). Pray tab all year; Today on Fridays of Lent.
5. **Mac:** on the iPad app on a Mac, Settings hides the Lock Screen widget steps.
6. Sources of every text: `content-sources.md`, section "Lent, Holy Week and the Stations of the Cross".

Not in this release:

- **Smaller download** (asset packs): moved to 2.3.1 in January, as the plan allows.
- **Readings for 2028:** the source (catholic-readings-api) has 2025–2027 only. Add 2028 in a 2027 update, before
  Ash Wednesday 2028 (1 March 2028).

## Good Friday: two prayers left out (Anton, 27 Oct 2026)

The 1926 Missal prints nine Solemn Prayers. The app shows seven. It leaves out the prayer for the emperor and the
prayer for the Jews in its pre-1959 wording, and says so under the prayers: "Two prayers of the 1926 Missal are not
shown: the prayer for the emperor, and the prayer for the Jews in its pre-1959 wording. The Church has since revised
them." The Exsultet keeps its petition for the emperor inside its last paragraph.

## Store text (drafts)

**What's New (iOS 2.3.0):**

```text
A Year with the Fathers: one reading a day from the Fathers of the Church through 2027, from 1 January. The readings follow the Church's year: St Leo the Great on each feast, St Cyril of Jerusalem in Lent and Easter week, St Augustine's Confessions in summer. Join on any day; the first seven days are free.

Lent with the Fathers: from Ash Wednesday, Today shows the week of Lent, a Father's comment on the day's Gospel and the Collect of the day from the Roman Missal. St Leo the Great's fourteen sermons on Lent and the Passion are free to read from Ash Wednesday to Easter Sunday. The Seven Penitential Psalms, in the Douay-Rheims.

Holy Week: the Missal's prayers for each day from Palm Sunday to Easter Sunday, with the Reproaches, the Exsultet and Victimae paschali.

The Stations of the Cross by St Alphonsus Liguori, with Giandomenico Tiepolo's etchings of the Way of the Cross. In the Pray tab all year, and on Today on the Fridays of Lent.

The Advent wreath: each week of Advent, the Collect of its Sunday from the Roman Missal.
```

**Play release notes (Android 1.3.0, under 500 characters):**

```text
A Year with the Fathers: one reading a day from the Fathers through 2027, from 1 January. The first 7 days are free.
Lent and Holy Week: the Collect of each day from the Roman Missal, St Leo's sermons on Lent free in Lent, the Seven Penitential Psalms and the Holy Week prayers.
The Stations of the Cross by St Alphonsus Liguori, with Tiepolo's etchings.
```

**Keywords (D4):** replace "widget" with "stations" in the 2.3.0 keyword field.

**In-App Events (create with 2.3.0; an event lasts at most 31 days):**

| Event (id) | Badge | Event dates (Toronto) | Publish from | Deep link | Images (`marketing/events/`) |
|---|---|---|---|---|---|
| A Year with the Fathers begins (6827675499) | Special Event | 1 Jan 00:00 – 31 Jan 2027 23:59 | 18 Dec 2026 | `nrsv://year` | `year-2027/`: Michael Pacher, *Altarpiece of the Church Fathers* (1471–75) |
| Lent with the Fathers (6827676614) | Special Event | 10 Feb 00:00 – 12 Mar 2027 23:59 | 27 Jan 2027 | `nrsv://lent` | `lent-2027/`: El Greco, *Agony in the Garden* |
| Holy Week with the Fathers (6827678051) | Special Event | 21 Mar 00:00 – 28 Mar 2027 23:59 | 7 Mar 2027 | `nrsv://holyweek` | `holy-week-2027/`: Giovanni Bellini, *Calvary* (Louvre) |

All three: access "In-App Purchase Not Required", purpose "Appropriate for all users", normal priority. Long
descriptions: "One reading a day from the Fathers of the Church through 2027, following the Church's year. The first 7
days are free." / "From Ash Wednesday: the Collect of each day, the Fathers on the Gospel, St Leo on Lent and the
Stations of the Cross." / "Palm Sunday to Easter: the Missal's prayers for each day, the Fathers on the Passion and
the Stations of the Cross." The images are public domain (Wikimedia Commons, checked with the
`scripts/fetch-artwork.py` licence rules) with metadata stripped: App Store Connect rejected the first details upload
as "wrong format".

Short descriptions (≤ 50 characters): "One reading from the Fathers each day of 2027" (45); "The Collect, the Fathers and the Stations" (41);
"The Missal's prayers from Palm Sunday to Easter" (47).

**Custom product pages (not made yet):** "A Year with the Fathers" (`nrsv://year`) and "Stations of the Cross"
(`nrsv://stations`, keyword "stations"); they need new framed screenshots. **Play:** custom listing "Search: Stations
of the Cross".

## Checks

- JohnCore: 109 tests pass (Lent calendar 9, Lent data 4).
- Android unit tests pass (LentTest 6).
- iOS simulator and Android emulator checked by hand on 12 Feb and 26 Mar 2027: Today rows, Lent page, Collect,
  Leo with the library locked, Stations (opening, Station 1), Holy Week on Good Friday.
- UI tests: `LentUITests` (4), with `AdventUITests` and `YearPlanUITests`.

## To ship

1. Done: the two Good Friday prayers are left out with a note.
2. Done 27 Oct: `scripts/native/release-testflight.sh 2.3.0 33`; Android: `ANDROID_RELEASE_VERSION_CODE=8 ANDROID_RELEASE_VERSION_NAME=1.3.0 python3 scripts/android/release/build-bundle.py`.
3. Mac: install the TestFlight build on this Mac; check the reader with keyboard and trackpad, window sizes, the
   purchase and restore, read aloud, notifications. Then mark the app verified for Mac in App Store Connect.
4. On Anton's ask: create version 2.3.0, attach build 33, What's New, keywords, events, product pages; submit.
