import type {
  RosaryMediaEpisode,
  RosaryMysterySet,
  RosaryMysterySetId,
  SevenSorrowsDevotion,
} from "./types"

export const ROSARY_MYSTERY_SETS: readonly RosaryMysterySet[] = [
  {
    id: "joyful",
    title: "The Joyful Mysteries",
    shortTitle: "Joyful",
    customaryDays: "Monday & Saturday",
    description:
      "“The first five decades, the ‘joyful mysteries’, are marked by the joy radiating from the event of the Incarnation.” — St. John Paul II, Rosarium Virginis Mariae, 20",
    mysteries: [
      { title: "The Annunciation", scriptureReference: "Luke 1:26–38" },
      { title: "The Visitation", scriptureReference: "Luke 1:39–56" },
      { title: "The Nativity", scriptureReference: "Luke 2:1–20" },
      { title: "The Presentation", scriptureReference: "Luke 2:22–38" },
      {
        title: "The Finding in the Temple",
        scriptureReference: "Luke 2:41–52",
      },
    ],
  },
  {
    id: "sorrowful",
    title: "The Sorrowful Mysteries",
    shortTitle: "Sorrowful",
    customaryDays: "Tuesday & Friday",
    description:
      "“The Gospels give great prominence to the sorrowful mysteries of Christ.” — St. John Paul II, Rosarium Virginis Mariae, 22",
    mysteries: [
      {
        title: "The Agony in the Garden",
        scriptureReference: "Matthew 26:36–46",
      },
      {
        title: "The Scourging at the Pillar",
        scriptureReference: "John 19:1",
      },
      {
        title: "The Crowning with Thorns",
        scriptureReference: "Matthew 27:27–31",
      },
      {
        title: "The Carrying of the Cross",
        scriptureReference: "Luke 23:26–32",
      },
      { title: "The Crucifixion", scriptureReference: "John 19:17–37" },
    ],
  },
  {
    id: "glorious",
    title: "The Glorious Mysteries",
    shortTitle: "Glorious",
    customaryDays: "Wednesday & Sunday",
    description:
      "“The contemplation of Christ’s face cannot stop at the image of the Crucified One. He is the Risen One!” — St. John Paul II, Rosarium Virginis Mariae, 23",
    mysteries: [
      { title: "The Resurrection", scriptureReference: "Matthew 28:1–10" },
      { title: "The Ascension", scriptureReference: "Acts 1:6–11" },
      {
        title: "The Descent of the Holy Spirit",
        scriptureReference: "Acts 2:1–13",
      },
      {
        title: "The Assumption of Mary",
        scriptureReference: "Revelation 12:1",
      },
      {
        title: "The Coronation of Mary",
        scriptureReference: "Revelation 12:1",
      },
    ],
  },
  {
    id: "luminous",
    title: "The Luminous Mysteries",
    shortTitle: "Luminous",
    customaryDays: "Thursday",
    description:
      "“Certainly the whole mystery of Christ is a mystery of light.” — St. John Paul II, Rosarium Virginis Mariae, 21",
    mysteries: [
      {
        title: "The Baptism of Jesus",
        scriptureReference: "Matthew 3:13–17",
      },
      {
        title: "The Wedding at Cana",
        scriptureReference: "John 2:1–12",
      },
      {
        title: "The Proclamation of the Kingdom",
        scriptureReference: "Mark 1:14–15",
      },
      {
        title: "The Transfiguration",
        scriptureReference: "Luke 9:28–36",
      },
      {
        title: "The Institution of the Eucharist",
        scriptureReference: "Luke 22:14–20",
      },
    ],
  },
]

/**
 * The Servite Rosary, prayed on a chaplet of seven sevens rather than five
 * decades. It is kept apart from ROSARY_MYSTERY_SETS because its shape differs:
 * each sorrow carries one Our Father and seven Hail Marys, and the devotion
 * closes with three Hail Marys honouring the tears of the Sorrowful Mother.
 */
export const SEVEN_SORROWS: SevenSorrowsDevotion = {
  id: "seven-sorrows",
  title: "The Seven Sorrows of Mary",
  shortTitle: "Seven Sorrows",
  customaryDays: "Fridays, Lent & September 15",
  description: "The Servite Rosary of the Seven Sorrows of the Blessed Virgin Mary.",
  sorrows: [
    {
      title: "The Prophecy of Simeon",
      scriptureReference: "Luke 2:25–35",
      grace: "Humility",
      invocation:
        "I grieve for thee, O Mary most sorrowful, in the affliction of thy tender heart at the prophecy of the holy and aged Simeon. Dear Mother, by thy heart so afflicted, obtain for me the virtue of humility and the gift of the holy fear of God.",
    },
    {
      title: "The Flight into Egypt",
      scriptureReference: "Matthew 2:13–15",
      grace: "Generosity",
      invocation:
        "I grieve for thee, O Mary most sorrowful, in the anguish of thy most affectionate heart during the flight into Egypt and thy sojourn there. Dear Mother, by thy heart so troubled, obtain for me the virtue of generosity, especially toward the poor, and the gift of piety.",
    },
    {
      title: "The Loss of the Child Jesus in the Temple",
      scriptureReference: "Luke 2:41–50",
      grace: "Chastity",
      invocation:
        "I grieve for thee, O Mary most sorrowful, in those anxieties which tried thy troubled heart at the loss of thy dear Jesus. Dear Mother, by thy heart so full of anguish, obtain for me the virtue of chastity and the gift of knowledge.",
    },
    {
      title: "Mary Meets Jesus on the Way to Calvary",
      scriptureReference: "Luke 23:27–31",
      grace: "Patience",
      invocation:
        "I grieve for thee, O Mary most sorrowful, in the consternation of thy heart at meeting Jesus as He carried His cross. Dear Mother, by thy heart so troubled, obtain for me the virtue of patience and the gift of fortitude.",
    },
    {
      title: "The Crucifixion and Death of Jesus",
      scriptureReference: "John 19:25–30",
      grace: "Temperance",
      invocation:
        "I grieve for thee, O Mary most sorrowful, in the martyrdom which thy generous heart endured in standing near Jesus in His agony. Dear Mother, by thy afflicted heart, obtain for me the virtue of temperance and the gift of counsel.",
    },
    {
      title: "Mary Receives the Body of Jesus",
      scriptureReference: "John 19:38–40",
      grace: "Fraternal charity",
      invocation:
        "I grieve for thee, O Mary most sorrowful, in the wounding of thy compassionate heart, when the side of Jesus was struck by the lance and His Heart was pierced before His body was removed from the Cross. Dear Mother, by thy heart thus transfixed, obtain for me the virtue of fraternal charity and the gift of understanding.",
    },
    {
      title: "The Burial of Jesus",
      scriptureReference: "John 19:41–42",
      grace: "Diligence",
      invocation:
        "I grieve for thee, O Mary most sorrowful, for the pangs that wrenched thy most loving heart at the burial of Jesus. Dear Mother, by thy heart sunk in the bitterness of desolation, obtain for me the virtue of diligence and the gift of wisdom.",
    },
  ],
}

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

/**
 * Whether the in-app player has an approved file to play. Until Word on Fire
 * grants permission none do, so release builds send people to the official
 * video instead of showing an empty player.
 */
export function hasApprovedRosaryMedia(episode: RosaryMediaEpisode | undefined): boolean {
  return Boolean(episode?.videoUri || episode?.audioUri)
}

/** Resolves any guided devotion: the four mystery sets or the Seven Sorrows. */
export function getRosaryDevotion(
  id: string | undefined,
): RosaryMysterySet | SevenSorrowsDevotion | undefined {
  if (id === SEVEN_SORROWS.id) return SEVEN_SORROWS
  return getRosaryMysterySet(id)
}
