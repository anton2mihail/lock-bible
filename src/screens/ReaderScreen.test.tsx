import { NavigationContainer } from "@react-navigation/native"
import { fireEvent, render, waitFor } from "@testing-library/react-native"

import { setReaderLocation } from "@/services/bible"
import { ThemeProvider } from "@/theme/context"
import { clear } from "@/utils/storage"

import { ReaderScreen } from "./ReaderScreen"

let mockParams: {
  book?: string
  chapter?: string
  verse?: string
  endVerse?: string
  contextRequest?: string
} = {}

const mockScrollTo = jest.fn()
const mockRouterPush = jest.fn()
const mockClipboardSet = jest.fn()
const mockToggleBookmark = jest.fn().mockResolvedValue(true)
const mockApplyHighlight = jest.fn().mockResolvedValue(undefined)
const mockClearHighlight = jest.fn().mockResolvedValue(undefined)
const mockGetChapterHighlights = jest.fn().mockResolvedValue({})
const mockLibraryDatabase = {}

jest.mock("expo-router", () => ({
  useLocalSearchParams: () => mockParams,
  useRouter: () => ({ push: mockRouterPush }),
  useFocusEffect: (callback: () => void | (() => void)) => {
    const React = jest.requireActual("react")
    React.useEffect(callback, [callback])
  },
}))

jest.mock("expo-clipboard", () => ({
  setStringAsync: (...args: unknown[]) => mockClipboardSet(...args),
}))

jest.mock("@/services/database", () => ({
  useLibraryDatabase: () => mockLibraryDatabase,
}))

jest.mock("@/services/library", () => {
  const actual = jest.requireActual("@/services/library")
  return {
    ...actual,
    toggleBookmark: (...args: unknown[]) => mockToggleBookmark(...args),
    applyHighlight: (...args: unknown[]) => mockApplyHighlight(...args),
    clearHighlight: (...args: unknown[]) => mockClearHighlight(...args),
    getChapterHighlights: (...args: unknown[]) => mockGetChapterHighlights(...args),
  }
})

jest.mock("@/components/Screen", () => {
  const React = jest.requireActual("react")
  const { View } = jest.requireActual("react-native")
  return {
    Screen: ({
      children,
      scrollViewRef,
      ScrollViewProps,
    }: {
      children: React.ReactNode
      scrollViewRef?: React.MutableRefObject<{ scrollTo: typeof mockScrollTo } | null>
      ScrollViewProps?: { onContentSizeChange?: (width: number, height: number) => void }
    }) => {
      if (scrollViewRef) scrollViewRef.current = { scrollTo: mockScrollTo }
      React.useEffect(() => {
        ScrollViewProps?.onContentSizeChange?.(320, 1200)
      }, [ScrollViewProps])
      return React.createElement(View, null, children)
    },
  }
})

jest.mock("@/components/Icon", () => {
  const React = jest.requireActual("react")
  const { View } = jest.requireActual("react-native")
  return { Icon: () => React.createElement(View) }
})

function reader() {
  return (
    <ThemeProvider>
      <NavigationContainer>
        <ReaderScreen />
      </NavigationContainer>
    </ThemeProvider>
  )
}

describe("ReaderScreen context navigation", () => {
  beforeEach(() => {
    mockParams = {}
    mockScrollTo.mockClear()
    mockRouterPush.mockClear()
    mockClipboardSet.mockClear()
    mockToggleBookmark.mockClear()
    mockApplyHighlight.mockClear()
    mockClearHighlight.mockClear()
    mockGetChapterHighlights.mockClear()
    clear()
  })

  it("opens a requested chapter even when the reader tab is already mounted", async () => {
    const screen = render(reader())
    expect(screen.getByText("Read the Bible")).toBeDefined()

    mockParams = {
      book: "JHN",
      chapter: "3",
      verse: "16",
      contextRequest: "first",
    }
    screen.rerender(reader())

    await waitFor(() => expect(screen.getByText("John 3")).toBeDefined())
    expect(screen.getByText(/For God so loved the world/)).toBeDefined()

    // Navigating back changes local reader state while the route params remain.
    fireEvent.press(screen.getByLabelText("Back to John chapters"))
    expect(screen.queryByText(/For God so loved the world/)).toBeNull()

    // A fresh request for the same passage must still be honored.
    mockParams = { ...mockParams, contextRequest: "second" }
    screen.rerender(reader())
    await waitFor(() => expect(screen.getByText(/For God so loved the world/)).toBeDefined())
  })

  it("offers the saved chapter as an explicit Continue Reading action", async () => {
    setReaderLocation({ book: "JHN", chapter: 3, scrollY: 240 })
    const screen = render(reader())

    expect(screen.getByText("Continue reading")).toBeDefined()
    fireEvent.press(screen.getByLabelText("Continue reading John chapter 3"))

    await waitFor(() => expect(screen.getByText("John 3")).toBeDefined())
    await waitFor(() => expect(mockScrollTo).toHaveBeenCalledWith({ y: 240, animated: false }))
  })

  it("moves directly to the next chapter", async () => {
    mockParams = { book: "JHN", chapter: "3", contextRequest: "next-test" }
    const screen = render(reader())
    await waitFor(() => expect(screen.getByText("John 3")).toBeDefined())

    fireEvent.press(screen.getByLabelText("Next chapter, John chapter 4"))

    await waitFor(() => expect(screen.getByText("John 4")).toBeDefined())
  })

  it("scrolls a linked context verse into view after layout", async () => {
    mockParams = { book: "JHN", chapter: "3", verse: "16", contextRequest: "scroll-test" }
    const screen = render(reader())
    await waitFor(() => expect(screen.getByTestId("reader-context-verse")).toBeDefined())

    fireEvent(screen.getByTestId("reader-verse-block"), "layout", {
      nativeEvent: { layout: { x: 0, y: 120, width: 300, height: 900 } },
    })
    fireEvent(screen.getByTestId("reader-context-verse"), "layout", {
      nativeEvent: { layout: { x: 0, y: 480, width: 300, height: 60 } },
    })

    await waitFor(() => expect(mockScrollTo).toHaveBeenCalledWith({ y: 576, animated: true }))
  })

  it("selects a single verse and extends it to a contiguous range", async () => {
    mockParams = { book: "JHN", chapter: "3", contextRequest: "selection-test" }
    const screen = render(reader())
    await waitFor(() => expect(screen.getByText("John 3")).toBeDefined())

    fireEvent.press(screen.getByTestId("reader-verse-16"))
    expect(screen.getByText("John 3:16")).toBeDefined()

    fireEvent.press(screen.getByTestId("reader-verse-18"))
    expect(screen.getByText("John 3:16–18")).toBeDefined()

    fireEvent.press(screen.getByLabelText("Copy John 3:16–18"))
    await waitFor(() => expect(mockClipboardSet).toHaveBeenCalled())
    expect(mockClipboardSet.mock.calls[0][0]).toContain("John 3:16–18")
  })

  it("bookmarks, highlights, and opens a note for the selected passage", async () => {
    mockParams = { book: "JHN", chapter: "3", contextRequest: "actions-test" }
    const screen = render(reader())
    await waitFor(() => expect(screen.getByText("John 3")).toBeDefined())

    fireEvent.press(screen.getByTestId("reader-verse-16"))
    fireEvent.press(screen.getByLabelText("Bookmark John 3:16"))
    await waitFor(() => expect(mockToggleBookmark).toHaveBeenCalled())

    fireEvent.press(screen.getByLabelText("Highlight John 3:16"))
    fireEvent.press(screen.getByLabelText("Apply gold highlight"))
    await waitFor(() => expect(mockApplyHighlight).toHaveBeenCalled())

    fireEvent.press(screen.getByLabelText("Note John 3:16"))
    expect(mockRouterPush).toHaveBeenCalledWith(
      expect.objectContaining({
        pathname: "/note",
        params: expect.objectContaining({ book: "JHN", chapter: "3", startVerse: "16" }),
      }),
    )
  })
})
