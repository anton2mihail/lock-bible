export type PrayerSection = {
  title?: string
  paragraphs: string[]
  response?: string
}

export type Novena = {
  id: string
  title: string
  subtitle: string
  about: string
  patronage: string
  traditionalStart?: string
  feastDay?: string
  sourceName: string
  sourceUrl: string
  searchTerms: string[]
  opening?: string
  sections: PrayerSection[]
}

export const NOVENA_DAY_COUNT = 9

export const padrePioNovena = {
  id: "st-padre-pio",
  title: "St. Padre Pio Novena",
  subtitle: "A nine-day prayer for healing and difficult needs",
  about:
    "Padre Pio was an Italian Capuchin friar remembered for spiritual counsel, a life of prayer, and patient trust through suffering. This novena uses the prayer to the Sacred Heart that he prayed for those who asked for his intercession.",
  patronage: "Those who suffer, healing, and relief from stress",
  traditionalStart: "September 14",
  feastDay: "September 23",
  sourceName: "Novena Prayer",
  sourceUrl: "https://novenaprayer.com/st-padre-pio-novena/",
  searchTerms: ["Padre Pio", "Sacred Heart", "healing", "difficult needs", "Italy"],
  opening: "In the name of the Father, and of the Son, and of the Holy Spirit. Amen.",
  sections: [
    {
      paragraphs: [
        "O my Jesus, You have said: “Truly I say to you, ask and you will receive, seek and you will find, knock and it will be opened to you.” Behold, I knock, I seek, and I ask for the grace of my intention.",
      ],
      response:
        "Our Father · Hail Mary · Glory Be\nSacred Heart of Jesus, I place all my trust in You.",
    },
    {
      paragraphs: [
        "O my Jesus, You have said: “Truly I say to you, if you ask anything of the Father in My name, He will give it to you.” Behold, in Your name, I ask the Father for the grace of my intention.",
      ],
      response:
        "Our Father · Hail Mary · Glory Be\nSacred Heart of Jesus, I place all my trust in You.",
    },
    {
      paragraphs: [
        "O my Jesus, You have said: “Truly I say to you, heaven and earth will pass away, but My words will not pass away.” Encouraged by Your infallible words, I now ask for the grace of my intention.",
      ],
      response:
        "Our Father · Hail Mary · Glory Be\nSacred Heart of Jesus, I place all my trust in You.",
    },
    {
      paragraphs: [
        "O Sacred Heart of Jesus, for whom it is impossible not to have compassion on the afflicted, have pity on us miserable sinners and grant us the grace which we ask of You, through the Sorrowful and Immaculate Heart of Mary, Your tender Mother and ours.",
      ],
    },
    {
      title: "Hail Holy Queen",
      paragraphs: [
        "Hail, Holy Queen, Mother of Mercy, our life, our sweetness, and our hope. To thee do we cry, poor banished children of Eve. To thee do we send up our sighs, mourning and weeping in this valley of tears.",
        "Turn then, most gracious advocate, thine eyes of mercy toward us. And after this, our exile, show unto us the blessed fruit of thy womb, Jesus. O clement, O loving, O sweet Virgin Mary.",
        "Pray for us, O Holy Mother of God, that we may be made worthy of the promises of Christ.",
      ],
    },
    {
      title: "Closing invocations",
      paragraphs: [
        "St. Padre Pio, pray for us.",
        "St. Joseph, foster father of Jesus, pray for us.",
      ],
    },
  ],
} satisfies Novena
