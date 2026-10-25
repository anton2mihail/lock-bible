# Before Advent 2026 — detailed plan

Approved by Anton on 25 October 2026 ("plan in detail and then execute all of the before advent suggestions").
Source ideas: `roadmap-ideas-2026-10-25.md`, Tier 1. Advent begins **Sunday 29 November 2026** (Year B).
Release: **iOS 2.2.0 (31)** and **Android 1.2.0 (6)**, built on branch `advent/2.2.0` (from `android/1.1.0`,
which already holds 2.1.0, the 2.1.1 interface polish and Android 1.1.0).

## 1. Today's Gospel with the Fathers (Catena Aurea)

**Source.** St Thomas Aquinas, *Catena Aurea*, London: J.G.F. and J. Rivington, 1842 (Newman's edition).
Public domain by publication date. Matthew (`catena1`) and Mark (`catena2`) are clean text on CCEL, the source
the library already uses, fetched with the same User-Agent and 10-second crawl delay into `.ccel-cache/`
(gitignored). Luke and John exist only as page scans; they need OCR and a proofread, so they are **not** in this
release. CCEL's metadata names "William Whiston" as translator; that is a known CCEL error
(`scripts/works-sources.json`). The app credits the 1842 Newman edition.

**Parse** (`scripts/build-catena.mjs`, new):
- "Chapter N" lines start a chapter. Matthew 11 has no heading in the CCEL text, so a verse number that restarts
  at 1 also starts the next chapter. Check: Matthew has 28 chapters, Mark 16.
- A section ("lectio") is a run of numbered Gospel verse lines (`N.` or `N-M.`), a separator line, then the
  Fathers' comments, each beginning with an attribution ("Jerome:", "Aug.:", "Chrys.:").
- Each section becomes one reader section: title "Matthew 2:1–2", first paragraph the Gospel text in quotation
  form, then one paragraph per comment. Editorial notes in square brackets stay as they are.
- Output: `src/services/works/data/aquinas/catena-aurea-matthew.json` and `catena-aurea-mark.json`, added to the
  Aquinas manifest with `book: "MAT"` / `"MRK"` (kind: commentary), and the Aquinas `chapterIndex.json` filled with
  one entry per section, including `fromVerse` and `toVerse`. `build-works-db.mjs` packs them as usual.

**Today card** (iOS and Android). Under today's Gospel: "The Fathers on today's Gospel", the first comment of the
section that covers the Gospel's first verse (with the Father's name), and a button "Read the Fathers on this Gospel"
that opens that section. The excerpt is free on Today. The full section follows the library rule (first section free,
the rest with the purchase). Days with a Luke or John Gospel show the card only when the existing chapter
commentary has a Father for that chapter, with the same button into it.

**Reference parsing.** The bundled readings give references like "Matthew 9:35–10:1, 5a, 6-8" and
"Luke 7:18b-23". Use the book, the chapter and the first verse number; strip letters (5a, 18b).

## 2. Advent (in the app)

- **Advent page** (`nrsv://advent`, also from a Today card from 29 Nov to 24 Dec): the week of Advent, today's
  Gospel with the Fathers, *Rorate caeli* (Isaiah 45:8, Douay-Rheims), and the O Antiphons.
- **O Antiphons**, 17–23 December, one per evening, Latin and English. English from the Catholic Encyclopedia
  article "O Antiphons" (1911, public domain). From 17 December the Today card shows that day's antiphon.
- **Deep link** `nrsv://advent` for the In-App Event and notifications. Old links keep working.
- No new prayers written by us: every text is quoted from a named public-domain source.

## 3. App Store In-App Event

- Name "Advent with the Fathers" (≤30). Short description "Today's Gospel, with the Church Fathers" (≤50).
  Long description (≤120): "From the first Sunday of Advent to Christmas Eve: the daily Gospel with the Fathers,
  and the O Antiphons from 17 December."
- Badge: Special Event. Event start 29 Nov 2026 00:00, end 24 Dec 2026 23:59, all regions where the app sells.
  Publish (promotion) start 15 Nov 2026. Deep link `nrsv://advent`.
- Media: event card 1920×1080 and details 1080×1920, made from the bundled Bloemaert painting and app screens.
- Requirement: 2.2.0 must be live before 29 November, because the event opens the Advent page.

## 4. Custom product pages

Five pages, each with its own first screenshot, promotional text and keywords (App Store Connect assigns keywords
to a custom product page):

| Page | First screenshot | Keywords (not in name or subtitle) |
|---|---|---|
| Douay-Rheims | Douay reader page | douay, rheims, challoner, kjv catholic |
| Latin Vulgate | Vulgate reader page | vulgate, latin, clementine, biblia sacra |
| Rosary | Rosary guide with painting | rosary, mysteries, chaplet, divine mercy |
| Saints | My Saints / saint of the day | saint of the day, novena, feast |
| Church Fathers | Fathers library + Catena on Today | church fathers, augustine, aquinas, catena |

Screenshots: iPhone 6.9" (1320×2868) and iPad 13" (2064×2752), framed with `marketing/frame-screenshots.py`
(new release set "cpp"). Pages are reviewed separately from app versions.

## 5. Android

Android 1.2.0 (6) gets the Catena data (shared `works.db`/catalog), the Today card, the Advent page and the
`nrsv://advent` route. Android 1.1.0 is still waiting for its internal-testing rollout and in-app product; 1.2.0
includes everything in 1.1.0.

## Checks

- Parser counts: chapters, sections, every verse of Matthew and Mark covered by exactly one section.
- Unit tests for reference parsing and section lookup (failure list first, as the repo requires).
- Simulator and emulator: Today on an Advent date (debug date override), the Advent page, 17 Dec antiphon,
  a Luke day fallback, the locked/unlocked library behaviour, dark mode, largest text size.
- Existing UI test suites that touch Today and Works.

## What needs Anton

- Submitting 2.2.0, the In-App Event and the custom product pages for review (prepared up to the submit button).
- Rolling out Android internal testing (open question from 25 October).

## Timeline

| By | What |
|---|---|
| 31 Oct | Catena data, Today card, Advent page (iOS + Android), tests |
| 3 Nov | 2.2.0 uploaded; event media; CPP screenshots |
| 5 Nov | Submissions prepared for Anton |
| 15 Nov | Event promotion starts (if approved) |
| 29 Nov | Advent begins |
