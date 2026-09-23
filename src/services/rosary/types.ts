export type RosaryMysterySetId = "joyful" | "sorrowful" | "glorious" | "luminous"

export type RosaryMystery = {
  title: string
  scriptureReference: string
  fruit: string
}

export type RosaryMysterySet = {
  id: RosaryMysterySetId
  title: string
  shortTitle: string
  customaryDays: string
  description: string
  mysteries: readonly RosaryMystery[]
}

export type SevenSorrowsDevotionId = "seven-sorrows"

/** Every guided devotion the Rosary guide screen can pray. */
export type RosaryDevotionId = RosaryMysterySetId | SevenSorrowsDevotionId

export type SevenSorrow = {
  title: string
  scriptureReference: string
  /** The Servite invocation prayed before the Our Father of this sorrow. */
  invocation: string
  /** The virtue traditionally asked for at this sorrow. */
  grace: string
}

/**
 * The Rosary of the Seven Sorrows keeps a different shape from the mystery
 * sets: seven groups of one Our Father and seven Hail Marys, closing with
 * three Hail Marys in honour of Mary's tears.
 */
export type SevenSorrowsDevotion = {
  id: SevenSorrowsDevotionId
  title: string
  shortTitle: string
  customaryDays: string
  description: string
  sorrows: readonly SevenSorrow[]
}

export type RosaryPrayerId =
  | "sign-of-the-cross"
  | "apostles-creed"
  | "our-father"
  | "hail-mary"
  | "glory-be"
  | "fatima-prayer"
  | "hail-holy-queen"
  | "closing-prayer"
  | "sorrows-opening"
  | "sorrows-versicle"
  | "sorrows-closing-prayer"

export type RosaryPrayer = {
  id: RosaryPrayerId
  title: string
  text: string
}

export type RosaryGuideStep = {
  id: string
  eyebrow: string
  title: string
  instruction?: string
  prayer?: RosaryPrayer
  /** Words particular to this step, such as a Servite invocation for one sorrow. */
  meditation?: string
  repetitions: number
  /** Index into the devotion's mysteries or sorrows, for art and the bead rail. */
  mysteryIndex?: number
}

/**
 * A devotion flattened into what the guide screen needs, so one screen can pray
 * both the five-decade mystery sets and the seven-sorrow devotion.
 */
export type RosarySession = {
  id: RosaryDevotionId
  title: string
  shortTitle: string
  /** One label per bead on the progress rail. */
  groupLabels: readonly string[]
  steps: readonly RosaryGuideStep[]
}

export type RosaryReminderFrequency = "daily" | "weekly"

export type RosaryReminderSettings = {
  enabled: boolean
  frequency: RosaryReminderFrequency
  hour: number
  minute: number
  /** Expo weekday: 1 = Sunday, 7 = Saturday. */
  weekday: number
  notificationId?: string
}

export type RosaryMediaEpisode = {
  id: string
  title: string
  subtitle: string
  officialUrl: string
  mysterySetId?: RosaryMysterySetId
  /** Approved direct media URLs can be added after permission is granted. */
  videoUri?: string
  audioUri?: string
}
