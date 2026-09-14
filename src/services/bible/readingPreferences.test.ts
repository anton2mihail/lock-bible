import { clear, save } from "@/utils/storage"

import {
  dismissWidgetGuide,
  getReaderLineSpacing,
  getReaderLocation,
  getReaderTextSize,
  getReaderTypeface,
  isWidgetGuideDismissed,
  setReaderLineSpacing,
  setReaderLocation,
  setReaderTextSize,
  setReaderTypeface,
} from "./readingPreferences"

describe("reading preferences", () => {
  beforeEach(clear)

  it("uses comfortable offline reading defaults", () => {
    expect(getReaderTextSize()).toBe("medium")
    expect(getReaderLineSpacing()).toBe("comfortable")
    expect(getReaderTypeface()).toBe("serif")
    expect(isWidgetGuideDismissed()).toBe(false)
  })

  it("persists reader appearance choices", () => {
    setReaderTextSize("extraLarge")
    setReaderLineSpacing("relaxed")
    setReaderTypeface("sans")

    expect(getReaderTextSize()).toBe("extraLarge")
    expect(getReaderLineSpacing()).toBe("relaxed")
    expect(getReaderTypeface()).toBe("sans")
  })

  it("persists and sanitizes the last reading location", () => {
    setReaderLocation({ book: "JHN", chapter: 3, scrollY: -20 })
    expect(getReaderLocation()).toMatchObject({ book: "JHN", chapter: 3, scrollY: 0 })

    save("bible.reader.location", { book: "JHN", chapter: 0, scrollY: 10 })
    expect(getReaderLocation()).toBeNull()
  })

  it("remembers that the first-run widget guide was dismissed", () => {
    dismissWidgetGuide()
    expect(isWidgetGuideDismissed()).toBe(true)
  })
})
