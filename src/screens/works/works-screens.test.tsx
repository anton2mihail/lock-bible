import { fireEvent, render, waitFor } from "@testing-library/react-native"

import {
  COLLECTIONS,
  getChapterCommentary,
  getCollection,
  getCollectionWorks,
  WORK_KIND_LABEL,
} from "@/services/works"
import { ThemeProvider } from "@/theme/context"

import { ChapterCommentaryScreen } from "./chapter-commentary-screen"
import { WorkReaderScreen } from "./work-reader-screen"
import { WorksCollectionScreen } from "./works-collection-screen"
import { WorksLibraryScreen } from "./works-library-screen"

const mockRouterPush = jest.fn()
const mockGetFirstAsync = jest.fn()
const mockGetAllAsync = jest.fn()
let mockDatabaseState: "opening" | "ready" | "failed" = "ready"

jest.mock("expo-router", () => ({
  useRouter: () => ({ push: mockRouterPush, back: jest.fn() }),
  useLocalSearchParams: () => ({}),
  useFocusEffect: (callback: () => void | (() => void)) => {
    const React = jest.requireActual("react")
    React.useEffect(callback, [callback])
  },
}))

jest.mock("@/services/database", () => ({
  useWorksDatabase: () => ({ getFirstAsync: mockGetFirstAsync, getAllAsync: mockGetAllAsync }),
  useWorksDatabaseState: () => mockDatabaseState,
}))

jest.mock("@/components/Screen", () => {
  const React = jest.requireActual("react")
  const { View } = jest.requireActual("react-native")
  return {
    Screen: ({ children }: { children: React.ReactNode }) =>
      React.createElement(View, null, children),
  }
})

// The real one paginates by measuring every paragraph with onTextLayout, which
// never fires without a layout pass. Render the prose plainly instead so the
// tests can assert on what the reader actually loaded.
jest.mock("@/components/PaginatedProse", () => {
  const React = jest.requireActual("react")
  const { Text, View } = jest.requireActual("react-native")
  return {
    PaginatedProse: ({ paragraphs }: { paragraphs: readonly string[] }) =>
      React.createElement(
        View,
        null,
        paragraphs.map((p, i) => React.createElement(Text, { key: i }, p)),
      ),
  }
})

function screen(element: React.ReactElement) {
  return render(<ThemeProvider>{element}</ThemeProvider>)
}

beforeEach(() => {
  mockRouterPush.mockClear()
  mockGetFirstAsync.mockReset()
  mockGetAllAsync.mockReset()
  mockDatabaseState = "ready"
})

describe("works library", () => {
  test("lists every author in the library", () => {
    const view = screen(<WorksLibraryScreen />)
    expect(COLLECTIONS.length).toBeGreaterThan(20)
    for (const collection of COLLECTIONS) {
      expect(view.getByTestId(`collection-${collection.id}`)).toBeTruthy()
    }
    expect(view.getByText("The Fathers & Doctors")).toBeTruthy()
  })

  test("names each author and how much of them there is", () => {
    const view = screen(<WorksLibraryScreen />)
    expect(view.getByText("St Augustine of Hippo")).toBeTruthy()
    expect(view.getByText("St Thomas Aquinas")).toBeTruthy()
    expect(view.getByText("The Apostolic Fathers")).toBeTruthy()
  })
})

describe("an author's shelf", () => {
  test("groups works by what they are, not only by the book they expound", () => {
    // The point of the grouping: most of the corpus comments on no chapter of
    // Scripture, and those works still need a heading of their own.
    const view = screen(<WorksCollectionScreen collectionId="augustine" />)
    expect(view.getByText("St Augustine of Hippo")).toBeTruthy()

    const works = getCollectionWorks("augustine")
    const kinds = new Set(works.map((work) => work.kind))
    expect(kinds.size).toBeGreaterThan(1)
    for (const kind of kinds) {
      expect(view.getByText(WORK_KIND_LABEL[kind])).toBeTruthy()
    }
  })

  test("shows works that map to no Bible chapter at all", () => {
    const view = screen(<WorksCollectionScreen collectionId="augustine" />)
    const unmapped = getCollectionWorks("augustine").filter((work) => !work.book)
    expect(unmapped.length).toBeGreaterThan(10)
    for (const work of unmapped.slice(0, 8)) {
      expect(view.getByTestId(`work-${work.id}`)).toBeTruthy()
    }
  })

  test("credits the translation it ships", () => {
    const view = screen(<WorksCollectionScreen collectionId="aquinas" />)
    expect(view.getByText(/English Dominican Province/)).toBeTruthy()
  })

  test("says so rather than rendering blank for an unknown author", () => {
    const view = screen(<WorksCollectionScreen collectionId="not-an-author" />)
    expect(view.getByText("That author isn’t available")).toBeTruthy()
  })
})

describe("the reader", () => {
  const work = getCollectionWorks("augustine").find(
    (candidate) => candidate.id === "augustine.the-confessions",
  )

  test("loads a section from the database and renders its prose", async () => {
    expect(work).toBeDefined()
    mockGetFirstAsync.mockResolvedValue({
      idx: 0,
      title: "Book I",
      words: 3,
      paragraphs: JSON.stringify(["Thou hast made us for Thyself."]),
    })

    const view = screen(<WorkReaderScreen workId={work!.id} section="0" />)
    await waitFor(() => expect(view.getByText("Thou hast made us for Thyself.")).toBeTruthy())
    expect(mockGetFirstAsync).toHaveBeenCalledWith(expect.stringContaining("FROM sections"), [
      work!.id,
      0,
    ])
  })

  test("reports a section it cannot open instead of spinning for ever", async () => {
    mockGetFirstAsync.mockResolvedValue(null)
    const view = screen(<WorkReaderScreen workId={work!.id} section="0" />)
    await waitFor(() => expect(view.getByText("That section could not be opened")).toBeTruthy())
  })

  test("survives a database error the same way", async () => {
    mockGetFirstAsync.mockRejectedValue(new Error("disk is on fire"))
    const view = screen(<WorkReaderScreen workId={work!.id} section="0" />)
    await waitFor(() => expect(view.getByText("That section could not be opened")).toBeTruthy())
  })

  test("says so when the library database could not be opened at all", async () => {
    // A device with no room left: the 43MB copy fails. The library should say
    // so rather than spin for ever, and the rest of the app is unaffected
    // because nothing outside /works opens this database.
    mockDatabaseState = "failed"
    const view = screen(<WorkReaderScreen workId={work!.id} section="0" />)
    await waitFor(() =>
      expect(view.getByText("The library could not be opened on this device")).toBeTruthy(),
    )
    expect(mockGetFirstAsync).not.toHaveBeenCalled()
  })

  test("says so rather than rendering blank for an unknown work", () => {
    const view = screen(<WorkReaderScreen workId="not-a-work" />)
    expect(view.getByText("That work isn’t available")).toBeTruthy()
  })
})

describe("the chapter commentary list", () => {
  test("lists every reading on a chapter, grouped by author", () => {
    // John 1 is the densest chapter in the index and draws on more than one
    // Father, which is the case the Bible reader could not previously reach.
    const entries = getChapterCommentary("JHN", 1)
    expect(entries.length).toBeGreaterThan(3)

    const view = screen(<ChapterCommentaryScreen book="JHN" chapter="1" />)
    for (const entry of entries) {
      expect(view.getByTestId(`commentary-${entry.workId}-${entry.sectionIndex}`)).toBeTruthy()
    }
    const authors = new Set(entries.map((entry) => entry.collectionId))
    for (const id of authors) {
      expect(view.getAllByText(getCollection(id)!.author).length).toBeGreaterThan(0)
    }
  })

  test("reaches every reading, not just the three the Bible reader previews", () => {
    const entries = getChapterCommentary("JHN", 1)
    const view = screen(<ChapterCommentaryScreen book="JHN" chapter="1" />)
    const rows = entries.filter((_, index) => index >= 3)
    expect(rows.length).toBeGreaterThan(0)
    for (const entry of rows) {
      expect(view.getByTestId(`commentary-${entry.workId}-${entry.sectionIndex}`)).toBeTruthy()
    }
  })

  test("says so for a chapter no Father commented on", () => {
    const view = screen(<ChapterCommentaryScreen book="OBA" chapter="1" />)
    expect(view.getByText("No readings on this chapter")).toBeTruthy()
  })
})

describe("the reader's table of contents", () => {
  test("loads section titles on demand and jumps to one", async () => {
    const work = getCollectionWorks("augustine").find(
      (candidate) => candidate.id === "augustine.expositions-on-the-book-of-psalms",
    )
    expect(work).toBeDefined()
    mockGetFirstAsync.mockResolvedValue({
      idx: 0,
      title: "Psalm I",
      words: 2,
      paragraphs: JSON.stringify(["Blessed is the man."]),
    })
    mockGetAllAsync.mockResolvedValue([
      { idx: 0, title: "Psalm I", words: 2 },
      { idx: 22, title: "Psalm XXIII", words: 2 },
    ])

    const view = screen(<WorkReaderScreen workId={work!.id} section="0" />)
    await waitFor(() => expect(view.getByText("Blessed is the man.")).toBeTruthy())

    // The "N of M" footer is the control; it was previously inert text.
    fireEvent.press(view.getByLabelText(/^Contents, /))
    await waitFor(() => expect(view.getByText("Psalm XXIII")).toBeTruthy())
    expect(mockGetAllAsync).toHaveBeenCalledWith(expect.stringContaining("ORDER BY idx"), [
      work!.id,
    ])
  })
})
