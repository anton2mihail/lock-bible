export type Teaching = {
  id: string
  title: string
  subtitle: string
  summary: string
  references: string[]
  catechism: string
  url: string
  reflection: string
  artwork: "mary" | "prayer" | "scripture"
}
const base = "https://www.vatican.va/content/catechism/en/"
export const TEACHINGS: Teaching[] = [
  {
    id: "eucharist",
    title: "The Eucharist",
    subtitle: "Catechism of the Catholic Church, §1324",
    artwork: "scripture",
    summary:
      "The Eucharist is “the source and summit of the Christian life.” “The other sacraments, and indeed all ecclesiastical ministries and works of the apostolate, are bound up with the Eucharist and are oriented toward it. For in the blessed Eucharist is contained the whole spiritual good of the Church, namely Christ himself, our Pasch.”",
    references: ["Luke 22:14–20", "John 6:51–58", "1 Corinthians 11:23–26"],
    catechism: "CCC 1324",
    url:
      base +
      "part_two/section_two/chapter_one/article_3/i_the_eucharist_source_and_summit_of_ecclesial_life.index.html",
    reflection: "",
  },
  {
    id: "forgiveness",
    title: "Forgiveness & reconciliation",
    subtitle: "Catechism of the Catholic Church, §1440",
    artwork: "prayer",
    summary:
      "Sin is before all else an offense against God, a rupture of communion with him. At the same time it damages communion with the Church. For this reason conversion entails both God’s forgiveness and reconciliation with the Church, which are expressed and accomplished liturgically by the sacrament of Penance and Reconciliation.",
    references: ["Luke 15:11–32", "John 20:19–23", "Matthew 18:21–35"],
    catechism: "CCC 1440",
    url:
      base +
      "part_two/section_two/chapter_two/article_4/vi_the_sacrament_of_penance_and_reconciliation.html",
    reflection: "",
  },
  {
    id: "mary",
    title: "Mary & discipleship",
    subtitle: "Catechism of the Catholic Church, §971",
    artwork: "mary",
    summary:
      "“All generations will call me blessed”: “The Church’s devotion to the Blessed Virgin is intrinsic to Christian worship.” The Church rightly honors “the Blessed Virgin with special devotion. From the most ancient times the Blessed Virgin has been honored with the title of ‘Mother of God,’ to whose protection the faithful fly in all their dangers and needs.... This very special devotion ... differs essentially from the adoration which is given to the incarnate Word and equally to the Father and the Holy Spirit, and greatly fosters this adoration.” The liturgical feasts dedicated to the Mother of God and Marian prayer, such as the rosary, an “epitome of the whole Gospel,” express this devotion to the Virgin Mary.",
    references: ["Luke 1:26–38", "Luke 1:46–55", "John 2:1–11"],
    catechism: "CCC 971",
    url:
      base +
      "part_one/section_two/chapter_three/article_9/paragraph_6_mary_-_mother_of_christ%2C_mother_of_the_church.html",
    reflection: "",
  },
  {
    id: "suffering",
    title: "Hope in suffering",
    subtitle: "Catechism of the Catholic Church, §1505",
    artwork: "prayer",
    summary:
      "Moved by so much suffering Christ not only allows himself to be touched by the sick, but he makes their miseries his own: “He took our infirmities and bore our diseases.” But he did not heal all the sick. His healings were signs of the coming of the Kingdom of God. They announced a more radical healing: the victory over sin and death through his Passover. On the cross Christ took upon himself the whole weight of evil and took away the “sin of the world,” of which illness is only a consequence. By his passion and death on the cross Christ has given a new meaning to suffering: it can henceforth configure us to him and unite us with his redemptive Passion.",
    references: ["Mark 1:40–45", "Matthew 11:28–30", "Romans 8:35–39"],
    catechism: "CCC 1505",
    url:
      base +
      "part_two/section_two/chapter_two/article_5/i_its_foundations_in_the_economy_of_salvation.html",
    reflection: "",
  },
  {
    id: "prayer",
    title: "Praying with Scripture",
    subtitle: "Catechism of the Catholic Church, §2708",
    artwork: "scripture",
    summary:
      "Meditation engages thought, imagination, emotion, and desire. This mobilization of faculties is necessary in order to deepen our convictions of faith, prompt the conversion of our heart, and strengthen our will to follow Christ. Christian prayer tries above all to meditate on the mysteries of Christ, as in lectio divina or the rosary. This form of prayerful reflection is of great value, but Christian prayer should go further: to the knowledge of the love of the Lord Jesus, to union with him.",
    references: ["Luke 10:38–42", "Luke 24:13–35", "John 15:1–11"],
    catechism: "CCC 2708",
    url: base + "part_four/section_one/chapter_three/article_1/ii_meditation.html",
    reflection: "",
  },
]
export const getTeaching = (id: string | undefined) => TEACHINGS.find((item) => item.id === id)
