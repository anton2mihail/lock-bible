import {
  buildRosaryGuide,
  getRosaryMysterySet,
  getSuggestedRosaryMysterySet,
  ROSARY_MEDIA_EPISODES,
  ROSARY_MYSTERY_SETS,
} from "./index"

describe("Rosary catalog", () => {
  test("contains the four traditional mystery sets with five mysteries each", () => {
    expect(ROSARY_MYSTERY_SETS.map((set) => set.id)).toEqual([
      "joyful",
      "sorrowful",
      "glorious",
      "luminous",
    ])
    expect(ROSARY_MYSTERY_SETS.every((set) => set.mysteries.length === 5)).toBe(true)
  })

  test.each([
    ["2026-08-31T12:00:00", "joyful"],
    ["2026-09-01T12:00:00", "sorrowful"],
    ["2026-09-02T12:00:00", "glorious"],
    ["2026-09-03T12:00:00", "luminous"],
  ])("suggests the customary set for %s", (date, expected) => {
    expect(getSuggestedRosaryMysterySet(new Date(date)).id).toBe(expected)
  })

  test("builds a complete five-decade guide", () => {
    const joyful = getRosaryMysterySet("joyful")!
    const guide = buildRosaryGuide(joyful)

    expect(guide.filter((step) => step.id.startsWith("mystery-"))).toHaveLength(5)
    expect(guide.filter((step) => step.id.startsWith("hail-marys-"))).toHaveLength(5)
    expect(
      guide
        .filter((step) => step.id.startsWith("hail-marys-"))
        .every((step) => step.repetitions === 10),
    ).toBe(true)
    expect(guide.at(-1)?.id).toBe("closing-sign-of-the-cross")
  })

  test("catalogues the official introduction and mystery episodes", () => {
    expect(ROSARY_MEDIA_EPISODES).toHaveLength(6)
    expect(ROSARY_MEDIA_EPISODES.filter((episode) => episode.mysterySetId)).toHaveLength(4)
    expect(
      ROSARY_MEDIA_EPISODES.every((episode) => episode.officialUrl.startsWith("https://")),
    ).toBe(true)
  })
})
