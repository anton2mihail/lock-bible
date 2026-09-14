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

export type RosaryPrayerId =
  | "sign-of-the-cross"
  | "apostles-creed"
  | "our-father"
  | "hail-mary"
  | "glory-be"
  | "fatima-prayer"
  | "hail-holy-queen"
  | "closing-prayer"

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
  repetitions: number
  mysteryIndex?: number
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
