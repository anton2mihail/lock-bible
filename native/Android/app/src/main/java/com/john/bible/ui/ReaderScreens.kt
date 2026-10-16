package com.john.bible.ui

import android.content.Intent
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.ScrollState
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withLink
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.john.bible.data.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.delay
import java.util.Locale

internal val editionTitles = linkedMapOf("web-ce" to "World English Bible · Catholic Edition", "douay-rheims" to "Douay–Rheims", "vulgate" to "Latin Vulgate")
internal fun editionShort(edition: String) = when (edition) { "web-ce" -> "WEB"; "douay-rheims" -> "D–R"; else -> "Vulgate" }
internal fun readerRoute(hit: SearchHit) = "reader/${hit.edition}/${hit.book}/${hit.chapter}/${hit.label.substringBefore('–').substringBefore('-')}"
internal fun sharePassage(context: android.content.Context, text: String) {
    context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply { type = "text/plain"; putExtra(Intent.EXTRA_TEXT, text) }, "Share passage"))
}
internal fun shareText(hit: SearchHit) = "${hit.text}\n\n${hit.bookName} ${hit.chapter}:${hit.label} (${editionShort(hit.edition)})"

@Composable internal fun ChoiceChips(options: List<Pair<String, String>>, selected: String, choose: (String) -> Unit) {
    val colors = LocalJohnColors.current
    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        options.forEach { (value, title) ->
            Box(Modifier.heightIn(min = 44.dp).background(if (selected == value) colors.tint else colors.card, RoundedCornerShape(10.dp))
                .border(1.dp, colors.border, RoundedCornerShape(10.dp)).semantics { this.selected = selected == value; role = Role.Button }.clickable { choose(value) }.padding(horizontal = 14.dp, vertical = 12.dp)) {
                Text(title, color = if (selected == value) colors.background else colors.text, fontFamily = SpaceGrotesk, fontSize = 14.sp)
            }
        }
    }
}

@Composable fun ReaderScreen(repo: JohnRepository, store: JohnStore, navigate: (String) -> Unit, initialRoute: String? = null) {
    val parts = remember(initialRoute) { initialRoute?.split('/') ?: emptyList() }
    var edition by rememberSaveable(initialRoute) { mutableStateOf(parts.getOrNull(1) ?: store.edition) }
    var bookCode by rememberSaveable(initialRoute) { mutableStateOf(parts.getOrNull(2) ?: "") }
    var chapter by rememberSaveable(initialRoute) { mutableIntStateOf(parts.getOrNull(3)?.toIntOrNull() ?: 0) }
    var contextLabel by rememberSaveable(initialRoute) { mutableStateOf(parts.getOrNull(4) ?: "") }
    var books by remember { mutableStateOf(emptyList<BibleBook>()) }
    var verses by remember { mutableStateOf(emptyList<Verse>()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var from by rememberSaveable { mutableStateOf<Int?>(null) }
    var to by rememberSaveable { mutableStateOf<Int?>(null) }
    var appearance by remember { mutableStateOf(false) }
    var goTo by remember { mutableStateOf(false) }
    var noteHit by remember { mutableStateOf<SearchHit?>(null) }
    var feedback by remember { mutableStateOf("") }
    val context = LocalContext.current
    val colors = LocalJohnColors.current
    val speech = remember { ReaderSpeech.get(context, store) }
    val currentSpeech = speech.matches(edition, bookCode, chapter)
    val chapterScroll = rememberSaveable(edition, bookCode, chapter, saver = ScrollState.Saver) {
        ScrollState(if (initialRoute == null && store.readerBook == bookCode && store.readerChapter == chapter) store.readerScrollIndex else 0)
    }
    val scrollMode = store.readerMode == "scroll"
    LaunchedEffect(edition, bookCode, chapter, initialRoute, scrollMode) {
        if (scrollMode && initialRoute == null && bookCode.isNotBlank() && chapter > 0) snapshotFlow { chapterScroll.value }.collectLatest { value ->
            delay(300)
            store.saveReaderLocation(bookCode, chapter, value)
        }
    }
    LaunchedEffect(edition, bookCode, chapter, verses, scrollMode) {
        if (scrollMode && verses.isNotEmpty()) snapshotFlow { chapterScroll.value to chapterScroll.maxValue }.collect { (value, max) ->
            if (value > 0 && value == max) store.markChapterRead(edition, bookCode, chapter)
        }
    }
    LaunchedEffect(store.edition) { if (initialRoute == null) edition = store.edition }
    LaunchedEffect(edition) {
        loading = true
        error = null
        runCatching { withContext(Dispatchers.IO) { repo.books(edition) } }.onSuccess { books = it }.onFailure { error = "Scripture could not be opened. Please try again." }
        loading = false
    }
    var loadedChapter by rememberSaveable(initialRoute) { mutableStateOf("") }
    LaunchedEffect(edition, bookCode, chapter) {
        val identity="$edition/$bookCode/$chapter"
        if(loadedChapter!=identity) { from = null; to = null; feedback = "" }
        loadedChapter=identity; verses = emptyList()
        if (bookCode.isNotEmpty() && chapter > 0) {
            loading = true
            error = null
            runCatching { withContext(Dispatchers.IO) { repo.chapter(edition, bookCode, chapter) } }
                .onSuccess { verses = it; if (initialRoute == null) store.saveReaderLocation(bookCode, chapter, chapterScroll.value) }
                .onFailure { error = "This chapter could not be opened. Please try again." }
            loading = false
        }
    }
    LaunchedEffect(verses,contextLabel) { if(verses.isNotEmpty() && contextLabel.isNotBlank()) { delay(600);contextLabel="" } }
    val book = books.firstOrNull { it.code == bookCode }
    val back: () -> Unit = { if (initialRoute != null && chapter > 0) navigate("back") else if (chapter > 0) chapter = 0 else bookCode = "" }
    BackHandler(bookCode.isNotEmpty()) { back() }
    val lower = minOf(from ?: -1, to ?: from ?: -1)
    val upper = maxOf(from ?: -1, to ?: from ?: -1)
    val selected = if (book != null && lower >= 0 && upper < verses.size) {
        val label = if (lower == upper) verses[lower].label else "${verses[lower].label}–${verses[upper].label}"
        SearchHit(edition, book.code, book.name, chapter, label, verses.subList(lower, upper + 1).joinToString(" ") { it.text })
    } else null
    if (bookCode.isEmpty()) {
        ReadingPage("Read the Bible") {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { ReaderButton("Search") { navigate("search") }; ReaderButton(editionShort(edition)) { goTo = true } }
            if (store.readerBook.isNotEmpty()) {
                val previous = books.firstOrNull { it.code == store.readerBook }
                if (previous != null) { JohnText("Continue reading", dim = true, size = 13); JohnPanel { JohnRow("${previous.name} ${store.readerChapter}") { bookCode = previous.code; chapter = store.readerChapter } } }
            }
            JohnText("The Church Fathers", dim = true, size = 13)
            JohnPanel { JohnRow("The Fathers and Doctors", "Works available offline") { navigate("works") } }
            if (loading) JohnText("Opening Scripture…", dim = true)
            error?.let { JohnText(it) }
            listOf("OT" to "Old Testament", "deutero" to "Deuterocanonical books", "NT" to "New Testament").forEach { (testament, title) ->
                val group = books.filter { it.testament.equals(testament, true) }
                if (group.isNotEmpty()) {
                    JohnText(title, size = 13, dim = true)
                    group.forEach { b -> JohnRow(b.name, "${b.chapters} chapters") { bookCode = b.code; chapter = 0 } }
                }
            }
            if (books.isNotEmpty() && books.none { it.testament.equals("OT", true) || it.testament.equals("NT", true) || it.testament == "old" || it.testament == "new" }) books.forEach { b -> JohnRow(b.name, "${b.chapters} chapters") { bookCode = b.code } }
        }
    } else if (chapter == 0) {
        ReadingPage(book?.name ?: "Choose a chapter", back = back) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { ReaderButton("Search") { navigate("search") }; ReaderButton("Go to") { goTo = true } }
            book?.let { b ->
                val read = (1..b.chapters).count { store.isChapterRead(edition, b.code, it) }
                JohnText("Choose a chapter", dim = true)
                JohnText("$read of ${b.chapters} read", dim = true, size = 13)
                (1..b.chapters).chunked(5).forEach { row ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        row.forEach { number ->
                            Box(Modifier.weight(1f).heightIn(min = 54.dp).background(colors.card, RoundedCornerShape(12.dp)).border(1.dp, colors.border, RoundedCornerShape(12.dp)).clickable { chapter = number; contextLabel = "" }.padding(14.dp).semantics { contentDescription = "${b.name} chapter $number${if (store.isChapterRead(edition, b.code, number)) ", read" else ""}" }) {
                                JohnText("$number${if (store.isChapterRead(edition, b.code, number)) " ✓" else ""}")
                            }
                        }
                        repeat(5 - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        }
    } else if (!scrollMode) {
        BackHandler(selected != null) { from = null; to = null }
        val spoken = speech.index.takeIf { currentSpeech && speech.active }
        PagedReader(
            repo, store, edition, books, bookCode, chapter,
            initialAnchor = {
                when {
                    contextLabel.isNotBlank() -> PageAnchor(contextLabel)
                    initialRoute == null && store.readerBook == bookCode && store.readerChapter == chapter && store.readerVerse.isNotBlank() -> PageAnchor(store.readerVerse, store.readerVerseOffset)
                    else -> PageAnchor.First
                }
            },
            lower = lower, upper = upper, spoken = spoken, selecting = from != null,
            tapVerse = { index -> if (from == null) { from = index; to = null } else if (to == null && from != index) to = index else { from = null; to = null } },
            holdVerse = { index -> from = index; to = null },
            clearSelection = { from = null; to = null },
            openChapter = { code, number -> bookCode = code; chapter = number; contextLabel = ""; from = null; to = null },
            savePosition = { key, anchor -> if (initialRoute == null) store.saveReaderAnchor(key.book, key.chapter, anchor.label, anchor.offset) },
            markRead = { key -> store.markChapterRead(key.edition, key.book, key.chapter) },
            chrome = PagedChrome(
                title = "${book?.name ?: bookCode} $chapter", subtitle = editionTitles[edition] ?: edition, back = back,
                search = { navigate("search") }, goTo = { goTo = true }, appearance = { appearance = true },
                fathers = { navigate("commentary/$bookCode/$chapter") }, reading = currentSpeech && speech.playing,
                readAloud = { start -> if (currentSpeech && speech.playing) speech.pause() else if (currentSpeech && speech.active) speech.resume() else speech.start(verses, from ?: start, edition, bookCode, book?.name ?: bookCode, chapter) },
                isRead = store.isChapterRead(edition, bookCode, chapter), toggleRead = { store.setChapterRead(edition, bookCode, chapter, !store.isChapterRead(edition, bookCode, chapter)) },
                message = speech.error
            ),
            selectionBar = if (selected == null) null else { { PassageToolbar(selected, store, feedback, { feedback = it }, { noteHit = selected }, { from = null; to = null }, navigate) } }
        )
    } else {
        ReadingPage("${book?.name ?: bookCode} $chapter", eyebrow = editionTitles[edition] ?: edition, back = back, scroll = chapterScroll, footer = if (selected == null) null else { {
            PassageToolbar(selected, store, feedback, { feedback = it }, { noteHit = selected }, { from = null; to = null }, navigate)
        } }) {
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ReaderButton("Go to") { goTo = true }; ReaderButton("Search") { navigate("search") }; ReaderButton("Aa") { appearance = true }; ReaderButton("The Fathers") { navigate("commentary/$bookCode/$chapter") }
                ReaderButton(if (currentSpeech && speech.playing) "Pause" else "Read aloud") {
                    if (currentSpeech && speech.playing) speech.pause() else if (currentSpeech && speech.active) speech.resume() else speech.start(verses, from ?: 0, edition, bookCode, book?.name ?: bookCode, chapter)
                }
            }
            if (currentSpeech && speech.active) Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ReaderButton("Previous verse") { speech.previous() }; ReaderButton("Next verse") { speech.next() }; ReaderButton("Stop") { speech.stop() }
            }
            if (speech.error.isNotBlank()) JohnText(speech.error, size = 13, dim = true)
            JohnText("Tap a verse to select it. Tap another verse to select a range.", dim = true, size = 12)
            if (loading) JohnText("Opening chapter…", dim = true)
            error?.let { JohnText(it) }
            if (store.readerLayout == "paragraphs") {
                ScriptureParagraphs(verses, store, edition, bookCode, book?.name ?: bookCode, chapter, lower, upper, speech.index.takeIf { currentSpeech && speech.active }, contextLabel) { index ->
                    if (from == null) { from = index; to = null } else if (to == null && from != index) to = index else { from = null; to = null }
                }
            } else verses.forEachIndexed { index, verse ->
                val hit = SearchHit(edition, bookCode, book?.name ?: bookCode, chapter, verse.label, verse.text)
                val selectedVerse = index in lower..upper && lower >= 0
                val highlight = store.highlightColor(hit)
                val selectedColor = when {
                    selectedVerse -> colors.tint.copy(alpha = .2f)
                    currentSpeech && speech.active && speech.index == index -> colors.tint.copy(alpha = .12f)
                    highlight != null -> highlightColor(highlight).copy(alpha = .24f)
                    else -> Color.Transparent
                }
                val bring = remember(edition, bookCode, chapter, verse.label) { BringIntoViewRequester() }
                LaunchedEffect(contextLabel, verses) { if (contextLabel == verse.label && contextLabel.isNotEmpty()) bring.bringIntoView() }
                Column(Modifier.fillMaxWidth().bringIntoViewRequester(bring).background(selectedColor, RoundedCornerShape(6.dp)).clickable {
                    if (from == null) { from = index; to = null } else if (to == null && from != index) to = index else { from = null; to = null }
                }.padding(vertical = 7.dp, horizontal = 3.dp).testTag("reader-verse-${verse.label}").semantics { contentDescription = "Verse ${verse.label}. ${verse.text}${if (selectedVerse) ". Selected" else ""}" }) {
                    Text(if (store.showVerseNumbers) "${verse.label}  ${verse.text}" else verse.text,
                        fontFamily = if (store.fontFamily == "serif") Lora else SpaceGrotesk, fontSize = store.textSize.sp, lineHeight = (store.textSize * store.lineSpacing).sp, color = colors.text)
                    if (store.isBookmarked(hit)) JohnText("Bookmarked", size = 11, dim = true)
                    if (store.noteFor(hit).isNotBlank()) JohnText("Note", size = 11, dim = true)
                }
            }
            if (!loading && verses.isNotEmpty()) {
                ReaderButton(if (store.isChapterRead(edition, bookCode, chapter)) "✓ Read" else "Mark read") { store.setChapterRead(edition, bookCode, chapter, !store.isChapterRead(edition, bookCode, chapter)) }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    if (chapter > 1) ReaderButton("‹ Previous") { chapter--; contextLabel = ""; from = null; to = null }
                    if (book != null && chapter < book.chapters) ReaderButton("Next ›") { chapter++; contextLabel = ""; from = null; to = null }
                }
            }
        }
    }
    if (appearance) AlertDialog(onDismissRequest = { appearance = false }, title = { JohnText("Reading", size = 24) }, text = { Column(verticalArrangement = Arrangement.spacedBy(16.dp)) { ReadingChoices(store) } }, confirmButton = { TextButton(onClick = { appearance = false }) { Text("Done") } })
    if (goTo) AlertDialog(onDismissRequest = { goTo = false }, title = { JohnText("Translation", size = 24) }, text = { Column { editionTitles.forEach { (id, title) -> JohnRow(title, if (id == edition) "Selected" else "") { edition = id; if (initialRoute == null) store.edition = id; goTo = false } }; JohnRow("Choose a book") { bookCode = ""; chapter = 0; goTo = false } } }, confirmButton = { TextButton(onClick = { goTo = false }) { Text("Done") } })
    noteHit?.let { hit -> NoteDialog(hit, store) { noteHit = null } }
}

internal fun highlightColor(color: String) = when (color) { "green" -> Color(0xff84ad72); "blue" -> Color(0xff6d9bb5); "pink" -> Color(0xffd18499); "purple" -> Color(0xffab84bd); else -> Color(0xffcba94f) }

@Composable internal fun NoteDialog(hit: SearchHit, store: JohnStore, close: () -> Unit) { NoteEditorDialog(hit,store,close) }

/** Uses the device's installed speech service. Each verse has its own utterance ID. */
internal class ReaderSpeech private constructor(context: android.content.Context, private var store: JohnStore) {
    var playing by mutableStateOf(false)
    var active by mutableStateOf(false)
    var index by mutableIntStateOf(0)
    var error by mutableStateOf("")
    private var verses: List<Verse> = emptyList()
    var edition by mutableStateOf("web-ce"); private set
    var bookCode by mutableStateOf(""); private set
    var bookName by mutableStateOf(""); private set
    var chapter by mutableIntStateOf(1); private set
    val label: String get() = verses.getOrNull(index)?.label ?: ""
    fun matches(edition: String, code: String, chapter: Int) = active && this.edition == edition && bookCode == code && this.chapter == chapter
    private var ready = false
    private var generation = 0
    private val main = android.os.Handler(android.os.Looper.getMainLooper())
    private var engine: TextToSpeech? = null
    private val audioManager=context.applicationContext.getSystemService(android.media.AudioManager::class.java)
    private val focus=android.media.AudioFocusRequest.Builder(android.media.AudioManager.AUDIOFOCUS_GAIN)
        .setAudioAttributes(android.media.AudioAttributes.Builder().setUsage(android.media.AudioAttributes.USAGE_MEDIA).setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH).build())
        .setOnAudioFocusChangeListener { change -> if(change==android.media.AudioManager.AUDIOFOCUS_LOSS || change==android.media.AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) pause() }.build()
    private fun requestFocus():Boolean = audioManager.requestAudioFocus(focus)==android.media.AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    init {
        engine = TextToSpeech(context.applicationContext) { result ->
            main.post { ready = result == TextToSpeech.SUCCESS; if (!ready) { error = "The device speech service is not available."; stop() }; if (ready && active && playing) speak() }
        }
        engine?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {}
            override fun onError(utteranceId: String?) { main.post { if (utteranceId == "$generation:$index") { error = "This verse could not be read aloud."; stop() } } }
            override fun onDone(utteranceId: String?) { main.post { if (utteranceId == "$generation:$index" && playing) { if (index < verses.lastIndex) { index++; speak() } else stop() } } }
        })
    }
    fun start(items: List<Verse>, from: Int, translation: String, code: String, name: String, number: Int) { error = ""; bookCode = code; bookName = name; chapter = number; verses = items; index = from.coerceIn(0, (items.size - 1).coerceAtLeast(0)); edition = translation; active = items.isNotEmpty(); playing = active && requestFocus(); if (ready && playing) speak() }
    private fun speak() {
        if (!ready || index !in verses.indices) return
        generation++
        val language = if (edition == "vulgate") Locale.forLanguageTag("la") else Locale.US
        val voices=engine?.voices.orEmpty().filter { !it.isNetworkConnectionRequired && "notInstalled" !in it.features && it.locale.language==language.language }
        val voice=voices.firstOrNull { it.name==store.readAloudVoice } ?: voices.firstOrNull { it.locale==language } ?: voices.sortedByDescending { it.quality }.firstOrNull()
        if(voice==null || engine?.setVoice(voice)!=TextToSpeech.SUCCESS) {
            error="Install an offline ${if(edition=="vulgate") "Latin" else "English"} speech voice in your device settings."
            stop()
            return
        }
        engine?.setSpeechRate(store.readAloudRate)
        if(engine?.speak(verses[index].text, TextToSpeech.QUEUE_FLUSH, null, "$generation:$index") != TextToSpeech.SUCCESS) {
            error="This verse could not be read aloud."
            stop()
        }
    }
    fun pause() { playing = false; generation++; engine?.stop(); audioManager.abandonAudioFocusRequest(focus) }
    fun resume() { playing = active && requestFocus(); if(playing)speak() }
    fun previous() { if (index > 0) { index--; playing = requestFocus(); if(playing)speak() } }
    fun next() { if (index < verses.lastIndex) { index++; playing = requestFocus(); if(playing)speak() } }
    fun stop() { generation++; playing = false; active = false; engine?.stop(); audioManager.abandonAudioFocusRequest(focus) }
    fun close() { stop(); engine?.shutdown(); main.removeCallbacksAndMessages(null) }
    companion object {
        private var instance: ReaderSpeech? = null
        fun current(): ReaderSpeech? = instance
        fun get(context: android.content.Context, store: JohnStore): ReaderSpeech = (instance ?: ReaderSpeech(context.applicationContext, store).also { instance = it }).also { it.store = store }
        fun closeAll() { instance?.close(); instance = null }
    }
}

@Composable internal fun ReaderButton(text: String, onClick: () -> Unit) {
    val colors = LocalJohnColors.current
    OutlinedButton(onClick = onClick, modifier = Modifier.heightIn(min = 44.dp), shape = RoundedCornerShape(8.dp), border = androidx.compose.foundation.BorderStroke(1.dp, colors.border), colors = ButtonDefaults.outlinedButtonColors(contentColor = colors.tint)) {
        Text(text, fontFamily = SpaceGrotesk, fontSize = 14.sp)
    }
}

@Composable internal fun ReadingPage(title: String, eyebrow: String = "", subtitle: String = "", back: (() -> Unit)? = null, scroll: ScrollState = rememberScrollState(), footer: (@Composable () -> Unit)? = null, content: @Composable ColumnScope.() -> Unit) {
    val colors = LocalJohnColors.current
    Column(Modifier.fillMaxSize().background(colors.background), horizontalAlignment = Alignment.CenterHorizontally) {
        Column(Modifier.weight(1f).widthIn(max = 740.dp).fillMaxWidth().verticalScroll(scroll).padding(horizontal = 24.dp).padding(top = 16.dp, bottom = 40.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (back != null) ReaderButton("‹ Back", back)
            if (eyebrow.isNotBlank()) JohnText(eyebrow.uppercase(), size = 11, dim = true)
            Text(title, fontFamily = SpaceGrotesk, fontWeight = FontWeight.Bold, fontSize = 36.sp, lineHeight = 43.sp, letterSpacing = (-.8).sp, color = colors.text, modifier = Modifier.semantics { heading() })
            if (subtitle.isNotBlank()) JohnText(subtitle, dim = true)
            content()
        }
        if (footer != null) Box(Modifier.widthIn(max = 740.dp).fillMaxWidth().background(colors.card).padding(horizontal = 16.dp, vertical = 8.dp)) { footer() }
    }
}

@Composable internal fun PassageToolbar(hit: SearchHit, store: JohnStore, feedback: String, setFeedback: (String) -> Unit, note: () -> Unit, clear: () -> Unit, navigate: (String) -> Unit) {
    val context = LocalContext.current
    val clipboard = LocalClipboardManager.current
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { JohnText(hit.reference, size = 13); TextButton(onClick = clear) { Text("Done") } }
        Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            ReaderButton(if (store.isBookmarked(hit)) "Remove bookmark" else "Bookmark") { setFeedback(if (store.toggleBookmark(hit)) "Bookmark saved" else "Bookmark removed") }
            ReaderButton("Note", note)
            ReaderButton("Copy") { clipboard.setText(AnnotatedString(shareText(hit))); setFeedback("Passage copied") }
            ReaderButton("Share") { sharePassage(context, shareText(hit)) }
            ReaderButton("Share card") { navigate("share-card/${hit.edition}/${hit.book}/${hit.chapter}/${android.net.Uri.encode(hit.label)}") }
            ReaderButton("Pray") { navigate("lectio/${android.net.Uri.encode(hit.reference + "\n" + hit.text)}") }
        }
        ChoiceChips(listOf("yellow" to "Yellow", "green" to "Green", "blue" to "Blue", "pink" to "Pink", "purple" to "Purple", "" to "Clear"), store.highlightColor(hit) ?: "") { store.highlight(hit, it); setFeedback(if (it.isBlank()) "Highlight removed" else "Highlight saved") }
        if (feedback.isNotBlank()) JohnText(feedback, size = 12, dim = true)
    }
}

@Composable private fun ScriptureParagraphs(verses: List<Verse>, store: JohnStore, edition: String, code: String, name: String, chapter: Int, lower: Int, upper: Int, spoken: Int?, contextLabel: String, select: (Int) -> Unit) {
    val colors = LocalJohnColors.current
    val groups = remember(verses) {
        val starts = verses.indices.filter { it == 0 || verses[it].paragraphStart }
        starts.mapIndexed { i, start -> start until (starts.getOrNull(i + 1) ?: verses.size) }
    }
    groups.forEach { range ->
        val bring = remember(edition, code, chapter, range.first) { BringIntoViewRequester() }
        LaunchedEffect(contextLabel, verses) { if (range.any { verses[it].label == contextLabel } && contextLabel.isNotBlank()) bring.bringIntoView() }
        val text = buildAnnotatedString {
            range.forEach { index ->
                val verse = verses[index]
                val hit = SearchHit(edition, code, name, chapter, verse.label, verse.text)
                val background = when {
                    lower >= 0 && index in lower..upper -> colors.tint.copy(alpha = .2f)
                    index == spoken -> colors.tint.copy(alpha = .12f)
                    store.highlightColor(hit) != null -> highlightColor(store.highlightColor(hit)!!).copy(alpha = .24f)
                    else -> Color.Transparent
                }
                withLink(LinkAnnotation.Clickable("verse-${verse.label}", TextLinkStyles(style = SpanStyle(color = colors.text, background = background))) { select(index) }) {
                    if (store.showVerseNumbers) withStyle(SpanStyle(fontSize = (store.textSize * .65f).sp, color = colors.textDim)) { append("${verse.label} ") }
                    append(verse.text)
                }
                append(" ")
            }
        }
        Text(text, modifier = Modifier.fillMaxWidth().bringIntoViewRequester(bring).testTag("reader-paragraph-${verses[range.first].label}"), fontFamily = if (store.fontFamily == "serif") Lora else SpaceGrotesk, fontSize = store.textSize.sp, lineHeight = (store.textSize * store.lineSpacing).sp, color = colors.text)
    }
}

@Composable fun ReadAloudMiniPlayer(store: JohnStore, navigate: (String) -> Unit = {}) {
    val context = LocalContext.current
    val speech = remember { ReaderSpeech.get(context, store) }
    if (speech.active) {
        val colors = LocalJohnColors.current
        Column(Modifier.fillMaxWidth().background(colors.card).padding(horizontal = 16.dp, vertical = 4.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f).clickable { navigate("reader/${speech.edition}/${speech.bookCode}/${speech.chapter}/${speech.label}") }) {
                    JohnText("${speech.bookName} ${speech.chapter}:${speech.label}", size = 14)
                    JohnText("${editionShort(speech.edition)} · ${if (speech.playing) "Reading aloud" else "Paused"}", size = 11, dim = true)
                }
                TextButton(onClick = { speech.previous() }, modifier = Modifier.semantics { contentDescription = "Previous verse" }) { Text("‹") }
                TextButton(onClick = { if (speech.playing) speech.pause() else speech.resume() }) { Text(if (speech.playing) "Pause" else "Play") }
                TextButton(onClick = { speech.next() }, modifier = Modifier.semantics { contentDescription = "Next verse" }) { Text("›") }
                TextButton(onClick = { speech.stop() }) { Text("Stop") }
            }
            if (speech.error.isNotBlank()) JohnText(speech.error, size = 12, dim = true)
        }
    }
}
