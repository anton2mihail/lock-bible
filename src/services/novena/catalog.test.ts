import { novenas, searchNovenas } from "./catalog"

describe("searchNovenas", () => {
  it("keeps every offline novena complete and uniquely addressable", () => {
    expect(new Set(novenas.map((novena) => novena.id)).size).toBe(novenas.length)

    for (const novena of novenas) {
      expect(novena.title).toBeTruthy()
      expect(novena.about).toBe("")
      expect(novena.patronage).toBeTruthy()
      expect(novena.sourceUrl).toMatch(/^https:\/\//)
      expect(novena.sections.length).toBeGreaterThan(0)
      expect(novena.sections.every((section) => section.paragraphs.length > 0)).toBe(true)
      expect(Boolean(novena.traditionalStart)).toBe(Boolean(novena.feastDay))
    }
  })

  it("returns the whole prayer library for a blank query", () => {
    const ids = searchNovenas("  ").map((novena) => novena.id)

    expect(ids).toEqual([
      "st-padre-pio",
      "st-jude",
      "st-peregrine",
      "st-joseph",
      "st-therese",
      "our-lady-perpetual-help",
      "divine-mercy",
    ])
  })

  it("searches titles, needs, and keywords", () => {
    expect(searchNovenas("hopeless").map((novena) => novena.id)).toEqual(["st-jude"])
    expect(searchNovenas("Padre Pio").map((novena) => novena.id)).toEqual(["st-padre-pio"])
    expect(searchNovenas("healing").map((novena) => novena.id)).toEqual([
      "st-padre-pio",
      "st-jude",
      "st-peregrine",
    ])
    expect(searchNovenas("cancer").map((novena) => novena.id)).toEqual(["st-peregrine"])
    expect(searchNovenas("care for them").map((novena) => novena.id)).toEqual(["st-peregrine"])
    expect(searchNovenas("employment").map((novena) => novena.id)).toEqual(["st-joseph"])
    expect(searchNovenas("Little Way").map((novena) => novena.id)).toEqual(["st-therese"])
    expect(searchNovenas("urgent need").map((novena) => novena.id)).toEqual([
      "our-lady-perpetual-help",
    ])
  })

  it("returns an empty list when nothing matches", () => {
    expect(searchNovenas("unicorn")).toEqual([])
  })

  it("finds the Divine Mercy novena", () => {
    expect(searchNovenas("Faustina").map((novena) => novena.id)).toEqual(["divine-mercy"])
  })
})
