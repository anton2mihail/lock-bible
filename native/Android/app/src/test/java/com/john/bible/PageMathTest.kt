package com.john.bible

import com.john.bible.ui.PageAnchor
import com.john.bible.ui.PageMath
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PageMathTest {
    private fun lines(vararg heights: Float): Pair<FloatArray, FloatArray> {
        val tops = FloatArray(heights.size)
        val bottoms = FloatArray(heights.size)
        var y = 0f
        heights.forEachIndexed { i, h -> tops[i] = y; y += h; bottoms[i] = y }
        return tops to bottoms
    }

    @Test fun linesFillPagesWithoutOverflow() {
        val (tops, bottoms) = lines(10f, 10f, 10f, 10f, 10f, 10f, 10f)
        val pages = PageMath.pageLines(tops, bottoms, BooleanArray(7), 30f)
        assertEquals(listOf(0..2, 3..5, 6..6), pages)
    }

    @Test fun spacerLinesNeverStartALaterPage() {
        val (tops, bottoms) = lines(10f, 10f, 4f, 10f, 10f)
        val spacer = booleanArrayOf(true, false, true, false, false)
        // The first page keeps its leading spacer. The spacer after line 1 moves off the top of page 2.
        assertEquals(listOf(0..1, 3..4), PageMath.pageLines(tops, bottoms, spacer, 20f))
    }

    @Test fun aLineTallerThanThePageStillGetsAPage() {
        val (tops, bottoms) = lines(50f, 10f)
        assertEquals(listOf(0..0, 1..1), PageMath.pageLines(tops, bottoms, BooleanArray(2), 20f))
    }

    @Test fun anchorsSurviveRepagination() {
        val labels = listOf("1", "2", "3", "4")
        val verseStarts = intArrayOf(10, 40, 90, 150)
        val verseEnds = intArrayOf(39, 89, 149, 200)
        // Small text: two pages. The second page starts inside verse 3.
        val small = intArrayOf(0, 120)
        val anchor = PageMath.anchorForPage(1, labels, verseStarts, small)
        assertEquals(PageAnchor("3", 30), anchor)
        // Large text: more pages. The anchor opens the page that holds character 120.
        val large = intArrayOf(0, 45, 100, 130, 170)
        assertEquals(2, PageMath.pageForAnchor(anchor, labels, verseStarts, verseEnds, large))
        assertEquals(4, PageMath.pageForAnchor(PageAnchor.Last, labels, verseStarts, verseEnds, large))
        assertEquals(0, PageMath.pageForAnchor(PageAnchor("99"), labels, verseStarts, verseEnds, large))
        assertEquals(PageAnchor("1", 0), PageMath.anchorForPage(0, labels, verseStarts, large))
        assertEquals(anchor, PageAnchor.decode(anchor.encode()))
    }

    @Test fun adjacentChaptersCrossBookLimits() {
        val books = listOf("GEN" to 50, "EXO" to 40, "REV" to 22)
        assertEquals("GEN" to 2, PageMath.adjacentChapter(books, "GEN", 1, 1))
        assertEquals("EXO" to 1, PageMath.adjacentChapter(books, "GEN", 50, 1))
        assertEquals("GEN" to 50, PageMath.adjacentChapter(books, "EXO", 1, -1))
        assertNull(PageMath.adjacentChapter(books, "GEN", 1, -1))
        assertNull(PageMath.adjacentChapter(books, "REV", 22, 1))
    }

    @Test fun footerCountsPagesLeft() {
        assertEquals("3 pages left in chapter", PageMath.pagesLeftText(0, 4))
        assertEquals("1 page left in chapter", PageMath.pagesLeftText(2, 4))
        assertEquals("Last page in chapter", PageMath.pagesLeftText(3, 4))
    }
}
