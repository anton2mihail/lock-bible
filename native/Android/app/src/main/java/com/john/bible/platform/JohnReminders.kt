package com.john.bible.platform

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.john.bible.MainActivity
import com.john.bible.R
import com.john.bible.data.JohnRepository
import java.time.*
import kotlin.concurrent.thread

data class ReminderSettings(val enabled:Boolean=false,val hour:Int=8,val minute:Int=0,val weekly:Boolean=false,val weekday:Int=1)
object JohnReminders {
    val kinds=listOf("calendar-notifications","rosary-reminder","reading-reminder")
    private fun prefs(context:Context)=context.getSharedPreferences("john_reminders",Context.MODE_PRIVATE)
    fun read(context:Context,kind:String):ReminderSettings {
        val p=prefs(context)
        return ReminderSettings(p.getBoolean("$kind.enabled",false),p.getInt("$kind.hour",8),p.getInt("$kind.minute",0),p.getBoolean("$kind.weekly",false),p.getInt("$kind.weekday",1))
    }
    fun save(context:Context,kind:String,s:ReminderSettings):Boolean {
        val saved=prefs(context).edit().putBoolean("$kind.enabled",s.enabled).putInt("$kind.hour",s.hour.coerceIn(0,23)).putInt("$kind.minute",s.minute.coerceIn(0,59)).putBoolean("$kind.weekly",s.weekly).putInt("$kind.weekday",s.weekday.coerceIn(1,7)).commit()
        if(saved) schedule(context,kind)
        return saved
    }
    fun scheduleAll(context:Context) { kinds.forEach { schedule(context,it) }; SaintReminders.scheduleAll(context) }
    fun schedule(context:Context,kind:String) {
        val s=read(context,kind)
        val alarm=context.getSystemService(AlarmManager::class.java)
        val intent=Intent(context,JohnReminderReceiver::class.java).putExtra("kind",kind)
        val pending=PendingIntent.getBroadcast(context,kinds.indexOf(kind),intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        alarm.cancel(pending)
        if(!s.enabled) return
        val now=ZonedDateTime.now()
        var next=now.withHour(s.hour).withMinute(s.minute).withSecond(0).withNano(0)
        if(next<=now) next=next.plusDays(1)
        if(s.weekly) while(next.dayOfWeek.value!=s.weekday) next=next.plusDays(1)
        // Inexact local alarms do not require restricted exact-alarm access.
        alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,next.toInstant().toEpochMilli(),pending)
    }
    fun channel(context:Context) {
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel("john_prayer","Scripture & prayer",NotificationManager.IMPORTANCE_DEFAULT))
    }
}
class JohnReminderReceiver:BroadcastReceiver() {
    override fun onReceive(context:Context,intent:Intent) {
        val kind=intent.getStringExtra("kind") ?: return
        if(!JohnReminders.read(context,kind).enabled) return
        val pending=goAsync()
        thread(name="JohnReminder") {
            try {
                JohnReminders.schedule(context,kind)
                if(Build.VERSION.SDK_INT>=33 && ContextCompat.checkSelfPermission(context,Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED) return@thread
                if(kind=="calendar-notifications" && SaintReminders.replacesCalendar(context,LocalDate.now())) return@thread
                JohnReminders.channel(context)
                val date=LocalDate.now().toString()
                val repo=JohnRepository(context)
                val store=com.john.bible.data.JohnStore(context)
                val chapter=store.todayJohnChapters().firstOrNull() ?: 1
                val title=when(kind) { "calendar-notifications" -> repo.celebrations(date)?.optString("title")?.takeIf { it.isNotBlank() } ?: "Today’s saints"; "rosary-reminder" -> "Make room for prayer"; else -> "Your reading for today" }
                val body=when(kind) {
                    "calendar-notifications" -> {
                        val readings = repo.readings(date)?.optJSONArray("readings")
                        val gospel = readings?.let { array ->
                            (0 until array.length()).map { array.getJSONObject(it) }
                                .firstOrNull { it.optString("label") == "Gospel" }?.optString("reference")
                        }
                        com.john.bible.data.saintsNoticeBody(repo.saintsCalendars(), LocalDate.parse(date), gospel)
                    }
                    "rosary-reminder" -> "Take a little time to pray the Rosary."
                    else -> repo.chapter(store.edition,"JHN",chapter).firstOrNull()?.let { "John $chapter:1 — ${it.text}" } ?: "Continue reading the Gospel of John."
                }
                val link=when(kind) { "calendar-notifications" -> "nrsv://daily?date=$date"; "rosary-reminder" -> "nrsv://pray/rosary"; else -> "nrsv://read?book=JHN&chapter=$chapter&translation=${store.edition}" }
                val open=PendingIntent.getActivity(context,JohnReminders.kinds.indexOf(kind),Intent(Intent.ACTION_VIEW,android.net.Uri.parse(link),context,MainActivity::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                val notification=NotificationCompat.Builder(context,"john_prayer").setSmallIcon(R.drawable.ic_notification).setContentTitle(title).setContentText(body).setStyle(NotificationCompat.BigTextStyle().bigText(body)).setContentIntent(open).setAutoCancel(true).build()
                context.getSystemService(NotificationManager::class.java).notify(JohnReminders.kinds.indexOf(kind)+100,notification)
                repo.close()
            } finally { pending.finish() }
        }
    }
}
class JohnBootReceiver:BroadcastReceiver() {
    override fun onReceive(context:Context,intent:Intent) {
        if(intent.action !in setOf(Intent.ACTION_BOOT_COMPLETED,Intent.ACTION_TIMEZONE_CHANGED,Intent.ACTION_TIME_CHANGED)) return
        val pending=goAsync()
        JohnReminders.scheduleAll(context)
        JohnVerseWidget.refreshAll(context) { pending.finish() }
    }
}
