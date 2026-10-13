package com.john.bible
import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDate
class ExternalRouteTest {
    @Test fun sharedIosPassageLinksKeepTranslationAndVerse() { assertEquals("reader/douay-rheims/JHN/3/16",externalRoute("nrsv://read?book=JHN&chapter=3&verse=16&translation=douay-rheims")) }
    @Test fun badParametersUseReaderDefaults() { assertEquals("reader/web-ce/JHN/1",externalRoute("nrsv://read?book=../../x&chapter=-2&translation=unknown&verse=%3Cbad%3E")) }
    @Test fun malformedDatesUseLocalToday() { assertEquals("daily/${LocalDate.now()}",externalRoute("nrsv://daily?date=2026-02-30")) }
    @Test fun foreignAndMalformedLinksAreIgnored() { assertNull(externalRoute("https://example.com/read")); assertNull(externalRoute("nrsv://read?verse=%ZZ")) }
    @Test fun savedAndPrayerRoutesMatchIos() { assertEquals("saved",externalRoute("nrsv://saved")); assertEquals("rosary",externalRoute("nrsv://pray/rosary")); assertEquals("lectio",externalRoute("nrsv://pray/lectio")) }
}
