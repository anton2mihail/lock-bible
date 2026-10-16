import XCTest

/// The paged Reader (Pages mode, the default). The checks read the page position from `reader-page-status`
/// ("John 1, page 2 of 5"). Only the page on screen exposes its verses to accessibility.
@MainActor
final class ReaderPagesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Tests

    func testPagesIsTheDefaultAndShowsThePagePosition() throws {
        let app = launch(reset: true, forcePages: false)
        open("nrsv://read?book=JHN&chapter=1", in: app)
        let position = waitForPosition(in: app) { $0.chapter == "John 1" && $0.page == 1 }
        XCTAssertGreaterThan(position.count, 1, "John 1 must need more than one page")
        XCTAssertFalse(app.scrollViews["reader-chapter-scroll"].exists, "Pages mode must not show the scroll Reader")
        XCTAssertTrue(app.otherElements["reader-chapter-heading"].exists || app.staticTexts["reader-chapter-heading"].exists
                      || app.descendants(matching: .any)["reader-chapter-heading"].exists,
                      "The first page must show the chapter heading")
        XCTAssertTrue(app.buttons["reader-verse-1"].isHittable)
    }

    func testTapZonesTurnPagesAndMiddleTapTogglesControls() throws {
        let app = launch(reset: true)
        open("nrsv://read?book=JHN&chapter=1", in: app)
        _ = waitForPosition(in: app) { $0.chapter == "John 1" && $0.page == 1 }
        XCTAssertTrue(app.buttons["reader-title"].exists, "The controls show when a chapter opens")

        tapPage(x: 0.9, in: app)
        _ = waitForPosition(in: app) { $0.chapter == "John 1" && $0.page == 2 }
        XCTAssertFalse(app.buttons["reader-title"].waitForExistence(timeout: 1), "A page turn hides the controls")

        tapPage(x: 0.9, in: app)
        _ = waitForPosition(in: app) { $0.page == 3 }
        tapPage(x: 0.1, in: app)
        _ = waitForPosition(in: app) { $0.page == 2 }

        tapPage(x: 0.5, y: 0.08, in: app)
        XCTAssertTrue(app.buttons["reader-title"].waitForExistence(timeout: 4), "A middle tap shows the controls")
        XCTAssertEqual(position(in: app)?.page, 2, "A middle tap does not turn the page")
        tapPage(x: 0.5, y: 0.5, in: app)
        XCTAssertFalse(app.buttons["reader-title"].waitForExistence(timeout: 1), "A second middle tap hides the controls")
        XCTAssertFalse(app.staticTexts["reader-selection-summary"].exists, "A middle tap does not select a verse")
    }

    func testSwipeTurnsIntoTheNextChapterAndBack() throws {
        let app = launch(reset: true)
        open("nrsv://read?book=JHN&chapter=1", in: app)
        let first = waitForPosition(in: app) { $0.chapter == "John 1" && $0.page == 1 }
        for _ in 0..<(first.count + 2) {
            if position(in: app)?.chapter == "John 2" { break }
            app.swipeLeft()
        }
        _ = waitForPosition(in: app) { $0.chapter == "John 2" && $0.page == 1 }
        app.swipeRight()
        _ = waitForPosition(in: app) { $0.chapter == "John 1" && $0.page == $0.count }
        // The Reader title follows the page turn into the other chapter.
        tapPage(x: 0.5, in: app)
        let title = app.buttons["reader-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 4))
        XCTAssertEqual(title.label, "John 1")
    }

    func testPageTurnCrossesIntoTheNextBook() throws {
        let app = launch(reset: true)
        open("nrsv://read?book=JUD&chapter=1", in: app)
        let first = waitForPosition(in: app) { $0.chapter == "Jude 1" && $0.page == 1 }
        for _ in 0..<(first.count + 2) {
            if position(in: app)?.chapter.hasPrefix("Revelation") == true { break }
            tapPage(x: 0.92, in: app)
            Thread.sleep(forTimeInterval: 0.6)
        }
        _ = waitForPosition(in: app) { $0.chapter.hasPrefix("Revelation") && $0.chapter.hasSuffix(" 1") && $0.page == 1 }
        tapPage(x: 0.08, in: app)
        _ = waitForPosition(in: app) { $0.chapter == "Jude 1" && $0.page == $0.count }
    }

    func testVerseLinkAndGoToLandOnTheRightPage() throws {
        let app = launch(reset: true)
        open("nrsv://read?book=PSA&chapter=119&verse=105", in: app)
        let position = waitForPosition(in: app) { $0.chapter.hasSuffix(" 119") }
        XCTAssertGreaterThan(position.page, 1, "Psalm 119:105 is not on the first page")
        XCTAssertGreaterThan(position.count, 8, "Psalm 119 needs many pages")
        let verse = app.buttons["reader-verse-105"]
        XCTAssertTrue(verse.waitForExistence(timeout: 6))
        XCTAssertTrue(verse.isHittable, "The linked verse must be on the page on screen")

        // Go to a chapter: it opens on its first page.
        let title = app.buttons["reader-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 4))
        title.tap()
        let book = app.buttons["go-to-book-ROM"]
        XCTAssertTrue(book.waitForExistence(timeout: 8))
        book.tap()
        let chapter = app.buttons["go-to-chapter-ROM-8"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 8))
        chapter.tap()
        _ = waitForPosition(in: app) { $0.chapter == "Romans 8" && $0.page == 1 }
        XCTAssertTrue(app.buttons["reader-verse-1"].waitForExistence(timeout: 6))
    }

    func testLongPressSelectsAVerseAndAHighlightDrawsOnThePage() throws {
        let app = launch(reset: true)
        open("nrsv://read?book=JHN&chapter=1", in: app)
        _ = waitForPosition(in: app) { $0.chapter == "John 1" && $0.page == 1 }
        let verse = app.buttons["reader-verse-3"]
        XCTAssertTrue(verse.waitForExistence(timeout: 8))
        verse.press(forDuration: 0.8)
        let summary = app.staticTexts["reader-selection-summary"]
        waitForLabel(summary, equals: "Selected: verses 3–3")
        XCTAssertTrue(verse.isSelected, "The selected verse reports the selected trait")

        // With a selection, a tap on another verse extends the range instead of turning the page.
        let next = app.buttons["reader-verse-4"]
        XCTAssertTrue(next.exists)
        next.tap()
        waitForLabel(summary, equals: "Selected: verses 3–4")
        XCTAssertEqual(position(in: app)?.page, 1)

        let gold = app.buttons["reader-highlight-gold"]
        XCTAssertTrue(gold.waitForExistence(timeout: 8))
        if gold.value as? String == "Selected" {
            app.buttons["reader-highlight-clear"].tap()
            waitForValue(gold, equals: "Not selected")
        }
        gold.tap()
        waitForValue(app.buttons["reader-verse-3"], equals: "Gold highlight")
        waitForValue(app.buttons["reader-verse-4"], equals: "Gold highlight")
        attachScreenshot(app, name: "pages-highlight")

        // Clean up, so a later run starts without the highlight.
        app.buttons["reader-highlight-clear"].tap()
        let cleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == nil OR value == ''"),
                                                object: app.buttons["reader-verse-3"])
        XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 8), .completed)
        // A tap beside the chapter number (no text there) only clears the selection. It does not turn the page.
        tapPage(x: 0.12, y: 0.19, in: app)
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: summary)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 4), .completed, "The tap must clear the selection")
        XCTAssertEqual(position(in: app)?.page, 1)
    }

    func testReadingPositionRestoresAfterRelaunch() throws {
        let app = launch(reset: true)
        open("nrsv://read?book=JHN&chapter=1", in: app)
        _ = waitForPosition(in: app) { $0.chapter == "John 1" && $0.page == 1 }
        tapPage(x: 0.9, in: app)
        _ = waitForPosition(in: app) { $0.page == 2 }
        tapPage(x: 0.9, in: app)
        let saved = waitForPosition(in: app) { $0.page == 3 }
        let firstVerse = visibleVerses(in: app).first
        XCTAssertNotNil(firstVerse)
        Thread.sleep(forTimeInterval: 1.5)
        app.terminate()

        let again = launch(reset: false)
        let read = again.tabBars.buttons["Read"].exists ? again.tabBars.buttons["Read"]
            : again.buttons.matching(identifier: "tab-read").firstMatch
        XCTAssertTrue(read.waitForExistence(timeout: 12))
        read.tap()
        let resume = again.buttons["reader-continue-reading"]
        if resume.waitForExistence(timeout: 4) { resume.tap() }
        let restored = waitForPosition(in: again) { $0.chapter == "John 1" }
        XCTAssertEqual(restored.page, saved.page, "The saved page must open again")
        if let firstVerse {
            XCTAssertTrue(again.buttons[firstVerse].waitForExistence(timeout: 4), "The saved verse must be on screen")
        }
    }

    func testTextSizeChangeKeepsTheVerseOnScreen() throws {
        let app = launch(reset: true)
        open("nrsv://read?book=JHN&chapter=1", in: app)
        _ = waitForPosition(in: app) { $0.chapter == "John 1" && $0.page == 1 }
        tapPage(x: 0.9, in: app)
        _ = waitForPosition(in: app) { $0.page == 2 }
        tapPage(x: 0.9, in: app)
        let before = waitForPosition(in: app) { $0.page == 3 }
        guard let anchor = visibleVerses(in: app).first else { return XCTFail("Page 3 must show verses") }

        tapPage(x: 0.5, y: 0.08, in: app)
        let aa = app.buttons["reader-appearance-button"]
        XCTAssertTrue(aa.waitForExistence(timeout: 4))
        aa.tap()
        let larger = app.buttons["settings-text-size-extra-large"]
        XCTAssertTrue(larger.waitForExistence(timeout: 8))
        larger.tap()
        app.buttons["reader-appearance-close"].tap()

        let after = waitForPosition(in: app) { $0.count > before.count }
        XCTAssertTrue(app.buttons[anchor].waitForExistence(timeout: 6),
                      "\(anchor) must stay on screen after the text grows (now page \(after.page) of \(after.count))")
        XCTAssertTrue(app.buttons[anchor].isHittable)
    }

    func testScrollChoiceSwitchesModesAndKeepsThePlace() throws {
        let app = launch(reset: true, forcePages: false)
        open("nrsv://read?book=JHN&chapter=1", in: app)
        _ = waitForPosition(in: app) { $0.chapter == "John 1" && $0.page == 1 }
        tapPage(x: 0.9, in: app)
        _ = waitForPosition(in: app) { $0.page == 2 }
        tapPage(x: 0.5, y: 0.08, in: app)
        let aa = app.buttons["reader-appearance-button"]
        XCTAssertTrue(aa.waitForExistence(timeout: 4))
        aa.tap()
        let scroll = app.buttons["settings-reading-mode-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["settings-reading-mode-pages"].value as? String, "Selected", "Pages is the default")
        scroll.tap()
        app.buttons["reader-appearance-close"].tap()
        XCTAssertTrue(app.scrollViews["reader-chapter-scroll"].waitForExistence(timeout: 8), "Scroll shows the scroll Reader")
        XCTAssertFalse(app.staticTexts["reader-page-status"].exists)

        app.buttons["reader-appearance-button"].tap()
        let pages = app.buttons["settings-reading-mode-pages"]
        XCTAssertTrue(pages.waitForExistence(timeout: 8))
        pages.tap()
        app.buttons["reader-appearance-close"].tap()
        // The scroll Reader keeps the verse at the top of page 2. Its top line can be the last line of page 1.
        _ = waitForPosition(in: app) { $0.chapter == "John 1" && abs($0.page - 2) <= 1 }
    }

    func testReadAloudTurnsToThePageOfTheSpokenVerse() throws {
        let app = launch(reset: true)
        open("nrsv://read?book=JHN&chapter=1", in: app)
        _ = waitForPosition(in: app) { $0.chapter == "John 1" && $0.page == 1 }
        let lastOnFirstPage = visibleVerses(in: app).compactMap { Int($0.replacingOccurrences(of: "reader-verse-", with: "")) }.max() ?? 1
        let start = app.buttons["reader-read-aloud-button"]
        XCTAssertTrue(start.waitForExistence(timeout: 6))
        start.tap()
        let next = app.buttons["reader-read-aloud-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 6))
        let toggle = app.buttons["reader-read-aloud-toggle"]
        toggle.tap()
        for _ in 0..<lastOnFirstPage { next.tap() }
        _ = waitForPosition(in: app) { $0.page == 2 }
        app.buttons["reader-read-aloud-stop"].tap()
    }

    // MARK: Helpers

    private struct Position {
        let chapter: String
        let page: Int
        let count: Int
    }

    private func launch(reset: Bool, forcePages: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"]
        if reset { app.launchArguments += ["-JohnResetNativeState"] }
        if forcePages { app.launchArguments += ["-JohnReaderMode", "pages"] }
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 15))
        return app
    }

    private func open(_ url: String, in app: XCUIApplication) {
        app.open(URL(string: url)!)
    }

    private func position(in app: XCUIApplication) -> Position? {
        let element = app.staticTexts["reader-page-status"]
        guard element.exists else { return nil }
        return Self.parse(element.label)
    }

    /// Parses "John 1, page 2 of 5".
    private static func parse(_ label: String) -> Position? {
        guard let range = label.range(of: ", page ", options: .backwards) else { return nil }
        let chapter = String(label[..<range.lowerBound])
        let numbers = label[range.upperBound...].components(separatedBy: " of ")
        guard numbers.count == 2, let page = Int(numbers[0]), let count = Int(numbers[1]) else { return nil }
        return Position(chapter: chapter, page: page, count: count)
    }

    @discardableResult
    private func waitForPosition(in app: XCUIApplication, timeout: TimeInterval = 15,
                                 file: StaticString = #filePath, line: UInt = #line,
                                 _ condition: @escaping (Position) -> Bool) -> Position {
        let element = app.staticTexts["reader-page-status"]
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            element.exists && Self.parse(element.label).map(condition) == true
        }, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        let label = element.exists ? element.label : "missing"
        XCTAssertEqual(result, .completed, "Unexpected page position: \(label)", file: file, line: line)
        return Self.parse(label) ?? Position(chapter: "", page: 0, count: 0)
    }

    private func tapPage(x: CGFloat, y: CGFloat = 0.5, in app: XCUIApplication) {
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
    }

    /// Identifiers of the verses on the page on screen, in reading order.
    private func visibleVerses(in app: XCUIApplication) -> [String] {
        let query = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "reader-verse-"))
        return query.allElementsBoundByIndex.filter { $0.isHittable }
            .sorted { ($0.frame.minX > app.frame.midX ? 1 : 0, $0.frame.minY) < ($1.frame.minX > app.frame.midX ? 1 : 0, $1.frame.minY) }
            .map(\.identifier)
    }

    private func waitForLabel(_ element: XCUIElement, equals value: String, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed,
                       "Expected label \(value)", file: file, line: line)
    }

    private func waitForValue(_ element: XCUIElement, equals value: String, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed,
                       "Expected value \(value)", file: file, line: line)
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
