import readings from "./data/readings-us.json"
import { referenceTarget, resolvePassage } from "./passage"
import { TEACHINGS } from "./teaching"

jest.mock("@/services/bible", () => ({ getActiveTranslationMeta: () => ({ id: "web-ce" }) }))

describe("prayer passage selection", () => {
  test("preserves the edition and full selected range", () => {
    const p = resolvePassage({
      book: "JHN",
      chapter: "1",
      startVerse: "1",
      endVerse: "3",
      translation: "web-ce",
    })
    expect(p?.reference).toBe("John 1:1–3")
    expect(p?.text).toContain("In the beginning")
    expect(p?.params.endVerse).toBe("3")
    expect(p?.translation).toBe("WEB-CE")
    expect(
      resolvePassage({ book: "JHN", chapter: "1", startVerse: "1", translation: "vulgate" })
        ?.translation,
    ).toBe("VUL")
  })
  test("rejects missing, reversed, and nonexistent verse selections", () => {
    expect(resolvePassage({ book: "NOPE", chapter: "1" })).toBeNull()
    expect(resolvePassage({ book: "JHN", chapter: "1000" })).toBeNull()
    expect(resolvePassage({ book: "JHN", chapter: "1", startVerse: "999" })).toBeNull()
    expect(resolvePassage({ book: "JHN", chapter: "1", startVerse: "3", endVerse: "1" })).toBeNull()
  })
  test("opens cross-chapter and lettered references in context without truncating their displayed label", () => {
    expect(referenceTarget("Sirach 27:30—28:7")).toMatchObject({ book: "SIR", chapter: "27" })
    expect(referenceTarget("Psalm 103:1-2, 3-4, 9-10, 11-12")).toMatchObject({
      book: "PSA",
      chapter: "103",
    })
  })
  test("every bundled reference can reach a Bible chapter", () => {
    const references = [
      ...Object.values(readings).flatMap((day) => day.readings.map((r) => r.reference)),
      ...TEACHINGS.flatMap((t) => t.references),
    ]
    const invalid = [...new Set(references)].filter((reference) => !referenceTarget(reference))
    expect(invalid).toEqual([])
  })
})
