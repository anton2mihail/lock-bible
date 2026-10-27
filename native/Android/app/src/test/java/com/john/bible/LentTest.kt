package com.john.bible

import com.john.bible.data.CompanionCalendar
import com.john.bible.data.FathersAccess
import com.john.bible.data.LentCalendar
import com.john.bible.data.AdventCalendar
import com.john.bible.data.LentContent
import org.json.JSONObject
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/** Lent and Holy Week (1.3.0). Failure list L1–L8 and H1 in docs/john/lent-holyweek-office-year-plan.md. */
class LentTest {
    private fun d(text: String) = LocalDate.parse(text)

    @Test fun ashWednesdayAndEaster() {
        mapOf(2027 to ("2027-02-10" to "2027-03-28"), 2028 to ("2028-03-01" to "2028-04-16"),
            2038 to ("2038-03-10" to "2038-04-25"), 2045 to ("2045-02-22" to "2045-04-09")).forEach { (year, dates) ->
            assertEquals(d(dates.first), LentCalendar.ashWednesday(year))
            assertEquals(d(dates.second), CompanionCalendar.easter(year))
        }
    }

    @Test fun weeksAndKeys() {
        assertEquals("ash-wed", LentCalendar.day(d("2027-02-10"))?.key)
        assertEquals(0, LentCalendar.day(d("2027-02-13"))?.week)
        assertEquals("lent1-sun", LentCalendar.day(d("2027-02-14"))?.key)
        assertEquals("lent5-sat", LentCalendar.day(d("2027-03-20"))?.key)
        assertEquals("palm-sun", LentCalendar.day(d("2027-03-21"))?.key)
        assertEquals("good-fri", LentCalendar.day(d("2027-03-26"))?.key)
        assertEquals("easter-sun", LentCalendar.day(d("2027-03-28"))?.key)
        assertNull(LentCalendar.day(d("2027-02-09")))
        assertNull(LentCalendar.day(d("2027-03-29")))
        val keys = (0L..46L).map { LentCalendar.day(d("2027-02-10").plusDays(it))!!.key }
        assertEquals(LentCalendar.allKeys, keys)
        assertEquals(47, keys.toSet().size)
        assertEquals(39, LentCalendar.lentKeys.size)
    }

    @Test fun sundaysFridaysPassiontideHolyWeek() {
        assertTrue(LentCalendar.day(d("2027-02-21"))!!.isSunday)
        assertTrue(LentCalendar.day(d("2027-02-12"))!!.isFriday)
        assertFalse(LentCalendar.day(d("2027-03-13"))!!.isPassiontide)
        assertTrue(LentCalendar.day(d("2027-03-14"))!!.isPassiontide)
        for (year in listOf(2027, 2028, 2038, 2045)) {
            val easter = CompanionCalendar.easter(year)
            assertTrue(LentCalendar.day(easter.minusDays(7))!!.isHolyWeek)
            assertFalse(LentCalendar.day(easter.minusDays(8))!!.isHolyWeek)
            assertEquals("Good Friday", LentCalendar.day(easter.minusDays(2))!!.dayTitle)
            assertTrue(LentCalendar.day(easter)!!.isEasterSunday)
        }
        assertEquals("Week 3 of Lent", LentCalendar.day(d("2027-02-28"))!!.weekLabel)
        assertEquals("The days after Ash Wednesday", LentCalendar.day(d("2027-02-11"))!!.weekLabel)
    }

    @Test fun neverAdventAndLent() {
        var day = d("2027-01-01")
        repeat(730) {
            assertFalse(LentCalendar.day(day) != null && AdventCalendar.week(day) != null)
            day = day.plusDays(1)
        }
    }

    @Test fun leoIsFreeInLent() {
        val leo = LentCalendar.LEO_WORK_ID
        for (index in 191..204) {
            assertFalse(FathersAccess.isSectionFree(leo, index, d("2027-02-09")))
            assertTrue(FathersAccess.isSectionFree(leo, index, d("2027-02-10")))
            assertTrue(FathersAccess.isSectionFree(leo, index, d("2027-03-28")))
            assertFalse(FathersAccess.isSectionFree(leo, index, d("2027-03-29")))
        }
        assertFalse(FathersAccess.isSectionFree(leo, 190, d("2027-02-10")))
        assertFalse(FathersAccess.isSectionFree(leo, 205, d("2027-02-10")))
        assertFalse(FathersAccess.isSectionFree("augustine.the-city-of-god", 195, d("2027-02-10")))
    }

    /** L3, L5, H2: the data file has one Collect per day, every Holy Week day, and 14 Stations with paintings. */
    @Test fun dataFile() {
        val lent = LentContent.parse(JSONObject(File("../../../src/services/lent/data/lent.json").readText()))
        assertEquals(LentCalendar.allKeys.toSet(), lent.collects.keys)
        assertTrue(lent.collects.values.all { it.text.length > 40 && it.page in 100..400 })
        assertEquals(LentCalendar.holyWeekKeys, lent.holyWeek.map { it.key })
        assertTrue(lent.holyWeek.all { day -> day.sections.isNotEmpty() && day.sections.all { it.paragraphs.isNotEmpty() && it.pages.isNotEmpty() } })
        assertEquals((1..14).toList(), lent.stations.map { it.number })
        assertTrue(lent.stations.all { it.painting == "stations-%02d".format(it.number) && it.verse.size == 4 })
        assertEquals(listOf(6, 31, 37, 50, 101, 129, 142), lent.penitentialPsalms)
        val solemn = lent.holyWeekDay("good-fri")!!.sections.first { it.kind == "solemn-prayers" }
        assertTrue(solemn.paragraphs.none { "emperor" in it || "perfidious" in it })
        assertTrue(solemn.note!!.contains("The Church has since revised them"))
    }
}
