import { novenas, searchNovenas } from "./catalog"

describe("searchNovenas", () => {
  it("keeps every offline novena complete and uniquely addressable", () => {
    expect(new Set(novenas.map((novena) => novena.id)).size).toBe(novenas.length)

    for (const novena of novenas) {
      expect(novena.title).toBeTruthy()
      expect(novena.about.length).toBeGreaterThan(80)
      expect(novena.patronage).toBeTruthy()
      expect(novena.sourceUrl).toMatch(/^https:\/\//)
      expect(novena.sections.length).toBeGreaterThan(0)
      expect(novena.sections.every((section) => section.paragraphs.length > 0)).toBe(true)
      expect(Boolean(novena.traditionalStart)).toBe(Boolean(novena.feastDay))
    }
  })

  it("returns the whole prayer library for a blank query", () => {
    const ids = searchNovenas("  ").map((novena) => novena.id)

    expect(ids).toHaveLength(27)
    expect(ids).toEqual([
      "st-padre-pio",
      "st-jude",
      "st-peregrine",
      "st-joseph",
      "st-therese",
      "our-lady-perpetual-help",
      "sacred-heart",
      "holy-spirit",
      "divine-mercy",
      "miraculous-medal",
      "immaculate-conception",
      "our-lady-lourdes",
      "our-lady-fatima",
      "our-lady-guadalupe",
      "assumption",
      "st-anthony",
      "st-anne",
      "st-rita",
      "st-monica",
      "st-michael",
      "st-benedict",
      "st-francis-assisi",
      "st-dymphna",
      "holy-souls",
      "christ-the-king",
      "respect-life",
      "mental-health",
    ])
  })

  it("searches titles, needs, and keywords", () => {
    expect(searchNovenas("hopeless").map((novena) => novena.id)).toEqual(["st-jude"])
    expect(searchNovenas("Padre Pio").map((novena) => novena.id)).toEqual(["st-padre-pio"])
    expect(searchNovenas("healing").map((novena) => novena.id)).toEqual([
      "st-padre-pio",
      "st-jude",
      "st-peregrine",
      "miraculous-medal",
      "our-lady-lourdes",
      "mental-health",
    ])
    expect(searchNovenas("cancer").map((novena) => novena.id)).toEqual(["st-peregrine"])
    expect(searchNovenas("care for them").map((novena) => novena.id)).toEqual([
      "st-peregrine",
      "our-lady-lourdes",
      "st-dymphna",
    ])
    expect(searchNovenas("employment").map((novena) => novena.id)).toEqual(["st-joseph"])
    expect(searchNovenas("Little Way").map((novena) => novena.id)).toEqual(["st-therese"])
    expect(searchNovenas("urgent need").map((novena) => novena.id)).toEqual([
      "our-lady-perpetual-help",
    ])
  })

  it("returns an empty list when nothing matches", () => {
    expect(searchNovenas("unicorn")).toEqual([])
  })

  it("finds the expanded library by saint, devotion, and need", () => {
    expect(searchNovenas("lost").map((novena) => novena.id)).toEqual(["st-anthony"])
    expect(searchNovenas("religious freedom").map((novena) => novena.id)).toEqual([
      "christ-the-king",
    ])
    expect(searchNovenas("mental health").map((novena) => novena.id)).toEqual([
      "st-dymphna",
      "mental-health",
    ])
    expect(searchNovenas("purgatory").map((novena) => novena.id)).toEqual([
      "divine-mercy",
      "holy-souls",
    ])
    expect(searchNovenas("care for creation").map((novena) => novena.id)).toEqual([
      "st-francis-assisi",
    ])
  })
})
