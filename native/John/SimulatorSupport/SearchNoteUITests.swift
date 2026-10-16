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
        app.launchArguments += ["-JohnTabBarMinimize", "never", "-JohnReaderMode", "scroll"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
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
        app.launchArguments += ["-JohnResetNativeState"] // test isolation: default edition and Reader location
        app.launchArguments += ["-JohnTabBarMinimize", "never", "-JohnReaderMode", "scroll"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
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

        tapSystemBack(in: app, expecting: app.buttons["reader-search-button"])
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
        app.launchArguments += ["-JohnTabBarMinimize", "never", "-JohnReaderMode", "scroll"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
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
        tapSystemBack(in: app, expecting: app.buttons["reader-title"])
        XCTAssertTrue(app.buttons["reader-title"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["reader-verse-16"].exists)
        NSLog("SEARCH_ROUTE_RESULT reference=John3:16 openedVerse=16 repeatedResult=John3:16 cancel=Reader; rapidReplacement=final-visible-query-state")
    }

    func testCreateVulgateNoteRetainsOriginalEditionAfterChangeAndRestart() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never", "-JohnReaderMode", "scroll"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        selectEdition("vulgate", in: app)
        selectVerseByVerseLayout(in: app)
        openSearch(in: app)
        enter("John 3:16", in: app.textFields["search-query-input"])
        assertResult("IOHANNEM 3:16", in: app)
        app.buttons["search-result-1"].tap()

        let verse = app.buttons["reader-verse-16"]
        XCTAssertTrue(verse.waitForExistence(timeout: 12))
        XCTAssertTrue(verse.label.contains("Sic enim Deus dilexit mundum"), verse.label)
        verse.tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["reader-selection-reference"], equals: "IOHANNEM 3:16"))
        let addNote = app.buttons["reader-selection-note"]
        XCTAssertTrue(addNote.waitForExistence(timeout: 8))
        XCTAssertTrue(addNote.isHittable)
        addNote.tap()

        let editor = app.textViews["saved-note-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 8))
        waitUntilEnabled(app.buttons["saved-note-save"])
        XCTAssertEqual(editor.value as? String, "")
        let note = "Created from the Vulgate at John 3:16."
        editor.tap()
        editor.typeText(note)
        app.buttons["saved-note-save"].tap()
        waitForDisappearance(editor)

        selectEdition("web-ce", in: app)
        tabButton(app, "tab-saved").tap()
        let noteFilter = app.buttons["saved-filter-note"]
        XCTAssertTrue(noteFilter.waitForExistence(timeout: 8))
        noteFilter.tap()
        let noteRowID = "saved-row-note:vulgate:JHN:3:16:16"
        var row = app.buttons[noteRowID]
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        XCTAssertTrue(row.label.contains("IOHANNEM 3:16"), row.label)
        XCTAssertTrue(row.label.contains("Sic enim Deus dilexit mundum"), row.label)
        row.tap()
        var reopenedEditor = app.textViews["saved-note-editor"]
        XCTAssertTrue(reopenedEditor.waitForExistence(timeout: 8))
        waitUntilEnabled(app.buttons["saved-note-save"])
        XCTAssertEqual(reopenedEditor.value as? String, note)
        let latinPreview = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@", "Sic enim Deus dilexit mundum"
        )).firstMatch
        XCTAssertTrue(latinPreview.waitForExistence(timeout: 5), "Saved text must use the captured Vulgate edition")
        app.buttons["saved-note-cancel"].tap()
        XCTAssertTrue(reopenedEditor.waitForNonExistence(timeout: 8))

        app.terminate()
        app.launchArguments += ["-JohnTabBarMinimize", "never", "-JohnReaderMode", "scroll"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        tabButton(app, "tab-saved").tap()
        let relaunchedFilter = app.buttons["saved-filter-note"]
        XCTAssertTrue(relaunchedFilter.waitForExistence(timeout: 8))
        relaunchedFilter.tap()
        row = app.buttons[noteRowID]
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        XCTAssertTrue(row.label.contains("IOHANNEM 3:16"), row.label)
        XCTAssertTrue(row.label.contains("Sic enim Deus dilexit mundum"), row.label)
        row.tap()
        reopenedEditor = app.textViews["saved-note-editor"]
        XCTAssertTrue(reopenedEditor.waitForExistence(timeout: 8))
        waitUntilEnabled(app.buttons["saved-note-save"])
        XCTAssertEqual(reopenedEditor.value as? String, note)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@", "Sic enim Deus dilexit mundum"
        )).firstMatch.exists)
        NSLog("SEARCH_NOTE_RESTART rowID=note:vulgate:JHN:3:16:16 translationID=vulgate bookCode=JHN chapter=3 startVerse=16 endVerse=16 reference=IOHANNEM3:16 note=%@ currentEdition=web-ce restartCount=1 seedRequiresNoNoteForJHN3:16 and verse-by-verse layout", note)
    }

    /// The iOS 26 system glass back button of a pushed screen. It replaced the Search `search-cancel-button`.
    private func systemBack(in app: XCUIApplication) -> XCUIElement {
        // `navigationBars.buttons.firstMatch` can return a trailing button or the button of another bar. Prefer the
        // `BackButton` identifier (the front-most one when two bars are on screen during a push). Otherwise use the
        // left-most hittable button of the front-most navigation bar.
        let named = app.navigationBars.buttons.matching(identifier: "BackButton")
        if named.count > 0 { return named.element(boundBy: named.count - 1) }
        let bars = app.navigationBars.allElementsBoundByIndex.filter { $0.exists }
        if let bar = bars.last(where: { $0.isHittable }) ?? bars.last {
            let buttons = bar.buttons.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
            if let leftmost = buttons.min(by: { $0.frame.minX < $1.frame.minX }) { return leftmost }
        }
        return app.navigationBars.buttons.firstMatch
    }

    /// Identity of the visible screen: the navigation bars, the page titles, and the number of back buttons.
    /// Taps Back and waits for the expected parent screen.
    private func tapSystemBack(in app: XCUIApplication, expecting parent: XCUIElement,
                               file: StaticString = #filePath, line: UInt = #line) {
        let back = systemBack(in: app)
        XCTAssertTrue(back.waitForExistence(timeout: 10), "Back control did not appear", file: file, line: line)
        back.tap()
        XCTAssertTrue(parent.waitForExistence(timeout: 10), "The parent screen must appear after Back", file: file, line: line)
    }

    private func openSearch(in app: XCUIApplication) {
        let readTab = tabButton(app, "tab-read")
        XCTAssertTrue(readTab.waitForExistence(timeout: 10))
        readTab.tap()
        let searchButton = app.buttons["reader-search-button"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 8))
        searchButton.tap()
        XCTAssertTrue(app.textFields["search-query-input"].waitForExistence(timeout: 8))
    }

    private func selectEdition(_ editionID: String, in app: XCUIApplication) {
        let settingsTab = tabButton(app, "tab-settings")
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 8))
        settingsTab.tap()
        let edition = app.buttons["translation-\(editionID)"]
        XCTAssertTrue(edition.waitForExistence(timeout: 8))
        edition.tap()
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Selected"), object: edition)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 8), .completed,
                       "Settings must commit the requested edition before the next route")
        let readTab = tabButton(app, "tab-read")
        XCTAssertTrue(readTab.waitForExistence(timeout: 8))
        readTab.tap()
    }

    private func selectVerseByVerseLayout(in app: XCUIApplication) {
        tabButton(app, "tab-settings").tap()
        let layout = app.buttons["settings-layout-verse-by-verse"]
        XCTAssertTrue(layout.waitForExistence(timeout: 8))
        if layout.value as? String != "Selected" {
            layout.tap()
            let selected = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", "Selected"), object: layout)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 8), .completed,
                           "Reader layout must be committed before verse selection")
        }
        tabButton(app, "tab-read").tap()
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

    private func waitForDisappearance(_ element: XCUIElement,
                                     timeout: TimeInterval = 8,
                                     file: StaticString = #filePath,
                                     line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed,
                       "Editor did not close", file: file, line: line)
    }

    private func waitUntilEnabled(_ element: XCUIElement,
                                  timeout: TimeInterval = 8,
                                  file: StaticString = #filePath,
                                  line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed,
                       "Control did not become enabled", file: file, line: line)
    }

    /// Tab bar button that survives a missing `tab-*` identifier (the system TabView sometimes drops it; the labels
    /// Today, Read, Saved, Pray, Settings are always present). Order: `tabBars.buttons[identifier]`,
    /// `tabBars.buttons[label]` (exact), `buttons[identifier]`. If none exists and the bar is minimized (one bubble),
    /// tap the bar to expand it and look again. If the bar does not exist yet, the returned query waits on the label.
    private func tabButton(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let name = identifier.hasPrefix("tab-") ? String(identifier.dropFirst(4)) : identifier
        let label = name.prefix(1).uppercased() + name.dropFirst()
        let bar = app.tabBars.firstMatch
        func find() -> XCUIElement? {
            [bar.buttons[identifier], bar.buttons[label], app.buttons[identifier]].first { $0.exists }
        }
        if let found = find() { return found }
        if bar.exists, bar.isHittable {
            bar.tap()
            _ = bar.buttons[label].waitForExistence(timeout: 2)
            if let found = find() { return found }
        }
        return bar.buttons[label]
    }
}
