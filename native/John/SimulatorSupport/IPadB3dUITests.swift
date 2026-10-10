import XCTest

/// E31 on iPad: sidebar at regular width, tab selection, Reader in the detail column, portrait and landscape.
/// The menu-bar shortcuts (E30) need a hardware keyboard. The headless simulator has none, so they are not tested here.
/// Run on the assigned iPad only.
@MainActor
final class IPadB3dUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JohnResetNativeState", "-JohnTabBarMinimize", "never"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 20))
        return app
    }

    private func shot(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func item(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testSidebarTabsAndReaderPush() throws {
        let device = XCUIDevice.shared
        device.orientation = .portrait
        let app = launch()
        XCTAssertTrue(item("ipad-sidebar", in: app).waitForExistence(timeout: 8), "Regular width must show the sidebar")
        shot("ipad-portrait-today", app)

        for id in ["tab-read", "tab-saved", "tab-pray", "tab-settings", "tab-today"] {
            let row = item(id, in: app)
            XCTAssertTrue(row.waitForExistence(timeout: 6), "Missing sidebar row \(id)")
            row.tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: row)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed, "\(id) must become selected")
        }

        // Reader opens in the detail column.
        item("tab-read", in: app).tap()
        let book = app.buttons["reader-book-JHN"]
        XCTAssertTrue(book.waitForExistence(timeout: 10), "The Reader book list must show in the detail column")
        shot("ipad-portrait-read", app)

        device.orientation = .landscapeLeft
        XCTAssertTrue(item("ipad-sidebar", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["reader-book-JHN"].waitForExistence(timeout: 8))
        shot("ipad-landscape-read", app)
        device.orientation = .portrait
    }
}
