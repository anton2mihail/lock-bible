package com.john.bible.platform

import android.app.*
import android.content.*
import android.net.Uri
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.john.bible.MainActivity
import com.john.bible.R
import com.john.bible.data.*
import java.time.LocalDate
import kotlin.concurrent.thread

object SaintReminders {
    private fun pending(context:Context,id:String,date:String=""):PendingIntent = PendingIntent.getBroadcast(context,0,
        Intent(context,SaintReminderReceiver::class.java).setData(Uri.parse("john://saint-reminder/$id")).putExtra("saintID",id).putExtra("date",date),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun schedule(context:Context,saint:PersonalSaint,profile:SaintProfile) {
        val alarm=context.getSystemService(AlarmManager::class.java)
        if(!profile.reminderEnabled) { alarm.cancel(pending(context,saint.id));return }
        val next=SaintDates.reminderDate(saint.observance(profile).monthDay,profile.reminderHour,profile.reminderMinute)
        alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,next.toInstant().toEpochMilli(),pending(context,saint.id,next.toLocalDate().toString()))
    }
    fun save(context:Context,store:JohnStore,saint:PersonalSaint,profile:SaintProfile) {
        if(profile.reminderEnabled && !NotificationManagerCompat.from(context).areNotificationsEnabled())
            error("Allow notifications in device settings to receive feast reminders.")
        val previous=store.saintProfile(saint.id)
        try {
            schedule(context,saint,profile)
            check(store.saveSaintProfile(saint.id,profile)) { "The feast settings could not be saved." }
        } catch(error:Exception) { runCatching { schedule(context,saint,previous) };throw error }
    }
    fun scheduleAll(context:Context) {
        JohnRepository(context).use { repo ->
            val store=JohnStore(context)
            repo.personalSaints().forEach { schedule(context,it,store.saintProfile(it.id)) }
        }
    }
    fun replacesCalendar(context:Context,date:LocalDate):Boolean {
        val daily=JohnReminders.read(context,"calendar-notifications")
        if(!daily.enabled)return false
        return JohnRepository(context).use { repo ->
            val store=JohnStore(context)
            repo.personalSaints().any { saint -> val p=store.saintProfile(saint.id)
                p.reminderEnabled && p.reminderHour==daily.hour && p.reminderMinute==daily.minute &&
                    saint.observance(p).monthDay==date.toString().takeLast(5)
            }
        }
    }
}
class SaintReminderReceiver:BroadcastReceiver() {
    override fun onReceive(context:Context,intent:Intent) {
        val id=intent.getStringExtra("saintID") ?: return
        val pending=goAsync()
        thread(name="SaintReminder") {
            try {
                JohnRepository(context).use { repo ->
                    val saint=repo.personalSaints().firstOrNull { it.id==id } ?: return@use
                    val profile=JohnStore(context).saintProfile(id)
                    SaintReminders.schedule(context,saint,profile)
                    if(!profile.reminderEnabled || intent.getStringExtra("date")!=LocalDate.now().toString() ||
                        !NotificationManagerCompat.from(context).areNotificationsEnabled())return@use
                    JohnReminders.channel(context)
                    val open=PendingIntent.getActivity(context,0,Intent(Intent.ACTION_VIEW,Uri.parse("nrsv://saint?id=$id&feast=1"),context,MainActivity::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    val content=NotificationCompat.Builder(context,"john_prayer").setSmallIcon(R.drawable.ic_notification)
                        .setContentTitle("Remember ${saint.name} today").setContentText("${saint.observance(profile).calendarName} commemoration. Open prayers and the saint’s life.")
                        .setContentIntent(open).setAutoCancel(true).build()
                    context.getSystemService(NotificationManager::class.java).notify("saint:$id",200,content)
                }
            } finally { pending.finish() }
        }
    }
}
