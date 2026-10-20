package com.john.bible.data

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.time.LocalDate
import java.time.ZoneId
import java.util.zip.InflaterInputStream

data class BibleBook(val code: String, val name: String, val longName: String, val chapters: Int, val testament: String)
data class Verse(val label: String, val text: String, val paragraphStart: Boolean = false)
data class SearchHit(val edition: String, val book: String, val bookName: String, val chapter: Int, val label: String, val text: String) {
    val reference: String get() = "$bookName $chapter:$label"
}
data class WorkAuthor(val id: String, val title: String, val author: String, val era: String, val workCount: Int, val sectionCount: Int, val words: Int, val attribution: String)
data class Work(val id: String, val collectionId: String, val title: String, val sectionCount: Int, val words: Int, val kind: String)
data class WorkSectionSummary(val index: Int, val title: String, val words: Int)
data class WorkSection(val index: Int, val title: String, val words: Int, val paragraphs: List<String>)

/** Uses the exact source corpus used by iOS. Large databases open only on demand. */
class JohnRepository(context: Context) : AutoCloseable {
    private val context = context.applicationContext
    private val editions = mutableMapOf<String, List<BibleBook>>()
    private val chapterCache = object : LinkedHashMap<String, List<Verse>>(8, .75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, List<Verse>>?) = size > 8
    }
    private val jsonCache = mutableMapOf<String, JSONObject>()
    private val databases = mutableMapOf<String, SQLiteDatabase>()
    private val rotations = mutableMapOf<String, List<Pair<SearchHit, String>>>()

    @Synchronized
    fun books(edition: String = "web-ce"): List<BibleBook> = editions.getOrPut(edition) {
        require(edition in EDITIONS)
        jsonArray("Bible/$edition/manifest.json").objects().map {
            BibleBook(it.getString("code"), it.getString("name"), it.getString("longName"), it.getInt("chapterCount"), it.getString("group"))
        }
    }

    @Synchronized
    fun chapter(edition: String, book: String, chapter: Int): List<Verse> {
        val descriptor = books(edition).firstOrNull { it.code == book } ?: error("Unknown Bible book: $book")
        require(chapter in 1..descriptor.chapters)
        return chapterCache.getOrPut("$edition/$book/$chapter") {
            val chapters = jsonObject("Bible/$edition/$book.json", cache = false).getJSONArray("chapters")
            chapters.objects().first { it.getInt("c") == chapter }.getJSONArray("verses").objects().map {
                val breaks = it.optJSONArray("br")
                val starts = breaks != null && (0 until breaks.length()).any { index ->
                    val mark = breaks.getJSONArray(index)
                    mark.optInt(0, -1) == 0 && mark.optString(1) == "p"
                }
                Verse(it.getString("n"), it.getString("t"), starts)
            }
        }
    }

    @Synchronized
    fun search(edition: String, query: String, scope: String = "all", book: String? = null): List<SearchHit> {
        require(edition in EDITIONS)
        val trimmed = query.trim()
        if (trimmed.isEmpty()) return emptyList()
        // A reference opens a passage directly, including numbered book names.
        val reference = BibleReferenceParser.parse(trimmed, books(edition))
        if (reference != null) {
            if ((book != null && book != reference.book.code) || !scopeMatches(reference.book.testament, scope)) return emptyList()
            val from = reference.startVerse?.takeWhile(Char::isDigit)?.toIntOrNull()
            val to = reference.endVerse?.takeWhile(Char::isDigit)?.toIntOrNull() ?: from
            return chapter(edition, reference.book.code, reference.chapter).filter { from == null || it.label.toIntOrNull()?.let { n -> n in minOf(from, to ?: from)..maxOf(from, to ?: from) } == true }
                .map { SearchHit(edition, reference.book.code, reference.book.name, reference.chapter, it.label, it.text) }
        }
        val expression = buildFTSQuery(trimmed) ?: return emptyList()
        val result = searchText(edition, expression, scope, book)
        if (result.isNotEmpty() || trimmed.startsWith('"')) return result
        val tokens = searchableTokens(trimmed)
        val corrected = tokens.map { correctedWord(edition, it) }
        if (tokens == corrected) return emptyList()
        return searchText(edition, corrected.joinToString(" ") { "\"$it*\"" }, scope, book)
    }

    private fun searchText(edition: String, expression: String, scope: String, book: String?): List<SearchHit> {
        val scopeSQL = when (scope.lowercase()) { "ot" -> " AND v.group_name IN ('ot','deutero')"; "nt" -> " AND v.group_name='nt'"; else -> "" }
        val bookSQL = if (book == null) "" else " AND v.book_code=?"
        val args = mutableListOf(expression, edition)
        if (book != null) args.add(book)
        return database("bible-search.db").rawQuery(
            "SELECT v.book_code,v.book_name,v.chapter,v.verse,v.text FROM verse_search CROSS JOIN verses v ON v.id=verse_search.docid WHERE verse_search MATCH ? AND v.translation_id=?$scopeSQL$bookSQL ORDER BY v.book_order,v.chapter,v.verse_order LIMIT 200",
            args.toTypedArray()
        ).use { cursor -> buildList { while (cursor.moveToNext()) add(SearchHit(edition, cursor.getString(0), cursor.getString(1), cursor.getInt(2), cursor.getString(3), cursor.getString(4))) } }
    }

    private fun correctedWord(edition: String, token: String): String {
        if (token.length < 4) return token
        val db = database("bible-search.db")
        if (db.rawQuery("SELECT 1 FROM vocabulary WHERE translation_id=? AND word=?", arrayOf(edition, token)).use { it.moveToFirst() }) return token
        val maximum = if (token.length >= 5) 2 else 1
        var best = token
        var bestDistance = maximum + 1
        db.rawQuery("SELECT word FROM vocabulary WHERE translation_id=? AND substr(word,1,1)=substr(?,1,1) AND length(word) BETWEEN ? AND ? ORDER BY frequency DESC LIMIT 300", arrayOf(edition, token, (token.length - maximum).toString(), (token.length + maximum).toString())).use { cursor ->
            while (cursor.moveToNext()) {
                val candidate = cursor.getString(0)
                val distance = BibleReferenceParser.editDistance(token, candidate, maximum)
                if (distance < bestDistance) { best = candidate; bestDistance = distance }
            }
        }
        return best
    }
    private fun scopeMatches(group: String, scope: String): Boolean = when (scope.lowercase()) { "ot" -> group in listOf("ot", "deutero"); "nt" -> group == "nt"; else -> true }

    fun workAuthors(): List<WorkAuthor> = catalog().getJSONArray("collections").objects().map {
        WorkAuthor(it.getString("id"), it.getString("title"), it.getString("author"), it.getString("era"), it.getInt("workCount"), it.getInt("sectionCount"), it.getInt("words"), it.getString("attribution"))
    }

    fun works(author: String? = null): List<Work> = catalog().getJSONArray("works").objects()
        .filter { author == null || it.getString("collectionId") == author }.map {
            Work(it.getString("id"), it.getString("collectionId"), it.getString("title"), it.getInt("sectionCount"), it.getInt("words"), it.optString("kind"))
        }

    @Synchronized
    fun workSections(workId: String): List<WorkSectionSummary> = database("works.db").rawQuery(
        "SELECT idx,title,words FROM sections WHERE work_id=? ORDER BY idx", arrayOf(workId)
    ).use { cursor -> buildList { while (cursor.moveToNext()) add(WorkSectionSummary(cursor.getInt(0), cursor.getString(1), cursor.getInt(2))) } }

    @Synchronized
    fun workSection(workId: String, index: Int): WorkSection = database("works.db").rawQuery(
        "SELECT idx,title,words,paragraphs FROM sections WHERE work_id=? AND idx=?", arrayOf(workId, index.toString())
    ).use { cursor ->
        check(cursor.moveToFirst()) { "Missing work section: $workId/$index" }
        val encoded = InflaterInputStream(ByteArrayInputStream(cursor.getBlob(3))).use { input ->
            val out = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                check(out.size() + count <= 400_000) { "Work section exceeds size limit" }
                out.write(buffer, 0, count)
            }
            out.toString("UTF-8")
        }
        WorkSection(cursor.getInt(0), cursor.getString(1), cursor.getInt(2), JSONArray(encoded).strings())
    }

    fun content(): JSONObject = jsonObject("Catalogs/devotional-catalogs.json")
    fun resolveReference(reference: String, edition: String = "web-ce"): SearchHit? = search(edition, reference).firstOrNull()
    fun commentary(bookCode: String, chapter: Int): List<JSONObject> = catalog().optJSONObject("commentary")?.optJSONObject(bookCode)?.optJSONArray(chapter.toString())?.objects() ?: emptyList()
    fun readings(date: String): JSONObject? = jsonObject("Calendar/readings-us.json").optJSONObject(date)
    fun celebrations(date: String): JSONObject? = jsonObject("Calendar/celebrations-us.json").optJSONObject(date)
    @Synchronized
    fun saintsCalendars(): List<SaintsCalendar> = listOf("vatican", "byzantine").map { tradition ->
        val data = jsonObject("Calendar/saints-$tradition.json")
        require(data.getInt("schemaVersion") == 1 && data.getString("tradition") == tradition)
        val hosts = if (tradition == "vatican") setOf("www.vaticannews.va", "www.vatican.va") else setOf("mci.archpitt.org")
        val entries = data.getJSONArray("entries").objects().map { entry ->
            val source = entry.getString("sourceURL")
            val uri = java.net.URI(source)
            require(uri.scheme == "https" && uri.host in hosts)
            SaintCommemoration(entry.getString("id"), entry.getString("monthDay"),
                entry.getString("name"), entry.getString("excerpt"), source,
                entry.optString("summary").takeIf { it.isNotBlank() },
                entry.optString("sourceLanguage").takeIf { it.isNotBlank() },
                entry.optString("observanceNote").takeIf { it.isNotBlank() }, entry.getString("calendarURL"))
        }
        require(entries.map { it.id }.toSet().size == entries.size)
        require(data.getJSONArray("checkedDates").length() == if (tradition == "vatican") 365 else 366)
        SaintsCalendar(tradition, data.getString("sourceName"), data.getString("retrievedOn"),
            data.getString("coverage"), entries)
    }
    fun calendarCoverage(): Pair<String, String> {
        val keys = jsonObject("Calendar/readings-us.json").keys().asSequence().toList().sorted()
        return keys.first() to keys.last()
    }

    @Synchronized
    fun rotatingVerse(edition: String, scope: String, interval: Int): SearchHit {
        val pool = rotations.getOrPut(edition) {
            val names = books(edition).associate { it.code to it.name }
            jsonObject("Bible/$edition/widgetVerses.json", cache = false).getJSONArray("verses").objects().map {
                SearchHit(edition, it.getString("book"), names.getValue(it.getString("book")), it.getInt("chapter"), it.getString("verse"), it.getString("text")) to it.getString("group")
            }
        }.filter { scope == "full" || if (scope == "nt") it.second == "nt" else it.second in listOf("ot", "deutero") }
        check(pool.isNotEmpty())
        val now = System.currentTimeMillis()
        val offset = ZoneId.systemDefault().rules.getOffset(java.time.Instant.ofEpochMilli(now)).totalSeconds * 1000L
        return pool[RotationMath.index(Math.floorDiv(now + offset, interval.coerceAtLeast(1) * 60_000L), pool.size)].first
    }

    private fun catalog() = jsonObject("Catalogs/works-catalog.json")
    @Synchronized
    private fun jsonObject(path: String, cache: Boolean = true): JSONObject {
        if (!cache) return JSONObject(readAsset(path))
        return jsonCache.getOrPut(path) { JSONObject(readAsset(path)) }
    }
    private fun jsonArray(path: String) = JSONArray(readAsset(path))
    private fun readAsset(path: String) = context.assets.open(path).bufferedReader().use { it.readText() }
    private fun database(name: String): SQLiteDatabase = databases.getOrPut(name) {
        val target = File(context.noBackupFilesDir, "bundled/$name")
        // Content upgrades replace only bundled databases, never the user library.
        val version = context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime.toString()
        val marker = File(target.parentFile, "$name.version")
        if (!target.exists() || !marker.exists() || marker.readText() != version) {
            target.parentFile?.mkdirs()
            val temp = File(target.parentFile, "$name.tmp")
            context.assets.open("Databases/$name").use { input -> temp.outputStream().use { input.copyTo(it) } }
            check(temp.renameTo(target))
            marker.writeText(version)
        }
        SQLiteDatabase.openDatabase(target.path, null, SQLiteDatabase.OPEN_READONLY)
    }
    @Synchronized
    override fun close() { databases.values.forEach { it.close() }; databases.clear() }
    companion object {
        val EDITIONS = listOf("web-ce", "douay-rheims", "vulgate")
        fun searchableTokens(query: String): List<String> {
            val normalized = java.text.Normalizer.normalize(query, java.text.Normalizer.Form.NFKD).replace(Regex("\\p{M}"), "").lowercase(java.util.Locale.ENGLISH)
            return Regex("[\\p{L}\\p{N}]+(?:['’][\\p{L}\\p{N}]+)*").findAll(normalized).map { it.value }.toList()
        }
        fun buildFTSQuery(query: String): String? {
            val trimmed = query.trim()
            val tokens = searchableTokens(trimmed)
            if (tokens.isEmpty()) return null
            if (trimmed.startsWith('"') && trimmed.endsWith('"') && trimmed.length > 2 && trimmed.none { it in "\n\r\u2028\u2029" }) return "\"${tokens.joinToString(" ")}\""
            // FTS4 requires the prefix marker inside quotes. FTS5 uses it outside.
            // Implicit conjunction works with both Android FTS4 parser modes.
            // Explicit AND is a literal word in the standard FTS3/FTS4 parser.
            return tokens.joinToString(" ") { "\"$it*\"" }
        }
    }
}

fun JSONArray.objects(): List<JSONObject> = (0 until length()).map { getJSONObject(it) }
fun JSONArray.strings(): List<String> = (0 until length()).map { getString(it) }

object RotationMath {
    fun index(slot: Long, count: Int): Int {
        require(count >= 0)
        if (count == 0) return 0
        fun gcd(a: Long, b: Long): Long { var x = a; var y = b; while (y != 0L) { val r = x % y; x = y; y = r }; return x }
        var stride = 104_729L
        while (gcd(stride, count.toLong()) != 1L) stride += 2
        return Math.floorMod(Math.floorMod(slot, count.toLong()) * stride + 1729, count.toLong()).toInt()
    }
}

object CompanionCalendar {
    val seasonNames = mapOf("advent" to "Advent", "christmas" to "Christmas", "lent" to "Lent", "triduum" to "The Sacred Triduum", "easter" to "Easter", "ordinary" to "Ordinary Time")
    fun readingsURL(date: LocalDate): String = "https://bible.usccb.org/bible/readings/%02d%02d%02d.cfm".format(date.monthValue, date.dayOfMonth, date.year % 100)
    fun rosarySet(date: LocalDate): String = when (date.dayOfWeek.value) { 1, 6 -> "joyful"; 2, 5 -> "sorrowful"; 4 -> "luminous"; else -> "glorious" }
    fun easter(year: Int): LocalDate {
        val a = year % 19; val b = year / 100; val c = year % 100; val d = b / 4; val e = b % 4
        val f = (b + 8) / 25; val g = (b - f + 1) / 3; val h = (19 * a + b - d - g + 15) % 30
        val i = c / 4; val k = c % 4; val l = (32 + 2 * e + 2 * i - h - k) % 7
        val m = (a + 11 * h + 22 * l) / 451; val n = h + l - 7 * m + 114
        return LocalDate.of(year, n / 31, n % 31 + 1)
    }
    fun season(date: LocalDate): String {
        val christmas = LocalDate.of(date.year, 12, 25)
        val advent = christmas.minusDays((if (christmas.dayOfWeek.value == 7) 7 else christmas.dayOfWeek.value).toLong() + 21)
        val jan2 = LocalDate.of(date.year, 1, 2)
        val epiphany = jan2.plusDays((7 - jan2.dayOfWeek.value).toLong())
        val baptism = epiphany.plusDays(if (epiphany.dayOfMonth >= 7) 1 else 7)
        val easter = easter(date.year)
        return when {
            date <= baptism || date >= christmas -> "christmas"
            date >= advent -> "advent"
            date >= easter && date <= easter.plusDays(49) -> "easter"
            date >= easter.minusDays(3) && date < easter -> "triduum"
            date >= easter.minusDays(46) && date < easter -> "lent"
            else -> "ordinary"
        }
    }
}
