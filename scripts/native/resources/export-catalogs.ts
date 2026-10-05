import { mkdirSync, writeFileSync } from "node:fs"
import { dirname } from "node:path"
import { PRAYERS } from "../../../src/services/companion/prayers"
import { TEACHINGS } from "../../../src/services/companion/teaching"
import { novenas } from "../../../src/services/novena/catalog"
import { ROSARY_MYSTERY_SETS, SEVEN_SORROWS, ROSARY_MEDIA_EPISODES, getRosaryMediaEpisode, hasApprovedRosaryMedia } from "../../../src/services/rosary/catalog"
import { ROSARY_PRAYERS, buildRosaryGuide, buildSevenSorrowsGuide, buildRosarySession } from "../../../src/services/rosary/prayers"

const output = process.argv[2]
if (!output) throw new Error("usage: export-catalogs.ts <output-json>")
const result = {
  formatVersion: 1,
  novenas,
  prayers: PRAYERS,
  teachings: TEACHINGS,
  rosary: {
    mysterySets: ROSARY_MYSTERY_SETS,
    sevenSorrows: SEVEN_SORROWS,
    mediaEpisodes: ROSARY_MEDIA_EPISODES,
    mediaFallback: getRosaryMediaEpisode(undefined) ?? ROSARY_MEDIA_EPISODES[0],
    mediaApproved: ROSARY_MEDIA_EPISODES.map((episode) => ({ id: episode.id, approved: hasApprovedRosaryMedia(episode) })),
    prayers: ROSARY_PRAYERS,
    guides: [...ROSARY_MYSTERY_SETS.map((set) => ({ id: set.id, steps: buildRosaryGuide(set) })), { id: "seven-sorrows", steps: buildSevenSorrowsGuide(SEVEN_SORROWS) }],
    sessions: [...ROSARY_MYSTERY_SETS.map((set) => buildRosarySession(set)), buildRosarySession(SEVEN_SORROWS)],
  },
}
mkdirSync(dirname(output), { recursive: true })
writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`)
console.log(JSON.stringify({ novenas: novenas.length, prayers: PRAYERS.length, teachings: TEACHINGS.length, mysterySets: ROSARY_MYSTERY_SETS.length, mediaEpisodes: ROSARY_MEDIA_EPISODES.length }))
