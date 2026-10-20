package com.john.bible.ui

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.platform.LocalDensity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.john.bible.data.JohnRepository
import com.john.bible.data.JohnStore
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.net.URLDecoder
import java.net.URLEncoder
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.roundToInt

private fun JSONArray?.objects(): List<JSONObject> = if (this == null) emptyList() else (0 until length()).mapNotNull { optJSONObject(it) }
private fun JSONArray?.strings(): List<String> = if (this == null) emptyList() else (0 until length()).map { optString(it) }
private fun JSONObject.array(key: String) = optJSONArray(key).objects()
private fun JSONObject.str(key: String) = if (isNull(key)) "" else optString(key)
private fun encoded(value: String): String = URLEncoder.encode(value, "UTF-8")
private fun decoded(value: String): String = URLDecoder.decode(value, "UTF-8")
private fun dateText(date: LocalDate, format: String) = date.format(DateTimeFormatter.ofPattern(format, Locale.US))
private fun mysteryTitle(set: String) = "The ${set.replaceFirstChar { it.uppercase() }} Mysteries"
private fun sunday(date: LocalDate) = date.plusDays((7-date.dayOfWeek.value).toLong())
private fun seasonArt(season: String) = when(season) { "advent" -> "advent"; "christmas" -> "joyful-3"; "lent" -> "sorrowful-1"; "triduum" -> "sorrowful-5"; "easter" -> "glorious-1"; else -> "scripture" }
private fun seasonName(season: String) = when(season) { "ordinary" -> "Ordinary Time"; "triduum" -> "The Sacred Triduum"; else -> season.replaceFirstChar { it.uppercase() } }
private fun novenaArt(id: String): String = when { id.startsWith("st-") -> id; id == "holy-spirit" -> "glorious-3"; id == "assumption" -> "glorious-4"; id in listOf("sacred-heart", "divine-mercy", "christ-the-king") -> "glorious-1"; id.contains("lady") || id in listOf("miraculous-medal", "immaculate-conception") -> "mary"; else -> "prayer" }

@Composable
private fun DevotionArt(name: String) {
    val context = LocalContext.current
    val bitmap = remember(name) { runCatching { context.assets.open("artwork/$name.jpg").use { BitmapFactory.decodeStream(it).asImageBitmap() } }.getOrNull() }
    if (bitmap != null) Image(bitmap, null, Modifier.fillMaxWidth().aspectRatio(1.7f).clip(RoundedCornerShape(18.dp)), contentScale = ContentScale.Crop)
}

@Composable
private fun DevotionInput(value: String, change: (String)->Unit, placeholder: String, multiline: Boolean = false) {
    val colors = LocalJohnColors.current
    OutlinedTextField(value, change, Modifier.fillMaxWidth().then(if (multiline) Modifier.heightIn(min=140.dp) else Modifier),
        placeholder={ JohnText(placeholder, dim=true) }, singleLine=!multiline,
        keyboardOptions=KeyboardOptions(autoCorrectEnabled=false),
        shape=RoundedCornerShape(10.dp), colors=OutlinedTextFieldDefaults.colors(focusedTextColor=colors.text,
            unfocusedTextColor=colors.text, focusedBorderColor=colors.tint, unfocusedBorderColor=colors.border,
            cursorColor=colors.tint, focusedContainerColor=colors.background, unfocusedContainerColor=colors.background))
}

@Composable
private fun DevotionHeroPage(image:String,title:String,eyebrow:String,subtitle:String,back:()->Unit,content:@Composable ColumnScope.()->Unit) {
    val colors=LocalJohnColors.current
    Column(Modifier.fillMaxSize().background(colors.background).verticalScroll(rememberScrollState()).padding(horizontal=24.dp).padding(top=16.dp,bottom=48.dp),verticalArrangement=Arrangement.spacedBy(24.dp)) {
        TextButton(onClick=back) { Text("Back",fontFamily=SpaceGrotesk) }
        DevotionArt(image)
        Column(verticalArrangement=Arrangement.spacedBy(8.dp)) {
            Text(eyebrow,fontFamily=SpaceGrotesk,fontWeight=FontWeight.SemiBold,fontSize=12.sp,lineHeight=18.sp,letterSpacing=1.8.sp,color=colors.tint)
            Text(title,fontFamily=SpaceGrotesk,fontWeight=FontWeight.Bold,fontSize=36.sp,lineHeight=44.sp,color=colors.text)
            JohnText(subtitle,dim=true)
        }
        content()
    }
}

@Composable
private fun NovenaLibraryCard(item:JSONObject,completed:Set<Int>,onClick:()->Unit) {
    val colors=LocalJohnColors.current
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(colors.card).border(1.dp,colors.border,RoundedCornerShape(20.dp)).clickable(onClick=onClick).padding(24.dp),verticalArrangement=Arrangement.spacedBy(24.dp)) {
        Row(horizontalArrangement=Arrangement.spacedBy(16.dp),verticalAlignment=Alignment.Top) {
            JohnArtwork(novenaArt(item.str("id")),Modifier.width(76.dp).height(92.dp).clip(RoundedCornerShape(10.dp)))
            Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(8.dp)) {
                Text(item.str("title"),fontFamily=SpaceGrotesk,fontWeight=FontWeight.Medium,fontSize=20.sp,lineHeight=32.sp,color=colors.text)
                JohnText(item.str("subtitle"),dim=true,size=14)
                JohnText("Patronage · ${item.str("patronage")}",dim=true,size=12)
            }
            JohnText("›",size=24)
        }
        Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
            (1..9).forEach { day -> Box(Modifier.size(10.dp).clip(CircleShape).background(if(day in completed) colors.tint else colors.background).border(1.dp,if(day in completed) colors.tint else colors.border,CircleShape)) }
        }
        Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) {
            Text(if(completed.isEmpty()) "READY TO BEGIN" else "${completed.size} OF 9 PRAYED",fontFamily=SpaceGrotesk,fontWeight=FontWeight.SemiBold,fontSize=12.sp,letterSpacing=1.sp,color=colors.tint)
            if(item.str("feastDay").isNotBlank()) JohnText("Feast ${item.str("feastDay")}",dim=true,size=12)
        }
    }
}

@Composable
fun TodayScreen(repo: JohnRepository, store: JohnStore, navigate: (String)->Unit) {
    var clockTick by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) { while(true) { delay(60_000); clockTick=System.currentTimeMillis() } }
    val currentTime=java.time.LocalDateTime.ofInstant(java.time.Instant.ofEpochMilli(clockTick),java.time.ZoneId.systemDefault())
    val now=currentTime.toLocalDate()
    val catalog = remember(repo) { repo.content() }
    val readings = remember(now) { repo.readings(now.toString()) }
    val celebration = remember(now) { repo.celebrations(now.toString()) }
    val season = com.john.bible.data.CompanionCalendar.season(now)
    val title = readings?.str("title")?.ifBlank { null } ?: celebration?.str("title")?.ifBlank { null } ?: seasonName(season)
    val set = com.john.bible.data.CompanionCalendar.rosarySet(now)
    val verse=remember(clockTick,store.edition,store.scope,store.intervalMinutes) { repo.rotatingVerse(store.edition,store.scope,store.intervalMinutes) }
    val prayerId = if(currentTime.hour < 17) "morning" else "evening"
    val prayer = catalog.array("prayers").firstOrNull { it.str("id")==prayerId } ?: catalog.array("prayers").firstOrNull()
    JohnPage("A little closer to God.", "JOHN 1:1  /  ${dateText(now,"EEEE, MMMM d")}", "Scripture for your day. Space for your soul.") {
        JohnArtCard(seasonArt(season), title, "${seasonName(season)} · Today’s readings") { navigate("daily/$now") }
        JohnText("United States · Roman Rite", dim=true, size=14)
        JohnRow("Saints & feast days", "Vatican News · Byzantine Catholic · Lives of the saints") { navigate("saints") }
        MySaintsTodaySection(repo,store,navigate)
        TodayReadingCard(repo,store,navigate)
        JohnText("Make room for prayer", size=20)
        JohnRow("Pray the Rosary", mysteryTitle(set)) { navigate("rosary/$set") }
        prayer?.let { JohnRow(it.str("title"),it.str("subtitle")) { navigate("prayer/${it.str("id")}") } }
        catalog.array("novenas").forEach { item ->
            val progress = store.novena(item.str("id"))
            if((progress.completedDays.isNotEmpty() || progress.intention.isNotBlank()) && progress.completedDays.size<9) JohnRow(item.str("title"), "Continue with day ${(1..9).first { it !in progress.completedDays }}") { navigate("novena/${item.str("id")}") }
        }
        JohnPanel {
            JohnText("A WORD TO CARRY WITH YOU",size=11)
            SelectionContainer { JohnText(verse.text,serif=true,size=24) }
            JohnText("${verse.reference} · ${editionShort(store.edition)}",dim=true,size=14)
            JohnButton("Pray with this passage") { navigate("lectio/${encoded(verse.reference + "\n" + verse.text)}") }
            JohnRow("Verse & lock screen widget","Read in context, share, or set up your widget") { navigate("verse") }
        }
        JohnArtCard("scripture", "Come ready for Sunday", "${dateText(sunday(now),"MMMM d")} · Read, reflect, return") { navigate("sunday") }
        JohnRow("Explore the Catholic faith", "Scripture alongside the Catechism") { navigate("learn") }
        JohnRow("Prepare for Confession", "The Ten Commandments and the Catechism on Penance") { navigate("confession") }
        JohnText("Your Bible, prayers, and reflections stay close. No account needed.",dim=true,size=14)
    }
}

@Composable
private fun rosaryReminderSummary():String {
    val settings=com.john.bible.platform.JohnReminders.read(LocalContext.current,"rosary-reminder")
    if(!settings.enabled) return "No reminder set"
    val time=java.time.LocalTime.of(settings.hour,settings.minute).format(DateTimeFormatter.ofLocalizedTime(java.time.format.FormatStyle.SHORT))
    return if(settings.weekly) "Every ${java.time.DayOfWeek.of(settings.weekday).getDisplayName(java.time.format.TextStyle.FULL,Locale.getDefault())} at $time" else "Every day at $time"
}

@Composable
private fun TodayReadingCard(repo:JohnRepository,store:JohnStore,navigate:(String)->Unit) {
    val colors=LocalJohnColors.current
    val books=remember(store.edition) { repo.books(store.edition) }
    val total=books.sumOf { it.chapters }
    val read=books.sumOf { book -> (1..book.chapters).count { chapter-> store.isChapterRead(store.edition,book.code,chapter) } }
    val john=(1..21).count { store.isChapterRead(store.edition,"JHN",it) }
    JohnText("Your reading",size=20)
    if(store.planId==null) JohnPanel {
        JohnText("Read John a little each day")
        JohnButton("Start: John in 21 days") { store.startPlan("john-21") }
        JohnButton("Start: John in 7 days") { store.startPlan("john-7") }
    } else {
        val days=if(store.planId=="john-7") 7 else 21
        val count=21/days
        val day=(store.planDay()-1).coerceAtLeast(0)
        val first=day.coerceAtMost(days-1)*count+1
        val last=(first+count-1).coerceAtMost(21)
        val done=(first..last).all { store.isChapterRead(store.edition,"JHN",it) }
        val label=if(first==last) "John $first" else "John $first–$last"
        JohnPanel {
            JohnText("JOHN IN $days DAYS  /  DAY ${(day+1).coerceAtMost(days)} OF $days",size=11)
            JohnText(if(done) "$label — read" else "Today: $label",serif=true,size=24)
            JohnButton(if(done) "Read again" else "Read now") { navigate("reader/${store.edition}/JHN/$first") }
            JohnButton(if(day>=days) "Finish plan" else "Stop plan") { store.startPlan(null) }
        }
    }
    JohnPanel {
        Row(horizontalArrangement=Arrangement.spacedBy(24.dp)) {
            listOf(Triple("All books",read,total),Triple("John",john,21)).forEach { (title,count,maximum) ->
                Column(horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(6.dp)) {
                    val fraction=if(maximum>0) count.toFloat()/maximum else 0f
                    Box(Modifier.size(64.dp),contentAlignment=Alignment.Center) {
                        CircularProgressIndicator(progress={fraction},modifier=Modifier.fillMaxSize(),color=colors.tint,strokeWidth=7.dp,trackColor=colors.border)
                        JohnText("${(fraction*100).roundToInt()}%",size=14)
                    }
                    JohnText(title,size=13)
                    JohnText("$count of $maximum",dim=true,size=12)
                }
            }
        }
    }
}

@Composable
fun PrayScreen(repo: JohnRepository, store: JohnStore, navigate: (String)->Unit) {
    val catalog=remember(repo) { repo.content() }
    var query by rememberSaveable { mutableStateOf("") }
    val reminder=rosaryReminderSummary()
    JohnPage("Prayer","PRAYER LIBRARY","Everyday prayer, the Rosary, and Catholic novenas. A little space to be with God.",sansTitle=true) {
        JohnArtCard("mary","Pray the Rosary","${mysteryTitle(com.john.bible.data.CompanionCalendar.rosarySet(LocalDate.now()))} · $reminder") { navigate("rosary") }
        JohnRow("Our Lady of Sorrows","The Servite Rosary of the Seven Sorrows") { navigate("rosary/seven-sorrows") }
        JohnRow("My Saints","Your saints, prayers, and feast days") { navigate("my-saints") }
        JohnRow("Everyday prayers","Traditional prayers and prayers of the saints") { navigate("prayers") }
        JohnRow("Pray with Scripture","A quiet guide to lectio divina") { navigate("lectio") }
        JohnRow("Prepare for Confession","The Ten Commandments and the Catechism on Penance") { navigate("confession") }
        JohnRow("Explore the Catholic faith","Scripture and the Catechism") { navigate("learn") }
        JohnText("Novenas",size=20)
        JohnText("Nine days of prayer",dim=true,size=12)
        DevotionInput(query,{query=it},"Search by saint or need…")
        val results = catalog.array("novenas").filter { query.isBlank() || listOf(it.str("title"),it.str("subtitle"),it.str("about"),it.str("patronage"),it.optJSONArray("searchTerms").strings().joinToString(" ")).joinToString(" ").contains(query.trim(),true) }
        JohnText(if(query.isBlank()) "${results.size} novenas · Available offline" else "${results.size} found · Available offline",dim=true,size=14)
        if(results.isEmpty()) JohnPanel { JohnText("No novenas found",size=20); JohnText("Try a saint’s name or a need such as healing or hope.",dim=true) }
        results.forEach { item ->
            val progress=store.novena(item.str("id"))
            NovenaLibraryCard(item,progress.completedDays) { navigate("novena/${item.str("id")}") }
        }
    }
}

@Composable
fun DevotionalScreen(route: String, repo: JohnRepository, store: JohnStore, navigate: (String)->Unit, back: ()->Unit) {
    val catalog=remember(repo) { repo.content() }
    val parts=route.split('/')
    when(parts[0]) {
        "my-saints" -> MySaintsScreen(repo,store,navigate,back)
        "saint" -> PersonalSaintScreen(parts.getOrNull(1).orEmpty(),repo,store,navigate,back)
        "saint-feast" -> SaintFeastScreen(parts.getOrNull(1).orEmpty(),repo,store,navigate,back)
        "saint-widget" -> SaintWidgetSetupScreen(repo,store,back)
        "saints" -> SaintsScreen(repo, back, navigate)
        "daily", "calendar", "sunday" -> CalendarScreen(parts.getOrNull(1),parts[0]=="sunday",repo,store,navigate,back)
        "prayers" -> PrayerLibrary(catalog,store,navigate,back)
        "prayer" -> PrayerDetail(parts.getOrNull(1).orEmpty(),catalog,store,navigate,back)
        "rosary-media" -> RosaryMedia(parts.getOrNull(1),catalog,back)
        "rosary" -> if(parts.size<2) RosaryLibrary(catalog,navigate,back) else RosaryGuide(parts[1],catalog,back)
        "lectio" -> LectioGuide(repo,store,parts.drop(1).joinToString("/"),navigate,back)
        "confession" -> ConfessionGuide(back)
        "learn" -> TeachingLibrary(catalog,navigate,back)
        "teaching" -> TeachingDetail(parts.getOrNull(1).orEmpty(),catalog,navigate,back)
        "novenas" -> PrayScreen(repo,store,navigate)
        "novena" -> NovenaDetail(parts.getOrNull(1).orEmpty(),catalog,store,back)
        "works" -> WorksLibrary(parts.getOrNull(1),repo,store,navigate,back)
        "work" -> WorkReader(parts.getOrNull(1).orEmpty(),parts.getOrNull(2)?.toIntOrNull(),repo,store,navigate,back)
        "commentary" -> CommentaryScreen(parts.getOrNull(1).orEmpty(),parts.getOrNull(2)?.toIntOrNull() ?: 1,repo,navigate,back)
        "citation" -> CitationScreen(decoded(parts.drop(1).joinToString("/")),repo,store,navigate,back)
        else -> JohnPage("Page not found",back=back) { JohnButton("Return",back) }
    }
}

@Composable
private fun PrayerLibrary(catalog:JSONObject,store:JohnStore,navigate:(String)->Unit,back:()->Unit) {
    var query by rememberSaveable { mutableStateOf("") }
    val prayers=catalog.array("prayers")
    JohnPage("Prayer for every day","Keep a little quiet","Traditional prayers and prayers of the saints, each with its source.",back) {
        DevotionInput(query,{query=it},"Find a prayer…")
        if(query.isBlank()) {
            val favorites=prayers.filter { it.str("id") in store.favoritePrayerIds }
            if(favorites.isNotEmpty()) { JohnText("Kept close",size=20); favorites.forEach { JohnRow(it.str("title"),it.str("subtitle")) { navigate("prayer/${it.str("id")}") } } }
        }
        val results=prayers.filter { query.isBlank() || "${it.str("title")} ${it.str("subtitle")} ${it.str("category")}".contains(query.trim(),true) }
        listOf("Daily rhythm","Traditional prayers","Prayers of the saints","In times of need").forEach { category ->
            val items=results.filter { it.str("category")==category }
            if(items.isNotEmpty()) { JohnText(category,size=20); items.forEach { JohnRow(it.str("title"),it.str("subtitle")) { navigate("prayer/${it.str("id")}") } } }
        }
        if(results.isEmpty()) JohnText("No prayers found. Try morning, Mary, or suffering.",dim=true)
    }
}

@Composable
private fun PrayerDetail(id:String,catalog:JSONObject,store:JohnStore,navigate:(String)->Unit,back:()->Unit) {
    val prayer=catalog.array("prayers").firstOrNull { it.str("id")==id }
    var favorite by remember(id) { mutableStateOf(id in store.favoritePrayerIds) }
    if(prayer==null) { JohnPage("Prayer not found",back=back) { JohnText("This prayer is not in the library."); JohnButton("Prayer library") { navigate("prayers") } }; return }
    JohnPage(prayer.str("title"),prayer.str("category"),prayer.str("subtitle"),back) {
        DevotionArt(if(id in listOf("angelus","hail-mary","regina-caeli")) "mary" else "prayer")
        SelectionContainer { JohnText(prayer.str("text"),serif=true,size=24) }
        if(id=="angelus") JohnRow("Hail Mary","Open the complete prayer") { navigate("prayer/hail-mary") }
        JohnButton(if(favorite) "Remove from favorites" else "Keep in favorites") { store.toggleFavoritePrayer(id); favorite=id in store.favoritePrayerIds }
        JohnText(prayer.str("source"),dim=true,size=14)
    }
}

@Composable
private fun TeachingLibrary(catalog:JSONObject,navigate:(String)->Unit,back:()->Unit) {
    JohnPage("Faith, rooted in Scripture","Explore & understand","Passages from the Catechism of the Catholic Church, with Scripture to read.",back) {
        catalog.array("teachings").forEach { item -> JohnArtCard(item.str("artwork"),item.str("title"),item.str("subtitle")) { navigate("teaching/${item.str("id")}") } }
    }
}

@Composable
private fun TeachingDetail(id:String,catalog:JSONObject,navigate:(String)->Unit,back:()->Unit) {
    val item=catalog.array("teachings").firstOrNull { it.str("id")==id }
    val uri=LocalUriHandler.current
    if(item==null) { JohnPage("Topic not found",back=back) { JohnButton("Explore the faith") { navigate("learn") } }; return }
    JohnPage(item.str("title"),"Scripture & Catholic teaching",item.str("subtitle"),back) {
        DevotionArt(item.str("artwork"))
        SelectionContainer { JohnText(item.str("summary"),serif=true,size=20) }
        JohnText("Catechism of the Catholic Church, ${item.str("catechism").replace("CCC ","§")}",dim=true,size=14)
        JohnPanel { JohnText("Read in Scripture",size=20); item.optJSONArray("references").strings().forEach { reference -> JohnRow(reference,"Open in context · WEB-CE") { navigate("citation/${encoded(reference)}") } } }
        JohnButton("Read ${item.str("catechism")} ↗") { runCatching { uri.openUri(item.str("url")) } }
    }
}

@Composable
private fun RosaryLibrary(catalog:JSONObject,navigate:(String)->Unit,back:()->Unit) {
    val rosary=catalog.optJSONObject("rosary") ?: JSONObject()
    val sets=rosary.array("mysterySets")
    val suggested=sets.firstOrNull { it.str("id")==com.john.bible.data.CompanionCalendar.rosarySet(LocalDate.now()) }
    val uri=LocalUriHandler.current
    val reminder=rosaryReminderSummary()
    DevotionHeroPage("mary","Pray the Rosary","THE MOST HOLY ROSARY","A step-by-step guide to the Rosary. The complete prayer guide works offline.",back) {
        suggested?.let { set -> JohnPanel {
            JohnText("SUGGESTED TODAY",size=12)
            JohnText(set.str("title"),size=20)
            JohnText(set.str("customaryDays"),dim=true,size=14)
            set.array("mysteries").forEachIndexed { index,item -> JohnText("${index+1}    ${item.str("title")}",size=14) }
            JohnButton("Begin today’s Rosary") { navigate("rosary/${set.str("id")}") }
        } }
        JohnRow("Rosary reminder","$reminder · Scheduled privately on this device") { navigate("rosary-reminder") }
        JohnText("Choose a mystery",size=20)
        JohnText("Sundays vary by liturgical season",dim=true,size=14)
        sets.forEach { set -> RosarySetCard(when(set.str("id")) { "joyful"->"joyful-3"; "sorrowful"->"sorrowful-1"; "glorious"->"glorious-1"; else->"luminous-5" },set) { navigate("rosary/${set.str("id")}") } }
        JohnText("Our Lady of Sorrows",size=20)
        JohnText("The Servite Rosary",dim=true,size=14)
        rosary.optJSONObject("sevenSorrows")?.let { set -> RosarySetCard("sorrows-6",set) { navigate("rosary/seven-sorrows") } }
        JohnText("Seven sorrows · one Our Father and seven Hail Marys each · about 15 minutes",dim=true,size=14)
        JohnText("The Rosary with Bishop Barron",size=20)
        JohnText("Watch the Rosary on Word on Fire’s official channels. An internet connection is needed.",dim=true,size=14)
        rosary.array("mediaEpisodes").forEach { episode -> JohnRow(episode.str("title"),"Bishop Robert Barron · Word on Fire") { navigate("rosary-media/${episode.str("id")}") } }
    }
}

@Composable
private fun RosarySetCard(image:String,set:JSONObject,onClick:()->Unit) {
    val colors=LocalJohnColors.current
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(colors.card).border(1.dp,colors.border,RoundedCornerShape(18.dp)).clickable(onClick=onClick).padding(16.dp),horizontalArrangement=Arrangement.spacedBy(16.dp),verticalAlignment=Alignment.Top) {
        JohnArtwork(image,Modifier.width(72.dp).height(84.dp).clip(RoundedCornerShape(10.dp)))
        Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(4.dp)) {
            Text(set.str("title"),fontFamily=SpaceGrotesk,fontWeight=FontWeight.SemiBold,fontSize=16.sp,color=colors.text)
            Text(set.str("customaryDays"),fontFamily=SpaceGrotesk,fontWeight=FontWeight.SemiBold,fontSize=12.sp,color=colors.tint)
            JohnText(set.str("description"),dim=true,size=14)
        }
        JohnText("›",size=24)
    }
}

@Composable
private fun RosaryGuide(id:String,catalog:JSONObject,back:()->Unit) {
    val session=catalog.optJSONObject("rosary")?.array("sessions")?.firstOrNull { it.str("id")==id }
    val context=LocalContext.current
    val credits=remember { runCatching { context.assets.open("artwork/credits.json").bufferedReader().use { JSONObject(it.readText()) } }.getOrDefault(JSONObject()) }
    val steps=session?.array("steps").orEmpty()
    var index by rememberSaveable(id) { mutableIntStateOf(0) }
    var repetition by rememberSaveable(id) { mutableIntStateOf(0) }
    if(session==null || steps.isEmpty()) { JohnPage("Rosary",back=back) { JohnText("This Rosary guide is not available right now.") }; return }
    if(index>=steps.size) {
        JohnPage(session.str("title"),"ROSARY COMPLETE",back=back) { JohnText("✢",size=40); JohnButton("Return to Rosary",back); JohnButton("Pray again") { index=0; repetition=0 } }; return
    }
    val step=steps[index]
    val repetitions=step.optInt("repetitions",1).coerceAtLeast(1)
    val total=steps.sumOf { it.optInt("repetitions",1).coerceAtLeast(1) }
    val completed=steps.take(index).sumOf { it.optInt("repetitions",1).coerceAtLeast(1) }+repetition
    JohnPage(step.str("title"),"${session.str("shortTitle")} / ${step.str("eyebrow")}",back=back) {
        JohnText("${completed*100/total}%",size=14,dim=true)
        LinearProgressIndicator(progress={completed.toFloat()/total},modifier=Modifier.fillMaxWidth(),color=LocalJohnColors.current.tint,trackColor=LocalJohnColors.current.separator)
        Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(8.dp)) {
            session.optJSONArray("groupLabels").strings().forEachIndexed { group,label ->
                Surface(Modifier.semantics { contentDescription=label }.clickable { val target=steps.indexOfFirst { it.optInt("mysteryIndex",-1)==group }; if(target>=0) { index=target; repetition=0 } },shape=CircleShape,color=if(group==step.optInt("mysteryIndex",-1)) LocalJohnColors.current.tint else LocalJohnColors.current.card) { Box(Modifier.padding(14.dp)) { JohnText("${group+1}",size=14) } }
            }
        }
        val mystery=step.optInt("mysteryIndex",-1)
        if(mystery>=0) {
            val art="${if(id=="seven-sorrows") "sorrows" else id}-${mystery+1}"
            DevotionArt(art)
            if(credits.str(art).isNotBlank()) JohnText(credits.str(art),dim=true,size=11)
        }
        if(repetitions>1) JohnText("${repetition+1} / $repetitions",dim=true,size=14)
        if(step.str("instruction").isNotBlank()) JohnText(step.str("instruction"),size=17)
        step.optJSONObject("prayer")?.let { SelectionContainer { JohnText(it.str("text"),serif=true,size=24) } }
        if(step.str("meditation").isNotBlank()) SelectionContainer { JohnText(step.str("meditation"),serif=true,size=22) }
        JohnButton(when { repetitions>1 && repetition+1<repetitions -> "Next prayer"; index==steps.lastIndex -> "Complete the Rosary"; else -> "Continue" }) { if(repetition+1<repetitions) repetition++ else { index++; repetition=0 } }
        if(index>0 || repetition>0) JohnButton("Previous") { if(repetition>0) repetition-- else { index--; repetition=steps[index].optInt("repetitions",1).coerceAtLeast(1)-1 } }
    }
}

@Composable
private fun NovenaDetail(id:String,catalog:JSONObject,store:JohnStore,back:()->Unit) {
    val item=catalog.array("novenas").firstOrNull { it.str("id")==id }
    var progress by remember(id) { mutableStateOf(store.novena(id)) }
    var reset by remember { mutableStateOf(false) }
    val uri=LocalUriHandler.current
    if(item==null) { JohnPage("Novena not found",subtitle="This prayer is not in your offline library.",back=back) {}; return }
    fun changeDay(day:Int) { store.updateNovena(id,progress.copy(selectedDay=day)); progress=store.novena(id) }
    DevotionHeroPage(novenaArt(id),item.str("title"),"NOVENA · 9 DAYS",item.str("subtitle"),back) {
        if(item.str("traditionalStart").isNotBlank()) JohnText("Begins ${item.str("traditionalStart")} · Feast ${item.str("feastDay")}",dim=true,size=12)
        JohnPanel { JohnText("ABOUT THIS NOVENA",size=12); JohnText(item.str("about"),dim=true); JohnText("Patronage · ${item.str("patronage")}") }
        JohnPanel {
            JohnText(if(progress.completedDays.size==9) "Novena complete" else "Day ${progress.selectedDay}",size=20)
            JohnText("${progress.completedDays.size} of 9 prayed",dim=true,size=14)
            Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(4.dp)) {
                (1..9).forEach { day ->
                    val colors=LocalJohnColors.current
                    Box(Modifier.size(40.dp).clip(CircleShape).background(if(day==progress.selectedDay) colors.text else if(day in progress.completedDays) colors.tint else colors.background).clickable { changeDay(day) }.padding(10.dp)) {
                        Text(if(day in progress.completedDays) "✓" else day.toString(),color=if(day==progress.selectedDay || day in progress.completedDays) colors.card else colors.text)
                    }
                }
            }
        }
        JohnPanel {
            JohnText("Your intention")
            JohnText("Stored privately on this device.",dim=true,size=14)
            DevotionInput(progress.intention,{ intention -> store.updateNovena(id,progress.copy(intention=intention)); progress=store.novena(id) },"Your intention",true)
        }
        JohnPanel {
            JohnText("DAY ${progress.selectedDay} PRAYER",size=14)
            if(item.str("opening").isNotBlank()) JohnText(item.str("opening"),size=20)
            item.array("sections").forEach { section ->
                if(section.str("title").isNotBlank()) JohnText(section.str("title"),size=20)
                section.optJSONArray("paragraphs").strings().forEach { paragraph -> SelectionContainer { JohnText(paragraph,size=18) } }
                if(section.str("response").isNotBlank()) JohnText(section.str("response"),size=16)
            }
        }
        if(progress.completedDays.size==9) JohnButton("Start the novena again") { reset=true }
        else if(progress.selectedDay in progress.completedDays) JohnText("Day ${progress.selectedDay} complete",dim=true)
        else JohnButton("Mark day ${progress.selectedDay} complete") { store.completeNovenaDay(id); progress=store.novena(id) }
        JohnRow("Devotion source · ${item.str("sourceName")}") { runCatching { uri.openUri(item.str("sourceUrl")) } }
    }
    if(reset) AlertDialog(onDismissRequest={reset=false},title={JohnText("Reset this novena?")},text={JohnText("Clears all nine completed days and your intention.")},confirmButton={TextButton(onClick={store.resetNovena(id);progress=store.novena(id);reset=false}) { Text("Reset") }},dismissButton={TextButton(onClick={reset=false}) { Text("Cancel") }})
}

@Composable
private fun CalendarScreen(initialDate:String?,isSunday:Boolean,repo:JohnRepository,store:JohnStore,navigate:(String)->Unit,back:()->Unit) {
    var date by rememberSaveable(initialDate) { mutableStateOf(initialDate ?: (if(isSunday) sunday(LocalDate.now()) else LocalDate.now()).toString()) }
    val day=runCatching { LocalDate.parse(date) }.getOrElse { LocalDate.now() }
    val entry=remember(date) { repo.readings(date) }
    val celebration=remember(date) { repo.celebrations(date) }
    val season=com.john.bible.data.CompanionCalendar.season(day)
    val uri=LocalUriHandler.current
    var before by remember(date) { mutableStateOf(store.reflection(date).before) }
    var after by remember(date) { mutableStateOf(store.reflection(date).after) }
    var feedback by remember(date) { mutableStateOf("") }
    JohnPage(if(isSunday) "Come ready for Sunday" else "Today’s readings", "United States · Roman Rite / ${seasonName(season)}",back=back) {
        Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) {
            TextButton(onClick={date=day.minusDays(if(isSunday) 7 else 1).toString()}) { Text("Previous") }
            Box(Modifier.padding(top=14.dp)) { JohnText(dateText(day,"MMM d, yyyy"),size=16) }
            TextButton(onClick={date=day.plusDays(if(isSunday) 7 else 1).toString()}) { Text("Next") }
        }
        JohnArtCard(seasonArt(season),entry?.str("title")?.ifBlank { null } ?: celebration?.str("title")?.ifBlank { null } ?: seasonName(season),dateText(day,"EEEE, MMMM d")) { runCatching { uri.openUri(com.john.bible.data.CompanionCalendar.readingsURL(day)) } }
        JohnText("USCCB reading selections. Transferred feasts and optional celebrations may differ at your parish.",dim=true,size=14)
        SaintsDaySection(repo, day) { navigate("saints") }
        JohnPanel {
            JohnText("Listen to the Word",size=20)
            JohnText("Open each reading in its biblical context. Scripture uses the offline WEB-CE edition; wording and verse divisions may differ from those proclaimed at Mass.",dim=true,size=14)
            entry?.array("readings")?.forEach { reading -> JohnRow(reading.str("reference"),reading.str("label")) { navigate("citation/${encoded(reading.str("reference"))}") } }
            if(entry==null) JohnText("Reading references for this date aren’t in your offline library. Open the official readings when you’re connected.",dim=true,size=14)
            JohnButton("Official readings ↗") { runCatching { uri.openUri(com.john.bible.data.CompanionCalendar.readingsURL(day)) } }
        }
        if(isSunday) JohnPanel {
            JohnText("Before Mass",size=20)
            DevotionInput(before,{before=it;feedback=""},"Your notes before Mass",true)
            JohnText("After Mass",size=20)
            DevotionInput(after,{after=it;feedback=""},"Your notes after Mass",true)
            JohnButton("Save reflection") { store.setReflection(date,before,after);feedback="Reflection saved on this device." }
            JohnText("Saved only when you choose. Reflections are kept on this device.",dim=true,size=14)
        }
        if(feedback.isNotEmpty()) JohnText(feedback,dim=true)
    }
}

@Composable
private fun WorksLibrary(authorId:String?,repo:JohnRepository,store:JohnStore,navigate:(String)->Unit,back:()->Unit) {
    val authors=remember(repo) { repo.workAuthors() }
    val author=authors.firstOrNull { it.id==authorId }
    val works=remember(authorId) { repo.works(authorId) }
    var query by rememberSaveable(authorId) { mutableStateOf("") }
    val lastWork=works.firstOrNull { it.id==store.lastWorkId }
    JohnPage(author?.author ?: "The Fathers & Doctors",if(author==null) "THE LIBRARY" else "THE COLLECTION",if(author==null) "${authors.size} authors · ${works.size} works · reads offline" else "${author.era.orEmpty()} · ${works.size} works · reads offline",back,sansTitle=true) {
        if(author==null) {
            if(lastWork!=null) JohnPanel { JohnText("CONTINUE READING",size=12);JohnRow(lastWork.title,"Section ${store.workLocation(lastWork.id)+1} of ${lastWork.sectionCount}") { navigate("work/${lastWork.id}") } }
            authors.forEach { item -> JohnRow(item.author,"${item.era.orEmpty()} · ${item.workCount} works") { navigate("works/${item.id}") } }
        } else {
            DevotionInput(query,{query=it},"Find a work…")
            works.filter { query.isBlank() || it.title.contains(query,true) }.forEach { work -> JohnRow(work.title,"${work.sectionCount} sections · ${work.words} words") { navigate("work/${work.id}") } }
            JohnText(author.attribution,dim=true,size=14)
        }
    }
}

private data class WorkPage(val text:String,val paragraph:Int,val offset:Int)

@Composable
private fun WorkReader(id:String,initialSection:Int?,repo:JohnRepository,store:JohnStore,navigate:(String)->Unit,back:()->Unit) {
    val work=remember(id) { repo.works().firstOrNull { it.id==id } }
    val sections=remember(id) { if(work==null) emptyList() else repo.workSections(id) }
    var section by rememberSaveable(id) { mutableIntStateOf((initialSection ?: store.workLocation(id)).coerceIn(0,(sections.size-1).coerceAtLeast(0))) }
    var contents by remember { mutableStateOf(false) }
    val selected=remember(id,section) { if(work!=null && sections.isNotEmpty()) repo.workSection(id,section.coerceIn(0,sections.lastIndex)) else null }
    val colors=LocalJohnColors.current
    val density=LocalDensity.current
    val measurer=rememberTextMeasurer()
    var previousSection by remember { mutableStateOf<Int?>(null) }
    if(work==null || selected==null) { JohnPage("Work not found",back=back) { JohnText("This work could not be opened from your offline library.") };return }
    BoxWithConstraints(Modifier.fillMaxSize().background(colors.background)) {
        val font=if(store.fontFamily=="sans") SpaceGrotesk else Lora
        val style=TextStyle(fontFamily=font,fontSize=store.textSize.sp,lineHeight=(store.textSize*store.lineSpacing).sp,color=colors.text)
        val textWidth=with(density) { (maxWidth-48.dp).roundToPx() }.coerceAtLeast(1)
        val workTitleHeight=measurer.measure(AnnotatedString(work.title),TextStyle(fontFamily=SpaceGrotesk,fontSize=12.sp,lineHeight=18.sp),constraints=Constraints(maxWidth=textWidth)).size.height
        val sectionTitleHeight=measurer.measure(AnnotatedString(selected.title),TextStyle(fontFamily=Lora,fontSize=22.sp,lineHeight=33.sp),constraints=Constraints(maxWidth=textWidth)).size.height
        val textHeight=(with(density) { (maxHeight-130.dp).roundToPx() }-workTitleHeight-sectionTitleHeight).coerceAtLeast(60)
        val gap=with(density) { 14.dp.roundToPx() }
        val lineHeight=with(density) { (store.textSize*store.lineSpacing).sp.toPx() }.coerceAtLeast(1f)
        val pages=remember(selected,textWidth,textHeight,store.textSize,store.lineSpacing,store.fontFamily) {
            val result=mutableListOf<WorkPage>()
            var draft=StringBuilder()
            var remaining=textHeight
            var anchor=0
            var anchorOffset=0
            fun flush() { if(draft.isNotEmpty()) { result+=WorkPage(draft.toString().trimEnd(),anchor,anchorOffset);draft=StringBuilder();remaining=textHeight } }
            selected.paragraphs.forEachIndexed { paragraphIndex,paragraph ->
                if(paragraph.isNotBlank()) {
                    val measured=measurer.measure(AnnotatedString(paragraph),style,constraints=Constraints(maxWidth=textWidth),skipCache=true)
                    var line=0
                    while(line<measured.lineCount) {
                        if(remaining<lineHeight) flush()
                        if(draft.isEmpty()) anchor=paragraphIndex
                        val capacity=(remaining/lineHeight).toInt().coerceAtLeast(1)
                        val endLine=(line+capacity).coerceAtMost(measured.lineCount)
                        val from=measured.getLineStart(line)
                        if(draft.isEmpty()) anchorOffset=from
                        val to=measured.getLineEnd(endLine-1)
                        draft.append(paragraph.substring(from,to))
                        remaining-=((endLine-line)*lineHeight).toInt()
                        line=endLine
                        if(line<measured.lineCount) flush() else { draft.append("\n\n");remaining-=gap }
                    }
                }
            }
            flush()
            result.ifEmpty { listOf(WorkPage("",0,0)) }
        }
        val restoredParagraph=remember(id,section) { if(initialSection==null && previousSection==null) store.workParagraph(id) else 0 }
        val restoredOffset=remember(id,section) { if(initialSection==null && previousSection==null) store.workOffset(id) else 0 }
        val startPage=pages.indexOfLast { it.paragraph<restoredParagraph || (it.paragraph==restoredParagraph && it.offset<=restoredOffset) }.coerceAtLeast(0)
        val pager=rememberPagerState(initialPage=startPage,pageCount={pages.size})
        val scope=rememberCoroutineScope()
        LaunchedEffect(section,pages) { if(previousSection!=null && previousSection!=section) pager.scrollToPage(0);previousSection=section;store.saveWorkLocation(id,section) }
        LaunchedEffect(pager.currentPage,pages) { val page=pages[pager.currentPage.coerceIn(0,pages.lastIndex)];store.saveWorkParagraph(id,page.paragraph);store.saveWorkOffset(id,page.offset) }
        Column(Modifier.fillMaxSize().padding(horizontal=24.dp)) {
            Row(Modifier.fillMaxWidth().heightIn(min=52.dp),horizontalArrangement=Arrangement.SpaceBetween) {
                TextButton(onClick=back) { Text("Back",fontFamily=SpaceGrotesk) }
                TextButton(onClick={contents=true}) { Text("Contents",fontFamily=SpaceGrotesk) }
            }
            JohnText(work.title,size=12,dim=true)
            JohnText(selected.title,size=22,serif=true)
            Spacer(Modifier.height(12.dp))
            HorizontalPager(pager,modifier=Modifier.weight(1f).fillMaxWidth(),key={page->"$section-$page"}) { page ->
                SelectionContainer { Text(pages[page].text,style=style,modifier=Modifier.fillMaxSize()) }
            }
            Row(Modifier.fillMaxWidth().height(60.dp),horizontalArrangement=Arrangement.SpaceBetween) {
                TextButton(onClick={ if(pager.currentPage>0) scope.launch { pager.animateScrollToPage(pager.currentPage-1) } else if(section>0) section-- },enabled=section>0 || pager.currentPage>0) { Text("Previous") }
                Box(Modifier.padding(top=18.dp)) { JohnText("${pager.currentPage+1} / ${pages.size}",size=12,dim=true) }
                TextButton(onClick={ if(pager.currentPage<pages.lastIndex) scope.launch { pager.animateScrollToPage(pager.currentPage+1) } else if(section<sections.lastIndex) section++ },enabled=section<sections.lastIndex || pager.currentPage<pages.lastIndex) { Text("Next") }
            }
        }
    }
    if(contents) AlertDialog(onDismissRequest={contents=false},title={JohnText("Contents",size=20)},text={
        Column(Modifier.heightIn(max=450.dp).verticalScroll(rememberScrollState())) { sections.forEach { item -> JohnRow(item.title,"Section ${item.index+1}") { section=item.index;contents=false } } }
    },confirmButton={TextButton(onClick={contents=false}) { Text("Close") }})
}

private data class ConfessionStep(val title:String,val body:String,val source:String)
private val confessionSteps=listOf(
    ConfessionStep("Prepare","“The reception of this sacrament ought to be prepared for by an examination of conscience made in the light of the Word of God.”","Catechism of the Catholic Church, §1454"),
    ConfessionStep("The sacrament of Penance","“Those who approach the sacrament of Penance obtain pardon from God’s mercy for the offense committed against him, and are, at the same time, reconciled with the Church which they have wounded by their sins and which by charity, by example, and by prayer labors for their conversion.”","Catechism of the Catholic Church, §1422"),
    ConfessionStep("Confess your sins","Confession to a priest is an essential part of the sacrament of Penance: “All mortal sins of which penitents after a diligent self-examination are conscious must be recounted by them in confession, even if they are most secret and have been committed against the last two precepts of the Decalogue; for these sins sometimes wound the soul more grievously and are more dangerous than those which are committed openly.”","Catechism of the Catholic Church, §1456"),
    ConfessionStep("Contrition","Among the penitent’s acts contrition occupies first place. Contrition is “sorrow of the soul and detestation for the sin committed, together with the resolution not to sin again.”","Catechism of the Catholic Church, §1451"),
    ConfessionStep("Absolution","God, the Father of mercies,\nthrough the death and the resurrection of his Son\nhas reconciled the world to himself\nand sent the Holy Spirit among us\nfor the forgiveness of sins;\nthrough the ministry of the Church\nmay God give you pardon and peace,\nand I absolve you from your sins in the name of the Father, and of the Son and of the Holy Spirit.","The formula of absolution, quoted in the Catechism of the Catholic Church, §1449")
)
private data class ExaminationSection(val title:String,val scripture:String,val questions:List<String>)
private val confessionExamination=listOf(
    ExaminationSection("The Ten Commandments","A traditional catechetical formula · Catechism of the Catholic Church",listOf("I am the LORD your God: you shall not have strange Gods before me.","You shall not take the name of the LORD your God in vain.","Remember to keep holy the LORD’S Day.","Honor your father and your mother.","You shall not kill.","You shall not commit adultery.","You shall not steal.","You shall not bear false witness against your neighbor.","You shall not covet your neighbor’s wife.","You shall not covet your neighbor’s goods.")),
    ExaminationSection("The great commandments","Matthew 22:37, 39 · WEB-CE",listOf("You shall love the Lord your God with all your heart, with all your soul, and with all your mind.","You shall love your neighbor as yourself.")),
    ExaminationSection("The Beatitudes","Matthew 5:3–10 · WEB-CE",listOf("Blessed are the poor in spirit, for theirs is the Kingdom of Heaven.","Blessed are those who mourn, for they shall be comforted.","Blessed are the gentle, for they shall inherit the earth.","Blessed are those who hunger and thirst for righteousness, for they shall be filled.","Blessed are the merciful, for they shall obtain mercy.","Blessed are the pure in heart, for they shall see God.","Blessed are the peacemakers, for they shall be called children of God.","Blessed are those who have been persecuted for righteousness’ sake, for theirs is the Kingdom of Heaven."))
)
private const val actOfContrition="O my God, I am heartily sorry for having offended Thee, and I detest all my sins because I dread the loss of heaven and the pains of hell, but most of all because they offend Thee, my God, who art all good and deserving of all my love. I firmly resolve, with the help of Thy grace, to confess my sins, to do penance, and to amend my life. Amen."
private data class LectioStep(val title:String,val name:String,val prompt:String)
private val lectioSteps=listOf(
    LectioStep("Read slowly","Lectio","It opens with the reading (lectio) of a text, which leads to a desire to understand its true content: what does the biblical text say in itself? Without this, there is always a risk that the text will become a pretext for never moving beyond our own ideas."),
    LectioStep("Stay with a word","Meditatio","Next comes meditation (meditatio), which asks: what does the biblical text say to us? Here, each person, individually but also as a member of the community, must let himself or herself be moved and challenged."),
    LectioStep("Speak to God","Oratio","Following this comes prayer (oratio), which asks the question: what do we say to the Lord in response to his word? Prayer, as petition, intercession, thanksgiving and praise, is the primary way by which the word transforms us."),
    LectioStep("Rest in his presence","Contemplatio","Finally, lectio divina concludes with contemplation (contemplatio), during which we take up, as a gift from God, his own way of seeing and judging reality, and ask ourselves what conversion of mind, heart and life is the Lord asking of us?"),
    LectioStep("Carry it into your day","Actio","We do well also to remember that the process of lectio divina is not concluded until it arrives at action (actio), which moves the believer to make his or her life a gift for others in charity.")
)

@Composable
private fun ConfessionGuide(back:()->Unit) {
    var index by rememberSaveable { mutableIntStateOf(0) }
    // Deliberately use remember, not rememberSaveable: confession notes never enter saved state.
    var notes by remember { mutableStateOf("") }
    var notice by remember { mutableStateOf("") }
    val owner=LocalLifecycleOwner.current
    val uri=LocalUriHandler.current
    DisposableEffect(owner) {
        val observer=LifecycleEventObserver { _,event -> if(event==Lifecycle.Event.ON_STOP) { notes="";notice="Your private notes were cleared when you left the app." } }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer);notes="" }
    }
    val step=confessionSteps[index]
    key(index) {
        JohnPage(step.title,"Prepare for Confession / ${index+1} of ${confessionSteps.size}",back=back) {
            SelectionContainer { JohnText(step.body,serif=true,size=20) }
            JohnText(step.source,dim=true,size=14)
            if(index==0) {
                JohnPanel {
                    JohnText("An examination of conscience",size=20)
                    confessionExamination.forEach { section ->
                        JohnText(section.title,size=20)
                        JohnText(section.scripture,dim=true,size=14)
                        section.questions.forEach { JohnText(it,size=17) }
                    }
                }
                JohnText("Private notes, if helpful")
                DevotionInput(notes,{notes=it},"These words will not be saved…",true)
                JohnText("These notes are never saved by John 1:1. They are cleared when you leave this guide or put the app in the background.",dim=true,size=14)
                if(notes.isNotEmpty()) JohnButton("Clear notes now") { notes="" }
            }
            if(index==2 && notes.isNotEmpty()) JohnPanel { JohnText("Your private notes",size=20);JohnText(notes) }
            if(index==3) JohnPanel { JohnText("Act of Contrition",size=20);SelectionContainer { JohnText(actOfContrition,serif=true,size=24) } }
            if(notice.isNotEmpty()) JohnText(notice,dim=true)
            JohnButton(if(index==confessionSteps.lastIndex) "Finish & clear notes" else "Continue") { if(index==confessionSteps.lastIndex) { notes="";back() } else index++ }
            if(index>0) JohnButton("Previous") { index-- }
            JohnText("Texts are quoted from the Catechism of the Catholic Church and from Scripture (WEB-CE). Your priest can help with questions about your circumstances.",dim=true,size=14)
            JohnButton("USCCB preparation resources ↗") { notes=""; runCatching { uri.openUri("https://www.usccb.org/prayer-and-worship/sacraments-and-sacramentals/penance/examinations-of-conscience") } }
        }
    }
}

@Composable
private fun LectioGuide(repo:JohnRepository,store:JohnStore,initial:String,navigate:(String)->Unit,back:()->Unit) {
    var index by rememberSaveable { mutableIntStateOf(0) }
    var deadline by remember { mutableStateOf<Long?>(null) }
    var seconds by remember { mutableIntStateOf(0) }
    val provided=remember(initial) { if(initial.isNotEmpty()) decoded(initial) else "" }
    val hit=remember(repo,store.edition) { if(provided.isBlank()) repo.rotatingVerse(store.edition,store.scope,store.intervalMinutes) else null }
    val reference=if(provided.contains('\n')) provided.substringBefore('\n') else hit?.let { "${it.bookName} ${it.chapter}:${it.label}" } ?: provided
    val passage=if(provided.contains('\n')) provided.substringAfter('\n') else hit?.text.orEmpty()
    val context=LocalContext.current
    val activity=context as? android.app.Activity
    DisposableEffect(activity,deadline) {
        if(deadline!=null) activity?.window?.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        onDispose { activity?.window?.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) }
    }
    LaunchedEffect(deadline) {
        val end=deadline ?: return@LaunchedEffect
        while(true) { seconds=((end-System.currentTimeMillis()+999)/1000).coerceAtLeast(0).toInt();if(seconds==0) { deadline=null;break };delay(250) }
    }
    val step=lectioSteps[index]
    key(index) {
        JohnPage(step.title,"Pray with Scripture / ${index+1} of ${lectioSteps.size}",back=back) {
            JohnPanel { JohnText(step.name.uppercase(),size=11);JohnText(step.prompt,size=17);JohnText("Pope Benedict XVI, Verbum Domini, 87",dim=true,size=14) }
            if(index==3) JohnPanel {
                JohnText(if(deadline!=null) "${seconds}s of quiet" else if(seconds==0) "A moment of stillness" else "Rest here for a while",serif=true,size=24)
                JohnButton(if(deadline!=null) "End the timer" else "Begin one quiet minute") { if(deadline!=null) { deadline=null;seconds=0 } else { seconds=60;deadline=System.currentTimeMillis()+60_000 } }
                JohnText("No sound or vibration. Continue whenever you are ready.",dim=true,size=14)
            }
            if(passage.isNotBlank()) { SelectionContainer { JohnText(passage,serif=true,size=24) };JohnText("$reference · ${editionShort(store.edition)}",dim=true,size=14) }
            else { JohnText("Choose a passage in the Bible reader, then select Pray.",dim=true);JohnButton("Open the Bible") { navigate("read") } }
            JohnButton(if(index==lectioSteps.lastIndex) "Finish prayer" else "Continue") { deadline=null;if(index==lectioSteps.lastIndex) back() else index++ }
            if(index>0) JohnButton("Previous step") { deadline=null;index-- }
        }
    }
}

@Composable
private fun CitationScreen(reference:String,repo:JohnRepository,store:JohnStore,navigate:(String)->Unit,back:()->Unit) {
    val normalized=remember(reference) {
        var text=reference.replace(Regex("^See\\s+",RegexOption.IGNORE_CASE),"").replace(Regex("\\s+")," ")
        text=text.replace(Regex("^Joel 3:",RegexOption.IGNORE_CASE),"Joel 2:").replace(Regex("^Joel 4:",RegexOption.IGNORE_CASE),"Joel 3:")
        mapOf("A" to 1,"B" to 3,"C" to 4,"D" to 5,"E" to 8,"F" to 10).forEach { (letter,chapter) -> text=text.replace(Regex("^Esther $letter:",RegexOption.IGNORE_CASE),"Esther $chapter:") }
        text.replace(Regex("^(Philemon|Jude|2 John|3 John) ([0-9]+)(?![0-9:])",RegexOption.IGNORE_CASE),"$1 1:$2")
    }
    val books=remember(repo) { repo.books("web-ce") }
    val match=Regex("^(.+?)\\s+(\\d+)(?::|$)").find(normalized)
    val aliases=mapOf("psalm" to "PSA","psalms" to "PSA","song of songs" to "SNG","song of solomon" to "SNG","canticle of canticles" to "SNG","ecclesiasticus" to "SIR","sirach" to "SIR","wisdom" to "WIS","revelation" to "REV","apocalypse" to "REV")
    val name=match?.groupValues?.get(1).orEmpty()
    val chapter=match?.groupValues?.get(2)?.toIntOrNull() ?: 0
    val book=books.firstOrNull { it.name.equals(name,true) || it.longName.equals(name,true) || it.code.equals(name,true) || it.code==aliases[name.lowercase()] }
    val verses=remember(reference) { if(book!=null && chapter in 1..book.chapters) repo.chapter("web-ce",book.code,chapter) else emptyList() }
    JohnPage(reference,"SCRIPTURE IN CONTEXT",back=back) {
        JohnText("The original citation is shown above. Read the complete chapter in the offline World English Bible, Catholic Edition. Wording and verse divisions can differ from those proclaimed at Mass.",dim=true,size=14)
        if(book!=null && verses.isNotEmpty()) {
            JohnText("${book.name} $chapter",size=20)
            JohnButton("Open in the Bible reader") { navigate("reader/web-ce/${book.code}/$chapter") }
            SelectionContainer { Column(verticalArrangement=Arrangement.spacedBy(16.dp)) { verses.forEach { JohnText("${it.label}  ${it.text}",serif=true,size=20) } } }
            JohnButton("Pray with this passage") { navigate("lectio/${encoded("${book.name} $chapter\n${verses.joinToString(" ") { it.text }}")}") }
        } else {
            JohnText("This citation could not be matched to an offline chapter. Search for the passage in the Bible reader.",dim=true)
            JohnButton("Open the Bible") { navigate("read") }
        }
    }
}

@Composable
private fun CommentaryScreen(bookCode:String,chapter:Int,repo:JohnRepository,navigate:(String)->Unit,back:()->Unit) {
    val entries=remember(bookCode,chapter) { repo.commentary(bookCode,chapter) }
    val authors=remember(repo) { repo.workAuthors() }
    val book=remember(bookCode) { repo.books("web-ce").firstOrNull { it.code==bookCode } }
    val groups=entries.groupBy { it.str("collectionID").ifBlank { it.str("collectionId") } }
    JohnPage("${book?.name ?: bookCode} $chapter","THE FATHERS ON","${entries.size} readings · ${groups.size} authors",back,sansTitle=true) {
        if(entries.isEmpty()) JohnText("No readings on this chapter",dim=true)
        groups.forEach { (collection,items) ->
            JohnText(authors.firstOrNull { it.id==collection }?.author.orEmpty(),dim=true)
            items.forEach { item -> JohnRow(item.str("sectionTitle"),item.str("workTitle")) { navigate("work/${item.str("workID").ifBlank { item.str("workId") }}/${item.optInt("sectionIndex")}") } }
        }
    }
}

@Composable
private fun RosaryMedia(initial:String?,catalog:JSONObject,back:()->Unit) {
    val rosary=catalog.optJSONObject("rosary") ?: JSONObject()
    val episodes=rosary.array("mediaEpisodes")
    var selected by rememberSaveable(initial) { mutableStateOf(initial ?: episodes.firstOrNull()?.str("id").orEmpty()) }
    var mode by rememberSaveable { mutableStateOf("video") }
    val episode=episodes.firstOrNull { it.str("id")==selected } ?: episodes.firstOrNull()
    val uri=LocalUriHandler.current
    var feedback by remember { mutableStateOf("") }
    if(episode==null) { JohnPage("Media is not available",back=back) { JohnText("The Rosary media list could not be opened.") };return }
    val approved=rosary.array("mediaApproved").any { it.str("id")==episode.str("id") && it.optBoolean("approved") }
    val video=episode.str("videoUri").takeIf { approved && it.isNotBlank() }
    val audio=episode.str("audioUri").takeIf { approved && it.isNotBlank() }
    fun open(address:String) { runCatching { uri.openUri(address) }.onFailure { feedback="The official site could not be opened. Please try again when connected." } }
    JohnPage(episode.str("title"),"WORD ON FIRE SERIES",episode.str("subtitle"),back,sansTitle=true) {
        if(video!=null || audio!=null) {
            Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                if(video!=null) TextButton(onClick={mode="video"}) { Text("Watch video") }
                if(audio!=null) TextButton(onClick={mode="audio"}) { Text("Listen to audio") }
            }
            if(mode=="video" && video!=null) ApprovedVideo(video)
            else if(audio!=null) ApprovedAudio(audio,episode.str("title"))
            else if(video!=null) ApprovedVideo(video)
        }
        if(com.john.bible.BuildConfig.DEBUG && !approved) JohnPanel {
            JohnText("PERMISSION PENDING",size=11)
            JohnText("The player is prepared for approved direct media URLs. Word on Fire’s standard permission page says archived on-demand audio and video require permission, so its files are not bundled here yet.",dim=true,size=14)
            JohnRow("Official Rosary page") { open("https://www.wordonfire.org/rosary/") }
            JohnRow("Content permission form") { open("https://www.wordonfire.org/contact/content-request/") }
        }
        JohnText("All episodes",size=20)
        episodes.forEachIndexed { index,item ->
            val colors=LocalJohnColors.current
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(colors.card).border(1.dp,if(item.str("id")==selected) colors.tint else colors.card,RoundedCornerShape(16.dp)).clickable { selected=item.str("id");feedback="" }.padding(12.dp),horizontalArrangement=Arrangement.spacedBy(12.dp),verticalAlignment=Alignment.CenterVertically) {
                Box(Modifier.size(38.dp).clip(CircleShape).background(if(item.str("id")==selected) colors.tint else colors.background),contentAlignment=Alignment.Center) { Text("%02d".format(index+1),fontFamily=SpaceGrotesk,fontSize=12.sp,color=if(item.str("id")==selected) colors.card else colors.text) }
                Column(Modifier.weight(1f)) { JohnText(item.str("title"),size=14);JohnText(item.str("subtitle"),size=12,dim=true) }
                JohnText("›",size=20)
            }
        }
        JohnButton("Watch on the official site") { open(episode.str("officialUrl")) }
        if(feedback.isNotBlank()) JohnText(feedback,dim=true)
    }
}

@Composable
private fun ApprovedVideo(address:String) {
    val context=LocalContext.current
    val owner=LocalLifecycleOwner.current
    val video=remember(address) { android.widget.VideoView(context).apply { setVideoURI(android.net.Uri.parse(address));setMediaController(android.widget.MediaController(context).also { it.setAnchorView(this) }) } }
    DisposableEffect(video,owner) {
        val observer=LifecycleEventObserver { _,event -> if(event==Lifecycle.Event.ON_STOP) video.pause() }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer);video.stopPlayback() }
    }
    key(address) { androidx.compose.ui.viewinterop.AndroidView(factory={video},modifier=Modifier.fillMaxWidth().aspectRatio(16/9f).clip(RoundedCornerShape(20.dp))) }
}

@Composable
private fun ApprovedAudio(address:String,title:String) {
    var ready by remember(address) { mutableStateOf(false) }
    var playing by remember(address) { mutableStateOf(false) }
    var failed by remember(address) { mutableStateOf(false) }
    var time by remember(address) { mutableIntStateOf(0) }
    var duration by remember(address) { mutableIntStateOf(0) }
    val owner=LocalLifecycleOwner.current
    val player=remember(address) { android.media.MediaPlayer() }
    DisposableEffect(player,owner) {
        player.setOnPreparedListener { ready=true;duration=it.duration }
        player.setOnCompletionListener { playing=false }
        player.setOnErrorListener { _,_,_ -> failed=true;playing=false;true }
        runCatching { player.setDataSource(address);player.prepareAsync() }.onFailure { failed=true }
        val observer=LifecycleEventObserver { _,event -> if(event==Lifecycle.Event.ON_STOP && ready) { player.pause();playing=false } }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer);player.release() }
    }
    LaunchedEffect(playing) { while(playing) { time=runCatching { player.currentPosition }.getOrDefault(0);delay(500) } }
    fun clock(ms:Int)="${ms/60000}:${"%02d".format(ms/1000%60)}"
    JohnPanel {
        JohnText("✢",size=48)
        JohnText(title,size=20)
        JohnText("Bishop Robert Barron",size=14,dim=true)
        Slider(value=if(duration>0) time.toFloat()/duration else 0f,onValueChange={if(ready) { time=(it*duration).toInt();player.seekTo(time) }},enabled=ready)
        JohnText("${clock(time)} / ${clock(duration)}",size=12,dim=true)
        JohnButton(if(failed) "Audio unavailable" else if(!ready) "Loading audio…" else if(playing) "Pause audio" else "Play audio") { if(ready && !failed) { if(playing) player.pause() else player.start();playing=!playing } }
    }
}
