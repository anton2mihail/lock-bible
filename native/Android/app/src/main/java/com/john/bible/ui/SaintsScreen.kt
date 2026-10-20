package com.john.bible.ui

import android.app.DatePickerDialog
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import com.john.bible.data.JohnRepository
import com.john.bible.data.SaintCommemoration
import com.john.bible.data.SaintsCalendar
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.time.MonthDay
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun SaintsScreen(repo: JohnRepository, back: () -> Unit) {
    var date by rememberSaveable { mutableStateOf(LocalDate.now().toString()) }
    var query by rememberSaveable { mutableStateOf("") }
    var tradition by rememberSaveable { mutableStateOf("vatican") }
    var limit by remember(query, tradition) { mutableIntStateOf(50) }
    var retry by remember { mutableIntStateOf(0) }
    var catalogs by remember { mutableStateOf<List<SaintsCalendar>?>(null) }
    var failed by remember { mutableStateOf(false) }
    LaunchedEffect(repo, retry) {
        failed = false
        try { catalogs = withContext(Dispatchers.IO) { repo.saintsCalendars() } }
        catch (_: Exception) { failed = true }
    }
    val context = LocalContext.current
    val day = LocalDate.parse(date)
    val catalog = catalogs?.firstOrNull { it.tradition == tradition }
    val results = remember(catalog, date, query) {
        if (query.isBlank()) catalog?.on(day).orEmpty()
        else catalog?.entries?.filter { it.name.contains(query.trim(), ignoreCase = true) }.orEmpty()
    }
    JohnPage("Saints & feast days", "The communion of saints",
        "Discover the witnesses of faith, day by day.", back) {
        Column {
            listOf("vatican" to "Vatican News", "byzantine" to "Byzantine Catholic · Ruthenian").forEach { (key, title) ->
                FilterChip(selected = tradition == key, onClick = { tradition = key }, label = { Text(title) })
            }
        }
        OutlinedTextField(query, { query = it }, Modifier.fillMaxWidth(),
            label = { Text("Find a saint across the year") }, singleLine = true)
        JohnButton(day.format(DateTimeFormatter.ofPattern("MMMM d, yyyy", Locale.US))) {
            DatePickerDialog(context, { _, year, month, dayOfMonth ->
                date = LocalDate.of(year, month + 1, dayOfMonth).toString()
            }, day.year, day.monthValue - 1, day.dayOfMonth).show()
        }
        if (catalog != null) {
            JohnText(catalog.coverage, size = 14, dim = true)
            if (results.isEmpty()) JohnText(if (query.isBlank()) "This source has no entry for this date."
                else "No saints match this name. Try another name.", dim = true)
            results.take(limit).forEach { SaintLifeCard(it, catalog.sourceName, showDate = true) }
            if (results.size > limit) JohnButton("Show more saints") { limit += 50 }
            JohnText("Source checked ${catalog.retrievedOn}. Accounts use short excerpts or English summaries. Summaries are not official translations. Open the source for the full account.", size = 14, dim = true)
        } else if (failed) {
            JohnText("The saints calendar could not be loaded.")
            JohnButton("Try again") { retry++ }
        } else CircularProgressIndicator()
    }
}

@Composable
fun SaintsDaySection(repo: JohnRepository, day: LocalDate, browse: () -> Unit) {
    var catalogs by remember(repo) { mutableStateOf<List<SaintsCalendar>>(emptyList()) }
    var failed by remember { mutableStateOf(false) }
    LaunchedEffect(repo) {
        try { catalogs = withContext(Dispatchers.IO) { repo.saintsCalendars() } }
        catch (_: Exception) { failed = true }
    }
    Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
        JohnText("Saints remembered today", size = 20)
        catalogs.forEach { catalog ->
            JohnText(catalog.title, size = 18)
            val saints = catalog.on(day)
            if (saints.isEmpty()) JohnText("This source has no entry for this date.", dim = true)
            saints.forEach { SaintLifeCard(it, catalog.sourceName, showDate = false) }
        }
        if (failed) JohnText("The saints calendar could not be loaded. Open the calendar to try again.", dim = true)
        JohnRow("Browse saints & feast days", "Choose a date or search by name", browse)
    }
}

@Composable
private fun SaintLifeCard(saint: SaintCommemoration, sourceName: String, showDate: Boolean) {
    val uri = LocalUriHandler.current
    var failed by remember(saint.id) { mutableStateOf(false) }
    JohnPanel {
        if (showDate) JohnText(MonthDay.parse("--${saint.monthDay}").atYear(2024)
            .format(DateTimeFormatter.ofPattern("MMMM d", Locale.US)), size = 14, dim = true)
        JohnText(saint.name, size = 24, serif = true)
        if (!saint.summary.isNullOrBlank()) {
            SelectionContainer { JohnText(saint.summary) }
            val language = when (saint.sourceLanguage) { "it" -> "Italian"; "de" -> "German"; else -> "English" }
            JohnText("English summary · $language Vatican source", size = 14, dim = true)
        } else if (saint.excerpt.isNotBlank()) SelectionContainer { JohnText("“${saint.excerpt}”") }
        else JohnText("The source lists this commemoration without a short life account.", dim = true)
        saint.observanceNote?.let { JohnText(it, size = 14, dim = true) }
        val source = if (java.net.URI(saint.sourceURL).host == "www.vatican.va") "The Holy See" else sourceName
        JohnRow("Read at $source ↗") {
            failed = runCatching { uri.openUri(saint.sourceURL) }.isFailure
        }
        if (saint.calendarURL != saint.sourceURL) JohnRow("View calendar entry ↗") {
            failed = runCatching { uri.openUri(saint.calendarURL) }.isFailure
        }
        if (failed) JohnText("The source could not be opened. Check your browser and connection.", dim = true)
    }
}
