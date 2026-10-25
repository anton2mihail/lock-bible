# Finish Tier 1 and Tier 2 — plan (25 October 2026)

Source list: `roadmap-ideas-2026-10-25.md`. Status at the start: iOS 2.2.0 (31) and Android 1.2.0 (6) are in
review with the Advent event, five App Store product pages and five Play custom listings.

Rules that stay: no account, no ads, no subscription, no analytics, **no server**. Every text is quoted from a
named public-domain source; the app adds no prayers of its own.

## The download question: iCloud or a server?

Neither. Both stores host extra app data for free:

- **iOS: Apple-hosted Background Assets** (asset packs). Apple stores the packs (up to 200 GB per app), they are
  uploaded and reviewed with the app version in App Store Connect, the system downloads them, and they work with
  no iCloud account. The app's deployment target is already iOS 26, which this needs.
- **Android: Play Asset Delivery.** Google stores the asset packs inside the app bundle upload and delivers them.

iCloud (CloudKit public database) could also hold files, but it has quotas, needs its own schema and upload
step, and is not tied to app versions. It is the wrong tool for this.

## Where the 147 MB goes today

| Part | Size | Plan |
|---|---|---|
| Fathers library (`works.db`) | 44 MB | Asset pack; a small sample database stays in the app |
| Bible search index (`bible-search.db`) | 33 MB | Rebuild smaller (the verse text is already in the Bible files) |
| Widget verse pools (`JohnSharedResources` framework) | 17 MB | One copy, shared by the app and the widget (checked 25 Oct; an earlier note here called it a duplicate, which was wrong). Measure whether a compressed format helps |
| Paintings | 18 MB | Re-encode at the size the screen needs |
| Bible text (3 editions) | 15 MB | Stays |
| Calendar, catalogs, fonts | 2.4 MB | Stays |

Target: about 65–75 MB in the app, down from 147 MB.

## Releases

| Release | Submit by | Contents |
|---|---|---|
| iOS 2.2.1 / Android 1.2.1 | 20 Nov 2026 | Catena Aurea on Luke and John; Advent wreath prayer (only a Church-approved text); content audit fixes; store text ("7 novenas") |
| iOS 2.3.0 / Android 1.3.0 | 8 Jan 2027 | Lent; smaller download; Mac; the rest of Android parity |
| iOS 2.4.0 / Android 1.4.0 | 22 Feb 2027 | Spanish, fully |

Advent starts 29 Nov. Luke 1 is the Gospel from 17 to 24 Dec and John 1 on Christmas Day, so Luke and John must
be live by 17 Dec. Ash Wednesday is 10 Feb 2027 and Easter 28 Mar 2027.

## Tier 1 — what is left

### 1. Catena Aurea on Luke and John (2.2.1)

- Source: the Oxford 1841–45 (Newman) translation, public domain. Clean HTML exists at isidore.co
  (`CALuke.htm`, `CAJohn.htm`, about 980,000 characters each). Before use, read the site's terms; if they do not
  allow reuse, OCR the archive.org scans of the 1843 Oxford volumes instead (adds about a week).
- Extend `scripts/build-catena.mjs` to the HTML input. Same checks: chapter counts (Luke 24, John 21), verse
  coverage, gap limit.
- Result: every Gospel day of the year gets a verse-level Father's comment on Today.

### 2. Advent wreath prayer (2.2.1, conditional)

- The usual modern blessing (USCCB *Book of Blessings*, 1989) is copyrighted. Use it only if a public-domain
  text is found: for example the Sunday Collects of Advent from a pre-1927 English missal, one per candle.
- If no clean source is found by 10 Nov, drop it; the Advent page already has Rorate caeli and the O Antiphons.

### 3. Lent (2.3.0)

- **Lent page** (`nrsv://lent`), like the Advent page: the week of Lent, today's Gospel with the Fathers, the
  Seven Penitential Psalms and the Miserere (Douay-Rheims, already in the app).
- **Stations of the Cross** by St Alphonsus Liguori (public domain English), 14 stations, each with a
  public-domain painting (for example the Tiepolo *Via Crucis*, San Polo, Venice, 1747–49). Shown on Fridays of
  Lent on Today.
- **In-App Events.** An event can last at most 31 days, so two events:
  1. "Lent with the Fathers": 10 Feb – 12 Mar 2027, promotion from 27 Jan.
  2. "Holy Week with the Fathers": 21 – 28 Mar 2027.
- A custom product page "Stations of the Cross". Its keyword must be in the version's keyword field first
  (field is 96/100 now; decision D4).

### 4. Ratings

Done as far as the rules allow: the in-app prompt shipped in 2.1.0. The outreach rules forbid asking anyone
for a review, so there is no outreach step.

## Tier 2

### 5. Spanish, fully (2.4.0)

1. **Bible.** Torres Amat (1823–25, public domain). No clean digital text was found; scans exist on Spanish
   Wikisource and archive.org (1836 Paris edition, no known copyright). Work: OCR, then check every chapter's
   verse count against the Douay-Rheims and the Vulgate, which use the same numbering. This is the largest risk;
   the source audit is the first task (by 15 Nov). Fallback: Scío de San Miguel (1790s), same check.
2. **Interface.** Today 82 iOS strings have Spanish; most screens pass plain `String` titles that are not
   localized, and Android has no `values-es`. Move every visible string into the String Catalog (iOS) and
   `strings.xml` (Android), then translate.
3. **Prayers.** The traditional Spanish texts of the Padre nuestro, Ave María, Gloria, Credo, Salve and the
   Rosary mysteries, quoted from a named public-domain catechism (Astete or Ripalda). Novenas without a
   public-domain Spanish source stay in English, and the store text says so.
4. **Saints.** Use Vatican News' Spanish saint-of-the-day pages, the same source as the English data.
5. **Fathers library** stays English (no public-domain Spanish translations at this scale). The store says so.
6. **Store.** Spanish (Mexico) and Spanish (Spain) listings and screenshots on both stores; a Spanish product
   page and Play custom listing ("Biblia católica").
7. **Review.** A native speaker proofreads the interface and store text before release (decision D1).

### 6. Smaller download (2.3.0)

1. Widget verse pools (17 MB) are already a single shared copy. Try a compressed format; keep it only if the
   widget stays within its memory limit.
2. Rebuild `bible-search.db` as an external-content FTS index over the Bible text the app already has. Measure;
   keep only if search results and speed do not change (search tests must pass unchanged).
3. Split the library:
   - **In the app:** `works-sample.db` with every free section (first section of each work, the Apostolic
     Fathers, the Confessions) and all four Catena Aurea volumes, because Today shows Catena excerpts to
     everyone.
   - **Asset pack "fathers-library":** the full `works.db`. It downloads only for people who have the library
     (purchase, restore or grandfathered), in the background, then stays offline. Free users never download it.
   - While it downloads, a locked-looking section shows "Downloading the library… 40%" instead of the unlock page.
4. Re-encode paintings at the largest size any screen shows.
5. Store text changes from "Everything works offline" to "Everything works offline; the full Fathers library
   downloads once after you unlock it."
6. Test with TestFlight asset packs (iOS) and internal testing (Android): new install, update from 2.2.x with the
   library, purchase, restore, airplane mode after download.

### 7. Mac (2.3.0)

- The iPad app already runs on Apple silicon Macs and shows "Not verified for macOS". Check on this Mac:
  paged reader with keyboard and trackpad, window resizing, the purchase and restore, read aloud, notifications.
  Widgets and the Lock Screen do not apply on Mac; hide those Settings rows there.
- Then mark it verified in App Store Connect so it appears in Mac App Store search.

### 8. Android parity and listing (2.3.0)

- Audit the 2.1.1 iOS interface changes against Android one by one (row chevrons, testament jump bar, hidden
  empty progress rings, Settings pages, one-line Fathers footer, tablet widths, unlock art) and port the missing
  ones. Advent screens are already aligned.
- New Play screenshots from the framed set; Play description leads with the Fathers library.

## Checks for every release

- Failure list first, then unit tests (JohnCore, Android unit tests), the affected UI tests, simulator and
  emulator checks in light, dark and the largest text size.
- One booted simulator or emulator at a time; delete build output after each release.
- Submission only on Anton's ask.

## Content rule (Anton, 25 Oct 2026)

Every prayer and every other religious text in the app must be **approved by the Catholic Church** and
**written by real people**: saints, popes, priests, religious, or the Church's liturgical books. Acceptable
evidence, one of: a liturgical book of the Church (Missal, Breviary, Ritual); an imprimatur or nihil obstat in the
edition quoted; a saint, Doctor or Father of the Church as author; a papal or episcopal text. No prayer text
written or translated by the app or by an AI. The app's own words are limited to interface text (titles, buttons,
short explanations of where a text comes from).

Consequences:
- **Content audit first** (2.2.1): list every prayer, novena, guide and teaching text with its author, the
  edition quoted, its approval and its copyright status. Anything that fails is replaced from an approved source
  or removed. Record in `docs/john/content-sources.md`.
- **Advent wreath prayer:** only a Church-approved text (for example the Sunday Collects of Advent from the Roman
  Missal, in an English missal with an imprimatur, published before 1931 so it is public domain in the US).
- **Spanish prayers:** only approved Spanish texts (catechisms of Astete or Ripalda, Spanish missals or
  devotionals with an imprimatur). No translation by us. Anything without such a source stays in English.
- **Spanish interface:** translated by us (D1), then a correctness pass.

## Decisions (answered 25 Oct 2026)

- **D1.** Spanish interface: best single translation now, then a correctness pass. (Prayers: see the content rule.)
- **D2.** Advent wreath: only a text the Church approves. Yes.
- **D3.** Library pack downloads only for people who own the library. Yes.
- **D4.** Keyword field for 2.3.0: swap "widget" for "stations". Yes.

## Decisions for Anton (original wording)

- **D1.** Who proofreads the Spanish? (Recommended: one paid native-speaker review of UI and store text.)
- **D2.** Advent wreath prayer only with a public-domain text, else drop it. (Recommended: yes.)
- **D3.** Library pack downloads only for people who have the library. (Recommended: yes.)
- **D4.** Keyword field for 2.3.0: swap "widget" or "lockscreen" for "stations"? (Recommended: swap "widget".)
