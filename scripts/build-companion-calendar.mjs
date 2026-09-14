/** Build compact offline calendar metadata. No lectionary text is included.
 * bun scripts/build-companion-calendar.mjs /path/to/catholic-readings-api
 * Source snapshot: cpbjr/catholic-readings-api @ 973e9864eb0f15accadfc48750f5b243a95b7a2c (MIT).
 */
import fs from "node:fs/promises"
import path from "node:path"
import { Romcal } from "romcal"
import { UnitedStates_En } from "@romcal/calendar.united-states"
const source = process.argv[2]
if (!source) throw Error("Provide a local catholic-readings-api checkout")
const out = new URL("../src/services/companion/data/", import.meta.url)
const labels = {
  firstReading: "First reading",
  psalm: "Responsorial Psalm",
  secondReading: "Second reading",
  gospel: "Gospel",
}
const entries = {},
  celebrations = {}
const romcal = new Romcal({
  localizedCalendar: UnitedStates_En,
  ascensionOnSunday: true,
  outputOptions: { calculateProperties: true },
})
for (let year = 2025; year <= 2032; year++) {
  const calendar = await romcal.generateCalendar(year)
  for (const [date, days] of Object.entries(calendar)) {
    const day = days[0]
    celebrations[date] = {
      title: day.name,
      season: day.seasons[0],
      rank: day.rank,
      color: day.colors[0],
    }
  }
  if (year > 2027) continue
  const folder = path.join(source, "readings", String(year))
  for (const filename of (await fs.readdir(folder)).filter((x) => x.endsWith(".json"))) {
    const data = JSON.parse(await fs.readFile(path.join(folder, filename), "utf8"))
    if (!/^\d{4}-\d{2}-\d{2}$/.test(data.date)) throw Error("Invalid date " + filename)
    const readings = Object.entries(labels).flatMap(([key, label]) =>
      typeof data.readings?.[key] === "string" && data.readings[key].trim()
        ? [{ label, reference: key === "psalm" && /^\d+:/.test(data.readings[key].trim()) ? `Psalm ${data.readings[key].trim()}` : data.readings[key].trim() }]
        : [],
    )
    if (!readings.some((x) => x.label === "Gospel")) throw Error("Missing Gospel " + data.date)
    const liturgy = JSON.parse(
      await fs
        .readFile(path.join(source, "liturgical-calendar", String(year), filename), "utf8")
        .catch(() => "{}"),
    )
    entries[data.date] = {
      title: liturgy.celebration?.name || celebrations[data.date]?.title || data.season,
      readings,
    }
  }
}
await fs.writeFile(
  new URL("readings-us.json", out),
  JSON.stringify(Object.fromEntries(Object.entries(entries).sort()), null, 2) + "\n",
)
await fs.writeFile(new URL("celebrations-us.json", out), JSON.stringify(celebrations) + "\n")
await fs.copyFile(
  path.join(source, "LICENSE"),
  new URL("../../../..//assets/READINGS-LICENSE.txt", out),
)
console.log(
  `${Object.keys(entries).length} reading days, ${Object.keys(celebrations).length} celebration days`,
)
