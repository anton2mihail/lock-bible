package com.john.bible.ui

import androidx.compose.foundation.Canvas
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import android.speech.tts.TextToSpeech
import android.speech.tts.Voice
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.john.bible.data.*

@Composable internal fun ReadingChoices(store: JohnStore) {
    JohnText("Reading mode", size = 13, dim = true)
    ChoiceChips(listOf("pages" to "Pages", "scroll" to "Scroll"), store.readerMode) { store.readerMode = it }
    JohnText("Text size", size = 13, dim = true)
    ChoiceChips(listOf("16" to "Small", "18" to "Default", "21" to "Large", "24" to "Extra large"), store.textSize.toInt().toString()) { store.textSize = it.toFloat() }
    JohnText("Line spacing", size = 13, dim = true)
    ChoiceChips(listOf("1.3" to "Compact", "1.55" to "Comfortable", "1.8" to "Relaxed"), store.lineSpacing.toString()) { store.lineSpacing = it.toFloat() }
    JohnText("Scripture typeface", size = 13, dim = true)
    ChoiceChips(listOf("serif" to "Serif", "sans" to "Sans"), store.fontFamily) { store.fontFamily = it }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { JohnText("Verse numbers"); Switch(store.showVerseNumbers, { store.showVerseNumbers = it }) }
    JohnText("Layout", size = 13, dim = true)
    ChoiceChips(listOf("paragraphs" to "Paragraphs", "verses" to "Verse by verse"), store.readerLayout) { store.readerLayout = it }
    JohnText("Appearance", size = 13, dim = true)
    ChoiceChips(listOf("system" to "System", "light" to "Light", "dark" to "Dark"), store.appearance) { store.appearance = it }
}

@Composable fun SettingsScreen(repo: JohnRepository, store: JohnStore, navigate: (String) -> Unit) {
    val uri=LocalUriHandler.current
    ReadingPage("Settings") {
        JohnText("Reading", size = 16, dim = true)
        JohnPanel { ReadingChoices(store) }
        JohnText("Reading progress", size = 16, dim = true)
        JohnPanel {
            JohnRow("Your reading", "${store.readChapterCount()} chapters read · ${store.streak()} day streak") { navigate("progress") }
            JohnRow("Daily reading reminder", "Choose a delivery time") { navigate("reading-reminder") }
        }
        JohnText("Read aloud", size = 16, dim = true)
        JohnPanel { ReadAloudChoices(store) }
        JohnText("Translation", size = 16, dim = true)
        JohnPanel {
            editionTitles.forEach { (id, title) -> JohnRow(title, if (store.edition == id) "Selected ✓" else "") { store.edition = id } }
            JohnText("3 complete Catholic editions are available offline. Your choice also controls the rotating verse and widget.", size = 12, dim = true)
        }
        JohnText("Verse pool", size = 16, dim = true)
        JohnPanel {
            ChoiceChips(listOf("full" to "Full Bible", "ot" to "Old Testament", "nt" to "New Testament"), store.scope) { store.scope = it }
            JohnText("Choose the part of Scripture for the rotating verse. Old Testament includes the deuterocanonical books.", size = 12, dim = true)
        }
        JohnText("Verse rotation", size = 16, dim = true)
        JohnPanel {
            listOf(10 to "Every 10 minutes", 15 to "Every 15 minutes", 30 to "Every 30 minutes", 60 to "Every hour", 180 to "Every 3 hours", 360 to "Every 6 hours", 720 to "Every 12 hours", 1440 to "Once a day").forEach { (minutes, title) -> JohnRow(title, if (store.intervalMinutes == minutes) "Selected ✓" else "") { store.intervalMinutes = minutes } }
            JohnText("How often the Verse of the Moment and your widget change.", size = 12, dim = true)
        }
        JohnText("Widgets", size = 16, dim = true)
        JohnPanel { JohnText("1. Touch and hold an empty area on your home screen.\n2. Tap Widgets.\n3. Choose John 1:1.\n4. Add Daily Verse or Daily Reading.", size = 15) }
        JohnText("Notifications", size = 16, dim = true)
        JohnPanel {
            JohnRow("Saints, feasts & daily readings", "Choose a delivery time and turn notices on or off") { navigate("calendar-notifications") }
            JohnRow("Rosary reminder", "Set a daily time for prayer") { navigate("rosary-reminder") }
        }
        JohnPanel { JohnRow("Privacy policy", "How John handles your notes and device services") { uri.openUri("https://anton2mihail.github.io/lock-bible/privacy.html") } }
        JohnText("John 1:1 · Scripture & Prayer", size = 16, dim = true)
        JohnPanel {
            JohnText("A little closer to God, every day.")
            JohnText("United States · Roman Rite. Local observances can differ.", size = 14)
            JohnText("Paintings are public-domain works from Wikimedia Commons. The app icon is a detail of the 6th-century Christ Pantocrator icon at Sinai. Prayers, novenas, and teachings are quoted from the sources named beside them. The app adds no prayers or commentary of its own.", size = 14)
            JohnText("Reading metadata: catholic-readings-api (MIT). Celebration calendar: romcal (MIT). Reflections stay on this device. Confession notes are never saved.", size = 14)
            JohnText("World English Bible Catholic Edition, Douay–Rheims, and Latin Vulgate Scripture texts are in the public domain.", size = 12, dim = true)
        }
    }
}

@Composable fun ReadingProgressScreen(store: JohnStore, navigate: (String) -> Unit, back: () -> Unit) {
    var reset by remember { mutableStateOf(false) }
    ReadingPage("Your reading", back = back) {
        JohnPanel {
            Row(horizontalArrangement = Arrangement.spacedBy(28.dp)) {
                ReadingRing("All books", store.readChapterCount(), if (store.edition == "web-ce") 1328 else 1334)
                ReadingRing("John", store.completedChapters.count { it.startsWith("JHN/") }, 21)
            }
            JohnText("${store.readChapterCount()} chapters read", serif = true, size = 28)
            JohnText("${store.streak()} day reading streak", dim = true)
            JohnText("A chapter counts as read when you reach its end or tap Mark read.", size = 14, dim = true)
            ReaderButton("Read the Bible") { navigate("read") }
        }
        JohnText("Reading plans", size = 16, dim = true)
        JohnPanel {
            JohnText("Read John a little each day", serif = true, size = 24)
            listOf("john-21" to "John in 21 days", "john-7" to "John in 7 days").forEach { (id, title) ->
                ReaderButton(if (store.planId == id) "✓ $title" else "Start: $title") { store.startPlan(id) }
            }
            if (store.planId != null) {
                val day = (store.planDay() - 1).coerceIn(0, (if (store.planId == "john-7") 7 else 21) - 1)
                val count = if (store.planId == "john-7") 3 else 1
                val first = (day * count + 1).coerceAtMost(21)
                val last = (first + count - 1).coerceAtMost(21)
                JohnText("Day ${day + 1} · John $first${if (last > first) "–$last" else ""}", dim = true)
                ReaderButton("Read now") { navigate("reader/${store.edition}/JHN/$first") }
                ReaderButton("Stop plan") { store.startPlan(null) }
            }
        }
        JohnPanel { JohnRow("Daily reading reminder", "Choose a delivery time") { navigate("reading-reminder") }; ReaderButton("Reset reading progress") { reset = true } }
    }
    if (reset) AlertDialog(onDismissRequest = { reset = false }, title = { JohnText("Reset reading progress?", size = 24) }, text = { JohnText("This clears chapters read and the current reading plan.") }, confirmButton = { TextButton(onClick = { store.resetProgress(); reset = false }) { Text("Reset") } }, dismissButton = { TextButton(onClick = { reset = false }) { Text("Cancel") } })
}

@Composable private fun ReadAloudChoices(store: JohnStore) {
    val context = LocalContext.current
    var voices by remember { mutableStateOf(emptyList<Voice>()) }
    var status by remember { mutableStateOf("Opening installed voices…") }
    DisposableEffect(context, store.edition) {
        var engine: TextToSpeech? = null
        val main = android.os.Handler(android.os.Looper.getMainLooper())
        var disposed = false
        engine = TextToSpeech(context.applicationContext) { result -> main.post {
            if (!disposed) {
                voices = if (result == TextToSpeech.SUCCESS) engine?.voices?.filter { !it.isNetworkConnectionRequired && "notInstalled" !in it.features && it.locale.language == if (store.edition == "vulgate") "la" else "en" }?.sortedBy { it.name } ?: emptyList() else emptyList()
                status = if (result == TextToSpeech.SUCCESS) "Read aloud uses the speech service on this device." else "The device speech service is not available."
            }
        } }
        onDispose { disposed = true; engine?.shutdown(); main.removeCallbacksAndMessages(null) }
    }
    JohnText("Reading speed", size = 13, dim = true)
    ChoiceChips(listOf("0.75" to "0.75×", "1.0" to "1×", "1.25" to "1.25×", "1.5" to "1.5×"), store.readAloudRate.toString()) { store.readAloudRate = it.toFloat() }
    JohnText("Voice", size = 13, dim = true)
    ChoiceChips(listOf("" to "Device default") + voices.map { it.name to "${it.locale.displayName} · ${it.name}" }, store.readAloudVoice) { store.readAloudVoice = it }
    JohnText(status, size = 12, dim = true)
}

@Composable private fun ReadingRing(title: String, read: Int, total: Int) {
    val colors = LocalJohnColors.current
    val fraction = (read.toFloat() / total.coerceAtLeast(1)).coerceIn(0f, 1f)
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.semantics { contentDescription = "$title reading progress. $read of $total chapters read." }) {
        Box(Modifier.size(70.dp), contentAlignment = Alignment.Center) {
            Canvas(Modifier.fillMaxSize().padding(4.dp)) {
                drawCircle(colors.border, style = Stroke(7.dp.toPx()))
                drawArc(colors.tint, -90f, fraction * 360, false, style = Stroke(7.dp.toPx(), cap = StrokeCap.Round))
            }
            JohnText("${(fraction * 100).toInt()}%", size = 14)
        }
        JohnText(title, size = 13)
        JohnText("$read of $total", size = 12, dim = true)
    }
}
