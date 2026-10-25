package com.john.bible.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.KeyboardArrowDown
import androidx.compose.material.icons.outlined.KeyboardArrowUp
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.john.bible.data.*
import com.john.bible.platform.FathersBilling
import java.time.LocalDate

/**
 * "A Year with the Fathers" (1.3.0, matching iOS YearPlanViews). Offered for the new year but never called a
 * resolution: "resolution", "goal", "challenge", "habit" and "streak" do not appear here (failure Y8).
 * Content shows in its final state, with no entrance animation.
 */
private object YearText {
    const val NAME = "A Year with the Fathers"
    const val INVITATION = "Begin the year with the Fathers. One reading a day, from 1 January."
    const val ABOUT = "365 days, one reading a day, 5 to 10 minutes. The Fathers of the Church, in order through the year: in Lent, the Fathers on Lent; in Holy Week, on the Passion. Begin on 1 January, or join on any day."
    const val LOCKED = "Days 1 to 7 are free. Continue the year with the Fathers library: Day 8 and every day after it."
    const val FINISHED = "Day 365. You read a year with the Fathers."
    fun missed(first: Int) = "You missed a few days. Read today’s reading, or catch up from Day $first."
    private val months = listOf("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December")
    fun month(number: Int) = months[number - 1]
    fun date(value: String): String = runCatching { LocalDate.parse(value).let { "${it.dayOfMonth} ${months[it.monthValue - 1]}" } }.getOrDefault(value)
}

@Composable private fun YearEyebrow(text: String) =
    Text(text, fontFamily = SpaceGrotesk, fontSize = 11.sp, lineHeight = 18.sp, letterSpacing = 2.sp, color = LocalJohnColors.current.tint)

private fun parseDate(value: String?): LocalDate? = value?.let { runCatching { LocalDate.parse(it) }.getOrNull() }

/** The Today row. Before 1 January it invites; once started it names today's reading. */
@Composable
fun YearPlanTodayRow(repo: JohnRepository, store: JohnStore, date: LocalDate, navigate: (String) -> Unit) {
    val plan = remember(repo) { repo.yearPlan() } ?: return
    val start = parseDate(store.yearStartDate)
    val (title, subtitle, route) = when {
        start != null -> {
            val current = YearPlanSchedule.dayNumber(start, date)
            when {
                current < 1 -> Triple(YearText.NAME, "Begins on ${YearText.date(start.toString())}. One reading a day.", "year")
                current > YearPlanSchedule.DAY_COUNT -> return
                else -> {
                    val day = plan.day(current) ?: return
                    val done = if (current in store.yearDaysRead) " · Read" else ""
                    Triple("Day $current · ${day.author}", "${day.title} · ${day.minutes} min$done", "year-day/$current")
                }
            }
        }
        YearPlanSchedule.isBeforeYear(date) -> Triple(YearText.NAME, YearText.INVITATION, "year")
        else -> {
            val join = YearPlanSchedule.dayOfYear(date) ?: return
            val day = plan.day(join) ?: return
            Triple(YearText.NAME, "Day $join today: ${day.author}, ${day.title}", "year")
        }
    }
    Box(Modifier.testTag("today-year-plan")) { JohnRow(title, subtitle, image = "scripture") { navigate(route) } }
}

/** The start screen and, once started, the plan: today's reading, catch-up, the reminder, and every day by month. */
@Composable
fun YearPlanScreen(repo: JohnRepository, store: JohnStore, navigate: (String) -> Unit, back: () -> Unit) {
    val plan = remember(repo) { repo.yearPlan() }
    val today = FeatureClock.today()
    val context = LocalContext.current
    val billing = remember { FathersBilling.get(context) }
    LaunchedEffect(Unit) { billing.start() }
    val start = parseDate(store.yearStartDate)
    val current = start?.let { YearPlanSchedule.dayNumber(it, today) }
    val eyebrow = when {
        current == null -> if (YearPlanSchedule.isBeforeYear(today)) "Begins 1 January 2027" else "2027"
        current < 1 -> "Begins ${YearText.date(start.toString())}"
        current > YearPlanSchedule.DAY_COUNT -> "365 days"
        else -> "Day $current of 365"
    }
    JohnPage(YearText.NAME, eyebrow, if (start == null) YearText.ABOUT else "", back) {
        if (plan == null) { JohnText("The plan could not be opened on this device.", dim = true); return@JohnPage }
        if (start == null) YearStart(plan, store, today, navigate) else YearPlanContent(plan, store, start, today, billing.isUnlocked, navigate)
    }
}

@Composable
private fun ColumnScope.YearStart(plan: YearPlan, store: JohnStore, today: LocalDate, navigate: (String) -> Unit) {
    val first = plan.day(1)
    val firstSubtitle = first?.let { "Day 1 today: ${it.author}, ${it.title}" } ?: "Day 1 today"
    if (YearPlanSchedule.isBeforeYear(today)) {
        Box(Modifier.testTag("year-remind-january")) {
            JohnButton("Remind me on 1 January") { store.startYear(YearPlanSchedule.YEAR_START, today); navigate("year-reminder") }
        }
        Box(Modifier.testTag("year-begin-now")) { JohnRow("Begin now", firstSubtitle) { store.startYear(today, today) } }
    } else {
        val order = if (YearPlanSchedule.suggestedStart(today) == YearPlanSchedule.Start.JOIN_TODAY)
            listOf(YearPlanSchedule.Start.JOIN_TODAY, YearPlanSchedule.Start.BEGIN_AT_DAY_ONE)
        else listOf(YearPlanSchedule.Start.BEGIN_AT_DAY_ONE, YearPlanSchedule.Start.JOIN_TODAY)
        order.forEach { option ->
            when (option) {
                YearPlanSchedule.Start.JOIN_TODAY -> {
                    val join = YearPlanSchedule.dayOfYear(today)
                    val day = join?.let { plan.day(it) }
                    if (join != null && day != null) Box(Modifier.testTag("year-join-today")) {
                        JohnRow("Join today", "Day $join: ${day.author}, ${day.title}. The seasons match the Church’s year.") {
                            store.startYear(YearPlanSchedule.startDate(option, today), today)
                        }
                    }
                }
                YearPlanSchedule.Start.BEGIN_AT_DAY_ONE -> Box(Modifier.testTag("year-begin-day-one")) {
                    JohnRow("Begin at Day 1", firstSubtitle) { store.startYear(YearPlanSchedule.startDate(option, today), today) }
                }
            }
        }
    }
    JohnText("Every reading is the Fathers’ own words, from the library in John 1:1. Days 1 to 7 are free.", dim = true, size = 14)
}

@Composable
private fun ColumnScope.YearPlanContent(plan: YearPlan, store: JohnStore, start: LocalDate, today: LocalDate, unlocked: Boolean, navigate: (String) -> Unit) {
    val current = YearPlanSchedule.dayNumber(start, today)
    val read = store.yearDaysRead
    var confirmRestart by remember { mutableStateOf(false) }
    var openMonth by remember { mutableStateOf<Int?>(plan.day(current.coerceIn(1, 365))?.date?.substring(5, 7)?.toIntOrNull()) }
    when {
        current > YearPlanSchedule.DAY_COUNT -> JohnPanel { JohnText(YearText.FINISHED, serif = true, size = 20) }
        current < 1 -> plan.day(1)?.let { first ->
            JohnPanel {
                YearEyebrow("DAY 1 · ${YearText.date(start.toString()).uppercase()}")
                JohnText("${first.author}, ${first.title}", serif = true, size = 20)
                JohnText("You can read it now, or wait for the day.", dim = true, size = 14)
                JohnRow("Read Day 1", "${first.minutes} min") { navigate("year-day/1") }
            }
        }
        else -> plan.day(current)?.let { day ->
            JohnPanel {
                // The feast belongs to the 2027 date; show it only when today is that date.
                val feast = day.feast?.takeIf { day.date == today.toString() }
                YearEyebrow(listOfNotNull("TODAY", feast?.uppercase()).joinToString(" · "))
                JohnText(day.author, size = 15, dim = true)
                JohnText(day.title, serif = true, size = 22)
                JohnText("${day.minutes} min" + if (current in read) " · Read" else "", dim = true, size = 14)
                Box(Modifier.testTag("year-read-today")) {
                    JohnButton(if (current in read) "Read it again" else "Read today’s reading") { navigate("year-day/$current") }
                }
            }
            val joinedAt = parseDate(store.yearJoinedDate)?.let { YearPlanSchedule.dayNumber(start, it) } ?: 1
            val missed = YearPlanSchedule.missedDays(read, current, joinedAt)
            if (missed.isNotEmpty()) Box(Modifier.testTag("year-catch-up")) {
                JohnRow(YearText.missed(missed.first()), "${missed.size} day${if (missed.size == 1) "" else "s"} to catch up") { navigate("year-day/${missed.first()}") }
            }
        }
    }
    if (!unlocked) JohnText(YearText.LOCKED, dim = true, size = 14)
    val context = LocalContext.current
    val reminder = com.john.bible.platform.JohnReminders.read(context, "year-reminder")
    Box(Modifier.testTag("year-reminder")) {
        JohnRow("Daily reminder", if (reminder.enabled) String.format(java.util.Locale.getDefault(), "Each day at %02d:%02d. Each reminder names that day’s reading.", reminder.hour, reminder.minute) else "Off") { navigate("year-reminder") }
    }
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
        Text("The year", Modifier.weight(1f).semantics { heading() }, fontFamily = SpaceGrotesk, fontWeight = FontWeight.SemiBold, fontSize = 20.sp, color = LocalJohnColors.current.text)
        JohnText("${read.size} of 365 read", dim = true, size = 14)
    }
    (1..12).forEach { month ->
        val days = plan.days.filter { it.date.substring(5, 7).toInt() == month }
        val c = LocalJohnColors.current
        Column {
            Row(Modifier.fillMaxWidth().clickable { openMonth = if (openMonth == month) null else month }.heightIn(min = 48.dp).testTag("year-month-$month"),
                verticalAlignment = Alignment.CenterVertically) {
                Text(YearText.month(month), Modifier.weight(1f), fontFamily = SpaceGrotesk, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = c.text)
                JohnText("${days.count { it.day in read }} of ${days.size}", dim = true, size = 13)
                Icon(if (openMonth == month) Icons.Outlined.KeyboardArrowUp else Icons.Outlined.KeyboardArrowDown, null, tint = c.textDim)
            }
            if (openMonth == month) days.forEach { day ->
                val isRead = day.day in read
                Row(Modifier.fillMaxWidth().clickable { navigate("year-day/${day.day}") }.padding(vertical = 8.dp)
                    .semantics(mergeDescendants = true) { contentDescription = "Day ${day.day}, ${day.author}, ${day.title}" + if (isRead) ", read" else "" }
                    .testTag("year-day-${day.day}"),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(if (isRead) Icons.Outlined.CheckCircle else Icons.Outlined.RadioButtonUnchecked, null, tint = if (isRead) c.tint else c.textDim, modifier = Modifier.size(20.dp))
                    Column(Modifier.weight(1f)) {
                        Text("Day ${day.day} · ${YearText.date(day.date)}" + (day.feast?.let { " · $it" } ?: ""), fontFamily = SpaceGrotesk, fontSize = 12.sp,
                            color = if (day.day == current) c.tint else c.textDim)
                        JohnText("${day.author}, ${day.title}", size = 15)
                    }
                }
            }
            HorizontalDivider(color = c.separator, thickness = 0.5.dp)
        }
    }
    Box(Modifier.testTag("year-restart")) {
        TextButton(onClick = { confirmRestart = true }) { Text("Start the plan again", fontFamily = SpaceGrotesk, color = LocalJohnColors.current.tint) }
    }
    if (confirmRestart) AlertDialog(onDismissRequest = { confirmRestart = false },
        title = { JohnText("Start the plan again?", size = 20) },
        text = { JohnText("You choose again how to begin. The days you read stay marked.") },
        confirmButton = { TextButton(onClick = { confirmRestart = false; store.startYear(null) }) { Text("Start again") } },
        dismissButton = { TextButton(onClick = { confirmRestart = false }) { Text("Cancel") } })
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

/** One day's reading: the paragraphs from the library, then "Mark as read". Day 8 and later show the purchase page without the library (Y4). */
@Composable
fun YearDayScreen(dayNumber: Int, repo: JohnRepository, store: JohnStore, navigate: (String) -> Unit, back: () -> Unit) {
    val plan = remember(repo) { repo.yearPlan() }
    val day = plan?.day(dayNumber)
    val context = LocalContext.current
    val billing = remember { FathersBilling.get(context) }
    LaunchedEffect(Unit) { billing.start() }
    val locked = YearPlanSchedule.isLocked(dayNumber, plan?.freeDays ?: 7, billing.isUnlocked)
    val blocks = remember(dayNumber, locked) {
        if (day == null || locked) emptyList() else runCatching {
            day.readings.flatMap { reading ->
                val section = repo.workSection(reading.workId, reading.section)
                val upper = minOf(reading.toParagraph, section.paragraphs.size - 1)
                val heading = if (reading.fromParagraph == 0) listOf(YearBlock(true, section.title)) else emptyList()
                heading + (if (reading.fromParagraph <= upper) section.paragraphs.subList(reading.fromParagraph, upper + 1) else emptyList())
                    .map { it.trim() }
                    .filter { it.isNotEmpty() && !it.all { ch -> ch in "—–-" } && it != section.title.trim() }
                    .map { YearBlock(isHeading(it), it) }
            }
        }.getOrDefault(emptyList())
    }
    val eyebrow = day?.let { listOfNotNull("Day $dayNumber", YearText.date(it.date), it.feast).joinToString(" · ") } ?: "Day $dayNumber"
    JohnPage(day?.title ?: YearText.NAME, eyebrow, day?.let { "${it.author} · ${it.minutes} min" } ?: "", back) {
        when {
            day == null -> JohnText("This day is not in the plan.", dim = true)
            locked -> FathersUnlockPanel(sampleNotice = YearText.LOCKED, totals = libraryTotals(repo))
            blocks.isEmpty() -> JohnText("This reading could not be opened. Try again, or open it in the library.", dim = true)
            else -> {
                Column(Modifier.testTag("year-day-text"), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    blocks.forEach { block ->
                        if (block.heading) Text(block.text, Modifier.semantics { heading() }, fontFamily = SpaceGrotesk, fontWeight = FontWeight.SemiBold,
                            fontSize = 15.sp, lineHeight = 22.sp, color = LocalJohnColors.current.text)
                        else SelectionContainer { JohnText(block.text, serif = true, size = 18) }
                    }
                }
                val isRead = dayNumber in store.yearDaysRead
                Box(Modifier.testTag("year-mark-read")) {
                    JohnButton(if (isRead) "Read · Mark as not read" else "Mark as read") { store.setYearDayRead(dayNumber, !isRead) }
                }
                val collection = day.readings.firstOrNull()?.let { FathersAccess.collectionId(it.workId) }
                repo.workAuthors().firstOrNull { it.id == collection }?.let { JohnText(it.attribution, dim = true, size = 14) }
            }
        }
        day?.readings?.firstOrNull()?.let { first ->
            Box(Modifier.testTag("year-open-library")) { JohnRow("Open in the library", day.work) { navigate("work/${first.workId}/${first.section}") } }
        }
        plan?.day(dayNumber + 1)?.let { next ->
            Box(Modifier.testTag("year-next-day")) { JohnRow("Next: Day ${next.day}", "${next.author}, ${next.title}") { navigate("year-day/${next.day}") } }
        }
    }
}
