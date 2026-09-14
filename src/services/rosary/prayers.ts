import type { RosaryGuideStep, RosaryMysterySet, RosaryPrayer, RosaryPrayerId } from "./types"

export const ROSARY_PRAYERS: Readonly<Record<RosaryPrayerId, RosaryPrayer>> = {
  "sign-of-the-cross": {
    id: "sign-of-the-cross",
    title: "The Sign of the Cross",
    text: "In the name of the Father, and of the Son, and of the Holy Spirit. Amen.",
  },
  "apostles-creed": {
    id: "apostles-creed",
    title: "The Apostles’ Creed",
    text: "I believe in God, the Father almighty, Creator of heaven and earth, and in Jesus Christ, his only Son, our Lord, who was conceived by the Holy Spirit, born of the Virgin Mary, suffered under Pontius Pilate, was crucified, died and was buried; he descended into hell; on the third day he rose again from the dead; he ascended into heaven, and is seated at the right hand of God the Father almighty; from there he will come to judge the living and the dead. I believe in the Holy Spirit, the holy catholic Church, the communion of saints, the forgiveness of sins, the resurrection of the body, and life everlasting. Amen.",
  },
  "our-father": {
    id: "our-father",
    title: "Our Father",
    text: "Our Father, who art in heaven, hallowed be thy name; thy kingdom come; thy will be done on earth as it is in heaven. Give us this day our daily bread; and forgive us our trespasses as we forgive those who trespass against us; and lead us not into temptation, but deliver us from evil. Amen.",
  },
  "hail-mary": {
    id: "hail-mary",
    title: "Hail Mary",
    text: "Hail Mary, full of grace, the Lord is with thee. Blessed art thou among women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen.",
  },
  "glory-be": {
    id: "glory-be",
    title: "Glory Be",
    text: "Glory be to the Father, and to the Son, and to the Holy Spirit, as it was in the beginning, is now, and ever shall be, world without end. Amen.",
  },
  "fatima-prayer": {
    id: "fatima-prayer",
    title: "Fatima Prayer",
    text: "O my Jesus, forgive us our sins, save us from the fires of hell, lead all souls to heaven, especially those in most need of thy mercy. Amen.",
  },
  "hail-holy-queen": {
    id: "hail-holy-queen",
    title: "Hail, Holy Queen",
    text: "Hail, holy Queen, Mother of mercy, our life, our sweetness, and our hope. To thee do we cry, poor banished children of Eve. To thee do we send up our sighs, mourning and weeping in this valley of tears. Turn then, most gracious advocate, thine eyes of mercy toward us, and after this our exile show unto us the blessed fruit of thy womb, Jesus. O clement, O loving, O sweet Virgin Mary. Pray for us, O holy Mother of God, that we may be made worthy of the promises of Christ.",
  },
  "closing-prayer": {
    id: "closing-prayer",
    title: "Closing Prayer",
    text: "O God, whose only-begotten Son, by his life, death and resurrection, has purchased for us the rewards of eternal life, grant, we beseech thee, that meditating upon these mysteries of the most holy Rosary of the Blessed Virgin Mary, we may imitate what they contain and obtain what they promise, through the same Christ our Lord. Amen.",
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
        instruction: `${mystery.scriptureReference} · Fruit of the mystery: ${mystery.fruit}`,
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
