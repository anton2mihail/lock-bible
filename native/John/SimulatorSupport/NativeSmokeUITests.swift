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
        XCTAssertTrue(app.staticTexts["page-title-read"].waitForExistence(timeout: 5))
        app.buttons["read-open-john-1-1"].tap()
        XCTAssertTrue(app.buttons["reader-appearance-button"].waitForExistence(timeout: 10))

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
}
