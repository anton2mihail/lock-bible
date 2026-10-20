package com.john.bible

import com.john.bible.data.SaintDates
import com.john.bible.data.SaintProfile
import java.time.LocalDate
import java.time.ZonedDateTime
import org.junit.Assert.*
import org.junit.Test

class MySaintsTest {
    @Test fun datesIncludeTodayAndRespectLeapYears() {
        assertEquals(LocalDate.parse("2027-03-19"), SaintDates.nextOccurrence("03-19",LocalDate.parse("2027-03-19")))
        assertEquals(LocalDate.parse("2028-03-19"), SaintDates.nextOccurrence("03-19",LocalDate.parse("2027-03-20")))
        assertEquals(LocalDate.parse("2028-02-29"), SaintDates.nextOccurrence("02-29",LocalDate.parse("2027-01-01")))
        assertEquals(LocalDate.parse("2028-01-01"), SaintDates.nextOccurrence("01-01",LocalDate.parse("2027-12-31")))
    }
    @Test fun remindersPreserveLocalHourAcrossYears() {
        val next=SaintDates.reminderDate("03-19",8,0,ZonedDateTime.parse("2027-03-19T09:00:00-04:00[America/Toronto]"))
        assertEquals(LocalDate.parse("2028-03-19"),next.toLocalDate())
        assertEquals(8,next.hour)
    }
    @Test fun plansOnlyAppearDuringTheNineDaysBeforeTheFeast() {
        val profile=SaintProfile(plannedFeastDate="2027-03-19")
        assertFalse(SaintDates.planIsDue(profile,LocalDate.parse("2027-03-09")))
        assertTrue(SaintDates.planIsDue(profile,LocalDate.parse("2027-03-10")))
        assertTrue(SaintDates.planIsDue(profile,LocalDate.parse("2027-03-18")))
        assertFalse(SaintDates.planIsDue(profile,LocalDate.parse("2027-03-19")))
        assertFalse(SaintDates.planIsDue(profile,LocalDate.parse("2028-03-10")))
    }
    @Test fun widgetAndNoticeLinksOpenTheCorrectSaint() {
        assertEquals("saint/st-joseph",externalRoute("nrsv://saint?id=st-joseph&widget=123"))
        assertEquals("saint-feast/st-joseph",externalRoute("nrsv://saint?id=st-joseph&feast=1"))
        assertEquals("my-saints",externalRoute("nrsv://saint"))
        assertEquals("my-saints",externalRoute("nrsv://saint?id=../../other"))
    }
}
