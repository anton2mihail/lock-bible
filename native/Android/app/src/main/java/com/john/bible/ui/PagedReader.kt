package com.john.bible.ui

import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PagerState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.outlined.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.outlined.VolumeUp
import androidx.compose.material.icons.outlined.FormatSize
import androidx.compose.material.icons.outlined.MoreVert
import androidx.compose.material.icons.outlined.Pause
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFontFamilyResolver
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.onLongClick
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.intl.LocaleList
import androidx.compose.ui.text.style.*
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import com.john.bible.data.BibleBook
import com.john.bible.data.JohnRepository
import com.john.bible.data.JohnStore
import com.john.bible.data.SearchHit
import com.john.bible.data.Verse
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** The app shell hides its tab bar while the paged reader shows a chapter. */
class ReaderChrome { var immersive by mutableStateOf(false) }
val LocalReaderChrome = staticCompositionLocalOf { ReaderChrome() }

internal data class ChapterKey(val edition: String, val book: String, val chapter: Int)

/** All values that change line breaks. Sizes are pixels. */
internal data class PageConfig(
    val width: Int, val height: Int, val textSize: Float, val lineSpacing: Float, val serif: Boolean,
    val verseNumbers: Boolean, val paragraphs: Boolean, val dark: Boolean, val density: Float, val fontScale: Float, val headingSpace: Int
)

internal class VerseFragment(val verse: Int, val start: Int, val end: Int, val continued: Boolean, val bounds: Rect)

/** One chapter, measured once and cut into pages. Each page draws a clipped part of the same text layout. */
internal class PagedChapter(
    val key: ChapterKey, val bookName: String, val verses: List<Verse>, val layout: TextLayoutResult, val pages: List<PageSlice>,
    val verseStarts: IntArray, val verseEnds: IntArray, val ornamentY: Float, val config: PageConfig
) {
    private val labels = verses.map { it.label }
    private val pageStarts = IntArray(pages.size) { pages[it].startOffset }
    val text: String get() = layout.layoutInput.text.text
    fun verseAt(offset: Int): Int = PageMath.lastAtOrBefore(verseStarts, offset).takeIf { it >= 0 && offset <= verseEnds[it] } ?: -1
    fun pageForVerse(index: Int) = PageMath.pageForOffset(pageStarts, verseStarts[index])
    fun pageFor(anchor: PageAnchor) = PageMath.pageForAnchor(anchor, labels, verseStarts, verseEnds, pageStarts)
    fun anchorFor(page: Int) = PageMath.anchorForPage(page, labels, verseStarts, pageStarts)
    fun fragments(page: Int): List<VerseFragment> {
        val slice = pages[page]
        val result = mutableListOf<VerseFragment>()
        var verse = PageMath.lastAtOrBefore(verseStarts, slice.startOffset).coerceAtLeast(0)
        while (verse < verses.size && verseStarts[verse] < slice.endOffset) {
            val start = max(verseStarts[verse], slice.startOffset)
            val end = min(verseEnds[verse], slice.endOffset)
            if (start < end) {
                val first = layout.getLineForOffset(start)
                val last = layout.getLineForOffset(end - 1)
                val left = if (first == last) layout.getHorizontalPosition(start, true) else 0f
                val right = if (first == last) lineRight(first, end) else config.width.toFloat()
                result += VerseFragment(verse, start, end, verseStarts[verse] < slice.startOffset,
                    Rect(left, layout.getLineTop(first) - slice.top, max(right, left + 1f), layout.getLineBottom(last) - slice.top))
            }
            verse++
        }
        return result
    }
    fun lineRight(line: Int, end: Int): Float = if (end >= layout.getLineEnd(line, visibleEnd = true)) layout.getLineRight(line) else layout.getHorizontalPosition(end, true)
}

/** Measures chapters off the main thread and keeps the last few results. */
internal class ChapterPaginator(private val repo: JohnRepository, private val measurer: TextMeasurer) {
    private val cache = object : LinkedHashMap<Pair<ChapterKey, PageConfig>, PagedChapter>(8, .75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<Pair<ChapterKey, PageConfig>, PagedChapter>?) = size > 7
    }
    private val lock = Mutex()
    fun cached(key: ChapterKey, config: PageConfig): PagedChapter? = synchronized(cache) { cache[key to config] }
    suspend fun paginate(key: ChapterKey, bookName: String, config: PageConfig, colors: JohnColors): PagedChapter {
        cached(key, config)?.let { return it }
        val verses = withContext(Dispatchers.IO) { repo.chapter(key.edition, key.book, key.chapter) }
        return lock.withLock {
            cached(key, config) ?: withContext(Dispatchers.Default) { measure(key, bookName, verses, config, colors) }
                .also { synchronized(cache) { cache[key to config] = it } }
        }
    }

    private fun measure(key: ChapterKey, bookName: String, verses: List<Verse>, config: PageConfig, colors: JohnColors): PagedChapter {
        val body = config.textSize
        val starts = IntArray(verses.size)
        val ends = IntArray(verses.size)
        fun pixelsToSp(pixels: Float): TextUnit = (pixels / (config.density * config.fontScale)).sp
        val family = if (config.serif) Lora else SpaceGrotesk
        var ornamentOffset = 0
        val plain = ParagraphStyle(textAlign = TextAlign.Center, textIndent = TextIndent.None, hyphens = Hyphens.None)
        val text = buildAnnotatedString {
            fun spacer(height: TextUnit) {
                withStyle(plain.copy(lineHeight = height)) { withStyle(SpanStyle(fontSize = 1.sp)) { append('​') } }
            }
            spacer(pixelsToSp(config.headingSpace.toFloat()))
            withStyle(plain.copy(lineHeight = 26.sp)) {
                withStyle(SpanStyle(fontFamily = SpaceGrotesk, fontWeight = FontWeight.Medium, fontSize = 12.sp, letterSpacing = 2.6.sp, color = colors.tint)) { append(bookName.uppercase()) }
            }
            val headingSize = max(30f, body * 1.75f)
            withStyle(plain.copy(lineHeight = (headingSize * 1.3f).sp)) {
                withStyle(SpanStyle(fontFamily = Lora, fontSize = headingSize.sp, letterSpacing = (-.3).sp, color = colors.text)) {
                    append(if (key.book == "PSA") "Psalm ${key.chapter}" else "Chapter ${key.chapter}")
                }
            }
            ornamentOffset = length
            spacer((body * 2.6f).sp)
            val groups = if (config.paragraphs) {
                val first = verses.indices.filter { it == 0 || verses[it].paragraphStart }
                first.mapIndexed { i, start -> start until (first.getOrNull(i + 1) ?: verses.size) }
            } else verses.indices.map { it..it }
            val number = SpanStyle(fontFamily = family, fontWeight = FontWeight.Medium, fontSize = .58.em, baselineShift = BaselineShift(.55f), color = colors.tint)
            groups.forEachIndexed { group, range ->
                if (!config.paragraphs && group > 0) spacer((body * config.lineSpacing * .35f).sp)
                val indent = if (config.paragraphs && group > 0) TextIndent(firstLine = 1.5.em) else TextIndent.None
                withStyle(ParagraphStyle(textIndent = indent)) {
                    range.forEach { index ->
                        if (index != range.first) append(' ')
                        starts[index] = length
                        if (config.verseNumbers) withStyle(number) { append(verses[index].label); append(' ') }
                        append(verses[index].text)
                        ends[index] = length
                    }
                }
            }
        }
        val style = TextStyle(
            color = colors.text, fontFamily = family, fontSize = body.sp, lineHeight = (body * config.lineSpacing).sp,
            textAlign = TextAlign.Justify, hyphens = Hyphens.Auto, lineBreak = LineBreak.Paragraph,
            lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.None),
            localeList = if (key.edition == "vulgate") LocaleList("la") else null
        )
        val layout = measurer.measure(text, style, constraints = Constraints.fixedWidth(config.width), skipCache = true)
        val count = layout.lineCount
        val tops = FloatArray(count) { layout.getLineTop(it) }
        val bottoms = FloatArray(count) { layout.getLineBottom(it) }
        val spacer = BooleanArray(count) { text.text.getOrNull(layout.getLineStart(it)) == '​' }
        val pages = PageMath.pageLines(tops, bottoms, spacer, config.height.toFloat()).map { lines ->
            PageSlice(lines.first, lines.last + 1, tops[lines.first], bottoms[lines.last], layout.getLineStart(lines.first), layout.getLineEnd(lines.last))
        }.ifEmpty { listOf(PageSlice(0, 0, 0f, 0f, 0, 0)) }
        val ornamentLine = layout.getLineForOffset(ornamentOffset)
        return PagedChapter(key, bookName, verses, layout, pages, starts, ends, (tops[ornamentLine] + bottoms[ornamentLine]) / 2f, config)
    }
}

private class PagerItem(val chapter: PagedChapter?, val pages: List<Int>, val role: Int)
private class PageGeometry(val columns: Int, val columnWidth: Int, val margin: Int, val top: Int, val textWidth: Int, val textHeight: Int)
private val AnchorSaver = Saver<MutableState<PageAnchor>, String>({ it.value.encode() }, { mutableStateOf(PageAnchor.decode(it)) })

internal class PagedChrome(
    val title: String, val subtitle: String, val back: () -> Unit, val search: () -> Unit, val goTo: () -> Unit,
    val appearance: () -> Unit, val fathers: () -> Unit, val reading: Boolean, val readAloud: (Int) -> Unit,
    val isRead: Boolean, val toggleRead: () -> Unit, val message: String
)

@Composable private fun pagedChapter(paginator: ChapterPaginator, key: ChapterKey?, name: String, config: PageConfig, colors: JohnColors): Result<PagedChapter>? {
    var loaded by remember { mutableStateOf<Pair<Pair<ChapterKey, PageConfig>, Result<PagedChapter>>?>(null) }
    LaunchedEffect(paginator, key, config) {
        if (key != null && paginator.cached(key, config) == null) {
            val result = try { Result.success(paginator.paginate(key, name, config, colors)) } catch (cancel: CancellationException) { throw cancel } catch (error: Exception) { Result.failure(error) }
            loaded = (key to config) to result
        }
    }
    if (key == null) return null
    return paginator.cached(key, config)?.let { Result.success(it) } ?: loaded?.takeIf { it.first == key to config }?.second
}

/**
 * Pages mode, as in Google Play Books. Each chapter is measured for the current page size and text settings.
 * The pager also holds one page of the previous and next chapter, so a swipe continues across chapters and books.
 */
@Composable internal fun PagedReader(
    repo: JohnRepository, store: JohnStore, edition: String, books: List<BibleBook>, bookCode: String, chapter: Int,
    initialAnchor: () -> PageAnchor, lower: Int, upper: Int, spoken: Int?, selecting: Boolean,
    tapVerse: (Int) -> Unit, holdVerse: (Int) -> Unit, clearSelection: () -> Unit,
    openChapter: (String, Int) -> Unit, savePosition: (ChapterKey, PageAnchor) -> Unit, markRead: (ChapterKey) -> Unit,
    chrome: PagedChrome, selectionBar: (@Composable () -> Unit)?
) {
    val colors = LocalJohnColors.current
    val density = LocalDensity.current
    val resolver = LocalFontFamilyResolver.current
    val direction = LocalLayoutDirection.current
    val readerChrome = LocalReaderChrome.current
    DisposableEffect(readerChrome) { readerChrome.immersive = true; onDispose { readerChrome.immersive = false } }
    val paginator = remember(repo, resolver, density, direction) { ChapterPaginator(repo, TextMeasurer(resolver, density, direction, 0)) }
    var landing by remember { mutableStateOf<Triple<String, Int, PageAnchor>?>(null) }
    var anchor by rememberSaveable(bookCode, chapter, saver = AnchorSaver) {
        mutableStateOf(landing?.takeIf { it.first == bookCode && it.second == chapter }?.third ?: initialAnchor())
    }
    var barsVisible by rememberSaveable { mutableStateOf(true) }
    val bookList = remember(books) { books.map { it.code to it.chapters } }
    val book = books.firstOrNull { it.code == bookCode }
    val previous = remember(bookList, bookCode, chapter) { PageMath.adjacentChapter(bookList, bookCode, chapter, -1) }
    val following = remember(bookList, bookCode, chapter) { PageMath.adjacentChapter(bookList, bookCode, chapter, 1) }
    val open: (Pair<String, Int>, PageAnchor) -> Unit = { target, at -> landing = Triple(target.first, target.second, at); openChapter(target.first, target.second) }
    val lastShown = remember { arrayOfNulls<PagedChapter>(1) }
    val scope = rememberCoroutineScope()

    BoxWithConstraints(Modifier.fillMaxSize().background(colors.background).testTag("paged-reader")) {
        val ready = readerChrome.immersive && book != null
        val columns = if (maxWidth >= 840.dp && maxWidth > maxHeight) 2 else 1
        val geometry = with(density) {
            val columnWidth = constraints.maxWidth / columns
            val margin = max(28.dp.roundToPx(), (columnWidth - 620.dp.roundToPx()) / 2)
            val top = 52.dp.roundToPx()
            PageGeometry(columns, columnWidth, margin, top, columnWidth - 2 * margin, (constraints.maxHeight - 2 * top).coerceAtLeast(1))
        }
        val config = PageConfig(geometry.textWidth.coerceAtLeast(1), geometry.textHeight, store.textSize, store.lineSpacing, store.fontFamily == "serif",
            store.showVerseNumbers, store.readerLayout == "paragraphs", colors == JohnDark, density.density, density.fontScale, (geometry.textHeight * .07f).toInt())
        val currentKey = ChapterKey(edition, bookCode, chapter)
        val current = pagedChapter(paginator, currentKey.takeIf { ready }, book?.name ?: bookCode, config, colors)
        current?.getOrNull()?.let { lastShown[0] = it }
        val shown = current?.getOrNull() ?: lastShown[0]?.takeIf { it.key == currentKey }
        val previousKey = previous?.let { ChapterKey(edition, it.first, it.second) }
        val followingKey = following?.let { ChapterKey(edition, it.first, it.second) }
        val previousPaged = pagedChapter(paginator, previousKey.takeIf { shown != null }, books.firstOrNull { it.code == previous?.first }?.name ?: "", config, colors)?.getOrNull()?.takeIf { it.config == shown?.config }
        val followingPaged = pagedChapter(paginator, followingKey.takeIf { shown != null }, books.firstOrNull { it.code == following?.first }?.name ?: "", config, colors)?.getOrNull()?.takeIf { it.config == shown?.config }

        if (shown == null) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                if (ready) Text(if (current?.isFailure == true) "This chapter could not be opened. Please try again." else "Opening chapter…",
                    fontFamily = SpaceGrotesk, fontSize = 14.sp, color = colors.textDim)
            }
            PagedTopBar(chrome) { 0 }
        } else key(shown.key, shown.config) {
            // The list must keep its identity between compositions. A new list in each pass changes the state below and starts the next pass.
            val items = remember(shown, columns, previous, following, previousPaged, followingPaged) {
                buildList {
                    if (previous != null) add(PagerItem(previousPaged, previousPaged?.let { it.pages.indices.chunked(columns).last() } ?: emptyList(), -1))
                    shown.pages.indices.chunked(columns).forEach { add(PagerItem(shown, it, 0)) }
                    if (following != null) add(PagerItem(followingPaged, followingPaged?.let { (0 until min(columns, it.pages.size)).toList() } ?: emptyList(), 1))
                }
            }
            val itemsState = rememberUpdatedState(items)
            val offset = if (previous != null) 1 else 0
            val pagerState = remember { PagerState(currentPage = offset + shown.pageFor(anchor) / columns) { itemsState.value.size } }
            val turn: (Int) -> Unit = { step -> scope.launch { pagerState.animateScrollToPage((pagerState.currentPage + step).coerceIn(0, itemsState.value.size - 1)) } }
            val actions = rememberUpdatedState(Triple(savePosition, markRead, open))
            LaunchedEffect(pagerState) {
                var first = true
                snapshotFlow { pagerState.settledPage }.collect { index ->
                    val item = itemsState.value.getOrNull(index) ?: return@collect
                    val (save, read, go) = actions.value
                    when (item.role) {
                        1 -> following?.let { read(shown.key); go(it, PageAnchor.First) }
                        -1 -> previous?.let { go(it, PageAnchor.Last) }
                        else -> {
                            anchor = shown.anchorFor(item.pages.first())
                            save(shown.key, anchor)
                            if (item.pages.last() == shown.pages.lastIndex && shown.pages.size > columns) read(shown.key)
                            if (!first) barsVisible = false
                        }
                    }
                    first = false
                }
            }
            LaunchedEffect(spoken, pagerState) {
                val verse = spoken ?: return@LaunchedEffect
                if (verse !in shown.verses.indices) return@LaunchedEffect
                val target = offset + shown.pageForVerse(verse) / columns
                if (target != pagerState.currentPage) pagerState.animateScrollToPage(target)
            }
            val haptic = LocalHapticFeedback.current
            val selectingState = rememberUpdatedState(selecting)
            fun hit(item: PagerItem, position: Offset): Int {
                val paged = item.chapter?.takeIf { item.role == 0 } ?: return -1
                val column = (position.x / geometry.columnWidth).toInt().coerceIn(0, columns - 1)
                val page = item.pages.getOrNull(column) ?: return -1
                val slice = paged.pages[page]
                val x = position.x - column * geometry.columnWidth - geometry.margin
                val y = position.y - geometry.top
                if (y < 0 || y > slice.bottom - slice.top || x < -geometry.margin / 2f || x > geometry.textWidth + geometry.margin / 2f) return -1
                val at = paged.layout.getOffsetForPosition(Offset(x.coerceIn(0f, geometry.textWidth.toFloat()), y + slice.top))
                if (at < slice.startOffset || at > slice.endOffset) return -1
                return paged.verseAt(at)
            }
            HorizontalPager(pagerState, Modifier.fillMaxSize().testTag("reader-pager"), beyondViewportPageCount = 1) { index ->
                val item = items[index]
                PageSpread(item, geometry, store, lower, upper, spoken, turn, tapVerse, holdVerse, { pagerState.currentPageOffsetFraction != 0f },
                    Modifier.pointerInput(item) {
                        detectTapGestures(
                            onTap = { position ->
                                if (selectingState.value) { val verse = hit(item, position); if (verse >= 0) tapVerse(verse) else clearSelection() }
                                else when {
                                    position.x < size.width / 3f -> turn(-1)
                                    position.x > size.width * 2f / 3f -> turn(1)
                                    else -> barsVisible = !barsVisible
                                }
                            },
                            onLongPress = { position ->
                                val verse = hit(item, position)
                                if (verse >= 0) { haptic.performHapticFeedback(HapticFeedbackType.LongPress); holdVerse(verse) }
                            }
                        )
                    })
            }
            val currentItem = items.getOrNull(pagerState.currentPage)
            val page = currentItem?.takeIf { it.role == 0 }?.pages?.first() ?: if (currentItem?.role == 1) shown.pages.lastIndex else 0
            AnimatedVisibility(barsVisible, Modifier.align(Alignment.TopCenter), enter = fadeIn(tween(150)), exit = fadeOut(tween(150))) {
                PagedTopBar(chrome) { shown.anchorFor(page).let { a -> shown.verses.indexOfFirst { it.label == a.label }.coerceAtLeast(0) } }
            }
            Box(Modifier.align(Alignment.BottomCenter).fillMaxWidth()) {
                if (selectionBar != null) Box(Modifier.fillMaxWidth().background(colors.card).padding(horizontal = 16.dp, vertical = 8.dp)) { selectionBar() }
                else AnimatedVisibility(barsVisible, enter = fadeIn(tween(150)), exit = fadeOut(tween(150))) {
                    PagedBottomBar(page, shown.pages.size, chrome.message,
                        scrub = { target -> scope.launch { pagerState.scrollToPage(offset + target / columns) } },
                        previousChapter = previous?.let { { open(it, PageAnchor.First) } },
                        nextChapter = following?.let { { open(it, PageAnchor.First) } })
                }
            }
        }
    }
}

@Composable private fun PageSpread(
    item: PagerItem, geometry: PageGeometry, store: JohnStore, lower: Int, upper: Int, spoken: Int?,
    turn: (Int) -> Unit, tapVerse: (Int) -> Unit, holdVerse: (Int) -> Unit, sliding: () -> Boolean, modifier: Modifier
) {
    val colors = LocalJohnColors.current
    val density = LocalDensity.current
    val shadow = with(density) { 14.dp.toPx() }
    // The shadow lies outside the page. It shows only while a page slides over the one before it.
    Box(modifier.fillMaxSize().drawBehind {
        if (sliding()) drawRect(Brush.horizontalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = if (colors == JohnDark) .35f else .12f)), startX = -shadow, endX = 0f), Offset(-shadow, 0f), Size(shadow, size.height))
    }.background(colors.background)) {
        Row(Modifier.fillMaxSize()) {
            repeat(geometry.columns) { column ->
                Box(Modifier.weight(1f).fillMaxHeight()) {
                    val chapter = item.chapter
                    val page = item.pages.getOrNull(column)
                    if (chapter != null && page != null) PageColumn(chapter, page, geometry, store, lower.takeIf { item.role == 0 } ?: -1, upper, spoken.takeIf { item.role == 0 },
                        footerStart = column == 0, footerEnd = column == geometry.columns - 1, turn, tapVerse, holdVerse)
                }
            }
        }
        if (geometry.columns == 2) Box(Modifier.align(Alignment.Center).fillMaxHeight(.86f).width(1.dp).background(colors.separator))
    }
}

private class VerseMark(val fragment: VerseFragment, val hit: SearchHit, val color: Color, val bookmarked: Boolean, val note: Boolean, val selected: Boolean)

@Composable private fun PageColumn(
    chapter: PagedChapter, page: Int, geometry: PageGeometry, store: JohnStore, lower: Int, upper: Int, spoken: Int?,
    footerStart: Boolean, footerEnd: Boolean, turn: (Int) -> Unit, tapVerse: (Int) -> Unit, holdVerse: (Int) -> Unit
) {
    val colors = LocalJohnColors.current
    val density = LocalDensity.current
    val slice = chapter.pages[page]
    val fragments = remember(chapter, page) { chapter.fragments(page) }
    val marks = fragments.map { fragment ->
        val verse = chapter.verses[fragment.verse]
        val hit = SearchHit(chapter.key.edition, chapter.key.book, chapter.bookName, chapter.key.chapter, verse.label, verse.text)
        val selected = lower >= 0 && fragment.verse in lower..upper
        val highlight = store.highlightColor(hit)
        val color = when {
            selected -> colors.tint.copy(alpha = .22f)
            spoken == fragment.verse -> colors.tint.copy(alpha = .13f)
            highlight != null -> highlightColor(highlight).copy(alpha = if (colors == JohnDark) .34f else .3f)
            else -> Color.Transparent
        }
        VerseMark(fragment, hit, color, store.coversVerse("bookmark", hit), store.coversVerse("note", hit), selected)
    }
    val fontPixels = with(density) { chapter.config.textSize.sp.toPx() }
    val textWidth = with(density) { geometry.textWidth.toDp() }
    val textHeight = with(density) { geometry.textHeight.toDp() }
    val margin = with(density) { geometry.margin.toDp() }
    val top = with(density) { geometry.top.toDp() }
    val heading = slice.startOffset == 0
    val pageActions = listOf(CustomAccessibilityAction("Next page") { turn(1); true }, CustomAccessibilityAction("Previous page") { turn(-1); true })
    Box(Modifier.fillMaxSize().testTag("reader-page-${chapter.key.book}-${chapter.key.chapter}-$page")) {
        if (!heading) Text("${chapter.bookName} ${chapter.key.chapter}".uppercase(), Modifier.align(Alignment.TopCenter).padding(top = 20.dp, start = margin, end = margin),
            fontFamily = SpaceGrotesk, fontSize = 10.sp, letterSpacing = 1.8.sp, color = colors.textDim, maxLines = 1)
        Canvas(Modifier.padding(start = margin, top = top).size(textWidth, textHeight)) {
            clipRect(0f, 0f, size.width, size.height) {
                translate(0f, -slice.top) {
                    marks.forEach { mark -> if (mark.color != Color.Transparent) drawVerseBand(chapter, mark.fragment.start, mark.fragment.end, mark.color, fontPixels) }
                    drawText(chapter.layout)
                }
            }
            if (heading) {
                val y = chapter.ornamentY - slice.top
                val half = 18.dp.toPx()
                drawLine(colors.tint.copy(alpha = .55f), Offset(size.width / 2 - half, y), Offset(size.width / 2 + half, y), strokeWidth = 1.dp.toPx())
                drawCircle(colors.tint.copy(alpha = .55f), 2.dp.toPx(), Offset(size.width / 2, y))
            }
            marks.filter { it.note && !it.fragment.continued }.forEach { mark ->
                val line = chapter.layout.getLineForOffset(mark.fragment.start)
                val y = (chapter.layout.getLineTop(line) + chapter.layout.getLineBottom(line)) / 2f - slice.top
                drawCircle(colors.tint, 3.dp.toPx(), Offset(size.width + geometry.margin / 2f, y))
            }
        }
        if (marks.any { it.bookmarked }) Canvas(Modifier.align(Alignment.TopEnd).padding(end = 18.dp).size(16.dp, 30.dp)) {
            drawPath(Path().apply { moveTo(0f, 0f); lineTo(size.width, 0f); lineTo(size.width, size.height); lineTo(size.width / 2, size.height - 6.dp.toPx()); lineTo(0f, size.height); close() }, colors.tint)
        }
        Box(Modifier.padding(start = margin, top = top).size(textWidth, textHeight)) {
            marks.forEach { mark ->
                val fragment = mark.fragment
                val label = mark.hit.label
                val words = chapter.text.substring(fragment.start, fragment.end).let { if (fragment.continued || !chapter.config.verseNumbers) it else it.removePrefix(label + ' ') }
                val description = buildString {
                    append(if (fragment.continued) "Verse $label, continued. " else "Verse $label. ")
                    append(words)
                    if (mark.bookmarked) append(". Bookmarked")
                    if (mark.note) append(". Has a note")
                    if (mark.selected) append(". Selected")
                }
                Box(Modifier.offset { IntOffset(fragment.bounds.left.roundToInt(), fragment.bounds.top.roundToInt()) }
                    .size(with(density) { fragment.bounds.width.toDp() }, with(density) { fragment.bounds.height.toDp() })
                    .testTag("page-verse-${chapter.key.chapter}:$label")
                    .semantics {
                        contentDescription = description
                        selected = mark.selected
                        onClick("Select verse") { tapVerse(fragment.verse); true }
                        onLongClick("Start a new selection") { holdVerse(fragment.verse); true }
                        customActions = pageActions
                    })
            }
        }
        Row(Modifier.align(Alignment.BottomCenter).fillMaxWidth().padding(start = margin, end = margin, bottom = 20.dp).semantics { customActions = pageActions }) {
            if (footerStart) Text("${page + 1} of ${chapter.pages.size}", fontFamily = SpaceGrotesk, fontSize = 11.sp, color = colors.textDim)
            Spacer(Modifier.weight(1f))
            if (footerEnd) Text(PageMath.pagesLeftText(page, chapter.pages.size), fontFamily = SpaceGrotesk, fontSize = 11.sp, color = colors.textDim)
        }
    }
}

/** Draws a highlighter band behind each line of a verse. */
private fun DrawScope.drawVerseBand(chapter: PagedChapter, start: Int, end: Int, color: Color, fontPixels: Float) {
    val layout = chapter.layout
    val pad = 2.dp.toPx()
    for (line in layout.getLineForOffset(start)..layout.getLineForOffset(end - 1)) {
        val from = max(start, layout.getLineStart(line))
        val to = min(end, layout.getLineEnd(line, visibleEnd = true))
        if (to <= from) continue
        val left = layout.getHorizontalPosition(from, true)
        val right = chapter.lineRight(line, end)
        val baseline = layout.getLineBaseline(line)
        drawRoundRect(color, Offset(left - pad, baseline - fontPixels * 1.02f), Size(right - left + 2 * pad, fontPixels * 1.38f), CornerRadius(3.dp.toPx()))
    }
}

@Composable private fun PagedTopBar(chrome: PagedChrome, startVerse: () -> Int) {
    val colors = LocalJohnColors.current
    var menu by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().background(colors.card)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = chrome.back) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, "Back", tint = colors.tint) }
            Column(Modifier.weight(1f).padding(horizontal = 4.dp)) {
                Text(chrome.title, fontFamily = SpaceGrotesk, fontWeight = FontWeight.Medium, fontSize = 17.sp, color = colors.text, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.semantics { heading() })
                Text(chrome.subtitle, fontFamily = SpaceGrotesk, fontSize = 11.sp, color = colors.textDim, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            IconButton(onClick = chrome.search) { Icon(Icons.Outlined.Search, "Search", tint = colors.tint) }
            IconButton(onClick = chrome.appearance) { Icon(Icons.Outlined.FormatSize, "Reading choices", tint = colors.tint) }
            IconButton(onClick = { chrome.readAloud(startVerse()) }) {
                if (chrome.reading) Icon(Icons.Outlined.Pause, "Pause reading aloud", tint = colors.tint) else Icon(Icons.AutoMirrored.Outlined.VolumeUp, "Read aloud", tint = colors.tint)
            }
            Box {
                IconButton(onClick = { menu = true }) { Icon(Icons.Outlined.MoreVert, "More reading actions", tint = colors.tint) }
                DropdownMenu(menu, { menu = false }, containerColor = colors.card) {
                    DropdownMenuItem(text = { Text("Go to", fontFamily = SpaceGrotesk) }, onClick = { menu = false; chrome.goTo() })
                    DropdownMenuItem(text = { Text("The Fathers", fontFamily = SpaceGrotesk) }, onClick = { menu = false; chrome.fathers() })
                    DropdownMenuItem(text = { Text(if (chrome.isRead) "Mark chapter unread" else "Mark chapter read", fontFamily = SpaceGrotesk) }, onClick = { menu = false; chrome.toggleRead() })
                }
            }
        }
        HorizontalDivider(color = colors.separator, thickness = .5.dp)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable private fun PagedBottomBar(page: Int, count: Int, message: String, scrub: (Int) -> Unit, previousChapter: (() -> Unit)?, nextChapter: (() -> Unit)?) {
    val colors = LocalJohnColors.current
    Column(Modifier.fillMaxWidth().background(colors.card)) {
        HorizontalDivider(color = colors.separator, thickness = .5.dp)
        Row(Modifier.fillMaxWidth().padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = { previousChapter?.invoke() }, enabled = previousChapter != null) { Icon(Icons.AutoMirrored.Outlined.KeyboardArrowLeft, "Previous chapter", tint = if (previousChapter != null) colors.tint else colors.border) }
            val sliderColors = SliderDefaults.colors(thumbColor = colors.tint, activeTrackColor = colors.tint, inactiveTrackColor = colors.separator, activeTickColor = Color.Transparent, inactiveTickColor = Color.Transparent)
            if (count > 1) Slider(page.toFloat(), { scrub(it.roundToInt()) }, Modifier.weight(1f).semantics { contentDescription = "Page ${page + 1} of $count" },
                valueRange = 0f..(count - 1).toFloat(), steps = (count - 2).coerceAtLeast(0), colors = sliderColors,
                thumb = { Box(Modifier.size(18.dp).background(colors.tint, CircleShape)) },
                track = { state -> SliderDefaults.Track(state, Modifier.height(3.dp), colors = sliderColors, drawStopIndicator = null, drawTick = { _, _ -> }, thumbTrackGapSize = 0.dp, trackInsideCornerSize = 0.dp) })
            else Spacer(Modifier.weight(1f))
            IconButton(onClick = { nextChapter?.invoke() }, enabled = nextChapter != null) { Icon(Icons.AutoMirrored.Outlined.KeyboardArrowRight, "Next chapter", tint = if (nextChapter != null) colors.tint else colors.border) }
        }
        Text("Page ${page + 1} of $count · ${PageMath.pagesLeftText(page, count)}", Modifier.fillMaxWidth(), textAlign = TextAlign.Center, fontFamily = SpaceGrotesk, fontSize = 12.sp, color = colors.text)
        Text(message.ifBlank { "Touch and hold a verse to select it." }, Modifier.fillMaxWidth().padding(top = 2.dp, bottom = 10.dp), textAlign = TextAlign.Center, fontFamily = SpaceGrotesk, fontSize = 11.sp, color = colors.textDim)
    }
}
