export type Teaching = {
  id: string
  title: string
  subtitle: string
  summary: string
  references: string[]
  catechism: string
  url: string
  reflection: string
  artwork: "mary" | "prayer" | "scripture" | "eucharist" | "confession"
}
const base = "https://www.vatican.va/content/catechism/en/"
export const TEACHINGS: Teaching[] = [
  {
    id: "eucharist",
    title: "The Eucharist",
    subtitle: "Christ gives himself to us",
    artwork: "eucharist",
    summary:
      "Catholics place the Eucharist at the center of the Church’s life. In the celebration of Mass, we receive Christ’s gift of himself and are drawn into communion with him and with one another. Reading the accounts of the Last Supper helps us approach this gift with gratitude.",
    references: ["Luke 22:14–20", "John 6:51–58", "1 Corinthians 11:23–26"],
    catechism: "CCC 1324–1327",
    url:
      base +
      "part_two/section_two/chapter_one/article_3/i_the_eucharist_source_and_summit_of_ecclesial_life.index.html",
    reflection: "How might I prepare more attentively for the next Mass I attend?",
  },
  {
    id: "forgiveness",
    title: "Forgiveness & reconciliation",
    subtitle: "Return to the Father’s mercy",
    artwork: "confession",
    summary:
      "Forgiveness begins with God’s mercy. Jesus forgives sins and entrusts a ministry of reconciliation to his apostles. In the sacrament of Penance, Catholics confess their sins and receive absolution through a priest. The return of the prodigal son offers a picture of a welcome we do not have to earn.",
    references: ["Luke 15:11–32", "John 20:19–23", "Matthew 18:21–35"],
    catechism: "CCC 1440–1445",
    url:
      base +
      "part_two/section_two/chapter_two/article_4/vi_the_sacrament_of_penance_and_reconciliation.html",
    reflection: "Where do I need to receive mercy, and where am I being invited to extend it?",
  },
  {
    id: "mary",
    title: "Mary & discipleship",
    subtitle: "Learn to say yes to God",
    artwork: "mary",
    summary:
      "Mary’s trust points us toward her Son. Catholics honor her as the Mother of God and ask for her intercession. This honor is distinct from the adoration given to God alone. Her response at the Annunciation and her words at Cana invite us to listen to Jesus and follow him.",
    references: ["Luke 1:26–38", "Luke 1:46–55", "John 2:1–11"],
    catechism: "CCC 969–971",
    url:
      base +
      "part_one/section_two/chapter_three/article_9/paragraph_6_mary_-_mother_of_christ%2C_mother_of_the_church.html",
    reflection: "What would a small, concrete yes to God look like today?",
  },
  {
    id: "suffering",
    title: "Hope in suffering",
    subtitle: "Christ draws near to our pain",
    artwork: "prayer",
    summary:
      "The Gospels show Jesus meeting illness and suffering with compassion. His healings reveal the coming of God’s Kingdom, and in his Passion he enters human suffering himself. Christian hope allows us to bring pain honestly to God and to accompany others with prayer and practical care.",
    references: ["Mark 1:40–45", "Matthew 11:28–30", "Romans 8:35–39"],
    catechism: "CCC 1503–1505",
    url:
      base +
      "part_two/section_two/chapter_two/article_5/i_its_foundations_in_the_economy_of_salvation.html",
    reflection: "Who could I accompany with a call, a meal, a visit, or a prayer?",
  },
  {
    id: "prayer",
    title: "Praying with Scripture",
    subtitle: "Let reading become a conversation",
    artwork: "scripture",
    summary:
      "Christian meditation helps us attend to God and respond with our whole lives. Scripture is a natural place to begin: read slowly, notice what draws your attention, and speak honestly to God. Lectio divina and the Rosary both turn our attention toward the mysteries of Christ.",
    references: ["Luke 10:38–42", "Luke 24:13–35", "John 15:1–11"],
    catechism: "CCC 2705–2708",
    url: base + "part_four/section_one/chapter_three/article_1/ii_meditation.html",
    reflection: "Which word or moment in this passage stays with me?",
  },
]
export const getTeaching = (id: string | undefined) => TEACHINGS.find((item) => item.id === id)
