package com.john.bible.platform

import android.app.Activity
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.john.bible.data.FathersAccess

/**
 * The one purchase in John 1:1 for Android: the full Fathers and Doctors library, bought once on Google Play.
 *
 * Access comes from, in order: a saved grandfathering decision, a cached purchase (so the library opens at
 * once and offline), and Google Play's list of owned purchases. A purchase is cleared only when Play no longer
 * lists it (for example after a refund). Grandfathering is decided once and never cleared.
 */
class FathersBilling private constructor(context: Context) {
    enum class Access { CHECKING, LOCKED, PURCHASED, GRANDFATHERED }

    private val app = context.applicationContext
    private val prefs = app.getSharedPreferences("john", Context.MODE_PRIVATE)
    private val main = Handler(Looper.getMainLooper())
    private var details: ProductDetails? = null
    private var forced = false

    var access by mutableStateOf(Access.CHECKING); private set
    var price by mutableStateOf<String?>(null); private set
    var productUnavailable by mutableStateOf(false); private set
    var busy by mutableStateOf(false); private set
    var message by mutableStateOf<String?>(null); private set

    val isUnlocked get() = access == Access.PURCHASED || access == Access.GRANDFATHERED

    private val client: BillingClient = BillingClient.newBuilder(app)
        .setListener { result, purchases -> main.post { onPurchasesUpdated(result, purchases) } }
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection()
        .build()

    init {
        val grandfathered = FathersAccess.decideGrandfathered(
            stored = if (prefs.contains(KEY_GRANDFATHERED)) prefs.getBoolean(KEY_GRANDFATHERED, false) else null,
            firstInstallTime = installTimes().first, lastUpdateTime = installTimes().second)
        prefs.edit().putBoolean(KEY_GRANDFATHERED, grandfathered).apply()
        access = when {
            grandfathered -> Access.GRANDFATHERED
            prefs.getBoolean(KEY_PURCHASED, false) -> Access.PURCHASED
            else -> Access.CHECKING
        }
    }

    /** Debug builds only: fixes the state for UI tests and screenshots, and stops Play from changing it. */
    fun force(value: String?) {
        access = when (value) {
            "locked" -> Access.LOCKED
            "purchased" -> Access.PURCHASED
            "grandfathered" -> Access.GRANDFATHERED
            else -> return
        }
        forced = true
    }

    /** Connects to Google Play, then refreshes owned purchases and the price. Safe to call more than once. */
    fun start() {
        if (forced || client.isReady) { if (client.isReady && !forced) refresh(); return }
        client.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                main.post {
                    if (result.responseCode == BillingClient.BillingResponseCode.OK) { refresh(); loadProduct() }
                    else if (access == Access.CHECKING) access = Access.LOCKED
                }
            }
            override fun onBillingServiceDisconnected() {}
        })
    }

    fun refresh(onDone: (() -> Unit)? = null) {
        if (forced || access == Access.GRANDFATHERED) { onDone?.invoke(); return }
        val params = QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build()
        client.queryPurchasesAsync(params) { result, purchases ->
            main.post {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    val owned = purchases.filter { FathersAccess.PRODUCT_ID in it.products && it.purchaseState == Purchase.PurchaseState.PURCHASED }
                    owned.forEach(::acknowledge)
                    setPurchased(owned.isNotEmpty())
                } else if (access == Access.CHECKING) access = Access.LOCKED
                onDone?.invoke()
            }
        }
    }

    private fun loadProduct() {
        val product = QueryProductDetailsParams.Product.newBuilder()
            .setProductId(FathersAccess.PRODUCT_ID).setProductType(BillingClient.ProductType.INAPP).build()
        client.queryProductDetailsAsync(QueryProductDetailsParams.newBuilder().setProductList(listOf(product)).build()) { result, list ->
            main.post {
                details = list.productDetailsList.firstOrNull()
                price = details?.oneTimePurchaseOfferDetails?.formattedPrice
                productUnavailable = result.responseCode != BillingClient.BillingResponseCode.OK || details == null
            }
        }
    }

    fun purchase(activity: Activity) {
        message = null
        val product = details
        if (product == null) { message = "Google Play could not be reached. Check your connection and try again."; start(); return }
        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(product).build()))
            .build()
        busy = true
        val result = client.launchBillingFlow(activity, params)
        if (result.responseCode != BillingClient.BillingResponseCode.OK) { busy = false; message = "The purchase did not start. Please try again." }
    }

    fun restore() {
        message = null
        if (!client.isReady) { start(); message = "Connecting to Google Play. Try again in a moment."; return }
        refresh { message = if (isUnlocked) "The full library is unlocked." else "No purchase was found for this Google account." }
    }

    private fun onPurchasesUpdated(result: BillingResult, purchases: List<Purchase>?) {
        busy = false
        when (result.responseCode) {
            BillingClient.BillingResponseCode.OK -> purchases.orEmpty().filter { FathersAccess.PRODUCT_ID in it.products }.forEach { purchase ->
                when (purchase.purchaseState) {
                    Purchase.PurchaseState.PURCHASED -> { acknowledge(purchase); setPurchased(true) }
                    Purchase.PurchaseState.PENDING -> message = "Your purchase is waiting for payment. The library unlocks as soon as it completes."
                    else -> {}
                }
            }
            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> refresh()
            BillingClient.BillingResponseCode.USER_CANCELED -> {}
            else -> message = "The purchase did not finish. Please try again."
        }
    }

    private fun acknowledge(purchase: Purchase) {
        if (purchase.isAcknowledged) return
        client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build()) {}
    }

    private fun setPurchased(value: Boolean) {
        if (forced || access == Access.GRANDFATHERED) return
        prefs.edit().putBoolean(KEY_PURCHASED, value).apply()
        access = if (value) Access.PURCHASED else Access.LOCKED
    }

    private fun installTimes(): Pair<Long, Long> = runCatching {
        val info = if (Build.VERSION.SDK_INT >= 33) app.packageManager.getPackageInfo(app.packageName, android.content.pm.PackageManager.PackageInfoFlags.of(0))
        else @Suppress("DEPRECATION") app.packageManager.getPackageInfo(app.packageName, 0)
        info.firstInstallTime to info.lastUpdateTime
    }.getOrDefault(0L to 0L)

    companion object {
        private const val KEY_PURCHASED = "fathersPurchased"
        private const val KEY_GRANDFATHERED = "fathersGrandfathered"
        @Volatile private var instance: FathersBilling? = null
        fun get(context: Context): FathersBilling = instance ?: synchronized(this) { instance ?: FathersBilling(context).also { instance = it } }
    }
}
