package com.john.bible
import com.john.bible.data.*
import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDate
class CalendarRotationTest {
    @Test fun rotationVisitsEveryVerseBeforeRepeating() { for(count in listOf(1,7,31,104729)) { val values=(0 until count).map { RotationMath.index(it.toLong(),count) }.toSet(); assertEquals(count,values.size) } }
    @Test fun rotationWorksBeforeEpoch() { for(slot in -100L..100L) assertTrue(RotationMath.index(slot,73) in 0..72) }
    @Test fun churchSeasonsRespectBoundaries() {
        assertEquals(LocalDate.of(2026,4,5),CompanionCalendar.easter(2026))
        assertEquals("lent",CompanionCalendar.season(LocalDate.of(2026,2,18)))
        assertEquals("triduum",CompanionCalendar.season(LocalDate.of(2026,4,2)))
        assertEquals("easter",CompanionCalendar.season(LocalDate.of(2026,4,5)))
        assertEquals("advent",CompanionCalendar.season(LocalDate.of(2026,11,29)))
        assertEquals("christmas",CompanionCalendar.season(LocalDate.of(2026,12,25)))
    }
    @Test fun weekdayMysteriesMatchIos() { val monday=LocalDate.of(2026,10,12); assertEquals(listOf("joyful","sorrowful","glorious","luminous","sorrowful","joyful","glorious"),(0..6).map { CompanionCalendar.rosarySet(monday.plusDays(it.toLong())) }) }
}
