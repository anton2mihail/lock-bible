import type { RosaryMediaEpisode, RosaryMysterySet, RosaryMysterySetId } from "./types"

export const ROSARY_MYSTERY_SETS: readonly RosaryMysterySet[] = [
  {
    id: "joyful",
    title: "The Joyful Mysteries",
    shortTitle: "Joyful",
    customaryDays: "Monday & Saturday",
    description:
      "Meditate on Christ’s hidden life, from the Annunciation to the finding in the Temple.",
    mysteries: [
      { title: "The Annunciation", scriptureReference: "Luke 1:26–38", fruit: "Humility" },
      { title: "The Visitation", scriptureReference: "Luke 1:39–56", fruit: "Love of neighbor" },
      { title: "The Nativity", scriptureReference: "Luke 2:1–20", fruit: "Poverty of spirit" },
      { title: "The Presentation", scriptureReference: "Luke 2:22–38", fruit: "Obedience" },
      {
        title: "The Finding in the Temple",
        scriptureReference: "Luke 2:41–52",
        fruit: "Seeking Jesus",
      },
    ],
  },
  {
    id: "sorrowful",
    title: "The Sorrowful Mysteries",
    shortTitle: "Sorrowful",
    customaryDays: "Tuesday & Friday",
    description:
      "Walk with Christ through his Passion and contemplate the depth of his saving love.",
    mysteries: [
      {
        title: "The Agony in the Garden",
        scriptureReference: "Matthew 26:36–46",
        fruit: "Trust in God",
      },
      {
        title: "The Scourging at the Pillar",
        scriptureReference: "John 19:1",
        fruit: "Purity",
      },
      {
        title: "The Crowning with Thorns",
        scriptureReference: "Matthew 27:27–31",
        fruit: "Moral courage",
      },
      {
        title: "The Carrying of the Cross",
        scriptureReference: "Luke 23:26–32",
        fruit: "Patience",
      },
      { title: "The Crucifixion", scriptureReference: "John 19:17–37", fruit: "Self-giving love" },
    ],
  },
  {
    id: "glorious",
    title: "The Glorious Mysteries",
    shortTitle: "Glorious",
    customaryDays: "Wednesday & Sunday",
    description: "Rejoice in Christ’s victory and the hope promised to the Church.",
    mysteries: [
      { title: "The Resurrection", scriptureReference: "Matthew 28:1–10", fruit: "Faith" },
      { title: "The Ascension", scriptureReference: "Acts 1:6–11", fruit: "Hope" },
      {
        title: "The Descent of the Holy Spirit",
        scriptureReference: "Acts 2:1–13",
        fruit: "Wisdom",
      },
      {
        title: "The Assumption of Mary",
        scriptureReference: "Revelation 12:1",
        fruit: "A holy death",
      },
      {
        title: "The Coronation of Mary",
        scriptureReference: "Revelation 12:1",
        fruit: "Perseverance",
      },
    ],
  },
  {
    id: "luminous",
    title: "The Luminous Mysteries",
    shortTitle: "Luminous",
    customaryDays: "Thursday",
    description: "Contemplate the public ministry of Jesus, the Light of the world.",
    mysteries: [
      {
        title: "The Baptism of Jesus",
        scriptureReference: "Matthew 3:13–17",
        fruit: "Openness to the Holy Spirit",
      },
      {
        title: "The Wedding at Cana",
        scriptureReference: "John 2:1–12",
        fruit: "Trust in Mary’s intercession",
      },
      {
        title: "The Proclamation of the Kingdom",
        scriptureReference: "Mark 1:14–15",
        fruit: "Conversion",
      },
      {
        title: "The Transfiguration",
        scriptureReference: "Luke 9:28–36",
        fruit: "Desire for holiness",
      },
      {
        title: "The Institution of the Eucharist",
        scriptureReference: "Luke 22:14–20",
        fruit: "Eucharistic devotion",
      },
    ],
  },
]

export const WORD_ON_FIRE_ROSARY_URL = "https://www.wordonfire.org/rosary/"
export const WORD_ON_FIRE_PERMISSION_URL = "https://www.wordonfire.org/contact/content-request/"

export const ROSARY_MEDIA_EPISODES: readonly RosaryMediaEpisode[] = [
  {
    id: "why-pray",
    title: "Why Pray the Rosary?",
    subtitle: "Bishop Robert Barron introduces the devotion.",
    officialUrl: "https://www.youtube.com/watch?v=vE247jOt4AA",
  },
  {
    id: "how-to-pray",
    title: "How to Pray the Rosary",
    subtitle: "A practical introduction with Bishop Robert Barron.",
    officialUrl: "https://www.youtube.com/watch?v=HXcWknfC0vI",
  },
  {
    id: "joyful",
    title: "The Joyful Mysteries",
    subtitle: "Pray the Joyful Mysteries with Bishop Robert Barron.",
    mysterySetId: "joyful",
    officialUrl: "https://www.youtube.com/watch?v=ckUJRg04jyg",
  },
  {
    id: "sorrowful",
    title: "The Sorrowful Mysteries",
    subtitle: "Pray the Sorrowful Mysteries with Bishop Robert Barron.",
    mysterySetId: "sorrowful",
    officialUrl: "https://www.youtube.com/watch?v=ry7FbjkN-p0",
  },
  {
    id: "glorious",
    title: "The Glorious Mysteries",
    subtitle: "Pray the Glorious Mysteries with Bishop Robert Barron.",
    mysterySetId: "glorious",
    officialUrl: "https://www.youtube.com/watch?v=WoJ1hQTVdSo",
  },
  {
    id: "luminous",
    title: "The Luminous Mysteries",
    subtitle: "Pray the Luminous Mysteries with Bishop Robert Barron.",
    mysterySetId: "luminous",
    officialUrl: "https://www.youtube.com/watch?v=b2EjBt2PFpc",
  },
]

const DEFAULT_SET_BY_DAY: readonly RosaryMysterySetId[] = [
  "glorious",
  "joyful",
  "sorrowful",
  "glorious",
  "luminous",
  "sorrowful",
  "joyful",
]

export function getRosaryMysterySet(id: string | undefined): RosaryMysterySet | undefined {
  return ROSARY_MYSTERY_SETS.find((set) => set.id === id)
}

export function getSuggestedRosaryMysterySet(date = new Date()): RosaryMysterySet {
  return getRosaryMysterySet(DEFAULT_SET_BY_DAY[date.getDay()]) ?? ROSARY_MYSTERY_SETS[0]
}

export function getRosaryMediaEpisode(id: string | undefined): RosaryMediaEpisode | undefined {
  return ROSARY_MEDIA_EPISODES.find((episode) => episode.id === id)
}
