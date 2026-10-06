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

    }

    func testL15PrayerHomeRosarySetsSevenSorrowsAndLectioTimer() throws {
        let app = launchWithFeatureClock()
        app.buttons["tab-pray"].tap()
        let rosaryHome = button(containing: "Pray the Rosary", in: app)
        XCTAssertTrue(rosaryHome.waitForExistence(timeout: 8), "Start from PrayerHome")
        tapWhenReady(rosaryHome, in: app)
        let rosarySets = [
            ("joyful", "The Joyful Mysteries", "Joyful"),
            ("sorrowful", "The Sorrowful Mysteries", "Sorrowful"),
            ("glorious", "The Glorious Mysteries", "Glorious"),
            ("luminous", "The Luminous Mysteries", "Luminous"),
        ]
        for (setID, cardTitle, guideTitle) in rosarySets {
            let card = button(containing: cardTitle, in: app)
            XCTAssertTrue(card.waitForExistence(timeout: 8), "Missing Rosary set \(setID): \(cardTitle)")
            tapWhenReady(card, in: app)
            XCTAssertTrue(app.staticTexts[guideTitle].waitForExistence(timeout: 8))
            tapWhenReady(app.buttons["Close Rosary guide"], in: app)
        }
        let sevenSorrows = button(containing: "The Seven Sorrows of Mary", in: app)
        XCTAssertTrue(sevenSorrows.waitForExistence(timeout: 8))
        tapWhenReady(sevenSorrows, in: app)
        XCTAssertTrue(app.staticTexts["Seven Sorrows"].waitForExistence(timeout: 8))
        tapWhenReady(app.buttons["Close Rosary guide"], in: app)

        app.buttons["tab-pray"].tap()
        tapWhenReady(button(containing: "Pray with Scripture", in: app), in: app)
        XCTAssertTrue(app.staticTexts["Read slowly"].waitForExistence(timeout: 10))
        tapWhenReady(app.buttons["Continue"], in: app)
        tapWhenReady(app.buttons["Continue"], in: app)
        tapWhenReady(app.buttons["Continue"], in: app)
        XCTAssertTrue(app.staticTexts["Rest in his presence"].waitForExistence(timeout: 5))
        tapWhenReady(app.buttons["Begin one quiet minute"], in: app)
        let countdown = app.staticTexts.matching(NSPredicate(
            format: "label MATCHES %@", "^([1-9]|[1-5][0-9]|60)s of quiet$"
        )).firstMatch
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        let initialSeconds = Int(countdown.label.split(separator: "s").first ?? "")
        let decreased = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard countdown.exists, let initialSeconds,
                  let current = Int(countdown.label.split(separator: "s").first ?? "") else { return false }
            return current < initialSeconds
        }, object: countdown)
        XCTAssertEqual(XCTWaiter.wait(for: [decreased], timeout: 5), .completed,
                       "The displayed timer value must decrease")
        tapWhenReady(app.buttons["End the timer"], in: app)
        XCTAssertTrue(app.staticTexts["A moment of stillness"].waitForExistence(timeout: 5))
    }

    func testL17RosaryGuideBackCompletionAndReset() throws {
        let app = launchWithFeatureClock()
        app.buttons["tab-pray"].tap()
        tapWhenReady(button(containing: "Pray the Rosary", in: app), in: app)
        tapWhenReady(button(containing: "The Joyful Mysteries", in: app), in: app)
        XCTAssertTrue(app.staticTexts["Joyful"].waitForExistence(timeout: 8))
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

    // MARK: Step 7 checks
    // Each test runs only when STEP7_CASES lists its case name. Default runs skip them.
    // See docs/native/reviews/Step7-remaining-feature-checks-plan.md.

    private func requireStep7(_ name: String) throws {
        let listed = (ProcessInfo.processInfo.environment["STEP7_CASES"] ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard listed.contains(name) else { throw XCTSkip("Set STEP7_CASES=\(name) to run this Step 7 check.") }
    }

    /// Fixed feature clock by default (same as the L14 and L15 tests). STEP7_REAL_CLOCK=1 uses the device clock.
    private func step7Launch() -> XCUIApplication {
        guard ProcessInfo.processInfo.environment["STEP7_REAL_CLOCK"] == "1" else { return launchWithFeatureClock() }
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))
        return app
    }

    private func step7DismissShareSheet(copy: XCUIElement, in app: XCUIApplication) {
        let close = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Close", "Cancel")).firstMatch
        if close.exists && close.isHittable { close.tap() } else { copy.swipeDown() }
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: copy)
        if XCTWaiter.wait(for: [gone], timeout: 6) != .completed {
            // An iPad share popover closes when the user taps outside it.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.02)).tap()
        }
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 8), .completed, "The share panel must close without Copy")
    }

    private func step7Attach(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Verse Moment: countdown text, widget guide steps and durable dismissal, Share, Scripture card, Read in context.
    /// Expected values (optional): STEP7_VERSE_REFERENCE, STEP7_VERSE_TEXT_PREFIX, STEP7_VERSE_ABBREVIATION,
    /// STEP7_VERSE_READER_TITLE. Source: DestinationView.swift VerseMomentDestination; src/screens/VerseOfDayScreen.tsx.
    func testStep7VerseMomentControlsGuideShareCardAndContext() throws {
        try requireStep7("verse-moment")
        let env = ProcessInfo.processInfo.environment
        let app = step7Launch()
        tapWhenReady(app.buttons["today-verse-card"], in: app)
        XCTAssertEqual(waitForPageTitle(app), "Verse of the moment")
        let countdown = app.staticTexts.matching(NSPredicate(
            format: "label MATCHES %@", "^New verse in ([0-9]+ min|[0-9]+h|[0-9]+h [0-9]+m)$")).firstMatch
        XCTAssertTrue(countdown.waitForExistence(timeout: 8), "The countdown must use the source wording")
        if let reference = env["STEP7_VERSE_REFERENCE"] {
            XCTAssertTrue(app.staticTexts[reference].waitForExistence(timeout: 8), "Expected verse reference \(reference)")
        }
        if let prefix = env["STEP7_VERSE_TEXT_PREFIX"] {
            let text = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "“" + prefix)).firstMatch
            XCTAssertTrue(text.waitForExistence(timeout: 8), "Expected verse text prefix \(prefix)")
        }
        if let abbreviation = env["STEP7_VERSE_ABBREVIATION"] {
            XCTAssertTrue(app.staticTexts[abbreviation].exists, "Expected edition label \(abbreviation)")
        }

        let dismiss = app.buttons["verse-widget-guide-dismiss"]
        let guideShown = dismiss.waitForExistence(timeout: 3)
        if guideShown {
            XCTAssertTrue(app.staticTexts["Put Scripture on your lock screen"].exists)
            let steps = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "1. Touch and hold your lock screen")).firstMatch
            XCTAssertFalse(steps.exists, "Steps must start collapsed")
            tapWhenReady(app.buttons["How to add it"], in: app)
            XCTAssertTrue(steps.waitForExistence(timeout: 5), "How to add it must show the four steps")
            XCTAssertTrue(steps.label.contains("4. Use the rectangular size when you want the full verse text."))
            tapWhenReady(app.buttons["Hide steps"], in: app)
            XCTAssertTrue(steps.waitForNonExistence(timeout: 5), "Hide steps must collapse the steps")
            tapWhenReady(dismiss, in: app)
            XCTAssertTrue(app.staticTexts["Put Scripture on your lock screen"].waitForNonExistence(timeout: 8),
                          "Got it must remove the guide")
        }
        NSLog("STEP7_VERSE_MOMENT guideShownAtStart=%d countdown=%@", guideShown ? 1 : 0, countdown.label)

        tapWhenReady(app.buttons["verse-moment-share"], in: app)
        let copy = app.cells.matching(NSPredicate(format: "label == %@", "Copy")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 15), "The native share panel must open")
        NSLog("STEP7_VERSE_MOMENT shareOpened popover=%d", app.popovers.firstMatch.exists ? 1 : 0)
        step7Attach("step7-verse-moment-share", app: app)
        step7DismissShareSheet(copy: copy, in: app)

        tapWhenReady(app.buttons["verse-moment-scripture-card"], in: app)
        XCTAssertEqual(waitForPageTitle(app), "A word worth sharing")
        if let reference = env["STEP7_VERSE_REFERENCE"] {
            let card = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", reference)).firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 8), "The card must keep the displayed verse reference")
        }
        step7Attach("step7-verse-moment-card", app: app)
        tapWhenReady(app.buttons["content-back"], in: app)

        tapWhenReady(app.buttons["verse-moment-read-context"], in: app)
        let title = app.buttons["reader-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 12), "Read in context must open the Reader")
        if let expectedTitle = env["STEP7_VERSE_READER_TITLE"] { XCTAssertEqual(title.label, expectedTitle) }
        XCTAssertTrue(app.staticTexts["reader-selection-summary"].waitForExistence(timeout: 10),
                      "The displayed verse must be selected in the Reader")
        step7Attach("step7-verse-moment-reader", app: app)

        if guideShown {
            app.terminate()
            let relaunched = step7Launch()
            tapWhenReady(relaunched.buttons["today-verse-card"], in: relaunched)
            XCTAssertEqual(waitForPageTitle(relaunched), "Verse of the moment")
            XCTAssertFalse(relaunched.buttons["verse-widget-guide-dismiss"].waitForExistence(timeout: 3),
                           "The guide dismissal must survive a fresh process")
            NSLog("STEP7_VERSE_MOMENT guideDismissalDurable=true")
        }
    }

    /// External URL fallbacks match the old app (Expo Router), not a silent ignore. Source:
    /// src/services/companion/calendar.ts:13-18 parseDate (bad or missing date gives today's readings);
    /// src/screens/ReaderScreen.tsx:289 (unknown book leaves the Reader as it was), :302-307 (bad chapter shows the
    /// book's chapter list); the old route reads only book, chapter, verse, endVerse (translation is ignored).
    /// The fixed feature clock is 2026-09-13T16:00Z Toronto, so "today" is Sep 13, 2026.
    func testStep7ExternalURLFallbacksMatchSource() throws {
        try requireStep7("url-fallbacks")
        let app = step7Launch()
        let todayLabel = "Sep 13, 2026"

        func backToToday() {
            app.buttons["tab-today"].tap()
            for _ in 0..<3 where !app.staticTexts["today-title"].isHittable {
                let back = app.buttons["content-back"]
                if back.exists && back.isHittable { back.tap() } else { break }
            }
            XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 8))
        }
        func readerState() -> String {
            if app.staticTexts["reader-book-list-title"].exists { return "books" }
            if app.buttons["reader-title"].exists { return "title:" + app.buttons["reader-title"].label }
            if app.scrollViews["reader-chapter-grid-scroll"].exists { return "chapters" }
            return "unknown"
        }
        func readTabContentVisible() -> Bool {
            app.staticTexts["reader-book-list-title"].exists || app.buttons["reader-title"].exists
                || app.scrollViews["reader-chapter-grid-scroll"].exists
        }

        // 1. Daily: a bad day, a bad format, and a missing date all open today's readings.
        for text in ["nrsv://daily?date=2026-02-30", "nrsv://daily?date=2026-9-1", "nrsv://daily"] {
            app.open(URL(string: text)!)
            XCTAssertEqual(waitForPageTitle(app), "Today’s readings", "Daily fallback must open readings: \(text)")
            XCTAssertTrue(app.staticTexts[todayLabel].waitForExistence(timeout: 8), "The fallback date must be today: \(text)")
            NSLog("STEP7_URL_FALLBACK url=%@ result=daily-today", text)
            backToToday()
        }

        // 2. Read without verse: the chapter opens at its top with no selection.
        app.open(URL(string: "nrsv://read?book=JHN&chapter=3")!)
        XCTAssertTrue(app.buttons["reader-title"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["reader-title"].label, "John 3")
        XCTAssertTrue(app.buttons["reader-verse-1"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["reader-selection-summary"].waitForExistence(timeout: 3), "No verse means no selection")
        NSLog("STEP7_URL_FALLBACK url=read-no-verse result=chapter-top-no-selection")
        backToToday()

        // 3. Empty endVerse is absent: one verse is selected.
        app.open(URL(string: "nrsv://read?book=JHN&chapter=3&verse=16&endVerse=")!)
        XCTAssertEqual(app.staticTexts["reader-selection-summary"].waitForExistence(timeout: 15) ? app.staticTexts["reader-selection-summary"].label : "none",
                       "Selected: verses 16–16")
        backToToday()

        // 4. An unknown translation value is ignored. The current edition (WEB-CE) opens.
        app.open(URL(string: "nrsv://read?book=JHN&chapter=3&verse=16&translation=unknown")!)
        XCTAssertTrue(app.buttons["reader-title"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["reader-title"].label, "John 3")
        XCTAssertEqual(app.staticTexts["reader-selection-summary"].waitForExistence(timeout: 10) ? app.staticTexts["reader-selection-summary"].label : "none",
                       "Selected: verses 16–16")
        backToToday()

        // 5. A known book with a chapter out of range, not a number, or missing opens the Read tab with that book's
        // chapter list (src/screens/ReaderScreen.tsx:292-308: Number(NaN) is invalid, so the chapter list shows).
        for text in ["nrsv://read?book=JHN&chapter=999&verse=1", "nrsv://read?book=JHN&chapter=0&verse=1",
                     "nrsv://read?book=JHN&chapter=abc&verse=1", "nrsv://read?book=JHN&verse=1"] {
            app.open(URL(string: text)!)
            XCTAssertTrue(app.scrollViews["reader-chapter-grid-scroll"].waitForExistence(timeout: 15), "Chapter list expected: \(text)")
            XCTAssertTrue(app.buttons["reader-chapter-1"].exists)
            XCTAssertEqual(app.buttons["reader-back"].label, "Back to books")
            XCTAssertFalse(app.staticTexts["today-title"].isHittable)
            NSLog("STEP7_URL_FALLBACK url=%@ result=chapter-list", text)
            backToToday()
        }

        // 6. Only an unknown or missing book selects the Read tab and keeps the Reader state (ReaderScreen.tsx:289).
        app.buttons["tab-read"].tap()
        _ = app.staticTexts["reader-book-list-title"].waitForExistence(timeout: 8)
        let before = readerState()
        backToToday()
        for text in ["nrsv://read?book=ZZZ&chapter=1&verse=1"] {
            app.open(URL(string: text)!)
            let appeared = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in readTabContentVisible() }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [appeared], timeout: 15), .completed, "The Read tab must be selected: \(text)")
            XCTAssertEqual(readerState(), before, "The Reader must keep its earlier state: \(text)")
            XCTAssertFalse(app.staticTexts["today-title"].isHittable)
            NSLog("STEP7_URL_FALLBACK url=%@ result=read-tab-only state=%@", text, before)
            backToToday()
        }

        // 7. Another host is ignored. Today stays.
        app.open(URL(string: "nrsv://unknown?x=1")!)
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(app.staticTexts["today-title"].isHittable, "An unknown host must be ignored")

        // 8. A valid URL still opens the verse.
        app.open(URL(string: "nrsv://read?book=JHN&chapter=1&verse=1")!)
        XCTAssertTrue(app.buttons["reader-verse-1"].waitForExistence(timeout: 15), "A valid URL must still open the Reader")
    }

    /// The one-line message uses the existing Saved status line (app commit 090bf12).
    private let savedOpenFailureMessageIdentifier = "saved-status"

    /// F2 decided: a saved passage or note that cannot open stays on Saved and shows one line, "This passage could not be opened."
    /// The line is the Saved status line (`saved-status`). A note row also checks that its passage loads before the editor opens.
    /// Trigger (bundle fault, no app change): stop the dev app, then run
    ///   inject_bundle_fault.py apply --fault chapter-missing --edition web-ce --book JHN ...
    /// The L25 native fixture holds a WEB-CE John 1:1 bookmark and a note on the same passage (`web-ce:JHN:1:1:1`),
    /// so both rows need the missing chapter file. Alternative: a damaged seed row (Step 7 plan, F2).
    /// Fault-injected: bundle file removed; task-only dev build; not a natural failure. Restore after the run.
    /// STEP7_SAVED_ROW_REFERENCE (default "John 1:1") selects the rows by label.
    /// STEP7_SAVED_NOTE_CASE=0 skips the note row part.
    func testStep7SavedOpenFailureStaysOnSavedWithMessage() throws {
        try requireStep7("saved-open-failure")
        let env = ProcessInfo.processInfo.environment
        let reference = env["STEP7_SAVED_ROW_REFERENCE"] ?? "John 1:1"
        let message = "This passage could not be opened."
        let app = step7Launch()
        tapWhenReady(app.buttons["tab-saved"], in: app)
        XCTAssertTrue(app.buttons["saved-filter-bookmark"].waitForExistence(timeout: 10), "The Saved tab must open")

        func status() -> XCUIElement {
            app.descendants(matching: .any).matching(identifier: savedOpenFailureMessageIdentifier).firstMatch
        }
        func assertStayedOnSaved(_ kind: String) {
            let line = status()
            XCTAssertTrue(line.waitForExistence(timeout: 10), "The failed \(kind) open must show one line")
            XCTAssertEqual(line.label, message)
            XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", message)).count, 1, "Show the message once")
            // The Saved tab stays selected: the Saved controls stay and no Reader, editor, or Today screen appears.
            XCTAssertTrue(app.buttons["saved-filter-bookmark"].isHittable, "The Saved tab must stay selected")
            XCTAssertFalse(app.buttons["reader-title"].exists, "The Reader must not open")
            XCTAssertFalse(app.staticTexts["reader-book-list-title"].exists, "The Reader must not open")
            XCTAssertFalse(app.textViews["saved-note-editor"].exists, "The note editor must not open")
            XCTAssertFalse(app.staticTexts["today-title"].isHittable)
            step7Attach("step7-saved-open-failure-\(kind)", app: app)
            NSLog("STEP7_SAVED_OPEN_FAILURE kind=%@ message=%@ stayedOnSaved=true", kind, message)
        }

        tapWhenReady(app.buttons["saved-filter-bookmark"], in: app)
        let bookmarkRow = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "saved-row-bookmark:", reference)).firstMatch
        XCTAssertTrue(bookmarkRow.waitForExistence(timeout: 10), "No saved bookmark row for \(reference). Use the L25 native fixture.")
        tapWhenReady(bookmarkRow, in: app)
        assertStayedOnSaved("bookmark")

        guard env["STEP7_SAVED_NOTE_CASE"] != "0" else { return }
        let noteFilter = app.buttons["saved-filter-note"]
        tapWhenReady(noteFilter, in: app)
        let noteRow = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "saved-row-note:", reference)).firstMatch
        XCTAssertTrue(noteRow.waitForExistence(timeout: 10), "No saved note row for \(reference). Use the L25 native fixture.")
        tapWhenReady(noteRow, in: app)
        assertStayedOnSaved("note")
    }

    /// Error states through a changed task-only development bundle. Set STEP7_FAULT to the fault that
    /// scripts/native/source-fixtures/step7/inject_bundle_fault.py applied. The test names the expected text.
    /// STEP7_FAULT_BOOK and STEP7_FAULT_CHAPTER (default JHN and 1) apply to chapter-missing.
    func testStep7BundleFaultMessage() throws {
        try requireStep7("bundle-fault")
        let env = ProcessInfo.processInfo.environment
        guard let fault = env["STEP7_FAULT"] else { XCTFail("Set STEP7_FAULT"); return }
        let app = step7Launch()
        switch fault {
        case "chapter-missing":
            let book = env["STEP7_FAULT_BOOK"] ?? "JHN"
            let chapter = env["STEP7_FAULT_CHAPTER"] ?? "1"
            app.buttons["tab-read"].tap()
            let bookList = app.staticTexts["reader-book-list-title"]
            for _ in 0..<3 where !bookList.exists {
                let back = app.buttons["reader-back"]
                XCTAssertTrue(back.waitForExistence(timeout: 8))
                back.tap()
            }
            tapWhenReady(app.buttons["reader-book-\(book)"], in: app)
            tapWhenReady(app.buttons["reader-chapter-\(chapter)"], in: app)
            XCTAssertTrue(app.staticTexts["Chapter unavailable"].waitForExistence(timeout: 12))
            XCTAssertTrue(app.staticTexts["This chapter is not available."].exists)
            XCTAssertTrue(app.buttons["reader-back"].exists, "The Reader must keep its Back control")
            step7Attach("step7-fault-chapter-missing", app: app)
        case "artwork-ivory-missing", "artwork-plum-missing":
            tapWhenReady(app.buttons["today-verse-card"], in: app)
            XCTAssertEqual(waitForPageTitle(app), "Verse of the moment")
            tapWhenReady(app.buttons["verse-moment-scripture-card"], in: app)
            XCTAssertEqual(waitForPageTitle(app), "A word worth sharing")
            if fault == "artwork-plum-missing" { tapWhenReady(app.buttons["Evening plum"], in: app) }
            XCTAssertTrue(app.staticTexts["Artwork could not load. You can still share the words on a plain background."]
                .waitForExistence(timeout: 8))
            step7Attach("step7-fault-\(fault)", app: app)
            tapWhenReady(app.buttons["scripture-card-share-image"], in: app)
            let copy = app.cells.matching(NSPredicate(format: "label == %@", "Copy")).firstMatch
            XCTAssertTrue(copy.waitForExistence(timeout: 15), "The words must still share on a plain background")
            step7DismissShareSheet(copy: copy, in: app)
        case "rosary-catalog-invalid":
            app.buttons["tab-pray"].tap()
            tapWhenReady(button(containing: "Pray the Rosary", in: app), in: app)
            XCTAssertTrue(app.staticTexts["The Rosary catalog is not available right now."].waitForExistence(timeout: 10))
            step7Attach("step7-fault-rosary-catalog", app: app)
        case "prayer-catalog-invalid":
            app.buttons["tab-pray"].tap()
            XCTAssertTrue(app.staticTexts["The prayer library is not available."].waitForExistence(timeout: 10))
            step7Attach("step7-fault-prayer-catalog", app: app)
        case "works-catalog-missing":
            app.buttons["tab-read"].tap()
            let bookList = app.staticTexts["reader-book-list-title"]
            for _ in 0..<3 where !bookList.exists {
                let back = app.buttons["reader-back"]
                XCTAssertTrue(back.waitForExistence(timeout: 8))
                back.tap()
            }
            tapWhenReady(app.buttons["reader-works-link"], in: app)
            XCTAssertTrue(app.staticTexts["The library could not be opened on this device."].waitForExistence(timeout: 10))
            step7Attach("step7-fault-works-catalog", app: app)
        case "search-db-missing":
            tapWhenReady(app.buttons["tab-read"], in: app)
            let search = app.buttons["reader-search-button"]
            if !search.exists {
                let bookList = app.staticTexts["reader-book-list-title"]
                for _ in 0..<3 where !bookList.exists {
                    let back = app.buttons["reader-back"]
                    XCTAssertTrue(back.waitForExistence(timeout: 8))
                    back.tap()
                }
            }
            tapWhenReady(app.buttons["reader-search-button"], in: app)
            let field = app.textFields["search-query-input"]
            XCTAssertTrue(field.waitForExistence(timeout: 10))
            field.typeText("mercy")
            XCTAssertTrue(app.staticTexts["Search could not be completed. Try a different phrase."].waitForExistence(timeout: 15))
            step7Attach("step7-fault-search-db", app: app)
        case "reading-reference-invalid":
            tapWhenReady(app.buttons["today-readings-card"], in: app)
            let row = button(containing: "Nonexistent 99:1", in: app)
            tapWhenReady(row, in: app)
            XCTAssertTrue(app.staticTexts["This reference could not be opened. You can find the passage using Bible search."]
                .waitForExistence(timeout: 10))
            step7Attach("step7-fault-reading-reference", app: app)
            tapWhenReady(app.buttons["Search the Bible"], in: app)
            XCTAssertTrue(app.textFields["search-query-input"].waitForExistence(timeout: 10), "Search the Bible must open Search")
        default:
            XCTFail("Unknown STEP7_FAULT: \(fault)")
        }
        NSLog("STEP7_FAULT fault=%@ observed=true", fault)
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
            let viewportFrame = visibleScrollViewport(in: app)
            XCTAssertGreaterThan(viewportFrame.height, 80, "No safe scroll area is visible", file: file, line: line)
            let oldFrame = element.frame
            let direction: CGFloat = oldFrame.midY < viewportFrame.minY ? -1 : 1
            let keyboard = app.keyboards.firstMatch
            let oldKeyboardFrame = keyboard.exists ? keyboard.frame : nil
            let centerX = viewportFrame.midX
            let lowerY = viewportFrame.minY + viewportFrame.height * 0.75
            let upperY = viewportFrame.minY + viewportFrame.height * 0.25
            let startY = direction > 0 ? lowerY : upperY
            let endY = direction > 0 ? upperY : lowerY
            NSLog("L14_SCROLL viewport=%@ keyboard=%@ target=%@ direction=%@",
                  frameDescription(viewportFrame),
                  app.keyboards.firstMatch.exists ? frameDescription(app.keyboards.firstMatch.frame) : "none",
                  frameDescription(oldFrame), direction > 0 ? "up" : "down")
            coordinate(in: app, x: centerX, y: startY)
                .press(forDuration: 0.05, thenDragTo: coordinate(in: app, x: centerX, y: endY))
            let moved = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in
                    element.frame != oldFrame || (keyboard.exists ? keyboard.frame : nil) != oldKeyboardFrame
                }, object: element)
            XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 2), .completed,
                           "Target and keyboard did not move after the gesture", file: file, line: line)
        }
        XCTAssertTrue(element.isHittable, "Control is not hittable", file: file, line: line)
        element.tap()
    }

    private func visibleScrollViewport(in app: XCUIApplication) -> CGRect {
        let scroll = app.scrollViews.allElementsBoundByIndex
            .filter { $0.exists && $0.isHittable }
            .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
        var viewport = (scroll?.frame ?? app.frame).intersection(app.frame)
        if app.keyboards.firstMatch.exists {
            viewport.size.height = min(viewport.height, app.keyboards.firstMatch.frame.minY - viewport.minY)
        }
        let tab = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tab-")).allElementsBoundByIndex
            .filter { $0.exists && $0.frame.intersects(viewport) }
            .map(\.frame.minY).min()
        if let tab { viewport.size.height = min(viewport.height, tab - viewport.minY) }
        let navigationBottom = app.navigationBars.allElementsBoundByIndex
            .filter { $0.exists && $0.frame.intersects(viewport) }
            .map(\.frame.maxY).max()
        if let navigationBottom {
            let clippedTop = max(viewport.minY, navigationBottom)
            viewport = CGRect(x: viewport.minX, y: clippedTop,
                              width: viewport.width, height: max(0, viewport.maxY - clippedTop))
        }
        return viewport
    }

    private func coordinate(in app: XCUIApplication, x: CGFloat, y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: x / app.frame.width, dy: y / app.frame.height))
    }

    private func frameDescription(_ frame: CGRect) -> String {
        "(\(frame.origin.x),\(frame.origin.y),\(frame.width),\(frame.height))"
    }
}
