/** Build offline Gospel previews from the same references and public-domain WEB-CE as the app. */
import fs from "node:fs"
const root = new URL("../", import.meta.url)
const read = (p) => JSON.parse(fs.readFileSync(new URL(p, root), "utf8"))
const readings = read("src/services/companion/data/readings-us.json")
const celebrations = read("src/services/companion/data/celebrations-us.json")
const books = Object.fromEntries(
  Object.entries({ Matthew: "MAT", Mark: "MRK", Luke: "LUK", John: "JHN" }).map(([name, code]) => [
    name,
    read(`src/services/bible/data/web-ce/${code}.json`),
  ]),
)
const years = {}
for (const [date, celebration] of Object.entries(celebrations)) {
  const day = readings[date]
  const reference = day?.readings.find((r) => r.label === "Gospel")?.reference
  let excerpt = ""
  if (reference) {
    const match = reference.match(/^(Matthew|Mark|Luke|John) (\d+):\s*(\d+)/)
    if (!match) throw Error(`Unsupported Gospel: ${date} ${reference}`)
    excerpt = books[match[1]].chapters
      .find((c) => c.c === Number(match[2]))
      ?.verses.find((v) => v.n === match[3])?.t
    if (!excerpt) throw Error(`Missing Gospel verse: ${date} ${reference}`)
  }
  const year = date.slice(0, 4)
  ;(years[year] ??= {})[date] = {
    title: day?.title ?? celebration.title,
    reference: reference ?? "",
    excerpt,
  }
}
for (const [year, data] of Object.entries(years)) {
  fs.writeFileSync(
    new URL(`targets/widget/daily-readings-${year}.json`, root),
    JSON.stringify(data) + "\n",
  )
}
console.log(`Built ${Object.keys(years).length} years of daily-reading widget data`)
