package com.john.bible.data

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.time.LocalDate

@RunWith(AndroidJUnit4::class)
class JohnDataTest {
    private lateinit var context: Context
    private lateinit var repository: JohnRepository
    private lateinit var store: JohnStore
    private val preferenceName = "john-data-test"

    @Before fun setup() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        context.getSharedPreferences(preferenceName, Context.MODE_PRIVATE).edit().clear().commit()
        repository = JohnRepository(context)
        store = JohnStore(context, preferenceName)
    }
    @After fun cleanup() {
        repository.close()
        context.getSharedPreferences(preferenceName, Context.MODE_PRIVATE).edit().clear().commit()
    }

    @Test fun completeBibleEditionsReadExactOpeningVerses() {
        val first = mapOf(
            "web-ce" to "In the beginning was the Word, and the Word was with God, and the Word was God.",
            "douay-rheims" to "In the beginning was the Word, and the Word was with God, and the Word was God.",
            "vulgate" to "[In principio erat Verbum, et Verbum erat apud Deum, et Deus erat Verbum."
        )
        for ((edition, text) in first) {
            val books = repository.books(edition)
            assertEquals(73, books.size)
            assertEquals(21, books.first { it.code == "JHN" }.chapters)
            val chapter = repository.chapter(edition, "JHN", 1)
            assertEquals("1", chapter.first().label)
            assertEquals(text, chapter.first().text)
            assertEquals(51, chapter.size)
            assertEquals(edition == "web-ce", chapter.first().paragraphStart)
            assertTrue(repository.chapter(edition, "REV", 22).isNotEmpty())
        }
    }

    @Test fun indexedSearchAndPassageReferencesReturnActualText() {
        val hits = repository.search("web-ce", "beginning Word")
        assertTrue(hits.any { it.book == "JHN" && it.chapter == 1 && it.label == "1" })
        val reference = repository.search("web-ce", "John 3:16–18")
        assertEquals(listOf("16", "17", "18"), reference.map { it.label })
        assertTrue(reference.first().text.contains("God so loved the world"))
        assertEquals("JHN", repository.resolveReference("John 3:16")!!.book)
        val latin = repository.search("vulgate", "principio Verbum")
        assertTrue("Latin hits=${latin.map { it.reference }}; ${searchDiagnostics()}", latin.any { it.book == "JHN" })
        assertTrue(repository.search("web-ce", "\" *").isEmpty())
        assertEquals(listOf("16", "17", "18"), repository.search("web-ce", "Jn. 3:18–16").map { it.label })
        assertEquals("JHN", repository.search("web-ce", "Johm 3:16").first().book)
        assertTrue(repository.search("web-ce", "God", "NT").all { repository.books("web-ce").first { book -> book.code == it.book }.testament == "nt" })
        assertTrue(repository.search("web-ce", "\"God so loved\"").any { it.book == "JHN" && it.chapter == 3 && it.label == "16" })
        assertTrue(repository.search("web-ce", "beg word", book = "JHN").any { it.chapter == 1 && it.label == "1" })
    }

    private fun searchDiagnostics(): String {
        val file = java.io.File(context.noBackupFilesDir, "bundled/bible-search.db")
        return android.database.sqlite.SQLiteDatabase.openDatabase(file.path, null, android.database.sqlite.SQLiteDatabase.OPEN_READONLY).use { db ->
            val options = db.rawQuery("PRAGMA compile_options", null).use { cursor -> buildList { while (cursor.moveToNext()) add(cursor.getString(0)) } }
            val expressions = listOf("\"principio*\" AND \"verbum*\"", "\"principio*\" \"verbum*\"")
            val counts = expressions.associateWith { query -> db.rawQuery("SELECT count(*) FROM verse_search WHERE verse_search MATCH ?", arrayOf(query)).use { cursor -> cursor.moveToFirst(); cursor.getInt(0) } }
            "FTS options=${options.filter { it.contains("FTS") }}; counts=$counts; query=${JohnRepository.buildFTSQuery("principio Verbum")}"
        }
    }

    @Test fun worksDecompressAndCalendarContentLoads() {
        assertEquals(26, repository.workAuthors().size)
        val work = repository.works("augustine").first()
        val summaries = repository.workSections(work.id)
        assertEquals(work.sectionCount, summaries.size)
        val section = repository.workSection(work.id, summaries.first().index)
        assertTrue(section.paragraphs.isNotEmpty())
        assertTrue(section.paragraphs.all { it.isNotEmpty() })
        assertEquals(summaries.first().title, section.title)
        assertEquals(7, repository.content().getJSONArray("novenas").length())
        assertEquals(28, repository.content().getJSONArray("prayers").length())
        assertEquals(5, repository.content().getJSONArray("teachings").length())
        val coverage = repository.calendarCoverage()
        assertNotNull(repository.readings(coverage.first))
        assertNotNull(repository.celebrations("2026-10-13"))
        assertNull(repository.readings("2025-09-18"))
    }

    @Test fun libraryChangesPersistAndRangeColorsPreserveOtherVerses() {
        val chapter = repository.chapter("web-ce", "JHN", 1)
        fun hit(from: Int, to: Int = from) = SearchHit("web-ce", "JHN", "John", 1, if (from == to) "$from" else "$from–$to", chapter.subList(from - 1, to).joinToString(" ") { it.text })
        assertTrue(store.toggleBookmark(hit(1, 3)))
        store.saveNote(hit(1), "A saved reflection")
        store.highlight(hit(1, 5), "yellow")
        store.highlight(hit(3), "blue")
        assertEquals("yellow", store.highlightColor(hit(1)))
        assertEquals("yellow", store.highlightColor(hit(2)))
        assertEquals("blue", store.highlightColor(hit(3)))
        assertEquals("yellow", store.highlightColor(hit(4)))
        assertEquals("yellow", store.highlightColor(hit(5)))
        store.highlight(hit(2, 4), "")
        assertEquals("yellow", store.highlightColor(hit(1)))
        assertNull(store.highlightColor(hit(2)))
        assertNull(store.highlightColor(hit(3)))
        assertNull(store.highlightColor(hit(4)))
        assertEquals("yellow", store.highlightColor(hit(5)))
        val note = store.saved.first { it.kind == "note" }
        store.setTags(note.id, listOf(" Reflection ", "Reflection", ""))
        store.toggleFavoritePrayer("morning")
        store.edition = "douay-rheims"
        store.textSize = 21f
        val restored = JohnStore(context, preferenceName)
        assertTrue(restored.isBookmarked(hit(1, 3)))
        assertEquals("A saved reflection", restored.noteFor(hit(1)))
        assertEquals(listOf("reflection"), restored.saved.first { it.kind == "note" }.tags)
        restored.saveNote(hit(1), "", "[[[0.1,0.2],[0.3,0.4]]]")
        assertEquals("[[[0.1,0.2],[0.3,0.4]]]", JohnStore(context, preferenceName).noteDrawing(hit(1)))
        assertEquals(setOf("morning"), restored.favoritePrayerIds)
        assertEquals("douay-rheims", restored.edition)
        assertEquals(21f, restored.textSize)
        val exported = restored.exportSaved()
        restored.saved.toList().forEach { restored.deleteSaved(it.id) }
        assertEquals(0, restored.saved.size)
        assertTrue(restored.importSaved(exported) >= 4)
        assertTrue(restored.isBookmarked(hit(1, 3)))
        assertEquals(0, restored.importSaved(exported))
        val nativeBackup = org.json.JSONObject(exported).apply { remove("saved"); remove("formatVersion") }
        restored.saved.toList().forEach { restored.deleteSaved(it.id) }
        assertTrue(restored.importSaved(nativeBackup.toString()) >= 4)
        assertTrue(restored.isBookmarked(hit(1, 3)))
        assertEquals("[[[0.1,0.2],[0.3,0.4]]]", restored.noteDrawing(hit(1)))
    }

    @Test fun readingProgressAndNovenaStateSurviveReopen() {
        assertEquals(18f, store.textSize)
        assertEquals(listOf(1), store.todayJohnChapters())
        store.markChapterRead("web-ce", "JHN", 1)
        assertEquals(listOf(2), store.todayJohnChapters())
        assertTrue(store.isChapterRead("vulgate", "JHN", 1))
        assertEquals(1, store.readChapterCount())
        assertEquals(1, store.streak())
        store.startPlan("john-21")
        assertEquals(1, store.planDay())
        assertEquals(emptyList<Int>(), store.todayJohnChapters())
        store.startPlan("john-7")
        assertEquals(listOf(2, 3), store.todayJohnChapters())
        store.startPlan("john-21")
        store.updateNovena("st-joseph", NovenaProgress(setOf(0, 1, 99), 2, "For my family"))
        store.completeNovenaDay("st-joseph")
        store.setReflection("2026-10-13", "Before prayer", "After prayer")
        val restored = JohnStore(context, preferenceName)
        assertEquals(NovenaProgress(setOf(1, 2), 3, "For my family"), restored.novena("st-joseph"))
        assertEquals(Reflection("Before prayer", "After prayer"), restored.reflection("2026-10-13"))
        assertEquals("john-21", restored.planId)
        restored.setChapterRead("web-ce", "JHN", 1, false)
        assertEquals(0, restored.readChapterCount())
        restored.resetProgress()
        assertEquals(0, restored.streak())
        assertNull(restored.planId)
    }

    @Test fun rotationMatchesSourcePermutationAndCalendarBoundaries() {
        for (count in listOf(1, 7, 104729, 35379)) {
            val indices = (0L until count.toLong()).map { RotationMath.index(it, count) }
            assertEquals(count, indices.toSet().size)
            assertEquals(RotationMath.index(-1, count), RotationMath.index(count.toLong() - 1, count))
        }
        assertEquals(0, RotationMath.index(0, 0))
        val verse = repository.rotatingVerse("web-ce", "nt", 1440)
        assertEquals("nt", repository.books("web-ce").first { it.code == verse.book }.testament)
        assertEquals(LocalDate.of(2026, 4, 5), CompanionCalendar.easter(2026))
        assertEquals("lent", CompanionCalendar.season(LocalDate.of(2026, 2, 18)))
        assertEquals("triduum", CompanionCalendar.season(LocalDate.of(2026, 4, 2)))
        assertEquals("easter", CompanionCalendar.season(LocalDate.of(2026, 4, 5)))
        assertEquals("advent", CompanionCalendar.season(LocalDate.of(2026, 11, 29)))
        assertEquals("christmas", CompanionCalendar.season(LocalDate.of(2026, 12, 25)))
    }
}
