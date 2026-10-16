import XCTest

/// Slice B4a: App Intent routes, dictation and handwriting controls, and Spanish chrome.
@MainActor
final class IntentsB4aUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnResetNativeState", "-JohnTabBarMinimize", "never", "-JohnReaderMode", "scroll"] + extra
        app.launch()
        return app
    }

    func testNoteIntentRouteOpensEditorWithDictationAndHandwriting() throws {
        let app = launch(["-JohnOpenURL", "nrsv://note"])
        XCTAssertTrue(app.textViews["saved-note-editor"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["saved-note-dictate"].exists)
        XCTAssertTrue(app.buttons["saved-note-handwrite"].exists)
        app.buttons["saved-note-handwrite"].tap()
        XCTAssertTrue(app.buttons["saved-note-canvas-done"].waitForExistence(timeout: 8))
        app.buttons["saved-note-canvas-done"].tap()
    }

    func testReadAloudIntentRouteStartsReading() throws {
        let app = launch(["-JohnOpenURL", "nrsv://readaloud"])
        let predicate = NSPredicate(format: "value BEGINSWITH 'playing' OR value BEGINSWITH 'paused'")
        let controls = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(controls.waitForExistence(timeout: 25))
    }

    func testSpanishSavedTitle() throws {
        let app = launch(["-AppleLanguages", "(es)", "-AppleLocale", "es_ES"])
        let saved = app.tabBars.buttons.element(boundBy: 2)
        XCTAssertTrue(saved.waitForExistence(timeout: 15))
        saved.tap()
        let title = app.staticTexts["page-title-saved"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "Guardado")
    }
}
