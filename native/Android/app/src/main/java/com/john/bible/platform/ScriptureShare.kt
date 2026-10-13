package com.john.bible.platform

import android.content.Context
import android.content.Intent
import android.graphics.*
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.core.content.FileProvider
import androidx.core.content.res.ResourcesCompat
import com.john.bible.R
import com.john.bible.data.SearchHit
import java.io.File

/** Mirrors the Swift ShareCardSurface at three pixels per logical point. */
object ScriptureShare {
    fun shareCard(context:Context,hit:SearchHit,plum:Boolean=false) {
        val width=1080
        val inset=96f
        val foreground=if(plum)Color.rgb(255,247,232) else Color.rgb(52,38,45)
        val background=if(plum)Color.rgb(47,29,44) else Color.rgb(244,234,219)
        val serif=ResourcesCompat.getFont(context,R.font.lora_regular)
        val sans=ResourcesCompat.getFont(context,R.font.space_grotesk_regular)
        val font=if(hit.text.length>900)60f else 78f
        val lineHeight=if(hit.text.length>900)93f else 117f
        val paint=TextPaint(Paint.ANTI_ALIAS_FLAG).apply {color=foreground;typeface=serif;textSize=font}
        val layout=StaticLayout.Builder.obtain(hit.text,0,hit.text.length,paint,width-192).setAlignment(Layout.Alignment.ALIGN_NORMAL).setLineSpacing((lineHeight-paint.fontSpacing).coerceAtLeast(0f),1f).setIncludePad(false).build()
        val height=(layout.height+864).coerceAtLeast(1440)
        require(height<=16384) {"This passage is too long for an image. Share the text instead."}
        val bitmap=Bitmap.createBitmap(width,height,Bitmap.Config.ARGB_8888)
        val canvas=Canvas(bitmap)
        canvas.drawColor(background)
        runCatching { context.assets.open(if(plum)"artwork/share-plum.jpg" else "artwork/share-ivory.jpg").use { BitmapFactory.decodeStream(it) } }.getOrNull()?.let {
            val scale=maxOf(width.toFloat()/it.width,height.toFloat()/it.height)
            val targetWidth=it.width*scale;val targetHeight=it.height*scale
            canvas.drawBitmap(it,null,RectF((width-targetWidth)/2,(height-targetHeight)/2,(width+targetWidth)/2,(height+targetHeight)/2),Paint(Paint.ANTI_ALIAS_FLAG))
            canvas.drawColor(Color.argb(33,Color.red(background),Color.green(background),Color.blue(background)))
            it.recycle()
        }
        paint.typeface=sans;paint.textSize=33f
        canvas.drawText("JOHN 1:1",inset,129f,paint)
        paint.typeface=serif;paint.textSize=font
        canvas.save();canvas.translate(inset,225f);layout.draw(canvas);canvas.restore()
        paint.typeface=sans;paint.textSize=42f
        canvas.drawText(hit.reference,inset,(layout.height+363).toFloat(),paint)
        paint.textSize=36f
        val edition=when(hit.edition){"web-ce"->"WEB-CE";"douay-rheims"->"DRB";else->"VUL"}
        canvas.drawText(edition,inset,(layout.height+411).toFloat(),paint)
        val folder=File(context.cacheDir,"shared").apply {mkdirs()}
        val file=File(folder,"scripture.png")
        file.outputStream().use {bitmap.compress(Bitmap.CompressFormat.PNG,100,it)}
        bitmap.recycle()
        val uri=FileProvider.getUriForFile(context,"${context.packageName}.files",file)
        val intent=Intent(Intent.ACTION_SEND).setType("image/png").putExtra(Intent.EXTRA_STREAM,uri).putExtra(Intent.EXTRA_TEXT,"${hit.text}\n${hit.reference} ($edition)").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        context.startActivity(Intent.createChooser(intent,"Share Scripture"))
    }
}
