package com.john.bible

import com.john.bible.data.YearPlan
import com.john.bible.data.YearPlanSchedule
import com.john.bible.data.YearPlanSchedule.Start
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.time.LocalDate

/** The same failure list as iOS YearPlanTests (Y3, Y4, Y7). */
class YearPlanTest {
    private fun d(y: Int, m: Int, day: Int) = LocalDate.of(y, m, day)
    private val plan by lazy {
        // Gradle runs unit tests from native/Android/app.
        YearPlan.parse(JSONObject(File("../../../src/services/works/data/year-plan.json").readText()))
    }

    @Test fun loadsThePlanFile() {
        assertEquals(365, plan.days.size)
        assertEquals(7, plan.freeDays)
        assertEquals("2027-01-01", plan.day(1)?.date)
        assertEquals("2027-12-31", plan.day(365)?.date)
        assertEquals("Easter Sunday", plan.day(87)?.feast)
        assertNull(plan.day(0)); assertNull(plan.day(366))
    }

    /** Y7: joining on Ash Wednesday gives Day 41; New Year's Eve is still before the year. */
    @Test fun y7JoinToday() {
        assertEquals(41, YearPlanSchedule.dayOfYear(d(2027, 2, 10)))
        assertTrue(YearPlanSchedule.isBeforeYear(d(2026, 12, 31)))
        assertNull(YearPlanSchedule.dayOfYear(d(2026, 12, 31)))
        assertEquals(1, YearPlanSchedule.dayOfYear(d(2027, 1, 1)))
        assertEquals(365, YearPlanSchedule.dayOfYear(d(2027, 12, 31)))
        assertNull(YearPlanSchedule.dayOfYear(d(2028, 1, 1)))
    }

    /** Y3: days count by calendar day, and days before joining are never missed. */
    @Test fun y3DayNumbers() {
        assertEquals(15, YearPlanSchedule.dayNumber(d(2027, 3, 1), d(2027, 3, 15)))
        assertEquals(0, YearPlanSchedule.dayNumber(d(2027, 1, 1), d(2026, 12, 31)))
        assertEquals(listOf(3, 5), YearPlanSchedule.missedDays(setOf(1, 2, 4), 6))
        assertEquals(emptyList<Int>(), YearPlanSchedule.missedDays(emptySet(), 41, joinedAt = 41))
        assertEquals(listOf(42, 43), YearPlanSchedule.missedDays(setOf(41), 44, joinedAt = 41))
        assertEquals(365, YearPlanSchedule.missedDays(emptySet(), 400).size)
    }

    @Test fun startChoices() {
        assertEquals(Start.JOIN_TODAY, YearPlanSchedule.suggestedStart(d(2027, 1, 15)))
        assertEquals(Start.BEGIN_AT_DAY_ONE, YearPlanSchedule.suggestedStart(d(2027, 3, 2)))
        assertEquals(Start.BEGIN_AT_DAY_ONE, YearPlanSchedule.suggestedStart(d(2026, 12, 20)))
        assertEquals(d(2027, 1, 1), YearPlanSchedule.startDate(Start.JOIN_TODAY, d(2027, 3, 2)))
        assertEquals(d(2027, 3, 2), YearPlanSchedule.startDate(Start.BEGIN_AT_DAY_ONE, d(2027, 3, 2)))
        assertEquals(d(2026, 12, 20), YearPlanSchedule.startDate(Start.JOIN_TODAY, d(2026, 12, 20)))
    }

    /** Y4: Day 8 and later need the library purchase. */
    @Test fun y4DayEight() {
        assertFalse(YearPlanSchedule.isLocked(7, 7, false))
        assertTrue(YearPlanSchedule.isLocked(8, 7, false))
        assertFalse(YearPlanSchedule.isLocked(8, 7, true))
    }

    @Test fun reminders() {
        assertEquals(1, YearPlanSchedule.reminderDay(d(2027, 1, 1), d(2027, 1, 1), emptySet()))
        assertNull(YearPlanSchedule.reminderDay(d(2027, 1, 1), d(2026, 12, 30), emptySet()))
        assertNull(YearPlanSchedule.reminderDay(d(2027, 1, 1), d(2027, 1, 1), setOf(1)))
        assertNull(YearPlanSchedule.reminderDay(d(2027, 1, 1), d(2028, 1, 1), emptySet()))
        assertNull(YearPlanSchedule.reminderDay(null, d(2027, 1, 1), emptySet()))
    }
}
