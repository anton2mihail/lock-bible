import { fireEvent, render } from "@testing-library/react-native"

import { ThemeProvider } from "@/theme/context"
import { clear } from "@/utils/storage"

import { GoToScreen } from "./GoToScreen"

let mockParams: { book?: string; chapter?: string } = {}
const mockDismissTo = jest.fn()
const mockBack = jest.fn()

jest.mock("expo-router", () => ({
  useLocalSearchParams: () => mockParams,
  useRouter: () => ({
    dismissTo: mockDismissTo,
    back: mockBack,
    canGoBack: () => true,
    replace: jest.fn(),
  }),
}))

function goTo() {
  return (
    <ThemeProvider>
      <GoToScreen />
    </ThemeProvider>
  )
}

describe("GoToScreen", () => {
  beforeEach(() => {
    mockParams = { book: "JHN", chapter: "3" }
    mockDismissTo.mockClear()
    mockBack.mockClear()
    clear()
  })

  it("opens the book being read to its chapters, with the current one marked", () => {
    const screen = render(goTo())

    expect(screen.getByLabelText("John chapter 21")).toBeDefined()
    expect(screen.getByLabelText("John chapter 3").props.accessibilityState).toEqual({
      selected: true,
    })
    expect(screen.queryByLabelText("Genesis chapter 1")).toBeNull()
  })

  it("goes straight to a chosen chapter", () => {
    const screen = render(goTo())

    fireEvent.press(screen.getByLabelText("John chapter 5"))

    expect(mockDismissTo).toHaveBeenCalledWith(
      expect.objectContaining({
        pathname: "/read",
        params: expect.objectContaining({ book: "JHN", chapter: "5" }),
      }),
    )
  })

  it("opens one book at a time, and goes straight into books of one chapter", () => {
    const screen = render(goTo())

    fireEvent.press(screen.getByLabelText("Genesis, 50 chapters"))
    expect(screen.getByLabelText("Genesis chapter 50")).toBeDefined()
    expect(screen.queryByLabelText("John chapter 21")).toBeNull()

    fireEvent.press(screen.getByLabelText("Obadiah, 1 chapter"))
    expect(mockDismissTo).toHaveBeenCalledWith(
      expect.objectContaining({ params: expect.objectContaining({ book: "OBA", chapter: "1" }) }),
    )
  })

  it("closes back to the chapter being read", () => {
    const screen = render(goTo())

    fireEvent.press(screen.getByLabelText("Close"))

    expect(mockBack).toHaveBeenCalled()
  })
})
