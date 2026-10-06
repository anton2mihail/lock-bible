import XCTest

@MainActor
final class ContentFlowUITests: XCTestCase {
    private let featureDate = "2026-09-13T16:00:00Z"
    private let featureZone = "America/Toronto"
    private let sundayKey = "2026-09-13"
    private let prayerID = "morning"
    private let novenaID = "st-padre-pio"
    private let intention = "For patience and healing in my family."
    private let beforeReflection = "I will listen with patience."
    private let afterReflection = "I will carry mercy into the week."

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testL14PersistentContentSurvivesOneRelaunch() throws {
        let app = launchWithFeatureClock()
        NSLog("L14_EXPECTED prayerID=%@ sundayKey=%@ novenaID=%@ intention=%@ completedDays=[1] selectedDay=2 before=%@ after=%@",
              prayerID, sundayKey, novenaID, intention, beforeReflection, afterReflection)

        let morningPrayer = button(containing: "A morning offering", in: app)
        tapWhenReady(morningPrayer, in: app)
        XCTAssertTrue(app.staticTexts["content-page-title"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts["content-page-title"].label, "Morning offering")
        let favorite = app.buttons["prayer-favorite"]
        XCTAssertEqual(favorite.label, "Keep in favorites", "The fresh seed must not contain this favorite")
        tapWhenReady(favorite, in: app)
        let favoriteUpdated = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Remove from favorites"), object: favorite)
        XCTAssertEqual(XCTWaiter.wait(for: [favoriteUpdated], timeout: 8), .completed)
        tapWhenReady(app.buttons["content-back"], in: app)

        tapWhenReady(button(containing: "Come ready for Sunday", in: app), in: app)
        XCTAssertEqual(waitForPageTitle(app), "Come ready for Sunday")
        XCTAssertTrue(app.staticTexts["Sep 13, 2026"].waitForExistence(timeout: 5))
        let before = textView(label: "Before Mass reflection", in: app)
        let after = textView(label: "After Mass reflection", in: app)
        XCTAssertEqual(before.value as? String, "")
        XCTAssertEqual(after.value as? String, "")
        enterText(before, beforeReflection, in: app)
        enterText(after, afterReflection, in: app)
        tapWhenReady(app.buttons["Save reflection"], in: app)
        XCTAssertTrue(app.staticTexts["Reflection saved on this device."].waitForExistence(timeout: 8))
        tapWhenReady(app.buttons["content-back"], in: app)

        app.buttons["tab-pray"].tap()
        let novenaSearch = app.textFields.matching(NSPredicate(format: "label == %@", "Search novenas")).firstMatch
        XCTAssertTrue(novenaSearch.waitForExistence(timeout: 8))
        enterText(novenaSearch, "Padre Pio", in: app)
        tapWhenReady(button(containing: "St. Padre Pio Novena", in: app), in: app)
        XCTAssertTrue(app.staticTexts["St. Padre Pio Novena"].waitForExistence(timeout: 8))
        let intentionField = textView(label: "Your novena intention", in: app)
        enterText(intentionField, intention, in: app)
        tapWhenReady(app.buttons["Mark day 1 complete"], in: app)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@", "Day 1, complete")).firstMatch.waitForExistence(timeout: 8))
        let selectedDayTwo = app.buttons.matching(NSPredicate(format: "label == %@", "Day 2")).firstMatch
        XCTAssertTrue(selectedDayTwo.waitForExistence(timeout: 8))
        XCTAssertTrue(selectedDayTwo.isSelected)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))

        tapWhenReady(button(containing: "A morning offering", in: app), in: app)
        XCTAssertEqual(waitForPageTitle(app), "Morning offering")
        XCTAssertEqual(app.buttons["prayer-favorite"].label, "Remove from favorites")
        tapWhenReady(app.buttons["content-back"], in: app)
        tapWhenReady(button(containing: "Come ready for Sunday", in: app), in: app)
        XCTAssertEqual(waitForPageTitle(app), "Come ready for Sunday")
        XCTAssertEqual(textView(label: "Before Mass reflection", in: app).value as? String, beforeReflection)
        XCTAssertEqual(textView(label: "After Mass reflection", in: app).value as? String, afterReflection)
        tapWhenReady(app.buttons["content-back"], in: app)

        app.buttons["tab-pray"].tap()
        let reopenedSearch = app.textFields.matching(NSPredicate(format: "label == %@", "Search novenas")).firstMatch
        enterText(reopenedSearch, "Padre Pio", in: app)
        tapWhenReady(button(containing: "St. Padre Pio Novena", in: app), in: app)
        XCTAssertTrue(app.staticTexts["St. Padre Pio Novena"].waitForExistence(timeout: 8))
        XCTAssertEqual(textView(label: "Your novena intention", in: app).value as? String, intention)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@", "Day 1, complete")).firstMatch.exists)
        let restoredDayTwo = app.buttons.matching(NSPredicate(format: "label == %@", "Day 2")).firstMatch
        XCTAssertTrue(restoredDayTwo.waitForExistence(timeout: 8))
        XCTAssertTrue(restoredDayTwo.isSelected)
    }

    func testL15DatedRoutesGuidesAndLectioTimer() throws {
        let app = launchWithFeatureClock()
        let dailyCard = button(containing: "24th Sunday of Ordinary Time", in: app)
        tapWhenReady(dailyCard, in: app)
        XCTAssertEqual(waitForPageTitle(app), "Today’s readings")
        XCTAssertTrue(app.staticTexts["Sep 13, 2026"].waitForExistence(timeout: 5))
        let sirach = button(containing: "Sirach 27:30—28:7", in: app)
        tapWhenReady(sirach, in: app)
        XCTAssertEqual(waitForPageTitle(app), "Sirach 27")
        XCTAssertTrue(app.staticTexts["Reading reference: Sirach 27:30—28:7"].waitForExistence(timeout: 8))
        tapWhenReady(app.buttons["content-back"], in: app)

        tapWhenReady(app.buttons["content-back"], in: app)
        tapWhenReady(button(containing: "Come ready for Sunday", in: app), in: app)
        XCTAssertEqual(waitForPageTitle(app), "Come ready for Sunday")
        XCTAssertTrue(app.staticTexts["Sep 13, 2026"].exists)
        XCTAssertTrue(button(containing: "Sirach 27:30—28:7", in: app).exists)
        tapWhenReady(app.buttons["content-back"], in: app)

        app.buttons["tab-pray"].tap()
        tapWhenReady(button(containing: "Explore the Catholic faith", in: app), in: app)
        XCTAssertEqual(waitForPageTitle(app), "Faith, rooted in Scripture")
        tapWhenReady(button(containing: "The Eucharist", in: app), in: app)
        XCTAssertEqual(waitForPageTitle(app), "The Eucharist")
        tapWhenReady(app.buttons["content-back"], in: app)
        tapWhenReady(app.buttons["content-back"], in: app)

        tapWhenReady(button(containing: "Pray the Rosary", in: app), in: app)
        let rosarySets = [
            ("joyful", "The Joyful Mysteries", "Joyful"),
            ("sorrowful", "The Sorrowful Mysteries", "Sorrowful"),
            ("glorious", "The Glorious Mysteries", "Glorious"),
            ("luminous", "The Luminous Mysteries", "Luminous"),
        ]
        for (_, cardTitle, guideTitle) in rosarySets {
            let card = button(containing: cardTitle, in: app)
            XCTAssertTrue(card.waitForExistence(timeout: 8), "Missing Rosary set: \(cardTitle)")
            tapWhenReady(card, in: app)
            XCTAssertTrue(app.staticTexts[guideTitle].waitForExistence(timeout: 8))
            tapWhenReady(app.buttons["Close Rosary guide"], in: app)
        }
        let sevenSorrows = button(containing: "The Seven Sorrows of Mary", in: app)
        XCTAssertTrue(sevenSorrows.waitForExistence(timeout: 8))
        tapWhenReady(sevenSorrows, in: app)
        XCTAssertTrue(app.staticTexts["Seven Sorrows"].waitForExistence(timeout: 8))
        tapWhenReady(app.buttons["Close Rosary guide"], in: app)

        app.buttons["tab-today"].tap()
        let prayPassage = app.buttons.matching(NSPredicate(format: "label == %@", "Pray with this passage")).firstMatch
        XCTAssertTrue(prayPassage.waitForExistence(timeout: 10), "Today must show the rotating verse action")
        tapWhenReady(prayPassage, in: app)
        XCTAssertTrue(app.staticTexts["Read slowly"].waitForExistence(timeout: 10))
        tapWhenReady(app.buttons["Continue"], in: app)
        tapWhenReady(app.buttons["Continue"], in: app)
        tapWhenReady(app.buttons["Continue"], in: app)
        XCTAssertTrue(app.staticTexts["Rest in his presence"].waitForExistence(timeout: 5))
        tapWhenReady(app.buttons["Begin one quiet minute"], in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "60s of quiet")).firstMatch.waitForExistence(timeout: 5))
        tapWhenReady(app.buttons["End the timer"], in: app)
        XCTAssertTrue(app.staticTexts["A moment of stillness"].waitForExistence(timeout: 5))
    }

    func testL17RosaryGuideBackCompletionAndReset() throws {
        let app = launchWithFeatureClock()
        app.buttons["tab-pray"].tap()
        tapWhenReady(button(containing: "Pray the Rosary", in: app), in: app)
        tapWhenReady(button(containing: "The Joyful Mysteries", in: app), in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Joyful Mysteries")).firstMatch.waitForExistence(timeout: 8))
        let progress = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Progress")).firstMatch
        XCTAssertEqual(progress.value as? String, "0 percent")
        NSLog("L17_ROSARY expectedSession=joyful totalActions=80 stepCount=33 initial=0%% back=0%% complete=100%% reset=0%% sourceFixtureSHA=8da3d86f5bb284a197188e69292ef1f3b5507b51229c5bc5dc6c9ca97bdb2dee")

        tapWhenReady(nextRosaryAction(in: app), in: app)
        tapWhenReady(app.buttons["Previous"], in: app)
        XCTAssertEqual(progress.value as? String, "0 percent", "Previous must return to the initial step")
        let expectedSourceActionCount = 80
        for _ in 0..<expectedSourceActionCount {
            if app.staticTexts["ROSARY COMPLETE"].exists { break }
            tapWhenReady(nextRosaryAction(in: app), in: app)
        }
        XCTAssertTrue(app.staticTexts["ROSARY COMPLETE"].waitForExistence(timeout: 5),
                      "The Joyful source session has exactly 80 prayer actions")
        XCTAssertTrue(app.staticTexts["The Joyful Mysteries"].exists)
        XCTAssertTrue(app.buttons["Return to Rosary"].exists)
        XCTAssertTrue(app.buttons["Pray again"].exists)
        tapWhenReady(app.buttons["Pray again"], in: app)
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertEqual(progress.value as? String, "0 percent", "Pray again must reset the temporary guide state")
    }

    func testL18ConfessionNotesClearOnBackgroundAndFinish() throws {
        let app = launchWithFeatureClock()
        tapWhenReady(button(containing: "Prepare for Confession", in: app), in: app)
        XCTAssertEqual(waitForPageTitle(app), "Prepare")
        let notes = textView(label: "Temporary confession notes", in: app)
        let privateNote = "L18 temporary note 7341."
        enterText(notes, privateNote, in: app)
        XCTAssertTrue((notes.value as? String ?? "").contains(privateNote))

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertEqual(waitForPageTitle(app), "Prepare")
        XCTAssertFalse((textView(label: "Temporary confession notes", in: app).value as? String ?? "").contains(privateNote),
                       "Backgrounding the app must clear temporary notes")

        let routeExitNote = "L18 route exit note 9152."
        enterText(textView(label: "Temporary confession notes", in: app), routeExitNote, in: app)
        app.buttons["tab-pray"].tap()
        XCTAssertTrue(button(containing: "Pray the Rosary", in: app).waitForExistence(timeout: 8))
        app.buttons["tab-today"].tap()
        if app.staticTexts["today-title"].exists {
            tapWhenReady(button(containing: "Prepare for Confession", in: app), in: app)
        }
        XCTAssertEqual(waitForPageTitle(app), "Prepare")
        XCTAssertFalse((textView(label: "Temporary confession notes", in: app).value as? String ?? "").contains(routeExitNote),
                       "Leaving and re-entering the guide must clear temporary notes")

        let reopenedNotes = textView(label: "Temporary confession notes", in: app)
        enterText(reopenedNotes, privateNote, in: app)
        tapWhenReady(app.buttons["Continue"], in: app)
        tapWhenReady(app.buttons["Continue"], in: app)
        XCTAssertEqual(waitForPageTitle(app), "Confess your sins")
        XCTAssertTrue(app.staticTexts["Your private notes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[privateNote].exists, "Notes must remain during internal guide steps")

        tapWhenReady(app.buttons["Continue"], in: app)
        tapWhenReady(app.buttons["Continue"], in: app)
        XCTAssertEqual(waitForPageTitle(app), "Go in peace")
        tapWhenReady(app.buttons["Finish & clear notes"], in: app)
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 8))
        tapWhenReady(button(containing: "Prepare for Confession", in: app), in: app)
        XCTAssertEqual(waitForPageTitle(app), "Prepare")
        XCTAssertFalse((textView(label: "Temporary confession notes", in: app).value as? String ?? "").contains(privateNote),
                       "Re-entry after Finish must not restore temporary notes")
    }

    private func launchWithFeatureClock() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-L14FeatureDate", featureDate,
                               "-L14FeatureTimeZone", featureZone]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))
        return app
    }

    private func waitForPageTitle(_ app: XCUIApplication) -> String {
        let title = app.staticTexts["content-page-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        return title.label
    }

    private func button(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func textView(label: String, in app: XCUIApplication) -> XCUIElement {
        let field = app.textViews.matching(NSPredicate(format: "label == %@", label)).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8), "Missing text input: \(label)")
        return field
    }

    private func enterText(_ element: XCUIElement, _ value: String, in app: XCUIApplication) {
        tapWhenReady(element, in: app)
        element.typeText(value)
    }

    private func nextRosaryAction(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Complete ", "Begin this ")).firstMatch
    }

    private func tapWhenReady(_ element: XCUIElement, in app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Control did not appear", file: file, line: line)
        for _ in 0..<8 where !element.isHittable {
            let viewport = app.scrollViews.allElementsBoundByIndex
                .filter { $0.exists && $0.isHittable }
                .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
            let viewportFrame = viewport?.frame ?? app.frame
            if element.frame.maxY < viewportFrame.minY { app.swipeDown() }
            else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable, "Control is not hittable", file: file, line: line)
        element.tap()
    }
}
