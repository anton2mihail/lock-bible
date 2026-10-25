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
| World English Bible, Catholic Edition | **Decide (D5)** | Modern public-domain translation by a private editor; **no imprimatur**. It is the default edition and the source of the widget verses |

## Prayers (prayer library, 28)

| Prayer | Current source | Status |
|---|---|---|
| Night Prayer | Roman Breviary, Compline, tr. Marquess of Bute (1879) | OK |
| Grace after meals | Lasance, *Prayer-Book for Religious* (1904) | OK |
| Memorare; Sub tuum; Miraculous Medal; Spiritual Communion (St Alphonsus); Prayer before study (St Thomas); Responsory of St Anthony | *The Raccolta* (1910), the Church's official collection of indulgenced prayers | OK |
| Prayer to St Michael | Pope Leo XIII, via Lasance (1904) | OK |
| Anima Christi | *A Manual of Prayers* (Third Plenary Council of Baltimore) | OK |
| Suscipe | St Ignatius, tr. Elder Mullan, S.J. (1914) | OK |
| We adore Thee | St Francis, tr. Paschal Robinson, O.F.M. (1905) | OK |
| Prayers of the Angel of Fatima | Sister Lúcia; Shrine of Fatima (approved apparitions) | OK |
| Morning Offering; Come, Holy Spirit | "text as published by EWTN" | Re-source (Raccolta / Manual of Prayers) |
| Grace before meals; Angelus; Regina Caeli; Our Father; Hail Mary; Glory Be; Act of Contrition; For the faithful departed | "historic English wording" | Re-source (Baltimore Catechism 1891 / Raccolta / Manual of Prayers) |
| Our hearts are restless; Too late did I love Thee | St Augustine, tr. Pilkington (NPNF, a non-Catholic series) | Replace translation (Catholic translation with imprimatur, e.g. Matthew–Hudleston, 1923) |
| Let nothing disturb thee | St Teresa, tr. H. W. Longfellow (a Protestant poet) | Replace translation (Catholic prayer book with imprimatur) |
| Christ with me (St Patrick) | tr. Kuno Meyer (scholar), "traditionally attributed" | Replace (Catholic prayer book with imprimatur) |
| Lead, Kindly Light | St John Henry Newman, written 1833 as an Anglican | Replace with a prayer Newman wrote as a Catholic (*Meditations and Devotions*, 1893) |

## Rosary

| Item | Status | Note |
|---|---|---|
| Rosary prayers (Sign of the Cross, Creed, Our Father, Hail Mary, Glory Be, Fatima prayer, Hail Holy Queen, closing prayer) | Re-source | Current wording is the modern US liturgical English (Creed: "descended into hell"). Approved, but the Creed wording is © ICEL. Either name it with permission or use *A Manual of Prayers* (1896) wording ("Holy Ghost") |
| Mystery descriptions | OK | Quote St John Paul II, *Rosarium Virginis Mariae* |
| Seven Sorrows invocations and prayers | Re-source | Servite chaplet; quote from the Raccolta (1910) |
| Videos | OK | Bishop Robert Barron (Word on Fire), links only |

## Novenas (7)

| Novena | Current source | Status |
|---|---|---|
| St Padre Pio | novenaprayer.com (no author) | Replace (e.g. the Efficacious Novena to the Sacred Heart that Padre Pio prayed daily, by St Margaret Mary) |
| St Jude; St Peregrine; St Joseph; Our Lady of Perpetual Help | EWTN web pages | Re-source (pre-1931 prayer book with imprimatur; Perpetual Help from a Redemptorist manual) |
| St Thérèse rose novena | Society of the Little Flower (Carmelites) | OK pending the edition (Fr Putigan, S.J., 1925) |
| Divine Mercy | Diary of St Faustina, 476 | Approved; **copyright**: the English Diary is © Marian Press. Check permission or quote the novena from an approved public-domain text |

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
| Translations | **Decide (D6)** | Most come from the 19th-century *Ante-Nicene* and *Nicene and Post-Nicene Fathers* series (named scholars, many Anglican or Protestant, no imprimatur). Catholic translations with imprimatur exist only for part of the library |

## Store text

- The App Store description says "27 novenas"; the app has **7**. Fix in the 2.2.1 description.

## Decisions for Anton

- **D5.** World English Bible Catholic Edition has no imprimatur. Options: (a) remove it and make the
  Douay-Rheims the default; (b) keep it, labelled as a study translation without Church approval.
- **D6.** Fathers library translations. Options: (a) keep, because the texts are the Fathers' own and the
  translators are named scholars; (b) keep only works with a Catholic translation with imprimatur.
