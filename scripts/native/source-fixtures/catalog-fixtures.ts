import { readFileSync, writeFileSync } from "node:fs"
import { createHash } from "node:crypto"
import { PRAYERS } from "../../../src/services/companion/prayers"
import { TEACHINGS } from "../../../src/services/companion/teaching"
import { novenas } from "../../../src/services/novena/catalog"
import { ROSARY_MYSTERY_SETS, SEVEN_SORROWS, ROSARY_MEDIA_EPISODES } from "../../../src/services/rosary/catalog"
import { ROSARY_PRAYERS, buildRosaryGuide, buildSevenSorrowsGuide, buildRosarySession } from "../../../src/services/rosary/prayers"
import { TRANSLATIONS } from "../../../src/services/bible/translations"

const readJson = (path: string) => JSON.parse(readFileSync(path, "utf8"))
const hash = (path: string) => createHash("sha256").update(readFileSync(path)).digest("hex")
const fixture = {
  formatVersion: 1,
  generatedBy: "scripts/native/source-fixtures/catalog-fixtures.ts",
  baselineCommit: "b64e1fc3cfc6a78f508b41d74b71dddfe9ff7697",
  runtimeBehaviorObserved: false,
  sources: {
    prayerCatalog: { path: "src/services/companion/prayers.ts", sha256: hash("src/services/companion/prayers.ts"), count: PRAYERS.length, values: PRAYERS },
    teachings: { path: "src/services/companion/teaching.ts", sha256: hash("src/services/companion/teaching.ts"), count: TEACHINGS.length, values: TEACHINGS },
    novenas: { path: "src/services/novena/catalog.ts and novena source modules", sha256: Object.fromEntries(["src/services/novena/catalog.ts", "src/services/novena/expandedNovenas.ts", "src/services/novena/padrePioNovena.ts", "src/services/novena/perpetualHelpNovena.ts", "src/services/novena/stJosephNovena.ts", "src/services/novena/stJudeNovena.ts", "src/services/novena/stPeregrineNovena.ts", "src/services/novena/stThereseNovena.ts"].map((path) => [path, hash(path)])), count: novenas.length, values: novenas },
    rosary: {
      sourceFiles: ["src/services/rosary/catalog.ts", "src/services/rosary/prayers.ts"],
      sha256: { catalog: hash("src/services/rosary/catalog.ts"), prayers: hash("src/services/rosary/prayers.ts") },
      mysterySets: ROSARY_MYSTERY_SETS,
      sevenSorrows: SEVEN_SORROWS,
      media: ROSARY_MEDIA_EPISODES,
      prayers: ROSARY_PRAYERS,
      guides: [...ROSARY_MYSTERY_SETS.map((set) => ({ id: set.id, steps: buildRosaryGuide(set) })), { id: "seven-sorrows", steps: buildSevenSorrowsGuide(SEVEN_SORROWS) }],
      sessions: [...ROSARY_MYSTERY_SETS.map((set) => buildRosarySession(set)), buildRosarySession(SEVEN_SORROWS)],
    },
    calendars: {
      readings: { path: "src/services/companion/data/readings-us.json", sha256: hash("src/services/companion/data/readings-us.json"), values: readJson("src/services/companion/data/readings-us.json") },
      celebrations: { path: "src/services/companion/data/celebrations-us.json", sha256: hash("src/services/companion/data/celebrations-us.json"), values: readJson("src/services/companion/data/celebrations-us.json") },
    },
    editions: Object.values(TRANSLATIONS).map((edition) => ({ id: edition.meta.id, meta: edition.meta, bookCount: edition.manifest.length, books: edition.manifest, widgetPoolCount: edition.widgetVerses.length, widgetPoolSource: `src/services/bible/data/${edition.meta.id}/widgetVerses.json`, widgetPoolSha256: hash(`src/services/bible/data/${edition.meta.id}/widgetVerses.json`) })),
    works: { path: "src/services/works/data/catalog.json", sha256: hash("src/services/works/data/catalog.json"), values: readJson("src/services/works/data/catalog.json") },
  },
}
writeFileSync("build/native-evidence/L00-source/catalog-fixtures.json", `${JSON.stringify(fixture, null, 2)}\n`)
console.log(`Wrote source fixture: ${novenas.length} novenas, ${PRAYERS.length} prayers, ${TEACHINGS.length} teachings, ${ROSARY_MYSTERY_SETS.length} mystery sets, and ${Object.values(TRANSLATIONS).length} editions.`)
