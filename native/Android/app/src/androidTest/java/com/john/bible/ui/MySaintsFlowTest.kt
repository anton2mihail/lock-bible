package com.john.bible.ui

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.john.bible.data.JohnRepository
import com.john.bible.data.JohnStore
import com.john.bible.data.SaintDates
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.time.LocalDate

@RunWith(AndroidJUnit4::class)
class MySaintsFlowTest {
    @get:Rule val compose = createComposeRule()
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private val preferences = "john-my-saints-test"
    private lateinit var repo: JohnRepository
    private lateinit var store: JohnStore

    @Before fun setup() {
        context.getSharedPreferences(preferences, 0).edit().clear().commit()
        repo = JohnRepository(context)
        store = JohnStore(context, preferences)
    }

    @After fun cleanup() {
        repo.close()
        context.getSharedPreferences(preferences, 0).edit().clear().commit()
    }

    @Test fun savedSaintAndPrivateNotesSurviveReopenAndUnsave() {
        compose.setContent { JohnTheme { PersonalSaintScreen("st-joseph", repo, store, {}, {}) } }
        compose.onNodeWithContentDescription("Save to My Saints").performScrollTo().performClick()
        compose.onNodeWithText("My notes").performScrollTo().performClick()
        compose.onNodeWithText("Add a private note").performScrollTo().performClick()
        compose.onNodeWithText("Your note").performTextInput("Patience with my family.")
        compose.onNodeWithText("Save").performClick()
        compose.onNodeWithText("Patience with my family.").assertExists()
        assertTrue(JohnStore(context, preferences).saintProfile("st-joseph").saved)
        assertEquals("Patience with my family.", JohnStore(context, preferences).saintProfile("st-joseph").reason)

        compose.onNodeWithText("Add an intention or thanks").performScrollTo().performClick()
        compose.onNodeWithText("Your note").performTextInput("Thank you for this day.")
        compose.onNodeWithText("Save").performClick()
        compose.onNodeWithContentDescription("Remove from My Saints").performScrollTo().performClick()
        val restored = JohnStore(context, preferences).saintProfile("st-joseph")
        assertFalse(restored.saved)
        assertEquals("Patience with my family.", restored.reason)
        assertEquals("Thank you for this day.", restored.notes.single().text)
    }

    @Test fun feastPlanPersistsWithoutCompletingPrayerDays() {
        // Pick an annual date outside its nine-day window, regardless of the test date.
        val saint = repo.personalSaints().first { candidate ->
            candidate.novenaID != null &&
                SaintDates.nextOccurrence(candidate.commemorations.first().monthDay).minusDays(9) > LocalDate.now()
        }
        compose.setContent { JohnTheme { SaintFeastScreen(saint.id, repo, store, {}, {}) } }
        compose.onNodeWithText("Plan this novena").performScrollTo().performClick()
        compose.onNodeWithText("Cancel novena plan").assertExists()
        val restored = JohnStore(context, preferences)
        assertEquals(SaintDates.nextOccurrence(saint.commemorations.first().monthDay).toString(),
            restored.saintProfile(saint.id).plannedFeastDate)
        assertTrue(restored.novena(saint.novenaID!!).completedDays.isEmpty())
        assertFalse(restored.saintProfile(saint.id).reminderEnabled)
    }
}
