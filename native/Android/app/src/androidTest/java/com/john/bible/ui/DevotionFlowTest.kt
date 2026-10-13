package com.john.bible.ui

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.john.bible.data.JohnRepository
import com.john.bible.data.JohnStore
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DevotionFlowTest {
    @get:Rule val compose=createComposeRule()
    private lateinit var repo:JohnRepository
    private lateinit var store:JohnStore
    private val context get()=InstrumentationRegistry.getInstrumentation().targetContext
    private val preferenceName="john-devotion-test"
    @Before fun setup() {
        context.getSharedPreferences(preferenceName,0).edit().clear().commit()
        repo=JohnRepository(context)
        store=JohnStore(context,preferenceName)
    }
    @After fun cleanup() {
        repo.close()
        context.getSharedPreferences(preferenceName,0).edit().clear().commit()
    }
    private fun screen(route:String) {
        compose.setContent { JohnTheme { DevotionalScreen(route,repo,store,{}, {}) } }
    }
    @Test fun prayerFavoritePersistsFromDetail() {
        screen("prayer/hail-mary")
        compose.onNodeWithText("Keep in favorites").performScrollTo().performClick()
        compose.onNodeWithText("Remove from favorites").assertExists()
        assertTrue("hail-mary" in JohnStore(context,preferenceName).favoritePrayerIds)
    }
    @Test fun completedNovenaDayAdvancesAndPersists() {
        val id=repo.content().getJSONArray("novenas").getJSONObject(0).getString("id")
        screen("novena/$id")
        compose.onNodeWithText("Mark day 1 complete").performScrollTo().performClick()
        assertEquals(setOf(1),JohnStore(context,preferenceName).novena(id).completedDays)
        assertEquals(2,JohnStore(context,preferenceName).novena(id).selectedDay)
        compose.onNodeWithText("Mark day 2 complete").assertExists()
    }
    @Test fun lectioContinuesToNextStep() {
        screen("lectio/${android.net.Uri.encode("John 1:1\nIn the beginning was the Word.")}")
        compose.onNodeWithText("Read slowly").assertExists()
        compose.onNodeWithText("Continue").performScrollTo().performClick()
        compose.onNodeWithText("Stay with a word").assertExists()
        compose.onNodeWithText("Previous step").performScrollTo().performClick()
        compose.onNodeWithText("Read slowly").assertExists()
    }
    @Test fun rosaryContinuesAndPreviousRestoresStep() {
        val sessions=repo.content().getJSONObject("rosary").getJSONArray("sessions")
        val session=(0 until sessions.length()).map { sessions.getJSONObject(it) }.first { it.getString("id")=="joyful" }
        val first=session.getJSONArray("steps").getJSONObject(0).getString("title")
        val next=session.getJSONArray("steps").getJSONObject(1).getString("title")
        screen("rosary/joyful")
        compose.onNodeWithText(first).assertExists()
        compose.onNodeWithText("Continue").performScrollTo().performClick()
        compose.onNodeWithText(next).assertExists()
        compose.onNodeWithText("Previous").performScrollTo().performClick()
        compose.onNodeWithText(first).assertExists()
    }
}
