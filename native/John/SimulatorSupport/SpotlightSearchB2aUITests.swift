import XCTest

/// Slice B2a: search scope tokens, suggestions, recent searches, and Spotlight routing.
@MainActor
final class SpotlightSearchB2aUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnResetNativeState", "-JohnTabBarMinimize", "never", "-JohnReaderMode", "scroll"] + extra
        app.launch()
        return app
    }

    private func openSearch(_ app: XCUIApplication) {
        let readTab = app.tabBars.buttons["tab-read"].exists ? app.tabBars.buttons["tab-read"] : app.tabBars.buttons["Read"]
        XCTAssertTrue(readTab.waitForExistence(timeout: 10))
        readTab.tap()
        let search = app.buttons["reader-search-button"]
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        search.tap()
        XCTAssertTrue(app.textFields["search-query-input"].waitForExistence(timeout: 8))
    }

    func testBookSuggestionBecomesScopeToken() throws {
        let app = launch()
        openSearch(app)
        let field = app.textFields["search-query-input"]
        field.tap()
        field.typeText("Joh")
        let suggestion = app.buttons["search-suggestion-1"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 8))
        suggestion.tap()
        let token = app.buttons["search-book-token"]
        XCTAssertTrue(token.waitForExistence(timeout: 5))
        token.tap()
        XCTAssertTrue(token.waitForNonExistence(timeout: 5))
    }

    func testEditionScopeTokenSelects() throws {
        let app = launch()
        openSearch(app)
        let vulgate = app.buttons["search-edition-vulgate"]
        XCTAssertTrue(vulgate.waitForExistence(timeout: 8))
        vulgate.tap()
        XCTAssertTrue(vulgate.isSelected)
    }

    func testRecentSearchIsKeptAfterOpeningResult() throws {
        let app = launch()
        openSearch(app)
        let field = app.textFields["search-query-input"]
        field.tap()
        field.typeText("John 3:16")
        let result = app.buttons["search-result-1"]
        XCTAssertTrue(result.waitForExistence(timeout: 12))
        result.tap()
        XCTAssertTrue(app.buttons["reader-search-button"].waitForExistence(timeout: 10))
        app.buttons["reader-search-button"].tap()
        XCTAssertTrue(app.buttons["search-recent-1"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["search-recent-1"].label.contains("John 3:16"))
        app.buttons["search-recents-clear"].tap()
        XCTAssertTrue(app.buttons["search-recent-1"].waitForNonExistence(timeout: 5))
    }

    func testSpotlightChapterIdentifierOpensReader() throws {
        let app = launch(extra: ["-JohnSpotlightIdentifier", "nrsv.chapter.web-ce.JHN.3"])
        XCTAssertTrue(app.buttons["reader-search-button"].waitForExistence(timeout: 15), "Reader must open")
    }

    func testSpotlightSavedIdentifierOpensSaved() throws {
        let app = launch(extra: ["-JohnSpotlightIdentifier", "nrsv.saved.abc"])
        XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 15), "Saved tab must open")
    }
}
