package com.john.bible.platform

import android.app.Activity
import android.content.Context
import com.google.android.play.core.review.ReviewManagerFactory
import com.john.bible.BuildConfig
import com.john.bible.data.ReviewPromptPolicy
import java.time.ZoneId

/** Counts what the rating rule needs, on this device only, and shows Google Play's in-app review sheet. */
object ReviewPrompt {
    private const val PRAYERS = "reviewPrayersCompleted"
    private const val OPEN_DAYS = "reviewOpenDays"
    private const val LAST_OPEN_DAY = "reviewLastOpenDay"
    private const val LAST_ASKED = "reviewLastAskedAt"

    private fun prefs(context: Context) = context.applicationContext.getSharedPreferences("john", Context.MODE_PRIVATE)

    /** Call when the app starts or returns to the front. Counts each local calendar day once. */
    fun recordOpen(context: Context, now: Long = System.currentTimeMillis()) {
        val p = prefs(context)
        val key = ReviewPromptPolicy.dayKey(now, ZoneId.systemDefault())
        if (p.getString(LAST_OPEN_DAY, null) == key) return
        p.edit().putString(LAST_OPEN_DAY, key).putInt(OPEN_DAYS, p.getInt(OPEN_DAYS, 0) + 1).apply()
    }

    /** Call right after a person finishes a Rosary or marks a novena day complete. Debug builds never ask. */
    fun prayerCompleted(activity: Activity, now: Long = System.currentTimeMillis()) {
        if (BuildConfig.DEBUG) return
        val p = prefs(activity)
        val prayers = p.getInt(PRAYERS, 0) + 1
        p.edit().putInt(PRAYERS, prayers).apply()
        val last = if (p.contains(LAST_ASKED)) p.getLong(LAST_ASKED, 0) else null
        if (!ReviewPromptPolicy.shouldAsk(prayers, p.getInt(OPEN_DAYS, 0), last, now)) return
        p.edit().putLong(LAST_ASKED, now).apply()
        val manager = ReviewManagerFactory.create(activity)
        manager.requestReviewFlow().addOnCompleteListener { request ->
            if (request.isSuccessful) manager.launchReviewFlow(activity, request.result)
        }
    }
}
