package com.john.bible.data

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate

data class SavedPassage(
    val id: String, val kind: String, val edition: String, val book: String, val bookName: String,
    val chapter: Int, val startLabel: String, val endLabel: String, val text: String,
    val note: String = "", val color: String = "", val updatedAt: Long = System.currentTimeMillis(),
    val tags: List<String> = emptyList(), val drawingJson: String = ""
) {
    val reference: String get() = "$bookName $chapter:$startLabel" + if (endLabel != startLabel) "–$endLabel" else ""
    val hit: SearchHit get() = SearchHit(edition, book, bookName, chapter, if (startLabel == endLabel) startLabel else "$startLabel–$endLabel", text)
}
data class NovenaProgress(val completedDays: Set<Int> = emptySet(), val selectedDay: Int = 1, val intention: String = "")
data class Reflection(val before: String = "", val after: String = "")

/** Observable local preferences and user library. Every edit persists immediately. */
class JohnStore(context: Context, preferenceName: String = "john") {
    private val context = context.applicationContext
    private val prefs = this.context.getSharedPreferences(preferenceName, Context.MODE_PRIVATE)
    private val bible by lazy { JohnRepository(this.context) }
    private fun string(key: String, default: String) = prefs.getString(key, default) ?: default
    private fun write(key: String, value: String) { prefs.edit().putString(key, value).apply() }
    private fun json(key: String): JSONObject = runCatching { JSONObject(string(key, "{}")) }.getOrElse { JSONObject() }

    private var editionState by mutableStateOf(string("edition", "web-ce").takeIf { it in JohnRepository.EDITIONS } ?: "web-ce")
    var edition: String
        get() = editionState
        set(value) { if (value in JohnRepository.EDITIONS) { editionState = value; write("edition", value) } }
    private var appearanceState by mutableStateOf(string("appearance", "system"))
    var appearance: String
        get() = appearanceState
        set(value) { appearanceState = value; write("appearance", value) }
    private var textSizeState by mutableStateOf(prefs.getFloat("textSize", 18f))
    var textSize: Float
        get() = textSizeState
        set(value) { textSizeState = value.coerceIn(12f, 36f); prefs.edit().putFloat("textSize", textSizeState).apply() }
    private var verseNumbersState by mutableStateOf(prefs.getBoolean("showVerseNumbers", true))
    var showVerseNumbers: Boolean
        get() = verseNumbersState
        set(value) { verseNumbersState = value; prefs.edit().putBoolean("showVerseNumbers", value).apply() }
    private var lineSpacingState by mutableStateOf(prefs.getFloat("lineSpacing", 1.55f))
    var lineSpacing: Float
        get() = lineSpacingState
        set(value) { lineSpacingState = value.coerceIn(1f, 2.5f); prefs.edit().putFloat("lineSpacing", lineSpacingState).apply() }
    private var fontState by mutableStateOf(string("fontFamily", "serif"))
    var fontFamily: String
        get() = fontState
        set(value) { fontState = value; write("fontFamily", value) }
    private var scopeState by mutableStateOf(string("scope", "full"))
    var scope: String
        get() = scopeState
        set(value) { if (value in listOf("full", "ot", "nt")) { scopeState = value; write("scope", value) } }
    private var intervalState by mutableStateOf(prefs.getInt("intervalMinutes", 1440))
    var intervalMinutes: Int
        get() = intervalState
        set(value) { if (value in listOf(10, 15, 30, 60, 180, 360, 720, 1440)) { intervalState = value; prefs.edit().putInt("intervalMinutes", value).apply() } }
    private var layoutState by mutableStateOf(string("readerLayout", "paragraphs"))
    var readerLayout: String
        get() = layoutState
        set(value) { layoutState = value; write("readerLayout", value) }
    private var modeState by mutableStateOf(string("readerMode", "pages").takeIf { it in READER_MODES } ?: "pages")
    /** "pages" turns pages, as in Play Books. "scroll" scrolls each chapter. */
    var readerMode: String
        get() = modeState
        set(value) { if (value in READER_MODES) { modeState = value; write("readerMode", value) } }
    private var aloudRateState by mutableStateOf(prefs.getFloat("readAloudRate", 1f))
    var readAloudRate: Float
        get() = aloudRateState
        set(value) { aloudRateState = value.coerceIn(.5f, 2f); prefs.edit().putFloat("readAloudRate", aloudRateState).apply() }
    private var aloudVoiceState by mutableStateOf(string("readAloudVoice", ""))
    var readAloudVoice: String
        get() = aloudVoiceState
        set(value) { aloudVoiceState = value; write("readAloudVoice", value) }
    var readerBook by mutableStateOf(string("readerBook", "JHN")); private set
    var readerChapter by mutableStateOf(prefs.getInt("readerChapter", 1)); private set
    var readerScrollIndex by mutableStateOf(prefs.getInt("readerScrollIndex", 0)); private set
    /** The verse at the top of the last page read, and the character offset in that verse. */
    var readerVerse by mutableStateOf(string("readerVerse", "")); private set
    var readerVerseOffset by mutableStateOf(prefs.getInt("readerVerseOffset", 0)); private set
    var saved by mutableStateOf(readSaved()); private set
    var recentSearches by mutableStateOf(runCatching { JSONArray(string("recentSearches", "[]")).strings() }.getOrDefault(emptyList())); private set
    var favoritePrayerIds by mutableStateOf(prefs.getStringSet("favoritePrayerIds", emptySet())!!.toSet()); private set
    var completedChapters by mutableStateOf(prefs.getStringSet("completedChapters", emptySet())!!.toSet()); private set
    var readingDays by mutableStateOf(prefs.getStringSet("readingDays", emptySet())!!.toSet()); private set
    var planId by mutableStateOf(string("planId", "").ifEmpty { null }); private set
    var planStartDate by mutableStateOf(string("planStartDate", "").ifEmpty { null }); private set
    private var novenas by mutableStateOf(json("novenas"))
    private var reflections by mutableStateOf(json("reflections"))
    private var workLocations by mutableStateOf(json("workLocations"))
    private var workParagraphs by mutableStateOf(json("workParagraphs"))
    private var workOffsets by mutableStateOf(json("workOffsets"))
    var lastWorkId by mutableStateOf(string("lastWorkId", "")); private set
    /** "A Year with the Fathers": the person's Day 1, the day they started (with "Join today" it is later), and read days. */
    var yearStartDate by mutableStateOf(string("yearStartDate", "").ifEmpty { null }); private set
    var yearJoinedDate by mutableStateOf(string("yearJoinedDate", "").ifEmpty { null }); private set
    var yearDaysRead by mutableStateOf(prefs.getStringSet("yearDaysRead", emptySet())!!.mapNotNull { it.toIntOrNull() }.toSet()); private set

    private var saintProfiles by mutableStateOf(json("mySaintProfiles"))
    var widgetSaintID by mutableStateOf(string("widgetSaintID", "")); private set
    var widgetSaintQuiet by mutableStateOf(prefs.getBoolean("widgetSaintQuiet", false)); private set
    fun saintProfile(id: String): SaintProfile = SaintProfile.parse(saintProfiles.optJSONObject(id))
    fun saveSaintProfile(id: String, profile: SaintProfile): Boolean {
        val next = JSONObject(saintProfiles.toString()).put(id, profile.json())
        val saved = prefs.edit().putString("mySaintProfiles", next.toString()).commit()
        if (saved) { saintProfiles = next; com.john.bible.platform.MySaintWidget.refreshAll(context) }
        return saved
    }
    fun saveSaintWidget(id: String, quiet: Boolean): Boolean {
        val saved = prefs.edit().putString("widgetSaintID", id).putBoolean("widgetSaintQuiet", quiet).commit()
        if (saved) { widgetSaintID = id; widgetSaintQuiet = quiet; com.john.bible.platform.MySaintWidget.refreshAll(context) }
        return saved
    }

    fun saveReaderLocation(book: String, chapter: Int, scrollIndex: Int = 0) {
        require(chapter > 0)
        val otherChapter = book != readerBook || chapter != readerChapter
        readerBook = book; readerChapter = chapter; readerScrollIndex = scrollIndex.coerceAtLeast(0)
        val edit = prefs.edit().putString("readerBook", book).putInt("readerChapter", chapter).putInt("readerScrollIndex", readerScrollIndex)
        if (otherChapter) { readerVerse = ""; readerVerseOffset = 0; edit.remove("readerVerse").remove("readerVerseOffset") }
        edit.apply()
    }

    /** Saves the paged reader position. A verse anchor stays correct after a change of text size or screen size. */
    fun saveReaderAnchor(book: String, chapter: Int, verse: String, offset: Int) {
        require(chapter > 0)
        readerBook = book; readerChapter = chapter; readerVerse = verse; readerVerseOffset = offset.coerceAtLeast(0)
        prefs.edit().putString("readerBook", book).putInt("readerChapter", chapter).putString("readerVerse", verse).putInt("readerVerseOffset", readerVerseOffset).apply()
    }

    fun toggleBookmark(hit: SearchHit): Boolean {
        val id = id("bookmark", hit)
        if (saved.any { it.id == id }) { deleteSaved(id); return false }
        putSaved(item("bookmark", hit)); return true
    }
    fun isBookmarked(hit: SearchHit): Boolean = saved.any { it.id == id("bookmark", hit) }
    /** True when a saved bookmark or note of this kind covers the verse, also as part of a range. */
    fun coversVerse(kind: String, hit: SearchHit): Boolean = saved.any { it.kind == kind && sameChapter(it, hit) && contains(it, hit.label) }
    fun saveNote(hit: SearchHit, text: String) {
        saveNote(hit, text, noteDrawing(hit))
    }
    fun saveNote(hit: SearchHit, text: String, drawingJson: String) {
        if (text.isBlank() && drawingJson.isBlank()) deleteSaved(id("note", hit))
        else putSaved(item("note", hit).copy(note = text.trim(), drawingJson = drawingJson))
    }
    fun noteDrawing(hit: SearchHit): String = saved.firstOrNull { it.id == id("note", hit) }?.drawingJson ?: ""
    fun noteFor(hit: SearchHit): String = saved.firstOrNull { it.id == id("note", hit) }?.note ?: ""
    fun highlight(hit: SearchHit, color: String) {
        val next = item("highlight", hit).copy(color = color)
        // A new color affects selected verses only. Keep the rest of an earlier range.
        saved = saved.flatMap { existing ->
            if (existing.kind != "highlight" || !sameChapter(existing, hit) || !overlaps(existing, next)) listOf(existing)
            else remainder(existing, next)
        }
        if (color.isNotEmpty()) putSaved(next) else persistSaved()
    }
    fun highlightColor(hit: SearchHit): String? {
        val bounds = labels(hit)
        val from = bounds.first.toIntOrNull()
        val to = bounds.second.toIntOrNull()
        val selected = if (from != null && to != null) (minOf(from, to)..maxOf(from, to)).map { it.toString() } else listOf(hit.label)
        val colors = selected.map { label -> saved.firstOrNull { it.kind == "highlight" && sameChapter(it, hit) && contains(it, label) }?.color }
        return colors.distinct().singleOrNull()
    }
    fun deleteSaved(id: String) { saved = saved.filterNot { it.id == id }; persistSaved() }
    fun restoreSaved(item: SavedPassage) = putSaved(item)
    fun setTags(id: String, tags: List<String>) {
        saved = saved.map { if (it.id == id) it.copy(tags = tags.map { tag -> tag.trim().lowercase().replace("#", "").take(40) }.filter(String::isNotEmpty).distinct(), updatedAt = System.currentTimeMillis()) else it }
        persistSaved()
    }
    fun exportSaved(): String {
        val tags = JSONObject()
        val items = JSONArray()
        saved.forEach { item ->
            val verses = bible.chapter(item.edition, item.book, item.chapter)
            val start = verses.indexOfFirst { it.label == item.startLabel }
            val end = verses.indexOfFirst { it.label == item.endLabel }
            val color = when (item.color) { "yellow" -> "gold"; "green" -> "sage"; "pink" -> "rose"; "purple" -> "blue"; else -> item.color }
            val row = JSONObject().put("id", item.id).put("kind", item.kind).put("translationID", item.edition)
                .put("bookCode", item.book).put("bookName", item.bookName).put("bookOrder", bible.books(item.edition).indexOfFirst { it.code == item.book })
                .put("chapter", item.chapter).put("startVerse", item.startLabel).put("endVerse", item.endLabel)
                .put("startIndex", start).put("endIndex", end).put("scriptureText", item.text).put("reference", item.reference)
                .put("createdAt", item.updatedAt).put("updatedAt", item.updatedAt).put("noteText", item.note).put("drawingJson", item.drawingJson)
            if (item.kind == "highlight" && start >= 0 && end >= start) {
                row.put("color", color)
                val keys = JSONArray()
                val highlights = JSONArray()
                for (index in start..end) {
                    val verse = verses[index]
                    val key = "${item.edition}:${item.book}:${item.chapter}:${verse.label}"
                    keys.put(key)
                    highlights.put(JSONObject().put("verseKey", key).put("batchID", item.id).put("verse", verse.label).put("verseIndex", index).put("verseText", verse.text).put("createdAt", item.updatedAt).put("updatedAt", item.updatedAt))
                }
                row.put("verseKeys", keys).put("highlightVerses", highlights)
            }
            items.put(row)
            tags.put(item.id, JSONArray(item.tags))
        }
        // Standard iOS backup fields permit transfer between both platforms.
        // Android extension fields retain drawings and the native color selection.
        return JSONObject().put("format", "john-saved-backup").put("version", 1).put("exportedAt", System.currentTimeMillis())
            .put("items", items).put("tags", tags).put("formatVersion", 1).put("saved", savedJson()).toString(2)
    }
    fun importSaved(source: String): Int {
        val document = JSONObject(source)
        val imported = if (document.has("saved")) {
            require(document.getInt("formatVersion") == 1) { "Unsupported saved library format" }
            document.getJSONArray("saved").objects().map(::decodeSaved)
        } else {
            require(document.getString("format") == "john-saved-backup" && document.optInt("version", 1) == 1) { "Unsupported saved library format" }
            document.getJSONArray("items").objects().map { row ->
                val hit = SearchHit(row.getString("translationID"), row.getString("bookCode"), row.getString("bookName"), row.getInt("chapter"), if (row.getString("startVerse") == row.getString("endVerse")) row.getString("startVerse") else "${row.getString("startVerse")}–${row.getString("endVerse")}", row.getString("scriptureText"))
                val color = when (row.optString("color")) { "gold" -> "yellow"; "sage" -> "green"; "rose" -> "pink"; else -> row.optString("color") }
                SavedPassage(id(row.getString("kind"), hit), row.getString("kind"), hit.edition, hit.book, hit.bookName, hit.chapter, row.getString("startVerse"), row.getString("endVerse"), hit.text,
                    row.optString("noteText"), color, row.getLong("updatedAt"), document.optJSONObject("tags")?.optJSONArray(row.getString("id"))?.strings() ?: emptyList(), row.optString("drawingJson"))
            }
        }
        require(imported.all { it.edition in JohnRepository.EDITIONS && it.chapter > 0 && it.kind in listOf("bookmark", "note", "highlight") })
        val unique = imported.groupBy { it.id }.values.map { versions -> versions.maxBy { it.updatedAt } }
        val applied = unique.filter { incoming -> saved.firstOrNull { it.id == incoming.id }?.let { incoming.updatedAt > it.updatedAt } ?: true }
        saved = (applied + saved.filterNot { existing -> applied.any { it.id == existing.id } }).sortedByDescending { it.updatedAt }
        persistSaved()
        return applied.size
    }
    fun addRecentSearch(query: String) {
        if (query.isBlank()) return
        recentSearches = (listOf(query.trim()) + recentSearches.filterNot { it.equals(query.trim(), true) }).take(12)
        write("recentSearches", JSONArray(recentSearches).toString())
    }
    fun clearRecentSearches() { recentSearches = emptyList(); write("recentSearches", "[]") }
    fun toggleFavoritePrayer(id: String) {
        favoritePrayerIds = if (id in favoritePrayerIds) favoritePrayerIds - id else favoritePrayerIds + id
        prefs.edit().putStringSet("favoritePrayerIds", favoritePrayerIds).apply()
    }

    // Canonical book/chapter identity lets progress survive translation changes.
    fun markChapterRead(edition: String, book: String, chapter: Int) = setChapterRead(edition, book, chapter, true)
    fun setChapterRead(edition: String, book: String, chapter: Int, read: Boolean) {
        require(edition in JohnRepository.EDITIONS && chapter > 0)
        val key = "$book/$chapter"
        completedChapters = if (read) completedChapters + key else completedChapters - key
        if (read) readingDays = readingDays + LocalDate.now().toString()
        prefs.edit().putStringSet("completedChapters", completedChapters).putStringSet("readingDays", readingDays).apply()
    }
    fun isChapterRead(edition: String, book: String, chapter: Int): Boolean = "$book/$chapter" in completedChapters
    fun readChapterCount(): Int = completedChapters.size
    fun streak(): Int {
        var day = LocalDate.now()
        if (day.toString() !in readingDays) day = day.minusDays(1)
        var count = 0
        while (day.toString() in readingDays) { count++; day = day.minusDays(1) }
        return count
    }
    fun resetProgress() {
        completedChapters = emptySet(); readingDays = emptySet(); startPlan(null)
        prefs.edit().remove("completedChapters").remove("readingDays").apply()
    }
    fun startPlan(id: String?) {
        planId = id; planStartDate = if (id == null) null else LocalDate.now().toString()
        write("planId", id ?: ""); write("planStartDate", planStartDate ?: "")
    }
    /** Saves Day 1 (`null` starts over; read days stay). The join date is today, or Day 1 when that is later. */
    fun startYear(start: LocalDate?, today: LocalDate = FeatureClock.today()) {
        yearStartDate = start?.toString()
        yearJoinedDate = start?.let { maxOf(it, today).toString() }
        write("yearStartDate", yearStartDate ?: ""); write("yearJoinedDate", yearJoinedDate ?: "")
    }
    fun setYearDayRead(day: Int, read: Boolean) {
        if (day !in 1..YearPlanSchedule.DAY_COUNT) return
        yearDaysRead = if (read) yearDaysRead + day else yearDaysRead - day
        prefs.edit().putStringSet("yearDaysRead", yearDaysRead.map { it.toString() }.toSet()).apply()
    }
    fun planDay(): Int = planStartDate?.let { runCatching { (java.time.temporal.ChronoUnit.DAYS.between(LocalDate.parse(it), LocalDate.now()).toInt() + 1).coerceAtLeast(1) }.getOrDefault(1) } ?: 1
    fun todayJohnChapters(): List<Int> {
        val days = when (planId) { "john-21" -> 21; "john-7" -> 7; else -> null }
        if (days != null && planStartDate != null) {
            val day = (planDay() - 1).coerceIn(0, days - 1)
            return (day * 21 / days + 1..(day + 1) * 21 / days).filter { "JHN/$it" !in completedChapters }
        }
        return (1..21).firstOrNull { "JHN/$it" !in completedChapters }?.let(::listOf) ?: emptyList()
    }
    fun novena(id: String): NovenaProgress {
        val value = novenas.optJSONObject(id) ?: return NovenaProgress()
        val complete = value.optJSONArray("completedDays") ?: JSONArray()
        return NovenaProgress((0 until complete.length()).map { complete.getInt(it) }.filter { it in 1..9 }.toSet(), value.optInt("selectedDay", 1).coerceIn(1, 9), value.optString("intention"))
    }
    fun updateNovena(id: String, progress: NovenaProgress) {
        val copy = JSONObject(novenas.toString())
        copy.put(id, JSONObject().put("completedDays", JSONArray(progress.completedDays.filter { it in 1..9 }.sorted())).put("selectedDay", progress.selectedDay.coerceIn(1, 9)).put("intention", progress.intention))
        novenas = copy; write("novenas", copy.toString())
    }
    fun completeNovenaDay(id: String) {
        val current = novena(id)
        val days = current.completedDays + current.selectedDay
        updateNovena(id, current.copy(completedDays = days, selectedDay = (1..9).firstOrNull { it !in days } ?: current.selectedDay))
    }
    fun resetNovena(id: String) = updateNovena(id, NovenaProgress())
    fun reflection(date: String): Reflection = reflections.optJSONObject(date)?.let { Reflection(it.optString("before"), it.optString("after")) } ?: Reflection()
    fun setReflection(date: String, before: String, after: String) {
        reflections = JSONObject(reflections.toString()).put(date, JSONObject().put("before", before).put("after", after))
        write("reflections", reflections.toString())
    }
    fun workLocation(workId: String): Int = workLocations.optInt(workId, 0)
    fun saveWorkLocation(workId: String, index: Int) {
        lastWorkId = workId; write("lastWorkId", workId)
        workLocations = JSONObject(workLocations.toString()).put(workId, index.coerceAtLeast(0))
        write("workLocations", workLocations.toString())
    }
    fun workParagraph(workId: String): Int = workParagraphs.optInt(workId, 0)
    fun saveWorkParagraph(workId: String, paragraph: Int) {
        workParagraphs = JSONObject(workParagraphs.toString()).put(workId, paragraph.coerceAtLeast(0))
        write("workParagraphs", workParagraphs.toString())
    }
    fun workOffset(workId: String): Int = workOffsets.optInt(workId, 0)
    fun saveWorkOffset(workId: String, offset: Int) {
        workOffsets = JSONObject(workOffsets.toString()).put(workId, offset.coerceAtLeast(0))
        write("workOffsets", workOffsets.toString())
    }

    companion object { val READER_MODES = listOf("pages", "scroll") }

    private fun labels(hit: SearchHit): Pair<String, String> {
        val parts = hit.label.split(Regex("[-–]"), limit = 2)
        return parts.first() to parts.last()
    }
    private fun id(kind: String, hit: SearchHit) = "$kind:${hit.edition}:${hit.book}:${hit.chapter}:${labels(hit).first}:${labels(hit).second}"
    private fun item(kind: String, hit: SearchHit): SavedPassage {
        val labels = labels(hit)
        val previous = saved.firstOrNull { it.id == id(kind, hit) }
        return SavedPassage(id(kind, hit), kind, hit.edition, hit.book, hit.bookName, hit.chapter, labels.first, labels.second, hit.text, tags = previous?.tags ?: emptyList())
    }
    private fun sameChapter(item: SavedPassage, hit: SearchHit) = item.edition == hit.edition && item.book == hit.book && item.chapter == hit.chapter
    private fun contains(item: SavedPassage, label: String): Boolean {
        if (label == item.startLabel || label == item.endLabel) return true
        val start = item.startLabel.toIntOrNull() ?: return false
        val end = item.endLabel.toIntOrNull() ?: return false
        return label.toIntOrNull()?.let { it in start..end } ?: false
    }
    private fun overlaps(a: SavedPassage, b: SavedPassage) = contains(a, b.startLabel) || contains(a, b.endLabel) || contains(b, a.startLabel)
    private fun remainder(existing: SavedPassage, removed: SavedPassage): List<SavedPassage> {
        val verses = bible.chapter(existing.edition, existing.book, existing.chapter)
        val start = verses.indexOfFirst { it.label == existing.startLabel }
        val end = verses.indexOfFirst { it.label == existing.endLabel }
        val removeStart = verses.indexOfFirst { it.label == removed.startLabel }
        val removeEnd = verses.indexOfFirst { it.label == removed.endLabel }
        if (start < 0 || end < start || removeStart < 0 || removeEnd < removeStart) return emptyList()
        return listOf(start until minOf(end + 1, removeStart), maxOf(start, removeEnd + 1)..end).filter { !it.isEmpty() }.map { range ->
            val first = verses[range.first].label
            val last = verses[range.last].label
            val hit = SearchHit(existing.edition, existing.book, existing.bookName, existing.chapter, if (first == last) first else "$first–$last", range.joinToString(" ") { verses[it].text })
            existing.copy(id = id("highlight", hit), startLabel = first, endLabel = last, text = hit.text)
        }
    }
    private fun putSaved(item: SavedPassage) { saved = (listOf(item) + saved.filterNot { it.id == item.id }).sortedByDescending { it.updatedAt }; persistSaved() }
    private fun persistSaved() = write("saved", savedJson().toString())
    private fun savedJson() = JSONArray(saved.map {
        JSONObject().put("id", it.id).put("kind", it.kind).put("edition", it.edition).put("book", it.book).put("bookName", it.bookName)
            .put("chapter", it.chapter).put("startLabel", it.startLabel).put("endLabel", it.endLabel).put("text", it.text)
            .put("note", it.note).put("color", it.color).put("updatedAt", it.updatedAt).put("tags", JSONArray(it.tags)).put("drawingJson", it.drawingJson)
    })
    private fun decodeSaved(it: JSONObject) = SavedPassage(it.getString("id"), it.getString("kind"), it.getString("edition"), it.getString("book"), it.getString("bookName"), it.getInt("chapter"), it.getString("startLabel"), it.getString("endLabel"), it.getString("text"), it.optString("note"), it.optString("color"), it.optLong("updatedAt"), it.optJSONArray("tags")?.strings() ?: emptyList(), it.optString("drawingJson"))
    private fun readSaved(): List<SavedPassage> = runCatching { JSONArray(string("saved", "[]")).objects().map(::decodeSaved).sortedByDescending { it.updatedAt } }.getOrDefault(emptyList())
}
