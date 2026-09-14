import { normalizeNovenaProgress } from "./progressModel"

describe("normalizeNovenaProgress", () => {
  it("keeps valid progress and removes invalid or duplicate days", () => {
    expect(
      normalizeNovenaProgress({
        completedDays: [3, 1, 3, 0, 10, "2"],
        selectedDay: 4,
        intention: "For healing",
      }),
    ).toEqual({
      completedDays: [1, 3],
      selectedDay: 4,
      intention: "For healing",
    })
  })

  it("falls back safely when persisted data is malformed", () => {
    expect(normalizeNovenaProgress({ completedDays: "all", selectedDay: 20 })).toEqual({
      completedDays: [],
      selectedDay: 1,
      intention: "",
    })
  })
})
