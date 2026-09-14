import { fireEvent, render, waitFor } from "@testing-library/react-native"

import { ThemeProvider } from "@/theme/context"

import { SavedScreen } from "./SavedScreen"

const mockPush = jest.fn()
const mockListSavedItems = jest.fn()
const mockDeleteSavedItem = jest.fn().mockResolvedValue(undefined)
const mockRestoreSavedItem = jest.fn().mockResolvedValue(undefined)
const mockLibraryDatabase = {}

jest.mock("expo-router", () => ({
  useRouter: () => ({ push: mockPush }),
  useFocusEffect: (callback: () => void | (() => void)) => {
    const React = jest.requireActual("react")
    React.useEffect(callback, [callback])
  },
}))

jest.mock("@/services/database", () => ({
  useLibraryDatabase: () => mockLibraryDatabase,
}))

jest.mock("@/services/library", () => ({
  listSavedItems: (...args: unknown[]) => mockListSavedItems(...args),
  deleteSavedItem: (...args: unknown[]) => mockDeleteSavedItem(...args),
  restoreSavedItem: (...args: unknown[]) => mockRestoreSavedItem(...args),
}))

const bookmark = {
  id: "bookmark:web-ce:JHN:3:16:18",
  kind: "bookmark",
  translationId: "web-ce",
  bookCode: "JHN",
  bookName: "John",
  bookOrder: 65,
  chapter: 3,
  startVerse: "16",
  endVerse: "18",
  startIndex: 15,
  endIndex: 17,
  scriptureText: "16 For God so loved the world",
  reference: "John 3:16–18",
  createdAt: 1,
  updatedAt: 1,
}

function savedScreen() {
  return (
    <ThemeProvider>
      <SavedScreen />
    </ThemeProvider>
  )
}

describe("SavedScreen", () => {
  beforeEach(() => {
    mockPush.mockClear()
    mockDeleteSavedItem.mockClear()
    mockRestoreSavedItem.mockClear()
    mockListSavedItems.mockResolvedValue([bookmark])
  })

  it("opens a saved range in the reader", async () => {
    const screen = render(savedScreen())
    await waitFor(() => expect(screen.getByText("John 3:16–18")).toBeDefined())
    fireEvent.press(screen.getByLabelText(/John 3:16–18, bookmark/))
    expect(mockPush).toHaveBeenCalledWith(
      expect.objectContaining({
        pathname: "/read",
        params: expect.objectContaining({ verse: "16", endVerse: "18" }),
      }),
    )
  })

  it("deletes a saved item and offers undo", async () => {
    const screen = render(savedScreen())
    await waitFor(() => expect(screen.getByText("John 3:16–18")).toBeDefined())
    fireEvent.press(screen.getByLabelText("Delete saved John 3:16–18"))
    await waitFor(() => expect(screen.getByText("Undo")).toBeDefined())
    fireEvent.press(screen.getByText("Undo"))
    await waitFor(() =>
      expect(mockRestoreSavedItem).toHaveBeenCalledWith(mockLibraryDatabase, bookmark),
    )
  })
})
