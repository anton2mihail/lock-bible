package com.john.bible.data

import org.json.JSONObject
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.time.temporal.TemporalAdjusters

/**
 * Advent (Android 1.2.0, matching iOS 2.2.0 AdventCalendar.swift): which week it is, and the O Antiphon of
 * 17–23 December. The antiphons are quoted, Latin and English, from Dom Prosper Guéranger, The Liturgical
 * Year: Advent (Dublin, 1870), public domain.
 */
object AdventCalendar {
    data class Antiphon(val day: Int, val title: String, val latin: String, val english: String)

    const val SOURCE = "Dom Prosper Guéranger, The Liturgical Year: Advent (Dublin, 1870)"

    val antiphons = listOf(
        Antiphon(17, "O Wisdom",
            "O Sapientia, quae ex ore Altissimi prodiisti, attingens a fine usque ad finem, fortiter suaviterque disponens omnia: veni ad docendum nos viam prudentiae.",
            "O Wisdom, that proceedest from the mouth of the Most High, reaching from end to end, disposing all things with strength and sweetness! come and teach us the way of prudence."),
        Antiphon(18, "O Adonai",
            "O Adonai, et dux domus Israel, qui Moysi in igne flammae rubi apparuisti, et ei in Sina legem dedisti: veni ad redimendum nos in brachio extento.",
            "O Adonai, and leader of the house of Israel, who appearedst to Moses in the fire of the flaming bush, and gavest him the law on Sinai: come and redeem us by thy outstretched arm."),
        Antiphon(19, "O Root of Jesse",
            "O Radix Jesse, qui stas in signum populorum, super quem continebunt reges os suum, quem gentes deprecabuntur: veni ad liberandum nos, jam noli tardare.",
            "O Root of Jesse, who standest as the standard of the people; before whom kings shall not open their lips; to whom the nations shall pray: come and deliver us; tarry now no more."),
        Antiphon(20, "O Key of David",
            "O Clavis David, et sceptrum domus Israel; qui aperis, et nemo claudit; claudis, et nemo aperit: veni, et educ vinctum de domo carceris, sedentem in tenebris, et umbra mortis.",
            "O Key of David, and Sceptre of the house of Israel! who openest, and no man shutteth; who shuttest, and no man openeth: come and lead the captive from prison, sitting in darkness and in the shadow of death."),
        Antiphon(21, "O Orient",
            "O Oriens, splendor lucis aeternae, et sol justitiae: veni, et illumina sedentes in tenebris, et umbra mortis.",
            "O Orient! splendour of eternal light, and Sun of Justice! come and enlighten them that sit in darkness, and in the shadow of death."),
        Antiphon(22, "O King of Nations",
            "O Rex gentium, et desideratus earum, lapisque angularis, qui facis utraque unum: veni, et salva hominem, quem de limo formasti.",
            "O King of nations, and their Desired One, and the Corner-Stone that makest both one: come and save man, whom thou formedst out of slime."),
        Antiphon(23, "O Emmanuel",
            "O Emmanuel, Rex et legifer noster, exspectatio gentium, et salvator earum: veni ad salvandum nos, Domine Deus noster.",
            "O Emmanuel, our King and Lawgiver, the Expectation and Saviour of the nations! come and save us, O Lord our God!"),
    )

    /** The Advent wreath: the Collect of each Sunday of Advent, as printed in The Missal (1926 printing), pp. 50, 54, 56, 69. */
    const val COLLECT_SOURCE = "The Missal, compiled by lawful authority from the Missale Romanum (Burns Oates; B. Herder, 1926 printing; Imprimatur Westminster, 1921)"
    val sundayCollects = listOf(
        "Stir up thy might, O Lord, we beseech thee, and come; that by thy protection we may deserve to be rescued from the threatening dangers of our sins and saved by thy deliverance: who livest and reignest with God the Father in the unity of the Holy Ghost, God, world without end. Amen.",
        "Stir up our hearts, O Lord, to prepare the ways of thine only-begotten Son; that through his coming we may be worthy to serve thee with purified minds: who liveth.",
        "Incline thine ear, O Lord, we beseech thee, to our prayers; and enlighten the darkness of our mind by the grace of thy visitation: who livest.",
        "Stir up, O Lord, we pray thee, thy power, and come, and with great might succour us; that, by the help of thy grace, that which our sins impede may be hastened by thy merciful forgiveness: who livest and reignest with God the Father.",
    )

    /** The Collect for the week of Advent containing [date], else null. */
    fun collect(date: LocalDate): String? = week(date)?.let { sundayCollects[it - 1] }

    /** The first Sunday of Advent of [year]: the fourth Sunday before Christmas. */
    fun firstSunday(year: Int): LocalDate =
        LocalDate.of(year, 12, 25).with(TemporalAdjusters.previous(DayOfWeek.SUNDAY)).minusWeeks(3)

    /** The week of Advent (1..4) on [date], or null outside Advent (Advent ends on 24 December). */
    fun week(date: LocalDate): Int? {
        if (date.monthValue == 12 && date.dayOfMonth > 24) return null
        val days = ChronoUnit.DAYS.between(firstSunday(date.year), date)
        if (days < 0) return null
        return minOf(days / 7 + 1, 4).toInt()
    }

    /** The O Antiphon for [date] (17–23 December), else null. */
    fun antiphon(date: LocalDate): Antiphon? =
        if (date.monthValue != 12) null else antiphons.firstOrNull { it.day == date.dayOfMonth }
}

/**
 * "The Fathers on today's Gospel" (matching iOS GospelFathers.swift): find the commentary for a day's Gospel and
 * make a short excerpt. The Catena Aurea (Matthew, Mark) is verse by verse, so its entries carry fromVerse/toVerse;
 * other Fathers are indexed by chapter only and are the fallback for Luke and John.
 */
object GospelFathers {
    data class Reference(val bookCode: String, val chapter: Int, val verse: Int)
    data class Excerpt(val father: String, val text: String)

    private val books = mapOf("Matthew" to "MAT", "Mark" to "MRK", "Luke" to "LUK", "John" to "JHN")
    private val pattern = Regex("""^\s*(Matthew|Mark|Luke|John)\s+(\d+)\s*:\s*(\d+)""")

    /** The last reading labelled "Gospel..." (Palm Sunday has two; the Mass Gospel is last). */
    fun gospelReference(entry: JSONObject?): String? {
        val readings = entry?.optJSONArray("readings") ?: return null
        return (0 until readings.length()).mapNotNull { readings.optJSONObject(it) }
            .lastOrNull { it.optString("label").lowercase().startsWith("gospel") }?.optString("reference")
    }

    fun parse(reference: String): Reference? {
        val match = pattern.find(reference.replace(' ', ' ')) ?: return null
        val code = books[match.groupValues[1]] ?: return null
        val chapter = match.groupValues[2].toIntOrNull() ?: return null
        val verse = match.groupValues[3].toIntOrNull() ?: return null
        if (chapter <= 0 || verse <= 0) return null
        return Reference(code, chapter, verse)
    }

    /** The Catena section that contains the verse; the one that starts closest before it; any other Father on the chapter. */
    fun entry(reference: Reference, entries: List<JSONObject>): JSONObject? {
        if (entries.isEmpty()) return null
        val ranged = entries.filter { it.has("fromVerse") && it.has("toVerse") }
            .sortedWith(compareBy({ it.optInt("fromVerse") }, { it.optInt("sectionIndex") }))
        ranged.firstOrNull { it.optInt("fromVerse") <= reference.verse && reference.verse <= it.optInt("toVerse") }?.let { return it }
        ranged.lastOrNull { it.optInt("fromVerse") <= reference.verse }?.let { return it }
        return ranged.firstOrNull() ?: entries.first()
    }

    private val fathers = mapOf(
        "aug" to "St Augustine", "augustine" to "St Augustine", "chrys" to "St John Chrysostom", "chrysostom" to "St John Chrysostom",
        "pseudo-chrys" to "Pseudo-Chrysostom", "greg" to "St Gregory the Great", "gregory" to "St Gregory the Great",
        "hil" to "St Hilary", "hilary" to "St Hilary", "jerome" to "St Jerome", "hier" to "St Jerome", "bede" to "St Bede",
        "ambrose" to "St Ambrose", "amb" to "St Ambrose", "raban" to "Rabanus Maurus", "rabanus" to "Rabanus Maurus",
        "remig" to "Remigius", "remigius" to "Remigius", "theophyl" to "Theophylact", "theophylact" to "Theophylact",
        "gloss" to "The Gloss", "orig" to "Origen", "origen" to "Origen", "cyril" to "St Cyril", "leo" to "St Leo the Great",
        "athan" to "St Athanasius", "basil" to "St Basil", "isidore" to "St Isidore", "anselm" to "St Anselm", "alcuin" to "Alcuin",
        "pseudo-jerome" to "Pseudo-Jerome", "victor" to "Victor of Antioch", "severianus" to "Severian", "dionysius" to "Dionysius",
        "euseb" to "Eusebius", "eusebius" to "Eusebius", "cyprian" to "St Cyprian", "pseudo-origen" to "Pseudo-Origen",
        "chrysostomus" to "St John Chrysostom", "chyrs" to "St John Chrysostom", "hilarius" to "St Hilary", "beda" to "St Bede",
        "origenes" to "Origen", "athanasius" to "St Athanasius", "titus" to "Titus of Bostra", "maxim" to "St Maximus",
        "maximus" to "St Maximus", "max" to "St Maximus", "damascene" to "St John Damascene", "damas" to "St John Damascene",
        "epiphan" to "St Epiphanius", "didymus" to "Didymus", "haymo" to "Haymo", "pseudo-aug" to "Pseudo-Augustine",
        "pseudo-basil" to "Pseudo-Basil", "greek" to ANONYMOUS_GREEK,
    )
    /** "Greek Ex." in the Catena: an unnamed Greek commentator. */
    const val ANONYMOUS_GREEK = "A Greek commentator"

    /** One comment from a Catena section (paragraph 0 is the Gospel text), preferring a named Father over the Gloss, the anonymous Greek commentator and Pseudo- works. */
    fun excerpt(paragraphs: List<String>, limit: Int = 360): Excerpt? {
        if (paragraphs.size < 2) return null
        val candidates = paragraphs.drop(1).mapNotNull { split(it) }
        val chosen = candidates.firstOrNull { it.third && !it.first.startsWith("Pseudo") && it.first != "The Gloss" && it.first != ANONYMOUS_GREEK } ?: candidates.firstOrNull() ?: return null
        return Excerpt(chosen.first, cut(chosen.second, limit))
    }

    private fun split(comment: String): Triple<String, String, Boolean>? {
        var father = "The Fathers"; var body = comment; var named = false
        val colon = comment.indexOf(':')
        if (colon in 0..60) {
            val label = comment.substring(0, colon)
            val head = label.split(',', ' ').firstOrNull { it.isNotEmpty() } ?: label
            val key = head.lowercase().trim('.').trim()
            fathers[key]?.let { father = it; body = comment.substring(colon + 1); named = true }
        }
        body = body.trim()
        return if (body.isEmpty()) null else Triple(father, body, named)
    }

    fun cut(text: String, limit: Int): String {
        if (text.length <= limit) return text
        val window = text.take(limit)
        val end = window.indexOfLast { it in ".;?!" }
        if (end >= limit / 3) return window.substring(0, end + 1)
        return window.split(' ').dropLast(1).joinToString(" ") + "…"
    }
}

/** Debug builds only: `--es johnFeatureDate 2026-12-05` sets the day that Today and Advent show, as iOS -L14FeatureDate. */
object FeatureClock {
    var date: LocalDate? = null
    fun today(): LocalDate = date ?: LocalDate.now()
}
