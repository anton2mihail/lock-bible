package com.john.bible.ui

import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Bundle
import android.widget.ImageView
import android.widget.TextView
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.john.bible.MainActivity
import com.john.bible.R
import com.john.bible.data.JohnStore
import com.john.bible.platform.MySaintWidget
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Exercise RemoteViews in a real host, including resize and the tap PendingIntent. */
@RunWith(AndroidJUnit4::class)
class MySaintWidgetTest {
    @get:Rule val compose = createComposeRule()

    @Test fun portraitPrayerAndTapWorkInTheNativeWidgetHost() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val manager = AppWidgetManager.getInstance(context)
        val host = AppWidgetHost(context, 61319)
        val id = host.allocateAppWidgetId()
        val store = JohnStore(context)
        val oldSaint = store.widgetSaintID
        val oldQuiet = store.widgetSaintQuiet
        val oldProfile = store.saintProfile("st-joseph")
        lateinit var view: AppWidgetHostView
        instrumentation.uiAutomation.adoptShellPermissionIdentity("android.permission.BIND_APPWIDGET")
        try {
            val provider = ComponentName(context, MySaintWidget::class.java)
            assertTrue(manager.bindAppWidgetIdIfAllowed(id, provider))
            assertTrue(store.saveSaintProfile("st-joseph", oldProfile.copy(reason = "Private widget test note")))
            assertTrue(store.saveSaintWidget("st-joseph", false))
            compose.setContent {
                AndroidView(factory = { host.createView(it, id, manager.getAppWidgetInfo(id)).also { created -> view = created } },
                    modifier = Modifier.size(360.dp, 200.dp))
            }
            compose.runOnIdle { host.startListening() }
            fun refresh(width: Int) {
                manager.updateAppWidgetOptions(id, Bundle().apply {
                    putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, width)
                    putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, width)
                    putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
                    putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 200)
                })
                val done = CountDownLatch(1)
                MySaintWidget.refresh(context, intArrayOf(id)) { done.countDown() }
                assertTrue(done.await(10, TimeUnit.SECONDS))
                compose.waitUntil(10_000) { view.findViewById<TextView>(R.id.saint_widget_name)?.text == "St. Joseph" }
            }
            refresh(160)
            compose.runOnIdle { assertNotNull(view.findViewById<ImageView>(R.id.saint_widget_art).drawable) }
            refresh(360)
            compose.waitUntil(10_000) { view.findViewById<TextView>(R.id.saint_widget_prayer)?.text?.contains("pray for us") == true }
            compose.runOnIdle {
                assertEquals("Novena to St. Joseph · Lasance, 1906", view.findViewById<TextView>(R.id.saint_widget_caption).text)
                assertFalse(view.findViewById<TextView>(R.id.saint_widget_prayer).text.contains("Private widget test note"))
            }
            val monitor = instrumentation.addMonitor(MainActivity::class.java.name, null, false)
            try {
                compose.runOnIdle { view.findViewById<android.view.View>(R.id.saint_widget_root).performClick() }
                val activity = instrumentation.waitForMonitorWithTimeout(monitor, 10_000)
                assertNotNull("The widget must open the app", activity)
                assertEquals("st-joseph", activity!!.intent.data?.getQueryParameter("id"))
                instrumentation.runOnMainSync { activity.finish() }
            } finally {
                instrumentation.removeMonitor(monitor)
            }
        } finally {
            host.stopListening()
            host.deleteHost()
            store.saveSaintProfile("st-joseph", oldProfile)
            store.saveSaintWidget(oldSaint, oldQuiet)
            instrumentation.uiAutomation.dropShellPermissionIdentity()
        }
    }
}
