package com.john.bible.data

import java.time.Instant
import java.time.ZoneId

/**
 * Who can read which part of the Fathers and Doctors library (Android 1.1.0, matching iOS 2.1.0).
 *
 * The library is one non-consumable Google Play product. Everything a person needs to pray stays free.
 * Without the purchase a reader gets the first section of every work, all of the Apostolic Fathers,
 * and Augustine's Confessions.
 *
 * Grandfathering: Google Play has no "original version" receipt like Apple's AppTransaction. Android keeps
 * the first install time across updates, so on the first launch of an entitlement-aware version the app
 * decides once and stores the answer: if the app was installed before that launch's version (first
 * install time differs from last update time), the person had the library free and keeps it.
 */
object FathersAccess {
    const val PRODUCT_ID = "com.nrsv.verse.fathers"
    const val SAMPLE_SECTION_COUNT = 1
    val freeCollectionIds = setOf("apostolic-fathers")
    val freeWorkIds = setOf("augustine.the-confessions")

    /** The collection id is the part of a work id before the first dot (true for all 273 works). */
    fun collectionId(workId: String): String? {
        val dot = workId.indexOf('.')
        return if (dot <= 0) null else workId.substring(0, dot)
    }

    fun isSectionFree(workId: String, index: Int): Boolean {
        if (index in 0 until SAMPLE_SECTION_COUNT) return true
        if (workId in freeWorkIds) return true
        val collection = collectionId(workId) ?: return false
        return collection in freeCollectionIds
    }

    fun isWorkFree(workId: String, sectionCount: Int): Boolean =
        sectionCount <= SAMPLE_SECTION_COUNT || isSectionFree(workId, SAMPLE_SECTION_COUNT)

    /**
     * The one-time grandfathering decision. [stored] is the saved answer (null before the first decision).
     * Install and update times are PackageInfo milliseconds. Zero or negative times never grandfather.
     */
    fun decideGrandfathered(stored: Boolean?, firstInstallTime: Long, lastUpdateTime: Long): Boolean {
        if (stored != null) return stored
        if (firstInstallTime <= 0 || lastUpdateTime <= 0) return false
        return lastUpdateTime > firstInstallTime
    }
}

/**
 * When the app may ask for a Google Play rating: right after a finished Rosary or novena day, once the person has
 * finished three prayers or opened the app on seven different days, at most once every 120 days.
 */
object ReviewPromptPolicy {
    const val PRAYER_THRESHOLD = 3
    const val OPEN_DAY_THRESHOLD = 7
    const val COOLDOWN_DAYS = 120L

    fun shouldAsk(prayersCompleted: Int, distinctOpenDays: Int, lastAskedMillis: Long?, nowMillis: Long): Boolean {
        if (prayersCompleted < PRAYER_THRESHOLD && distinctOpenDays < OPEN_DAY_THRESHOLD) return false
        if (lastAskedMillis == null) return true
        return nowMillis - lastAskedMillis >= COOLDOWN_DAYS * 86_400_000L
    }

    // Instant.atZone works from API 26; LocalDate.ofInstant needs API 34.
    fun dayKey(nowMillis: Long, zone: ZoneId): String = Instant.ofEpochMilli(nowMillis).atZone(zone).toLocalDate().toString()
}
