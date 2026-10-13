package com.john.bible.ui

import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.john.bible.data.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

@Composable fun SavedScreen(repo: JohnRepository, store: JohnStore, navigate: (String) -> Unit) {
    var filter by rememberSaveable { mutableStateOf("all") }
    var folder by rememberSaveable { mutableStateOf("") }
    var tagFilter by rememberSaveable { mutableStateOf("") }
    var undo by remember { mutableStateOf<SavedPassage?>(null) }
    var note by remember { mutableStateOf<SearchHit?>(null) }
    var tagItem by remember { mutableStateOf<SavedPassage?>(null) }
    var tagText by remember { mutableStateOf("") }
    var status by remember { mutableStateOf("") }
    val context = LocalContext.current
    val export = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        if (uri != null) status = runCatching { context.contentResolver.openOutputStream(uri)?.bufferedWriter()?.use { it.write(store.exportSaved()) }; "Saved passages exported" }.getOrDefault("The export could not be saved.")
    }
    val import = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) status = runCatching { val json = context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() } ?: error("Empty document"); "${store.importSaved(json)} passages imported" }.getOrDefault("This file could not be imported.")
    }
    val visible = store.saved.filter { item ->
        (filter == "all" || item.kind == filter) && (tagFilter.isBlank() || tagFilter in item.tags) && when (folder) {
            "recent" -> item.updatedAt > System.currentTimeMillis() - 7L * 24 * 60 * 60 * 1000
            "notes" -> item.kind == "note"
            "untagged" -> item.tags.isEmpty()
            else -> true
        }
    }.sortedByDescending { it.updatedAt }
    ReadingPage("Saved") {
        ChoiceChips(listOf("all" to "All", "bookmark" to "Bookmarks", "highlight" to "Highlights", "note" to "Notes"), filter) { filter = it }
        ChoiceChips(listOf("" to "All passages", "recent" to "Recent", "notes" to "With notes", "untagged" to "Untagged"), folder) { folder = it }
        val tags = store.saved.flatMap { it.tags }.distinct().sorted()
        if (tags.isNotEmpty()) ChoiceChips(listOf("" to "All tags") + tags.map { it to it }, tagFilter) { tagFilter = it }
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            ReaderButton("Export") { export.launch("John-saved-passages.json") }
            ReaderButton("Import") { import.launch(arrayOf("application/json", "text/plain")) }
        }
        if (status.isNotBlank()) JohnText(status, dim = true, size = 13)
        if (visible.isEmpty()) JohnPanel { JohnText("Keep a passage close", serif = true, size = 24); JohnText("Select a verse in the reader to add a bookmark, highlight, or note.", dim = true); ReaderButton("Read the Bible") { navigate("read") } }
        visible.forEach { item ->
            val hit = SearchHit(item.edition, item.book, item.bookName, item.chapter, if (item.endLabel == item.startLabel) item.startLabel else "${item.startLabel}–${item.endLabel}", item.text)
            JohnPanel {
                JohnRow(item.reference, "${editionShort(item.edition)} · ${item.kind.replaceFirstChar { it.uppercase() }}") { navigate(readerRoute(hit)) }
                JohnText(item.text, serif = true, size = 17)
                if (item.note.isNotBlank()) JohnText(item.note, size = 15)
                if (item.tags.isNotEmpty()) JohnText(item.tags.joinToString(" · "), size = 12, dim = true)
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    ReaderButton("Open") { navigate(readerRoute(hit)) }
                    ReaderButton("Note") { note = hit }
                    ReaderButton("Share") { sharePassage(context, shareText(hit)) }
                    ReaderButton("Tag") { tagItem = item; tagText = item.tags.joinToString(", ") }
                    ReaderButton("Delete") { undo = item; store.deleteSaved(item.id); status = "${item.reference} deleted" }
                }
            }
        }
        undo?.let { item -> JohnPanel { JohnText("${item.reference} deleted", size = 14); ReaderButton("Undo") { store.restoreSaved(item); undo = null; status = "Passage restored" } } }
    }
    note?.let { NoteDialog(it, store) { note = null } }
    if (tagItem != null) AlertDialog(onDismissRequest = { tagItem = null }, title = { JohnText("Tags", size = 24) }, text = { OutlinedTextField(tagText, { tagText = it }, label = { Text("Separate tags with commas") }) }, confirmButton = { TextButton(onClick = { tagItem?.let { store.setTags(it.id, tagText.split(',').map(String::trim).filter(String::isNotBlank).distinct()) }; tagItem = null }) { Text("Save") } }, dismissButton = { TextButton(onClick = { tagItem = null }) { Text("Cancel") } })
}

@Composable fun SearchScreen(repo: JohnRepository, store: JohnStore, navigate: (String) -> Unit, back: () -> Unit) {
    var query by rememberSaveable { mutableStateOf("") }
    var edition by rememberSaveable { mutableStateOf(store.edition) }
    var scope by rememberSaveable { mutableStateOf("all") }
    var bookToken by rememberSaveable { mutableStateOf("") }
    var books by remember { mutableStateOf(emptyList<BibleBook>()) }
    var hits by remember { mutableStateOf(emptyList<SearchHit>()) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(edition) { books = withContext(Dispatchers.IO) { repo.books(edition) } }
    LaunchedEffect(query, edition, scope, bookToken) {
        val clean = query.trim()
        hits = emptyList(); error = null
        if (clean.isBlank()) { busy = false; return@LaunchedEffect }
        busy = true
        delay(220)
        runCatching { withContext(Dispatchers.IO) { repo.search(edition, clean, scope, bookToken.takeIf { it.isNotBlank() }) } }.onSuccess { result ->
            val byCode = books.associateBy { it.code }
            hits = result.filter { hit -> (bookToken.isBlank() || bookToken == hit.book) && (scope == "all" || byCode[hit.book]?.testament.equals(scope, true) || (scope == "OT" && byCode[hit.book]?.testament == "deutero")) }
        }.onFailure { error = "Search could not be completed. Please try again." }
        busy = false
    }
    val colors = LocalJohnColors.current
    ReadingPage("Search Scripture", back = back) {
        OutlinedTextField(query, { query = it }, modifier = Modifier.fillMaxWidth(), label = { Text("Search Scripture") }, placeholder = { Text("Reference, word, or exact phrase") }, singleLine = true, colors = OutlinedTextFieldDefaults.colors(focusedTextColor = colors.text, unfocusedTextColor = colors.text, focusedBorderColor = colors.tint, unfocusedBorderColor = colors.border, focusedLabelColor = colors.tint))
        if (query.isNotBlank()) ReaderButton("Clear search") { query = "" }
        ChoiceChips(editionTitles.map { it.key to editionShort(it.key) }, edition) { edition = it }
        ChoiceChips(listOf("all" to "All", "OT" to "Old Testament", "NT" to "New Testament"), scope) { scope = it }
        if (bookToken.isNotEmpty()) ReaderButton("In ${books.firstOrNull { it.code == bookToken }?.name ?: bookToken} ×") { bookToken = "" }
        val suggestions = if (query.trim().length >= 2) books.filter { it.name.startsWith(query.trim(), true) && it.code != bookToken }.take(6) else emptyList()
        suggestions.forEach { book -> ReaderButton("In ${book.name}") { bookToken = book.code; query = "" } }
        if (busy) JohnText("Searching…", dim = true)
        error?.let { JohnText(it) }
        if (query.isBlank()) {
            if (store.recentSearches.isEmpty()) JohnPanel { JohnText("Find a passage", serif = true, size = 24); JohnText("Search by reference, keyword, or exact phrase.", dim = true) }
            else {
                JohnText("Recent searches", dim = true, size = 13)
                store.recentSearches.forEach { recent -> JohnRow(recent) { query = recent } }
                ReaderButton("Clear recent searches") { store.clearRecentSearches() }
            }
        } else if (!busy && error == null) {
            JohnText(if (hits.isEmpty()) "No verses found. Try another word or reference." else "${hits.size} verses found", dim = true, size = 13)
            hits.forEach { hit -> JohnPanel {
                JohnRow("${hit.bookName} ${hit.chapter}:${hit.label}", editionTitles[edition] ?: edition) { store.addRecentSearch(query.trim()); navigate(readerRoute(hit)) }
                JohnText(hit.text, serif = true, size = 17)
            } }
        }
    }
}
