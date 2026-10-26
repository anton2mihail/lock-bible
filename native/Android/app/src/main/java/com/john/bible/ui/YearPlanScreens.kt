package com.john.bible.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowForward
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.KeyboardArrowDown
import androidx.compose.material.icons.outlined.KeyboardArrowUp
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.john.bible.data.*
import com.john.bible.platform.FathersBilling
import com.john.bible.platform.JohnReminders
import java.time.LocalDate
import java.util.Locale

/**
 * "A Year with the Fathers" (1.3.0, matching iOS YearPlanViews and the "design polish" canvas). Offered for the new
 * year but never called a resolution: "resolution", "goal", "challenge", "habit" and "streak" do not appear here
 * (failure Y8), and missed days are "open", never owed. Content shows in its final state, with no entrance animation.
 */
private object YearText {
    const val NAME = "A Year with the Fathers"
    const val ABOUT = "One reading a day from the Fathers of the Church, 5 to 10 minutes. The readings follow the Church’s year."
    const val BEFORE_YEAR = "Begins 1 January. One reading a day from the Fathers of the Church."
    const val FOOTNOTE = "Every word is the Fathers’ own, from the library in John 1:1. Days 1 to 7 are free."
    const val LOCKED = "Days 1 to 7 are free. Day 8 and every day after it come from the Fathers library."
    const val UNLOCK = "The first seven days are free. Day 8 and every day after it come from the Fathers library: 275 works, offline, yours to keep."
    const val FINISHED = "Day 365. You read a year with the Fathers."
    val THROUGH_THE_YEAR = listOf(
        "January" to "St Athanasius, On the Incarnation",
        "Lent" to "St Leo on Lent; St Cyril to those preparing for Baptism",
        "Holy Week" to "St Leo on the Passion, each day",
        "Summer" to "St Augustine, Confessions",
        "Advent" to "The Catena Aurea on Luke 1",
    )
    private val months = listOf("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December")
    fun month(number: Int) = months[(number - 1).coerceIn(0, 11)]
    fun date(value: LocalDate) = "${value.dayOfMonth} ${months[value.monthValue - 1]}"

    /** "St Leo the Great, On Lent, I"; "The Didache, chapters I–VI" when the title is only the chapters. */
    fun reading(day: YearDay): String {
        val title = if (day.title.startsWith("Chapter")) day.title.replaceFirstChar { it.lowercase() } else day.title
        return "${day.author}, $title"
    }

    /** "Three earlier days are open": missed days are offered, never counted against the reader. */
    fun openDays(days: List<Int>): Pair<String, String> {
        val words = listOf("One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine")
        val title = if (days.size == 1) "One earlier day is open" else "${if (days.size <= 9) words[days.size - 1] else days.size.toString()} earlier days are open"
        val shown = days.take(3)
        val list = when (shown.size) {
            1 -> "Day ${shown[0]}"
            2 -> "Days ${shown[0]} and ${shown[1]}"
            else -> "Days ${shown[0]}, ${shown[1]} and ${shown[2]}"
        }
        val more = if (days.size > 3) " and ${days.size - 3} more" else ""
        return title to "$list$more, whenever you wish"
    }

    /** The season's painting, as on Today. */
    fun artwork(season: String) = when (season) {
        "christmas" -> "joyful-3"; "lent" -> "sorrowful-1"; "holy-week" -> "sorrowful-5"
        "easter" -> "glorious-1"; "advent" -> "advent"; else -> "scripture"
    }
}

/** Where the person is today: the plan, their Day 1, the day they joined, and the days read. */
private class YearState(val plan: YearPlan, val start: LocalDate?, val joined: LocalDate?, val read: Set<Int>, val today: LocalDate) {
    val current: Int? = start?.let { YearPlanSchedule.dayNumber(it, today) }
    val joinDay: Int? = YearPlanSchedule.dayOfYear(today)
    val missed: List<Int> get() {
        val start = start ?: return emptyList()
        val current = current ?: return emptyList()
        val joinedAt = joined?.let { YearPlanSchedule.dayNumber(start, it) } ?: 1
        return YearPlanSchedule.missedDays(read, current, joinedAt)
    }
    /** The person's own date for a plan day: the 2027 date for "Join today", later for "Begin at Day 1". */
    fun personalDate(day: Int): LocalDate? = start?.plusDays((day - 1).toLong())
    /** The feast belongs to the 2027 date: shown only where the person's day falls on it. */
    fun feast(day: YearDay): String? = day.feast?.takeIf { personalDate(day.day)?.toString() == day.date }
}

private fun parseDate(value: String?): LocalDate? = value?.let { runCatching { LocalDate.parse(it) }.getOrNull() }

@Composable private fun rememberYearState(repo: JohnRepository, store: JohnStore, today: LocalDate): YearState? {
    val plan = remember(repo) { repo.yearPlan() } ?: return null
    return YearState(plan, parseDate(store.yearStartDate), parseDate(store.yearJoinedDate), store.yearDaysRead, today)
}

@Composable private fun YearEyebrow(text: String) =
    Text(text, fontFamily = SpaceGrotesk, fontSize = 11.sp, lineHeight = 18.sp, letterSpacing = 2.sp, color = LocalJohnColors.current.tint)

/** The dark button, as iOS ContentEmphasisButton. */
@Composable private fun YearEmphasisButton(text: String, tag: String, onClick: () -> Unit) {
    val c = LocalJohnColors.current
    Button(onClick = onClick, modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).testTag(tag), shape = RoundedCornerShape(4.dp),
        colors = ButtonDefaults.buttonColors(containerColor = c.text, contentColor = c.card)) {
        Text(text, fontFamily = SpaceGrotesk, fontSize = 16.sp, fontWeight = FontWeight.Medium)
    }
}

@Composable private fun Centered(text: String) {
    Text(text, Modifier.fillMaxWidth(), fontFamily = SpaceGrotesk, fontSize = 14.sp, lineHeight = 21.sp,
        color = LocalJohnColors.current.textDim, textAlign = TextAlign.Center)
}

/** The Today row. Before 1 January it invites; once started it names the day and today's reading. */
@Composable
fun YearPlanTodayRow(repo: JohnRepository, store: JohnStore, date: LocalDate, navigate: (String) -> Unit) {
    val state = rememberYearState(repo, store, date) ?: return
    val christmas = YearText.artwork("christmas")
    val reminder = JohnReminders.read(LocalContext.current, "year-reminder")
    val current = state.current
    val row: List<String> = when {
        current != null && current < 1 -> {
            val begins = YearText.date(state.start!!)
            listOf(YearText.NAME, if (reminder.enabled) "Begins $begins. Your reminder is set." else "Begins $begins. One reading a day.", christmas, "year")
        }
        current != null -> {
            val day = state.plan.day(current) ?: return
            val art = YearText.artwork(day.season)
            if (current in state.read) {
                val tomorrow = state.plan.day(current + 1)?.let { "Tomorrow: ${YearText.reading(it)}" } ?: YearText.FINISHED
                listOf("Day $current · Read", tomorrow, art, "year")
            } else {
                listOf("Day $current · ${state.feast(day) ?: YearText.NAME}", "${YearText.reading(day)} · ${day.minutes} min", art, "year-day/$current")
            }
        }
        YearPlanSchedule.isBeforeYear(date) -> listOf(YearText.NAME, YearText.BEFORE_YEAR, christmas, "year")
        else -> {
            val join = state.joinDay ?: return
            val day = state.plan.day(join) ?: return
            listOf(YearText.NAME, "Day $join today: ${YearText.reading(day)}", YearText.artwork(day.season), "year")
        }
    }
    Box(Modifier.testTag("today-year-plan")) { JohnRow(row[0], row[1], image = row[2]) { navigate(row[3]) } }
}

/** The start screen and, once started, the plan: today's reading, open earlier days, the reminder, and the year. */
@Composable
fun YearPlanScreen(repo: JohnRepository, store: JohnStore, navigate: (String) -> Unit, back: () -> Unit) {
    val today = FeatureClock.today()
    val context = LocalContext.current
    val billing = remember { FathersBilling.get(context) }
    LaunchedEffect(Unit) { billing.start() }
    val state = rememberYearState(repo, store, today)
    val current = state?.current
    val eyebrow = when {
        current == null -> if (YearPlanSchedule.isBeforeYear(today)) "Begins 1 January 2027" else "2027"
        current < 1 -> "Begins ${YearText.date(state.start!!)}"
        current > YearPlanSchedule.DAY_COUNT -> "365 days"
        else -> "Day $current of 365"
    }
    JohnPage(YearText.NAME, eyebrow, if (state?.start == null) YearText.ABOUT else "", back) {
        if (state == null) { JohnText("The plan could not be opened on this device.", dim = true); return@JohnPage }
        if (state.start == null) YearStart(state, store, today) else YearPlanContent(state, store, billing.isUnlocked, navigate)
    }
}

@Composable
private fun ColumnScope.YearStart(state: YearState, store: JohnStore, today: LocalDate) {
    val context = LocalContext.current
    var reminder by remember { mutableStateOf(JohnReminders.read(context, "year-reminder")) }
    var message by remember { mutableStateOf("") }
    val time = String.format(Locale.getDefault(), "%d:%02d", reminder.hour, reminder.minute)
    // "Remind me on 1 January" turns the reminder on in one step; Android asks for permission first when needed.
    val remind: () -> Unit = {
        store.startYear(YearPlanSchedule.YEAR_START, today)
        val on = reminder.copy(enabled = true)
        if (JohnReminders.save(context, "year-reminder", on)) reminder = on else message = "Could not save the reminder. Please try again."
    }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) remind() else { store.startYear(YearPlanSchedule.YEAR_START, today); message = "Allow notifications in your device settings to receive the reminder." }
    }
    JohnPanel {
        YearEyebrow("THROUGH THE YEAR")
        YearText.THROUGH_THE_YEAR.forEach { (season, works) ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(season, Modifier.width(76.dp), fontFamily = SpaceGrotesk, fontSize = 14.sp, lineHeight = 20.sp, color = LocalJohnColors.current.textDim)
                Text(works, Modifier.weight(1f), fontFamily = SpaceGrotesk, fontSize = 14.sp, lineHeight = 20.sp, color = LocalJohnColors.current.text)
            }
        }
    }
    val firstSubtitle = state.plan.day(1)?.let { "Day 1 today: ${YearText.reading(it)}" } ?: "Day 1 today"
    if (YearPlanSchedule.isBeforeYear(today)) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            YearEmphasisButton("Remind me on 1 January", "year-remind-january") {
                if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)
                    permission.launch(Manifest.permission.POST_NOTIFICATIONS) else remind()
            }
            Centered("Each day at $time. You can change the time later.")
        }
        Box(Modifier.testTag("year-begin-now")) { JohnRow("Begin now", firstSubtitle) { store.startYear(today, today) } }
    } else {
        val suggested = YearPlanSchedule.suggestedStart(today)
        listOf(suggested, if (suggested == YearPlanSchedule.Start.JOIN_TODAY) YearPlanSchedule.Start.BEGIN_AT_DAY_ONE else YearPlanSchedule.Start.JOIN_TODAY)
            .forEachIndexed { index, option ->
                val start = { store.startYear(YearPlanSchedule.startDate(option, today), today) }
                val (title, detail, tag) = when (option) {
                    YearPlanSchedule.Start.JOIN_TODAY -> {
                        val join = state.joinDay ?: return@forEachIndexed
                        val day = state.plan.day(join) ?: return@forEachIndexed
                        Triple("Join today", "Day $join: ${YearText.reading(day)}. The seasons match the Church’s year.", "year-join-today")
                    }
                    YearPlanSchedule.Start.BEGIN_AT_DAY_ONE -> Triple("Begin at Day 1", firstSubtitle, "year-begin-day-one")
                }
                if (index == 0) Column(verticalArrangement = Arrangement.spacedBy(10.dp)) { YearEmphasisButton(title, tag, start); Centered(detail) }
                else Box(Modifier.testTag(tag)) { JohnRow(title, detail, onClick = start) }
            }
    }
    if (message.isNotEmpty()) JohnText(message, dim = true, size = 14)
    JohnText(YearText.FOOTNOTE, dim = true, size = 14)
}

@Composable
private fun ColumnScope.YearPlanContent(state: YearState, store: JohnStore, unlocked: Boolean, navigate: (String) -> Unit) {
    val c = LocalJohnColors.current
    val current = state.current ?: 1
    var confirmRestart by remember { mutableStateOf(false) }
    val monthKey = { day: Int -> state.personalDate(day)?.let { "${it.year}-${it.monthValue}" } }
    var openMonth by remember { mutableStateOf(monthKey(current.coerceIn(1, YearPlanSchedule.DAY_COUNT))) }
    when {
        current > YearPlanSchedule.DAY_COUNT -> JohnPanel { JohnText(YearText.FINISHED, serif = true, size = 20) }
        current < 1 -> state.plan.day(1)?.let { first ->
            YearTodayPanel(first, "DAY 1 · ${YearText.date(state.start!!).uppercase()}", "${first.minutes} min · You can read it now, or wait for the day.", "Read Day 1") { navigate("year-day/1") }
        }
        else -> state.plan.day(current)?.let { day ->
            YearTodayPanel(day, listOfNotNull("TODAY", state.feast(day)?.uppercase()).joinToString(" · "),
                "${day.minutes} min" + if (current in state.read) " · Read" else "",
                if (current in state.read) "Read again" else "Read today’s reading") { navigate("year-day/$current") }
            val missed = state.missed
            if (missed.isNotEmpty()) Box(Modifier.testTag("year-catch-up")) {
                val (title, subtitle) = YearText.openDays(missed)
                JohnRow(title, subtitle) { navigate("year-day/${missed.first()}") }
            }
        }
    }
    if (!unlocked && current >= 6) JohnText(YearText.LOCKED, dim = true, size = 14)
    val reminder = JohnReminders.read(LocalContext.current, "year-reminder")
    Box(Modifier.testTag("year-reminder")) {
        JohnRow("Daily reminder", if (reminder.enabled) String.format(Locale.getDefault(), "%d:%02d · names the day’s reading", reminder.hour, reminder.minute) else "Off") { navigate("year-reminder") }
    }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
            Text("The year", Modifier.weight(1f).semantics { heading() }, fontFamily = SpaceGrotesk, fontWeight = FontWeight.SemiBold, fontSize = 20.sp, color = c.text)
            JohnText("${state.read.size} of 365 read", dim = true, size = 14)
        }
        // Static: it shows where the reader is, with no animation and no count of days in a row.
        Box(Modifier.fillMaxWidth().height(4.dp).clip(RoundedCornerShape(2.dp)).background(c.separator)) {
            Box(Modifier.fillMaxWidth(state.read.size / 365f).height(4.dp).background(c.tint))
        }
    }
    val firstYear = state.personalDate(1)?.year
    state.plan.days.groupBy { monthKey(it.day) ?: "" }.forEach { (key, days) ->
        val date = state.personalDate(days.first().day) ?: return@forEach
        val title = YearText.month(date.monthValue) + if (date.year != firstYear) " ${date.year}" else ""
        Column {
            Row(Modifier.fillMaxWidth().clickable { openMonth = if (openMonth == key) null else key }.heightIn(min = 48.dp).testTag("year-month-$key"),
                verticalAlignment = Alignment.CenterVertically) {
                Text(title, Modifier.weight(1f), fontFamily = SpaceGrotesk, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = c.text)
                JohnText("${days.count { it.day in state.read }} of ${days.size}", dim = true, size = 13)
                Icon(if (openMonth == key) Icons.Outlined.KeyboardArrowUp else Icons.Outlined.KeyboardArrowDown, null, tint = c.textDim)
            }
            if (openMonth == key) days.forEach { day -> YearDayRow(day, state, unlocked, navigate) }
            HorizontalDivider(color = c.separator, thickness = 0.5.dp)
        }
    }
    Box(Modifier.testTag("year-restart")) {
        TextButton(onClick = { confirmRestart = true }) { Text("Start the plan again", fontFamily = SpaceGrotesk, color = c.tint) }
    }
    if (confirmRestart) AlertDialog(onDismissRequest = { confirmRestart = false },
        title = { JohnText("Start the plan again?", size = 20) },
        text = { JohnText("You choose again how to begin. The days you read stay marked.") },
        confirmButton = { TextButton(onClick = { confirmRestart = false; store.startYear(null) }) { Text("Start again") } },
        dismissButton = { TextButton(onClick = { confirmRestart = false }) { Text("Cancel") } })
}

@Composable
private fun YearTodayPanel(day: YearDay, eyebrow: String, detail: String, button: String, onRead: () -> Unit) {
    val c = LocalJohnColors.current
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(c.card).border(0.5.dp, c.separator, RoundedCornerShape(18.dp))) {
        JohnArtwork(YearText.artwork(day.season), Modifier.fillMaxWidth().height(150.dp))
        Column(Modifier.padding(start = 20.dp, end = 20.dp, top = 18.dp, bottom = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            YearEyebrow(eyebrow)
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                JohnText(day.author, size = 15, dim = true)
                JohnText(day.title, serif = true, size = 24)
            }
            JohnText(detail, dim = true, size = 14)
            Spacer(Modifier.height(4.dp))
            YearEmphasisButton(button, "year-read-today", onRead)
        }
    }
}

@Composable
private fun YearDayRow(day: YearDay, state: YearState, unlocked: Boolean, navigate: (String) -> Unit) {
    val c = LocalJohnColors.current
    val isRead = day.day in state.read
    val isToday = day.day == state.current
    val locked = YearPlanSchedule.isLocked(day.day, state.plan.freeDays, unlocked)
    val date = state.personalDate(day.day)?.let { YearText.date(it) } ?: ""
    val label = (if (isToday) "Today · " else "") + "Day ${day.day} · " + (if (isToday) state.feast(day) ?: date else date)
    Row(Modifier.fillMaxWidth().padding(vertical = 2.dp).clip(RoundedCornerShape(10.dp))
        .background(if (isToday) c.tint.copy(alpha = 0.1f) else c.background.copy(alpha = 0f))
        .clickable { navigate("year-day/${day.day}") }.padding(horizontal = if (isToday) 10.dp else 0.dp, vertical = 8.dp)
        .semantics(mergeDescendants = true) {
            contentDescription = (if (isToday) "Today, " else "") + "Day ${day.day}, ${YearText.reading(day)}" + (if (isRead) ", read" else "") + if (locked) ", in the Fathers library" else ""
        }
        .testTag("year-day-${day.day}"),
        horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        when {
            isRead -> Icon(Icons.Outlined.CheckCircle, null, tint = c.tint, modifier = Modifier.size(20.dp))
            isToday -> Box(Modifier.size(20.dp), contentAlignment = Alignment.Center) { Box(Modifier.size(10.dp).clip(RoundedCornerShape(5.dp)).background(c.tint)) }
            locked -> Icon(Icons.Outlined.Lock, null, tint = c.textDim, modifier = Modifier.size(20.dp))
            else -> Icon(Icons.Outlined.RadioButtonUnchecked, null, tint = c.textDim, modifier = Modifier.size(20.dp))
        }
        Column(Modifier.weight(1f)) {
            Text(label, fontFamily = SpaceGrotesk, fontSize = 12.sp, fontWeight = if (isToday) FontWeight.Medium else FontWeight.Normal, color = if (isToday) c.tint else c.textDim)
            JohnText(YearText.reading(day), size = 15)
        }
    }
}

private data class YearBlock(val heading: Boolean, val text: String)

/** A short line without closing punctuation is a heading; so are "Chapter …" lines and St Leo's numbered summaries (same rule as iOS). */
private fun isHeading(text: String): Boolean {
    val words = text.split(Regex("\\s+")).size
    if (words <= 25 && Regex("^[IVXLC]+\\.\\s").containsMatchIn(text)) return true
    if (words > 14) return false
    if (text.startsWith("Chapter") || text.startsWith("Book") || text.startsWith("Lecture")) return true
    return text.last() !in ".!?:;”\"’)"
}

/** One day's reading: the paragraphs from the library, an end mark, then "Mark as read" and the next day. Day 8 and later show the purchase page without the library (Y4). */
@Composable
fun YearDayScreen(dayNumber: Int, repo: JohnRepository, store: JohnStore, navigate: (String) -> Unit, back: () -> Unit) {
    val c = LocalJohnColors.current
    val today = FeatureClock.today()
    val state = rememberYearState(repo, store, today)
    val day = state?.plan?.day(dayNumber)
    val context = LocalContext.current
    val billing = remember { FathersBilling.get(context) }
    LaunchedEffect(Unit) { billing.start() }
    val locked = YearPlanSchedule.isLocked(dayNumber, state?.plan?.freeDays ?: 7, billing.isUnlocked)
    val isToday = state?.current == dayNumber
    val blocks = remember(dayNumber, locked) {
        if (day == null || locked) emptyList() else runCatching {
            day.readings.flatMap { reading ->
                val section = repo.workSection(reading.workId, reading.section)
                val upper = minOf(reading.toParagraph, section.paragraphs.size - 1)
                // One reading: the page title already names it, so the library's section title is not repeated.
                val heading = if (reading.fromParagraph == 0 && day.readings.size > 1) listOf(YearBlock(true, section.title)) else emptyList()
                heading + (if (reading.fromParagraph <= upper) section.paragraphs.subList(reading.fromParagraph, upper + 1) else emptyList())
                    .map { it.trim() }
                    .filter { it.isNotEmpty() && !it.all { ch -> ch in "—–-" } && it != section.title.trim() }
                    .map { YearBlock(isHeading(it), it) }
            }
        }.getOrDefault(emptyList())
    }
    val eyebrow = day?.let { d -> listOfNotNull("Day $dayNumber", state.feast(d)).joinToString(" · ") } ?: "Day $dayNumber"
    JohnPage(day?.title ?: YearText.NAME, eyebrow, day?.let { "${it.author} · ${it.minutes} min" } ?: "", back) {
        when {
            day == null -> JohnText("This day is not in the plan.", dim = true)
            locked -> FathersUnlockPanel(sampleNotice = YearText.UNLOCK, totals = libraryTotals(repo), title = "Continue the year")
            blocks.isEmpty() -> JohnText("This reading could not be opened. Try again, or open it in the library.", dim = true)
            else -> {
                Column(Modifier.testTag("year-day-text"), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    blocks.forEach { block ->
                        if (block.heading) Text(block.text, Modifier.padding(top = 6.dp).semantics { heading() }, fontFamily = SpaceGrotesk, fontWeight = FontWeight.SemiBold,
                            fontSize = 15.sp, lineHeight = 22.sp, color = c.text)
                        // Follows the reader's typeface, size and spacing, as the Bible reader does.
                        else SelectionContainer {
                            Text(block.text, fontFamily = if (store.fontFamily == "serif") Lora else SpaceGrotesk, fontSize = store.textSize.sp,
                                lineHeight = (store.textSize * store.lineSpacing).sp, color = c.text)
                        }
                    }
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        HorizontalDivider(Modifier.weight(1f), color = c.separator)
                        Text("✝", fontSize = 16.sp, color = c.tint, modifier = Modifier.clearAndSetSemantics { })
                        HorizontalDivider(Modifier.weight(1f), color = c.separator)
                    }
                    JohnText(if (isToday) "End of today’s reading" else "End of the reading", dim = true, size = 14)
                }
                if (dayNumber in store.yearDaysRead) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(4.dp)).background(c.card).border(1.dp, c.border, RoundedCornerShape(4.dp))
                            .testTag("year-read-state"), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Outlined.Check, null, tint = c.tint, modifier = Modifier.size(20.dp))
                            Spacer(Modifier.width(10.dp))
                            Text("Read", fontFamily = SpaceGrotesk, fontWeight = FontWeight.Medium, fontSize = 16.sp, color = c.text)
                        }
                        TextButton(onClick = { store.setYearDayRead(dayNumber, false) }, modifier = Modifier.testTag("year-mark-unread")) {
                            Text("Mark as not read", fontFamily = SpaceGrotesk, fontSize = 14.sp, color = c.tint)
                        }
                    }
                } else {
                    YearEmphasisButton("Mark as read", "year-mark-read") { store.setYearDayRead(dayNumber, true) }
                }
            }
        }
        state?.plan?.day(dayNumber + 1)?.let { next ->
            Column(Modifier.testTag("year-next-day")) {
                HorizontalDivider(color = c.separator, thickness = 0.5.dp)
                Row(Modifier.fillMaxWidth().clickable { navigate("year-day/${next.day}") }.padding(vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text((if (isToday) "TOMORROW" else "NEXT") + " · DAY ${next.day}", fontFamily = SpaceGrotesk, fontSize = 12.sp, letterSpacing = 1.4.sp, color = c.tint)
                        Text(YearText.reading(next), fontFamily = SpaceGrotesk, fontWeight = FontWeight.Medium, fontSize = 16.sp, lineHeight = 24.sp, color = c.text)
                        JohnText("${next.minutes} min", dim = true, size = 14)
                    }
                    Icon(Icons.AutoMirrored.Outlined.ArrowForward, null, tint = c.tint, modifier = Modifier.size(19.dp))
                }
                HorizontalDivider(color = c.separator, thickness = 0.5.dp)
            }
        }
        day?.readings?.firstOrNull()?.let { first ->
            Box(Modifier.testTag("year-open-library")) {
                TextButton(onClick = { navigate("work/${first.workId}/${first.section}") }, contentPadding = PaddingValues(0.dp)) {
                    Text("Open in the library", fontFamily = SpaceGrotesk, fontSize = 15.sp, color = c.tint)
                }
            }
        }
        if (day != null && !locked) {
            val collection = day.readings.firstOrNull()?.let { FathersAccess.collectionId(it.workId) }
            repo.workAuthors().firstOrNull { it.id == collection }?.let { JohnText(it.attribution, dim = true, size = 14) }
        }
    }
}
