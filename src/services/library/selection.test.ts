import { listBooks, setTranslationId } from "@/services/bible"
import { clear } from "@/utils/storage"

import { selectionFromReference } from "./selection"

describe("selectionFromReference", () => {
  beforeEach(() => clear())

  it("reads a saved passage from its own translation, not the active one", () => {
    setTranslationId("web-ce")
    const john = listBooks("douay-rheims").find((book) => book.code === "JHN")
    if (!john) throw new Error("The Douay–Rheims manifest has no John")

    const selection = selectionFromReference("douay-rheims", john, 2, "1")

    expect(selection?.translationId).toBe("douay-rheims")
    expect(selection?.scriptureText).toContain("marriage in Cana")
  })
})
