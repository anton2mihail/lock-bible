import XCTest

/// Focused Reader checks for URL context, saved Reader state, bookmarks, Aa background taps, and the Aa reflow check.
/// Main must provide a fresh task-only WEB-CE seed. The bookmark check creates a JHN 3:16 bookmark in the UI.
@MainActor
final class ReaderRegressionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testColdURLContextSurvivesLaunchAndSettles() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))
        app.terminate()
        XCTAssertEqual(app.state, .notRunning, "The app must be stopped before URL delivery")

        app.open(contextURL(verse: 16))
        let request = assertContextVerse(16, in: app, label: "cold-url")
        XCTAssertEqual(app.state, .runningForeground, "Cold URL delivery must launch the app")
        Thread.sleep(forTimeInterval: 2.2)
        XCTAssertEqual(readerRequest(in: app), request, "The cold URL request must stay current after launch")
        assertContextVerseStillVisible(16, in: app, label: "cold-url-after-settle")
        NSLog("READER_CONTEXT coldURL=true state=runningForeground request=%@ stableSeconds=2.2", request)
    }

    func testContextURLFromEachOriginTab() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))
        let tabs = ["tab-today", "tab-read", "tab-saved", "tab-pray", "tab-settings"]
        var previousRequest: String?

        for tab in tabs {
            tapTab(tab, in: app)
            XCTAssertTrue(tabElement(tab, in: app).isSelected, "The origin tab must be selected before URL delivery: \(tab)")
            app.open(contextURL(verse: 16))
            let request = assertContextVerse(16, in: app, label: "origin-\(tab)", previousRequest: previousRequest)
            if let previousRequest {
                XCTAssertNotEqual(request, previousRequest, "Each URL delivery must create a fresh Reader request")
            }
            previousRequest = request
            Thread.sleep(forTimeInterval: 2.2)
            XCTAssertEqual(readerRequest(in: app), request,
                           "The request from \(tab) must stay current after settling")
            assertContextVerseStillVisible(16, in: app, label: "origin-\(tab)-after-settle")
        }
    }

    func testSavedBookmarkOpensNonTopContextVerseWithoutSelection() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))

        app.open(contextURL(verse: 16))
        XCTAssertTrue(app.buttons["reader-title"].waitForExistence(timeout: 12))
        XCTAssertEqual(app.buttons["reader-title"].label, "John 3")
        let verse = app.buttons["reader-verse-16"]
        XCTAssertTrue(verse.waitForExistence(timeout: 10))
        XCTAssertTrue(verse.isHittable)
        verse.tap()
        let summary = app.staticTexts["reader-selection-summary"]
        let exactSelection = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Selected: verses 16–16"), object: summary)
        XCTAssertEqual(XCTWaiter.wait(for: [exactSelection], timeout: 8), .completed,
                       "The bookmark action must apply to verse 16 only")
        let bookmark = app.buttons["reader-selection-bookmark"]
        XCTAssertTrue(bookmark.waitForExistence(timeout: 8))
        XCTAssertEqual(bookmark.value as? String, "Not selected", "The L25 seed must not contain a John 3:16 bookmark")
        bookmark.tap()
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Selected"), object: bookmark)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 8), .completed, "John 3:16 bookmark must save")

        app.open(URL(string: "nrsv://read?book=JHN&chapter=1&verse=1")!)
        let johnOneTitle = app.buttons["reader-title"]
        let johnOne = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "John 1"), object: johnOneTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [johnOne], timeout: 15), .completed,
                       "Move the Reader away from John 3 before opening Saved")
        tapTab("tab-saved", in: app)
        let bookmarkFilter = app.buttons["saved-filter-bookmark"]
        XCTAssertTrue(bookmarkFilter.waitForExistence(timeout: 10))
        bookmarkFilter.tap()
        let row = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "saved-row-bookmark:", "John 3:16")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The seed must contain a WEB-CE John 3:16 bookmark")
        row.tap()

        let title = app.buttons["reader-title"]
        let johnThree = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "John 3"), object: title)
        XCTAssertEqual(XCTWaiter.wait(for: [johnThree], timeout: 12), .completed, "The saved bookmark must open John 3")
        let request = readerRequest(in: app)
        XCTAssertNotNil(UUID(uuidString: request), "The saved item must create a real Reader request UUID")
        assertContextVerseStillVisible(16, in: app, label: "saved-bookmark")
        Thread.sleep(forTimeInterval: 2.2)
        XCTAssertEqual(readerRequest(in: app), request, "The saved bookmark request must stay current after settling")
        assertContextVerseStillVisible(16, in: app, label: "saved-bookmark-after-settle")
        XCTAssertFalse(app.staticTexts["reader-selection-summary"].exists,
                       "Opening a saved bookmark must show context, not an active selection")
        NSLog("READER_CONTEXT savedBookmark=web-ce:JHN:3:16:16 createdInUI=true verse=16 request=%@ stableSeconds=2.2 selection=absent", request)
    }

    func testSavedReaderPositionWinsWhenReturningToReadTab() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))

        app.open(contextURL(verse: 16))
        let contextRequest = assertContextVerse(16, in: app, label: "saved-position-context")

        // Leave the explicit John 3:16 request through the Reader controls.
        let bookList = app.staticTexts["reader-book-list-title"]
        for _ in 0..<3 where !bookList.exists {
            let back = app.buttons["reader-back"]
            XCTAssertTrue(back.waitForExistence(timeout: 8), "Return to the Reader book list")
            back.tap()
        }
        XCTAssertTrue(bookList.waitForExistence(timeout: 8))
        let john = app.buttons["reader-book-JHN"]
        XCTAssertTrue(john.waitForExistence(timeout: 10))
        john.tap()
        let chapterOne = app.buttons["reader-chapter-1"]
        XCTAssertTrue(chapterOne.waitForExistence(timeout: 10))
        chapterOne.tap()

        let title = app.buttons["reader-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 12))
        XCTAssertEqual(title.label, "John 1", "The UI navigation must leave the Reader at John 1")
        XCTAssertNotEqual(readerRequest(in: app), contextRequest,
                          "Opening John 1 must replace the explicit John 3:16 request")
        let priorAnchor = anchorToken(in: title)

        // Scroll from the visible John 1 text so the app saves a new Reader anchor.
        let reader = app.scrollViews["reader-chapter-scroll"]
        XCTAssertTrue(reader.waitForExistence(timeout: 10))
        let verseFive = app.buttons["reader-verse-5"]
        XCTAssertTrue(verseFive.waitForExistence(timeout: 8))
        for _ in 0..<8 where !verseFive.isHittable { reader.swipeUp() }
        XCTAssertTrue(verseFive.isHittable, "John 1:5 must be reachable before saving a Reader position")
        reader.swipeUp()
        let savedAnchorValue = waitForNewNonTopAnchor(title, after: priorAnchor, timeout: 10)
        XCTAssertNotNil(savedAnchorValue, "Reader scrolling must save a new non-top verse and text offset")
        guard let savedAnchorValue,
              let savedToken = savedAnchorValue.components(separatedBy: "anchor=").last?.components(separatedBy: ";").first,
              let savedVerse = Int(savedToken.split(separator: ":").first ?? "") else { return }
        XCTAssertGreaterThan(savedVerse, 1, "The saved Reader anchor must differ from the top of John 1")
        tapTab("tab-today", in: app)
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))
        tapTab("tab-read", in: app)

        let restoredTitle = app.buttons["reader-title"]
        let restoredJohnOne = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "John 1"), object: restoredTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [restoredJohnOne], timeout: 12), .completed,
                       "Returning to Read must not replay the old John 3:16 context request")
        XCTAssertTrue((restoredTitle.value as? String ?? "").contains("anchor=\(savedToken)"),
                      "Returning to Read must restore the saved John 1 anchor")
        let restoredVerse = app.buttons["reader-verse-\(savedVerse)"]
        XCTAssertTrue(restoredVerse.waitForExistence(timeout: 8))
        XCTAssertTrue(restoredVerse.isHittable,
                      "The saved John 1 verse must be visible when Read returns")
        XCTAssertFalse(app.staticTexts["reader-selection-summary"].exists,
                       "Restoring a saved Reader position must not create a verse selection")
        let returnedRequest = readerRequest(in: app)
        XCTAssertNotNil(UUID(uuidString: returnedRequest),
                         "Returning to Read must expose a valid Reader request UUID")
        XCTAssertNotEqual(returnedRequest, contextRequest,
                          "Returning to Read must not replay the old John 3:16 context request")
        Thread.sleep(forTimeInterval: 2.2)
        XCTAssertEqual(restoredTitle.label, "John 1",
                       "The Reader must stay at John 1 after the context request settles")
        XCTAssertEqual(readerRequest(in: app), returnedRequest,
                       "The returned John 1 request must stay current after settling")
        XCTAssertTrue((restoredTitle.value as? String ?? "").contains("anchor=\(savedToken)"),
                      "The saved John 1 anchor must stay current after settling")
        XCTAssertTrue(restoredVerse.isHittable,
                      "The saved John 1 verse must stay visible after settling")
        NSLog("READER_SAVED_POSITION contextRequest=%@ savedAnchor=%@ returnTitle=%@ visibleVerse=%d",
              contextRequest, savedToken, restoredTitle.label, savedVerse)
    }

    func testSavedAnchor50Offset85SurvivesLargeReflowAndRestart() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))
        // Seed through visible controls. A saved anchor made outside the test is not required.
        // 1. Set Medium text size in Settings.
        tapTab("tab-settings", in: app)
        let mediumSeed = app.buttons["settings-text-size-default"]
        XCTAssertTrue(mediumSeed.waitForExistence(timeout: 10))
        mediumSeed.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Selected"), object: mediumSeed)], timeout: 8), .completed)
        // 2. Open John 1 from the book list.
        tapTab("tab-read", in: app)
        let bookListTitle = app.staticTexts["reader-book-list-title"]
        for _ in 0..<3 where !bookListTitle.exists {
            let back = app.buttons["reader-back"]
            XCTAssertTrue(back.waitForExistence(timeout: 8), "Return to the visible Reader book list")
            back.tap()
        }
        let john = app.buttons["reader-book-JHN"]
        XCTAssertTrue(john.waitForExistence(timeout: 10))
        john.tap()
        let chapterOne = app.buttons["reader-chapter-1"]
        XCTAssertTrue(chapterOne.waitForExistence(timeout: 10))
        chapterOne.tap()
        let title = app.buttons["reader-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 12))
        // 3. Scroll deep into John 1. The saved anchor is the one the Reader reports at rest.
        let scroll = app.scrollViews["reader-chapter-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        let target = app.buttons["reader-verse-50"]
        for _ in 0..<40 where !(target.exists && target.isHittable) { scroll.swipeUp(velocity: .fast) }
        XCTAssertTrue(target.exists && target.isHittable, "John 1:50 must be visible after the seed scroll")
        Thread.sleep(forTimeInterval: 2.2)
        let seeded = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                guard let t = self.anchorToken(in: title) else { return false }
                return (Int(t.prefix { $0 != ":" }) ?? 0) >= 40
            }, object: title)
        XCTAssertEqual(XCTWaiter.wait(for: [seeded], timeout: 15), .completed,
                       "The Reader must report an anchor deep in John 1 after the seed scroll")
        let seedAnchor = self.anchorToken(in: title) ?? ""
        let anchorVerse = Int(seedAnchor.prefix { $0 != ":" }) ?? 50
        let initialRequest = readerRequest(in: app)
        XCTAssertNotNil(UUID(uuidString: initialRequest), "The saved John 1 location must have a Reader request UUID")

        // Change text size in Settings. Tapping the Aa toolbar at this saved deep anchor makes XCTest scroll
        // the toolbar into view and changes the Reader position before the sheet opens.
        tapTab("tab-settings", in: app)
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 10))
        let medium = app.buttons["settings-text-size-default"]
        let large = app.buttons["settings-text-size-large"]
        XCTAssertTrue(medium.waitForExistence(timeout: 8))
        XCTAssertTrue(large.waitForExistence(timeout: 8))
        XCTAssertEqual(medium.value as? String, "Selected", "The task fixture must start at Medium")
        XCTAssertEqual(large.value as? String, "Not selected", "The task fixture must start below Large")
        large.tap()
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Selected"), object: large)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 8), .completed,
                       "Settings must commit Large text")
        tapTab("tab-read", in: app)
        let reflowTitle = app.buttons["reader-title"]
        XCTAssertTrue(reflowTitle.waitForExistence(timeout: 12), "Read must reopen its current Reader chapter")
        let reflowed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "John 1"), object: reflowTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [reflowed], timeout: 15), .completed,
                       "Returning to Read must reopen John 1")
        let reflowRequest = readerRequest(in: app)
        XCTAssertNotNil(UUID(uuidString: reflowRequest), "The reflowed Reader must have a valid request UUID")
        Thread.sleep(forTimeInterval: 2.2)
        XCTAssertEqual(readerRequest(in: app), reflowRequest,
                       "The reflowed John 1 request must stay current after settling")
        assertSavedAnchorVisible(seedAnchor, verse: anchorVerse, title: reflowTitle, in: app, label: "anchor-50-85-large")
        let reflowShot = XCTAttachment(screenshot: app.screenshot())
        reflowShot.name = "reader-anchor-50-85-large-reflow"
        reflowShot.lifetime = .keepAlways
        add(reflowShot)

        app.terminate()
        app.launchArguments += ["-JohnTabBarMinimize", "never"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))
        tapTab("tab-read", in: app)
        let continued = app.buttons["reader-continue-reading"]
        XCTAssertTrue(continued.waitForExistence(timeout: 10))
        continued.tap()
        let restoredTitle = app.buttons["reader-title"]
        let restored = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS %@", "anchor=" + seedAnchor), object: restoredTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 15), .completed,
                       "A fresh process must restore the exact John 1 anchor")
        let restartRequest = readerRequest(in: app)
        XCTAssertNotNil(UUID(uuidString: restartRequest),
                         "The restored John 1 location must have a valid Reader request UUID")
        Thread.sleep(forTimeInterval: 2.2)
        assertSavedAnchorVisible(seedAnchor, verse: anchorVerse, title: restoredTitle, in: app,
                                 label: "anchor-50-85-after-restart")
        XCTAssertEqual(readerRequest(in: app), restartRequest,
                       "The restored John 1 request must remain current after settling")
        let restartShot = XCTAttachment(screenshot: app.screenshot())
        restartShot.name = "reader-anchor-50-85-after-restart"
        restartShot.lifetime = .keepAlways
        add(restartShot)
        tapTab("tab-settings", in: app)
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 10))
        let persistedLarge = app.buttons["settings-text-size-large"]
        XCTAssertTrue(persistedLarge.waitForExistence(timeout: 8))
        XCTAssertEqual(persistedLarge.value as? String, "Selected",
                       "Large must remain selected after restart")
        // Restore Medium so later tests start from the standard text size.
        let restoreMedium = app.buttons["settings-text-size-default"]
        XCTAssertTrue(restoreMedium.waitForExistence(timeout: 8))
        restoreMedium.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Selected"), object: restoreMedium)], timeout: 8), .completed)
        NSLog("L08_READER_ANCHOR exact=%@ mediumToLarge=true restart=true largePersisted=true initialRequest=%@ restartRequest=%@",
              seedAnchor, initialRequest, restartRequest)
    }

    func testAaMediumBackgroundVerseTapClosesWithoutSelection() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))
        tapTab("tab-read", in: app)

        let bookList = app.staticTexts["reader-book-list-title"]
        for _ in 0..<3 where !bookList.exists {
            let back = app.buttons["reader-back"]
            XCTAssertTrue(back.waitForExistence(timeout: 8), "Return to the visible Reader book list")
            back.tap()
        }
        XCTAssertTrue(bookList.waitForExistence(timeout: 8), "The independent Aa check must start from the book list")
        let book = app.buttons["reader-book-JHN"]
        XCTAssertTrue(book.waitForExistence(timeout: 10))
        book.tap()
        let chapter = app.buttons["reader-chapter-1"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 10))
        chapter.tap()
        XCTAssertTrue(app.buttons["reader-title"].waitForExistence(timeout: 12))
        XCTAssertFalse(app.staticTexts["reader-selection-summary"].exists, "Aa check must start with no active selection")

        let appearance = app.buttons["reader-appearance-button"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 8))
        appearance.tap()
        let close = app.buttons["reader-appearance-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 8), "Aa must open before the background tap")
        let verse = app.buttons["reader-verse-1"]
        XCTAssertTrue(verse.waitForExistence(timeout: 8))
        XCTAssertTrue(verse.isHittable, "Verse 1 text must remain exposed behind the medium Aa sheet")
        verse.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(close.waitForNonExistence(timeout: 8), "A chapter text tap must close Aa")
        XCTAssertFalse(app.staticTexts["reader-selection-summary"].exists,
                       "A chapter text tap that closes Aa must not select the verse")
        XCTAssertFalse(verse.isSelected, "The verse must remain unselected after the Aa background tap")
        NSLog("READER_AA backgroundVerseTap=JHN:1:1 sheetClosed=true selection=absent")
    }

    func testAaReflowKeepsVisibleTopAnchor() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))
        tapTab("tab-read", in: app)

        let bookList = app.staticTexts["reader-book-list-title"]
        for _ in 0..<3 where !bookList.exists {
            let back = app.buttons["reader-back"]
            XCTAssertTrue(back.waitForExistence(timeout: 8), "Return to the visible Reader book list")
            XCTAssertTrue(back.isHittable, "Back must be hittable without scrolling the chapter")
            back.tap()
        }
        XCTAssertTrue(bookList.waitForExistence(timeout: 8), "Aa reflow must start from the book list")
        let book = app.buttons["reader-book-JHN"]
        XCTAssertTrue(book.waitForExistence(timeout: 10))
        book.tap()
        let chapter = app.buttons["reader-chapter-1"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 10))
        chapter.tap()

        let title = app.buttons["reader-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 12))
        let opened = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "John 1"), object: title)
        XCTAssertEqual(XCTWaiter.wait(for: [opened], timeout: 15), .completed,
                       "Aa reflow must start in John 1")
        let verse = app.buttons["reader-verse-1"]
        XCTAssertTrue(verse.waitForExistence(timeout: 8))
        XCTAssertTrue(verse.isHittable, "Verse 1 must be visible before Aa opens")
        let appearance = app.buttons["reader-appearance-button"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 8))
        XCTAssertTrue(appearance.isHittable,
                      "Aa must already be hittable. Do not scroll the chapter to reach it.")
        Thread.sleep(forTimeInterval: 2.2)
        let anchorBefore = anchorToken(in: title)
        XCTAssertEqual(anchorToken(in: title), anchorBefore,
                       "The starting anchor must be stable before Aa opens")

        appearance.tap()
        let close = app.buttons["reader-appearance-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 8), "Aa must open")
        let medium = app.buttons["settings-text-size-default"]
        let large = app.buttons["settings-text-size-large"]
        XCTAssertTrue(medium.waitForExistence(timeout: 8))
        XCTAssertTrue(large.waitForExistence(timeout: 8))
        XCTAssertEqual(medium.value as? String, "Selected", "The standard seed must start at Medium")
        XCTAssertTrue(large.isHittable, "Large must be hittable inside the Aa sheet")
        large.tap()
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Selected"), object: large)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 8), .completed,
                       "Aa must commit Large text")
        Thread.sleep(forTimeInterval: 2.2)
        XCTAssertEqual(anchorToken(in: title), anchorBefore,
                       "Aa reflow must keep the anchor that was visible before the size change")
        XCTAssertTrue(verse.isHittable, "Verse 1 must stay visible after the Aa size change")
        XCTAssertFalse(app.staticTexts["reader-selection-summary"].exists,
                       "Aa reflow must not select a verse")
        XCTAssertTrue(close.isHittable, "Done must be hittable")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 8), "Done must close Aa")
        XCTAssertEqual(anchorToken(in: title), anchorBefore, "Closing Aa must keep the same anchor")
        XCTAssertTrue(verse.isHittable, "Verse 1 must stay visible after Aa closes")

        app.terminate()
        app.launchArguments += ["-JohnTabBarMinimize", "never"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))
        tapTab("tab-read", in: app)
        let continued = app.buttons["reader-continue-reading"]
        XCTAssertTrue(continued.waitForExistence(timeout: 10))
        XCTAssertTrue(continued.isHittable, "Continue reading must be hittable")
        continued.tap()
        let restored = app.buttons["reader-title"]
        XCTAssertTrue(restored.waitForExistence(timeout: 12))
        let restoredJohn = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "John 1"), object: restored)
        XCTAssertEqual(XCTWaiter.wait(for: [restoredJohn], timeout: 15), .completed,
                       "Restart must reopen John 1")
        Thread.sleep(forTimeInterval: 2.2)
        XCTAssertEqual(anchorToken(in: restored), anchorBefore,
                       "Restart must keep the anchor from the Aa reflow")
        let restoredVerse = app.buttons["reader-verse-1"]
        XCTAssertTrue(restoredVerse.waitForExistence(timeout: 8))
        XCTAssertTrue(restoredVerse.isHittable, "Verse 1 must stay visible after restart")
        tapTab("tab-settings", in: app)
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 10))
        let persisted = app.buttons["settings-text-size-large"]
        XCTAssertTrue(persisted.waitForExistence(timeout: 8))
        XCTAssertEqual(persisted.value as? String, "Selected",
                       "Large must remain selected after restart")
        NSLog("READER_AA_REFLOW anchorBefore=%@ largePersisted=true", anchorBefore ?? "none")
    }

    private func contextURL(verse: Int) -> URL {
        URL(string: "nrsv://read?book=JHN&chapter=3&verse=\(verse)")!
    }

    @discardableResult
    private func assertContextVerse(_ verseNumber: Int, in app: XCUIApplication, label: String,
                                    previousRequest: String? = nil) -> String {
        let title = app.buttons["reader-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 20), "\(label): Reader must open")
        XCTAssertEqual(title.label, "John 3", "\(label): URL must open John 3")
        if let previousRequest {
            let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard let uuid = UUID(uuidString: self.readerRequest(in: app)) else { return false }
                return uuid.uuidString.lowercased() != previousRequest.lowercased()
            }, object: title)
            XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 15), .completed,
                           "\(label): URL delivery must create a fresh Reader request UUID")
        }
        let request = readerRequest(in: app)
        XCTAssertNotNil(UUID(uuidString: request), "\(label): Reader must expose a valid request UUID")
        assertContextVerseStillVisible(verseNumber, in: app, label: label)
        return request
    }

    private func assertContextVerseStillVisible(_ verseNumber: Int, in app: XCUIApplication, label: String) {
        let verse = app.buttons["reader-verse-\(verseNumber)"]
        XCTAssertTrue(verse.waitForExistence(timeout: 12), "\(label): requested verse must exist")
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in verse.isHittable }, object: verse)
        let visibility = XCTWaiter.wait(for: [visible], timeout: 12)
        if visibility != .completed {
            let reader = app.scrollViews["reader-chapter-scroll"]
            let summary = app.staticTexts["reader-selection-summary"]
            NSLog("L08_READER_CONTEXT_DIAGNOSTIC label=%@ title=%@ verse=%@ verseFrame=%@ viewport=%@ viewportValue=%@ selection=%@",
                  label, app.buttons["reader-title"].label, verse.label, NSCoder.string(for: verse.frame),
                  NSCoder.string(for: reader.frame), reader.value as? String ?? "none",
                  summary.exists ? summary.label : "absent")
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "\(label)-accessibility-tree"
            tree.lifetime = .keepAlways
            add(tree)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "\(label)-not-hittable"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        XCTAssertEqual(visibility, .completed, "\(label): requested verse must become visible")
        XCTAssertFalse(app.staticTexts["reader-selection-summary"].exists,
                       "\(label): context must not create a selection")
    }

    private func readerRequest(in app: XCUIApplication) -> String {
        guard let value = app.buttons["reader-title"].value as? String,
              let range = value.range(of: "request=") else { return "" }
        return String(value[range.upperBound...].prefix { $0 != ";" })
    }

    private func assertSavedAnchorVisible(_ token: String, verse verseNumber: Int,
                                          title: XCUIElement, in app: XCUIApplication, label: String) {
        let exactAnchor = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in self.anchorToken(in: title) == token }, object: title)
        XCTAssertEqual(XCTWaiter.wait(for: [exactAnchor], timeout: 12), .completed,
                       "\(label): the exact saved anchor must remain current")
        let verse = app.buttons["reader-verse-\(verseNumber)"]
        XCTAssertTrue(verse.waitForExistence(timeout: 8), "\(label): saved verse must exist")
        let visible = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in verse.isHittable }, object: verse)
        let visibility = XCTWaiter.wait(for: [visible], timeout: 12)
        if visibility != .completed {
            let reader = app.scrollViews["reader-chapter-scroll"]
            let summary = app.staticTexts["reader-selection-summary"]
            NSLog("L08_READER_CONTEXT_DIAGNOSTIC label=%@ title=%@ verse=%@ verseFrame=%@ viewport=%@ viewportValue=%@ selection=%@",
                  label, app.buttons["reader-title"].label, verse.label, NSCoder.string(for: verse.frame),
                  NSCoder.string(for: reader.frame), reader.value as? String ?? "none",
                  summary.exists ? summary.label : "absent")
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "\(label)-accessibility-tree"
            tree.lifetime = .keepAlways
            add(tree)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "\(label)-not-hittable"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        XCTAssertEqual(visibility, .completed,
                       "\(label): saved verse must be visible")
    }

    private func anchorToken(in title: XCUIElement) -> String? {
        let value = title.value as? String ?? ""
        guard let range = value.range(of: #"anchor=([0-9]+:[0-9]+)"#, options: .regularExpression) else {
            return nil
        }
        return String(value[range]).replacingOccurrences(of: "anchor=", with: "")
    }

    private func waitForNewNonTopAnchor(_ title: XCUIElement, after priorAnchor: String?,
                                        timeout: TimeInterval = 8) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let token = anchorToken(in: title), token != priorAnchor,
               let verse = Int(token.split(separator: ":").first ?? ""), verse > 1 {
                return title.value as? String
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return nil
    }

    private func tapTab(_ identifier: String, in app: XCUIApplication) {
        let tab = tabElement(identifier, in: app)
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Missing tab \(identifier)")
        tab.tap()
    }

    private func tabElement(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let label = String(identifier.dropFirst("tab-".count))
        let capitalized = label.prefix(1).uppercased() + label.dropFirst()
        let bar = app.tabBars.firstMatch
        let byIdentifier = bar.buttons[identifier]
        if byIdentifier.exists { return byIdentifier }
        let byLabel = bar.buttons[capitalized]
        if byLabel.exists { return byLabel }
        return app.buttons[identifier]
    }
}
