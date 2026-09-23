import { StyleSheet } from "react-native"
import { render } from "@testing-library/react-native"

import type { Chapter, ReaderLayout } from "@/services/bible"
import { ThemeProvider } from "@/theme/context"

import { ChapterText, HIGHLIGHT_FILLS } from "./ChapterText"

const chapter: Chapter = {
  c: 3,
  verses: [
    { n: "15", t: "that whoever believes in him should not perish.", br: [[0, "p"]] },
    { n: "16", t: "For God so loved the world." },
  ],
}

const passageStyle = { fontSize: 18, lineHeight: 30 }

function renderChapter(layout: ReaderLayout) {
  return render(
    <ThemeProvider>
      <ChapterText
        chapter={chapter}
        layout={layout}
        passageStyle={passageStyle}
        selectionRange={[1, 1]}
        contextRange={null}
        highlights={{ "16": "sage" }}
        onSelectVerse={() => {}}
        onContextVerseY={() => {}}
      />
    </ThemeProvider>,
  )
}

describe("ChapterText selection", () => {
  it("keeps a selected verse's highlight showing inside its outline, verse by verse", () => {
    const screen = renderChapter("verses")
    const style = StyleSheet.flatten(screen.getByTestId("reader-verse-16").props.style)

    expect(style.backgroundColor).toBe(HIGHLIGHT_FILLS.sage.light)
    expect(style.borderWidth).toBe(1.5)
  })

  it("keeps a selected verse's highlight showing under its underline, in paragraphs", () => {
    const screen = renderChapter("paragraphs")
    const style = StyleSheet.flatten(screen.getByTestId("reader-verse-16").props.style)

    expect(style.backgroundColor).toBe(HIGHLIGHT_FILLS.sage.light)
    expect(style.textDecorationLine).toBe("underline")
  })
})

describe("ChapterText verse numbers", () => {
  // iOS spaces a whole paragraph by the line height of its first character,
  // and every verse starts with its number: a number set in the small size's
  // own line height packed the lines, whatever the reader chose.
  it.each<ReaderLayout>(["paragraphs", "verses"])(
    "carry the passage's line height, %s",
    (layout) => {
      const screen = renderChapter(layout)

      for (const number of ["15", "16"]) {
        const style = StyleSheet.flatten(screen.getByText(number).props.style)
        expect(style.lineHeight).toBe(passageStyle.lineHeight)
      }
    },
  )
})
