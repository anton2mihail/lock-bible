package com.john.bible.ui

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.john.bible.platform.FathersBilling

internal fun Context.findActivity(): Activity? {
    var current: Context? = this
    while (current is ContextWrapper) { if (current is Activity) return current; current = current.baseContext }
    return null
}

/**
 * The one purchase page (Android 1.1.0, matching iOS 2.1.0). The reader shows it in place of a locked section;
 * Settings and the library card open it too. The price always comes from Google Play.
 */
@Composable internal fun FathersUnlockPanel(sampleNotice: String? = null, totals: String? = null) {
    val context = LocalContext.current
    val billing = remember { FathersBilling.get(context) }
    val colors = LocalJohnColors.current
    LaunchedEffect(Unit) { billing.start() }
    Column(Modifier.fillMaxWidth().testTag("fathers-unlock"), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        val art = remember { runCatching { context.assets.open("artwork/scripture.jpg").use { BitmapFactory.decodeStream(it).asImageBitmap() } }.getOrNull() }
        if (art != null) {
            Image(art, null, Modifier.fillMaxWidth().height(170.dp).clip(RoundedCornerShape(18.dp)), contentScale = ContentScale.Crop)
            JohnText("Abraham Bloemaert, The Four Evangelists, c. 1612–15", size = 11, dim = true)
        }
        JohnText("THE FATHERS & DOCTORS", size = 12)
        sampleNotice?.let { JohnText(it, size = 14, dim = true) }
        Text(if (billing.isUnlocked) "The whole library is yours" else "Read the whole library", fontFamily = SpaceGrotesk,
            fontSize = 28.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold, color = colors.text)
        JohnText((totals?.let { "$it, offline. " } ?: "") + "Augustine complete, the Summa of St Thomas Aquinas, Chrysostom, Jerome, Ambrose, Athanasius and more. The first part of every work, the Apostolic Fathers and the Confessions are free to read.")
        when (billing.access) {
            FathersBilling.Access.GRANDFATHERED -> JohnText("You installed John 1:1 before the library was sold, so it stays free for you. Thank you.", size = 14, dim = true)
            FathersBilling.Access.PURCHASED -> JohnText("Thank you for supporting John 1:1.", size = 14, dim = true)
            else -> {
                Button(
                    onClick = { context.findActivity()?.let(billing::purchase) },
                    enabled = !billing.busy && billing.access != FathersBilling.Access.CHECKING,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).testTag("fathers-buy"),
                    shape = RoundedCornerShape(16.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = colors.tint, contentColor = colors.background)
                ) {
                    Text(when {
                        billing.access == FathersBilling.Access.CHECKING -> "Checking your purchases…"
                        billing.price != null -> "Unlock the library · ${billing.price}"
                        else -> "Unlock the library"
                    }, fontFamily = SpaceGrotesk, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                }
                JohnButton("Restore Purchases") { billing.restore() }
                billing.message?.let { JohnText(it, size = 14, dim = true) }
                JohnText("Everything else in John 1:1 stays free: the Bible, the Rosary, prayers, readings, saints and widgets. One payment, no subscription.", size = 14, dim = true)
            }
        }
    }
}

/** The purchase page on its own, for Settings and the library card. */
@Composable internal fun FathersUnlockScreen(totals: String?, back: () -> Unit) {
    JohnPage("", back = back) { FathersUnlockPanel(totals = totals) }
}

/** The "Free to start" card at the top of the library, shown only before the library is unlocked. */
@Composable internal fun FathersLibraryCard(open: () -> Unit) {
    val context = LocalContext.current
    val billing = remember { FathersBilling.get(context) }
    LaunchedEffect(Unit) { billing.start() }
    if (billing.isUnlocked) return
    JohnPanel {
        JohnText("FREE TO START", size = 12)
        JohnText("Read the first part of every work, the Apostolic Fathers and the Confessions free. Unlock the whole library once.", size = 14)
        JohnRow(billing.price?.let { "Unlock · $it" } ?: "Unlock the library") { open() }
    }
}

/** The Settings section: the purchase row and Restore Purchases. */
@Composable internal fun FathersSettingsSection(open: () -> Unit) {
    val context = LocalContext.current
    val billing = remember { FathersBilling.get(context) }
    LaunchedEffect(Unit) { billing.start() }
    JohnText("The Fathers & Doctors", size = 16, dim = true)
    JohnPanel {
        val (title, detail) = when (billing.access) {
            FathersBilling.Access.GRANDFATHERED -> "The full library is unlocked" to "Free for you: you installed before it was sold"
            FathersBilling.Access.PURCHASED -> "The full library is unlocked" to "Thank you for your purchase"
            else -> "Unlock the full library" to (billing.price?.let { "One payment of $it, no subscription" } ?: "One payment, no subscription")
        }
        JohnRow(title, detail) { open() }
        if (!billing.isUnlocked) ReaderButton("Restore Purchases") { billing.restore() }
        billing.message?.let { JohnText(it, size = 12, dim = true) }
    }
}
