package com.john.bible.data

import java.text.Normalizer
import java.util.Locale

data class ParsedBibleReference(val book: BibleBook, val chapter: Int, val startVerse: String?, val endVerse: String?)

/** Uses the same aliases and bounded spelling correction as the iOS reference parser. */
object BibleReferenceParser {
    private val aliases = mapOf(
        "GEN" to listOf("gen"), "EXO" to listOf("ex", "exod"), "LEV" to listOf("lev"), "NUM" to listOf("num"),
        "DEU" to listOf("deut", "dt"), "JOS" to listOf("josh"), "JDG" to listOf("judg"),
        "PSA" to listOf("ps", "psalm", "psalms"), "PRO" to listOf("prov"), "ECC" to listOf("eccl"),
        "SNG" to listOf("song", "song of songs", "songs", "sos"), "ISA" to listOf("isa"),
        "JER" to listOf("jer"), "LAM" to listOf("lam"), "EZK" to listOf("ezek", "ezk"), "DAN" to listOf("dan"),
        "OBA" to listOf("obad"), "MIC" to listOf("mic"), "NAM" to listOf("nah", "nahum"), "HAB" to listOf("hab"),
        "ZEP" to listOf("zeph"), "HAG" to listOf("hag"), "ZEC" to listOf("zech"), "MAL" to listOf("mal"),
        "MAT" to listOf("matt", "mt"), "MRK" to listOf("mark", "mk"), "LUK" to listOf("luke", "lk"),
        "JHN" to listOf("john", "jn"), "ACT" to listOf("acts"), "ROM" to listOf("rom"), "GAL" to listOf("gal"),
        "EPH" to listOf("eph"), "PHP" to listOf("phil", "philippians"), "COL" to listOf("col"), "TIT" to listOf("tit"),
        "PHM" to listOf("phlm", "philemon"), "HEB" to listOf("heb"), "JAS" to listOf("jas", "james"),
        "JUD" to listOf("jude"), "REV" to listOf("rev", "revelation")
    )
    fun normalize(value: String): String = Normalizer.normalize(value, Normalizer.Form.NFKD)
        .replace(Regex("\\p{M}"), "").lowercase(Locale.ENGLISH).replace(".", "")
        .replace(Regex("[\\s\\p{Z}]+"), " ").trim()
    private fun names(book: BibleBook): List<String> = (listOf(book.code, book.name, book.longName, book.name.replace(Regex("^([1-4])\\s+"), "$1")) + aliases[book.code].orEmpty()).map(::normalize)
    fun findBook(value: String, books: List<BibleBook>): BibleBook? {
        val input = normalize(value)
        books.firstOrNull { input in names(it) }?.let { return it }
        if (input.length < 4) return null
        val maximum = if (input.length >= 8) 2 else 1
        var best: BibleBook? = null
        var bestDistance = maximum + 1
        for (book in books) for (name in names(book)) {
            val distance = editDistance(input, name, maximum)
            if (distance < bestDistance) { best = book; bestDistance = distance }
        }
        return best
    }
    fun editDistance(left: String, right: String, maximum: Int = Int.MAX_VALUE): Int {
        if (kotlin.math.abs(left.length - right.length) > maximum) return maximum + 1
        var previous = IntArray(right.length + 1) { it }
        for (i in left.indices) {
            val current = IntArray(right.length + 1)
            current[0] = i + 1
            var minimum = current[0]
            for (j in right.indices) {
                current[j + 1] = minOf(previous[j + 1] + 1, current[j] + 1, previous[j] + if (left[i] == right[j]) 0 else 1)
                minimum = minOf(minimum, current[j + 1])
            }
            if (minimum > maximum) return maximum + 1
            previous = current
        }
        return previous.last()
    }
    fun parse(query: String, books: List<BibleBook>): ParsedBibleReference? {
        val value = query.replace('–', '-').replace('—', '-').trim()
        val match = Regex("^(.+?)[\\s\\p{Z}]+([0-9]+)(?:(?:\\s*:\\s*|\\s+)([0-9]+[a-z]?)(?:\\s*-\\s*([0-9]+[a-z]?))?)?$", RegexOption.IGNORE_CASE).matchEntire(value) ?: return null
        val book = findBook(match.groupValues[1], books) ?: return null
        val chapter = match.groupValues[2].toIntOrNull() ?: return null
        if (chapter !in 1..book.chapters) return null
        val start = match.groupValues[3].ifEmpty { null }
        val end = match.groupValues[4].ifEmpty { start }
        return ParsedBibleReference(book, chapter, start, end)
    }
}
