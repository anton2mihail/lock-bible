import { getBook, listBooks } from "./bibleService"
import { layoutChapter, type ChapterBlock } from "./chapterLayout"
import type { Chapter } from "./types"

function describeBlocks(blocks: ChapterBlock[]) {
  return blocks.map((block) =>
    block.type === "heading"
      ? `${block.kind}: ${block.text}`
      : `${block.kind}${block.stanzaBreak ? "+b" : ""}: ${block.segments
          .map((segment) => `${segment.label ?? ""}|${segment.text}`)
          .join(" ")}`,
  )
}

describe("layoutChapter", () => {
  it("sets a psalm's title above poetry lines that break inside verses", () => {
    const chapter: Chapter = {
      c: 3,
      verses: [
        {
          n: "1",
          t: "LORD, how my adversaries have increased! Many are those who rise up against me.",
          br: [
            [0, "q1"],
            [41, "q2"],
          ],
          hd: [["d", "A Psalm by David."]],
        },
        { n: "2", t: "Many there are who say of my soul.", br: [[0, "q1"]] },
      ],
    }

    const layout = layoutChapter(chapter)

    expect(describeBlocks(layout.blocks)).toEqual([
      "d: A Psalm by David.",
      "q1: 1|LORD, how my adversaries have increased!",
      "q2: |Many are those who rise up against me.",
      "q1: 2|Many there are who say of my soul.",
    ])
    expect(layout.verses[0].lines.map((line) => line.kind)).toEqual(["q1", "q2"])
    expect(layout.verses[0].headings).toEqual([["d", "A Psalm by David."]])
  })

  it("runs verses on within a paragraph until the next one begins", () => {
    const chapter: Chapter = {
      c: 1,
      verses: [
        { n: "1", t: "In the beginning was the Word.", br: [[0, "p"]] },
        { n: "2", t: "The same was in the beginning with God." },
        { n: "3", t: "There came a man sent from God.", br: [[0, "p"]] },
      ],
    }

    const layout = layoutChapter(chapter)

    expect(describeBlocks(layout.blocks)).toEqual([
      "p: 1|In the beginning was the Word. 2|The same was in the beginning with God.",
      "p: 3|There came a man sent from God.",
    ])
    expect(layout.verses.map((verse) => verse.startsBlock)).toEqual([true, false, true])
  })

  it("starts an indented paragraph partway through a verse", () => {
    const chapter: Chapter = {
      c: 9,
      verses: [
        { n: "10", t: "We have not obeyed.", br: [[0, "p"]] },
        { n: "11", t: "Israel turned aside. “Therefore the curse.", br: [[21, "pi"]] },
      ],
    }

    const layout = layoutChapter(chapter)

    expect(describeBlocks(layout.blocks)).toEqual([
      "p: 10|We have not obeyed. 11|Israel turned aside.",
      "pi: |“Therefore the curse.",
    ])
    expect(layout.verses[1].lines).toEqual([
      { type: "text", kind: "p", text: "Israel turned aside.", stanzaBreak: false },
      { type: "text", kind: "pi", text: "“Therefore the curse.", stanzaBreak: false },
    ])
  })

  it("prints a heading that falls inside a verse where it stands", () => {
    const chapter: Chapter = {
      c: 1,
      verses: [
        {
          n: "4",
          t: "Take me away with you. We will be glad. They are right.",
          br: [
            [0, "q1"],
            [23, "q1"],
            [39, "q1"],
          ],
          hd: [
            ["sp", "Friends", 23],
            ["sp", "Beloved", 39],
          ],
        },
        // Words after a heading with no block of their own resume the kind in progress.
        { n: "5", t: "I am dark. But lovely.", br: [[0, "q1"]], hd: [["sp", "Lover", 11]] },
      ],
    }

    const layout = layoutChapter(chapter)

    expect(describeBlocks(layout.blocks)).toEqual([
      "q1: 4|Take me away with you.",
      "sp: Friends",
      "q1: |We will be glad.",
      "sp: Beloved",
      "q1: |They are right.",
      "q1: 5|I am dark.",
      "sp: Lover",
      "q1: |But lovely.",
    ])
    expect(layout.verses[0].headings).toEqual([])
    expect(layout.verses[0].lines.map((line) => `${line.type}:${line.text}`)).toEqual([
      "text:Take me away with you.",
      "heading:Friends",
      "text:We will be glad.",
      "heading:Beloved",
      "text:They are right.",
    ])
  })

  it("marks stanza breaks, and resumes the kind in progress when none is given", () => {
    const chapter: Chapter = {
      c: 1,
      verses: [
        { n: "1", t: "First line.", br: [[0, "q1"]] },
        {
          n: "2",
          t: "Second stanza.",
          br: [
            [0, "b"],
            [0, "q1"],
          ],
        },
        { n: "3", t: "Third stanza.", br: [[0, "b"]] },
      ],
    }

    const layout = layoutChapter(chapter)

    expect(describeBlocks(layout.blocks)).toEqual([
      "q1: 1|First line.",
      "q1+b: 2|Second stanza.",
      "q1+b: 3|Third stanza.",
    ])
    expect(layout.verses[1].lines[0]).toEqual({
      type: "text",
      kind: "q1",
      text: "Second stanza.",
      stanzaBreak: true,
    })
  })

  it("sets every verse on its own line in editions without paragraphing", () => {
    const chapter: Chapter = {
      c: 1,
      verses: [
        { n: "1", t: "In the beginning was the Word." },
        { n: "2", t: "The same was in the beginning with God." },
      ],
    }

    const layout = layoutChapter(chapter)

    expect(describeBlocks(layout.blocks)).toEqual([
      "p: 1|In the beginning was the Word.",
      "p: 2|The same was in the beginning with God.",
    ])
    expect(layout.verses.every((verse) => verse.startsBlock)).toBe(true)
  })

  it("keeps every word of every WEB-CE verse, in order", () => {
    for (const book of listBooks("web-ce")) {
      for (const chapter of getBook(book.code, "web-ce").chapters) {
        const layout = layoutChapter(chapter)
        chapter.verses.forEach((verse, index) => {
          const rejoined = layout.verses[index].lines
            .filter((line) => line.type === "text")
            .map((line) => line.text)
            .join(" ")
          if (rejoined !== verse.t) {
            throw new Error(`${book.code} ${chapter.c}:${verse.n} lost text: ${rejoined}`)
          }
        })
        const verseOrder = layout.blocks.flatMap((block) =>
          block.type === "text" ? block.segments.map((segment) => segment.verseIndex) : [],
        )
        expect(verseOrder).toEqual([...verseOrder].sort((a, b) => a - b))
      }
    }
  })

  it("reads the real structure of Psalm 23 and John 1", () => {
    const psalm = layoutChapter(getBook("PSA", "web-ce").chapters[22])
    expect(psalm.blocks[0]).toEqual({
      type: "heading",
      kind: "d",
      text: "A Psalm by David.",
      verseIndex: 0,
    })
    expect(psalm.verses[0].lines.map((line) => line.kind)).toEqual(["q1", "q2"])

    const john = layoutChapter(getBook("JHN", "web-ce").chapters[0])
    const paragraphStarts = john.verses
      .map((verse, index) => (verse.startsBlock ? index + 1 : undefined))
      .filter((verse) => verse != null)
    expect(paragraphStarts.slice(0, 2)).toEqual([1, 6])
  })

  it("keeps the Song of Songs' speakers out of the words of its verses", () => {
    const song = getBook("SNG", "web-ce").chapters[0]
    const verse = song.verses.find((candidate) => candidate.n === "4")
    expect(verse?.t).toBe(
      "Take me away with you. Let’s hurry. The king has brought me into his rooms. We will be glad and rejoice in you. We will praise your love more than wine! They are right to love you.",
    )

    const layout = layoutChapter(song)
    const speakers = layout.blocks.flatMap((block) =>
      block.type === "heading" && block.kind === "sp" ? [block.text] : [],
    )
    expect(speakers.slice(0, 3)).toEqual(["Beloved", "Friends", "Beloved"])
  })
})
