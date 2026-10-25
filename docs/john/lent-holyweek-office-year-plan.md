# Lent, Holy Week, the Little Office and "A Year with the Fathers" — detailed plan (25 October 2026)

Four features for John 1:1 (iOS and Android). Rules that apply to all of them:

- **Content rule:** every prayer and religious text is approved by the Church and written by real people (a
  liturgical book, an imprimatur, or a saint/Father as author). No prayer text written or translated by the app or
  an AI. Public domain (US: published before 1931) or licensed. Every text is checked word for word against the page
  scan before it ships, and recorded in `docs/john/content-sources.md`.
- No server, no account, offline. No entrance animations. Failure list first, then tests.
- Everything a person needs to pray stays free. The Fathers library stays behind the existing purchase.

## Key dates

| Date | What |
|---|---|
| Wed 10 Feb 2027 | Ash Wednesday |
| Sun 21 Mar 2027 | Palm Sunday |
| Thu 25 – Sat 27 Mar | Sacred Triduum |
| Sun 28 Mar 2027 | Easter |
| Wed 1 Mar 2028 | Ash Wednesday 2028 (readings data must reach it) |

The readings calendar in the app ends on **31 Dec 2027**. Extending it through 2028 is part of this work (same
source as today: catholic-readings-api, MIT), so Lent 2028 works too.

## Sources (all checked or located on 25 Oct 2026)

| Source | Use | Approval | Scan |
|---|---|---|---|
| *The Missal, compiled by lawful authority from the Missale Romanum* (Burns Oates; B. Herder, 1926 printing) | Collect of every day of Lent; Holy Week rites: blessing of palms, Mandatum antiphons, the Reproaches, the Solemn Prayers of Good Friday, *Crux fidelis*, the *Exsultet*, *Victimae paschali* | Liturgical book; Nihil obstat Bergh, O.S.B., Imprimatur Westminster 1921 | archive.org `missal0000vari` (already used for Advent) |
| *The Little Office of the Blessed Virgin Mary … and the Office of the Dead, in Latin and English* (Benziger Brothers, 1915) | The whole Little Office, all hours and seasons; the Office of the Dead | **Nihil obstat** Remigius Lafort, S.T.D.; **Imprimatur** John Cardinal Farley, New York, 10 June 1915 (checked on the scan) | archive.org `littleofficeofbl00newy` (446 page images, no machine text) |
| *A Manual of Prayers* (Third Plenary Council of Baltimore, 1889), p. 348 ff. | Stations of the Cross, "Composed by St. Alphonsus Liguori, A.D. 1787" | Approved by Cardinal Gibbons; Imprimatur Archbishop of New York | archive.org `manualofprayersf00cath` |
| Douay-Rheims (already in the app) | The Seven Penitential Psalms (Ps 6, 31, 37, 50, 101, 129, 142); check of the Little Office psalms | Approved Catholic Bible | — |
| Fathers library (already in the app) | Leo the Great, *On Lent* I, II, IV, VIII, XI and *On the Passion* (sections 191–204); Catena Aurea; the works used by "A Year with the Fathers" | Fathers and Doctors | — |
| Paintings | Stations of the Cross: Giandomenico Tiepolo, *Via Crucis*, San Polo, Venice (1747–49), 14 canvases | Public domain | Wikimedia Commons (to confirm all 14 are there at good size) |

Rejected: *The Hours, or Little Office … chiefly after the use of Sarum* (London, 1869) is an Anglican edition.
Modern texts (USCCB fasting rules, the ICEL Roman Missal, the modern Liturgy of the Hours) are copyrighted; the app
links to usccb.org for the fasting and abstinence rules instead of restating them.

### Text pipeline (shared by Lent, Holy Week and the Little Office)

1. Download the page images for the needed pages only (no full-book downloads kept in the repo).
2. OCR with `tesseract` (installed, English data; the Latin is not needed in the first release).
3. Proofread: every text is compared against the page image by a person or agent reading the image, line by line.
   Psalms of the Little Office are also compared with the app's Douay-Rheims (same Challoner text, same numbering):
   any difference is checked on the scan.
4. Store as JSON in `src/services/<feature>/data/` with, for each text: page, scan URL, book id. A test checks that
   every text has a source.
5. Record the books in `content-sources.md`.

---

## 1. Lent (iOS 2.3.0 / Android 1.3.0)

### What the person sees

- **Today, from Ash Wednesday to Holy Saturday:** a row "Lent with the Fathers · Week N of Lent" (painting: a
  Passion work already bundled), like the Advent row. On Fridays of Lent the row says "Friday: the Stations of the
  Cross" and opens the Stations.
- **The Lent page** (`nrsv://lent`, also from the row):
  1. Eyebrow "WEEK N OF LENT" (Ash Wednesday to Saturday = "THE DAYS AFTER ASH WEDNESDAY").
  2. Today's readings card (exists).
  3. "Today's Gospel, with the Fathers" (exists; the Catena covers all four Gospels).
  4. **The Collect of the day** from the Missal (every weekday of Lent has its own Mass in the Missal).
  5. **St Leo the Great on Lent:** a row into his sermons on Lent (and in Passiontide, on the Passion). These are
     library sections 191–204 (14 sermons); they are **free from Ash Wednesday to Easter Sunday** (decision L1)
     and locked again after Easter for people without the library.
  6. **The Seven Penitential Psalms:** a list of the seven; each opens in the Douay-Rheims reader.
  7. **The Stations of the Cross** row.
  8. A link "Fasting and abstinence (USCCB)" to the bishops' page.
- **The Stations of the Cross** (`nrsv://stations`): St Alphonsus's text from the 1889 *Manual of Prayers*: the
  opening prayer, then 14 pages, one per station, each with the painting, "V. We adore Thee, O Christ…", the
  meditation and prayer, and the verse "Dear Jesus, Thou dost go to die". Swipe or Next/Previous like the Rosary
  guide. Works all year (Pray tab), featured on Fridays of Lent and on Good Friday.

### Data and code

- `JohnCore/LentCalendar.swift` and Android `data/Lent.kt`: Ash Wednesday and Easter for any year (Easter computus
  already exists in `CompanionCalendar.easter`), week of Lent, Passiontide (from the 5th Sunday), Holy Week flag.
- `src/services/lent/data/collects.json`: 46 entries keyed by liturgical day ("ash-wednesday", "lent-1-sun", …,
  "holy-saturday"), with page and scan link.
- `src/services/devotions/data/stations.json`: opening, 14 stations, closing; each with page reference and painting id.
- Staged into the devotional catalog (iOS and the pinned Android catalog; `refresh-companion.py --write`).
- Routes: `CompanionRoute.lent`, `.stations`; `ExternalRouteParser` and Android `ExternalRoute.kt` hosts `lent`,
  `stations`. Pray tab gets a "Stations of the Cross" row.

### Failure list (tests written first)

- L1. Ash Wednesday or Easter wrong for a year (test 2027, 2028, 2038, 2045, and a year with Easter in April).
- L2. A day of Lent gets the wrong week, or a day outside Lent shows the Lent row.
- L3. A Lent day has no Collect, or gets the Collect of another day (46 days, each exactly one).
- L4. Sundays of Lent (Sunday is not a fast day) or Passiontide labels wrong.
- L5. Stations: fewer than 14, a station without a painting or source page.
- L6. The Lent row and the Advent row both show on one day (never; different seasons).
- L7. Time-zone edge: 23:30 in Toronto on Shrove Tuesday is not Lent.
- L8. Leo's 14 sermons: locked the day before Ash Wednesday and the Monday after Easter, open on every day between,
  for a user without the library; never locked for a user with it. In the smaller-download build these 14 sections
  are in the in-app sample database, not only in the downloaded pack.

### Store

- In-App Events (an event can last at most 31 days):
  1. "Lent with the Fathers": 10 Feb – 12 Mar 2027, publish from 27 Jan, deep link `nrsv://lent`.
  2. "Holy Week with the Fathers": 21 – 28 Mar 2027, publish from 10 Mar, deep link `nrsv://holyweek`.
- Custom product page "Stations of the Cross" (keyword "stations" replaces "widget" in 2.3.0, decision D4).
- Play: custom listing "Search: Stations of the Cross".
- Media: event cards from the Tiepolo Stations and a bundled Passion painting.

---

## 2. Holy Week (same release)

### What the person sees

From Palm Sunday to Easter Sunday the Lent row becomes "Holy Week · <day>" and opens **the Holy Week page**
(`nrsv://holyweek`), one section per day, today first, with the other days below:

| Day | Content (all from the Missal 1926 unless noted) |
|---|---|
| Palm Sunday | Gospel of the procession and the Passion (readings card); Fathers on the Passion (Catena); the Collect; the prayer of the blessing of palms |
| Monday – Wednesday | Readings and Fathers; the Collect; St Leo, *On the Passion* (Wednesday sermons) |
| Holy Thursday | Readings and Fathers; the Collect; the Mandatum antiphons ("A new commandment I give unto you…", *Ubi caritas*) |
| Good Friday | Readings (the Passion of St John) and Fathers; the Solemn Prayers; the Reproaches; *Crux fidelis*; the Stations of the Cross |
| Holy Saturday | The *Exsultet*; Fathers on the Resurrection Gospel |
| Easter Sunday | The sequence *Victimae paschali*; the Collect; the Regina Caeli replaces the Angelus from today (exists) |

The day's texts are shown in full with page references; long texts (the *Exsultet*, the Solemn Prayers) are
collapsed to the first lines with "Read all".

### Data and code

- `src/services/lent/data/holyweek.json`: days → sections (title, paragraphs, source page). Same pipeline.
- The Holy Week page reuses the Lent page components. Route `CompanionRoute.holyWeek`, host `holyweek`.
- Note: the Triduum liturgy in the 1926 Missal is the pre-1955 rite (Holy Saturday Vigil in the morning). The texts
  above are the same prayers the Church still uses; the page shows them as prayers for the day, not as a guide to
  the current rite, and each says "From the Roman Missal (1926 English edition)".

### Failure list

- H1. Holy Week dates wrong in a year (Palm Sunday = Easter − 7).
- H2. A Holy Week day has no section, or two days share one.
- H3. Good Friday does not offer the Stations; Easter Sunday still shows Lent.
- H4. Collapsed long texts lose words when expanded (compare with the full JSON).

---

## 3. The Little Office of the Blessed Virgin Mary (iOS 2.5.0 / Android 1.5.0)

### What it is

The short office of Our Lady prayed by lay people and religious for centuries: eight hours (Matins, Lauds, Prime,
Terce, Sext, None, Vespers, Compline), each with a hymn, psalms with antiphons, a chapter, versicles and a prayer.
It changes by season (three forms: from Advent to Christmas; from Christmas to the Purification; the rest of the
year) and Matins changes by weekday (three sets of psalms). The 1915 book also has the Office of the Dead.

### What the person sees

- **Pray tab:** a "Little Office of Our Lady" row; Today shows "Pray the Hour: <hour>" by the time of day (Lauds
  until 9:00, Terce 9–12, Sext 12–15, None 15–18, Vespers 18–21, Compline after 21:00; Matins and Prime from the
  hour list).
- **Hour screen:** the hour, built for today's season and weekday, as one scrolling text: V./R. lines in the tint
  colour, psalm verses in lines, antiphons marked. **English only** in the first release (decision O1); the Latin
  can come in a later update from the same book. Read aloud works as in the reader.
- **Office of the Dead:** a row in the same section (and featured in November).
- Free, offline. No new purchase.

### Data and code

- `src/services/office/data/little-office.json`: parts (hymns, antiphons, psalms, chapters, versicles, prayers) with
  ids, English text and page references (a `latin` field is left empty for a later update); and `hours`: for each hour, the ordered list of part ids per season and
  weekday. One builder function (shared logic in JohnCore and Android) assembles an hour for a date.
- Season rules (from the book's rubrics, quoted in the source notes): Advent form from the first Sunday of Advent to
  24 Dec; Christmas form from 25 Dec to 2 Feb; ordinary form otherwise. Matins psalms: Sunday, Monday, Thursday;
  Tuesday, Friday; Wednesday, Saturday.
- Pipeline volume: about 390 pages, Latin and English side by side. OCR and
  proofread only the English pages, in full against the images; check every psalm against the app's Douay-Rheims.

### Failure list

- O1. An hour is missing a part or repeats one.
- O2. The wrong seasonal form for 1 Dec, 24 Dec, 25 Dec, 2 Feb, 3 Feb.
- O3. The wrong Matins psalms for a weekday.
- O4. A psalm differs from the Douay-Rheims without a note that the book differs.
- O5. "Pray the Hour" picks the wrong hour at the boundaries (8:59, 9:00, 21:00).
- O6. A part has no English text or no page reference.

---

## 4. "A Year with the Fathers" (iOS 2.3.0 / Android 1.3.0 if it fits, else 2.4.0 — decision Y1)

### What it is

A 365-day reading plan through the Fathers library: one reading a day, 5–10 minutes (about 800–1,600 words), in
order through the year. It turns the library from a shelf into a daily guide and gives Today a reason to open the
library every day.

### How the readings are chosen (no text of our own)

The text is always the Fathers' own; the app only chooses the order. The choice follows the Church where it can:

1. **Seasons:** Advent: the Catena Aurea on the Infancy Gospels; Lent: St Leo's Lenten sermons, then St Augustine,
   *Confessions*; Holy Week: Leo *On the Passion*, Chrysostom on the Passion; Easter: Augustine, *Tractates on John*;
   Pentecost: Basil, *On the Holy Spirit*.
2. **The rest of the year:** whole classic works read straight through in daily portions: the *Didache* and the
   Apostolic Fathers (start), Augustine's *Confessions*, Athanasius *On the Incarnation*, Gregory the Great
   *Pastoral Rule*, Cyril of Jerusalem's *Catecheses*, Ambrose *On the Mysteries*, Benedict-era Cassian
   *Conferences* (selections), Vincent of Lérins *Commonitory*.
3. **A plan file** `src/services/works/data/year-plan.json`: 365 entries `{day, workId, sectionIndex, fromParagraph,
   toParagraph, words}`, generated by a script from the library and reviewed by hand; a test checks that every entry
   exists in `works.db`, that each day is 500–2,000 words, and that no reading repeats.

### What the person sees

- **Start:** "A Year with the Fathers" card in the library and on Today until started. Start any day; the plan
  counts days from the start date (Day 1 = Didache). Option to start on the first Sunday of Advent to follow the
  Church's year (then the seasonal blocks fall in their seasons).
- **Today:** "Day 37 · St Augustine, Confessions, Book II" with a progress ring; opens the reading at the right
  paragraph in the library reader; "Mark as read".
- **Plan page:** all 365 days by month, read days ticked, catch-up ("You are 3 days behind: read today's or catch
  up").
- **Reminder:** optional daily notification at a chosen time (local notification).
- **Price:** the first 7 days are free (they use free sections: Apostolic Fathers, *Confessions* opening). Day 8 on
  needs the Fathers library; Day 8 shows the unlock page with "Continue the year". Grandfathered users have it all.
- Progress stays on the device (and in iCloud key-value storage on iOS, as reading progress does today).

### Failure list

- Y1. A plan entry points to a section or paragraph that does not exist.
- Y2. A day is under 500 or over 2,000 words.
- Y3. Day counting wrong across time zones and daylight-saving changes; a missed day moves the plan.
- Y4. A locked user can read Day 8 without the purchase; a purchased user sees the unlock page.
- Y5. The free days use a locked section.
- Y6. Smaller-download build: the free 7 days must be in the in-app sample database, not the downloaded pack.

---

## Release plan

| Release | Submit by | Contents |
|---|---|---|
| 2.2.1 / 1.2.1 | 20 Nov 2026 | (in progress) Luke and John Catena, approved prayer texts, Advent wreath |
| **2.3.0 / 1.3.0** | **8 Jan 2027** | **Lent, Holy Week, Stations of the Cross**; readings data through 2028; "A Year with the Fathers" (if Y1 = early); smaller download; Mac; Android parity |
| 2.4.0 / 1.4.0 | 22 Feb 2027 | Spanish; "A Year with the Fathers" (if Y1 = later) |
| **2.5.0 / 1.5.0** | **16 Apr 2027** | **The Little Office and the Office of the Dead** |

### Work order for 2.3.0 (about 6 weeks)

| Week | Work |
|---|---|
| 1 (from 9 Nov) | Missal pages: OCR + proofread 46 Lent collects and the Holy Week texts; Stations text and the 14 paintings; content-sources entries |
| 2 | LentCalendar (iOS, Android) with tests L1–L7, H1–H4; JSON data; staging |
| 3 | Lent page, Holy Week page, Stations guide, Today rows, routes, deep links (iOS) |
| 4 | Same on Android; readings data through 2028 |
| 5 | A Year with the Fathers: plan script, plan file review, Today card, plan page, reminder, unlock gate (Y1–Y6) |
| 6 | UI tests, simulator and emulator checks (Lent dates, Good Friday, Easter, largest text, dark mode), store media, In-App Events and product pages drafted |

### Little Office (2.5.0, about 5–6 weeks, after Spanish)

| Week | Work |
|---|---|
| 1–2 | OCR and proofread the English pages; psalm checks against the Douay-Rheims |
| 3 | JSON structure and builder with tests O1–O6 |
| 4 | Hour screen, Pray tab and Today rows (iOS) |
| 5 | Android |
| 6 | Office of the Dead; tests; store text |

## Decisions (Anton, 25 October 2026)

- **L1. Yes.** St Leo's 14 sermons on Lent and the Passion (sections 191–204) are free from Ash Wednesday to
  Easter Sunday, as a seasonal sample of the library.
- **Y2. 7 free days** in "A Year with the Fathers"; Day 8 on needs the Fathers library.
- **O1. English first.** The Little Office ships in English only; the Latin may follow in a later update.
- **Y1. Open:** ship "A Year with the Fathers" in 2.3.0 (January, adds about a week) or in 2.4.0 with Spanish?
  (Recommended: 2.3.0.)
