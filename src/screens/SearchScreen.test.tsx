import { fireEvent, render, waitFor } from "@testing-library/react-native"

import { ThemeProvider } from "@/theme/context"

import { SearchScreen } from "./SearchScreen"

const mockPush = jest.fn()
const mockBack = jest.fn()
const mockSearchBible = jest.fn()
const mockSearchDatabase = {}

jest.mock("expo-router", () => ({
  useRouter: () => ({ push: mockPush, back: mockBack }),
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
    mockPush.mockClear()
    mockBack.mockClear()
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

    fireEvent.press(screen.getByTestId("search-result-JHN-3-16"))
    expect(mockPush).toHaveBeenCalledWith(
      expect.objectContaining({
        pathname: "/read",
        params: expect.objectContaining({ book: "JHN", chapter: "3", verse: "16" }),
      }),
    )
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
