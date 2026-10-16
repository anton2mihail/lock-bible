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
 * Before the run, clear the app data (pm clear com.john.bible) and turn on System UI demo mode
 * (9:41, full battery, Wi-Fi only). Turn demo mode off after the run.
 * The images are 01-reader-pages (Pages mode, John 1 page 1), 02-today, 03-read, 04-prayer, 05-saved, 06-settings.
 */
@RunWith(AndroidJUnit4::class)
class StoreCaptureTest {
    private val compose = createAndroidComposeRule<MainActivity>()
    private val instrumentation get() = InstrumentationRegistry.getInstrumentation()
    @get:Rule val rule: org.junit.rules.TestRule = org.junit.rules.RuleChain.outerRule(object : org.junit.rules.ExternalResource() {
        override fun before() {
            instrumentation.targetContext.getSharedPreferences("john", 0).edit().clear()
                .putString("appearance", "light").putString("readerMode", "pages").commit()
        }
        override fun after() {
            instrumentation.targetContext.getSharedPreferences("john", 0).edit().clear().commit()
        }
    }).around(compose)

    private fun capture(name: String) {
        compose.waitForIdle()
        instrumentation.waitForIdleSync()
        dismissLauncherAnr()
        val automation = instrumentation.uiAutomation
        compose.waitUntil(10000) { automation.rootInActiveWindow?.packageName?.toString() == "com.john.bible" }
        check(automation.rootInActiveWindow?.packageName?.toString() == "com.john.bible") {
            "The active window is not John. Do not export this frame."
        }
        automation.waitForIdle(250, 3000)
        val image = requireNotNull(instrumentation.uiAutomation.takeScreenshot())
        try {
            check(image.width == 1080 && image.height == 1920) { "Use a 1080x1920 viewport for Play captures." }
            val output = File(instrumentation.targetContext.getExternalFilesDir(null), "store-captures")
            check(output.isDirectory || output.mkdirs())
            File(output, "$name.png").outputStream().use { check(image.compress(Bitmap.CompressFormat.PNG, 100, it)) }
        } finally { image.recycle() }
    }

    private fun dismissLauncherAnr() {
        val automation = instrumentation.uiAutomation
        automation.serviceInfo = automation.serviceInfo.apply {
            flags = flags or android.accessibilityservice.AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        }
        fun roots() = automation.windows.mapNotNull { it.root } + listOfNotNull(automation.rootInActiveWindow)
        fun launcherDialog() = roots().firstOrNull { root ->
            root.findAccessibilityNodeInfosByText("Pixel Launcher").any { it.text?.toString()?.contains("responding") == true }
        }
        launcherDialog()?.let { dialog ->
            var wait = dialog.findAccessibilityNodeInfosByText("Wait").firstOrNull { it.text?.toString() == "Wait" }
            while (wait != null && !wait.isClickable) wait = wait.parent
            check(wait?.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_CLICK) == true) {
                "Cannot dismiss the launcher ANR with its non-destructive Wait action."
            }
            val deadline = android.os.SystemClock.uptimeMillis() + 10000
            while (launcherDialog() != null && android.os.SystemClock.uptimeMillis() < deadline) android.os.SystemClock.sleep(100)
            check(launcherDialog() == null) { "The launcher ANR dialog remains visible after Wait." }
        }
        check(roots().none { root -> root.findAccessibilityNodeInfosByText("isn't responding").isNotEmpty() }) {
            "A system ANR dialog is visible. Do not export this frame."
        }
        instrumentation.waitForIdleSync()
    }

    private fun tab(title: String) = compose.onNodeWithText(title, useUnmergedTree = true).performClick()
    private fun back() = compose.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }

    /** True when a node with this tag is inside the screen. The pager composes the next page off screen. */
    private fun displayed(tag: String): Boolean {
        val width = compose.onAllNodes(isRoot()).fetchSemanticsNodes().maxOf { it.boundsInRoot.width }
        return compose.onAllNodesWithTag(tag).fetchSemanticsNodes()
            .any { it.boundsInRoot.left >= -1f && it.boundsInRoot.right <= width + 1f && it.boundsInRoot.width > 0f }
    }
    private fun readingChoicesShown() = compose.onAllNodesWithContentDescription("Reading choices").fetchSemanticsNodes().isNotEmpty()

    @Test fun captureRealStoreScreens() {
        org.junit.Assume.assumeTrue(InstrumentationRegistry.getArguments().getString("storeCaptures") == "true")
        compose.onNodeWithText("A little closer to God.").assertIsDisplayed()
        capture("02-today")
        tab("Read")
        compose.waitUntil(20000) { compose.onAllNodesWithText("Genesis").fetchSemanticsNodes().isNotEmpty() }
        capture("03-read")
        compose.onNodeWithText("The Fathers and Doctors").performClick()
        compose.onNodeWithText("The Fathers & Doctors").assertIsDisplayed()
        back()
        // The paged Reader (Pages mode, the default) on the first page of John 1, as in Google Play Books.
        compose.activityRule.scenario.onActivity { it.receiveExternalUrl("nrsv://read?book=JHN&chapter=1&translation=web-ce") }
        compose.waitUntil(30000) { displayed("reader-page-JHN-1-0") && displayed("page-verse-1:1") }
        check(compose.onAllNodesWithTag("reader-verse-1").fetchSemanticsNodes().isEmpty()) { "The Reader must be in Pages mode, not Scroll" }
        // A tap in the middle third hides the top and bottom bars, so the image shows only the page.
        if (readingChoicesShown()) compose.onNodeWithTag("reader-pager").performTouchInput { click(center) }
        compose.waitUntil(5000) { !readingChoicesShown() }
        check(displayed("reader-page-JHN-1-0")) { "The middle tap must not turn the page" }
        capture("01-reader-pages")
        // Only public Scripture is saved. No personal notes or intentions are made.
        compose.onAllNodesWithTag("page-verse-1:1")[0].performTouchInput { longClick() }
        compose.onNodeWithText("Bookmark").performClick()
        compose.onNodeWithText("Bookmark saved").assertExists()
        compose.onNodeWithText("Done").performClick()
        // Pages mode hides the tab bar. Back returns to the Bible library, where the tabs show again.
        fun tabsShown() = compose.onAllNodesWithText("Saved", useUnmergedTree = true).fetchSemanticsNodes().isNotEmpty()
        repeat(3) {
            if (!tabsShown()) { back(); compose.waitForIdle(); runCatching { compose.waitUntil(4000) { tabsShown() } } }
        }
        check(tabsShown()) { "The tab bar must show after Back from the Reader" }
        tab("Saved")
        compose.onNodeWithText("John 1:1").assertIsDisplayed()
        capture("05-saved")
        tab("Pray")
        compose.onNodeWithText("Prayer").assertIsDisplayed()
        capture("04-prayer")
        tab("Settings")
        compose.onNodeWithText("Reading").assertIsDisplayed()
        capture("06-settings")
    }
}
