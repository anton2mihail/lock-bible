import { act, fireEvent, render } from "@testing-library/react-native"

import { getReaderTextSize, setReaderTextSize } from "@/services/bible"
import { ThemeProvider } from "@/theme/context"
import { clear } from "@/utils/storage"

import { ReadingSettings } from "./ReadingSettings"

function settings() {
  return (
    <ThemeProvider>
      <ReadingSettings />
    </ThemeProvider>
  )
}

describe("ReadingSettings", () => {
  beforeEach(clear)

  it("saves a choice", () => {
    const screen = render(settings())

    fireEvent.press(screen.getByLabelText("Text size, Large"))

    expect(getReaderTextSize()).toBe("large")
    expect(screen.getByLabelText("Text size, Large").props.accessibilityState).toEqual({
      checked: true,
    })
  })

  it("follows a change made from another screen while it stays mounted", () => {
    const screen = render(settings())
    expect(screen.getByLabelText("Text size, Default").props.accessibilityState).toEqual({
      checked: true,
    })

    // The reader's Aa sheet, say, while Settings waits in its tab.
    act(() => setReaderTextSize("extraLarge"))

    expect(screen.getByLabelText("Text size, Extra large").props.accessibilityState).toEqual({
      checked: true,
    })
  })
})
