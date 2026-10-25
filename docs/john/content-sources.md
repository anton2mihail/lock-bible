# Content sources and Church approval (audit of 25 October 2026)

Rule (Anton, 25 Oct 2026): every prayer and religious text must be **approved by the Catholic Church** and
**written by real people** (saints, Fathers, popes, priests, religious, or the liturgical books). Evidence: a
liturgical book, an imprimatur or nihil obstat in the edition quoted, or saint/Father authorship. No text
written or translated by the app or by an AI. Copyright: public domain (in the US, published before 1931) or
licensed.

Status: **OK** = meets the rule, source named. **Re-source** = text is traditional and approved, but the app
names a website or "historic English wording"; quote it from a named approved edition. **Replace** = the
current text or translation does not meet the rule. **Decide** = needs Anton.

## Bible

| Edition | Status | Note |
|---|---|---|
| Douay-Rheims (Challoner) | OK | Approved Catholic translation, public domain |
| Clementine Vulgate | OK | The Church's Latin Bible |
| World English Bible, Catholic Edition | Kept, labelled (D5) | Modern public-domain translation by a private editor; **no imprimatur**. Labelled in Settings and in its attribution line as "Study translation without Church approval (no imprimatur)" |

## Prayers, Rosary and novenas (updated 25 Oct 2026 for 2.2.1)

Every replacement text below was checked word for word against the page scan. Exact texts, pages and scan links:
`docs/john/approved-prayer-texts.md`.

| Item | Source now | Status |
|---|---|---|
| Morning Offering | Lasance, *My Prayer-Book* (1908, Imprimatur Farley), p. 149 | OK |
| Grace before and after meals | *My Prayer-Book* (1908), p. 218 | OK |
| Angelus, Regina Caeli | *The Raccolta* (1910), no. 182 | OK |
| Our Father, Hail Mary, Glory Be, Come Holy Ghost, Eternal rest | Lasance, *With God* (1911, Imprimatur Farley) | OK |
| Act of Contrition (also the confession guide) | *A Manual of Prayers* (Baltimore, 1889), p. 54 | OK |
| Memorare, Sub tuum, Miraculous Medal, Spiritual Communion, Prayer before study, Responsory of St Anthony | *The Raccolta* (1910) | OK |
| Night Prayer; St Michael; Anima Christi; Suscipe; We adore Thee | Roman Breviary (Bute 1879); Lasance 1904; Manual of Prayers; Mullan, S.J.; Robinson, O.F.M. | OK |
| Our hearts are restless; Too late have I loved Thee | Short quotations in *My Prayer-Book* (1908) and Forbes, *Life of St Monica* (Imprimatur 1915). No full Catholic translation before 1931 is scanned | OK (shortened) |
| Let nothing disturb thee | *With God* (1911), p. 156 | OK |
| St Patrick's Breastplate | *Prayers of the Gael* (1915, Imprimatur Edinburgh 1914), stanza 8 | OK |
| Newman | "Lead, Kindly Light" (Anglican, 1833) replaced by "Stay with me", *Meditations and Devotions* (1893) | OK |
| Rosary: Sign of the Cross, Creed, Our Father, Hail Mary, Glory Be | Marchant 1929; *With God* (1911) | OK |
| Rosary: Hail, Holy Queen; Rosary collect | *Manual of Prayers* (1889); *The Missal* (1926 printing, Imprimatur 1921), ending "Through the same." as printed | OK |
| Seven Sorrows: opening, seven invocations, versicle, collect | *The Raccolta* (1910), nos. 230, 232 ("I compassionate thee, sorrowing Mary") | OK |
| St Joseph novena | Lasance, *The Catholic Girl's Guide* (1906), pp. 598–599 | OK |
| St Jude novena | Marchant, O.P., *Life of St. Jude Thaddeus* (Chicago, 1929, Imprimatur Mundelein), pp. 19–21. One misprint corrected: "they aid" → "thy aid" | OK |
| Our Lady of Perpetual Help novena | *With God* (1911), p. 685 | OK |
| St Peregrine | No approved novena before 1931; the Collect of his feast from *The Missal* (1926), p. 1207, prayed for nine days | OK |
| St Thérèse rose novena | Society of the Little Flower | Edition to confirm |
| Advent wreath | The four Sunday Collects of Advent, *The Missal* (1926), pp. 50, 54, 56, 69 | OK (new) |
| **Fatima prayer** (Rosary decades) and **Prayers of the Angel of Fatima** | Approved devotion, but no approved English text before 1931 exists (apparitions approved 1930) | **Decide (D7)** |
| **St Padre Pio novena** | Website, no author. No approved public-domain novena exists (canonized 2002) | **Decide (D7)** |
| **Divine Mercy novena** | St Faustina's *Diary*; the English text is © Marian Press | **Decide (D7)** |

## Guides and teaching

| Item | Status | Note |
|---|---|---|
| Lectio Divina steps | OK | Benedict XVI, *Verbum Domini* 87 |
| Confession guide (native apps) | OK | Catechism, formula of absolution, Act of Contrition, Decalogue, Beatitudes |
| Confession questions in the old Expo code (`src/services/companion/confession.ts`) | Replace / remove | App-written questions. Not used by the native apps; delete from the repo |
| Teachings (5) | OK | Catechism of the Catholic Church quotes |
| Saints of the day | OK | Vatican News |
| Advent: O Antiphons, Rorate caeli, Catena Aurea | OK | Roman Breviary via Dom Guéranger (1870); Douay-Rheims; St Thomas Aquinas |

## Fathers and Doctors library

| Item | Status | Note |
|---|---|---|
| Authors | OK | Fathers and Doctors of the Church |
| Translations | Kept (D6) | Most come from the 19th-century *Ante-Nicene* and *Nicene and Post-Nicene Fathers* series (named scholars, many Anglican or Protestant, no imprimatur). Catholic translations with imprimatur exist only for part of the library |

## Store text

- The App Store description says "27 novenas"; the app has **7**. Fix in the 2.2.1 description.

## Decision still open

- **D7.** The Fatima prayers, the Padre Pio novena and the Divine Mercy novena have no approved English text in
  the public domain. Options: (a) remove them; (b) keep them with the text of a modern approved edition, under a
  licence from its publisher (Marian Press for Divine Mercy; a Capuchin or diocesan edition for Padre Pio; the
  Shrine of Fatima for the Fatima prayers).

## Decisions (Anton, 25 Oct 2026)

- **D5.** Keep the World English Bible Catholic Edition, labelled as a study translation without Church approval.
- **D6.** Keep the Fathers library translations: the texts are the Fathers' own, the translators are named scholars.
