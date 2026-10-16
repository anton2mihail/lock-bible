import type { Novena } from "./padrePioNovena"

// Every novena here quotes its source verbatim. Do not add app-written prayers.
export const expandedNovenas: Novena[] = [
  {
    id: "divine-mercy",
    title: "Divine Mercy Novena",
    subtitle: "The Chaplet of Divine Mercy, prayed for nine days",
    about: "",
    patronage: "Mercy on us and on the whole world",
    traditionalStart: "Good Friday",
    feastDay: "Divine Mercy Sunday",
    sourceName: "Diary of St. Maria Faustina Kowalska, 476",
    sourceUrl: "https://www.thedivinemercy.org/message/devotions/pray-the-chaplet",
    searchTerms: ["Faustina", "mercy", "chaplet", "forgiveness", "Easter", "Divine Mercy Sunday"],
    sections: [
      {
        title: "Diary, 476",
        paragraphs: [
          "This prayer will serve to appease My wrath. You will recite it for nine days, on the beads of the rosary, in the following manner: First of all, you will say one OUR FATHER and HAIL MARY and the I BELIEVE IN GOD.",
        ],
        response: "Our Father · Hail Mary · I Believe in God",
      },
      {
        title: "On the Our Father beads",
        paragraphs: [
          "Eternal Father, I offer You the Body and Blood, Soul and Divinity of Your dearly beloved Son, Our Lord Jesus Christ, in atonement for our sins and those of the whole world.",
        ],
      },
      {
        title: "On the Hail Mary beads",
        paragraphs: [
          "For the sake of His sorrowful Passion have mercy on us and on the whole world.",
        ],
      },
      {
        title: "In conclusion, three times",
        paragraphs: [
          "Holy God, Holy Mighty One, Holy Immortal One, have mercy on us and on the whole world.",
        ],
      },
    ],
  },
]
