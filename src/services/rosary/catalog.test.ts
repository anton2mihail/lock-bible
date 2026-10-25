import {
  buildRosaryGuide,
  buildRosarySession,
  buildSevenSorrowsGuide,
  getRosaryDevotion,
  getRosaryMysterySet,
  getSuggestedRosaryMysterySet,
  ROSARY_MEDIA_EPISODES,
  ROSARY_MYSTERY_SETS,
  SEVEN_SORROWS,
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

describe("Seven Sorrows devotion", () => {
  test("keeps the seven sorrows out of the five-decade mystery sets", () => {
    expect(SEVEN_SORROWS.sorrows).toHaveLength(7)
    expect(ROSARY_MYSTERY_SETS.map((set) => set.id)).not.toContain(SEVEN_SORROWS.id)
  })

  test("gives every sorrow a reference, an invocation and a grace", () => {
    for (const sorrow of SEVEN_SORROWS.sorrows) {
      expect(sorrow.scriptureReference).toMatch(/^[1-3]? ?[A-Za-z]+ \d+:\d+/)
      expect(sorrow.invocation).toContain("I compassionate thee, sorrowing Mary")
      expect(sorrow.grace.length).toBeGreaterThan(0)
    }
  })

  test("resolves through the shared devotion lookup", () => {
    expect(getRosaryDevotion("seven-sorrows")).toBe(SEVEN_SORROWS)
    expect(getRosaryDevotion("joyful")?.id).toBe("joyful")
    expect(getRosaryDevotion("nonsense")).toBeUndefined()
  })

  test("builds seven groups of one Our Father and seven Hail Marys", () => {
    const guide = buildSevenSorrowsGuide(SEVEN_SORROWS)

    expect(guide.filter((step) => step.id.startsWith("sorrow-") && step.meditation)).toHaveLength(7)
    expect(guide.filter((step) => step.id.startsWith("sorrow-our-father-"))).toHaveLength(7)

    const decadeHailMarys = guide.filter((step) => step.id.startsWith("sorrow-hail-marys-"))
    expect(decadeHailMarys).toHaveLength(7)
    expect(decadeHailMarys.every((step) => step.repetitions === 7)).toBe(true)
  })

  test("closes with three Hail Marys for Mary's tears", () => {
    const guide = buildSevenSorrowsGuide(SEVEN_SORROWS)
    const tears = guide.find((step) => step.id === "tears-hail-marys")

    expect(tears?.repetitions).toBe(3)
    expect(tears?.eyebrow).toBe("For the tears of our Sorrowful Mother")
    expect(guide.at(-1)?.id).toBe("closing-sign-of-the-cross")
  })

  test("prays fifty-two Hail Marys and seven Our Fathers in all", () => {
    const guide = buildSevenSorrowsGuide(SEVEN_SORROWS)
    const count = (prayerId: string) =>
      guide
        .filter((step) => step.prayer?.id === prayerId)
        .reduce((total, step) => total + step.repetitions, 0)

    expect(count("hail-mary")).toBe(7 * 7 + 3)
    expect(count("our-father")).toBe(7)
  })

  test("pairs each sorrow's steps with its own index for art and the bead rail", () => {
    const guide = buildSevenSorrowsGuide(SEVEN_SORROWS)

    SEVEN_SORROWS.sorrows.forEach((_, index) => {
      const group = guide.filter((step) => step.mysteryIndex === index)
      expect(group).toHaveLength(3)
      expect(group.map((step) => step.eyebrow)).toEqual(Array(3).fill(`Sorrow ${index + 1} of 7`))
    })
  })
})

describe("Rosary sessions", () => {
  test("flattens the seven sorrows for the guide screen", () => {
    const session = buildRosarySession(SEVEN_SORROWS)

    expect(session.id).toBe("seven-sorrows")
    expect(session.groupLabels).toHaveLength(7)
    expect(session.groupLabels[0]).toBe("The Prophecy of Simeon")
    expect(session.steps).toEqual(buildSevenSorrowsGuide(SEVEN_SORROWS))
  })

  test("flattens a mystery set the same way", () => {
    const joyful = getRosaryMysterySet("joyful")!
    const session = buildRosarySession(joyful)

    expect(session.groupLabels).toHaveLength(5)
    expect(session.steps).toEqual(buildRosaryGuide(joyful))
  })
})
