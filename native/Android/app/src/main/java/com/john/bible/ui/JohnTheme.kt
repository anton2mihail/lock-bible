package com.john.bible.ui

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.ArrowForward
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.john.bible.R

// Values, fonts, and spacing match native/John/DesignSystem and ContentPage.swift.
data class JohnColors(val background:Color,val card:Color,val border:Color,val separator:Color,val text:Color,val textDim:Color,val tint:Color)
val JohnLight = JohnColors(Color(0xFFF6F2EA),Color(0xFFFFFCF6),Color(0xFFC6BAA9),Color(0xFFE1D9CC),Color(0xFF191015),Color(0xFF564E4A),Color(0xFF745439))
val JohnDark = JohnColors(Color(0xFF191419),Color(0xFF251D23),Color(0xFF564E4A),Color(0xFF3C3836),Color(0xFFF4F2F1),Color(0xFFB6ACA6),Color(0xFFD9BE8D))
val LocalJohnColors = staticCompositionLocalOf { JohnLight }
val Lora = FontFamily(Font(R.font.lora_regular),Font(R.font.lora_medium,FontWeight.Medium))
val SpaceGrotesk = FontFamily(Font(R.font.space_grotesk_regular),Font(R.font.space_grotesk_light,FontWeight.Light),Font(R.font.space_grotesk_medium,FontWeight.Medium),Font(R.font.space_grotesk_semibold,FontWeight.SemiBold),Font(R.font.space_grotesk_bold,FontWeight.Bold))

@Composable fun JohnTheme(appearance:String="system", content:@Composable ()->Unit) {
    val dark = when(appearance) { "dark" -> true; "light" -> false; else -> isSystemInDarkTheme() }
    val c=if(dark) JohnDark else JohnLight
    val scheme=if(dark) darkColorScheme(primary=c.tint,background=c.background,surface=c.card,onSurface=c.text,onBackground=c.text,outline=c.border) else lightColorScheme(primary=c.tint,background=c.background,surface=c.card,onSurface=c.text,onBackground=c.text,outline=c.border)
    CompositionLocalProvider(LocalJohnColors provides c) {
        MaterialTheme(colorScheme=scheme,typography=Typography(bodyLarge=androidx.compose.ui.text.TextStyle(fontFamily=SpaceGrotesk,fontSize=16.sp,lineHeight=24.sp),titleLarge=androidx.compose.ui.text.TextStyle(fontFamily=Lora,fontSize=24.sp))) { content() }
    }
}

@Composable fun JohnPage(title:String,eyebrow:String="",subtitle:String="",back:(()->Unit)?=null,sansTitle:Boolean=false,content:@Composable ColumnScope.()->Unit) {
    val c=LocalJohnColors.current
    Box(Modifier.fillMaxSize().background(c.background),contentAlignment=Alignment.TopCenter) {
        Column(Modifier.widthIn(max=740.dp).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal=24.dp).padding(top=24.dp,bottom=48.dp),verticalArrangement=Arrangement.spacedBy(24.dp)) {
            if(back!=null) IconButton(onClick=back) { Icon(Icons.AutoMirrored.Outlined.ArrowBack,"Back",tint=c.tint) }
            Column(verticalArrangement=Arrangement.spacedBy(8.dp)) {
                if(eyebrow.isNotEmpty()) Text(eyebrow.uppercase(),fontFamily=SpaceGrotesk,fontSize=11.sp,lineHeight=18.sp,letterSpacing=2.sp,color=c.tint)
                Text(title,fontFamily=if(sansTitle)SpaceGrotesk else Lora,fontWeight=if(sansTitle)FontWeight.Bold else FontWeight.Normal,fontSize=36.sp,lineHeight=46.sp,letterSpacing=(-0.8).sp,color=c.text,modifier=Modifier.semantics { heading() })
                if(subtitle.isNotEmpty()) JohnText(subtitle,dim=true)
            }
            content()
        }
    }
}
@Composable fun JohnText(text:String,serif:Boolean=false,size:Int=16,dim:Boolean=false) {
    val c=LocalJohnColors.current
    Text(text,fontFamily=if(serif) Lora else SpaceGrotesk,fontSize=size.sp,lineHeight=(size*1.5).sp,color=if(dim)c.textDim else c.text)
}
@Composable fun JohnPanel(content:@Composable ColumnScope.()->Unit) {
    val c=LocalJohnColors.current
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(c.card).border(0.5.dp,c.separator,RoundedCornerShape(18.dp)).padding(20.dp),verticalArrangement=Arrangement.spacedBy(16.dp),content=content)
}
@Composable fun JohnRow(title:String,subtitle:String="",onClick:()->Unit) {
    val c=LocalJohnColors.current
    Column {
        Row(Modifier.fillMaxWidth().clickable(onClick=onClick).heightIn(min=72.dp).padding(vertical=12.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(16.dp)) {
            Column(Modifier.weight(1f)) {
                Text(title,fontFamily=SpaceGrotesk,fontWeight=FontWeight.Medium,fontSize=16.sp,lineHeight=24.sp,color=c.text)
                if(subtitle.isNotEmpty()) JohnText(subtitle,size=14,dim=true)
            }
            Icon(Icons.AutoMirrored.Outlined.ArrowForward,contentDescription=null,tint=c.tint,modifier=Modifier.size(19.dp))
        }
        HorizontalDivider(color=c.separator,thickness=0.5.dp)
    }
}
@Composable fun JohnButton(text:String,onClick:()->Unit) {
    val c=LocalJohnColors.current
    OutlinedButton(onClick=onClick,modifier=Modifier.fillMaxWidth().heightIn(min=56.dp),shape=RoundedCornerShape(4.dp),border=androidx.compose.foundation.BorderStroke(1.dp,c.border),colors=ButtonDefaults.outlinedButtonColors(contentColor=c.text,containerColor=c.card)) {
        Text(text,fontFamily=SpaceGrotesk,fontSize=16.sp,fontWeight=FontWeight.Medium)
    }
}
@Composable fun JohnArtwork(image:String,modifier:Modifier=Modifier) {
    val context=LocalContext.current
    val bitmap=remember(image) { runCatching { context.assets.open("artwork/$image.jpg").use { BitmapFactory.decodeStream(it) } }.getOrNull() }
    bitmap?.let { Image(it.asImageBitmap(),null,modifier,contentScale=ContentScale.Crop) }
}
@Composable fun JohnArtCard(image:String,title:String,subtitle:String,onClick:()->Unit) {
    val c=LocalJohnColors.current
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(c.card).border(0.5.dp,c.separator,RoundedCornerShape(18.dp)).clickable(onClick=onClick)) {
        JohnArtwork(image,Modifier.fillMaxWidth().aspectRatio(2f))
        Column(Modifier.padding(20.dp),verticalArrangement=Arrangement.spacedBy(8.dp)) {
            JohnText(title,serif=true,size=23)
            JohnText(subtitle,size=14,dim=true)
        }
    }
}
