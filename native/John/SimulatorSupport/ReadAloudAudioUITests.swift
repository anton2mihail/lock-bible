import XCTest

/// State-based checks for read-aloud (E8) and the audio mini-player (E27).
/// The synthesizer cannot be heard in a test, so the checks read accessibility values.
@MainActor
final class ReadAloudAudioUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func tab(_ label: String, in app: XCUIApplication) -> XCUIElement {
        let byID = app.buttons.matching(identifier: "tab-\(label.lowercased())").firstMatch
        return byID.exists ? byID : app.tabBars.buttons[label]
    }

    private func openJohnOne() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))
        tab("Read", in: app).tap()
        let title = app.buttons["reader-title"]
        if !(title.waitForExistence(timeout: 3) && title.label == "John 1") {
            let book = app.buttons["reader-book-JHN"]
            if book.waitForExistence(timeout: 5) { book.tap() }
            let chapter = app.buttons["reader-chapter-1"]
            XCTAssertTrue(chapter.waitForExistence(timeout: 8))
            chapter.tap()
        }
        XCTAssertTrue(app.buttons["reader-read-aloud-button"].waitForExistence(timeout: 10))
        return app
    }

    private func waitForValue(_ element: XCUIElement, contains text: String, timeout: TimeInterval = 8) -> Bool {
        let predicate = NSPredicate(format: "value CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    func testReadAloudStateControlsAndMiniPlayer() throws {
        let app = openJohnOne()
        let start = app.buttons["reader-read-aloud-button"]
        XCTAssertEqual(start.value as? String, "idle")
        XCTAssertFalse(app.otherElements["audio-mini-player"].exists, "No mini-player before audio starts")

        start.tap()
        XCTAssertTrue(waitForValue(start, contains: "playing verse 1"))
        let toggle = app.buttons["reader-read-aloud-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))

        app.buttons["reader-read-aloud-next"].tap()
        XCTAssertTrue(waitForValue(start, contains: "verse 2"))
        app.buttons["reader-read-aloud-previous"].tap()
        XCTAssertTrue(waitForValue(start, contains: "verse 1"))

        toggle.tap()
        XCTAssertTrue(waitForValue(start, contains: "paused verse 1"))

        // The mini-player shows on another tab and opens the Reader at the spoken verse.
        tab("Settings", in: app).tap()
        let mini = app.descendants(matching: .any).matching(identifier: "audio-mini-player").firstMatch
        XCTAssertTrue(mini.waitForExistence(timeout: 8), "Mini-player must show while read-aloud is active")
        XCTAssertTrue(waitForValue(mini, contains: "read-aloud, paused"))
        app.buttons["audio-mini-player-toggle"].firstMatch.tap()
        XCTAssertTrue(waitForValue(mini, contains: "read-aloud, playing"))
        app.buttons["audio-mini-player-open"].firstMatch.tap()
        XCTAssertTrue(app.buttons["reader-read-aloud-button"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["reader-title"].label, "John 1")

        app.buttons["reader-read-aloud-stop"].tap()
        XCTAssertTrue(waitForValue(app.buttons["reader-read-aloud-button"], contains: "idle"))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "audio-mini-player").firstMatch.waitForExistence(timeout: 2),
                       "Mini-player must hide when audio stops")
    }
}
