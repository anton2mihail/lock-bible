# Store text drafts — week 1 (2026-10-23)

Part A1 of `store-conversion-and-first-unlock-plan.md`. Drafts only. Anton saves each field in App Store Connect himself.

## Correction to the plan: what can change without a release

Only **Promotional Text** can change on a live version. Description, keywords, subtitle, name and category are locked on 2.0.3 and save with the next version. So:

| Field | When it can be saved |
|---|---|
| Promotional text | **Now** |
| Description, keywords, subtitle, name, category | With 2.1.0 (prepare them in the 2.1.0 version page) |

The description and keywords below are written for the 2.1.0 name and subtitle.

## Live values read on 2026-10-23

| Field | Live value | Chars |
|---|---|---|
| Name | John 1:1 - Lock Bible | 21 |
| Subtitle | Daily Scripture, Fully Offline | 30 |
| Promotional text | (empty) | 0 |
| Keywords | `catholic,bible,verse,scripture,prayer,widget,lockscreen,search,bookmark,notes,offline,devotional` | 96 |

Problems with the live keywords: "catholic" and "bible" are already in the name, so they waste 15 characters. "search", "bookmark" and "notes" are features, not things people type to find a Catholic app.

## 1. Promotional text — save now (155 / 170)

> The Catholic Bible, the Rosary, today's Mass readings, the saints and 15 million words of the Church Fathers. Offline. No account, no ads, no subscription.

Spanish, if a Spanish localization exists in App Store Connect (186 chars, too long; use this 158-char version):

> La Biblia católica, el Rosario, las lecturas de hoy, los santos y 15 millones de palabras de los Padres de la Iglesia. Sin conexión, sin cuenta, sin anuncios.

## 2. Name and subtitle — with 2.1.0

| Field | Draft | Chars |
|---|---|---|
| Name (D1) | John 1:1 - Catholic Bible | 25 |
| Subtitle | Rosary, Mass Readings & Saints | 30 |

The subtitle changed from the plan's "Catholic Bible, Rosary, Saints". With D1 approved, "Catholic Bible" is already in the name. Apple indexes name and subtitle together, so the subtitle should add new words, not repeat them.

## 3. Keywords — with 2.1.0 (97 / 100)

```
douay,vulgate,novena,chaplet,church fathers,augustine,aquinas,confession,prayer,widget,lockscreen
```

- Not repeated: john, catholic, bible (name); rosary, mass, readings, saints (subtitle).
- "lockscreen" keeps the old searches that found "Lock Bible" after the name change.
- Dropped from the live set: verse, scripture, search, bookmark, notes, offline, devotional.
- Before saving, Anton can check popularity of "douay", "novena" and "church fathers" in Apple Search Ads (free to look, spend nothing).

## 4. Description — with 2.1.0 (2,245 / 4,000)

The first three lines show before "more". They say what the app is.

```
A complete Catholic Bible, the Rosary, today's Mass readings and the saints, on your iPhone and iPad. Everything works offline. No account, no ads, no subscription.

THE BIBLE
• Three Catholic editions, with the deuterocanonical books: the World English Bible Catholic Edition, the Douay-Rheims and the Clementine Vulgate in Latin
• A reader that sets Scripture like a book: paragraphs, psalms and poetry in lines, your choice of typeface, size and spacing
• Search every verse in every edition, even without a connection
• Bookmarks, highlights and private notes, on your device or synced to your own iCloud if you choose

PRAYER
• The Rosary with all four sets of mysteries, each with a public-domain painting
• The Rosary of the Seven Sorrows and the Chaplet of Divine Mercy
• 27 novenas with sources, nine-day progress and your intentions
• A library of everyday prayers: Morning Offering, Angelus, Regina Caeli, Anima Christi, St. Michael, St. Patrick's Breastplate and more
• A guided Lectio Divina and an examination of conscience for Confession (your notes clear when you leave)

THE CHURCH YEAR
• Today's Mass readings on the United States Roman calendar, opened in their full chapter
• The saint of the day from the Vatican News calendar and the Ruthenian Byzantine Catholic calendar
• My Saints: save the saints you love, keep private intentions, and prepare for their feast days with a novena and an optional reminder

THE FATHERS AND DOCTORS
• 26 authors, 271 works, 15 million words, all offline: Augustine complete, the Summa Theologica of St. Thomas Aquinas, John Chrysostom, Jerome, Ambrose, Athanasius, Gregory the Great and more
• Open a chapter of Scripture and see which Fathers wrote on it

ON YOUR LOCK SCREEN
• A verse widget for the Lock Screen and Home Screen that changes as often as you choose, from every 10 minutes to once a day
• My Saint widgets with sacred art

PRIVATE BY DESIGN
• No account or sign-in
• No ads and no tracking
• Your notes, highlights and intentions stay private: on your device, or in your own iCloud if you turn on sync

Reading references are bundled for 2026 and 2027. For the exact lectionary wording, the app links to the USCCB. Local calendars can differ.

All artwork is public domain.
```

## Checks before saving

1. Count each field in App Store Connect's own counter.
2. The description makes no "#1" claim and names no other app.
3. Do not mention NRSV anywhere.
4. If 2.1.0 makes the Fathers library a paid unlock, add one line under THE FATHERS AND DOCTORS before submission: "Read a sample of every work free. Unlock the full library once, with no subscription." The plan keeps the library free for everyone who installed before 2.1.0.
