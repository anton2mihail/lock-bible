import type { Novena } from "./padrePioNovena"

type TraditionalNovena = Omit<Novena, "opening" | "sections"> & {
  prayer: string
  petition: string
  closing: string
  response: string
}

function createTraditionalNovena({
  prayer,
  petition,
  closing,
  response,
  ...details
}: TraditionalNovena): Novena {
  return {
    ...details,
    opening: "In the name of the Father, and of the Son, and of the Holy Spirit. Amen.",
    sections: [
      { title: "Prayer", paragraphs: [prayer] },
      { title: "For this intention", paragraphs: [petition] },
      { title: "Closing prayer", paragraphs: [closing], response },
    ],
  }
}

export const expandedNovenas: Novena[] = [
  createTraditionalNovena({
    id: "sacred-heart",
    title: "Sacred Heart of Jesus Novena",
    subtitle: "For deeper trust in the faithful and merciful love of Christ",
    about:
      "Devotion to the Sacred Heart contemplates the human heart of Jesus as the sign of his divine love for every person. St. Margaret Mary Alacoque helped spread this devotion, with its call to trust, reparation, and generous love.",
    patronage: "Trust, reparation, family needs, conversion, and perseverance",
    traditionalStart: "Nine days before the solemnity",
    feastDay: "Sacred Heart solemnity",
    sourceName: "EWTN",
    sourceUrl: "https://www.ewtn.com/catholicism/library/novena-to-the-sacred-heart-of-jesus-11890",
    searchTerms: ["Jesus", "Sacred Heart", "trust", "mercy", "reparation", "First Friday"],
    prayer:
      "Lord Jesus Christ, gentle and humble of heart, draw me close to the love that moved you to become human, to heal the suffering, and to give your life for the world. Make my heart more like yours: patient, faithful, and ready to love without counting the cost.",
    petition:
      "Sacred Heart of Jesus, I place this intention within your merciful care. Grant what will lead me and those I love toward holiness, and give me peace when your answer unfolds differently from my hope.",
    closing:
      "Receive my prayers, work, joys, and suffering. Unite them to your perfect offering to the Father, for the good of the Church and the needs of the whole world.",
    response: "Sacred Heart of Jesus, I trust in You. Amen.",
  }),
  createTraditionalNovena({
    id: "holy-spirit",
    title: "Holy Spirit Novena",
    subtitle: "For the seven gifts and a renewed life in God",
    about:
      "The first Christian novena recalls the nine days of prayer between the Ascension and Pentecost, when Mary and the apostles awaited the promised Spirit. It asks for wisdom, understanding, counsel, fortitude, knowledge, piety, and fear of the Lord.",
    patronage: "Discernment, courage, wisdom, vocation, and renewal",
    traditionalStart: "Friday after Ascension",
    feastDay: "Pentecost",
    sourceName: "EWTN",
    sourceUrl:
      "https://www.ewtn.com/catholicism/library/novena-to-the-holy-ghost-for-the-seven-gifts-9112",
    searchTerms: ["Pentecost", "seven gifts", "discernment", "wisdom", "vocation", "courage"],
    prayer:
      "Come, Holy Spirit, Lord and giver of life. Enlighten my mind, strengthen my will, and kindle in me the fire of divine love. Remove whatever resists your grace and make my heart a willing dwelling place for you.",
    petition:
      "Give me wisdom and understanding, right judgment and courage, knowledge and reverence, and wonder before God. Guide this intention according to the Father’s will and teach me how to act with charity.",
    closing:
      "As you descended upon Mary and the apostles, renew your Church and renew me. Send me to bear the peace and truth of Christ wherever I am called.",
    response: "Come, Holy Spirit, and renew the face of the earth. Amen.",
  }),
  createTraditionalNovena({
    id: "divine-mercy",
    title: "Divine Mercy Novena",
    subtitle: "For sinners, the suffering, and complete trust in God’s mercy",
    about:
      "St. Faustina Kowalska recorded a nine-day devotion preparing for Divine Mercy Sunday. Each day brings people and their needs before the merciful Heart of Jesus and rests in the saving power of his Passion and Resurrection.",
    patronage: "Mercy, forgiveness, conversion, the dying, and souls in purgatory",
    traditionalStart: "Good Friday",
    feastDay: "Divine Mercy Sunday",
    sourceName: "EWTN Divine Mercy Novena",
    sourceUrl: "https://www.ewtn.com/catholicism/library/divine-mercy-novena-9119",
    searchTerms: ["Faustina", "mercy", "forgiveness", "dying", "purgatory", "Easter"],
    prayer:
      "Most merciful Jesus, your love is greater than every sin and your compassion is never exhausted. Draw sinners, the suffering, the doubtful, and the dying into the shelter of your Heart, and let the grace of your Passion restore their hope.",
    petition:
      "I entrust this need to your mercy. Where there is guilt, grant forgiveness; where there is injury, bring healing; where there is fear, awaken trust; and where there is despair, reveal the light of your Resurrection.",
    closing:
      "Eternal Father, look with mercy upon us through the wounds of your beloved Son. For the sake of his sorrowful Passion, have mercy on us and on the whole world.",
    response: "Jesus, I trust in You. Amen.",
  }),
  createTraditionalNovena({
    id: "miraculous-medal",
    title: "Miraculous Medal Novena",
    subtitle: "For Mary’s protection and a heart made ready for Christ",
    about:
      "The Miraculous Medal devotion arose from the 1830 apparitions to St. Catherine Labouré in Paris. Its image proclaims Mary’s Immaculate Conception, her maternal prayer, and the graces God gives through confident faith.",
    patronage: "Protection, conversion, healing, and confidence in Mary’s intercession",
    traditionalStart: "November 18",
    feastDay: "November 27",
    sourceName: "EWTN",
    sourceUrl: "https://www.ewtn.com/catholicism/library/miraculous-medal-novena-9129",
    searchTerms: ["Catherine Laboure", "medal", "Paris", "conversion", "protection", "Mary"],
    prayer:
      "O Mary, conceived without sin, Mother of Jesus and our mother, receive me beneath your protection. Help me reject sin, follow your Son faithfully, and welcome the graces he desires to give.",
    petition:
      "Present this intention to Jesus. Ask that my need be answered in the way that most serves God’s glory, and give me the faith to recognize grace in ordinary moments as well as extraordinary ones.",
    closing:
      "Immaculate Mother, form in me a humble and generous heart. May the sign of your medal remind me to live every day in the light of Christ.",
    response: "O Mary, conceived without sin, pray for us who have recourse to you. Amen.",
  }),
  createTraditionalNovena({
    id: "immaculate-conception",
    title: "Immaculate Conception Novena",
    subtitle: "For purity of heart, conversion, and freedom from sin",
    about:
      "The Immaculate Conception celebrates that Mary, through the merits of Christ, was preserved from original sin from the first moment of her life. Her complete openness to grace offers the Church a radiant image of redeemed humanity.",
    patronage: "Purity, new beginnings, conversion, and the United States",
    traditionalStart: "November 29",
    feastDay: "December 8",
    sourceName: "EWTN Marian Feastday Prayers",
    sourceUrl: "https://www.ewtn.com/catholicism/library/our-ladys-feastdays-5706",
    searchTerms: ["Immaculate", "purity", "sin", "new beginning", "United States", "Mary"],
    prayer:
      "Immaculate Mary, full of grace from the first moment of your life, praise God with me for the saving work of Jesus. Help me turn away from sin quickly and receive the mercy that makes all things new.",
    petition:
      "Mother of the Redeemer, carry this intention to your Son. Obtain for me a clean heart, steadfast faith, and the courage to begin again wherever I have failed.",
    closing:
      "May your yes to God shape my choices. Lead me into deeper friendship with Jesus and teach me to serve him with undivided love.",
    response: "Mary conceived without sin, pray for us. Amen.",
  }),
  createTraditionalNovena({
    id: "our-lady-lourdes",
    title: "Our Lady of Lourdes Novena",
    subtitle: "For healing, conversion, and hope in suffering",
    about:
      "In 1858 Mary appeared to St. Bernadette Soubirous at Lourdes, calling people to prayer and conversion. The sanctuary remains a place of pilgrimage where the sick and those who care for them are held close in prayer.",
    patronage: "The sick, caregivers, healing, disability, and conversion",
    traditionalStart: "February 2",
    feastDay: "February 11",
    sourceName: "Diocesan Shrine of Our Lady of Lourdes",
    sourceUrl: "https://santuariodelourdes.com.br/novena/",
    searchTerms: ["Bernadette", "Lourdes", "sick", "caregiver", "healing", "disability"],
    prayer:
      "Our Lady of Lourdes, you came to the humble grotto to call God’s children back to the Gospel. Stand beside all who are ill, lonely, exhausted, or afraid, and lead us to the healing presence of Jesus.",
    petition:
      "I place this need in your motherly hands. Ask for healing of body, mind, memory, and spirit, and for the grace to carry every cross with faith when healing is not immediate.",
    closing:
      "Help me imitate St. Bernadette’s simplicity and perseverance. Make me attentive to the sick and ready to become an instrument of Christ’s compassion.",
    response: "Our Lady of Lourdes, pray for us. Amen.",
  }),
  createTraditionalNovena({
    id: "our-lady-fatima",
    title: "Our Lady of Fatima Novena",
    subtitle: "For peace, conversion, and reparation",
    about:
      "At Fatima in 1917, Mary asked three shepherd children to pray the Rosary, offer sacrifices for sinners, and seek peace through conversion. The devotion directs every act of reparation toward the mercy of God.",
    patronage: "Peace, conversion of sinners, families, and perseverance in prayer",
    traditionalStart: "May 4",
    feastDay: "May 13",
    sourceName: "Shrine of Fatima",
    sourceUrl: "https://www.santuario-fatima.pt/en/pages/fatima-prayers",
    searchTerms: ["Fatima", "Lucia", "Francisco", "Jacinta", "Rosary", "peace", "reparation"],
    prayer:
      "Our Lady of Fatima, teach me to believe, adore, hope, and love God more deeply. Obtain peace for the world, conversion for sinners, and consolation for hearts wounded by violence and division.",
    petition:
      "Receive this intention and join it to the prayers of all who seek peace. Help me offer the duties and difficulties of today with love rather than resentment.",
    closing:
      "Lead me to Jesus in the Eucharist and make my prayer fruitful in works of mercy. May the Immaculate Heart of Mary guide me toward the triumph of Christ’s peace.",
    response: "Our Lady of Fatima, pray for us. Amen.",
  }),
  createTraditionalNovena({
    id: "our-lady-guadalupe",
    title: "Our Lady of Guadalupe Novena",
    subtitle: "For the Americas, families, and the protection of human life",
    about:
      "Our Lady appeared to St. Juan Diego at Tepeyac in 1531 and left her image on his tilma. Honored as Mother of the Americas, she draws nations and cultures toward Christ with tenderness and respect for every human life.",
    patronage: "The Americas, unborn children, families, migrants, and evangelization",
    traditionalStart: "December 3",
    feastDay: "December 12",
    sourceName: "United States Conference of Catholic Bishops",
    sourceUrl: "https://www.usccb.org/resources/prayer-our-lady-guadalupe",
    searchTerms: ["Guadalupe", "Juan Diego", "Mexico", "Americas", "unborn", "pro life", "migrant"],
    prayer:
      "Our Lady of Guadalupe, Mother of the true God and Mother of the Church, hold the peoples of the Americas in your loving care. Unite us across every boundary and lead our homes and communities to Jesus.",
    petition:
      "Intercede for this intention and for every life that is vulnerable, forgotten, displaced, or afraid. Teach us to defend human dignity with courage, gentleness, and practical love.",
    closing:
      "As you reassured St. Juan Diego, remind me that I am never outside a mother’s care. Help me carry Christ into the world with humility and joy.",
    response: "Our Lady of Guadalupe, pray for us. Amen.",
  }),
  createTraditionalNovena({
    id: "assumption",
    title: "Assumption of Mary Novena",
    subtitle: "For hope in the resurrection and fidelity to the end",
    about:
      "The Assumption celebrates that Mary, at the completion of her earthly life, was taken body and soul into heavenly glory. Her destiny reveals the hope promised to the whole Church through the Resurrection of Christ.",
    patronage: "Hope, a holy death, perseverance, and trust in eternal life",
    traditionalStart: "August 6",
    feastDay: "August 15",
    sourceName: "EWTN Marian Feastday Prayers",
    sourceUrl: "https://www.ewtn.com/catholicism/library/our-ladys-feastdays-5706",
    searchTerms: ["Assumption", "heaven", "resurrection", "holy death", "eternal life", "Mary"],
    prayer:
      "Mary, assumed into heaven, praise the risen Christ with us. When suffering or death makes hope feel distant, remind me that God intends to redeem the whole person and bring his faithful children home.",
    petition:
      "Present this intention before your Son. Help me live today in the light of eternity, faithful in small duties and free from attachments that draw my heart away from God.",
    closing:
      "Mother of hope, accompany the dying and console those who mourn. Lead us to the joy of the resurrection and the communion of saints.",
    response: "Mary, Queen assumed into heaven, pray for us. Amen.",
  }),
  createTraditionalNovena({
    id: "st-anthony",
    title: "St. Anthony of Padua Novena",
    subtitle: "For what is lost and for help in every difficulty",
    about:
      "St. Anthony was a Franciscan priest, gifted preacher, and Doctor of the Church. Catholics invoke the “Wonder Worker” not only for lost objects, but also for lost faith, hope, peace, and direction.",
    patronage: "Lost things, the poor, travelers, seekers, and difficult needs",
    traditionalStart: "June 4",
    feastDay: "June 13",
    sourceName: "National Shrine of St. Anthony",
    sourceUrl: "https://www.stanthony.org/st-anthony-novena-prayer/",
    searchTerms: ["Anthony", "lost", "missing", "poor", "Franciscan", "traveler", "Wonder Worker"],
    prayer:
      "St. Anthony, faithful preacher of the Gospel and friend of the poor, you helped people recover what was lost and discover the greater treasure of Christ. Pray that I may seek first the kingdom of God.",
    petition:
      "Intercede for what I have lost and for the need I now name. If it should not be restored, obtain for me new hope, wisdom, and the peace to trust God’s providence.",
    closing:
      "Help me recognize Jesus in the poor and suffering. May every favor received make me more generous, grateful, and faithful to the Gospel.",
    response: "St. Anthony of Padua, pray for us. Amen.",
  }),
  createTraditionalNovena({
    id: "st-anne",
    title: "St. Anne Novena",
    subtitle: "For mothers, grandparents, marriage, and family life",
    about:
      "Ancient Christian tradition names St. Anne and St. Joachim as the parents of the Virgin Mary. Their patient hope and care for Mary make Anne a beloved intercessor for parents, grandparents, married couples, and those longing for a child.",
    patronage: "Mothers, grandparents, marriage, pregnancy, infertility, and homemakers",
    traditionalStart: "July 17",
    feastDay: "July 26",
    sourceName: "EWTN Lives of Saints",
    sourceUrl: "https://www.ewtn.com/catholicism/library/st-anne-mother-of-the-blessed-virgin-5188",
    searchTerms: [
      "Anne",
      "Joachim",
      "mother",
      "grandmother",
      "marriage",
      "pregnancy",
      "infertility",
    ],
    prayer:
      "St. Anne, mother of Mary and grandmother of Jesus, your home helped prepare the way for the Savior. Pray for families, especially those carrying hidden grief, waiting for children, or struggling to love one another well.",
    petition:
      "Bring this family need before God. Obtain patience in waiting, tenderness in conflict, wisdom in parenting, and healing wherever disappointment has taken root.",
    closing:
      "Teach me to make my home a place where faith can grow. With St. Joachim and the Blessed Mother, lead every generation of my family closer to Christ.",
    response: "St. Anne and St. Joachim, pray for us. Amen.",
  }),
  createTraditionalNovena({
    id: "st-rita",
    title: "St. Rita of Cascia Novena",
    subtitle: "For impossible situations, wounded marriages, and forgiveness",
    about:
      "St. Rita lived the vocations of wife, mother, widow, and Augustinian nun. Her perseverance through violence, loss, and suffering—without surrendering forgiveness—made her a powerful patron for situations that seem impossible.",
    patronage: "Impossible causes, troubled marriages, abuse survivors, forgiveness, and widows",
    traditionalStart: "May 13",
    feastDay: "May 22",
    sourceName: "National Shrine of Saint Rita of Cascia",
    sourceUrl: "https://www.saintritashrine.org/novena-prayers",
    searchTerms: ["Rita", "impossible", "marriage", "forgiveness", "widow", "abuse", "rose"],
    prayer:
      "St. Rita, steadfast disciple of the crucified Christ, you chose forgiveness in circumstances filled with pain. Pray for all who feel trapped in conflict, grief, danger, or a problem beyond human skill.",
    petition:
      "Intercede for this seemingly impossible need. Ask God to open a safe and truthful path forward, protect everyone in danger, and give me courage to seek wise help as well as grace.",
    closing:
      "Help me forgive without excusing harm, hope without denying reality, and entrust every outcome to God. May Christ’s peace take root where bitterness once lived.",
    response: "St. Rita, advocate of impossible causes, pray for us. Amen.",
  }),
  createTraditionalNovena({
    id: "st-monica",
    title: "St. Monica Novena",
    subtitle: "For the conversion and return of loved ones",
    about:
      "St. Monica prayed for years for her son Augustine and accompanied him with patient love until his conversion. Her witness encourages parents and families to persevere in prayer while respecting the freedom and dignity of those they love.",
    patronage: "Mothers, difficult marriages, wayward children, conversion, and perseverance",
    traditionalStart: "August 18",
    feastDay: "August 27",
    sourceName: "St. Rita’s Centre",
    sourceUrl: "https://www.stritascentre.org/novena-prayer-to-st-monica-and-st-augustine-1",
    searchTerms: [
      "Monica",
      "Augustine",
      "conversion",
      "child",
      "mother",
      "return to faith",
      "family",
    ],
    prayer:
      "St. Monica, faithful mother and tireless intercessor, you trusted God through long years when you could not see the answer to your prayers. Stand beside all who grieve for a loved one far from faith or family.",
    petition:
      "Pray for the person and intention I carry today. Obtain grace for conversion, reconciliation, freedom from addiction, and the healing of relationships, always without coercion or fear.",
    closing:
      "Teach me patient love, wise boundaries, and confidence in God’s timing. Keep my own heart close to Christ while I wait and pray for others.",
    response: "St. Monica and St. Augustine, pray for us. Amen.",
  }),
  createTraditionalNovena({
    id: "st-michael",
    title: "St. Michael the Archangel Novena",
    subtitle: "For protection, courage, and strength in spiritual battle",
    about:
      "Scripture presents Michael as the great defender of God’s people. The Church invokes him for protection against evil and for courage to remain faithful to Christ in temptation, danger, and spiritual struggle.",
    patronage: "The Church, police, soldiers, first responders, protection, and spiritual warfare",
    traditionalStart: "September 20",
    feastDay: "September 29",
    sourceName: "EWTN",
    sourceUrl: "https://www.ewtn.com/catholicism/devotions/prayer-to-st-michael-the-archangel-371",
    searchTerms: ["Michael", "archangel", "protection", "evil", "temptation", "police", "soldier"],
    prayer:
      "St. Michael the Archangel, defender of God’s people, stand with us in every struggle against sin, deception, and despair. By God’s power, guard the Church and protect all who face danger in body or soul.",
    petition:
      "Carry this need before the throne of God. Obtain courage to reject evil, clarity to recognize temptation, and humility to rely on grace rather than fear or my own strength.",
    closing:
      "Prince of the heavenly host, guide us safely toward Christ. May God rebuke every power that seeks the ruin of souls and establish his peace within us.",
    response: "St. Michael the Archangel, defend us in battle. Amen.",
  }),
  createTraditionalNovena({
    id: "st-benedict",
    title: "St. Benedict Novena",
    subtitle: "For peace, disciplined prayer, and protection from evil",
    about:
      "St. Benedict of Nursia shaped Western monastic life through a rule centered on prayer, work, stability, and listening to God. His medal and blessing are cherished reminders that the Cross of Christ is our light.",
    patronage: "Monastics, students, Europe, protection, peaceful homes, and a holy death",
    traditionalStart: "July 2",
    feastDay: "July 11",
    sourceName: "Benedictine Confederation",
    sourceUrl: "https://www.osb.org/the-benedictine-order/the-benedictine-confederation/",
    searchTerms: ["Benedict", "monk", "medal", "protection", "prayer", "work", "peace", "Europe"],
    prayer:
      "St. Benedict, father of monks and teacher of those who seek God, help me listen with the ear of the heart. Bring order to what is scattered in my life and teach me to find Christ in prayer, work, and community.",
    petition:
      "Intercede for this need and for peace within my home. Protect us from every influence that leads away from truth, charity, sobriety, or faithful responsibility.",
    closing:
      "May the holy Cross be my light. Help me prefer nothing to the love of Christ and finish each day’s work with gratitude and peace.",
    response: "St. Benedict, pray for us. Amen.",
  }),
  createTraditionalNovena({
    id: "st-francis-assisi",
    title: "St. Francis of Assisi Novena",
    subtitle: "For peace, simplicity, care for creation, and love of the poor",
    about:
      "St. Francis embraced poverty to follow the crucified Christ with an undivided heart. His love of the Eucharist, the poor, creation, and peace continues to call Christians toward joyful simplicity and fraternity.",
    patronage: "Animals, ecology, merchants, the poor, peace, and Franciscan vocations",
    traditionalStart: "September 25",
    feastDay: "October 4",
    sourceName: "Friars of St. Francis",
    sourceUrl:
      "https://www.friarsofstfrancis.org/wp-content/uploads/2025/09/Novena-in-Honour-of-St-Francis-of-Assisi.pdf",
    searchTerms: [
      "Francis",
      "Assisi",
      "animal",
      "creation",
      "environment",
      "poor",
      "peace",
      "Franciscan",
    ],
    prayer:
      "St. Francis, joyful brother of the poor and friend of creation, you saw every good gift as a path of praise. Help me follow Jesus simply, reverence the Eucharist, and meet suffering with generous love.",
    petition:
      "Pray for this intention and for peace wherever creation or human dignity is wounded. Show me one concrete way to serve, reconcile, share, or care for our common home.",
    closing:
      "Free me from possessions that possess me and from pride that divides me from others. Make me an instrument of the peace of Christ.",
    response: "St. Francis of Assisi, pray for us. Amen.",
  }),
  createTraditionalNovena({
    id: "st-dymphna",
    title: "St. Dymphna Novena",
    subtitle: "For mental health, emotional distress, and compassionate care",
    about:
      "St. Dymphna is honored as a patron of people living with mental and neurological illness and of those who care for them. Her shrine recalls the Christian duty to replace stigma and isolation with safety, community, and skilled care.",
    patronage: "Mental health, neurological illness, abuse survivors, therapists, and caregivers",
    traditionalStart: "May 6",
    feastDay: "May 15",
    sourceName: "National Shrine of St. Dymphna",
    sourceUrl: "https://www.natlshrinestdymphna.org/site/wp-content/uploads/2014/01/novena2.pdf",
    searchTerms: [
      "Dymphna",
      "mental health",
      "anxiety",
      "depression",
      "trauma",
      "therapist",
      "neurological",
    ],
    prayer:
      "St. Dymphna, faithful witness in danger and distress, pray for everyone living with anxiety, depression, trauma, addiction, or neurological illness. May they be treated with dignity and surrounded by patient, informed care.",
    petition:
      "Intercede for this mental or emotional need. Ask Jesus for safety, effective treatment, trustworthy companions, and the courage to seek professional help when it is needed.",
    closing:
      "Pray also for families, clinicians, clergy, and communities who accompany those who suffer. Help us end stigma and build places of belonging and hope.",
    response: "St. Dymphna, patron of mental health, pray for us. Amen.",
  }),
  createTraditionalNovena({
    id: "holy-souls",
    title: "Holy Souls Novena",
    subtitle: "For the faithful departed and souls undergoing purification",
    about:
      "From the earliest centuries, Christians have prayed for the dead. The Church teaches that our prayers, especially the Mass, can assist those being purified as they journey toward the full joy of heaven.",
    patronage: "The faithful departed, grieving families, forgotten souls, and a holy death",
    traditionalStart: "October 24",
    feastDay: "November 2",
    sourceName: "EWTN",
    sourceUrl: "https://www.ewtn.com/catholicism/library/padre-pio-and-the-poor-souls-13855",
    searchTerms: ["dead", "departed", "purgatory", "grief", "mourning", "funeral", "souls"],
    prayer:
      "Merciful Father, receive the faithful departed into the light of your presence. Purify every soul who died in your friendship, console those who mourn, and remember especially those who have no one to pray for them.",
    petition:
      "I offer this prayer for the people I name in my heart and for all the forgotten dead. Apply to them the saving merits of Jesus Christ and hasten the day when they rejoice with the saints.",
    closing:
      "Teach me to live prepared for death, reconciled with you and neighbor. May the hope of resurrection shape my grief and make me faithful in praying for others.",
    response:
      "Eternal rest grant unto them, O Lord, and let perpetual light shine upon them. Amen.",
  }),
  createTraditionalNovena({
    id: "christ-the-king",
    title: "Christ the King Novena",
    subtitle: "For religious freedom, truth, and the reign of Christ in every heart",
    about:
      "The solemnity of Christ the King proclaims that every earthly power is accountable to Jesus, whose kingdom is revealed through truth, mercy, service, and the Cross. This novena asks for courage to live the Gospel in public and private life.",
    patronage: "Religious freedom, public life, unity, justice, and fidelity to the Gospel",
    traditionalStart: "Nine days before the solemnity",
    feastDay: "Christ the King solemnity",
    sourceName: "United States Conference of Catholic Bishops",
    sourceUrl: "https://www.usccb.org/committees/religious-liberty/christ-king-novena",
    searchTerms: ["Christ King", "religious freedom", "politics", "truth", "justice", "government"],
    prayer:
      "Lord Jesus Christ, sovereign King and servant of all, establish your reign in my heart. Free me from fear, pride, and partisan hatred so that my words and choices bear witness to truth joined with charity.",
    petition:
      "I entrust this need and the needs of public life to you. Protect authentic religious freedom, guide leaders toward justice, and keep your Church close to people who are poor, vulnerable, or excluded.",
    closing:
      "By your Holy Spirit, unite us as one family of God. Give us courage to remain friends of the truth and patience to carry one another’s burdens.",
    response: "Christ our King, may Your kingdom come. Amen.",
  }),
  createTraditionalNovena({
    id: "respect-life",
    title: "Respect Life Novena",
    subtitle: "For the protection of every human life from conception to natural death",
    about:
      "This novena joins prayer with practical care for human life at every stage. It holds together unborn children, expectant parents, people with disabilities, migrants, prisoners, the sick, the elderly, and all whose dignity is threatened.",
    patronage:
      "Unborn children, parents, disability, migrants, prisoners, the sick, and the elderly",
    sourceName: "United States Conference of Catholic Bishops",
    sourceUrl: "https://www.usccb.org/respect-life-novena",
    searchTerms: [
      "pro life",
      "unborn",
      "pregnancy",
      "abortion",
      "euthanasia",
      "disability",
      "elderly",
      "dignity",
    ],
    prayer:
      "Father and maker of all, every person is created in your image and loved into being. Protect human life from conception to natural death, and heal the social wounds that make people feel disposable, burdensome, or alone.",
    petition:
      "Receive this intention for human life. Give courage and support to parents in crisis, compassionate care to the sick and dying, welcome to migrants, justice to prisoners, and belonging to people with disabilities.",
    closing:
      "Show me the next work of mercy you are asking of me. Make our parishes and communities places where truth is spoken with love and no one faces fear or hardship alone.",
    response: "Our Lady of Guadalupe, Mother of life, pray for us. Amen.",
  }),
  createTraditionalNovena({
    id: "mental-health",
    title: "Mental Health Novena",
    subtitle: "For healing, accompaniment, and an end to stigma",
    about:
      "The USCCB Mental Health Novena invites the whole Church to pray for people affected by mental illness and for those who accompany them. Prayer belongs alongside—not in place of—professional care, safe communities, and practical support.",
    patronage: "Mental illness, families, clinicians, crisis workers, parishes, and recovery",
    sourceName: "United States Conference of Catholic Bishops",
    sourceUrl: "https://www.usccb.org/mental-health-novena",
    searchTerms: [
      "mental health",
      "anxiety",
      "depression",
      "suicide",
      "stigma",
      "therapy",
      "recovery",
      "crisis",
    ],
    prayer:
      "God of compassion, draw near to everyone affected by mental illness, emotional crisis, addiction, or isolation. Replace shame with dignity, confusion with wise guidance, and loneliness with communities able to listen and remain present.",
    petition:
      "I entrust this person and need to your care. Provide safety, sound treatment, patient support, and hope for the next step. Strengthen clinicians, families, clergy, and crisis workers in their service.",
    closing:
      "Teach your Church to welcome without stigma and to respond to suffering with humility and practical love. Keep us attentive to warning signs and willing to seek urgent help when life is at risk.",
    response: "Jesus, healer of mind and heart, have mercy on us. Amen.",
  }),
]
