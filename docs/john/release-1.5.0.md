# 1.5.0 — The reader

**Status: building. Build 18.**

The first release from the September UI/UX review, which ran the app and read
every screen's code. 1.4.0 shipped on 22 September; everything below is new
since then.

## What's New (App Store text)

> Scripture now reads like a book. Paragraphs flow, psalms and poetry are set
> in lines, and psalm titles are back. Prefer one verse per line? It's a tap
> away.
>
> • The new Aa button changes text size, line spacing, typeface and layout
> while you read, and the chapter changes as you choose.
> • Tap the chapter title to jump to any book and chapter.
> • The Bible reopens where you left off.
> • A clearer verse toolbar: highlights stay visible while a verse is
> selected, and Bookmark shows when a passage is already saved.
> • Line spacing now works on iPhone, and large text no longer crowds the
> lines.
> • A comfortable line length on iPad.
> • VoiceOver announces saved items, search results and errors. Stronger
> contrast in dark mode, and layouts that hold up at the largest text sizes.
> • Closing Search returns you to your chapter, and switching translation
> updates the open chapter.

## What shipped

**Reading.**
- WEB-CE keeps its paragraphs, poetry lines, stanza breaks and headings,
  including Psalm superscriptions and Song of Songs speakers. The reader lays
  a chapter out as paragraphs by default, or verse by verse. A screen reader
  always gets verse by verse.
- The WEB-CE text now matches eBible's current revision, which changed six
  verses.
- The **Aa** sheet holds text size, line spacing, typeface, layout and
  appearance. The same controls are in Settings, and both follow a change made
  in the other.
- The chapter title opens **Go to**, with every book listed, the current one
  open and its chapter marked. The Read tab reopens the last chapter at its
  scroll position.
- The verse toolbar has icons, inline highlight swatches and a saved state for
  Bookmark. A selection is outlined or underlined, never filled.
- On iPad, text, title and toolbar sit in a column of about 70 characters.

**Fixes.**
- **Line spacing never applied on iOS, including in every shipped version.**
  Each verse begins with its number, which carried the small text size's 21 pt
  line height, and iOS spaces a paragraph by its first character. Large and
  Extra large text overlapped. The number now takes the passage's line height,
  so the default "Comfortable" reads noticeably more open than before.
- Search was a hidden tab, so closing it landed on Today and VoiceOver counted
  six tabs. It is a stacked screen now.
- A translation switch left the open chapter in the old edition, and the next
  bookmark saved the old words under the new edition's name.
- The Rosary card no longer opens the placeholder media player, which showed
  "PERMISSION PENDING".

**Accessibility.**
- iOS ignores live regions, so status messages are now also announced to
  VoiceOver: undo in Saved, search results, note errors, and six companion
  screens.
- The dark-mode red is `#F4876B`, at least 4.7:1 on every background. It was
  2.9:1 on cards.
- Text fields, novena day circles and the Fathers contents rows grow with the
  text size instead of clipping.
- At the largest sizes, header and toolbar text stops growing so the text they
  sit around keeps the room. This covers the reader title, the Aa sheet, the
  verse toolbar, the Fathers reader and the close buttons. The Fathers reader
  went from 11 pages to 3 for its first section at AX5.
- The Rosary progress bar has a value, and Settings' titles are headings. The
  Fathers page counter reads "Page 3 of 12".

## Verified

- 182 tests, typecheck, lint and dependency rules clean.
- Web build at 402×874 and at iPad sizes, light and dark.
- The dedicated simulator "John 1:1 Review iPhone 17 Pro" (iOS 26.5):
  - the reader header and the Aa sheet's slide-up and live restyle;
  - Settings and the sheet following each other;
  - paragraph and verse layouts at every text size;
  - AX5 across the reader, Search, a novena, the Rosary guide and the Fathers
    reader.
- Not checked: VoiceOver itself, which Simulator doesn't have.

## Known, not fixed

- Store screenshots are still from 1.2.2 and show the old reader header.
- At AX5, Search's "Old Testament" and "New Testament" buttons break mid-word,
  and the mystery names under the Rosary beads truncate.
