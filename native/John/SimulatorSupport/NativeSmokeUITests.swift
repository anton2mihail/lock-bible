import XCTest

@MainActor
final class NativeSmokeUITests: XCTestCase {
    func testPrimaryTabsAndSharedReaderAppearance() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))

        let readTab = app.buttons["tab-read"]
        XCTAssertTrue(readTab.waitForExistence(timeout: 5))
        readTab.tap()
        XCTAssertTrue(app.staticTexts["reader-book-list-title"].waitForExistence(timeout: 5))
        app.buttons["reader-book-JHN"].tap()
        XCTAssertTrue(app.buttons["reader-chapter-1"].waitForExistence(timeout: 5))
        app.buttons["reader-chapter-1"].tap()
        XCTAssertTrue(app.buttons["reader-appearance-button"].waitForExistence(timeout: 10))
        let verse = app.buttons["reader-verse-1"]
        XCTAssertTrue(verse.waitForExistence(timeout: 10))
        verse.tap()
        XCTAssertTrue(app.staticTexts["reader-selection-summary"].waitForExistence(timeout: 5))

        app.buttons["reader-appearance-button"].tap()
        let readerSize = app.buttons["settings-text-size"]
        XCTAssertTrue(readerSize.waitForExistence(timeout: 5))
        readerSize.tap()
        app.buttons["Large"].tap()
        XCTAssertTrue(app.buttons["settings-text-size"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["settings-text-size"].value as? String, "Large")
        app.buttons["reader-appearance-close"].tap()

        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "page-title-settings").firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["settings-text-size"].value as? String, "Large")

        for (tab, title) in [
            ("tab-saved", "page-title-saved"),
            ("tab-pray", "page-title-pray"),
            ("tab-today", "today-title")
        ] {
            let button = app.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing tab: \(tab)")
            button.tap()
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: title).firstMatch.waitForExistence(timeout: 5), "Missing root: \(title)")
        }
    }

    func testColdAndRepeatedURLsAndDurableReadingSize() throws {
        let app = XCUIApplication()
        let readURL = URL(string: "nrsv://read?book=JHN&chapter=1&verse=1")!
        app.launchArguments = ["-L04TestStartupDelaySeconds", "5"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Loading saved data."].waitForExistence(timeout: 3))
        app.open(readURL)
        XCTAssertTrue(app.buttons["reader-verse-1"].waitForExistence(timeout: 15), "Queued URL must open after saved state loads")

        let settingsTab = app.buttons["tab-settings"]
        settingsTab.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "page-title-settings").firstMatch.waitForExistence(timeout: 5))
        app.open(readURL)
        XCTAssertTrue(app.buttons["reader-verse-1"].waitForExistence(timeout: 10), "First ready URL must open the Reader")
        settingsTab.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "page-title-settings").firstMatch.waitForExistence(timeout: 5))
        app.open(readURL)
        XCTAssertTrue(app.buttons["reader-verse-1"].waitForExistence(timeout: 10), "Repeated equal URL must open the Reader again")

        settingsTab.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "page-title-settings").firstMatch.waitForExistence(timeout: 5))
        let readerSize = app.buttons["settings-text-size"]
        readerSize.tap()
        app.buttons["Extra large"].tap()
        XCTAssertEqual(readerSize.value as? String, "Extra large")
        app.terminate()

        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 15))
        settingsTab.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "page-title-settings").firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["settings-text-size"].value as? String, "Extra large", "Aa value must survive a fresh process")
    }

    func testSameIDReleasePreferenceSurvivesFreshProcess() throws {
        let app = XCUIApplication(bundleIdentifier: "com.nrsv.verse")
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 15))
        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "page-title-settings").firstMatch.waitForExistence(timeout: 5))

        let textSize = app.buttons["settings-text-size"]
        XCTAssertTrue(textSize.waitForExistence(timeout: 5))
        textSize.tap()
        app.buttons["Large"].tap()
        let largeSaved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Large"), object: textSize)
        XCTAssertEqual(XCTWaiter.wait(for: [largeSaved], timeout: 10), .completed)
        NSLog("L04_SAME_ID_RELEASE_NATIVE_SIZE_UPDATED value=Large")
        app.terminate()

        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 15))
        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "page-title-settings").firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["settings-text-size"].value as? String, "Large", "Native state must win over the unchanged legacy MMKV value")
        NSLog("L04_SAME_ID_RELEASE_NATIVE_SIZE_RESTORED value=Large")
    }

    func testSameProcessRepeatedReadyURLs() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 15))
        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "page-title-settings").firstMatch.waitForExistence(timeout: 5))

        NSLog("L04_READY_URL_PHASE_1")
        let firstReader = app.buttons["reader-verse-1"]
        XCTAssertTrue(firstReader.waitForExistence(timeout: 45), "Host must send the first URL to the running app")
        let readerTitle = app.buttons["reader-title"]
        XCTAssertTrue(readerTitle.waitForExistence(timeout: 5))
        let firstRequestID = try XCTUnwrap(readerTitle.value as? String)
        XCTAssertFalse(firstRequestID.isEmpty)
        NSLog("L04_READY_URL_PHASE_1_REQUEST id=%@", firstRequestID)
        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "page-title-settings").firstMatch.waitForExistence(timeout: 5))

        NSLog("L04_READY_URL_PHASE_2")
        let newRequest = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == YES AND value != %@ AND value != ''", firstRequestID),
            object: readerTitle
        )
        XCTAssertEqual(XCTWaiter.wait(for: [newRequest], timeout: 45), .completed,
                       "Repeated equal URL must create a new Reader request in the same process")
        let secondRequestID = try XCTUnwrap(readerTitle.value as? String)
        XCTAssertNotEqual(firstRequestID, secondRequestID)
        XCTAssertEqual(readerTitle.label, "John 1")
        XCTAssertTrue(firstReader.waitForExistence(timeout: 5))
        NSLog("L04_READY_URL_PHASE_2_DELIVERED firstID=%@ secondID=%@", firstRequestID, secondRequestID)
        Thread.sleep(forTimeInterval: 15)
    }
}
