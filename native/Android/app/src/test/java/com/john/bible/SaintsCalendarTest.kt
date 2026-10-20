package com.john.bible

import com.john.bible.data.SaintCommemoration
import com.john.bible.data.SaintsCalendar
import com.john.bible.data.saintsNoticeBody
import java.time.LocalDate
import org.junit.Assert.*
import org.junit.Test

class SaintsCalendarTest {
    private val cassian = SaintCommemoration("cassian", "02-29", "Cassian", "A monk.", "https://mci.archpitt.org/menaion/02-29.html")
    private val byzantine = SaintsCalendar("byzantine", "MCI", "2026-10-20", "", listOf(cassian))

    @Test fun cassianMovesToComplineOnFebruary28OnlyInNonLeapYears() {
        assertEquals(listOf(cassian), byzantine.on(LocalDate.of(2027, 2, 28)))
        assertTrue(byzantine.on(LocalDate.of(2028, 2, 28)).isEmpty())
        assertEquals(listOf(cassian), byzantine.on(LocalDate.of(2028, 2, 29)))
    }

    @Test fun notificationIncludesBothCalendarsAndAllNames() {
        val saints = listOf(
            SaintCommemoration("one", "02-28", "First saint", "", "https://www.vaticannews.va/en/saints/02/28.html"),
            SaintCommemoration("two", "02-28", "Second saint", "", "https://www.vaticannews.va/en/saints/02/28.html")
        )
        val vatican = SaintsCalendar("vatican", "Vatican News", "2026-10-20", "", saints)
        val body = saintsNoticeBody(listOf(vatican, byzantine), LocalDate.of(2035, 2, 28), "John 1:1")
        assertTrue(body.contains("First saint; Second saint"))
        assertTrue(body.contains("Byzantine Catholic · Ruthenian: Cassian"))
        assertTrue(body.contains("Roman Rite Gospel: John 1:1"))
        assertFalse(saintsNoticeBody(listOf(vatican), LocalDate.of(2035, 2, 28), null).contains("Gospel:"))
    }
}
