package com.john.bible.ui

import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.outlined.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.john.bible.data.FeatureClock
import com.john.bible.data.JohnRepository
import com.john.bible.data.LentCalendar
import com.john.bible.data.LentContent
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Lent, Holy Week and the Stations of the Cross (Android 1.3.0, matching iOS 2.3.0 LentViews.swift). */
private object LentText {
    const val FASTING_URL = "https://www.usccb.org/prayer-and-worship/liturgical-year-and-calendar/lent/catholic-information-on-lenten-fast-and-abstinence"
    const val MISSAL = "The Missal (1926 printing; Imprimatur Westminster, 1921)"
    const val MANUAL = "A Manual of Prayers (Baltimore, 1889)"
    const val MASS_EVERY_DAY = "The Roman Missal (New York, 1916; Imprimatur Farley)"
    val leoTitles = listOf("On Lent, I", "On Lent, II", "On Lent, IV", "On Lent, VIII", "On Lent, XI", "On the Transfiguration",
        "On the Passion, III", "On the Passion, IV", "On the Passion, VII", "On the Passion, VIII",
        "On the Passion, XI", "On the Passion, XII", "On the Passion, XVI", "On the Passion, XVII")
    val psalmTitles = mapOf(6 to "Domine, ne in furore", 31 to "Beati quorum", 37 to "Domine, ne in furore (II)",
        50 to "Miserere", 101 to "Domine, exaudi", 129 to "De profundis", 142 to "Domine, exaudi (II)")
    fun pages(pages: List<Int>): String {
        val first = pages.minOrNull() ?: return ""; val last = pages.max()
        return if (first == last) "p. $first" else "pp. $first–$last"
    }
}

@Composable private fun LentEyebrow(text: String) = Text(text.uppercase(), fontFamily = SpaceGrotesk, fontSize = 11.sp, lineHeight = 18.sp, letterSpacing = 2.sp, color = LocalJohnColors.current.tint)

/** The Today row from Ash Wednesday to Easter Sunday. Fridays of Lent open the Stations; Holy Week opens its page. */
@Composable
fun LentTodayRow(repo: JohnRepository, date: java.time.LocalDate, navigate: (String) -> Unit) {
    if (repo.lent() == null) return
    val day = LentCalendar.day(date) ?: return
    Box(Modifier.testTag(if (day.isHolyWeek) "today-holy-week" else "today-lent")) {
        when {
            day.isHolyWeek -> JohnRow("Holy Week · ${day.dayTitle}",
                if (day.isEasterSunday) "Victimae paschali and the Collect of Easter" else "The day’s readings, the Fathers and the Missal’s prayers",
                image = if (day.isEasterSunday) "glorious-1" else "sorrowful-5") { navigate("holy-week") }
            day.isFriday -> JohnRow("Friday: the Stations of the Cross", "${day.weekLabel} · St Alphonsus Liguori", image = "stations-01") { navigate("stations") }
            else -> JohnRow(if (day.offset == 0) "Ash Wednesday: Lent with the Fathers" else "Lent with the Fathers",
                "${day.weekLabel} · The Gospel, the Fathers and the Collect", image = "sorrowful-1") { navigate("lent") }
        }
    }
}

/** A quoted text: an eyebrow, the paragraphs, and its book and page. Long texts show "Read all" first. */
@Composable
private fun LentTextPanel(eyebrow: String, paragraphs: List<String>, source: String, heading: String? = null,
                          rubrics: List<String> = emptyList(), collapseAfter: Int = Int.MAX_VALUE, note: String? = null) {
    var expanded by remember { mutableStateOf(false) }
    val collapsed = !expanded && paragraphs.size > collapseAfter
    val c = LocalJohnColors.current
    JohnPanel {
        LentEyebrow(eyebrow)
        heading?.let { JohnText(it, size = 15) }
        rubrics.forEach { Text(it, fontFamily = Lora, fontStyle = FontStyle.Italic, fontSize = 15.sp, lineHeight = 22.sp, color = c.textDim) }
        SelectionContainer {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                (if (collapsed) paragraphs.take(collapseAfter) else paragraphs).forEach { JohnText(it, serif = true, size = 19) }
            }
        }
        if (collapsed) Text("Read all", Modifier.clickable { expanded = true }.heightIn(min = 44.dp).padding(vertical = 10.dp),
            fontFamily = SpaceGrotesk, fontSize = 15.sp, color = c.tint)
        note?.let { JohnText(it, dim = true, size = 14) }
        JohnText(source, dim = true, size = 14)
    }
}

/** The Lent page (`nrsv://lent`): the week, today's Gospel with the Fathers, the Collect, St Leo, the Penitential Psalms and the Stations. */
@Composable
fun LentScreen(repo: JohnRepository, navigate: (String) -> Unit, back: () -> Unit) {
    val date = FeatureClock.today()
    val day = LentCalendar.day(date)
    val lent = remember(repo) { repo.lent() }
    val readings = remember(date) { repo.readings(date.toString()) }
    val context = LocalContext.current
    JohnPage("Lent", day?.dayTitle ?: day?.weekLabel ?: "The season of Lent", "Ash Wednesday to Holy Saturday", back) {
        if (day != null) {
            Box(Modifier.testTag("lent-readings")) {
                JohnArtCard("sorrowful-1", "Today’s readings", readings?.optString("title")?.ifBlank { null } ?: "The Mass readings of the day") { navigate("daily/$date") }
            }
            GospelFathersPanel(repo, readings, navigate, "TODAY’S GOSPEL, WITH THE FATHERS")
        } else {
            val year = if (date < LentCalendar.ashWednesday(date.year)) date.year else date.year + 1
            JohnText("Lent begins on Ash Wednesday, ${LentCalendar.ashWednesday(year).format(DateTimeFormatter.ofPattern("d MMMM yyyy", Locale.UK))}.", dim = true, size = 14)
        }
        val collect = day?.let { lent?.collects?.get(it.key) }
        if (collect != null) Box(Modifier.testTag("lent-collect")) {
            LentTextPanel("The Collect of the day", listOf(collect.text), "${if (collect.book == "massEveryDay") LentText.MASS_EVERY_DAY else LentText.MISSAL}, p. ${collect.page}", heading = collect.title)
        }
        if (day?.isHolyWeek == true) JohnRow("Holy Week", "Palm Sunday to Easter Sunday: the Missal’s prayers for each day", image = "sorrowful-5") { navigate("holy-week") }
        val passion = day?.isPassiontide == true || day?.isHolyWeek == true
        JohnText(if (passion) "St Leo the Great on the Passion" else "St Leo the Great on Lent", size = 20)
        JohnText("Fourteen sermons from the library, free to read from Ash Wednesday to Easter Sunday.", dim = true, size = 14)
        val all = LentCalendar.leoSections.toList()
        (if (passion) all.drop(6) + all.take(6) else all).forEach { index ->
            Box(Modifier.testTag("lent-leo-$index")) {
                JohnRow(LentText.leoTitles[index - LentCalendar.leoSections.first], "St Leo the Great · Sermons") { navigate("work/${LentCalendar.LEO_WORK_ID}/$index") }
            }
        }
        JohnText("The Seven Penitential Psalms", size = 20)
        JohnText("Douay-Rheims, with the Vulgate’s numbering.", dim = true, size = 14)
        (lent?.penitentialPsalms ?: listOf(6, 31, 37, 50, 101, 129, 142)).forEach { psalm ->
            Box(Modifier.testTag("lent-psalm-$psalm")) { JohnRow("Psalm $psalm", LentText.psalmTitles[psalm].orEmpty()) { navigate("reader/douay-rheims/PSA/$psalm") } }
        }
        JohnText("Prayer", size = 20)
        Box(Modifier.testTag("lent-stations")) { JohnRow("The Stations of the Cross", "St Alphonsus Liguori · Fourteen stations", image = "stations-01") { navigate("stations") } }
        JohnRow("Fasting and abstinence", "The rules of the United States bishops (USCCB)") {
            runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(LentText.FASTING_URL))) }
        }
    }
}

/** The Holy Week page (`nrsv://holyweek`): today's day first, then the other days, each with the Missal's texts. */
@Composable
fun HolyWeekScreen(repo: JohnRepository, navigate: (String) -> Unit, back: () -> Unit) {
    val date = FeatureClock.today()
    val today = LentCalendar.day(date)?.takeIf { it.isHolyWeek }
    val days = remember(repo) { repo.lent()?.holyWeek.orEmpty() }
    val ordered = today?.let { t -> days.filter { it.key == t.key } + days.filter { it.key != t.key } } ?: days
    val readings = remember(date) { repo.readings(date.toString()) }
    JohnPage("Holy Week", today?.dayTitle ?: "Palm Sunday to Easter Sunday", "The prayers of the Roman Missal for each day", back) {
        if (today != null) {
            JohnArtCard(if (today.isEasterSunday) "glorious-1" else "sorrowful-5", "Today’s readings", readings?.optString("title")?.ifBlank { null } ?: "The Mass readings of the day") { navigate("daily/$date") }
            GospelFathersPanel(repo, readings, navigate, "TODAY’S GOSPEL, WITH THE FATHERS")
        }
        ordered.forEach { day ->
            Box(Modifier.testTag("holy-week-${day.key}")) { JohnText(if (day.key == today?.key) "Today: ${day.title}" else day.title, size = 20) }
            if (day.key == "good-fri") JohnRow("The Stations of the Cross", "St Alphonsus Liguori", image = "stations-12") { navigate("stations") }
            day.sections.forEach { section ->
                Box(Modifier.testTag("holy-week-${day.key}-${section.id}")) {
                    LentTextPanel(section.title, section.paragraphs, "${LentText.MISSAL}, ${LentText.pages(section.pages)}", rubrics = section.rubrics, collapseAfter = 3, note = section.note)
                }
            }
        }
        JohnText("From the Roman Missal in its 1926 English printing. These are prayers of the day, not a guide to the rite as it is celebrated now.", dim = true, size = 14)
    }
}

/** The Stations of the Cross (`nrsv://stations`): the opening prayer, then one page for each station, then the closing. */
@Composable
fun StationsScreen(repo: JohnRepository, back: () -> Unit) {
    val lent = remember(repo) { repo.lent() }
    if (lent == null) { JohnPage("Stations of the Cross", back = back) { JohnText("The Stations are not available.", dim = true) }; return }
    val count = lent.stations.size + if (lent.closing == null) 1 else 2
    val pager = rememberPagerState { count }
    val scope = rememberCoroutineScope()
    val c = LocalJohnColors.current
    val context = LocalContext.current
    val credits = remember { runCatching { context.assets.open("artwork/credits.json").bufferedReader().use { JSONObject(it.readText()) } }.getOrDefault(JSONObject()) }
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = back) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, "Back", tint = c.tint) }
            Text("Stations of the Cross", fontFamily = SpaceGrotesk, fontSize = 16.sp, color = c.text)
        }
        HorizontalPager(pager, Modifier.weight(1f)) { page ->
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.TopCenter) {
                Column(Modifier.widthIn(max = 620.dp).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    when {
                        page == 0 -> StationsPart(lent.opening)
                        page <= lent.stations.size -> StationPage(lent.stations[page - 1], credits.optString(lent.stations[page - 1].painting))
                        else -> lent.closing?.let { StationsPart(it) }
                    }
                }
            }
        }
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp).testTag("stations-controls"), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = { scope.launch { pager.scrollToPage(pager.currentPage - 1) } }, enabled = pager.currentPage > 0) {
                Icon(Icons.AutoMirrored.Outlined.KeyboardArrowLeft, "Previous", tint = if (pager.currentPage > 0) c.tint else c.border)
            }
            Text(when { pager.currentPage == 0 -> "Opening prayer"; pager.currentPage <= lent.stations.size -> "Station ${pager.currentPage} of ${lent.stations.size}"; else -> "Closing prayer" },
                Modifier.weight(1f), textAlign = TextAlign.Center, fontFamily = SpaceGrotesk, fontSize = 13.sp, color = c.textDim)
            IconButton(onClick = { scope.launch { pager.scrollToPage(pager.currentPage + 1) } }, enabled = pager.currentPage < count - 1) {
                Icon(Icons.AutoMirrored.Outlined.KeyboardArrowRight, "Next", tint = if (pager.currentPage < count - 1) c.tint else c.border)
            }
        }
    }
}

@Composable
private fun StationsPart(part: LentContent.Part) {
    JohnText(part.title, serif = true, size = 28)
    SelectionContainer { Column(verticalArrangement = Arrangement.spacedBy(14.dp)) { part.paragraphs.forEach { JohnText(it, serif = true, size = 19) } } }
    JohnText("St Alphonsus Liguori · ${LentText.MANUAL}, ${LentText.pages(part.pages)}", dim = true, size = 14)
}

@Composable
private fun StationPage(station: LentContent.Station, credit: String) {
    val c = LocalJohnColors.current
    val context = LocalContext.current
    val bitmap = remember(station.painting) { runCatching { context.assets.open("artwork/${station.painting}.jpg").use { BitmapFactory.decodeStream(it) } }.getOrNull() }
    Box(Modifier.testTag("station-${station.number}")) {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            bitmap?.let { Image(it.asImageBitmap(), null, Modifier.fillMaxWidth().heightIn(max = 360.dp).clip(RoundedCornerShape(12.dp)), contentScale = ContentScale.Fit) }
            if (credit.isNotBlank()) JohnText(credit, dim = true, size = 12)
            LentEyebrow("Station ${station.number}")
            JohnText(station.title, serif = true, size = 26)
            listOf("V." to station.versicle, "R." to station.response).forEach { (mark, text) ->
                Text(buildAnnotatedString { withStyle(SpanStyle(color = c.tint)) { append("$mark ") }; append(text) },
                    fontFamily = Lora, fontSize = 18.sp, lineHeight = 27.sp, color = c.text)
            }
            SelectionContainer { Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                JohnText(station.meditation, serif = true, size = 19)
                JohnText(station.prayer, serif = true, size = 19)
            } }
            Text(station.after, fontFamily = Lora, fontStyle = FontStyle.Italic, fontSize = 17.sp, lineHeight = 26.sp, color = c.textDim)
            Text(station.verse.joinToString("\n"), Modifier.fillMaxWidth(), textAlign = TextAlign.Center, fontFamily = Lora, fontSize = 17.sp, lineHeight = 26.sp, color = c.text)
            JohnText("St Alphonsus Liguori · ${LentText.MANUAL}, ${LentText.pages(station.pages)}", dim = true, size = 14)
        }
    }
}
