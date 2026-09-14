import { AppState, type AppStateStatus } from "react-native"
import { act, fireEvent, render } from "@testing-library/react-native"

import { ThemeProvider } from "@/theme/context"

import { ConfessionScreen } from "./ConfessionScreen"

const mockBack = jest.fn()
let mockBlur: (() => void) | undefined
jest.mock("expo-router", () => ({
  useRouter: () => ({ back: mockBack, canGoBack: () => true }),
  useFocusEffect: (callback: () => () => void) => {
    mockBlur = callback()
  },
}))
jest.mock("@expo/vector-icons", () => ({ Feather: () => null }))

test("confession notes survive guide steps but disappear on background and blur", () => {
  let onState: ((state: AppStateStatus) => void) | undefined
  const listener = jest
    .spyOn(AppState, "addEventListener")
    .mockImplementation((_event, handler) => {
      onState = handler
      return { remove: jest.fn() }
    })
  const screen = render(
    <ThemeProvider>
      <ConfessionScreen />
    </ThemeProvider>,
  )
  fireEvent.changeText(screen.getByLabelText("Temporary confession notes"), "A temporary test note")
  fireEvent.press(screen.getByText("Continue"))
  fireEvent.press(screen.getByText("Continue"))
  expect(screen.getByText("A temporary test note")).toBeTruthy()
  act(() => onState?.("background"))
  expect(screen.queryByText("A temporary test note")).toBeNull()
  fireEvent.press(screen.getByText("Previous"))
  fireEvent.press(screen.getByText("Previous"))
  expect(screen.getByLabelText("Temporary confession notes").props.value).toBe("")
  fireEvent.changeText(
    screen.getByLabelText("Temporary confession notes"),
    "Another temporary test note",
  )
  act(() => mockBlur?.())
  expect(screen.getByLabelText("Temporary confession notes").props.value).toBe("")
  listener.mockRestore()
})

jest.mock("@react-navigation/native", () => ({
  ...jest.requireActual("@react-navigation/native"),
  useScrollToTop: () => {},
}))
