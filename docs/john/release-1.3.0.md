# John 1:1 1.3.0 (16)

The first feature release since 1.2.2 (15) was approved on September 16, 2026.

## Our Lady of Sorrows

The Servite Rosary of the Seven Sorrows, prayed on its own shape rather than the
five-decade one: seven groups of one Our Father and seven Hail Marys, closing
with three Hail Marys in honour of the tears of the Sorrowful Mother. Reachable
from the prayer library and from the Rosary screen.

The structure was reconciled across three independent source families. Sources
disagree on whether each sorrow carries one Our Father or seven; the Raccolta
settles it at one. The seven Servite invocations ("I grieve for thee, O Mary
most sorrowful…") are verbatim, and the opening offering prayer replaced a
paraphrase.

`buildRosaryGuide` was left untouched. The new devotion is a sibling builder and
both flatten into a `RosarySession`, so the guide screen prays either one.

## St John Chrysostom

36 works, 532 homilies and letters, 2.48 million words, all offline. The text is
the Nicene and Post-Nicene Fathers translation (Schaff, 1886–1890), which is in
the public domain; `scripts/build-works-data.mjs` builds the bundled JSON.

Pages turn by swiping rather than scrolling. Each paragraph is measured once
with `onTextLayout` and its real line boxes are packed into page-height columns,
so a page can break mid-paragraph while paragraph breaks survive everywhere
else. Changing the reader's type size repaginates.

At the end of any chapter Chrysostom expounded, the Bible reader now offers his
homilies on it — 176 of the 177 chapters across the 17 books he commented on.
The corpus writes its references four different ways, and the Commentary on
Galatians carries none at all (it is organised by Bible chapter, so its section
titles are the reference); all five cases are handled.

## Artwork

32 of the app's devotional images are now historical paintings in the public
domain — Fra Angelico, Bellini, Leonardo, Velázquez, El Greco, Caravaggio, van
Eyck, Georges de La Tour, Murillo, Millet, Sassoferrato — fetched by
`scripts/fetch-artwork.py` from `assets/artwork/sources.json`. Credits are
generated from that manifest so an attribution cannot drift from the file it
sits under.

Twelve images keep their generated artwork. Some subjects have no clean
public-domain candidate (the Resurrection, the Visitation); some have none at
all, Padre Pio having died in 1968.

Three separate licence and attribution traps were hit getting here, all of them
after the offending file had already been written into `assets/artwork/`:

- A Commons `{{Artwork}}` page carries two licences, one for the painting and
  one for the photograph, and the API reports only the first. An Accademia
  photograph of a Previtali *Crucifixion* read as "Public domain" while the
  photograph was CC BY-SA 4.0.
- The first fix matched `{{cc-by...` only where it followed the braces
  directly, so `{{self|cc-by-sa-4.0}}` went straight through it — which is how
  a Bellini *Resurrection* and a Murillo *Marriage at Cana* got in a second
  time. The check now matches a CC name anywhere inside a template.
- `{{PD-self}}` means the photographer released their own rights and says
  nothing about the painting in the photograph. Fine for a flat scan of an old
  master, not fine for a picture taken inside a church. Two images failed on it.

Attribution had the same shape of bug: the API's `Artist` field names the
photographer, so Leonardo's *Last Supper* was briefly credited to the person who
photographed it. Credits now come from the `{{Artwork}}` template's artist
field. Full provenance in `docs/john/artwork-sources.md`.

## Size

The IPA is 66.8 MB, up from roughly 24 MB at 1.2.2. Chrysostom accounts for
about 13 MB of bundled JSON and the rest is the new artwork. Worth watching: if
it becomes a problem, the works pipeline can ship only the 17 scriptural
commentaries and leave the treatises out.

## Build and submission

- Build: local EAS production build, `build-1789946178491.ipa` (66.8 MB)
- Submission: https://expo.dev/accounts/antonmihail/projects/NRSV/submissions/550cdad7-9b09-4f2b-a393-9d44af58b0b5
- App Store Connect: https://appstoreconnect.apple.com/apps/6784763639/distribution

Submitted to App Review on September 21, 2026. Status: Waiting for Review. Set
to release automatically once approved.

App Store Connect notes for this submission:

- The version draft in App Store Connect was sitting at 1.2.3; it was renamed to
  1.3.0 to match the build, since two new features are more than a patch.
- The reviewer notes still described the September 11 rejection of 1.2 (13) and
  were replaced with notes for this release: where to find both new features,
  that no account or demo credentials exist, and that the artwork is public
  domain.
- The submission carried one pending change to shared app information: the app
  name differs from the live listing by a dash character
  ("John 1:1 - Lock Bible" against "John 1:1 – Lock Bible"). Both contain the
  on-device name, which is what Guideline 2.3.8 asks for.
- Screenshots are the six from 1.2.2. They remain accurate for a five-tab app
  but do not show the Seven Sorrows or Chrysostom. Regenerate with
  `marketing/capture-screenshots.yaml` when convenient.
