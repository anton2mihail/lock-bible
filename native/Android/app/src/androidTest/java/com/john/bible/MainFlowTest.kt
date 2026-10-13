package com.john.bible

import android.content.Intent
import android.net.Uri
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MainFlowTest {
    val compose=createAndroidComposeRule<MainActivity>()
    @get:Rule val rule:org.junit.rules.TestRule=org.junit.rules.RuleChain.outerRule(object:org.junit.rules.ExternalResource() {
        override fun before() {
            androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext.getSharedPreferences("john",0).edit().clear().putString("readerLayout","verses").commit()
        }
        override fun after() {
            androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext.getSharedPreferences("john",0).edit().clear().commit()
        }
    }).around(compose)
    @Test fun fiveTabsOpenAndReturnToToday() {
        compose.onNodeWithText("A little closer to God.").assertIsDisplayed()
        compose.onNodeWithText("Read",useUnmergedTree=true).performClick()
        compose.onNodeWithText("Read the Bible").assertIsDisplayed()
        compose.onNodeWithText("Saved",useUnmergedTree=true).performClick()
        compose.onAllNodesWithText("Saved").assertCountEquals(2)
        compose.onNodeWithText("Pray",useUnmergedTree=true).performClick()
        compose.onNodeWithText("Prayer").assertExists()
        compose.onNodeWithText("Settings",useUnmergedTree=true).performClick()
        compose.onNodeWithText("Reading").assertIsDisplayed()
        compose.onNodeWithText("Today",useUnmergedTree=true).performClick()
        compose.onNodeWithText("A little closer to God.").assertIsDisplayed()
    }
    @Test fun sharedIosDeepLinkSelectsVerseAndStoresBookmark() {
        compose.activityRule.scenario.onActivity { it.receiveExternalUrl("nrsv://read?book=JHN&chapter=1&verse=1&translation=web-ce") }
        compose.waitUntil(20000) { compose.onAllNodesWithTag("reader-verse-1").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("reader-verse-1").performClick()
        compose.onNodeWithText("Bookmark").performClick()
        compose.onNodeWithText("Bookmark saved").assertExists()
    }
    @Test fun writtenAndDrawnNotePersistsAfterSave() {
        compose.activityRule.scenario.onActivity { it.receiveExternalUrl("nrsv://read?book=JHN&chapter=1&verse=1") }
        compose.waitUntil(20000) { compose.onAllNodesWithTag("reader-verse-1").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("reader-verse-1").performClick()
        compose.onNodeWithText("Note").performClick()
        compose.onNodeWithText("Your note").performTextInput("Remember this passage.")
        compose.activityRule.scenario.onActivity { activity -> activity.getSystemService(android.view.inputmethod.InputMethodManager::class.java).hideSoftInputFromWindow(activity.window.decorView.windowToken,0) }
        compose.onNodeWithText("Handwritten note").performScrollTo().performClick()
        compose.onNodeWithTag("note-drawing").performScrollTo().performTouchInput { swipe(androidx.compose.ui.geometry.Offset(20f,20f),androidx.compose.ui.geometry.Offset(180f,100f),500) }
        compose.onNodeWithText("Save").performClick()
        val store=com.john.bible.data.JohnStore(compose.activity)
        val hit=com.john.bible.data.SearchHit("web-ce","JHN","John",1,"1","")
        org.junit.Assert.assertEquals("Remember this passage.",store.noteFor(hit))
        org.junit.Assert.assertTrue(store.noteDrawing(hit).isNotBlank())
    }

    @Test fun searchBackKeepsChapterAndSelection() {
        compose.activityRule.scenario.onActivity { it.receiveExternalUrl("nrsv://read?book=JHN&chapter=1&verse=1") }
        compose.waitUntil(20000) { compose.onAllNodesWithTag("reader-verse-1").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("reader-verse-1").performClick()
        compose.onNodeWithText("Search").performClick()
        compose.onNodeWithText("‹ Back").performClick()
        compose.waitUntil(20000) { compose.onAllNodesWithTag("reader-verse-1").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("John 1").assertExists()
        compose.onNodeWithText("Bookmark").assertExists()
    }

    @Test fun cancellingDictationNoticeKeepsNoteEditorWithoutExternalLaunch() {
        val instrumentation = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation()
        val monitor = instrumentation.addMonitor(android.content.IntentFilter(android.speech.RecognizerIntent.ACTION_RECOGNIZE_SPEECH), null, true)
        try {
            compose.activityRule.scenario.onActivity { it.receiveExternalUrl("nrsv://read?book=JHN&chapter=1&verse=1") }
            compose.waitUntil(20000) { compose.onAllNodesWithTag("reader-verse-1").fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithTag("reader-verse-1").performClick()
            compose.onNodeWithText("Note").performClick()
            compose.onNodeWithText("Dictate").performClick()
            compose.onNodeWithText("Use device dictation?").assertIsDisplayed()
            compose.onNodeWithText("This opens your device’s speech service. Its provider may send your audio to its servers. John receives the recognized text. You can type your note instead.").assertIsDisplayed()
            compose.onNodeWithText("Continue").assertIsDisplayed()
            val notice = isDialog() and hasAnyDescendant(hasText("Use device dictation?"))
            compose.onNode(hasText("Cancel") and hasAnyAncestor(notice), useUnmergedTree = true).performClick()
            compose.onNodeWithText("Use device dictation?").assertDoesNotExist()
            compose.onNodeWithText("Your note").assertIsDisplayed()
            org.junit.Assert.assertEquals(0, monitor.hits)
            org.junit.Assert.assertEquals(androidx.lifecycle.Lifecycle.State.RESUMED, compose.activity.lifecycle.currentState)
        } finally { instrumentation.removeMonitor(monitor) }
    }

}
