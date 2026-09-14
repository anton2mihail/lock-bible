import { fireEvent, render, waitFor } from "@testing-library/react-native"

import { ThemeProvider } from "@/theme/context"

import { NoteEditorScreen } from "./NoteEditorScreen"

const mockBack = jest.fn()
const mockGetNote = jest.fn()
const mockSaveNote = jest.fn()
const mockDeleteNote = jest.fn()
const mockLibraryDatabase = {}

jest.mock("expo-router", () => ({
  useLocalSearchParams: () => ({
    book: "JHN",
    chapter: "3",
    startVerse: "16",
    endVerse: "18",
  }),
  useRouter: () => ({ back: mockBack }),
}))

jest.mock("@/services/database", () => ({
  useLibraryDatabase: () => mockLibraryDatabase,
}))

jest.mock("@/services/library", () => {
  const actual = jest.requireActual("@/services/library")
  return {
    ...actual,
    getNote: (...args: unknown[]) => mockGetNote(...args),
    saveNote: (...args: unknown[]) => mockSaveNote(...args),
    deleteNote: (...args: unknown[]) => mockDeleteNote(...args),
  }
})

function noteEditor() {
  return (
    <ThemeProvider>
      <NoteEditorScreen />
    </ThemeProvider>
  )
}

describe("NoteEditorScreen", () => {
  beforeEach(() => {
    mockBack.mockClear()
    mockGetNote.mockReset().mockResolvedValue("Remember this")
    mockSaveNote.mockReset().mockResolvedValue(undefined)
    mockDeleteNote.mockReset().mockResolvedValue(undefined)
  })

  it("loads and saves a private note for the full selected range", async () => {
    const screen = render(noteEditor())
    const input = await screen.findByLabelText("Note for John 3:16–18")
    await waitFor(() => expect(input.props.value).toBe("Remember this"))

    fireEvent.changeText(input, "A private reflection")
    fireEvent.press(screen.getByText("Save"))

    await waitFor(() => expect(mockSaveNote).toHaveBeenCalled())
    expect(mockSaveNote.mock.calls[0][0]).toBe(mockLibraryDatabase)
    expect(mockSaveNote.mock.calls[0][1]).toMatchObject({
      bookCode: "JHN",
      chapter: 3,
      startVerse: "16",
      endVerse: "18",
    })
    expect(mockSaveNote.mock.calls[0][2]).toBe("A private reflection")
    expect(mockBack).toHaveBeenCalled()
  })

  it("deletes an existing note", async () => {
    const screen = render(noteEditor())
    await screen.findByDisplayValue("Remember this")
    fireEvent.press(screen.getByText("Delete note"))
    await waitFor(() => expect(mockDeleteNote).toHaveBeenCalled())
    expect(mockBack).toHaveBeenCalled()
  })
})
