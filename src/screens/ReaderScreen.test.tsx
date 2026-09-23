import { StyleSheet } from "react-native"
import { NavigationContainer } from "@react-navigation/native"
import { act, fireEvent, render, waitFor } from "@testing-library/react-native"

import { setReaderLayout, setReaderLocation, setTranslationId } from "@/services/bible"
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
const mockIsPassageBookmarked = jest.fn().mockResolvedValue(false)
const mockApplyHighlight = jest.fn().mockResolvedValue(undefined)
const mockClearHighlight = jest.fn().mockResolvedValue(undefined)
const mockGetChapterHighlights = jest.fn().mockResolvedValue({})
const mockLibraryDatabase = {}
const mockFocusCallbacks = new Set<() => void | (() => void)>()

jest.mock("expo-router", () => ({
  useLocalSearchParams: () => mockParams,
  useRouter: () => ({ push: mockRouterPush }),
  useFocusEffect: (callback: () => void | (() => void)) => {
    const React = jest.requireActual("react")
    React.useEffect(() => {
      mockFocusCallbacks.add(callback)
      const cleanup = callback()
      return () => {
        mockFocusCallbacks.delete(callback)
        if (typeof cleanup === "function") cleanup()
      }
    }, [callback])
  },
}))

/** The Read tab stays mounted; coming back to it only re-runs focus effects. */
function refocusReader() {
  act(() => {
    mockFocusCallbacks.forEach((callback) => callback())
  })
}

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
    isPassageBookmarked: (...args: unknown[]) => mockIsPassageBookmarked(...args),
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
    mockIsPassageBookmarked.mockReset().mockResolvedValue(false)
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

  it("reopens the chapter the reader left, where they left it", async () => {
    setReaderLocation({ book: "JHN", chapter: 3, scrollY: 240 })
    const screen = render(reader())

    expect(screen.getByText("John 3")).toBeDefined()
    await waitFor(() => expect(mockScrollTo).toHaveBeenCalledWith({ y: 240, animated: false }))

    // The book list is a step back, and still offers the way back in.
    fireEvent.press(screen.getByLabelText("Back to John chapters"))
    fireEvent.press(screen.getByLabelText("Back to books"))
    expect(screen.getByText("Continue reading")).toBeDefined()
    fireEvent.press(screen.getByLabelText("Continue reading John chapter 3"))
    await waitFor(() => expect(screen.getByText("John 3")).toBeDefined())
  })

  it("opens the book and chapter picker from the chapter title", async () => {
    mockParams = { book: "JHN", chapter: "3", contextRequest: "title-test" }
    const screen = render(reader())
    await waitFor(() => expect(screen.getByText("John 3")).toBeDefined())

    fireEvent.press(screen.getByTestId("reader-title"))

    expect(mockRouterPush).toHaveBeenCalledWith({
      pathname: "/go-to",
      params: { book: "JHN", chapter: "3" },
    })
  })

  it("shows the open chapter in a translation chosen in Settings", async () => {
    mockParams = { book: "JHN", chapter: "1", contextRequest: "translation-test" }
    const screen = render(reader())
    await waitFor(() => expect(screen.getByText(/hasn’t overcome it/)).toBeDefined())

    // Move on from the requested chapter, so a switch must not replay the request.
    fireEvent.press(screen.getByLabelText("Next chapter, John chapter 2"))
    await waitFor(() => expect(screen.getByText(/wedding in Cana/)).toBeDefined())

    setTranslationId("douay-rheims")
    refocusReader()

    await waitFor(() => expect(screen.getByText(/marriage in Cana/)).toBeDefined())
    expect(screen.getByText("John 2")).toBeDefined()
  })

  it("explains verse selection only until the reader has used it", async () => {
    const hint = "Tap a verse to select it. Tap another verse to select a range."
    mockParams = { book: "JHN", chapter: "3", contextRequest: "hint-test" }
    const screen = render(reader())
    await waitFor(() => expect(screen.getByText("John 3")).toBeDefined())
    expect(screen.getByText(hint)).toBeDefined()

    fireEvent.press(screen.getByTestId("reader-verse-16"))
    fireEvent.press(screen.getByLabelText("Clear passage selection"))
    fireEvent.press(screen.getByLabelText("Next chapter, John chapter 4"))

    await waitFor(() => expect(screen.getByText("John 4")).toBeDefined())
    expect(screen.queryByText(hint)).toBeNull()
  })

  it("moves directly to the next chapter", async () => {
    mockParams = { book: "JHN", chapter: "3", contextRequest: "next-test" }
    const screen = render(reader())
    await waitFor(() => expect(screen.getByText("John 3")).toBeDefined())

    fireEvent.press(screen.getByLabelText("Next chapter, John chapter 4"))

    await waitFor(() => expect(screen.getByText("John 4")).toBeDefined())
  })

  it("scrolls a linked context verse into view after layout, verse by verse", async () => {
    setReaderLayout("verses")
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

  it("scrolls to the line where a linked verse begins inside a paragraph", async () => {
    mockParams = { book: "JHN", chapter: "3", verse: "16", contextRequest: "paragraph-scroll" }
    const screen = render(reader())
    await waitFor(() => expect(screen.getByTestId("reader-context-block")).toBeDefined())

    fireEvent(screen.getByTestId("reader-verse-block"), "layout", {
      nativeEvent: { layout: { x: 0, y: 120, width: 300, height: 900 } },
    })
    fireEvent(screen.getByTestId("reader-context-block"), "layout", {
      nativeEvent: { layout: { x: 0, y: 480, width: 300, height: 400 } },
    })
    // John 3:16 continues the paragraph that verse 10 begins, so it is not on
    // the block's first line.
    fireEvent(screen.getByTestId("reader-context-block-text"), "textLayout", {
      nativeEvent: {
        lines: [
          { text: "N", x: 0, y: 0, width: 10, height: 30, ascender: 0, capHeight: 0 },
          {
            text: "x".repeat(5000),
            x: 0,
            y: 36,
            width: 300,
            height: 30,
            ascender: 0,
            capHeight: 0,
          },
        ],
      },
    })

    await waitFor(() => expect(mockScrollTo).toHaveBeenCalledWith({ y: 612, animated: true }))
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
    // The toolbar now shows the passage as bookmarked.
    await waitFor(() =>
      expect(screen.getByLabelText("Bookmark John 3:16").props.accessibilityState).toEqual({
        selected: true,
      }),
    )
    expect(screen.getByText("Saved")).toBeDefined()

    // Colours apply in one tap, and the applied one becomes the way to remove it.
    fireEvent.press(screen.getByLabelText("Apply gold highlight"))
    await waitFor(() => expect(mockApplyHighlight).toHaveBeenCalled())
    await waitFor(() => expect(screen.getByLabelText("Remove gold highlight")).toBeDefined())
    fireEvent.press(screen.getByLabelText("Remove gold highlight"))
    await waitFor(() => expect(mockClearHighlight).toHaveBeenCalled())

    fireEvent.press(screen.getByLabelText("Note John 3:16"))
    expect(mockRouterPush).toHaveBeenCalledWith(
      expect.objectContaining({
        pathname: "/note",
        params: expect.objectContaining({ book: "JHN", chapter: "3", startVerse: "16" }),
      }),
    )
  })

  it("shows a passage that is already bookmarked, so a second tap reads as removal", async () => {
    mockIsPassageBookmarked.mockResolvedValue(true)
    mockToggleBookmark.mockResolvedValueOnce(false)
    mockParams = { book: "JHN", chapter: "3", contextRequest: "bookmarked-test" }
    const screen = render(reader())
    await waitFor(() => expect(screen.getByText("John 3")).toBeDefined())

    fireEvent.press(screen.getByTestId("reader-verse-16"))
    await waitFor(() => expect(screen.getByText("Saved")).toBeDefined())

    fireEvent.press(screen.getByLabelText("Bookmark John 3:16"))
    await waitFor(() => expect(screen.getByText("Bookmark removed")).toBeDefined())
    expect(screen.getByLabelText("Bookmark John 3:16").props.accessibilityState).toEqual({
      selected: false,
    })
  })

  it("restyles the chapter from the Aa sheet as each option is chosen", async () => {
    setReaderLayout("verses")
    mockParams = { book: "JHN", chapter: "3", contextRequest: "text-settings-test" }
    const screen = render(reader())
    await waitFor(() => expect(screen.getByText("John 3")).toBeDefined())
    const verseFontSize = () =>
      StyleSheet.flatten(screen.getByText(/For God so loved the world/).props.style).fontSize
    expect(verseFontSize()).toBe(18)

    fireEvent.press(screen.getByLabelText("Text settings"))
    fireEvent.press(screen.getByLabelText("Text size, Extra large"))

    // The chapter behind the sheet follows at once, before the sheet closes.
    expect(verseFontSize()).toBe(24)
    fireEvent.press(screen.getByLabelText("Done"))
    expect(screen.queryByTestId("text-settings-sheet")).toBeNull()
  })
})
