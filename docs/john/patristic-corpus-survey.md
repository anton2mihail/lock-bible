# The Fathers and Doctors: what is free, and what we can ship

Survey date: 21 September 2026. Method: fourteen agents — seven surveying groups
of authors and sources, seven attacking the first seven's claims. Every licence
conclusion below survived an adversarial pass whose brief was to refute it.

Machine-readable output: [`scripts/works-sources.json`](../../scripts/works-sources.json).

## Status: built

The recommendation below was carried out on 21 September 2026. The app now
ships 26 authors, 275 works and 15.2 million words offline, and the works moved
from bundled JSON to a SQLite asset first, as recommended. See
[works-pipeline.md](works-pipeline.md) for how it is built and what was
deliberately excluded.

Shipped from the tiers below: Augustine complete (3.91m words including the
*Confessions* and 168 letters, all 150 Psalms mapped), the Dominican *Summa* (2.56m), Chrysostom (2.48m), and twenty-three
more — Tertullian, Athanasius, Jerome, Gregory of Nyssa, Ambrose, Origen,
Clement of Alexandria, Cassian, Gregory the Great, Eusebius, Cyprian,
Lactantius, Basil, Gregory Nazianzen, Irenaeus, Hippolytus, Ephraim, Leo the
Great, Cyril of Jerusalem, Justin Martyr, the Apostolic Fathers, John Damascene
and Vincent of Lérins.

Not yet taken: everything in tier 2 outside the ANF/NPNF corpus — Teresa, John of the Cross, Francis de Sales,
Liguori, Bernard, Catherine of Siena, the *Imitation*, the Rule of St Benedict —
which come from Gutenberg and archive.org rather than CCEL and so need a second
ingester.

## The short answer

**Most of it is free, and far more than expected.** 112 works are ready to
ingest as they stand — 17.9 million words, from 28 of the 37 Doctors of the
Church plus the Ante-Nicene Fathers. That is seven times the Chrysostom corpus
already shipping.

Eight Doctors cannot be represented by their own words at all, and a ninth
(Bonaventure) only after an OCR pass. That is a hard fact about English
translation history, not a gap we can close with effort.

## The blocker is delivery, not licensing

Chrysostom's 12.82 MB of JSON became **+37 MB of `main.jsbundle`** — a 2.9×
inflation, because `worksService.ts` imports the JSON, so Metro inlines it as
JavaScript source and Hermes compiles it to bytecode. Measured from the two
IPAs:

| | 1.2.x | 1.3.0 |
|---|---|---|
| `main.jsbundle` | 12.56 MB | 49.56 MB |
| `bible-search.db` (flat asset) | — | 33.00 MB |
| IPA | 16.45 MB | 70.03 MB |

The Bible does not pay this tax: it ships as a SQLite asset, 1:1, memory-mapped
rather than parsed at launch.

At 2.9×, tier 1 alone (58 MB of JSON) would mean a ~220 MB bytecode bundle. As
SQLite the same text is ~58 MB of asset. **The corpus is affordable; the current
container is not.** The road is already built — `expo-sqlite` is a dependency,
[`build-bible-search.mjs`](../../scripts/build-bible-search.mjs) already emits an
FTS5 database into `assets/`, and `DatabaseProvider.tsx` already loads one. A
works database is close to a copy of that script, and it brings full-text search
across the Fathers, which the JSON design cannot offer at any size.

**Recommendation: migrate works to SQLite before adding a single new author.**
Doing it after means migrating twenty times the data.

## What to add, in order

### Phase 1 — the commentary layer (~2.55M words)

The app's real differentiator is the chapterIndex: open Matthew 5, get
Chrysostom on Matthew 5. These extend that to 22 books of Scripture.

| Work | Author | Words | Maps to |
|---|---|---|---|
| Expositions on the Book of Psalms | Augustine | 654k | PSA 1–150 |
| Tractates on the Gospel of John | Augustine | 398k | JHN |
| Catena Aurea — Matthew | Aquinas | 408k | MAT |
| Sermons on Selected Lessons of the NT | Augustine | 295k | 14 NT books |
| Commentary on Luke | Cyril of Alexandria | 269k | LUK |
| Catena Aurea — Mark | Aquinas | 140k | MRK |
| Commentary on John (Bks 1–10) | Origen | 114k | JHN |
| Commentary on Matthew (Bks 13–22) | Origen | 103k | MAT |
| Ten Homilies on 1 John | Augustine | 62k | 1JN |
| Our Lord's Sermon on the Mount | Augustine | 54k | MAT 5–7 |
| The Hexaemeron | Basil | 54k | GEN 1 |

Augustine's Psalms is the single biggest win available anywhere: 153 sections
titled plainly `Psalm I`–`Psalm CL`, so the mapping is near-trivial and should
beat the 480/489 achieved for Chrysostom. The Psalms are what people actually
pray.

The Catena Aurea deserves special note — it is verse-by-verse and stitched from
the Fathers themselves, so it is the closest thing in existence to this app's
own feature, written in 1263.

### Phase 2 — the famous books (~1.1M words)

What users will search for by name: Augustine's *Confessions* (126k), *The
Imitation of Christ* (67k), Teresa's *Interior Castle* (70k) and *Life* (165k),
John of the Cross's *Ascent* (115k) and *Dark Night* (200k), Francis de Sales's
*Introduction to the Devout Life* (120k), the *Rule of St Benedict* (21k),
Catherine of Siena's *Dialogue* (91k), Anselm's *Prayers and Meditations* (70k),
Clement and Ignatius (28k).

Highest recognition per megabyte in the whole survey. *Confessions* alone is
0.7 MB and is the most-read Christian book after the Bible.

### Phase 3 — bulk (~14M words)

The complete ANF (10 vols) and NPNF series 1 and 2 (28 vols) from CCEL, plus
Aquinas's *Summa Theologica* (2.6M), Gregory's *Moralia on Job* (800k), Cyril on
John (520k), Alphonsus (3.1M across the Centenary Edition).

## What we cannot have

Nine Doctors have no public-domain English text. Worth stating plainly, because
the instinct is to assume a search would find one:

| Doctor | Why |
|---|---|
| **Isidore of Seville** | The *Etymologies* was first fully Englished in 2006 (CUP). |
| **Peter Chrysologus** | Both sermon translations are 1953 and 2004–05. |
| **Peter Damian** | Only Blum/Resnick, CUA Press 1989–2005. |
| **Hildegard of Bingen** | Every translation postdates 1929, without exception. |
| **Anthony of Padua** | Only Spilsbury, from the 1979 critical Latin edition. |
| **Peter Canisius** | Nothing transcribed; only early-modern page images. |
| **Lawrence of Brindisi** | No English translation exists of anything. |
| **Gregory of Narek** | Declared a Doctor in 2015; reception entirely modern. |
| **Bonaventure** | Page images only — recoverable, but needs an OCR pass. |

Also unavailable and individually painful: **Origen's ~200 homilies** on the Old
Testament (the costliest single loss to the chapterIndex), **Gregory the Great's
Forty Gospel Homilies**, **Bede's biblical commentaries** (his history is free,
his exegesis is not), **Ambrose's exegesis**, Hippolytus's *Apostolic Tradition*,
the *Philokalia*, Maximus the Confessor, John Climacus, and Symeon the New
Theologian — the Byzantine tradition was largely not translated during the
public-domain window.

## Licence traps found

The adversarial pass produced 7 fatal findings and 49 corrections. Three
patterns are worth carrying forward into the ingestion script:

1. **Publication year is the wrong test.** W. K. Lowther Clarke's 1916 *Life of
   St Macrina* looks safely Victorian and is PD in the US — but Clarke died in
   1968, so it stays in copyright until 2039 everywhere that uses life+70. Our
   release is worldwide. The test is the **translator's death date**, not the
   imprint. Everything else in the survey is 1847–1899 and nowhere near the
   line; record the jurisdiction each claim rests on rather than leaving it
   implicit.
2. **"Freely circulating" is not "public domain."** Origen's *On Prayer* on
   tertullian.org carries an explicit "copy freely" grant, but it descends from
   an unpublished typescript, newly edited in the modern era, and the person
   granting permission is not the rightsholder. Dropped.
3. **Check the scan, not the catalogue entry.** Teresa's *Book of the
   Foundations* is catalogued complete; the only machine-readable layer holds
   32k of ~100k words and stops mid-sentence at page 82. Bellarmine on the
   Psalms is 495k words, not the 150k claimed — and is raw OCR.

On sources: **CCEL is the one to use.** All 38 ANF/NPNF volumes, each carrying
`<DC.Rights>Public Domain</DC.Rights>` in its own ThML header, predictable
unauthenticated URLs, `robots.txt` disallowing nothing at a 10-second crawl
delay. There is no bulk API — none is needed. New Advent asserts its own
copyright over the same translations; Gutenberg does not carry the series at
all; Wikisource is 50% complete and unevenly proofed; no openly-licensed
structured patristic dataset exists on GitHub.
