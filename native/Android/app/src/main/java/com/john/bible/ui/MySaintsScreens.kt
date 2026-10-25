package com.john.bible.ui

import android.Manifest
import android.app.TimePickerDialog
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Favorite
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.NotificationManagerCompat
import com.john.bible.data.*
import com.john.bible.platform.SaintReminders
import java.time.LocalDate
import java.time.MonthDay
import java.time.format.DateTimeFormatter
import java.util.Locale

private fun dayLabel(value:String)=MonthDay.parse("--$value").atYear(2024).format(DateTimeFormatter.ofPattern("MMMM d",Locale.getDefault()))
private fun dateLabel(value:LocalDate)=value.format(DateTimeFormatter.ofPattern("MMMM d, yyyy",Locale.getDefault()))

@Composable internal fun saintChoiceColors(): SelectableChipColors {
    val c=LocalJohnColors.current
    return FilterChipDefaults.filterChipColors(containerColor=c.card,labelColor=c.text,
        selectedContainerColor=c.tint,selectedLabelColor=c.card)
}

@Composable internal fun saintSwitchColors(): SwitchColors {
    val c=LocalJohnColors.current
    return SwitchDefaults.colors(checkedThumbColor=c.card,checkedTrackColor=c.tint,
        uncheckedThumbColor=c.textDim,uncheckedTrackColor=c.card,uncheckedBorderColor=c.border)
}

@Composable private fun SaintAction(text:String,onClick:()->Unit) {
    val c=LocalJohnColors.current
    Button(onClick=onClick,modifier=Modifier.fillMaxWidth().heightIn(min=48.dp),shape=RoundedCornerShape(12.dp),
        colors=ButtonDefaults.buttonColors(containerColor=c.tint,contentColor=c.card)) { Text(text,fontFamily=SpaceGrotesk,fontWeight=FontWeight.Medium) }
}

@Composable fun MySaintsTodaySection(repo:JohnRepository,store:JohnStore,navigate:(String)->Unit) {
    val saints=remember(repo) { runCatching { repo.personalSaints() }.getOrDefault(emptyList()) }
    JohnRow("My Saints","A saint to return to") { navigate("my-saints") }
    saints.filter { store.saintProfile(it.id).saved }.forEach { saint ->
        JohnRow(saint.name,saint.subtitle,image=saint.artwork) { navigate("saint/${saint.id}") }
    }
    saints.filter { SaintDates.planIsDue(store.saintProfile(it.id)) }.forEach { saint ->
        saint.novenaID?.let { JohnRow("Pray with ${saint.name}","Your planned novena is ready") { navigate("novena/$it") } }
    }
}

@Composable fun MySaintsScreen(repo:JohnRepository,store:JohnStore,navigate:(String)->Unit,back:()->Unit) {
    val result=remember(repo) { runCatching { repo.personalSaints() } }
    val saints=result.getOrDefault(emptyList())
    var query by rememberSaveable { mutableStateOf("") }
    JohnPage("My Saints",subtitle="Return to the saints you have chosen.",back=back) {
        if(result.isFailure)JohnText("The saints could not be loaded. Open this page again to retry.")
        val saved=saints.filter { store.saintProfile(it.id).saved }
        if(saved.isEmpty())JohnText("Choose a saint you would like to know. Keep their prayers, story, and feast day together.",dim=true)
        saved.forEach { saint -> JohnRow(saint.name,saint.subtitle,image=saint.artwork) { navigate("saint/${saint.id}") } }
        JohnText("Find a saint",size=20)
        OutlinedTextField(query,{query=it},Modifier.fillMaxWidth(),label={Text("Search by name")},singleLine=true)
        saints.filter { query.isBlank() || it.name.contains(query.trim(),true) }.forEach { saint ->
            JohnRow(saint.name,saint.subtitle,image=saint.artwork) { navigate("saint/${saint.id}") }
        }
        JohnText("These personal pages use reviewed links to the existing calendars. More saints are available in Saints & feast days.",size=14,dim=true)
        JohnButton("Browse saints & feast days") { navigate("saints") }
        JohnButton("My Saint widget") { navigate("saint-widget") }
    }
}

@Composable fun PersonalSaintScreen(id:String,repo:JohnRepository,store:JohnStore,navigate:(String)->Unit,back:()->Unit) {
    val saint=remember(id,repo) { runCatching { repo.personalSaints().firstOrNull { it.id==id } }.getOrNull() }
    if(saint==null) { JohnPage("My Saints",back=back) { JohnText("This personal saint page is not available.") };return }
    val profile=store.saintProfile(id)
    val observance=saint.observance(profile)
    val c=LocalJohnColors.current
    val uri=LocalUriHandler.current
    var tab by rememberSaveable(id) { mutableIntStateOf(0) }
    var editor by rememberSaveable(id) { mutableStateOf<String?>(null) }
    var draft by rememberSaveable(id) { mutableStateOf("") }
    var message by remember { mutableStateOf<String?>(null) }
    var confirmRemove by remember { mutableStateOf(false) }
    val save:(SaintProfile)->Boolean={ next -> store.saveSaintProfile(id,next).also { message=if(it)null else "Your change could not be saved. Try again." } }
    fun toggleSaved() { save(profile.copy(saved=!profile.saved)) }
    Column(Modifier.fillMaxSize().background(c.background).verticalScroll(rememberScrollState()).padding(24.dp),verticalArrangement=Arrangement.spacedBy(18.dp)) {
        Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) {
            TextButton(onClick=back) { Text("Back",fontFamily=SpaceGrotesk) }
            TextButton(onClick={navigate("saint-widget")}) { Text("Widget",fontFamily=SpaceGrotesk) }
        }
        saint.artwork?.let { JohnArtwork(it,Modifier.fillMaxWidth().height(186.dp).clip(RoundedCornerShape(18.dp))) }
        saint.artworkCredit?.let { JohnText(it,size=12,dim=true) }
        Row(verticalAlignment=Alignment.CenterVertically) {
            Text(saint.name,Modifier.weight(1f),fontFamily=Lora,fontSize=32.sp,lineHeight=40.sp,color=c.text)
            IconButton(onClick={if(profile.saved&&profile.reminderEnabled)confirmRemove=true else toggleSaved()}) {
                Icon(if(profile.saved)Icons.Outlined.Favorite else Icons.Outlined.FavoriteBorder,if(profile.saved)"Remove from My Saints" else "Save to My Saints",tint=c.tint)
            }
        }
        JohnText(saint.subtitle,dim=true)
        saint.novenaID?.let { SaintAction("Pray with ${saint.name}") { navigate("novena/$it") } }
        val life=if(id in listOf("st-therese","st-monica","st-anne"))"Her life" else "His life"
        Box(Modifier.fillMaxWidth()) {
            HorizontalDivider(Modifier.align(Alignment.BottomCenter),color=c.separator)
            Row(horizontalArrangement=Arrangement.spacedBy(22.dp)) {
                listOf(life,"Prayers","My notes").forEachIndexed { i,title ->
                    Column(Modifier.width(IntrinsicSize.Max).semantics { selected=tab==i }.clickable(role=Role.Tab) {tab=i}) {
                        Text(title,Modifier.padding(vertical=14.dp),fontFamily=SpaceGrotesk,fontSize=14.sp,
                            fontWeight=if(tab==i)FontWeight.SemiBold else FontWeight.Normal,color=if(tab==i)c.text else c.textDim)
                        Box(Modifier.fillMaxWidth().height(2.dp).background(if(tab==i)c.tint else androidx.compose.ui.graphics.Color.Transparent))
                    }
                }
            }
        }
        when(tab) {
            0 -> {
                SelectionContainer { JohnText(observance.displayAccount.ifEmpty { "The source has no short life account." }) }
                JohnText("${if(observance.displayIsSummary)"English summary" else "Excerpt"} · ${observance.calendarName}",size=12,dim=true)
                TextButton(onClick={runCatching { uri.openUri(observance.sourceURL) }.onFailure { message="The source could not be opened." }}) { Text("Read the full life account ↗") }
                JohnRow("Prepare for the feast","${dayLabel(observance.monthDay)} · ${observance.calendarName}") { navigate("saint-feast/$id") }
                JohnText("Why I chose ${saint.name}",size=18)
                if(profile.reason.isNotBlank())SelectionContainer { JohnText(profile.reason,serif=true,size=17) }
                JohnButton(if(profile.reason.isBlank())"Add a private note" else "Edit my note") { draft=profile.reason;editor="reason" }
            }
            1 -> {
                saint.novenaID?.let { JohnRow("Novena to ${saint.name}","Nine days of prayer · Available offline") { navigate("novena/$it") } }
                    ?: JohnText("There is no prayer linked to this saint in the current library.",dim=true)
                JohnRow("Open the prayer library") { navigate("prayers") }
                JohnRow("Prepare for the feast",dayLabel(observance.monthDay)) { navigate("saint-feast/$id") }
            }
            else -> {
                JohnText("Why I chose ${saint.name}",size=18)
                if(profile.reason.isNotBlank())SelectionContainer { JohnText(profile.reason,serif=true,size=17) }
                JohnButton(if(profile.reason.isBlank())"Add a private note" else "Edit my note") { draft=profile.reason;editor="reason" }
                JohnButton("Add an intention or thanks") { draft="";editor="note" }
                profile.notes.sortedByDescending { it.createdAt }.forEach { note -> JohnPanel {
                    JohnText(java.text.DateFormat.getDateInstance().format(java.util.Date(note.createdAt)),size=12,dim=true)
                    SelectionContainer { JohnText(note.text) }
                    TextButton(onClick={save(profile.copy(notes=profile.notes.filterNot { it.id==note.id }))}) { Text("Delete note") }
                } }
                JohnText("Notes stay on this device. They do not appear in widgets or notifications.",size=12,dim=true)
            }
        }
        message?.let { JohnText(it,dim=true) }
    }
    if(confirmRemove)AlertDialog(onDismissRequest={confirmRemove=false},title={Text("Remove from My Saints?")},
        text={Text("Your notes and feast reminder will remain. You can turn off the reminder on the feast page.")},
        confirmButton={TextButton(onClick={toggleSaved();confirmRemove=false}) { Text("Remove saint") }},dismissButton={TextButton(onClick={confirmRemove=false}) {Text("Cancel")}})
    if(editor!=null)AlertDialog(onDismissRequest={editor=null},title={Text(if(editor=="reason")"Why I chose ${saint.name}" else "An intention or thanks",fontFamily=Lora)},
        text={Column { JohnText("Stored only on this device.",size=12,dim=true);OutlinedTextField(draft,{draft=it},Modifier.fillMaxWidth().heightIn(min=150.dp),label={Text("Your note")});message?.let { Text(it) } }},
        confirmButton={TextButton(enabled=editor=="reason"||draft.isNotBlank(),onClick={
            val next=if(editor=="reason")profile.copy(reason=draft.trim()) else profile.copy(notes=profile.notes+SaintNote(text=draft.trim()))
            if(save(next))editor=null
        }) {Text("Save")}},dismissButton={TextButton(onClick={editor=null}) {Text("Cancel")}})
}

@Composable fun SaintFeastScreen(id:String,repo:JohnRepository,store:JohnStore,navigate:(String)->Unit,back:()->Unit) {
    val saint=remember(id,repo) { runCatching { repo.personalSaints().firstOrNull { it.id==id } }.getOrNull() }
    if(saint==null) {JohnPage("My Saints",back=back) {JohnText("This saint is not available.")};return}
    val profile=store.saintProfile(id)
    var selection by rememberSaveable(id) { mutableStateOf(saint.observance(profile).id) }
    var enabled by rememberSaveable(id) { mutableStateOf(profile.reminderEnabled) }
    var hour by rememberSaveable(id) { mutableIntStateOf(profile.reminderHour) }
    var minute by rememberSaveable(id) { mutableIntStateOf(profile.reminderMinute) }
    var message by remember { mutableStateOf<String?>(null) }
    val context=LocalContext.current
    val uri=LocalUriHandler.current
    val observance=saint.commemorations.firstOrNull { it.id==selection } ?: saint.observance(profile)
    val feast=SaintDates.nextOccurrence(observance.monthDay)
    val today=feast==LocalDate.now()
    fun saveSettings() {
        val next=profile.copy(observanceID=selection,reminderEnabled=enabled,reminderHour=hour,reminderMinute=minute,
            plannedFeastDate=profile.plannedFeastDate.takeIf { profile.observanceID==selection })
        message=runCatching { SaintReminders.save(context,store,saint,next);"Saved." }.getOrElse { it.message ?: "The settings could not be saved." }
    }
    val permission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if(granted)saveSettings() else message="Notifications are off. Allow them in device settings to receive reminders."
    }
    val c=LocalJohnColors.current
    Column(Modifier.fillMaxSize().background(c.background).verticalScroll(rememberScrollState()).padding(24.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
        TextButton(onClick=back) {Text("Back",fontFamily=SpaceGrotesk)}
        Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(12.dp)) {
            saint.artwork?.let {JohnArtwork(it,Modifier.size(52.dp).clip(RoundedCornerShape(12.dp)))}
            Column(verticalArrangement=Arrangement.spacedBy(4.dp)) {
                JohnText(saint.name,size=16)
                JohnText(observance.calendarName,size=14,dim=true)
            }
        }
        JohnText(if(today)"Remember ${saint.name} today." else "Prepare for the feast.",serif=true,size=32)
        saint.commemorations.forEach { item -> FilterChip(selected=selection==item.id,onClick={selection=item.id},label={Text("${dayLabel(item.monthDay)} · ${item.calendarName}")},colors=saintChoiceColors()) }
        Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(18.dp)) {
            JohnText(feast.dayOfMonth.toString(),serif=true,size=50)
            Column(verticalArrangement=Arrangement.spacedBy(4.dp)) {
                JohnText(feast.format(DateTimeFormatter.ofPattern("MMMM yyyy")),size=17)
                JohnText(if(today)"Today" else feast.format(DateTimeFormatter.ofPattern("EEEE")),size=14,dim=true)
            }
        }
        JohnText(observance.name,dim=true)
        observance.observanceNote?.let { JohnText(it,size=14,dim=true) }
        if(today) {
            saint.novenaID?.let { SaintAction("Pray with ${saint.name}") { navigate("novena/$it") } }
            JohnRow("Open the saint’s life and notes") { navigate("saint/$id") }
        } else saint.novenaID?.let { novena -> JohnPanel {
            JohnText("Nine days of prayer",size=20)
            val start=feast.minusDays(9)
            JohnText("${dateLabel(start)} – ${dateLabel(feast.minusDays(1))}",dim=true,size=14)
            val progress=store.novena(novena)
            if(progress.completedDays.isNotEmpty()||progress.intention.isNotEmpty())SaintAction("Continue novena") {navigate("novena/$novena")}
            else if(start<=LocalDate.now()) {
                JohnText("You can begin today. Missed days are not marked as prayed.",dim=true,size=14)
                SaintAction("Begin novena") {navigate("novena/$novena")}
            } else {
                val planned=profile.plannedFeastDate==feast.toString()&&profile.observanceID==selection
                SaintAction(if(planned)"Cancel novena plan" else "Plan this novena") {
                    val next=profile.copy(observanceID=selection,plannedFeastDate=if(planned)null else feast.toString())
                    message=runCatching { if(profile.reminderEnabled)SaintReminders.save(context,store,saint,next) else check(store.saveSaintProfile(id,next));"Saved." }.getOrElse {"The plan could not be saved."}
                }
                if(planned)JohnText("This novena will appear on Today when it is due.",size=14,dim=true)
            }
        } } ?: JohnText("No sourced novena is linked to this saint. Return to the life account and prayer library.",dim=true)
        Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) { Text("Remind me on the feast day",Modifier.weight(1f),fontFamily=SpaceGrotesk);Switch(enabled,{enabled=it},colors=saintSwitchColors()) }
        if(enabled)JohnButton("Reminder time: %02d:%02d".format(hour,minute)) {TimePickerDialog(context,{_,h,m->hour=h;minute=m},hour,minute,false).show()}
        if(selection!=profile.observanceID&&profile.plannedFeastDate!=null)JohnText("Changing the commemoration cancels the existing novena plan.",size=14,dim=true)
        SaintAction("Save feast settings") {
            if(enabled&&Build.VERSION.SDK_INT>=33&&!NotificationManagerCompat.from(context).areNotificationsEnabled())permission.launch(Manifest.permission.POST_NOTIFICATIONS)
            else saveSettings()
        }
        if(profile.reminderEnabled)JohnText("Next reminder: ${SaintDates.reminderDate(saint.observance(profile).monthDay,profile.reminderHour,profile.reminderMinute).format(DateTimeFormatter.ofPattern("MMM d, yyyy 'at' h:mm a"))}",size=14,dim=true)
        message?.let {JohnText(it)}
        TextButton(onClick={context.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE,context.packageName))}) {Text("Notification settings")}
        JohnText("Date from ${observance.calendarName}. Your parish may observe a different date. Android can delay reminders to save battery. An alert at the same time replaces the general calendar alert.",size=12,dim=true)
        TextButton(onClick={runCatching {uri.openUri(observance.calendarURL)}.onFailure {message="The source could not be opened."}}) {Text("View calendar source ↗")}
    }
}

@Composable fun SaintWidgetSetupScreen(repo:JohnRepository,store:JohnStore,back:()->Unit) {
    val saints=remember(repo) {runCatching {repo.personalSaints()}.getOrDefault(emptyList())}
    var selected by rememberSaveable {mutableStateOf(store.widgetSaintID)}
    var quiet by rememberSaveable {mutableStateOf(store.widgetSaintQuiet)}
    var message by remember {mutableStateOf<String?>(null)}
    JohnPage("My Saint widget",subtitle="Keep one saint in view.",back=back) {
        saints.forEach {saint->FilterChip(selected=selected==saint.id,onClick={selected=saint.id},label={Text(saint.name)},colors=saintChoiceColors())}
        Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) {Text("Artwork and name only",Modifier.weight(1f));Switch(quiet,{quiet=it},colors=saintSwitchColors())}
        saints.firstOrNull {it.id==selected}?.let {saint->JohnPanel {
            saint.artwork?.let {JohnArtwork(it,Modifier.fillMaxWidth().height(160.dp).clip(RoundedCornerShape(18.dp)))}
            JohnText(saint.name,serif=true,size=28)
            if(!quiet)JohnText(saint.widgetText(store.saintProfile(saint.id)),serif=true)
        }}
        SaintAction("Save widget choice") {message=if(store.saveSaintWidget(selected,quiet))"Widget choice saved." else "The choice could not be saved. Try again."}
        message?.let {JohnText(it)}
        JohnText("Add to your Home Screen",size=20)
        JohnText("1. Touch and hold an empty part of the Home Screen.\n2. Open Widgets.\n3. Choose John 1:1, then My Saint.\n4. Add the widget and choose a saint.")
        JohnText("Resize the widget for a compact or wide view. Launcher steps can differ. Notes and intentions never appear in this widget.",size=14,dim=true)
    }
}
