package com.john.bible.ui

import android.Manifest
import android.app.TimePickerDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import com.john.bible.data.*
import com.john.bible.platform.*
import java.util.Locale

@Composable fun ReminderScreen(kind:String,back:()->Unit) {
    val context=LocalContext.current
    var settings by remember(kind) { mutableStateOf(JohnReminders.read(context,kind)) }
    var message by remember { mutableStateOf("") }
    val save:()->Unit={ message=if(JohnReminders.save(context,kind,settings)) if(settings.enabled) "Notifications are on." else "Notifications are off." else "Could not save. Please try again." }
    val permission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted -> if(granted)save() else message="Allow notifications in device settings to receive reminders." }
    val title=when(kind) { "calendar-notifications" -> "A day in the Church"; "rosary-reminder" -> "Rosary reminder"; else -> "Reading reminder" }
    JohnPage(title,eyebrow=if(kind=="calendar-notifications")"Calendar notifications" else "Prayer rhythm",subtitle=if(kind=="calendar-notifications") "One daily notice with saints from Vatican News and the Ruthenian Byzantine Catholic calendar, plus the Roman Rite Gospel reference when available." else "Your phone schedules this reminder locally. It works without an account, server, or internet connection.",back=back) {
        JohnPanel {
            Row(verticalAlignment=Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) { JohnText(if(kind=="rosary-reminder")"Remind me to pray" else "Notify me each day"); JohnText(if(settings.enabled) "Reminder will repeat until turned off" else "No notifications scheduled",size=14,dim=true) }
                Switch(settings.enabled,{settings=settings.copy(enabled=it)})
            }
            if(kind=="rosary-reminder") {
                JohnRow("Repeat",if(settings.weekly)"Once a week" else "Every day") { settings=settings.copy(weekly=!settings.weekly) }
                if(settings.weekly) {
                    DayOfWeekRow(settings.weekday) { settings=settings.copy(weekday=it) }
                }
            }
            JohnRow("Delivery time",String.format(Locale.getDefault(),"%02d:%02d",settings.hour,settings.minute)) {
                TimePickerDialog(context,{_,h,m -> settings=settings.copy(hour=h,minute=m)},settings.hour,settings.minute,android.text.format.DateFormat.is24HourFormat(context)).show()
            }
        }
        if(kind=="calendar-notifications") JohnText("Saints: Vatican News and Ruthenian Byzantine Catholic, United States, Gregorian dates. Readings: United States · Roman Rite. Local calendars and transferred feasts can differ. Each notice opens that date’s saints and readings.",size=14,dim=true)
        JohnText("Uses your device’s current time zone. Android can delay reminders to save battery.",size=14,dim=true)
        if(message.isNotEmpty()) JohnText(message)
        JohnButton(if(kind=="calendar-notifications")"Save notifications" else "Save reminder") {
            if(settings.enabled && Build.VERSION.SDK_INT>=33 && ContextCompat.checkSelfPermission(context,Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED) permission.launch(Manifest.permission.POST_NOTIFICATIONS) else save()
        }
        JohnButton("Device notification settings") { context.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE,context.packageName)) }
    }
}
@Composable private fun DayOfWeekRow(selected:Int,onSelect:(Int)->Unit) {
    Column { (1..7).forEach { day -> JohnRow(java.time.DayOfWeek.of(day).getDisplayName(java.time.format.TextStyle.FULL,Locale.getDefault()),if(day==selected)"Selected" else "") {onSelect(day)} } }
}
@Composable fun WidgetHelpScreen(back:()->Unit) {
    JohnPage("Scripture close at hand",eyebrow="Home screen widgets",back=back) {
        JohnText("1. Touch and hold an empty area of your home screen.\n2. Tap Widgets.\n3. Choose John 1:1.\n4. Add Daily Verse, Daily Reading, or Reading Progress.")
        JohnText("Tap a widget to open the passage or your reading progress. Widget updates follow Android’s background update limits.",dim=true)
    }
}
@Composable fun VerseScreen(repo:JohnRepository,store:JohnStore,navigate:(String)->Unit,back:()->Unit,card:Boolean=false) {
    val context=LocalContext.current
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) { while(true) { kotlinx.coroutines.delay(1000);now=System.currentTimeMillis() } }
    val offset=java.time.ZoneId.systemDefault().rules.getOffset(java.time.Instant.ofEpochMilli(now)).totalSeconds*1000L
    val interval=store.intervalMinutes*60000L
    val slot=Math.floorDiv(now+offset,interval)
    val verse=remember(store.edition,store.scope,store.intervalMinutes,slot) { repo.rotatingVerse(store.edition,store.scope,store.intervalMinutes) }
    JohnPage(if(card)"Share Scripture" else "Verse of the Moment",back=back) {
        JohnPanel {
            JohnText(verse.text,serif=true,size=26)
            JohnText("${verse.bookName} ${verse.chapter}:${verse.label} · ${store.edition}",dim=true)
        }
        val seconds=((slot+1)*interval-offset-now)/1000
        JohnText("Next verse in ${seconds/3600}:${(seconds%3600/60).toString().padStart(2,'0')}:${(seconds%60).toString().padStart(2,'0')}",dim=true)
        JohnButton("Share Scripture card") {navigate("share-card/${verse.edition}/${verse.book}/${verse.chapter}/${verse.label}")}
        JohnButton("Read in context") { navigate("reader/${verse.edition}/${verse.book}/${verse.chapter}/${verse.label}") }
        JohnButton("Share passage") {
            context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT,"${verse.text}\n${verse.bookName} ${verse.chapter}:${verse.label}\n${store.edition}\nnrsv://read?book=${verse.book}&chapter=${verse.chapter}&verse=${verse.label}&translation=${verse.edition}"),"Share Scripture"))
        }
        JohnButton("Pray with this passage") { navigate("lectio") }
        JohnButton("Home screen widgets") {navigate("widget-help")}
    }
}

@Composable fun ScriptureCardScreen(route:String,repo:JohnRepository,store:JohnStore,back:()->Unit) {
    val context=LocalContext.current
    val parts=route.split('/')
    val edition=parts.getOrNull(1) ?: store.edition
    val book=parts.getOrNull(2) ?: "JHN"
    val chapter=parts.getOrNull(3)?.toIntOrNull() ?: 1
    val label=android.net.Uri.decode(parts.getOrNull(4) ?: "1")
    val hit=remember(route) {
        runCatching {
            val labels=label.split(Regex("[-–]"),limit=2)
            val verses=repo.chapter(edition,book,chapter)
            val first=verses.indexOfFirst { it.label==labels.first() }.coerceAtLeast(0)
            val last=verses.indexOfFirst { it.label==labels.last() }.coerceAtLeast(first)
            SearchHit(edition,book,repo.books(edition).first { it.code==book }.name,chapter,label,verses.subList(first,last+1).joinToString(" ") { it.text })
        }.getOrNull()
    }
    var plum by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    JohnPage("A word worth sharing","Scripture cards","Choose a background. Keep the words at the center.",back) {
        ChoiceChips(listOf("ivory" to "Warm ivory","plum" to "Evening plum"),if(plum)"plum" else "ivory") {plum=it=="plum"}
        if(hit!=null) {
            val foreground=if(plum)Color(0xFFFFF7E8) else Color(0xFF34262D)
            Box(Modifier.fillMaxWidth().heightIn(min=480.dp).clip(RoundedCornerShape(8.dp)).background(if(plum)Color(0xFF2F1D2C) else Color(0xFFF4EADB))) {
                JohnArtwork(if(plum)"share-plum" else "share-ivory",Modifier.matchParentSize())
                Column(Modifier.padding(32.dp).padding(bottom=88.dp),verticalArrangement=Arrangement.spacedBy(32.dp)) {
                    Text("JOHN 1:1",fontFamily=SpaceGrotesk,fontSize=11.sp,letterSpacing=5.sp,color=foreground)
                    Text(hit.text,fontFamily=Lora,fontSize=if(hit.text.length>900)20.sp else 26.sp,lineHeight=if(hit.text.length>900)31.sp else 39.sp,color=foreground)
                    Column { Text(hit.reference,fontFamily=SpaceGrotesk,fontSize=14.sp,color=foreground);Text(editionShort(hit.edition),fontFamily=SpaceGrotesk,fontSize=12.sp,color=foreground) }
                }
            }
            JohnButton("Share Scripture card") {runCatching { ScriptureShare.shareCard(context,hit,plum) }.onFailure {error="The Scripture card could not be prepared. You can share the words instead."}}
            JohnButton("Share text instead") {sharePassage(context,shareText(hit))}
        } else JohnText("Passage not found. Return to the reader and select the passage again.")
        if(error.isNotBlank()) JohnText(error,dim=true)
    }
}
