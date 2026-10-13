package com.john.bible.ui

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.john.bible.data.*
import org.json.JSONArray

private fun decodeDrawing(value:String):List<List<Offset>> = runCatching {
    val strokes=JSONArray(value)
    (0 until strokes.length()).map { i -> val points=strokes.getJSONArray(i);(0 until points.length()).map { p -> val point=points.getJSONArray(p);Offset(point.getDouble(0).toFloat(),point.getDouble(1).toFloat()) } }
}.getOrDefault(emptyList())
private fun encodeDrawing(strokes:List<List<Offset>>):String=if(strokes.isEmpty())"" else JSONArray(strokes.map { JSONArray(it.map { point -> JSONArray(listOf(point.x,point.y)) }) }).toString()

@Composable internal fun NoteEditorDialog(hit:SearchHit,store:JohnStore,close:()->Unit) {
    var text by remember(hit) { mutableStateOf(store.noteFor(hit)) }
    var strokes by remember(hit) { mutableStateOf(decodeDrawing(store.noteDrawing(hit))) }
    var drawing by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf("") }
    var dictationNotice by remember { mutableStateOf(false) }
    val colors=LocalJohnColors.current
    val context=LocalContext.current
    val dictation=rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if(result.resultCode==Activity.RESULT_OK)result.data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()?.let { text=if(text.isBlank())it else "$text $it" }
    }
    AlertDialog(onDismissRequest=close,title={JohnText("Note · ${hit.reference}",size=20)},text={
        Column(Modifier.heightIn(max=520.dp).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(12.dp)) {
            JohnText(hit.text,serif=true,size=15)
            OutlinedTextField(text,{text=it},label={Text("Your note")},modifier=Modifier.fillMaxWidth().heightIn(min=140.dp),textStyle=LocalTextStyle.current.copy(color=colors.text))
            Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                TextButton(onClick={dictationNotice=true}) {Text("Dictate")}
                TextButton(onClick={drawing=!drawing}){Text(if(drawing)"Hide drawing" else "Handwritten note")}
            }
            if(drawing) {
                JohnText("Draw with your finger or stylus.",size=12,dim=true)
                Canvas(Modifier.testTag("note-drawing").fillMaxWidth().height(230.dp).background(colors.background).pointerInput(hit) {
                    detectDragGestures(onDragStart={point -> strokes=strokes+listOf(listOf(Offset((point.x/size.width).coerceIn(0f,1f),(point.y/size.height).coerceIn(0f,1f))))},onDrag={change,_ ->
                        change.consume()
                        val point=Offset((change.position.x/size.width).coerceIn(0f,1f),(change.position.y/size.height).coerceIn(0f,1f))
                        if(strokes.isNotEmpty())strokes=strokes.dropLast(1)+listOf(strokes.last()+point)
                    })
                }) {
                    strokes.forEach { points ->
                        if(points.size==1)drawCircle(colors.text,2.dp.toPx(),Offset(points[0].x*size.width,points[0].y*size.height))
                        else if(points.isNotEmpty()) {
                            val path=Path().apply {moveTo(points[0].x*size.width,points[0].y*size.height);points.drop(1).forEach { lineTo(it.x*size.width,it.y*size.height) }}
                            drawPath(path,colors.text,style=Stroke(width=2.dp.toPx(),cap=StrokeCap.Round))
                        }
                    }
                }
                Row {TextButton(onClick={strokes=strokes.dropLast(1)}){Text("Undo stroke")};TextButton(onClick={strokes=emptyList()}){Text("Clear drawing")}}
            }
            if(message.isNotBlank())JohnText(message,size=12,dim=true)
            if(store.noteFor(hit).isNotBlank() || store.noteDrawing(hit).isNotBlank())TextButton(onClick={store.saveNote(hit,"","");close()}){Text("Delete note")}
        }
    },confirmButton={TextButton(onClick={store.saveNote(hit,text.trim(),encodeDrawing(strokes));close()}){Text("Save")}},dismissButton={TextButton(onClick=close){Text("Cancel")}})
    if(dictationNotice) AlertDialog(onDismissRequest={dictationNotice=false},title={JohnText("Use device dictation?",size=22)},text={JohnText("This opens your device’s speech service. Its provider may send your audio to its servers. John receives the recognized text. You can type your note instead.")},confirmButton={TextButton(onClick={
        dictationNotice=false
        runCatching { dictation.launch(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,RecognizerIntent.LANGUAGE_MODEL_FREE_FORM).putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE,true).putExtra(RecognizerIntent.EXTRA_PROMPT,"Add to your note")) }.onFailure { message="Voice dictation is not available on this device." }
    }) {Text("Continue")}},dismissButton={TextButton(onClick={dictationNotice=false}) {Text("Cancel")}})
}
