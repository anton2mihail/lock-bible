package com.john.bible.ui

import android.content.Context
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.john.bible.MainActivity
import com.john.bible.data.JohnStore
import com.john.bible.data.SearchHit
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Pages mode: page turns, chapter limits, jumps, selection, and saved positions. */
@RunWith(AndroidJUnit4::class)
class PagedReaderTest {
    @get:Rule val compose = createEmptyComposeRule()
    private val context: Context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private val prefs get() = context.getSharedPreferences("john", 0)
    private var scenario: ActivityScenario<MainActivity>? = null

    @Before fun setup() { prefs.edit().clear().putString("appearance", "light").commit() }
    @After fun cleanup() { scenario?.close(); prefs.edit().clear().commit() }

    private fun launch() { scenario = ActivityScenario.launch(MainActivity::class.java) }
    private fun open(link: String) {
        if (scenario == null) launch()
        scenario!!.onActivity { it.receiveExternalUrl(link) }
    }
    /** True when a node with this tag is on screen. Pages next to the current page are composed off screen. */
    private fun displayed(tag: String): Boolean {
        val width = compose.onAllNodes(isRoot()).fetchSemanticsNodes().maxOf { it.boundsInRoot.width }
        return compose.onAllNodesWithTag(tag).fetchSemanticsNodes().any { it.boundsInRoot.left >= -1f && it.boundsInRoot.right <= width + 1f && it.boundsInRoot.width > 0f }
    }
    private fun displayedWithPrefix(prefix: String): List<String> {
        val width = compose.onAllNodes(isRoot()).fetchSemanticsNodes().maxOf { it.boundsInRoot.width }
        return compose.onAllNodes(SemanticsMatcher("tag starts with $prefix") { node ->
            node.config.getOrElseNullable(androidx.compose.ui.semantics.SemanticsProperties.TestTag) { null }?.startsWith(prefix) == true
        }).fetchSemanticsNodes().filter { it.boundsInRoot.left >= -1f && it.boundsInRoot.right <= width + 1f }
            .sortedBy { it.boundsInRoot.top }
            .map { it.config[androidx.compose.ui.semantics.SemanticsProperties.TestTag] }
    }
    private fun waitFor(tag: String) = compose.waitUntil(30000) { displayed(tag) }
    private fun pager() = compose.onNodeWithTag("reader-pager")
    private fun tapRight() = pager().performTouchInput { click(Offset(width * .9f, height * .5f)) }
    private fun tapLeft() = pager().performTouchInput { click(Offset(width * .1f, height * .5f)) }

    @Test fun tapsAndSwipesTurnPages() {
        open("nrsv://read?book=JHN&chapter=1")
        waitFor("reader-page-JHN-1-0")
        tapRight(); waitFor("reader-page-JHN-1-1")
        pager().performTouchInput { swipeLeft() }; waitFor("reader-page-JHN-1-2")
        tapLeft(); waitFor("reader-page-JHN-1-1")
        pager().performTouchInput { swipeRight() }; waitFor("reader-page-JHN-1-0")
        // A page turn hides the bars. The middle third shows and hides them. It does not turn the page.
        compose.waitUntil(5000) { compose.onAllNodesWithContentDescription("Reading choices").fetchSemanticsNodes().isEmpty() }
        pager().performTouchInput { click(center) }
        compose.onNodeWithContentDescription("Reading choices").assertExists()
        pager().performTouchInput { click(center) }
        compose.waitUntil(5000) { compose.onAllNodesWithContentDescription("Reading choices").fetchSemanticsNodes().isEmpty() }
        assertTrue(displayed("reader-page-JHN-1-0"))
    }

    @Test fun swipesCrossChapterAndBookLimits() {
        open("nrsv://read?book=JUD&chapter=1")
        waitFor("reader-page-JUD-1-0")
        repeat(30) { if (!displayed("reader-page-REV-1-0")) { pager().performTouchInput { swipeLeft() }; compose.waitForIdle() } }
        waitFor("reader-page-REV-1-0")
        assertTrue(JohnStore(context).isChapterRead("web-ce", "JUD", 1))
        pager().performTouchInput { swipeRight() }
        compose.waitUntil(30000) { displayedWithPrefix("reader-page-JUD-1-").isNotEmpty() }
        // The back turn lands on the last page of the earlier chapter, which holds its last verse.
        assertTrue(displayed("page-verse-1:25"))
    }

    @Test fun linkLandsOnThePageThatHoldsTheVerse() {
        val started = System.nanoTime()
        open("nrsv://read?book=PSA&chapter=119&verse=150")
        waitFor("page-verse-119:150")
        val seconds = (System.nanoTime() - started) / 1e9
        assertFalse(displayed("reader-page-PSA-119-0"))
        assertTrue("Psalm 119 opened in $seconds s", seconds < 15)
    }

    @Test fun holdSelectsVerseAndHighlightIsSaved() {
        open("nrsv://read?book=JHN&chapter=1")
        waitFor("page-verse-1:1")
        compose.onAllNodesWithTag("page-verse-1:1")[0].performTouchInput { longClick() }
        compose.onNodeWithText("John 1:1").assertExists()
        // TalkBack uses the verse click action to extend the selection.
        compose.onAllNodesWithTag("page-verse-1:3")[0].performSemanticsAction(SemanticsActions.OnClick)
        compose.onNodeWithText("John 1:1–3").assertExists()
        compose.onNodeWithText("Yellow").performClick()
        compose.onNodeWithText("Highlight saved").assertExists()
        assertEquals("yellow", JohnStore(context).highlightColor(SearchHit("web-ce", "JHN", "John", 1, "2", "")))
        compose.onNodeWithText("Bookmark").performClick()
        compose.onNodeWithText("Bookmark saved").assertExists()
        compose.onNodeWithText("Done").performClick()
        compose.waitUntil(5000) { compose.onAllNodesWithText("Bookmark").fetchSemanticsNodes().isEmpty() }
        val description = compose.onAllNodesWithTag("page-verse-1:2")[0].fetchSemanticsNode().config[androidx.compose.ui.semantics.SemanticsProperties.ContentDescription].single()
        assertTrue(description, description.startsWith("Verse 2. The same was in the beginning"))
        assertTrue(description, description.contains("Bookmarked"))
    }

    @Test fun savedPositionReturnsAfterRestart() {
        prefs.edit().putString("readerBook", "JHN").putInt("readerChapter", 3).putString("readerVerse", "16").putInt("readerVerseOffset", 0).commit()
        launch()
        compose.onNodeWithText("Read", useUnmergedTree = true).performClick()
        compose.onNodeWithText("John 3").performClick()
        waitFor("page-verse-3:16")
        compose.waitForIdle()
        // The first page saves the verse and offset where it starts. A page turn saves a later position.
        fun position() = "${prefs.getString("readerVerse", "")}:${prefs.getInt("readerVerseOffset", 0)}"
        val before = position()
        tapRight()
        compose.waitUntil(30000) { position() != before }
        val verse = prefs.getString("readerVerse", "")!!
        assertTrue(displayed("page-verse-3:$verse"))
        // A rotation or other configuration change keeps the page.
        scenario!!.recreate()
        waitFor("page-verse-3:$verse")
        // A new process reads the saved verse.
        scenario!!.close()
        launch()
        compose.onNodeWithText("Read", useUnmergedTree = true).performClick()
        compose.onNodeWithText("John 3").performClick()
        waitFor("page-verse-3:$verse")
    }

    @Test fun largerTextKeepsTheVerseOnScreen() {
        prefs.edit().putString("readerBook", "JHN").putInt("readerChapter", 1).commit()
        launch()
        compose.onNodeWithText("Read", useUnmergedTree = true).performClick()
        compose.onNodeWithText("John 1").performClick()
        waitFor("reader-page-JHN-1-0")
        tapRight(); waitFor("reader-page-JHN-1-1")
        tapRight(); waitFor("reader-page-JHN-1-2")
        compose.waitUntil(30000) { prefs.getString("readerVerse", "").orEmpty().isNotEmpty() && prefs.getString("readerVerse", "") != "1" }
        val verse = prefs.getString("readerVerse", "")!!
        pager().performTouchInput { click(center) }
        compose.onNodeWithContentDescription("Reading choices").performClick()
        compose.onNodeWithText("Extra large").performClick()
        compose.onNodeWithText("Done").performClick()
        waitFor("page-verse-1:$verse")
        assertEquals(24f, JohnStore(context).textSize)
    }

    @Test fun readingModeChoicePersists() {
        open("nrsv://read?book=JHN&chapter=1")
        waitFor("reader-page-JHN-1-0")
        compose.onNodeWithContentDescription("Reading choices").performClick()
        compose.onNodeWithText("Scroll").performClick()
        compose.onNodeWithText("Done").performClick()
        compose.waitUntil(20000) { compose.onAllNodesWithTag("reader-verse-1").fetchSemanticsNodes().isNotEmpty() || compose.onAllNodesWithTag("reader-paragraph-1").fetchSemanticsNodes().isNotEmpty() }
        assertEquals("scroll", prefs.getString("readerMode", ""))
        compose.onNodeWithText("Aa").performClick()
        compose.onNodeWithText("Pages").performClick()
        compose.onNodeWithText("Done").performClick()
        waitFor("reader-page-JHN-1-0")
        assertEquals("pages", JohnStore(context).readerMode)
    }
}
