package com.john.bible.ui

/** One page of a measured chapter. Lines are [startLine, endLine). Offsets are [startOffset, endOffset). */
internal data class PageSlice(val startLine: Int, val endLine: Int, val top: Float, val bottom: Float, val startOffset: Int, val endOffset: Int)

/** A reading position that does not depend on the page size or the text size. */
internal data class PageAnchor(val label: String, val offset: Int = 0, val last: Boolean = false) {
    fun encode() = "$label\u001f$offset\u001f$last"
    companion object {
        val First = PageAnchor("")
        val Last = PageAnchor("", last = true)
        fun decode(value: String): PageAnchor {
            val parts = value.split('\u001f')
            return PageAnchor(parts.getOrElse(0) { "" }, parts.getOrNull(1)?.toIntOrNull() ?: 0, parts.getOrNull(2) == "true")
        }
    }
}

/** Page and chapter arithmetic without Android or Compose types, so JVM tests can check it. */
internal object PageMath {
    /**
     * Puts measured lines on pages that are not taller than [height].
     * Each page has at least one line. A page after the first never starts with a spacer line.
     */
    fun pageLines(tops: FloatArray, bottoms: FloatArray, spacer: BooleanArray, height: Float): List<IntRange> {
        require(tops.size == bottoms.size && tops.size == spacer.size)
        val pages = mutableListOf<IntRange>()
        var line = 0
        while (line < tops.size) {
            if (pages.isNotEmpty()) while (line < tops.size && spacer[line]) line++
            if (line >= tops.size) break
            val top = tops[line]
            var end = line + 1
            while (end < tops.size && bottoms[end] - top <= height) end++
            pages += line until end
            line = end
        }
        return pages
    }

    /** The index of the last start that is not after [offset], or -1. [starts] is in ascending order. */
    fun lastAtOrBefore(starts: IntArray, offset: Int): Int {
        var low = 0
        var high = starts.size - 1
        var found = -1
        while (low <= high) {
            val middle = (low + high) ushr 1
            if (starts[middle] <= offset) { found = middle; low = middle + 1 } else high = middle - 1
        }
        return found
    }

    /** The page that holds [offset]. */
    fun pageForOffset(pageStarts: IntArray, offset: Int): Int = lastAtOrBefore(pageStarts, offset).coerceAtLeast(0)

    /** The page for a saved anchor. Unknown labels open the first page. */
    fun pageForAnchor(anchor: PageAnchor, labels: List<String>, verseStarts: IntArray, verseEnds: IntArray, pageStarts: IntArray): Int {
        if (pageStarts.isEmpty()) return 0
        if (anchor.last) return pageStarts.lastIndex
        val verse = labels.indexOf(anchor.label)
        if (verse < 0) return 0
        val length = (verseEnds[verse] - verseStarts[verse]).coerceAtLeast(1)
        return pageForOffset(pageStarts, verseStarts[verse] + anchor.offset.coerceIn(0, length - 1))
    }

    /** The anchor for the first character of a page. Text before the first verse belongs to the first verse. */
    fun anchorForPage(page: Int, labels: List<String>, verseStarts: IntArray, pageStarts: IntArray): PageAnchor {
        if (labels.isEmpty() || page !in pageStarts.indices) return PageAnchor.First
        val offset = pageStarts[page]
        val verse = lastAtOrBefore(verseStarts, offset)
        return if (verse < 0) PageAnchor(labels.first(), 0) else PageAnchor(labels[verse], offset - verseStarts[verse])
    }

    /** The chapter before or after a chapter, across book limits. [books] holds each book code and chapter count in canonical order. */
    fun adjacentChapter(books: List<Pair<String, Int>>, book: String, chapter: Int, step: Int): Pair<String, Int>? {
        val index = books.indexOfFirst { it.first == book }
        if (index < 0) return null
        val next = chapter + step
        if (next in 1..books[index].second) return book to next
        val other = books.getOrNull(index + step) ?: return null
        return if (step > 0) other.first to 1 else other.first to other.second
    }

    /** Text for the page footer, as Play Books shows it. */
    fun pagesLeftText(page: Int, count: Int): String = when (val left = count - page - 1) {
        0 -> "Last page in chapter"
        1 -> "1 page left in chapter"
        else -> "$left pages left in chapter"
    }
}
