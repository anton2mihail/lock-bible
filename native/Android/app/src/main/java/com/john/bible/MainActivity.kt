package com.john.bible

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.john.bible.data.JohnRepository
import com.john.bible.data.JohnStore
import com.john.bible.platform.*
import com.john.bible.ui.*

class MainActivity : ComponentActivity() {
    private var incoming by mutableStateOf<String?>(null)
    override fun onCreate(savedInstanceState:Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        if(savedInstanceState==null) receiveExternalUrl(intent.dataString)
        // Debug builds only: -e johnFathersAccess locked|purchased|grandfathered fixes the library state for checks.
        if(BuildConfig.DEBUG) FathersBilling.get(applicationContext).force(intent.getStringExtra("johnFathersAccess"))
        if(BuildConfig.DEBUG) com.john.bible.data.FeatureClock.date=intent.getStringExtra("johnFeatureDate")?.let { runCatching { java.time.LocalDate.parse(it) }.getOrNull() }
        FathersBilling.get(applicationContext).start()
        ReviewPrompt.recordOpen(applicationContext)
        setContent {
            val store=remember { JohnStore(applicationContext) }
            val repo=remember { JohnRepository(applicationContext) }
            DisposableEffect(repo) { onDispose { repo.close() } }
            val speech=remember { ReaderSpeech.get(applicationContext,store) }
            LaunchedEffect(speech.active) { if(speech.active) JohnPlaybackService.start(applicationContext) }
            JohnTheme(store.appearance) {
                val colors=LocalJohnColors.current
                SideEffect { androidx.core.view.WindowCompat.getInsetsController(window,window.decorView).isAppearanceLightStatusBars=colors==JohnLight }
                LaunchedEffect(store.edition,store.scope,store.intervalMinutes,store.completedChapters) { JohnVerseWidget.refreshAll(applicationContext) }
                JohnShell(repo,store,incoming) { incoming=null }
            }
        }
        JohnReminders.scheduleAll(applicationContext)
    }
    override fun onDestroy() {
        if(isFinishing && ReaderSpeech.current()?.active!=true) ReaderSpeech.closeAll()
        super.onDestroy()
    }
    override fun onNewIntent(intent:Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiveExternalUrl(intent.dataString)
    }
    internal fun receiveExternalUrl(url:String?) { incoming=externalRoute(url,getSharedPreferences("john",MODE_PRIVATE).getString("edition","web-ce") ?: "web-ce") }
}
private data class JohnTab(val title:String,val icon:ImageVector)
private val tabs=listOf(JohnTab("Today",Icons.Outlined.WbSunny),JohnTab("Read",Icons.AutoMirrored.Outlined.MenuBook),JohnTab("Saved",Icons.Outlined.BookmarkBorder),JohnTab("Pray",Icons.Outlined.FavoriteBorder),JohnTab("Settings",Icons.Outlined.Settings))

@Composable private fun JohnShell(repo:JohnRepository,store:JohnStore,incoming:String?,consume:()->Unit) {
    var selected by rememberSaveable { mutableIntStateOf(0) }
    // Keep a distinct destination stack for each tab, as in AppRouter.swift.
    var paths by rememberSaveable { mutableStateOf(List(5) { emptyList<String>() }) }
    val savedScreens=rememberSaveableStateHolder()
    val path=paths[selected]
    val route=path.lastOrNull()
    val back:()->Unit={ paths=paths.mapIndexed { i,p -> if(i==selected)p.dropLast(1) else p } }
    val navigate:(String)->Unit={ next ->
        if(next=="back") { paths=paths.mapIndexed { i,p -> if(i==selected)p.dropLast(1) else p } }
        else if(next=="read" || next=="bible") { selected=1; paths=paths.mapIndexed { i,p -> if(i==1)emptyList() else p } }
        else paths=paths.mapIndexed { i,p -> if(i==selected)p+next else p }
    }
    LaunchedEffect(incoming) {
        incoming?.let {
            when(it) {
                "saved" -> { selected=2;paths=paths.mapIndexed { index,p -> if(index==2)emptyList() else p } }
                "read" -> { selected=1;paths=paths.mapIndexed { index,p -> if(index==1)emptyList() else p } }
                else -> { selected=when { it.startsWith("reader/")->1;it.startsWith("rosary") || it.startsWith("lectio") || it=="stations"->3;else->0 }; paths=paths.mapIndexed { i,p -> if(i==selected)listOf(it) else p } }
            }
            consume()
        }
    }
    BackHandler(path.isNotEmpty(),onBack=back)
    val c=LocalJohnColors.current
    // The paged reader fills the screen, as in Play Books. Back returns to the tabs.
    val readerChrome=remember { ReaderChrome() }
    val immersive=readerChrome.immersive
    CompositionLocalProvider(LocalReaderChrome provides readerChrome) {
    BoxWithConstraints(Modifier.fillMaxSize().background(c.background).windowInsetsPadding(WindowInsets.safeDrawing)) {
        val wide=maxWidth>=840.dp
        Row(Modifier.fillMaxSize()) {
            if(wide && !immersive) NavigationRail(containerColor=c.card) {
                Spacer(Modifier.height(20.dp))
                tabs.forEachIndexed { index,tab -> NavigationRailItem(selected=selected==index,onClick={if(index==selected)backToRoot(index,paths) { paths=it } else selected=index},icon={Icon(tab.icon,tab.title)},label={Text(tab.title,fontFamily=SpaceGrotesk)}) }
            }
            Column(Modifier.weight(1f)) {
                if(route==null && selected!=1) Row(Modifier.fillMaxWidth().height(48.dp).padding(horizontal=16.dp),horizontalArrangement=Arrangement.End,verticalAlignment=Alignment.CenterVertically) {
                    IconButton(onClick={navigate("search")}) { Icon(Icons.Outlined.Search,"Search Scripture",tint=c.tint) }
                }
                Box(Modifier.weight(1f)) {
                    savedScreens.SaveableStateProvider("tab:$selected:${path.joinToString("|")}") {
                    if(route!=null) {
                        when {
                            route=="search" -> SearchScreen(repo,store,navigate,back)
                            route=="progress" || route=="reading-progress" -> ReadingProgressScreen(store,navigate,back)
                            route in listOf("calendar-notifications","rosary-reminder","reading-reminder","year-reminder") -> ReminderScreen(route,back)
                            route.startsWith("reader/") -> ReaderScreen(repo,store,navigate,initialRoute=route)
                            route.startsWith("share-card/") -> ScriptureCardScreen(route,repo,store,back)
                            route=="verse" -> VerseScreen(repo,store,navigate,back)
                            route=="widget-help" -> WidgetHelpScreen(back)
                            else -> DevotionalScreen(route,repo,store,navigate,back)
                        }
                    } else when(selected) {
                        0 -> TodayScreen(repo,store,navigate)
                        1 -> ReaderScreen(repo,store,navigate)
                        2 -> SavedScreen(repo,store,navigate)
                        3 -> PrayScreen(repo,store,navigate)
                        4 -> SettingsScreen(repo,store,navigate)
                    }
                    }
                }
                ReadAloudMiniPlayer(store,navigate)
                if(!wide && !immersive) NavigationBar(containerColor=c.card,tonalElevation=0.dp,windowInsets=WindowInsets(0,0,0,0)) {
                    tabs.forEachIndexed { index,tab ->
                        NavigationBarItem(selected=selected==index,onClick={ if(index==selected)backToRoot(index,paths) {paths=it} else selected=index },icon={Icon(tab.icon,tab.title)},label={Text(tab.title,fontFamily=SpaceGrotesk,fontSize=11.sp)},colors=NavigationBarItemDefaults.colors(selectedIconColor=c.tint,selectedTextColor=c.tint,indicatorColor=c.background,unselectedIconColor=c.textDim,unselectedTextColor=c.textDim))
                    }
                }
            }
        }
    }
    }
}
private fun backToRoot(index:Int,paths:List<List<String>>,set:(List<List<String>>)->Unit) { set(paths.mapIndexed { i,p -> if(i==index)emptyList() else p }) }
