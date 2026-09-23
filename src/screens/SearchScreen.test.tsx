import { fireEvent, render, waitFor } from "@testing-library/react-native"

import { ThemeProvider } from "@/theme/context"

import { SearchScreen } from "./SearchScreen"

const mockDismissTo = jest.fn()
const mockBack = jest.fn()
const mockReplace = jest.fn()
const mockCanGoBack = jest.fn(() => true)
const mockSearchBible = jest.fn()
const mockSearchDatabase = {}

jest.mock("expo-router", () => ({
  useRouter: () => ({
    dismissTo: mockDismissTo,
    back: mockBack,
    replace: mockReplace,
    canGoBack: mockCanGoBack,
  }),
}))

jest.mock("@/services/database", () => ({
  useSearchDatabase: () => mockSearchDatabase,
}))

jest.mock("@/services/bible/searchService", () => ({
  searchBible: (...args: unknown[]) => mockSearchBible(...args),
}))

function searchScreen() {
  return (
    <ThemeProvider>
      <SearchScreen />
    </ThemeProvider>
  )
}

describe("SearchScreen", () => {
  beforeEach(() => {
    jest.useRealTimers()
    mockDismissTo.mockClear()
    mockBack.mockClear()
    mockReplace.mockClear()
    mockCanGoBack.mockReturnValue(true)
    mockSearchBible.mockReset()
  })

  it("searches locally and opens the exact result in context", async () => {
    mockSearchBible.mockResolvedValue({
      isReference: false,
      results: [
        {
          id: 1,
          bookCode: "JHN",
          bookName: "John",
          group: "nt",
          chapter: 3,
          verse: "16",
          verseOrder: 15,
          text: "For God so loved the world",
          reference: "John 3:16",
        },
      ],
    })
    const screen = render(searchScreen())
    fireEvent.changeText(screen.getByLabelText("Search Scripture"), "God so loved")

    await waitFor(() => expect(screen.getByText("John 3:16")).toBeDefined())
    expect(mockSearchBible).toHaveBeenCalledWith(mockSearchDatabase, "God so loved", "all")

    expect(screen.getByText("1 result")).toBeDefined()

    fireEvent.press(screen.getByTestId("search-result-JHN-3-16"))
    expect(mockDismissTo).toHaveBeenCalledWith(
      expect.objectContaining({
        pathname: "/read",
        params: expect.objectContaining({ book: "JHN", chapter: "3", verse: "16" }),
      }),
    )
  })

  it("closes back to the screen that opened it", () => {
    const screen = render(searchScreen())
    fireEvent.press(screen.getByLabelText("Close search"))
    expect(mockBack).toHaveBeenCalled()

    mockCanGoBack.mockReturnValue(false)
    fireEvent.press(screen.getByLabelText("Close search"))
    expect(mockReplace).toHaveBeenCalledWith("/read")
  })

  it("discloses a lightly corrected query", async () => {
    mockSearchBible.mockResolvedValue({
      isReference: true,
      correctedQuery: "Philippians 4:6",
      results: [],
    })
    const screen = render(searchScreen())
    fireEvent.changeText(screen.getByLabelText("Search Scripture"), "Phillipians 4:6")
    await waitFor(() =>
      expect(screen.getByText("Showing results for “Philippians 4:6”")).toBeDefined(),
    )
  })
})
