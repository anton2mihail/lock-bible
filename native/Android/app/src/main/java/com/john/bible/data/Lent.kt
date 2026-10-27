package com.john.bible.data

import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * Lent and Holy Week (Android 1.3.0, matching iOS 2.3.0 LentCalendar.swift): which day of Lent it is, from Ash
 * Wednesday (Easter − 46) to Easter Sunday. Each day has a key ("ash-wed", "lent1-sun" … "lent5-sat",
 * "palm-sun" … "easter-sun") that names its Collect and its Holy Week texts in `Catalogs/lent.json`.
 */
object LentCalendar {
    data class Day(val key: String, val week: Int, val date: LocalDate, val offset: Int) {
        val isSunday get() = date.dayOfWeek.value == 7
        val isFriday get() = date.dayOfWeek.value == 5
        /** From Passion Sunday (the fifth Sunday) to Holy Saturday. */
        val isPassiontide get() = offset in 32 until 46
        /** Palm Sunday to Easter Sunday. */
        val isHolyWeek get() = offset >= 39
        val isEasterSunday get() = offset == 46
        val weekLabel get() = when (week) { 0 -> "The days after Ash Wednesday"; 6 -> "Holy Week"; else -> "Week $week of Lent" }
        /** The day's own name in Holy Week and on Ash Wednesday, else null. */
        val dayTitle: String? get() = if (offset == 0) "Ash Wednesday" else if (offset >= 39) holyWeekTitles[offset - 39] else null
    }

    const val LEO_WORK_ID = "leo-great.the-letters-and-sermons-of-leo-the-great"
    /** St Leo's sermons on Lent and the Passion: free from Ash Wednesday to Easter Sunday (decision L1). */
    val leoSections = 191..204

    private val weekdayKeys = listOf("sun", "mon", "tue", "wed", "thu", "fri", "sat")
    val holyWeekKeys = listOf("palm-sun", "holy-mon", "holy-tue", "holy-wed", "holy-thu", "good-fri", "holy-sat", "easter-sun")
    val holyWeekTitles = listOf("Palm Sunday", "Monday of Holy Week", "Tuesday of Holy Week", "Wednesday of Holy Week",
        "Holy Thursday", "Good Friday", "Holy Saturday", "Easter Sunday")
    val lentKeys = listOf("ash-wed", "ash-thu", "ash-fri", "ash-sat") + (1..5).flatMap { w -> weekdayKeys.map { "lent$w-$it" } }
    val allKeys = lentKeys + holyWeekKeys

    fun ashWednesday(year: Int): LocalDate = CompanionCalendar.easter(year).minusDays(46)

    /** The day of Lent or Holy Week on [date], or null before Ash Wednesday and after Easter Sunday. */
    fun day(date: LocalDate): Day? {
        val offset = ChronoUnit.DAYS.between(ashWednesday(date.year), date).toInt()
        if (offset !in 0..46) return null
        val week = if (offset < 4) 0 else if (offset < 39) (offset - 4) / 7 + 1 else 6
        return Day(allKeys[offset], week, date, offset)
    }

    fun isLeoSeason(date: LocalDate): Boolean = day(date) != null
}

/**
 * The texts of Lent, Holy Week and the Stations of the Cross from `Catalogs/lent.json` (iOS LentContent.swift).
 * Every text is quoted from The Missal (1926 printing) or A Manual of Prayers (Baltimore, 1889) with its page.
 */
data class LentContent(
    val collects: Map<String, Collect>,
    val holyWeek: List<HolyWeekDay>,
    val opening: Part,
    val stations: List<Station>,
    val closing: Part?,
    val penitentialPsalms: List<Int>,
) {
    data class Collect(val title: String, val text: String, val page: Int, val scan: String, val book: String?)
    data class Section(val id: String, val title: String, val kind: String, val paragraphs: List<String>, val rubrics: List<String>, val pages: List<Int>)
    data class HolyWeekDay(val key: String, val title: String, val sections: List<Section>)
    data class Part(val title: String, val paragraphs: List<String>, val pages: List<Int>)
    data class Station(val number: Int, val title: String, val versicle: String, val response: String, val meditation: String,
                       val prayer: String, val after: String, val verse: List<String>, val pages: List<Int>, val painting: String)

    fun holyWeekDay(key: String) = holyWeek.firstOrNull { it.key == key }

    companion object {
        private fun strings(array: JSONArray?) = (0 until (array?.length() ?: 0)).map { array!!.getString(it) }
        private fun ints(array: JSONArray?) = (0 until (array?.length() ?: 0)).map { array!!.getInt(it) }
        private fun objects(array: JSONArray) = (0 until array.length()).map { array.getJSONObject(it) }
        private fun part(json: JSONObject) = Part(json.getString("title"), strings(json.getJSONArray("paragraphs")), ints(json.getJSONArray("pages")))

        fun parse(json: JSONObject): LentContent {
            val collects = json.getJSONObject("collects").let { all ->
                all.keys().asSequence().associateWith { key ->
                    all.getJSONObject(key).let { Collect(it.getString("title"), it.getString("text"), it.getInt("page"), it.getString("scan"), it.optString("book").ifBlank { null }) }
                }
            }
            val holyWeek = objects(json.getJSONArray("holyWeek")).map { day ->
                HolyWeekDay(day.getString("key"), day.getString("title"), objects(day.getJSONArray("sections")).map {
                    Section(it.getString("id"), it.getString("title"), it.getString("kind"), strings(it.getJSONArray("paragraphs")),
                        strings(it.optJSONArray("rubrics")), ints(it.getJSONArray("pages")))
                })
            }
            val stations = json.getJSONObject("stations")
            return LentContent(collects, holyWeek, part(stations.getJSONObject("opening")),
                objects(stations.getJSONArray("stations")).map {
                    Station(it.getInt("number"), it.getString("title"), it.getString("versicle"), it.getString("response"),
                        it.getString("meditation"), it.getString("prayer"), it.getString("after"), strings(it.getJSONArray("verse")),
                        ints(it.getJSONArray("pages")), it.getString("painting"))
                },
                stations.optJSONObject("closing")?.let { part(it) },
                ints(json.getJSONArray("penitentialPsalms")))
        }
    }
}
