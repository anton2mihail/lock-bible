# Advent 2026 — store setup (state on 25 October 2026, updated the same day)

Companion to `advent-2026-plan.md`. Nothing here is submitted or published. Each item stops before the submit or
publish button, which stays with Anton.

## Builds

| Platform | Version | State |
|---|---|---|
| iOS | 2.2.0 (31) | Uploaded to TestFlight on 25 Oct (`scripts/native/release-testflight.sh 2.2.0 31`). Not submitted. |
| Android | 1.2.0 (6) | Signed bundle `~/.local/share/john-android/releases/com.john.bible-6-7d45f92acab3.aab` (88 MB). Anton uploads it: the browser upload limit is 10 MB. |

Android 1.2.0 contains everything in 1.1.0 (Fathers unlock with Play Billing). The Play in-app product
`com.nrsv.verse.fathers` still waits for an internal-testing release to be rolled out.

## App Store In-App Event (draft saved 25 Oct, id 6826894210, not submitted)

| Field | Value |
|---|---|
| Reference name | Advent 2026 |
| Event name (≤30) | Advent with the Fathers |
| Short description (≤50) | Today's Gospel, with the Church Fathers |
| Long description (≤120) | From Advent Sunday to Christmas Eve: the daily Gospel with the Fathers, and the O Antiphons from 17 December. (The first draft was 122 characters.) |
| Badge | Special Event |
| Event purpose | Appropriate for all users (App Store Connect allows one choice) |
| Priority | Normal |
| Event access | In-App Purchase Not Required |
| Event start / end | 29 Nov 2026 00:00 – 24 Dec 2026 23:59 (Toronto time) |
| Publish start | 15 Nov 2026 |
| Regions | All regions where the app sells |
| Deep link | `nrsv://advent` |
| Event card (16:9) | `marketing/events/advent-2026/event-card-1920x1080.jpg` |
| Event details (9:16) | `marketing/events/advent-2026/event-details-1080x1920.jpg` |

Media: Geertgen tot Sint Jans, *Saint John the Baptist in the Wilderness* (c. 1480–1490), the painting the app
already uses for Advent (`assets/artwork/sources.json`). No text on the images.

The event opens the Advent page, so 2.2.0 must be live before 15 November (the promotion start).

## App Store custom product pages (five drafts saved 25 Oct, "Ready to Submit", not submitted)

Five pages, each copied from the 2.1.0 product page. Screenshots: iPhone 6.9" set = the page's own slide from
`marketing/screenshots/framed-cpp/iphone-6.9_1320x2868/`, then the six 2.1.0 slides (7 in all); iPad 13" set = its own
slide, then the four 2.1.0 iPad slides (5 in all). Smaller sizes scale down from these.

Keywords on a custom product page can only be chosen from the current version's keyword field (douay, vulgate,
novena, chaplet, church fathers, augustine, aquinas, confession, prayer, widget, lockscreen). The values used:

| Page | Keywords chosen | Deep link |
|---|---|---|
| Douay-Rheims | douay | `nrsv://read?book=JHN&chapter=1&translation=douay-rheims` |
| Latin Vulgate | vulgate | `nrsv://read?book=PSA&chapter=50&translation=vulgate` |
| Rosary | chaplet, prayer | `nrsv://pray/rosary` |
| Saints | novena, prayer | none (`nrsv://saint` without an id does not open My Saints on iPad) |
| Church Fathers | church fathers, augustine, aquinas | none |

To give the Rosary and Saints pages better keywords ("rosary", "saint"), add them to the 2.2.0 keyword field first.

The table below is the original plan (promotional text as entered).

| Page | First slide | Promotional text (≤170) | Keywords (≤100) |
|---|---|---|---|
| Douay-Rheims | `01-douay.png` | The Douay-Rheims Bible with every deuterocanonical book, page by page. Free, offline, no account. | douay,rheims,challoner,catholic bible,deuterocanonical,dr bible |
| Latin Vulgate | `02-vulgate.png` | The Clementine Vulgate beside the Douay-Rheims and the WEB Catholic Edition. Free and offline. | vulgate,latin,clementine,biblia sacra,vulgata,latin bible |
| Rosary | `03-rosary.png` | Pray the Rosary step by step: every set of mysteries, the Seven Sorrows and the chaplets. Offline. | rosary,mysteries,chaplet,divine mercy,seven sorrows,holy rosary |
| Saints | `04-saints.png` | The saint of the day, your own patron saints, their prayers and feast days. | saint of the day,novena,feast,patron saint,saints |
| Church Fathers | `05-fathers.png` | Today's Gospel with the Fathers: the Catena Aurea of St Thomas Aquinas and 26 Fathers and Doctors. | church fathers,augustine,aquinas,catena,chrysostom,summa |

Apple reviews custom product pages separately from app versions. The Fathers page shows a 2.2.0 screen, so submit
it after 2.2.0 is approved.

## Google Play custom store listings (drafts saved on 25 October)

Play has no "Promotional content" (LiveOps) section for this app, so there is no Play equivalent of the In-App
Event. Search-keyword custom listings are the Play equivalent of the custom product pages.

| Draft | Keywords | Short description | First screenshot |
|---|---|---|---|
| Search: Douay-Rheims | douay rheims, douay rheims bible, douay-rheims, catholic bible douay rheims, challoner bible | The Douay-Rheims Catholic Bible, page by page. Free and fully offline. | `c1-douay.png` |
| Search: Latin Vulgate | latin vulgate, vulgate bible, latin bible, clementine vulgate, biblia sacra, vulgata | The Latin Vulgate beside the Douay-Rheims. Free and fully offline. | `c2-vulgate.png` |
| Search: Rosary | rosary, holy rosary, catholic rosary, rosary app, mysteries of the rosary, divine mercy chaplet, seven sorrows rosary | Pray the Rosary step by step, with the chaplets and novenas. Offline. | `c3-rosary.png` |
| Search: Saints | saint of the day, catholic saints, patron saints, lives of the saints, feast days, novena | The saint of the day and your patron saints, with prayers and feast days. | `c4-saints.png` |
| Search: Church Fathers | church fathers, early church fathers, catena aurea, summa theologica, augustine confessions, aquinas, chrysostom homilies | Today's Gospel with the Church Fathers. Augustine, Aquinas and more. | `c5-fathers.png` |

Each draft duplicates the default listing (name, full description, icon, feature graphic), then puts its own
screenshot first and the six standard screenshots after it. Screenshots: `assets/play-store/screenshots-cpp/`
(provenance in that folder). Rollout is Play's default of 50% of the keyword audience; Anton can raise it before
publishing. The Church Fathers draft shows a 1.2.0 screen, so publish it after 1.2.0 is live.

## What Anton does

1. Upload the Android 1.2.0 (6) bundle.
2. Submit 2.2.0, the event and the product pages, and publish the Play drafts, when ready.
