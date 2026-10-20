package com.john.bible.platform

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.*
import android.net.Uri
import android.widget.RemoteViews
import com.john.bible.MainActivity
import com.john.bible.R
import com.john.bible.data.*
import java.time.LocalDate
import kotlin.concurrent.thread

open class JohnVerseWidget:AppWidgetProvider() {
    open val kind="verse"
    override fun onUpdate(context:Context,manager:AppWidgetManager,ids:IntArray) { val pending=goAsync(); update(context,manager,ids,kind) { JohnWidgetSchedule.refresh(context);pending.finish() } }
    override fun onDeleted(context:Context,ids:IntArray) { JohnWidgetSchedule.refresh(context) }
    companion object {
        fun refreshAll(context:Context,complete:()->Unit={}) {
            val manager=AppWidgetManager.getInstance(context)
            val tasks=listOf(JohnVerseWidget::class.java to "verse",JohnDailyWidget::class.java to "daily",JohnProgressWidget::class.java to "progress").map { (type,kind) -> manager.getAppWidgetIds(ComponentName(context,type)) to kind }.filter { it.first.isNotEmpty() }
            JohnWidgetSchedule.refresh(context)
            val remaining=java.util.concurrent.atomic.AtomicInteger(tasks.size + 1)
            MySaintWidget.refreshAll(context) { if(remaining.decrementAndGet()==0)complete() }
            tasks.forEach { (ids,kind) -> update(context,manager,ids,kind) { if(remaining.decrementAndGet()==0)complete() } }
        }
        private fun update(context:Context,manager:AppWidgetManager,ids:IntArray,kind:String,complete:()->Unit={}) {
            thread(name="JohnWidget") {
                try {
                runCatching {
                    JohnRepository(context).use { repo ->
                    val store=JohnStore(context)
                    val date=LocalDate.now().toString()
                    val verse=repo.rotatingVerse(store.edition,store.scope,store.intervalMinutes)
                    val chapter=store.todayJohnChapters().firstOrNull() ?: 1
                    val views=RemoteViews(context.packageName,R.layout.verse_widget)
                    val title=when(kind){"daily"->"DAILY READING"; "progress"->"READING PROGRESS";else->"DAILY VERSE"}
                    val body=when(kind){"daily"->readingsSummary(repo.readings(date),repo);"progress"->"${store.completedChapters.count { it.startsWith("JHN/") }} of 21 chapters read\nContinue reading the Gospel of John.";else->verse.text}
                    val reference=if(kind=="verse")"${verse.bookName} ${verse.chapter}:${verse.label}" else date
                    val url=when(kind){"daily"->"nrsv://daily?date=$date";"progress"->"john://read?book=JHN&chapter=$chapter&translation=${store.edition}";else->"nrsv://read?book=${verse.book}&chapter=${verse.chapter}&verse=${verse.label}&translation=${verse.edition}"}
                    views.setTextViewText(R.id.widget_title,title)
                    views.setTextViewText(R.id.widget_body,body)
                    views.setTextViewText(R.id.widget_reference,reference)
                    views.setOnClickPendingIntent(R.id.widget_body,PendingIntent.getActivity(context,kind.hashCode(),Intent(Intent.ACTION_VIEW,Uri.parse(url),context,MainActivity::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                    ids.forEach { manager.updateAppWidget(it,views) }
                    }
                }
                } finally { complete() }
            }
        }
        private fun readingsSummary(value:org.json.JSONObject?,repo:JohnRepository):String {
            if(value==null)return "Open today’s readings."
            val readings=value.optJSONArray("readings")
            val gospel=readings?.let { (0 until it.length()).mapNotNull(it::optJSONObject).firstOrNull { row -> row.optString("label")=="Gospel" } }
            val reference=gospel?.optString("reference").orEmpty()
            val passage=runCatching { repo.resolveReference(reference) }.getOrNull()
            return passage?.let { "${it.text}\n$reference" } ?: reference.ifBlank { value.optString("title","Open today’s readings.") }
        }
    }
}
class JohnDailyWidget:JohnVerseWidget() { override val kind="daily" }
class JohnProgressWidget:JohnVerseWidget() { override val kind="progress" }

class JohnWidgetRefreshReceiver:BroadcastReceiver() {
    override fun onReceive(context:Context,intent:Intent) {
        if(intent.action!="com.john.bible.REFRESH_WIDGETS")return
        val pending=goAsync()
        JohnVerseWidget.refreshAll(context) { pending.finish() }
    }
}
object JohnWidgetSchedule {
    fun refresh(context:Context) {
        val manager=AppWidgetManager.getInstance(context)
        val count=listOf(JohnVerseWidget::class.java,JohnDailyWidget::class.java,JohnProgressWidget::class.java,MySaintWidget::class.java).sumOf { manager.getAppWidgetIds(ComponentName(context,it)).size }
        val alarm=context.getSystemService(android.app.AlarmManager::class.java)
        val pending=android.app.PendingIntent.getBroadcast(context,400,Intent(context,JohnWidgetRefreshReceiver::class.java).setAction("com.john.bible.REFRESH_WIDGETS"),android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        alarm.cancel(pending)
        if(count==0)return
        val minutes=JohnStore(context).intervalMinutes
        val now=System.currentTimeMillis()
        val offset=java.time.ZoneId.systemDefault().rules.getOffset(java.time.Instant.ofEpochMilli(now)).totalSeconds*1000L
        val next=(Math.floorDiv(now+offset,minutes*60000L)+1)*minutes*60000L-offset
        alarm.setAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP,next,pending)
    }
}
