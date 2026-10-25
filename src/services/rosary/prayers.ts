import type {
  RosaryGuideStep,
  RosaryMysterySet,
  RosaryPrayer,
  RosaryPrayerId,
  RosarySession,
  SevenSorrowsDevotion,
} from "./types"

/**
 * Sources (all checked against the page scans; see docs/john/content-sources.md):
 * Sign of the Cross: Marchant, Life of St. Jude Thaddeus (1929, Imprimatur Mundelein), p. 19.
 * Creed, Our Father, Hail Mary, Glory Be: Lasance, With God (1911, Imprimatur Farley), pp. 153–154, 514.
 * Hail, Holy Queen: A Manual of Prayers (Third Plenary Council of Baltimore, 1889), pp. 79–80.
 * Rosary collect: The Missal (Burns Oates; B. Herder, 1926 printing; Imprimatur Westminster 1921), p. 695.
 * Seven Sorrows: The Raccolta (1910, tr. Ambrose St. John), nos. 230 and 232.
 * The Fatima prayer is awaiting a decision (no approved English text before 1931 was found).
 */
export const ROSARY_PRAYERS: Readonly<Record<RosaryPrayerId, RosaryPrayer>> = {
  "sign-of-the-cross": {
    id: "sign-of-the-cross",
    title: "The Sign of the Cross",
    text: "In the Name of the Father, and of the Son, and of the Holy Ghost. Amen.",
  },
  "apostles-creed": {
    id: "apostles-creed",
    title: "The Apostles’ Creed",
    text: "I believe in God, the Father Almighty, Creator of heaven and earth; and in Jesus Christ, His only Son, our Lord: Who was conceived by the Holy Ghost, born of the Virgin Mary, suffered under Pontius Pilate, was crucified, died, and was buried. He descended into hell; the third day He rose again from the dead; He ascended into heaven, sitteth at the right hand of God, the Father Almighty; from thence He shall come to judge the living and dead. I believe in the Holy Ghost, the holy Catholic Church, the communion of saints, the forgiveness of sins, the resurrection of the body, and the life everlasting. Amen.",
  },
  "our-father": {
    id: "our-father",
    title: "Our Father",
    text: "Our Father, Who art in heaven, hallowed be Thy name. Thy kingdom come; Thy will be done on earth, as it is in heaven. Give us this day our daily bread; and forgive us our trespasses, as we forgive those who trespass against us. And lead us not into temptation; but deliver us from evil. Amen.",
  },
  "hail-mary": {
    id: "hail-mary",
    title: "Hail Mary",
    text: "Hail, Mary, full of grace; the Lord is with thee; blessed art thou among women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen.",
  },
  "glory-be": {
    id: "glory-be",
    title: "Glory Be",
    text: "Glory be to the Father, and to the Son, and to the Holy Ghost; as it was in the beginning, is now, and ever shall be, world without end. Amen.",
  },
  "fatima-prayer": {
    id: "fatima-prayer",
    title: "Fatima Prayer",
    text: "O my Jesus, forgive us our sins, save us from the fires of hell, lead all souls to heaven, especially those in most need of thy mercy. Amen.",
  },
  "hail-holy-queen": {
    id: "hail-holy-queen",
    title: "Hail, Holy Queen",
    text: "Hail, holy Queen, Mother of mercy; our life, our sweetness, and our hope. To thee do we cry, poor banished children of Eve; to thee do we send up our sighs, mourning and weeping in this valley of tears. Turn, then, most gracious Advocate, thine eyes of mercy towards us; and after this our exile, show unto us the blessed fruit of thy womb, Jesus; O clement, O pious, O sweet Virgin Mary.\nV. Pray for us, O holy Mother of God.\nR. That we may be made worthy of the promises of Christ.",
  },
  "closing-prayer": {
    id: "closing-prayer",
    title: "Closing Prayer",
    text: "O God, whose only-begotten Son by his life, death and resurrection hath purchased for us the rewards of eternal salvation; grant, we beseech thee, that, meditating upon these mysteries in the most holy Rosary of the blessed Virgin Mary, we may both imitate what they contain, and obtain what they promise. Through the same.",
  },
  "sorrows-opening": {
    id: "sorrows-opening",
    title: "Opening Versicle",
    text: "V. O God, come to my assistance.\nR. O Lord, make haste to help me.\nGlory be to the Father, and to the Son, and to the Holy Ghost; as it was in the beginning, is now, and ever shall be, world without end. Amen.",
  },
  "sorrows-versicle": {
    id: "sorrows-versicle",
    title: "Pray for Us",
    text: "V. Pray for us, Virgin most sorrowful.\nR. That we may be made worthy of the promises of Christ.",
  },
  "sorrows-closing-prayer": {
    id: "sorrows-closing-prayer",
    title: "Closing Prayer",
    text: "Grant, we beseech Thee, O Lord Jesus Christ, that the most blessed Virgin Mary, thy Mother, may intercede for us before the throne of thy mercy, now and at the hour of our death, whose most holy soul was transfixed with the sword of sorrow in the hour of thine own Passion. Through Thee, Jesus Christ, Saviour of the world, who livest and reignest, etc. Amen.",
  },
}

function prayerStep(
  id: string,
  eyebrow: string,
  prayerId: RosaryPrayerId,
  repetitions = 1,
  mysteryIndex?: number,
): RosaryGuideStep {
  return {
    id,
    eyebrow,
    title: ROSARY_PRAYERS[prayerId].title,
    prayer: ROSARY_PRAYERS[prayerId],
    repetitions,
    mysteryIndex,
  }
}

export function buildRosaryGuide(set: RosaryMysterySet): readonly RosaryGuideStep[] {
  const opening: RosaryGuideStep[] = [
    prayerStep("sign-of-the-cross", "Opening", "sign-of-the-cross"),
    prayerStep("apostles-creed", "Opening", "apostles-creed"),
    prayerStep("opening-our-father", "For the Holy Father’s intentions", "our-father"),
    prayerStep("opening-hail-marys", "For faith, hope, and charity", "hail-mary", 3),
    prayerStep("opening-glory-be", "Opening", "glory-be"),
  ]

  const decades = set.mysteries.flatMap<RosaryGuideStep>((mystery, index) => {
    const decade = index + 1
    const eyebrow = `Decade ${decade} of 5`
    return [
      {
        id: `mystery-${decade}`,
        eyebrow,
        title: mystery.title,
        instruction: mystery.scriptureReference,
        repetitions: 1,
        mysteryIndex: index,
      },
      prayerStep(`our-father-${decade}`, eyebrow, "our-father", 1, index),
      prayerStep(`hail-marys-${decade}`, eyebrow, "hail-mary", 10, index),
      prayerStep(`glory-be-${decade}`, eyebrow, "glory-be", 1, index),
      prayerStep(`fatima-${decade}`, eyebrow, "fatima-prayer", 1, index),
    ]
  })

  return [
    ...opening,
    ...decades,
    prayerStep("hail-holy-queen", "Conclusion", "hail-holy-queen"),
    prayerStep("closing-prayer", "Conclusion", "closing-prayer"),
    prayerStep("closing-sign-of-the-cross", "Conclusion", "sign-of-the-cross"),
  ]
}

/**
 * The Servite Rosary: seven groups of one Our Father and seven Hail Marys, then
 * three Hail Marys honouring the tears of the Sorrowful Mother.
 */
export function buildSevenSorrowsGuide(devotion: SevenSorrowsDevotion): readonly RosaryGuideStep[] {
  const opening: RosaryGuideStep[] = [
    prayerStep("sign-of-the-cross", "Opening", "sign-of-the-cross"),
    prayerStep("sorrows-opening", "Opening", "sorrows-opening"),
  ]

  const groups = devotion.sorrows.flatMap<RosaryGuideStep>((sorrow, index) => {
    const number = index + 1
    const eyebrow = `Sorrow ${number} of 7`
    return [
      {
        id: `sorrow-${number}`,
        eyebrow,
        title: sorrow.title,
        instruction: `${sorrow.scriptureReference} · Grace of this sorrow: ${sorrow.grace}`,
        meditation: sorrow.invocation,
        repetitions: 1,
        mysteryIndex: index,
      },
      prayerStep(`sorrow-our-father-${number}`, eyebrow, "our-father", 1, index),
      prayerStep(`sorrow-hail-marys-${number}`, eyebrow, "hail-mary", 7, index),
    ]
  })

  return [
    ...opening,
    ...groups,
    prayerStep("tears-hail-marys", "For the tears of our Sorrowful Mother", "hail-mary", 3),
    prayerStep("sorrows-versicle", "Conclusion", "sorrows-versicle"),
    prayerStep("sorrows-closing-prayer", "Conclusion", "sorrows-closing-prayer"),
    prayerStep("closing-sign-of-the-cross", "Conclusion", "sign-of-the-cross"),
  ]
}

/** Flattens either devotion into the shape the guide screen prays. */
export function buildRosarySession(
  devotion: RosaryMysterySet | SevenSorrowsDevotion,
): RosarySession {
  if (devotion.id === "seven-sorrows") {
    return {
      id: devotion.id,
      title: devotion.title,
      shortTitle: devotion.shortTitle,
      groupLabels: devotion.sorrows.map((sorrow) => sorrow.title),
      steps: buildSevenSorrowsGuide(devotion),
    }
  }

  return {
    id: devotion.id,
    title: devotion.title,
    shortTitle: devotion.shortTitle,
    groupLabels: devotion.mysteries.map((mystery) => mystery.title),
    steps: buildRosaryGuide(devotion),
  }
}
