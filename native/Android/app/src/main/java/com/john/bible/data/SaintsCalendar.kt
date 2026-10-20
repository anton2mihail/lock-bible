package com.john.bible.data

import java.time.LocalDate
import java.time.MonthDay

data class SaintCommemoration(
    val id: String, val monthDay: String, val name: String, val excerpt: String,
    val sourceURL: String, val summary: String? = null, val sourceLanguage: String? = null,
    val observanceNote: String? = null, val calendarURL: String = sourceURL
)

data class SaintsCalendar(
    val tradition: String, val sourceName: String, val retrievedOn: String,
    val coverage: String, val entries: List<SaintCommemoration>
) {
    val title: String get() = if (tradition == "byzantine") "Byzantine Catholic · Ruthenian" else "Vatican News · Saints"

    fun on(date: LocalDate): List<SaintCommemoration> {
        val key = MonthDay.from(date).toString().removePrefix("--")
        val includeCassian = tradition == "byzantine" && key == "02-28" && !date.isLeapYear
        return entries.filter { it.monthDay == key || (includeCassian && it.monthDay == "02-29") }
    }
}

fun saintsNoticeBody(calendars: List<SaintsCalendar>, date: LocalDate, gospel: String?): String {
    val lines = calendars.mapNotNull { calendar ->
        calendar.on(date).takeIf { it.isNotEmpty() }?.let { saints ->
            "${calendar.title}: ${saints.joinToString("; ") { it.name }}."
        }
    }.toMutableList()
    if (!gospel.isNullOrBlank()) lines += "Roman Rite Gospel: $gospel."
    lines += "Open today’s saints and readings."
    return lines.joinToString("\n")
}
