package com.john.bible.data

import org.json.JSONObject
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * "A Year with the Fathers" (Android 1.3.0, matching iOS 2.3.0 JohnCore YearPlan): one reading a day from the
 * library through 2027. The plan file (`Catalogs/year-plan.json`) is built by scripts/build-year-plan.mjs.
 * Day 1 is 1 January 2027, so a feast's reading falls on the feast for anyone who joins on the day.
 */
data class YearReading(val workId: String, val section: Int, val fromParagraph: Int, val toParagraph: Int)

data class YearDay(
    val day: Int, val date: String, val season: String, val feast: String?, val author: String, val work: String,
    val title: String, val words: Int, val minutes: Int, val readings: List<YearReading>,
)

class YearPlan(val year: Int, val freeDays: Int, val days: List<YearDay>) {
    fun day(number: Int): YearDay? = days.getOrNull(number - 1)

    companion object {
        fun parse(json: JSONObject): YearPlan {
            require(json.optInt("version") == 1) { "Year plan version" }
            val array = json.getJSONArray("days")
            val days = (0 until array.length()).map { index ->
                val item = array.getJSONObject(index)
                val readings = item.getJSONArray("readings").let { list ->
                    (0 until list.length()).map { list.getJSONObject(it) }.map {
                        YearReading(it.getString("workId"), it.getInt("section"), it.getInt("fromParagraph"), it.getInt("toParagraph"))
                    }
                }
                YearDay(item.getInt("day"), item.getString("date"), item.getString("season"),
                    item.optString("feast").ifBlank { null }, item.getString("author"), item.getString("work"),
                    item.getString("title"), item.getInt("words"), item.getInt("minutes"), readings)
            }
            require(days.map { it.day } == (1..days.size).toList()) { "Year plan days are not numbered 1 to ${days.size}" }
            return YearPlan(json.getInt("year"), json.getInt("freeDays"), days)
        }
    }
}

/** Where a person is in the plan. Dates are calendar days on the device. */
object YearPlanSchedule {
    const val DAY_COUNT = 365
    val YEAR_START: LocalDate = LocalDate.of(2027, 1, 1)

    enum class Start { JOIN_TODAY, BEGIN_AT_DAY_ONE }

    /** The plan day for [today]: 1 on [start]. Zero or less before it; more than 365 after the end. */
    fun dayNumber(start: LocalDate, today: LocalDate): Int = ChronoUnit.DAYS.between(start, today).toInt() + 1

    /** The day of 2027 (1 = 1 January), or null outside 2027. */
    fun dayOfYear(today: LocalDate): Int? = dayNumber(YEAR_START, today).takeIf { it in 1..DAY_COUNT }

    fun isBeforeYear(today: LocalDate): Boolean = today < YEAR_START

    /** Join in January (the seasons still match); begin at Day 1 later. */
    fun suggestedStart(today: LocalDate): Start =
        dayOfYear(today)?.let { if (it <= 31) Start.JOIN_TODAY else Start.BEGIN_AT_DAY_ONE } ?: Start.BEGIN_AT_DAY_ONE

    fun startDate(start: Start, today: LocalDate): LocalDate =
        if (start == Start.JOIN_TODAY && !isBeforeYear(today)) YEAR_START else today

    /** Days before today that are not read, from the day the person joined. */
    fun missedDays(read: Set<Int>, today: Int, joinedAt: Int = 1): List<Int> =
        if (today <= 1) emptyList() else (maxOf(1, joinedAt) until minOf(today, DAY_COUNT + 1)).filter { it !in read }

    /** Days after the free days need the library purchase. */
    fun isLocked(day: Int, freeDays: Int, libraryUnlocked: Boolean): Boolean = !libraryUnlocked && day > freeDays

    /** The day a reminder on [today] names, or null when there is nothing to read (not begun, ended, or read). */
    fun reminderDay(start: LocalDate?, today: LocalDate, read: Set<Int>): Int? {
        start ?: return null
        val day = dayNumber(start, today)
        return day.takeIf { it in 1..DAY_COUNT && it !in read }
    }
}
