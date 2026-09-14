export type Prayer = {
  id: string
  title: string
  subtitle: string
  category: "Daily rhythm" | "Traditional prayers" | "In times of need"
  text: string
  source: string
}
export const ACT_OF_CONTRITION =
  "O my God, I am heartily sorry for having offended Thee, and I detest all my sins because I dread the loss of heaven and the pains of hell, but most of all because they offend Thee, my God, who art all good and deserving of all my love. I firmly resolve, with the help of Thy grace, to confess my sins, to do penance, and to amend my life. Amen."
const traditional = "Traditional Catholic prayer · historic English wording"
const original = "An original prayer written for John 1:1"
export const PRAYERS: Prayer[] = [
  {
    id: "morning",
    title: "Morning offering",
    subtitle: "Begin the day with God",
    category: "Daily rhythm",
    text: "Father, thank you for the gift of this day. Through Jesus Christ, I offer you my work, my rest, my joys, and my difficulties. Help me to meet each person with patience and love. May your Holy Spirit guide my choices, and may Mary teach me to say yes to you. Amen.",
    source: original,
  },
  {
    id: "evening",
    title: "Evening examen",
    subtitle: "Look back with gratitude and honesty",
    category: "Daily rhythm",
    text: "Be still. Ask the Holy Spirit to help you see this day with love.\n\nGive thanks. Remember one gift, however small.\n\nReview the day. Where did you receive love? Where did you withhold it?\n\nAsk forgiveness. Bring one failure to God without excuses or despair.\n\nLook toward tomorrow. Ask for the grace to make one loving response.\n\nFather, receive this day. Forgive what needs forgiving, heal what needs healing, and let me rest in your care. Amen.",
    source: "Original prompts inspired by the Ignatian practice of the examen",
  },
  {
    id: "meals",
    title: "Grace before meals",
    subtitle: "Give thanks for daily bread",
    category: "Daily rhythm",
    text: "Bless us, O Lord, and these Thy gifts, which we are about to receive from Thy bounty, through Christ our Lord. Amen.",
    source: traditional,
  },
  {
    id: "angelus",
    title: "The Angelus",
    subtitle: "Remember the Incarnation",
    category: "Traditional prayers",
    text: "The Angel of the Lord declared unto Mary.\nAnd she conceived of the Holy Spirit.\n\nPray the Hail Mary.\n\nBehold the handmaid of the Lord.\nBe it done unto me according to thy word.\n\nPray the Hail Mary.\n\nAnd the Word was made flesh.\nAnd dwelt among us.\n\nPray the Hail Mary.\n\nPray for us, O holy Mother of God.\nThat we may be made worthy of the promises of Christ.\n\nLet us pray. Pour forth, we beseech Thee, O Lord, Thy grace into our hearts; that we, to whom the Incarnation of Christ Thy Son was made known by the message of an angel, may by His Passion and Cross be brought to the glory of His Resurrection. Through the same Christ our Lord. Amen.",
    source: traditional,
  },
  {
    id: "regina-caeli",
    title: "Regina Caeli",
    subtitle: "A Marian prayer for Easter",
    category: "Traditional prayers",
    text: "Queen of Heaven, rejoice, alleluia.\nFor He whom thou didst merit to bear, alleluia,\nHas risen, as He said, alleluia.\nPray for us to God, alleluia.\n\nRejoice and be glad, O Virgin Mary, alleluia.\nFor the Lord has truly risen, alleluia.\n\nLet us pray. O God, who gave joy to the world through the Resurrection of Thy Son, our Lord Jesus Christ, grant, we beseech Thee, that through the intercession of the Virgin Mary, His Mother, we may obtain the joys of everlasting life. Through the same Christ our Lord. Amen.",
    source: traditional,
  },
  {
    id: "our-father",
    title: "Our Father",
    subtitle: "The prayer Jesus taught us",
    category: "Traditional prayers",
    text: "Our Father, who art in heaven, hallowed be Thy name; Thy kingdom come; Thy will be done on earth as it is in heaven. Give us this day our daily bread; and forgive us our trespasses as we forgive those who trespass against us; and lead us not into temptation, but deliver us from evil. Amen.",
    source: traditional,
  },
  {
    id: "hail-mary",
    title: "Hail Mary",
    subtitle: "Ask Mary to pray with you",
    category: "Traditional prayers",
    text: "Hail Mary, full of grace, the Lord is with thee. Blessed art thou among women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen.",
    source: traditional,
  },
  {
    id: "glory-be",
    title: "Glory Be",
    subtitle: "Praise the Holy Trinity",
    category: "Traditional prayers",
    text: "Glory be to the Father, and to the Son, and to the Holy Spirit. As it was in the beginning, is now, and ever shall be, world without end. Amen.",
    source: traditional,
  },
  {
    id: "contrition",
    title: "Act of Contrition",
    subtitle: "Turn toward God’s mercy",
    category: "Traditional prayers",
    text: ACT_OF_CONTRITION,
    source: traditional,
  },
  {
    id: "suffering",
    title: "For someone who is suffering",
    subtitle: "Bring a loved one into prayer",
    category: "In times of need",
    text: "Jesus, you drew near to people in pain. Be close to the person I hold in my heart. Grant them comfort, strength, and the care they need. Guide those who support them. Show me how to help with patience, practical kindness, and faithful presence. Amen.",
    source: original,
  },
  {
    id: "anxiety",
    title: "In an anxious moment",
    subtitle: "Make room for a quiet breath",
    category: "In times of need",
    text: "Lord, I bring you what I cannot settle on my own. Help me attend to this moment and take the next small step. Give me courage to ask for help, wisdom to accept support, and patience with myself. Remain with me in this uncertainty. Amen.",
    source: original,
  },
  {
    id: "departed",
    title: "For the faithful departed",
    subtitle: "Remember those who have died",
    category: "In times of need",
    text: "Eternal rest grant unto them, O Lord, and let perpetual light shine upon them. May they rest in peace. Amen.\n\nMay the souls of all the faithful departed, through the mercy of God, rest in peace. Amen.",
    source: traditional,
  },
]
export function getPrayer(id: string | undefined): Prayer | undefined {
  return PRAYERS.find((prayer) => prayer.id === id)
}
