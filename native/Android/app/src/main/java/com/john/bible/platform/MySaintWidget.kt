package com.john.bible.platform

import android.app.Activity
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.*
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.john.bible.MainActivity
import com.john.bible.R
import com.john.bible.data.*
import com.john.bible.ui.*
import java.time.LocalDate
import kotlin.concurrent.thread

class MySaintWidget:AppWidgetProvider() {
    override fun onUpdate(context:Context,manager:AppWidgetManager,ids:IntArray) {val pending=goAsync();refresh(context,ids) {pending.finish()}}
    override fun onAppWidgetOptionsChanged(context:Context,manager:AppWidgetManager,id:Int,options:Bundle) {val pending=goAsync();refresh(context,intArrayOf(id)) {pending.finish()}}
    override fun onDeleted(context:Context,ids:IntArray) {
        val edit=context.getSharedPreferences("john_saint_widgets",Context.MODE_PRIVATE).edit()
        ids.forEach {edit.remove("$it.saint").remove("$it.quiet")};edit.apply();JohnWidgetSchedule.refresh(context)
    }
    companion object {
        fun refreshAll(context:Context,complete:()->Unit={}) {
            refresh(context,AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context,MySaintWidget::class.java)),complete)
        }
        fun refresh(context:Context,ids:IntArray,complete:()->Unit={}) {
            if(ids.isEmpty()){complete();return}
            thread(name="MySaintWidget") {
                try {
                    JohnRepository(context).use {repo->
                        val saints=repo.personalSaints();val store=JohnStore(context)
                        val prefs=context.getSharedPreferences("john_saint_widgets",Context.MODE_PRIVATE)
                        val manager=AppWidgetManager.getInstance(context)
                        ids.forEach {id->
                            val selected=prefs.getString("$id.saint",null)?.ifEmpty {null} ?: store.widgetSaintID
                            val quiet=if(prefs.contains("$id.saint"))prefs.getBoolean("$id.quiet",false) else store.widgetSaintQuiet
                            val saint=saints.firstOrNull {it.id==selected}
                            val profile=saint?.let {store.saintProfile(it.id)} ?: SaintProfile()
                            val wide=manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,160)>=250
                            val views=RemoteViews(context.packageName,if(wide)R.layout.saint_widget_medium else R.layout.saint_widget_small)
                            val bitmap=saint?.artwork?.let {name->runCatching { context.assets.open("artwork/$name.jpg").use {BitmapFactory.decodeStream(it,null,BitmapFactory.Options().apply {inSampleSize=3})} }.getOrNull()}
                            views.setImageViewBitmap(R.id.saint_widget_art,bitmap)
                            views.setViewVisibility(R.id.saint_widget_art,if(bitmap!=null)View.VISIBLE else View.GONE)
                            views.setTextViewText(R.id.saint_widget_name,saint?.name ?: "Choose a saint")
                            val today=saint?.observance(profile)?.monthDay==LocalDate.now().toString().takeLast(5)
                            views.setTextViewText(R.id.saint_widget_caption,when {
                                saint==null->"Open John 1:1"
                                today->"Remembered today"
                                wide&&!quiet&&saint.id=="st-joseph"->"Novena to St. Joseph · Lasance, 1906"
                                wide->saint.observance(profile).calendarName
                                else->"Open prayers and life"
                            })
                            if(wide) {
                                views.setTextViewText(R.id.saint_widget_prayer,saint?.widgetText(profile).orEmpty())
                                views.setViewVisibility(R.id.saint_widget_prayer,if(quiet)View.GONE else View.VISIBLE)
                            } else {
                                views.setViewVisibility(R.id.saint_widget_shade,if(bitmap!=null)View.VISIBLE else View.GONE)
                                views.setTextColor(R.id.saint_widget_name,if(bitmap!=null)Color.WHITE else context.getColor(R.color.saint_widget_text))
                                views.setTextColor(R.id.saint_widget_caption,if(bitmap!=null)Color.WHITE else context.getColor(R.color.saint_widget_secondary))
                                views.setViewVisibility(R.id.saint_widget_caption,if(quiet&&!today&&saint!=null)View.GONE else View.VISIBLE)
                            }
                            val url=Uri.parse("nrsv://saint?widget=$id"+(saint?.let {"&id=${it.id}"} ?: ""))
                            views.setOnClickPendingIntent(R.id.saint_widget_root,PendingIntent.getActivity(context,id,Intent(Intent.ACTION_VIEW,url,context,MainActivity::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                            manager.updateAppWidget(id,views)
                        }
                    }
                    JohnWidgetSchedule.refresh(context)
                } finally {complete()}
            }
        }
    }
}

class SaintWidgetConfigurationActivity:ComponentActivity() {
    override fun onCreate(savedInstanceState:Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(Activity.RESULT_CANCELED)
        val widgetID=intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,AppWidgetManager.INVALID_APPWIDGET_ID)
        if(widgetID==AppWidgetManager.INVALID_APPWIDGET_ID){finish();return}
        val prefs=getSharedPreferences("john_saint_widgets",MODE_PRIVATE)
        val store=JohnStore(this)
        val saints=JohnRepository(this).use {it.personalSaints()}
        setContent {JohnTheme(store.appearance) {
            var selected by remember {mutableStateOf(prefs.getString("$widgetID.saint",store.widgetSaintID).orEmpty())}
            var quiet by remember {mutableStateOf(prefs.getBoolean("$widgetID.quiet",store.widgetSaintQuiet))}
            var error by remember {mutableStateOf<String?>(null)}
            JohnPage("My Saint widget",subtitle="Choose the saint for this widget.",back={finish()}) {
                saints.forEach {saint->FilterChip(selected=selected==saint.id,onClick={selected=saint.id},label={Text(saint.name)},colors=saintChoiceColors())}
                Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) {Text("Artwork and name only");Switch(quiet,{quiet=it},colors=saintSwitchColors())}
                Button(enabled=selected.isNotBlank(),onClick={
                    if(prefs.edit().putString("$widgetID.saint",selected).putBoolean("$widgetID.quiet",quiet).commit()) {
                        MySaintWidget.refresh(applicationContext,intArrayOf(widgetID))
                        setResult(Activity.RESULT_OK,Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,widgetID));finish()
                    } else error="The widget choice could not be saved. Try again."
                },modifier=Modifier.fillMaxWidth().heightIn(min=48.dp)) {Text("Save widget")}
                error?.let {JohnText(it)}
            }
        }}
    }
}
