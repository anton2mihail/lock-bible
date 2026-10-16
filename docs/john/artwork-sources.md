# Artwork provenance

Every image in `assets/artwork/` is a photograph of a historical artwork in the
public domain. `scripts/fetch-artwork.py` fetches each one from Wikimedia
Commons, as listed in the manifest at `assets/artwork/sources.json`. The app has
no AI-generated images and no images drawn by code. The script only crops and
resizes the photographs.

Some subjects have no public-domain image that passes the licence check, so the
app shows a related work in their place:

- **St. Padre Pio Novena.** Padre Pio died in 1968, so no portrait of him is in
  the public domain. This novena is the Efficacious Novena to the Sacred Heart
  that he prayed, so the app shows Pompeo Batoni's *Sacred Heart of Jesus*.
- **St. Peregrine Novena.** Every photograph of a painting of St. Peregrine on
  Commons carries a Creative Commons claim. St. Peregrine was healed of cancer,
  so the app shows a Gospel healing: Murillo's *Christ Healing the Paralytic at
  the Pool of Bethesda*.
- **St. Thérèse Novena.** The photographs of Thérèse are not public domain in
  every country (the photographer, Céline Martin, died in 1959). Her religious
  name is "of the Child Jesus and the Holy Face", so the app shows Domenico
  Fetti's *The Veil of Veronica*, a painting of the Holy Face.

Nothing here is redistributed under a Creative Commons licence. Every file below
carries a plain public-domain tag on Commons, which the script re-checks on
every run:

```bash
python3 scripts/fetch-artwork.py --check
```

`--check` fails if any file has stopped being cleanly public domain. Run it
before a release that ships new artwork. `--force` re-downloads and re-renders
everything.

It reads the file page's wikitext, not just the API summary, and that
distinction matters. A Commons `{{Artwork}}` page carries two licences: one for
the painting and one for the photograph of it. The API's `LicenseShortName`
reports only the first. An earlier draft of this set used a Gallerie
dell'Accademia photograph of a Previtali *Crucifixion* whose page reads:

```
|artwork license = {{PD-old-100}}
|photo license   = {{cc-by-sa-4.0}}
```

The API called that "Public domain" and the check passed it, but the
photographer's share-alike claim would have followed the image into the app.
Mantegna replaced it. The check now scans for any `cc-by` / `cc-sa` / `cc-zero`
template anywhere on the page and refuses the file if it finds one, so a
museum photograph cannot slip through behind a public-domain painting.


## Two ways a file can look public domain and not be

Both of these shipped into `assets/artwork/` before being caught, so the checks
exist because the mistakes were made.

**The photograph's licence hides behind the painting's.** A Commons
`{{Artwork}}` page carries two licences and the API reports only the first, so a
Gallerie dell'Accademia photograph of a Previtali *Crucifixion* read as "Public
domain" while the photograph itself was CC BY-SA 4.0. Worse, the first fix only
matched `{{cc-by...` directly after the braces, and Commons commonly writes
`{{self|cc-by-sa-4.0}}` — that let Bellini's *Resurrection* and a Murillo
*Marriage at Cana* through a second time. The check now matches a Creative
Commons name anywhere inside a template.

**Only the photographer released their rights.** `{{PD-self}}` and
`{{PD-user-w}}` mean the uploader gave up their claim on the photograph. For a
flat scan of an old master that is the whole story. For a picture taken inside a
church, the painting on the wall has its own copyright that the page never
addresses. Two images failed on this and were dropped.

The same trap applies to attribution: the API's `Artist` field names the
photographer, so credits are read from the `{{Artwork}}` template's own artist
field instead. Leonardo's *Last Supper* was briefly credited to the person who
photographed it.

## The paintings

| Asset | Sorrow | Painting | Artist | Date |
| --- | --- | --- | --- | --- |
| `sorrows-1.jpg` | The Prophecy of Simeon | Presentation in the Temple | Master of the Life of the Virgin | c. 1460–1480 |
| `sorrows-2.jpg` | The Flight into Egypt | Fuga in Egitto (National Gallery of Art, Washington) | Vittore Carpaccio | 1500 |
| `sorrows-3.jpg` | The Loss of the Child Jesus in the Temple | The Finding of the Saviour in the Temple | William Holman Hunt | 1854–1860 |
| `sorrows-4.jpg` | Mary Meets Jesus on the Way to Calvary | Lo Spasimo di Sicilia (Christ Falling on the Way to Calvary) | Raphael | c. 1516 |
| `sorrows-5.jpg` | The Crucifixion and Death of Jesus | The Crucifixion (San Zeno Altarpiece predella, Louvre) | Andrea Mantegna | 1457–1459 |
| `sorrows-6.jpg` | Mary Receives the Body of Jesus | Pietà | Rogier van der Weyden | c. 1441 |
| `sorrows-7.jpg` | The Burial of Jesus | The Deposition (Pala Baglioni, Galleria Borghese) | Raphael | 1507 |

Artist and title are shown to the reader on the meditation step, so the credit
travels with the image rather than living only here.

## Why these, and why they are cropped the way they are

Each painting had to show the sorrow itself with Mary present and legible at a
glance. That ruled out a lot of otherwise beautiful work: panoramic Netherlandish
landscapes put the Holy Family a few pixels tall, and crowded Venetian machines
bury the moment in incident.

Devotional painting is mostly taller than the app's landscape frame, so a plain
centre crop decapitates altarpieces. Each entry in the script carries its own
`top`/`bottom` window, expressed as fractions of the source height:

- **Sorrow 4** keeps the bottom 55% of Raphael's *Spasimo*. The upper half is
  soldiers, banners and sky; the meeting — Christ fallen and turning toward his
  mother, Mary reaching for him — is entirely below it.
- **Sorrow 7** trims the top and a sliver of the base of Raphael's near-square
  *Deposition* so the frame holds the bearers, the body, and the Virgin
  swooning at the right.
- The rest are wide enough to take the full height.

Output is a 1200×800 JPEG, with the quality stepped down until the file is
under 360KB. An entry can also set `left`/`right` crop fractions, an output
`size` (the share-card backgrounds are 800×1200), and an `output` name (the app
icon is a 1024×1024 opaque PNG). The script downloads Wikimedia's standard
thumbnail widths (3840, 1920, 1280 or 960 px), because Wikimedia refuses
scripted downloads of original files with HTTP 429.

## A note on style

These are real works across fourteen centuries, from a 6th-century Sinai icon
to 19th-century canvases. They do not share one style. Holman Hunt's *Finding
of the Saviour in the Temple* is the loudest of them. It earns its place because
no other public-domain work states the third sorrow as plainly: Mary with her
arms around the boy she had lost. To change an image, change its entry in
`assets/artwork/sources.json` and run `scripts/fetch-artwork.py --force --only
<slug>`. Do not edit the JPEG by hand.

<!-- table:start -->

### The Seven Sorrows

| Asset | Subject | Commons file | Artist | Date |
| --- | --- | --- | --- | --- |
| `sorrows-1.jpg` | The Prophecy of Simeon | Meister des Marienlebens candlemas | Master of the Life of the Virgin | c. 1460–1480 |
| `sorrows-2.jpg` | The Flight into Egypt | Vittore Carpaccio - Fuga in Egitto (Washington) | Vittore Carpaccio | 1500 |
| `sorrows-3.jpg` | The Loss of the Child Jesus in the Temple | William Holman Hunt - The Finding of the Saviour in the Temple - Google Art Project | William Holman Hunt | 1854–1860 |
| `sorrows-4.jpg` | Mary Meets Jesus on the Way to Calvary | Christ Falling on the Way to Calvary - Raphael | Raphael | c. 1516 |
| `sorrows-5.jpg` | The Crucifixion and Death of Jesus | Mantegna, Andrea - crucifixion - Louvre from Predella San Zeno Altarpiece Verona, louvre | Andrea Mantegna | 1457–1459 |
| `sorrows-6.jpg` | Mary Receives the Body of Jesus | Rogier van der Weyden - Pietà - Google Art Project | Rogier van der Weyden | c. 1441 |
| `sorrows-7.jpg` | The Burial of Jesus | Raffael-grablegung-christi | Raphael | 1507 |

### The Joyful Mysteries

| Asset | Subject | Commons file | Artist | Date |
| --- | --- | --- | --- | --- |
| `joyful-1.jpg` | The Annunciation | Fra Angelico - Annunciation | Fra Angelico | c. 1440–1445 |
| `joyful-2.jpg` | The Visitation | La Visitation avec Marie-Jacobie et Marie-Salomé - Domenico Ghirlandaio - Musée du Louvre Peintures INV 297 ; MR 240 | Domenico Ghirlandaio | 1491 |
| `joyful-3.jpg` | The Nativity | Adoration of the Shepherds, Murillo (Prado Museum) | Bartolomé Esteban Murillo | circa 1650 |
| `joyful-4.jpg` | The Presentation in the Temple | Presentation of Jesus at the Temple by Fra Angelico (San Marco Cell 10) | Fra Angelico | between 1439 and 1443 |
| `joyful-5.jpg` | The Finding in the Temple | Albrecht Dürer - Jesus among the Doctors - Google Art Project | Albrecht Dürer | 1506 |

### The Sorrowful Mysteries

| Asset | Subject | Commons file | Artist | Date |
| --- | --- | --- | --- | --- |
| `sorrowful-1.jpg` | The Agony in the Garden | El Greco 019 | El Greco and workshop | 1590s |
| `sorrowful-2.jpg` | The Scourging at the Pillar | Isenmann, Colmar Altarpiece (Flagellation) | Caspar Isenmann | c. 1465 |
| `sorrowful-3.jpg` | The Crowning with Thorns | The Crowning with Thorns-Caravaggio (1602) | Caravaggio | circa 1602/04 |
| `sorrowful-4.jpg` | The Carrying of the Cross | Christ Carrying the Cross 1580 | El Greco | 1580s |
| `sorrowful-5.jpg` | The Crucifixion | Calvary - Giovanni Bellini - Louvre RF 1970-39 | Giovanni Bellini | c. 1465–1470 |

### The Glorious Mysteries

| Asset | Subject | Commons file | Artist | Date |
| --- | --- | --- | --- | --- |
| `glorious-1.jpg` | The Resurrection | Piero della Francesca - Resurrection - WGA17609 | Piero della Francesca | c. 1463–1465 |
| `glorious-2.jpg` | The Ascension | Jesus ascending to heaven | John Singleton Copley | 1775 |
| `glorious-3.jpg` | The Descent of the Holy Spirit | Pentecostés (El Greco, c. 1600) Prado | El Greco | circa 1600 |
| `glorious-4.jpg` | The Assumption of Mary | Matteo di Giovanni - The Assumption of the Virgin - 1474 | Matteo di Giovanni | 1474 |
| `glorious-5.jpg` | The Coronation of Mary | Diego Velázquez - Coronation of the Virgin - Prado | Diego Velázquez | c. 1635–1636 |

### The Luminous Mysteries

| Asset | Subject | Commons file | Artist | Date |
| --- | --- | --- | --- | --- |
| `luminous-1.jpg` | The Baptism of Jesus | Verrocchio, Leonardo da Vinci - Battesimo di Cristo - Google Art Project | Andrea del Verrocchio and Leonardo da Vinci | c. 1475 |
| `luminous-2.jpg` | The Wedding at Cana | Julius Schnorr von Carolsfeld 002 | Julius Schnorr von Carolsfeld | 1819 |
| `luminous-3.jpg` | The Proclamation of the Kingdom | Bloch-SermonOnTheMount (The Sermon on the Mount) | Carl Bloch | 1877 |
| `luminous-4.jpg` | The Transfiguration | Paris 1er - Musée du Louvre - Exposition Naples à Paris - La Transfiguration (Giovanni Bellini) | Giovanni Bellini | c. 1487 |
| `luminous-5.jpg` | The Institution of the Eucharist | Last Supper by Leonardo da Vinci | Leonardo da Vinci | 1495–1498 |

### Saints

| Asset | Subject | Commons file | Artist | Date |
| --- | --- | --- | --- | --- |
| `st-anne.jpg` | Saint Anne | St Anne Teaching the Virgin to Read - MNK XII-A-264 (331827) | Unknown | 17th century |
| `st-anthony.jpg` | Saint Anthony of Padua | Francisco de Zurbarán - Sto Antonio de Padua | Francisco de Zurbarán | from 1627 until 1630 |
| `st-benedict.jpg` | Saint Benedict | A Miracle of Saint Benedict A17552 | French 15th Century | circa 1480 |
| `st-francis-assisi.jpg` | Saint Francis of Assisi | Attributed to Jan van Eyck, Netherlandish (active Bruges), c. 1395 - 1441 - Saint Francis of Assisi Receiving the Stigmata - Google Art Project | Attributed to Jan van Eyck | c. 1430–1432 |
| `st-joseph.jpg` | Saint Joseph | La Tour | Georges de La Tour | 1640s |
| `st-jude.jpg` | Saint Jude Thaddeus | Georges de La Tour - Saint Jude Thaddée | Georges de La Tour | c. 1620 |
| `st-padre-pio.jpg` | The Sacred Heart of Jesus (Efficacious Novena to the Sacred Heart) | Sacred Heart of Jesus, Gesu Church, Rome | Pompeo Batoni | 1767 |
| `st-peregrine.jpg` | Christ Healing the Paralytic at the Pool of Bethesda | Curacion del paralitico Murillo 1670 | Bartolomé Esteban Murillo | 1667–1670 |
| `st-therese.jpg` | The Holy Face (The Veil of Veronica) | Domenico Fetti - The Veil of Veronica | Domenico Fetti | c. 1618–1622 |
| `st-monica.jpg` | Saint Monica | Luis Tristán de Escamilla - St Monica - WGA23069 | Luis Tristán de Escamilla | 1616 |

### General

| Asset | Subject | Commons file | Artist | Date |
| --- | --- | --- | --- | --- |
| `mary.jpg` | The Blessed Virgin Mary | Sassoferrato - Jungfrun i bön | Il Sassoferrato | between 1640 and 1650 |
| `prayer.jpg` | Prayer | JEAN-FRANÇOIS MILLET - El Ángelus (Museo de Orsay, 1857-1859. Óleo sobre lienzo, 55.5 x 66 cm) | Jean-François Millet | from 1857 until 1859 |
| `scripture.jpg` | Scripture | The Four Evangelists (Abraham Bloemaert) | Abraham Bloemaert | between 1612 and 1615 |
| `advent.jpg` | Advent: Saint John the Baptist in the Wilderness | Geertgen tot Sint Jans - Johannes der Täufer in der Einöde, um 1480-1490, 1631 | Geertgen tot Sint Jans | c. 1480–1490 |

### Share cards and app icon

| Asset | Subject | Commons file | Artist | Date |
| --- | --- | --- | --- | --- |
| `share-ivory.jpg` | The plain wall in The Milkmaid (detail, 800×1200) | Johannes Vermeer - Het melkmeisje - Google Art Project | Johannes Vermeer | c. 1657–1658 |
| `share-plum.jpg` | The night sky in Starry Night (detail, 800×1200) | Starry Night by Jean-François Millet | Jean-François Millet | c. 1850–1865 |
| `john-icon.png` | Face of Christ Pantocrator, Saint Catherine's Monastery, Sinai (1024×1024) | Spas vsederzhitel sinay | Unknown Byzantine painter | 6th century |
| `john-adaptive-background.png` | Wider crop of the same icon for the Android launcher | Spas vsederzhitel sinay | Unknown Byzantine painter | 6th century |

`scripts/build-john-icon-variants.py` makes `john-icon-dark.png` (80%
brightness), `john-icon-tinted.png` (greyscale), `john-splash.png` and
`assets/images/john-favicon.png` (resized) from `john-icon.png`. It copies
`john-adaptive-background.png` to the Android `drawable-nodpi/john_background.png`.

<!-- table:end -->
