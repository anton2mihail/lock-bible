import XCTest

/// Source fixture: build/native-evidence/L09/source-preparation/search-fixtures-final.json
/// SHA-256: 2b489648b2c454b624d5d43e5cdb431b0bee04fc30ef66b6a76ff23e8c5d2a6b
/// Main must use a fresh task-only development container. Do not run these journeys
/// on the production-ID container or on an old-app update fixture.
@MainActor
final class SearchNoteUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSearchReferencePhraseCorrectionAndNoResults() throws {
        let app = XCUIApplication()
        app.launch()
        selectEdition("web-ce", in: app)
        openSearch(in: app)

        let field = app.textFields["search-query-input"]
        enter("John 3:16", in: field)
        assertResult("John 3:16", in: app)
        XCTAssertTrue(app.staticTexts["search-result-count"].label.contains("1 result"))

        replaceQuery(with: "\"In the beginning\"", in: app)
        assertResult("John 1:2", in: app)

        replaceQuery(with: "fiath", in: app)
        let correction = app.staticTexts["search-correction-notice"]
        XCTAssertTrue(waitForLabel(correction, equals: "Showing results for “fifth”"))
        assertResult("Ezekiel 1:2", in: app)

        replaceQuery(with: "qzxvqqq", in: app)
        XCTAssertTrue(waitForLabel(app.staticTexts["search-status"], equals: "No passages found. Try fewer words or check the reference."))

        NSLog("SEARCH_SOURCE_CASES fixture=2b489648b2c454b624d5d43e5cdb431b0bee04fc30ef66b6a76ff23e8c5d2a6b reference=John3:16 phrase=John1:2 correction=fifth:Ezekiel1:2 noResults=qzxvqqq")
    }

    func testSearchScopesEditionAndLatinText() throws {
        let app = XCUIApplication()
        app.launch()
        selectEdition("web-ce", in: app)
        openSearch(in: app)
        let field = app.textFields["search-query-input"]
        enter("John 3:16", in: field)
        assertResult("John 3:16", in: app)

        app.buttons["search-scope-ot"].tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["search-status"], equals: "No passages found. Try fewer words or check the reference."))
        app.buttons["search-scope-nt"].tap()
        assertResult("John 3:16", in: app)
        app.buttons["search-scope-all"].tap()

        app.buttons["search-cancel-button"].tap()
        selectEdition("vulgate", in: app)
        openSearch(in: app)

        enter("John 3:16", in: app.textFields["search-query-input"])
        assertResult("IOHANNEM 3:16", in: app)
        XCTAssertTrue(app.buttons["search-result-1"].label.contains("Sic enim Deus dilexit mundum"))

        replaceQuery(with: "deus", in: app)
        assertResult("MATTHEUM 22:32", in: app)
        XCTAssertTrue(app.buttons["search-result-1"].label.contains("Ego sum Deus Abraham"))
        NSLog("SEARCH_SOURCE_CASES fixture=2b489648b2c454b624d5d43e5cdb431b0bee04fc30ef66b6a76ff23e8c5d2a6b edition=vulgate latin=deus first=MATTHEUM22:32")
    }

    func testRapidSearchReplacementCloseAndRepeatResult() throws {
        let app = XCUIApplication()
        app.launch()
        selectEdition("web-ce", in: app)
        openSearch(in: app)
        let field = app.textFields["search-query-input"]
        field.tap()
        field.typeText("In the beginning")
        let clear = app.buttons["search-clear-button"]
        XCTAssertTrue(clear.waitForExistence(timeout: 3))
        clear.tap()
        field.typeText("John 3:16")
        assertResult("John 3:16", in: app)
        XCTAssertFalse(app.buttons["search-result-1"].label.contains("John 1:2"))
        app.buttons["search-result-1"].tap()

        let verse = app.buttons["reader-verse-16"]
        XCTAssertTrue(verse.waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["reader-title"].label.contains("John 3"))
        XCTAssertTrue(app.buttons["reader-search-button"].waitForExistence(timeout: 8))
        app.buttons["reader-search-button"].tap()

        XCTAssertTrue(app.textFields["search-query-input"].waitForExistence(timeout: 8))
        replaceQuery(with: "John 3:16", in: app)
        assertResult("John 3:16", in: app)
        app.buttons["search-result-1"].tap()
        XCTAssertTrue(app.buttons["reader-verse-16"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["reader-title"].label.contains("John 3"))

        app.buttons["reader-search-button"].tap()
        XCTAssertTrue(app.textFields["search-query-input"].waitForExistence(timeout: 8))
        app.buttons["search-cancel-button"].tap()
        XCTAssertTrue(app.buttons["reader-title"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["reader-verse-16"].exists)
        NSLog("SEARCH_ROUTE_RESULT reference=John3:16 openedVerse=16 repeatedResult=John3:16 cancel=Reader; rapidReplacement=final-visible-query-state")
    }

    private func openSearch(in app: XCUIApplication) {
        let readTab = app.buttons["tab-read"]
        XCTAssertTrue(readTab.waitForExistence(timeout: 10))
        readTab.tap()
        let searchButton = app.buttons["reader-search-button"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 8))
        searchButton.tap()
        XCTAssertTrue(app.textFields["search-query-input"].waitForExistence(timeout: 8))
    }

    private func selectEdition(_ editionID: String, in app: XCUIApplication) {
        let settingsTab = app.buttons["tab-settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 8))
        settingsTab.tap()
        let edition = app.buttons["translation-\(editionID)"]
        XCTAssertTrue(edition.waitForExistence(timeout: 8))
        edition.tap()
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Selected"), object: edition)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 8), .completed,
                       "Settings must commit the requested edition before the next route")
        let readTab = app.buttons["tab-read"]
        XCTAssertTrue(readTab.waitForExistence(timeout: 8))
        readTab.tap()
    }

    private func enter(_ query: String, in field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(query)
    }

    private func replaceQuery(with query: String, in app: XCUIApplication) {
        let clear = app.buttons["search-clear-button"]
        if clear.exists {
            XCTAssertTrue(clear.isHittable)
            clear.tap()
        }
        enter(query, in: app.textFields["search-query-input"])
    }

    private func assertResult(_ reference: String, in app: XCUIApplication, timeout: TimeInterval = 12,
                              file: StaticString = #filePath, line: UInt = #line) {
        let result = app.buttons["search-result-1"]
        let predicate = NSPredicate(format: "label BEGINSWITH %@", "\(reference).")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: result)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed,
                       "Expected first source-ordered result \(reference), got \(result.label)", file: file, line: line)
    }

    private func waitForLabel(_ element: XCUIElement, equals value: String,
                              timeout: TimeInterval = 12,
                              file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", value), object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Expected label \(value), got \(element.label)", file: file, line: line)
        return result == .completed
    }
}
