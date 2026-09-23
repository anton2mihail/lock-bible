# The patristic library: how it is built and why

The app ships 26 authors, 271 works and **15.1 million words** of the Fathers
and Doctors, offline. This is how that gets from CCEL into the reader, and the
decisions worth knowing before changing any of it.

## The pipeline

```
node scripts/fetch-ccel.mjs        # .ccel-cache/*.epub      (gitignored, re-fetchable)
node scripts/build-ccel-works.mjs  # src/services/works/data/<collection>/*.json
bun  scripts/build-works-db.mjs    # assets/works/works.db + data/catalog.json
```

Chrysostom comes from a different source — a compiled EPUB, via
`scripts/build-works-data.mjs` — and lands in the same intermediate format, so
the last step is shared. Adding an author means adding an entry to `COLLECTIONS`
in `build-ccel-works.mjs` and re-running the last two steps.

## Why SQLite, and what stays bundled

The works used to be JSON imported by `worksService.ts`. Metro inlines imported
JSON as JavaScript source and Hermes compiles it to bytecode, so Chrysostom's
12.8MB on disk cost **37MB of `main.jsbundle`** — a 2.9× tax. That does not
scale: the current corpus would have meant a ~220MB bytecode bundle.

The split now is by purpose, not by size:

| | where | why |
|---|---|---|
| Section text | `assets/works/works.db`, 43MB | All of the bytes, none needed until a homily is opened. Memory-mapped, not parsed. |
| Catalog — collections, work manifest, chapter index | `data/catalog.json`, 0.24MB | Keeps the library list and the Bible reader's "Fathers on this chapter" **synchronous**. |

### The text is deflated

Stored plainly the corpus is 107MB, which would have put the app near 245MB
installed. Each section's paragraphs are deflated instead (`zlib` in the
builder, `fflate`'s `unzlibSync` in `loadSection`), and the page size is raised
from the 4KB default to 64KB. Both matter, and the page size is the less
obvious half: every section is one large value stored in an overflow chain, and
64KB pages waste far less on the tail page of each chain.

| page size | plain | deflated |
|---|---|---|
| 4KB (default) | 107.5MB | 62.6MB |
| 64KB | 130.4MB | **42.8MB** |

Inflating a section costs a millisecond or two against a read that is already
asynchronous. `decodeParagraphs` also accepts a plain string, so a database
built before this change still reads rather than throwing. `metadata` records
`paragraphEncoding = zlib-json` and `schemaVersion = 2`.

Measured after the change: the iOS bundle is 32.6MB with 15.1M words in the
library, against 49.6MB when it held 2.5M. Adding twelve and a half million
words made the JavaScript bundle *smaller*.

`loadSection(database, workId, index)` is the only call that touches the
database, and deliberately loads one section: the largest work is 433,000 words
and reading homily 40 should not pull homilies 1–39 into memory.

## Work ids are qualified

Work ids are `<collectionId>.<slug>` — `augustine.on-patience`. Slugs collide
across authors (Augustine and Tertullian both wrote *On Patience*), and the
reader addresses a work by id alone with no collection in the route. Two works
*within* one collection can also share a title — Polycarp and Ignatius both
wrote to the Philippians — so `build-ccel-works.mjs` suffixes the duplicate.
Without that the intermediate JSON, which is named after the slug, silently
overwrote its predecessor. A test asserts both invariants.

## Tables of contents differ per volume

There is no generic rule for where a work sits in a CCEL volume, which is the
single biggest engineering fact here:

- `npnf102` puts works at depth 0 (*City of God*).
- `npnf103` nests them under thematic groupings, so works are at depth 1.
- `npnf101` nests the whole volume under "About This Book" and has no node for
  the *Confessions* at all.
- `anf01` files everything beneath author names in capitals.

Hence `workDepth` per volume, plus `sectionDepth` where a level has meaning of
its own: `npnf108` pins it to 1 so Psalm 119's twenty-two Hebrew-letter
divisions stay part of that psalm instead of becoming psalms in their own right.
`only` and `under` split volumes holding more than one author — NPNF2 vol. 12 is
Leo the Great and Gregory the Great bound together.

`rangeWorks` covers the worst case. NPNF1 vol. 1 has no node for the
*Confessions*, so the work is named in the config and assembled from the
thirteen "Book" entries it spans. Augustine's letters in the same volume are a
single "Division 1" node covering 173 files; `splitByFile` makes each file a
section and takes its number from the file name, since they carry no headings.
Two traps there, both real: the volume's subject index sits inside that spine
range as `npnf101.viii.*.html`, whose lowercase "viii" a loose match reads as
letter 8 and staples an index onto a genuine letter; and long letters are split
across sub-part files repeating their parent's numeral, so files are grouped by
numeral rather than counted.

## What is deliberately excluded

**Apparatus.** Indexes, contents, prefaces, prolegomena, bibliographies and
chronological tables. A skipped node takes its whole subtree, which is what
removes each volume's subject index — CCEL names those children after the works
they index, so they are otherwise indistinguishable from the works themselves.

**CCEL's own writing.** "About This Book" is a modern CCEL blurb. The same
reasoning already dropped the Chrysostom EPUB's "Introduction".

**Nineteenth-century editorial essays.** Prolegomena and introductory essays are
public domain, but they are a named Victorian editor arguing a case — Warfield's
Reformed reading of Augustine among them — and this app should not present one
as the Father's own words.

**Spurious works.** ANF prints the forged Ignatian epistles as flat siblings of
the genuine letters, announced only by a heading, and one of them shares its
title with Polycarp's real letter to the Philippians. They can only be excluded
by position, which is what `skipBetween` does. Also dropped: the appendix of
dubious and spurious Hippolytus, and pseudo-Tertullian's *Against All Heresies*.
Shipping a forgery under a saint's name is an error of substance, not of style.

**Running heads.** CCEL's per-section files open with the print edition's
running head — the work's title broken across lines, a rule of dashes, the
section heading repeated — before the first real sentence. `trimRunningHead`
removes it, bounded to the first few paragraphs and to short lines, so a genuine
short opening survives. Psalm 23 keeps "A psalm of David himself."

**Footnote markers.** `<sup class="Note">615</sup>` welds itself to the
preceding word — "faith,616 there hath He placed me" — so markers and the
`<div class="mnote">` bodies both go before any text is read.

Result: **zero residual markup or HTML entities across 111,061 paragraphs.**

## The chapter index

975 entries across 20 books of Scripture, so opening a chapter offers the
Fathers on it. Coverage: all 150 Psalms (Augustine), all 28 of Matthew and all
21 of John (Chrysostom and Augustine together), 27 of Acts, and the Pauline
epistles.

Per-work rules in `WORK_RULES` say how to read a reference out of a section
title — `psalm` for "Psalm CXIX", `chapterRef` for "Chapter I. 1–5.",
`scriptureRef` for "…Matt. v. 16…". A work with no rule simply contributes no
index entries, which is the normal case: most of the corpus expounds no
particular chapter, and that is why the library is organised by author and by
kind rather than by Bible book.

## Rights

Every volume's own ThML metadata records `DC.Rights` as "Public Domain", and the
print sources are 1885–1900 — Ante-Nicene Fathers (Roberts & Donaldson,
1885–87), Nicene and Post-Nicene Fathers (Schaff & Wace, 1886–1900) and the
Dominican *Summa* (1911–25). All pre-1929, so public domain in the US, and all
translators long enough dead to be clear in life+70 jurisdictions too — which
matters because the App Store release is worldwide, and is why
`docs/john/patristic-corpus-survey.md` records a translation's *death date* test
rather than its publication year.

**CCEL's site-wide terms are a separate question and are not clean.** The
copyright page asserts rights over the library, permits personal, educational
and non-profit use, and asks that they be contacted about commercial
republication. Three things bear on that: the per-volume metadata says Public
Domain without exception; a faithful transcription of a public-domain text earns
no new copyright in the US; and this pipeline keeps only extracted paragraph
text, discarding CCEL's markup, styling, blurbs and editorial matter.

That is a defensible position rather than a settled one. **Write to CCEL.** A
one-line acknowledgement costs an email and removes the only real exposure. The
volumes' own `DC.Rights` field is the opening, and it is worth noting that
`DC.Source` on the ANF/NPNF ThML reads "Logos Research Systems, Inc." — the
digitisation was donated to CCEL, another link in the provenance worth naming.

## What an adversarial review changed

A six-dimension review of this pipeline, with each finding attacked by a second
agent, produced twenty findings that survived verification. The ones that
mattered, and what they cost before they were caught:

**A dead guard dropped every work's opening file.** The condition
`starts[0].at > start && !kept.length` is unreachable in both arms, so whatever
sat between a work's own table-of-contents node and its first child was read by
no section and vanished without an error or a changed word count. It cost the
Ignatian epistles their salutations, the Martyrdom of Polycarp its opening
address, and left "Fragments of Lactantius" containing no fragment of
Lactantius. The head range now runs to the first child, kept or skipped.

**A work ran past shallower boundaries.** `nextPeer` looked only for the next
node at the work's own depth, so a work could swallow the matter introduced by
the next author or thematic grouping. Ambrose's *Concerning Widows* ended with a
note on his letters. It now stops at the first node at its depth **or above**.

**A bare "Preface" in the skip list deleted the Fathers' own.** CCEL uses that
one title for both a volume editor's preface and the author's, so skipping it
took Origen's preface to *De Principiis* - his statement of the rule of faith -
along with the editors'. It is now skipped only at work level, where it is the
volume's; nested inside a work it is the author's and is kept.

**Editorial essays shipped as the Fathers' words.** About 136,000 words of
named Victorian editors sat inside works where the title-based skip lists never
looked: Richardson's prolegomena as a third of Eusebius's *Life of Constantine*,
Robertson's introduction as section 1 of Athanasius's *On the Incarnation*.
These are removed by explicit id in `EDITORIAL_SECTIONS` rather than by
pattern, because no pattern separates them from the Fathers: "Introduction." is
Robertson at the head of the *Defence Against the Arians* and, one section
later, Athanasius himself saying "I supposed that, after so many proofs of my
innocence had been given...". A rule broad enough to catch the first deletes
8,568 words of the second.

**A pagan senator shipped as a Doctor of the Church.** Symmachus's memorial
petitioning to restore the Altar of Victory is printed beside Ambrose's reply;
on an Ambrose shelf it read as Ambrose arguing for the Vestal Virgins.

**`kindFor` matched titles by substring**, shelving *A Treatise on the Spirit
and the Letter* and *Against the Epistle of Manichaeus* under "Letters". The
test is now whether the word is the head noun, not whether it appears.
