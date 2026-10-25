package com.john.bible.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.material3.Text
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.sp
import com.john.bible.data.AdventCalendar
import com.john.bible.data.FeatureClock
import com.john.bible.data.GospelFathers
import com.john.bible.data.JohnRepository
import org.json.JSONObject
import java.time.LocalDate

@Composable private fun Eyebrow(text: String) = Text(text, fontFamily = SpaceGrotesk, fontSize = 11.sp, lineHeight = 18.sp, letterSpacing = 2.sp, color = LocalJohnColors.current.tint)

/** Today's lookup for "The Fathers on today's Gospel" (1.2.0, matching iOS GospelFathersCard). */
private data class GospelFathersCard(val reference: String, val entry: JSONObject, val excerpt: GospelFathers.Excerpt?, val author: String)

private fun gospelFathers(repo: JohnRepository, readings: JSONObject?): GospelFathersCard? {
    val reference = GospelFathers.gospelReference(readings) ?: return null
    val parsed = GospelFathers.parse(reference) ?: return null
    val entry = GospelFathers.entry(parsed, repo.commentary(parsed.bookCode, parsed.chapter)) ?: return null
    val workId = entry.optString("workId").ifBlank { entry.optString("workID") }
    // Today shows one comment from the Catena free of charge; the button opens the section behind the usual gate.
    val excerpt = if (entry.has("fromVerse")) runCatching { GospelFathers.excerpt(repo.workSection(workId, entry.optInt("sectionIndex")).paragraphs) }.getOrNull() else null
    val collection = entry.optString("collectionId").ifBlank { entry.optString("collectionID") }
    val author = repo.workAuthors().firstOrNull { it.id == collection }?.author ?: "The Fathers"
    return GospelFathersCard(reference, entry, excerpt, author)
}

/** One comment from the Catena Aurea, or the Father who preached on the chapter. Nothing when no Father wrote on it. */
@Composable
fun GospelFathersPanel(repo: JohnRepository, readings: JSONObject?, navigate: (String)->Unit, eyebrow: String = "THE FATHERS ON TODAY’S GOSPEL") {
    val card = remember(readings) { gospelFathers(repo, readings) } ?: return
    val workId = card.entry.optString("workId").ifBlank { card.entry.optString("workID") }
    JohnPanel {
        Eyebrow(eyebrow)
        if (card.excerpt != null) {
            Box(Modifier.testTag("today-fathers-excerpt")) { SelectionContainer { JohnText("“${card.excerpt.text}”", serif = true, size = 20) } }
            JohnText("${card.excerpt.father} · Catena Aurea, ${card.entry.optString("sectionTitle")}", dim = true, size = 14)
        } else {
            JohnText("${card.author} on today’s Gospel", serif = true, size = 20)
            JohnText("${card.entry.optString("workTitle")} · ${card.entry.optString("sectionTitle")}", dim = true, size = 14)
        }
        Box(Modifier.testTag("today-fathers-open")) {
            JohnRow("Read the Fathers on this Gospel", card.reference) { navigate("work/$workId/${card.entry.optInt("sectionIndex")}") }
        }
    }
}

/** The Advent row on Today, from the first Sunday of Advent to 24 December; from 17 December it names that evening's O Antiphon. */
@Composable
fun AdventTodayRow(date: LocalDate, navigate: (String)->Unit) {
    val week = AdventCalendar.week(date) ?: return
    val antiphon = AdventCalendar.antiphon(date)
    val ordinal = listOf("First", "Second", "Third", "Fourth")[(week - 1).coerceIn(0, 3)]
    Box(Modifier.testTag("today-advent")) {
        JohnRow(antiphon?.let { "${it.title}: tonight’s O Antiphon" } ?: "Advent with the Fathers",
            "$ordinal week of Advent · The Gospel, the Fathers and the O Antiphons", image = "joyful-1") { navigate("advent") }
    }
}

/** The Advent page (`nrsv://advent`, and the Today row): today's readings, the Gospel with the Fathers, Rorate caeli and the O Antiphons. */
@Composable
fun AdventScreen(repo: JohnRepository, navigate: (String)->Unit, back: ()->Unit) {
    val date = FeatureClock.today()
    val week = AdventCalendar.week(date)
    val tonight = AdventCalendar.antiphon(date)
    val readings = remember(date) { repo.readings(date.toString()) }
    val rorate = remember(repo) { runCatching { repo.chapter("douay-rheims", "ISA", 45).firstOrNull { it.label == "8" }?.text }.getOrNull() }
    JohnPage("Advent", week?.let { "Week $it of Advent" } ?: "The season of Advent", "Make ready the way of the Lord.", back) {
        JohnArtCard("advent", "Today’s readings", readings?.optString("title")?.ifBlank { null } ?: "The Mass readings of the day") { navigate("daily/$date") }
        GospelFathersPanel(repo, readings, navigate, "TODAY’S GOSPEL, WITH THE FATHERS")
        JohnPanel {
            Eyebrow("RORATE CAELI")
            SelectionContainer { JohnText(rorate ?: "Drop down dew, ye heavens, from above, and let the clouds rain the just: let the earth be opened, and bud forth a saviour.", serif = true, size = 20) }
            JohnText("Isaiah 45:8 · Douay-Rheims", dim = true, size = 14)
        }
        val collect = AdventCalendar.collect(date)
        if (week != null && collect != null) {
            Box(Modifier.testTag("advent-wreath")) {
                JohnPanel {
                    Eyebrow("THE ADVENT WREATH")
                    JohnText("${listOf("First", "Second", "Third", "Fourth")[week - 1]} candle: the Collect of the ${listOf("first", "second", "third", "fourth")[week - 1]} Sunday of Advent", size = 15)
                    SelectionContainer { JohnText(collect, serif = true, size = 20) }
                    JohnText(AdventCalendar.COLLECT_SOURCE, dim = true, size = 14)
                }
            }
        }
        JohnText("The O Antiphons", size = 20)
        JohnText("Sung at Vespers on the seven evenings before Christmas Eve, from 17 December.", dim = true, size = 14)
        AdventCalendar.antiphons.forEach { antiphon ->
            Box(Modifier.testTag("advent-antiphon-${antiphon.day}")) {
                JohnPanel {
                    val isTonight = antiphon.day == tonight?.day
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
                        Text(antiphon.title, Modifier.weight(1f), fontFamily = SpaceGrotesk, fontWeight = FontWeight.SemiBold, fontSize = 17.sp,
                            color = if (isTonight) LocalJohnColors.current.tint else LocalJohnColors.current.text)
                        JohnText("${antiphon.day} December" + if (isTonight) " · Tonight" else "", dim = true, size = 12)
                    }
                    SelectionContainer { JohnText(antiphon.english, serif = true, size = 18) }
                    SelectionContainer { JohnText(antiphon.latin, serif = true, size = 15, dim = true) }
                }
            }
        }
        JohnText("The antiphons in Latin and English are from ${AdventCalendar.SOURCE}. Public domain.", dim = true, size = 14)
    }
}
