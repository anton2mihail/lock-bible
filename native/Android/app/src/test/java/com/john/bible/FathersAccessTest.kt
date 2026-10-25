package com.john.bible

import com.john.bible.data.FathersAccess
import com.john.bible.data.ReviewPromptPolicy
import java.time.ZoneId
import org.junit.Assert.*
import org.junit.Test

// Ways the access and rating rules can fail. Each test maps to one entry.
//
// F1. A section past the sample reads free in a paid work.
// F2. The first section of a paid work is locked.
// F3. A negative index reads free.
// F4. The Apostolic Fathers lock after their first section.
// F5. The Confessions lock after their first section.
// F6. A look-alike collection prefix reads free.
// F7. A single-section work or a free work shows an unlock notice it never needs.
// G1. An update from an older version (install time before update time) loses the library.
// G2. A fresh install gets the library free.
// G3. A saved decision is ignored, so a later update grandfathers a person who bought nothing.
// G4. Missing install times grandfather by mistake.
// R1. The rating prompt appears before either threshold.
// R2. Either threshold fails to allow the first prompt.
// R3. A second prompt appears inside 120 days.
// R4. Day keys follow UTC instead of the person's zone.
class FathersAccessTest {
    @Test fun f1PastSampleLocked() {
        assertFalse(FathersAccess.isSectionFree("ambrose.on-the-duties-of-the-clergy", 1))
    }
    @Test fun f2SampleFree() {
        assertTrue(FathersAccess.isSectionFree("ambrose.on-the-duties-of-the-clergy", 0))
    }
    @Test fun f3NegativeIndex() {
        assertFalse(FathersAccess.isSectionFree("ambrose.on-the-duties-of-the-clergy", -1))
    }
    @Test fun f4ApostolicFathersFree() {
        assertTrue(FathersAccess.isSectionFree("apostolic-fathers.the-didache", 7))
    }
    @Test fun f5ConfessionsFree() {
        assertTrue(FathersAccess.isSectionFree("augustine.the-confessions", 12))
        assertFalse(FathersAccess.isSectionFree("augustine.the-city-of-god", 12))
    }
    @Test fun f6LookAlikePrefix() {
        assertFalse(FathersAccess.isSectionFree("apostolic-fathers-extra.work", 3))
        assertFalse(FathersAccess.isSectionFree("apostolic-fathers", 3))
        assertFalse(FathersAccess.isSectionFree(".apostolic-fathers", 3))
    }
    @Test fun f7WholeWorkFree() {
        assertTrue(FathersAccess.isWorkFree("leo-great.letters", 1))
        assertTrue(FathersAccess.isWorkFree("augustine.the-confessions", 13))
        assertFalse(FathersAccess.isWorkFree("augustine.the-city-of-god", 22))
    }
    @Test fun g1UpdateKeepsLibrary() {
        assertTrue(FathersAccess.decideGrandfathered(null, 1_700_000_000_000, 1_790_000_000_000))
    }
    @Test fun g2FreshInstallPays() {
        assertFalse(FathersAccess.decideGrandfathered(null, 1_790_000_000_000, 1_790_000_000_000))
    }
    @Test fun g3SavedDecisionWins() {
        assertFalse(FathersAccess.decideGrandfathered(false, 1_700_000_000_000, 1_790_000_000_000))
        assertTrue(FathersAccess.decideGrandfathered(true, 1_790_000_000_000, 1_790_000_000_000))
    }
    @Test fun g4MissingTimes() {
        assertFalse(FathersAccess.decideGrandfathered(null, 0, 1_790_000_000_000))
        assertFalse(FathersAccess.decideGrandfathered(null, 1_700_000_000_000, -1))
    }
    private val now = 1_792_800_000_000L
    @Test fun r1TooEarly() {
        assertFalse(ReviewPromptPolicy.shouldAsk(2, 6, null, now))
    }
    @Test fun r2Thresholds() {
        assertTrue(ReviewPromptPolicy.shouldAsk(3, 1, null, now))
        assertTrue(ReviewPromptPolicy.shouldAsk(0, 7, null, now))
    }
    @Test fun r3Cooldown() {
        assertFalse(ReviewPromptPolicy.shouldAsk(9, 30, now - 119L * 86_400_000L, now))
        assertTrue(ReviewPromptPolicy.shouldAsk(9, 30, now - 120L * 86_400_000L, now))
    }
    @Test fun r4LocalDay() {
        // 2026-10-24 03:30 UTC is still 2026-10-23 in Toronto.
        assertEquals("2026-10-23", ReviewPromptPolicy.dayKey(1_792_812_600_000L, ZoneId.of("America/Toronto")))
        assertEquals("2026-10-24", ReviewPromptPolicy.dayKey(1_792_812_600_000L, ZoneId.of("UTC")))
    }
}
