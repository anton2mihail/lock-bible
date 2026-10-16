export type Prayer = {
  id: string
  title: string
  subtitle: string
  category: "Daily rhythm" | "Traditional prayers" | "In times of need" | "Prayers of the saints"
  text: string
  source: string
}
export const ACT_OF_CONTRITION =
  "O my God, I am heartily sorry for having offended Thee, and I detest all my sins because I dread the loss of heaven and the pains of hell, but most of all because they offend Thee, my God, who art all good and deserving of all my love. I firmly resolve, with the help of Thy grace, to confess my sins, to do penance, and to amend my life. Amen."
export const PRAYERS: Prayer[] = [
  {
    id: "morning",
    title: "Morning Offering",
    subtitle: "Offer the day through the Heart of Jesus",
    category: "Daily rhythm",
    text: "O Jesus, through the Immaculate Heart of Mary, I offer You my prayers, works, joys and sufferings of this day for all the intentions of Your Sacred Heart, in union with the Holy Sacrifice of the Mass throughout the world, in reparation for my sins, for the intentions of all my relatives and friends, and in particular for the intentions of the Holy Father. Amen.",
    source: "Traditional prayer of the Apostleship of Prayer · text as published by EWTN",
  },
  {
    id: "evening",
    title: "Night Prayer",
    subtitle: "The collect of Compline",
    category: "Daily rhythm",
    text: "Visit, we beseech Thee, O Lord, this habitation, and drive far from it all snares of the enemy: let Thine holy Angels dwell herein, to keep us in peace, and may Thy blessing be always upon us. Through our Lord Jesus Christ Thy Son, Who liveth and reigneth with Thee, in the unity of the Holy Ghost, one God, world without end. Amen.",
    source: "The Roman Breviary, Compline · translated by the Marquess of Bute (1879)",
  },
  {
    id: "meals",
    title: "Grace before meals",
    subtitle: "Before eating",
    category: "Daily rhythm",
    text: "Bless us, O Lord, and these Thy gifts, which we are about to receive from Thy bounty, through Christ our Lord. Amen.",
    source: "Traditional Catholic prayer · historic English wording",
  },
  {
    id: "grace-after-meals",
    title: "Grace after meals",
    subtitle: "After eating",
    category: "Daily rhythm",
    text: "We give Thee thanks, almighty God, for all Thy benefits, Who livest and reignest now and for ever. Amen.",
    source: "Traditional Catholic prayer · F. X. Lasance, Prayer-Book for Religious (1904)",
  },
  {
    id: "angelus",
    title: "The Angelus",
    subtitle: "Morning, noon, and evening",
    category: "Traditional prayers",
    text: "The Angel of the Lord declared unto Mary.\nAnd she conceived of the Holy Spirit.\n\nPray the Hail Mary.\n\nBehold the handmaid of the Lord.\nBe it done unto me according to thy word.\n\nPray the Hail Mary.\n\nAnd the Word was made flesh.\nAnd dwelt among us.\n\nPray the Hail Mary.\n\nPray for us, O holy Mother of God.\nThat we may be made worthy of the promises of Christ.\n\nLet us pray. Pour forth, we beseech Thee, O Lord, Thy grace into our hearts; that we, to whom the Incarnation of Christ Thy Son was made known by the message of an angel, may by His Passion and Cross be brought to the glory of His Resurrection. Through the same Christ our Lord. Amen.",
    source: "Traditional Catholic prayer · historic English wording",
  },
  {
    id: "regina-caeli",
    title: "Regina Caeli",
    subtitle: "In place of the Angelus during Eastertide",
    category: "Traditional prayers",
    text: "Queen of Heaven, rejoice, alleluia.\nFor He whom thou didst merit to bear, alleluia,\nHas risen, as He said, alleluia.\nPray for us to God, alleluia.\n\nRejoice and be glad, O Virgin Mary, alleluia.\nFor the Lord has truly risen, alleluia.\n\nLet us pray. O God, who gave joy to the world through the Resurrection of Thy Son, our Lord Jesus Christ, grant, we beseech Thee, that through the intercession of the Virgin Mary, His Mother, we may obtain the joys of everlasting life. Through the same Christ our Lord. Amen.",
    source: "Traditional Catholic prayer · historic English wording",
  },
  {
    id: "our-father",
    title: "Our Father",
    subtitle: "The Lord’s Prayer · Matthew 6:9–13",
    category: "Traditional prayers",
    text: "Our Father, who art in heaven, hallowed be Thy name; Thy kingdom come; Thy will be done on earth as it is in heaven. Give us this day our daily bread; and forgive us our trespasses as we forgive those who trespass against us; and lead us not into temptation, but deliver us from evil. Amen.",
    source: "Traditional Catholic prayer · historic English wording",
  },
  {
    id: "hail-mary",
    title: "Hail Mary",
    subtitle: "The Angelic Salutation · Luke 1:28, 42",
    category: "Traditional prayers",
    text: "Hail Mary, full of grace, the Lord is with thee. Blessed art thou among women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen.",
    source: "Traditional Catholic prayer · historic English wording",
  },
  {
    id: "glory-be",
    title: "Glory Be",
    subtitle: "The lesser doxology",
    category: "Traditional prayers",
    text: "Glory be to the Father, and to the Son, and to the Holy Spirit. As it was in the beginning, is now, and ever shall be, world without end. Amen.",
    source: "Traditional Catholic prayer · historic English wording",
  },
  {
    id: "contrition",
    title: "Act of Contrition",
    subtitle: "Before or after Confession",
    category: "Traditional prayers",
    text: ACT_OF_CONTRITION,
    source: "Traditional Catholic prayer · historic English wording",
  },
  {
    id: "memorare",
    title: "The Memorare",
    subtitle: "Traditionally attributed to St. Bernard of Clairvaux",
    category: "Traditional prayers",
    text: "Remember, O most gracious Virgin Mary, that never was it known that any one who fled to thy protection, implored thy help, or sought thy intercession, was left unaided. Inspired with this confidence, I fly unto thee, O Virgin of virgins, my mother; to thee I come, before thee I stand, sinful and sorrowful; O Mother of the Word Incarnate, despise not my petitions; but in thy clemency hear and answer me. Amen.",
    source: "The Raccolta, no. 196 · translated by Ambrose St. John (1910)",
  },
  {
    id: "come-holy-spirit",
    title: "Come, Holy Spirit",
    subtitle: "Prayer to the Holy Spirit",
    category: "Traditional prayers",
    text: "Come, Holy Spirit, fill the hearts of Thy faithful and enkindle in them the fire of Thy love.\nV. Send forth Thy Spirit and they shall be created.\nR. And Thou shalt renew the face of the earth.\n\nLet us pray. O God, Who didst instruct the hearts of the faithful by the light of the Holy Spirit, grant us in the same Spirit to be truly wise, and ever to rejoice in His consolation. Through Christ our Lord.\nAmen.",
    source: "Traditional Catholic prayer · text as published by EWTN",
  },
  {
    id: "anima-christi",
    title: "Anima Christi",
    subtitle: "Soul of Christ, sanctify me",
    category: "Traditional prayers",
    text: "Soul of Christ, sanctify me!\nBody of Christ, save me!\nBlood of Christ, inebriate me!\nWater from the side of Christ, wash me!\nPassion of Christ, strengthen me!\nO Good Jesus, hear me!\nWithin Thy Wounds hide me!\nSuffer me not to be separated from Thee!\nFrom the malicious enemy defend me!\nIn the hour of my death, call me,\nAnd bid me come to Thee;\nThat with Thy Saints I may praise Thee\nFor ever and ever. Amen.",
    source:
      "Medieval prayer that St. Ignatius of Loyola placed at the start of the Spiritual Exercises · A Manual of Prayers (1898)",
  },
  {
    id: "sub-tuum",
    title: "Sub tuum praesidium",
    subtitle: "The oldest known prayer to Mary",
    category: "In times of need",
    text: "We fly to thy patronage, O Holy Mother of God; despise not thou our petitions in our necessities, but deliver us always from all dangers, O glorious and blessed Virgin.",
    source: "The Raccolta, no. 184 · translated by Ambrose St. John (1910)",
  },
  {
    id: "st-michael",
    title: "Prayer to St. Michael",
    subtitle: "Pope Leo XIII",
    category: "In times of need",
    text: "St. Michael the archangel, defend us in battle; be our protection against the malice and snares of the devil. Rebuke him, O God, we humbly pray; and do thou, O prince of the heavenly host, by the divine power, thrust into hell Satan and the other evil spirits who roam through the world seeking the ruin of souls. Amen.",
    source: "Pope Leo XIII (1886) · F. X. Lasance, Prayer-Book for Religious (1904)",
  },
  {
    id: "miraculous-medal",
    title: "Invocation of the Miraculous Medal",
    subtitle: "Given to St. Catherine Labouré, 1830",
    category: "In times of need",
    text: "O Mary, conceived without sin, pray for us who have recourse to thee.",
    source: "The Raccolta, no. 249 (1910)",
  },
  {
    id: "departed",
    title: "For the faithful departed",
    subtitle: "Eternal rest",
    category: "In times of need",
    text: "Eternal rest grant unto them, O Lord, and let perpetual light shine upon them. May they rest in peace. Amen.\n\nMay the souls of all the faithful departed, through the mercy of God, rest in peace. Amen.",
    source: "Traditional Catholic prayer · historic English wording",
  },
  {
    id: "st-augustine-restless",
    title: "Our hearts are restless",
    subtitle: "St. Augustine of Hippo",
    category: "Prayers of the saints",
    text: "Great art Thou, O Lord, and greatly to be praised; great is Thy power, and of Thy wisdom there is no end. And man, being a part of Thy creation, desires to praise Thee, man, who bears about with him his mortality, the witness of his sin, even the witness that Thou “resistest the proud,”—yet man, this part of Thy creation, desires to praise Thee. Thou movest us to delight in praising Thee; for Thou hast formed us for Thyself, and our hearts are restless till they find rest in Thee.",
    source:
      "St. Augustine, Confessions, Book I, 1 · translated by J. G. Pilkington, Nicene and Post-Nicene Fathers (1886)",
  },
  {
    id: "st-augustine-too-late",
    title: "Too late did I love Thee",
    subtitle: "St. Augustine of Hippo",
    category: "Prayers of the saints",
    text: "Too late did I love Thee, O Fairness, so ancient, and yet so new! Too late did I love Thee! For behold, Thou wert within, and I without, and there did I seek Thee; I, unlovely, rushed heedlessly among the things of beauty Thou madest. Thou wert with me, but I was not with Thee. Those things kept me far from Thee, which, unless they were in Thee, were not. Thou calledst, and criedst aloud, and forcedst open my deafness. Thou didst gleam and shine, and chase away my blindness. Thou didst exhale odours, and I drew in my breath and do pant after Thee. I tasted, and do hunger and thirst. Thou didst touch me, and I burned for Thy peace.",
    source:
      "St. Augustine, Confessions, Book X, 38 · translated by J. G. Pilkington, Nicene and Post-Nicene Fathers (1886)",
  },
  {
    id: "st-ignatius-suscipe",
    title: "Suscipe",
    subtitle: "St. Ignatius of Loyola",
    category: "Prayers of the saints",
    text: "Take, Lord, and receive all my liberty, my memory, my intellect, and all my will—all that I have and possess. Thou gavest it to me: to Thee, Lord, I return it! All is Thine, dispose of it according to all Thy will. Give me Thy love and grace, for this is enough for me.",
    source:
      "St. Ignatius of Loyola, Spiritual Exercises, Contemplation to Gain Love · translated by Elder Mullan, S.J. (1914)",
  },
  {
    id: "st-teresa-bookmark",
    title: "Let nothing disturb thee",
    subtitle: "St. Teresa of Ávila",
    category: "Prayers of the saints",
    text: "Let nothing disturb thee,\nNothing affright thee;\nAll things are passing;\nGod never changeth;\nPatient endurance\nAttaineth to all things;\nWho God possesseth\nIn nothing is wanting;\nAlone God sufficeth.",
    source:
      "St. Teresa of Ávila · “Santa Teresa’s Book-Mark,” translated by Henry Wadsworth Longfellow",
  },
  {
    id: "st-patrick-breastplate",
    title: "Christ with me",
    subtitle: "St. Patrick’s Breastplate",
    category: "Prayers of the saints",
    text: "Christ with me, Christ before me, Christ behind me,\nChrist in me, Christ beneath me, Christ above me,\nChrist on my right, Christ on my left,\nChrist when I lie down, Christ when I sit down, Christ when I arise,\nChrist in the heart of every man who thinks of me,\nChrist in the mouth of every one who speaks of me,\nChrist in every eye that sees me,\nChrist in every ear that hears me.",
    source:
      "“The Deer’s Cry,” traditionally attributed to St. Patrick · translated by Kuno Meyer (1911)",
  },
  {
    id: "st-francis-adoration",
    title: "We adore Thee",
    subtitle: "St. Francis of Assisi",
    category: "Prayers of the saints",
    text: "We adore Thee Lord Jesus Christ here and in all Thy churches which are in the whole world, and we bless Thee because by Thy holy cross Thou hast redeemed the world.",
    source: "St. Francis of Assisi, Testament · translated by Paschal Robinson, O.F.M. (1905)",
  },
  {
    id: "st-alphonsus-spiritual-communion",
    title: "Act of Spiritual Communion",
    subtitle: "St. Alphonsus Liguori",
    category: "Prayers of the saints",
    text: "My Jesus, I believe that Thou art in the Blessed Sacrament. I love Thee above everything, and I long for Thee in my soul. Since I cannot now receive Thee sacramentally, come at least spiritually into my heart. As though Thou wert already come, I embrace Thee and unite myself entirely to Thee; allow me not to be separated from Thee.\nJesus, my good, my sweet love,\nWound, inflame this heart of mine.\nSo that it may be always and all on fire for Thee.",
    source: "St. Alphonsus Liguori · The Raccolta, no. 104 (1910)",
  },
  {
    id: "st-thomas-before-study",
    title: "Prayer before study",
    subtitle: "St. Thomas Aquinas",
    category: "Prayers of the saints",
    text: "O Ineffable Creator, who, of the treasures of thy wisdom hast formed the nine choirs of Angels, and set them on high above the heavens in a wonderful order, and hast exquisitely fashioned and knit together all parts of the universe; do Thou, who art the true fountain and one principle of light and wisdom, deign to shed the brightness of thy light upon the darkness of my understanding, and thus to disperse the twofold darkness of sin and ignorance wherein I was born. O Thou, who makest eloquent the tongues of babes, instruct my tongue, and pour forth on my lips the grace of thy blessing. Grant me acuteness in understanding what I read, power to retain it, subtiety [sic] to discern its true meaning, and clearness and ease in expressing it. Do Thou order my beginnings, direct and further my progress, complete and bless my ending; Thou who art true God and true Man, who livest and reignest world without end. Amen.",
    source: "St. Thomas Aquinas, “Creator ineffabilis” · The Raccolta, no. 52 (1910)",
  },
  {
    id: "st-anthony-responsory",
    title: "Responsory of St. Anthony",
    subtitle: "Si quaeris miracula",
    category: "Prayers of the saints",
    text: "If then you ask for miracles,\nDeath, error, all calamities,\nThe leprosy and demons fly,\nAnd health succeeds infirmities.\n\nThe sea obeys, and fetters break,\nAnd lifeless limbs thou dost restore;\nWhilst treasures lost are found again,\nWhen young or old thine aid implore.\n\nAll dangers vanish at thy prayer,\nAnd direst need doth quickly flee.\nLet those who know thy power proclaim—\nLet Paduans say—These are of thee.\n\nThe sea obeys, etc.\n\nTo Father, Son, may glory be,\nAnd Holy Ghost eternally.\n\nThe sea obeys, etc.\nV. Pray for us, blessed Anthony.\nR. That we may be made worthy of the promises of Christ.\n\nLet us pray.\nO God, may the votive commemoration of the blessed Anthony, thy Confessor, be a source of joy to thy Church, that she may always be fortified with spiritual assistance, and deserve to enjoy eternal rewards. Through Jesus Christ our Lord. Amen.",
    source: "Traditionally attributed to St. Bonaventure · The Raccolta, no. 358 (1910)",
  },
  {
    id: "st-newman-lead-kindly-light",
    title: "Lead, Kindly Light",
    subtitle: "St. John Henry Newman",
    category: "Prayers of the saints",
    text: "Lead, Kindly Light, amid the encircling gloom\nLead Thou me on!\nThe night is dark, and I am far from home—\nLead Thou me on!\nKeep Thou my feet; I do not ask to see\nThe distant scene—one step enough for me.\n\nI was not ever thus, nor pray'd that Thou\nShouldst lead me on.\nI loved to choose and see my path, but now\nLead Thou me on!\nI loved the garish day, and, spite of fears,\nPride ruled my will: remember not past years.\n\nSo long Thy power hath blest me, sure it still\nWill lead me on,\nO'er moor and fen, o'er crag and torrent, till\nThe night is gone;\nAnd with the morn those angel faces smile\nWhich I have loved long since, and lost awhile.",
    source: "St. John Henry Newman, “The Pillar of the Cloud” (1833)",
  },
  {
    id: "fatima-angel",
    title: "Prayers of the Angel of Fatima",
    subtitle: "Taught to Sts. Francisco and Jacinta Marto and Lúcia, 1916",
    category: "Prayers of the saints",
    text: "My God, I believe, I adore, I hope and I love You! I ask pardon of You for those who do not believe, do not adore, do not hope and do not love You!\n\nMost Holy Trinity, Father, Son and Holy Spirit, I adore You profoundly and I offer You the most precious Body, Blood, Soul and Divinity of Jesus Christ, present in all the tabernacles of the world, in reparation for the outrages, sacrileges and indifference with which He is offended. And through the infinite merits of the Sacred Heart and the Immaculate Heart of Mary, I beg the conversion of poor sinners.",
    source: "As recorded by Sister Lúcia of Fatima · text from the Shrine of Fatima",
  },
]
export function getPrayer(id: string | undefined): Prayer | undefined {
  return PRAYERS.find((prayer) => prayer.id === id)
}
