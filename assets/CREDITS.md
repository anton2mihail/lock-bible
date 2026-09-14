# Asset credits & licenses

## John 1:1 artwork and icon

The production icon, splash mark, favicon, liturgical seasons, sacraments,
devotional paintings, saint portraits, Rosary mysteries and sharing backgrounds
are generated artwork. Prompts are recorded in `docs/john/prompts/`. These are
devotional illustrations, not historical portraits. The current icon is
`artwork/john-icon.png`.

Legacy icons retained in `images/` use Material Design Icons by Pictogrammers
(Apache License 2.0): https://pictogrammers.com/library/mdi/icon/book-bible/.
The old `scripts/build-app-icons.py` produces those legacy assets, not the
current generated icon.

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

`logo*.png` and `welcome-face*.png` are original Ignite boilerplate demo assets
(Infinite Red), now only referenced by the unrouted `WelcomeScreen` — safe to
remove. `sad-face*.png` is still referenced by the `EmptyState` component, so
leave it (or replace it if you use `EmptyState` anywhere).
