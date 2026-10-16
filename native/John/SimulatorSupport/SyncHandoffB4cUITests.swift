import XCTest

/// Slice B4c: iCloud sync toggle in Settings and Handoff state. Each test starts from reset state with sync off.
@MainActor
final class SyncHandoffB4cUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnResetNativeState", "-JohnTabBarMinimize", "never", "-JohnReaderMode", "scroll"] + extra
        app.launch()
        return app
    }

    private func openTab(_ app: XCUIApplication, _ name: String) {
        let button = app.tabBars.buttons[name].exists ? app.tabBars.buttons[name] : app.tabBars.buttons["tab-\(name.lowercased())"]
        XCTAssertTrue(button.waitForExistence(timeout: 20))
        button.tap()
    }

    func testICloudSyncIsOffByDefaultAndToggleShowsStatus() throws {
        let app = launch()
        openTab(app, "Settings")
        let toggle = app.switches["settings-icloud-sync-toggle"]
        var swipes = 0
        while !toggle.exists && swipes < 8 { app.swipeUp(); swipes += 1 }
        try XCTSkipUnless(toggle.waitForExistence(timeout: 3),
                          "iCloud sync is hidden: this build sets JohnCloudSyncAvailable to false (no iCloud entitlement)")
        let status = app.staticTexts["settings-icloud-sync-status"]
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertTrue(status.label.hasPrefix("Off"))

        toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()
        let on = NSPredicate(format: "value == '1'")
        expectation(for: on, evaluatedWith: toggle)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(status.label.hasPrefix("Off"))
        XCTAssertTrue(app.buttons["settings-icloud-sync-now"].exists)

        toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()
        expectation(for: NSPredicate(format: "value == '0'"), evaluatedWith: toggle)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(status.label.hasPrefix("Off"))
    }

    func testReaderPublishesHandoffForChapterAndVerse() throws {
        let app = launch(["-JohnOpenURL", "nrsv://read?book=JHN&chapter=3"])
        let state = app.otherElements["handoff-state-com.nrsv.verse.reading"]
        XCTAssertTrue(state.waitForExistence(timeout: 25))
        let value = state.value as? String ?? ""
        XCTAssertTrue(value.hasPrefix("nrsv://read?"), value)
        XCTAssertTrue(value.contains("book=JHN") && value.contains("chapter=3"), value)
    }

    func testSavedPublishesHandoff() throws {
        let app = launch()
        openTab(app, "Saved")
        let state = app.otherElements["handoff-state-com.nrsv.verse.saved"]
        XCTAssertTrue(state.waitForExistence(timeout: 15))
        XCTAssertEqual(state.value as? String, "nrsv://saved")
    }
}
