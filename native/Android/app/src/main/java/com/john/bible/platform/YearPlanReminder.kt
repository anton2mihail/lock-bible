package com.john.bible.platform

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.john.bible.MainActivity
import com.john.bible.R
import com.john.bible.data.JohnRepository
import com.john.bible.data.JohnStore
import com.john.bible.data.YearPlanSchedule
import java.time.LocalDate

/**
 * The "A Year with the Fathers" reminder (1.3.0). The daily alarm is the "year-reminder" kind of [JohnReminders];
 * this names that day's reading, and stays silent before the person's Day 1, after Day 365, or when today is read.
 */
object YearPlanReminder {
    fun notify(context: Context) {
        val store = JohnStore(context)
        val start = store.yearStartDate?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
        val dayNumber = YearPlanSchedule.reminderDay(start, LocalDate.now(), store.yearDaysRead) ?: return
        val repo = JohnRepository(context)
        try {
            val day = repo.yearPlan()?.day(dayNumber) ?: return
            JohnReminders.channel(context)
            val body = "${day.author}, ${day.title} · ${day.minutes} min"
            val id = JohnReminders.kinds.indexOf("year-reminder")
            val open = PendingIntent.getActivity(context, id,
                Intent(Intent.ACTION_VIEW, android.net.Uri.parse("nrsv://year"), context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val notification = NotificationCompat.Builder(context, "john_prayer").setSmallIcon(R.drawable.ic_notification)
                .setContentTitle("A Year with the Fathers · Day $dayNumber").setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body)).setContentIntent(open).setAutoCancel(true).build()
            context.getSystemService(NotificationManager::class.java).notify(id + 100, notification)
        } finally { repo.close() }
    }
}
