# 1.4.0 — The Fathers and Doctors

**Status: submitted to App Review 21 September 2026, 3:46 PM. Build 17.
Waiting for Review, set to release automatically on approval.**

Supersedes 1.3.0, which was pulled from the review queue rather than reviewed
twice: everything in it ships here as well.

## What shipped

**The patristic library.** 26 authors, 271 works, **15.1 million words**,
offline. Augustine complete (3.9m, including the *Confessions* and 168 letters,
and his expositions on all 150 Psalms), the Dominican *Summa Theologica*
(2.5m), Chrysostom (2.5m), Tertullian, Athanasius, Jerome, Gregory of Nyssa,
Ambrose, Origen, Clement of Alexandria, Cassian, Gregory the Great, Eusebius,
Cyprian, Lactantius, Basil, Gregory Nazianzen, Irenaeus, Hippolytus, Ephraim,
Leo the Great, Cyril of Jerusalem, Justin Martyr, the Apostolic Fathers, John
Damascene, Vincent of Lérins.

**The chapter index grew to 975 readings across 20 books** — all 150 Psalms,
all 28 chapters of Matthew, all 21 of John, 27 of Acts — so opening a chapter
offers the Fathers who wrote on it, and a new screen lists all of them.

**From 1.3.0**, which never reached users: the Seven Sorrows rosary and 32
public-domain paintings.

## Size

The corpus is 15.1m words. Stored plainly that is 107MB and would have put the
app near 245MB installed; deflated, at a 64KB page size, `works.db` is **43MB**.
See [works-pipeline.md](works-pipeline.md) for the measurements.

The JS bundle went the other way. Works used to be JSON imported by
`worksService.ts`, which Metro inlines as JavaScript source for Hermes to
compile — 12.8MB of Chrysostom cost 37MB of `main.jsbundle`. Moving the text to
a SQLite asset took the bundle from **49.6MB to 32.6MB while the corpus grew
six-fold**.

## Verified

- 151 tests, typecheck and lint clean.
- Driven by hand in the Simulator: library, author shelves, the reader on
  Augustine's Psalms and Aquinas's *Summa*, the contents sheet on a
  1,103-section work, and the chapter-commentary list from John 1.
- A test opens the real shipped database, inflates a real deflated blob through
  the app's own `loadSection`, and reads back "The Lord feedeth me".

## What an adversarial review caught, before release

Twenty findings survived verification. The ones that mattered were substance
errors, not style:

- A dead guard dropped every work's opening file: the Ignatian epistles lost
  their salutations and "Fragments of Lactantius" contained no fragments.
- A bare `"Preface"` in the skip list deleted the Fathers' own prefaces along
  with the editors' — Origen's to *De Principiis* among them.
- ~136,000 words of named Victorian editors shipped as the Fathers' words,
  including a third of Eusebius's *Life of Constantine*.
- Symmachus's pagan plea to restore the Altar of Victory shipped as a work of
  St Ambrose.
- "All N readings on this chapter" re-opened reading #1; the rest were
  unreachable.
- A 1,103-section work could only be navigated one arrow-tap at a time.
- A failed database import would have thrown during render with nothing to
  catch it, blanking the whole app rather than one screen.

All fixed. Full detail in [works-pipeline.md](works-pipeline.md).

## Known, not fixed

- **Screenshots are still the six from 1.2.2.** Accurate for a five-tab app,
  but they show neither the rosary nor the library.
  `marketing/capture-screenshots.yaml` regenerates them without resubmitting
  the binary.
- **CCEL's terms are not clean.** Every volume's own metadata says Public
  Domain and the print sources are 1885–1900, but their site asserts copyright
  over the library and asks to be contacted about commercial republication. We
  keep only extracted paragraph text. Worth an email; the argument is written
  up in works-pipeline.md.
- Tier-2 authors outside the ANF/NPNF corpus — Teresa of Ávila, John of the
  Cross, Francis de Sales, Liguori, Bernard, Catherine of Siena, the
  *Imitation*, the Rule of St Benedict — need a second ingester for Gutenberg
  and archive.org.

## Build notes

Two things that cost hours and are worth knowing:

- **CocoaPods needs a UTF-8 locale.** This machine has `LANG` unset and
  `LC_CTYPE=C`, which makes `pod install` die with
  `Unicode Normalization not appropriate for ASCII-8BIT`. Prefix native builds
  with `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`, or set it in the shell profile.
- **Never run two Xcode builds at once.** They share
  `~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex` and corrupt it;
  the symptom is `could not build module 'simd'`. Delete that directory to
  recover.
- `EAS_SKIP_AUTO_FINGERPRINT=1` avoids a long fingerprint pass that hashes the
  whole asset tree.

## Submission notes

- 1.3.0 was removed from the review queue first; App Store Connect will not
  accept a new build while a version is waiting. The old submission now shows
  as "Removed" and its version record was renamed 1.3.0 -> 1.4.0, so build 16
  had to be detached and 17 attached in its place.
- The submit dialog again flagged a pending change to the shared app Name. It
  is the dash: App Store Connect holds "John 1:1 - Lock Bible" against the live
  "John 1:1 – Lock Bible". Both contain the on-device name "John 1:1", which is
  what Guideline 2.3.8 asks for, so it ships with this release.
- `eas submit` buffers its output when it is not attached to a terminal, so a
  backgrounded run looks dead - a zero-byte log and no progress for an hour.
  Run it under `script -q <logfile>` to get a pseudo-TTY and real progress.
  Check for an existing submit with `pgrep -f <ipa name>`, not a generic `eas`
  pattern, which also matches other projects' builds on this machine; two
  concurrent submits of the same binary will stall each other indefinitely.
