package com.john.bible

import android.graphics.Bitmap
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Real app captures for Play. Run this class alone with -e storeCaptures true.
 * Set the viewport to 1080x1920 before the run. Restore it after the run.
 * Capture files are under the target app's external files/store-captures folder.
 */
@RunWith(AndroidJUnit4::class)
class StoreCaptureTest {
    private val compose = createAndroidComposeRule<MainActivity>()
    private val instrumentation get() = InstrumentationRegistry.getInstrumentation()
    @get:Rule val rule: org.junit.rules.TestRule = org.junit.rules.RuleChain.outerRule(object : org.junit.rules.ExternalResource() {
        override fun before() {
            instrumentation.targetContext.getSharedPreferences("john", 0).edit().clear()
                .putString("appearance", "light").putString("readerLayout", "verses").commit()
        }
        override fun after() {
            instrumentation.targetContext.getSharedPreferences("john", 0).edit().clear().commit()
        }
    }).around(compose)

    private fun capture(name: String) {
        compose.waitForIdle()
        instrumentation.waitForIdleSync()
        val image = requireNotNull(instrumentation.uiAutomation.takeScreenshot())
        try {
            check(image.width == 1080 && image.height == 1920) { "Use a 1080x1920 viewport for Play captures." }
            val output = File(instrumentation.targetContext.getExternalFilesDir(null), "store-captures")
            check(output.isDirectory || output.mkdirs())
            File(output, "$name.png").outputStream().use { check(image.compress(Bitmap.CompressFormat.PNG, 100, it)) }
        } finally { image.recycle() }
    }

    private fun tab(title: String) = compose.onNodeWithText(title, useUnmergedTree = true).performClick()
    private fun back() = compose.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }

    @Test fun captureRealStoreScreens() {
        org.junit.Assume.assumeTrue(InstrumentationRegistry.getArguments().getString("storeCaptures") == "true")
        compose.onNodeWithText("A little closer to God.").assertIsDisplayed()
        capture("01-today")
        tab("Read")
        compose.waitUntil(20000) { compose.onAllNodesWithText("Genesis").fetchSemanticsNodes().isNotEmpty() }
        capture("02-read")
        compose.onNodeWithText("The Fathers and Doctors").performClick()
        compose.onNodeWithText("The Fathers & Doctors").assertIsDisplayed()
        capture("05-works")
        back()
        compose.activityRule.scenario.onActivity { it.receiveExternalUrl("nrsv://read?book=JHN&chapter=1&translation=web-ce") }
        compose.waitUntil(20000) { compose.onAllNodesWithTag("reader-verse-1").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("John 1").assertIsDisplayed()
        capture("03-scripture")
        // Only public Scripture is saved. No personal notes or intentions are made.
        compose.onNodeWithTag("reader-verse-1").performClick()
        compose.onNodeWithText("Bookmark").performClick()
        compose.onNodeWithText("Bookmark saved").assertExists()
        tab("Saved")
        compose.onNodeWithText("John 1:1").assertIsDisplayed()
        capture("06-saved")
        tab("Pray")
        compose.onNodeWithText("Prayer").assertIsDisplayed()
        capture("04-prayer")
        tab("Settings")
        compose.onNodeWithText("Reading").assertIsDisplayed()
        capture("07-settings")
    }
}
