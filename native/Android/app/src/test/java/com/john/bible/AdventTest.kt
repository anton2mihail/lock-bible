package com.john.bible

import com.john.bible.data.AdventCalendar
import com.john.bible.data.GospelFathers
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDate

/** The same failure list as iOS AdventCalendarTests and GospelFathersTests. */
class AdventTest {
    private fun d(y: Int, m: Int, day: Int) = LocalDate.of(y, m, day)

    @Test fun a1FirstSunday() {
        assertEquals(d(2026, 11, 29), AdventCalendar.firstSunday(2026))
        assertEquals(d(2027, 11, 28), AdventCalendar.firstSunday(2027))
        assertEquals(d(2022, 11, 27), AdventCalendar.firstSunday(2022))
    }
    @Test fun a2Weeks() {
        assertEquals(1, AdventCalendar.week(d(2026, 11, 29))); assertEquals(1, AdventCalendar.week(d(2026, 12, 5)))
        assertEquals(2, AdventCalendar.week(d(2026, 12, 6))); assertEquals(4, AdventCalendar.week(d(2026, 12, 20)))
        assertEquals(4, AdventCalendar.week(d(2026, 12, 24)))
    }
    @Test fun a3Outside() {
        assertNull(AdventCalendar.week(d(2026, 11, 28))); assertNull(AdventCalendar.week(d(2026, 12, 25))); assertNull(AdventCalendar.week(d(2027, 1, 3)))
    }
    @Test fun o1Antiphons() {
        assertEquals((17..23).toList(), AdventCalendar.antiphons.map { it.day })
        assertEquals("O Wisdom", AdventCalendar.antiphon(d(2026, 12, 17))?.title)
        assertEquals("O Emmanuel", AdventCalendar.antiphon(d(2026, 12, 23))?.title)
    }
    @Test fun o2NoAntiphon() {
        assertNull(AdventCalendar.antiphon(d(2026, 12, 16))); assertNull(AdventCalendar.antiphon(d(2026, 12, 24))); assertNull(AdventCalendar.antiphon(d(2026, 11, 17)))
    }

    @Test fun pParse() {
        assertEquals(GospelFathers.Reference("MAT", 9, 35), GospelFathers.parse("Matthew 9:35–10:1, 5a, 6-8"))
        assertEquals(GospelFathers.Reference("LUK", 7, 18), GospelFathers.parse("Luke 7:18b-23"))
        assertNull(GospelFathers.parse("Psalm 80:2-3")); assertNull(GospelFathers.parse("Mark")); assertNull(GospelFathers.parse("Mark 0:1"))
        assertEquals(GospelFathers.Reference("MAT", 15, 21), GospelFathers.parse("Matthew 15: 21-28"))
        assertEquals(GospelFathers.Reference("JHN", 1, 1), GospelFathers.parse("John 1:1-18"))
    }
    @Test fun p5LastGospel() {
        val entry = JSONObject("""{"title":"Palm Sunday","readings":[{"label":"Gospel at the procession","reference":"Mark 11:1-10"},{"label":"First reading","reference":"Isaiah 50:4-7"},{"label":"Gospel","reference":"Mark 14:1–15:47"}]}""")
        assertEquals("Mark 14:1–15:47", GospelFathers.gospelReference(entry))
    }

    private fun catena(index: Int, from: Int, to: Int) = JSONObject(mapOf("workId" to "aquinas.catena-aurea-matthew", "sectionIndex" to index, "fromVerse" to from, "toVerse" to to))
    private val chrysostom = JSONObject(mapOf("workId" to "chrysostom.homilies-on-matthew", "sectionIndex" to 4))
    private fun ref(verse: Int) = GospelFathers.Reference("MAT", 1, verse)

    @Test fun lLookup() {
        assertEquals(1, GospelFathers.entry(ref(4), listOf(catena(0, 1, 1), catena(1, 2, 5), catena(2, 6, 8)))?.optInt("sectionIndex"))
        assertEquals(1, GospelFathers.entry(ref(6), listOf(catena(2, 6, 8), catena(1, 3, 6)))?.optInt("sectionIndex"))
        assertEquals(1, GospelFathers.entry(ref(12), listOf(catena(0, 1, 5), catena(1, 6, 8)))?.optInt("sectionIndex"))
        assertEquals("chrysostom.homilies-on-matthew", GospelFathers.entry(ref(26), listOf(chrysostom))?.optString("workId"))
        assertNull(GospelFathers.entry(ref(1), emptyList()))
    }
    @Test fun eExcerpt() {
        val e1 = GospelFathers.excerpt(listOf("1. The book of the generation.", "Aug., de Cons. Ev., ii, 1: Matthew wrote for the Jews."))
        assertEquals("St Augustine", e1?.father); assertEquals("Matthew wrote for the Jews.", e1?.text)
        val long = "The word was made flesh and dwelt among us. ".repeat(20)
        val e2 = GospelFathers.excerpt(listOf("v", "Chrys.: $long"), limit = 120)
        assertEquals("St John Chrysostom", e2?.father); assertTrue((e2?.text?.length ?: 0) <= 120); assertTrue(e2!!.text.endsWith("."))
        val e3 = GospelFathers.excerpt(listOf("v", "Some reader says: the light shines."))
        assertEquals("The Fathers", e3?.father); assertEquals("Some reader says: the light shines.", e3?.text)
        assertNull(GospelFathers.excerpt(listOf("1. In the beginning.")))
        assertEquals("St Jerome", GospelFathers.excerpt(listOf("v", "Gloss.: A note.", "Pseudo-Chrys.: Another.", "Jerome: The Father speaks."))?.father)
        assertEquals("The Gloss", GospelFathers.excerpt(listOf("v", "Gloss.: Only a note."))?.father)
        assertEquals("Titus of Bostra", GospelFathers.excerpt(listOf("v", "Greek Ex: A note.", "Titus Bost: The Father speaks."))?.father)
    }
    @Test fun adventLinkOpensAdvent() { assertEquals("advent", externalRoute("nrsv://advent")) }
}
