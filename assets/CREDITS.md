# Asset credits & licenses

## John 1:1 artwork and icon

Every image in `artwork/` is a photograph of a public-domain historical artwork
from Wikimedia Commons. No artwork in the app or its store graphics is generated
by AI or drawn by code. `scripts/fetch-artwork.py` downloads each file listed in
`artwork/sources.json`, checks that both the artwork and the photograph are
public domain, and only crops and resizes it. The artist and date of each work
are in `artwork/credits.json`; the full list with Commons file names is in
`docs/john/artwork-sources.md`.

The app icon (`artwork/john-icon.png`) is a detail of the 6th-century icon of
Christ Pantocrator at Saint Catherine's Monastery, Sinai (Wikimedia Commons:
`File:Spas vsederzhitel sinay.jpg`, public domain). The Android launcher layer
`artwork/john-adaptive-background.png` is a wider crop of the same photograph.
`scripts/build-john-icon-variants.py` makes the other icon files from the icon
by resizing only, plus one global colour change for two of them:
`john-icon-dark.png` (80% brightness), `john-icon-tinted.png` (greyscale),
`john-splash.png` and `images/john-favicon.png` (resized).

The share-card backgrounds are details of two paintings: `share-ivory.jpg` is
the plain wall in Johannes Vermeer's *The Milkmaid* (c. 1657–1658), and
`share-plum.jpg` is the night sky in Jean-François Millet's *Starry Night*
(c. 1850–1865).

## Calendar and reading references

Reading citations derive from cpbjr/catholic-readings-api, MIT licensed,
commit `973e9864eb0f15accadfc48750f5b243a95b7a2c`.
See `READINGS-LICENSE.txt`. No USCCB Scripture text is redistributed.
Celebrations derive from romcal and its United States calendar, version
3.0.0-dev.117, MIT licensed; see `ROMCAL-LICENSE.txt`.

Lora is distributed under the SIL Open Font License through
`@expo-google-fonts/lora`. Feather navigation symbols are MIT licensed.

## Bundled Bible editions

The app includes three complete, offline, public-domain Catholic editions,
normalized to the 73-book Catholic canon from source files provided by
[eBible.org](https://ebible.org/):

- [World English Bible — Catholic Edition](https://ebible.org/eng-web-c/)
  (`WEB-CE`), public domain. “World English Bible” is a trademark of
  eBible.org.
- [Douay–Rheims 1899 American Edition](https://ebible.org/engDRA/) (`DRB`),
  public domain.
- [Clementine Vulgate 1598](https://ebible.org/latVUC/) (`VUL`, Latin), public
  domain.

The generated reader JSON, full-text search index, and WidgetKit resources are
all derived from those same source files by `scripts/build-bible-data.mjs`.

Modern copyrighted Catholic translations are not bundled without a
distribution license.

## Other bundled images

`sad-face*.png` is an original Ignite boilerplate asset (Infinite Red) still
referenced by the `EmptyState` component.
