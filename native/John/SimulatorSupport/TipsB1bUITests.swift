import XCTest

/// Slice B1b. Each test starts from the default native state.
@MainActor
final class TipsB1bUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never", "-JohnResetNativeState", "-JohnResetTips"] + extra
        app.launch()
        return app
    }

    func testNoTipOnFirstUse() throws {
        let app = launch(["-JohnShowTips"])
        let read = app.tabBars.buttons["Read"]
        XCTAssertTrue(read.waitForExistence(timeout: 10))
        read.tap()
        XCTAssertFalse(app.staticTexts["Resize the text"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Share a verse"].exists)
    }

    func testSavedTipHiddenWithoutUse() throws {
        let app = launch(["-JohnShowTips"])
        let saved = app.tabBars.buttons["Saved"]
        XCTAssertTrue(saved.waitForExistence(timeout: 10))
        saved.tap()
        XCTAssertFalse(app.staticTexts["Share a saved verse"].waitForExistence(timeout: 2))
    }

    func testReaderTipsShowAtOnceWhenForced() throws {
        let app = launch(["-JohnTipsShowAll"])
        let read = app.tabBars.buttons["Read"]
        XCTAssertTrue(read.waitForExistence(timeout: 10))
        read.tap()
        let book = app.buttons["reader-book-JHN"]
        if book.waitForExistence(timeout: 2) { book.tap() }
        let chapter = app.buttons["reader-chapter-1"]
        if chapter.waitForExistence(timeout: 2) { chapter.tap() }
        let tip = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@ OR label CONTAINS %@", "tip-pinch-text", "Resize the text")).firstMatch
        for _ in 0..<12 where !tip.exists { app.swipeUp(velocity: .fast) }
        XCTAssertTrue(tip.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(tip.frame.height, 0)
    }
}
