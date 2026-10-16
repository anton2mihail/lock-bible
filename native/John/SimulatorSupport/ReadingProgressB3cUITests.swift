import XCTest

/// E7 reading progress and plan, and E28 Today background. Each test starts from clean state.
@MainActor
final class ReadingProgressB3cUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JohnResetNativeState", "-JohnTabBarMinimize", "never", "-JohnReaderMode", "scroll",
                               "-L14FeatureDate", "2026-09-13T16:00:00Z", "-L14FeatureTimeZone", "America/Toronto"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 20))
        return app
    }

    private func tab(_ id: String, in app: XCUIApplication) -> XCUIElement {
        let byID = app.buttons.matching(identifier: "tab-\(id)").firstMatch
        return byID.exists ? byID : app.tabBars.buttons[id.capitalized]
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var tries = 0
        while !(element.exists && element.isHittable) && tries < 8 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(element.exists, "Missing \(element.identifier)")
    }

    func testRingsPlanAndMarkRead() throws {
        let app = launch()
        let overall = app.descendants(matching: .any)["progress-ring-overall"]
        scrollTo(overall, in: app)
        // First frame: the ring shows its final value, and it is zero on clean state.
        XCTAssertTrue((overall.value as? String ?? "").hasPrefix("0 percent"), "\(String(describing: overall.value))")

        let start = app.buttons["today-plan-start-john-21"]
        scrollTo(start, in: app)
        start.tap()
        let assignment = app.staticTexts["today-plan-assignment"]
        XCTAssertTrue(assignment.waitForExistence(timeout: 5))
        XCTAssertEqual(assignment.label, "Today: John 1")

        app.buttons["today-plan-open"].tap()
        let mark = app.buttons["reader-mark-read"]
        var tries = 0
        while !(mark.exists && mark.isHittable) && tries < 12 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(mark.exists)
        XCTAssertEqual(mark.value as? String, "Unread")
        mark.tap()
        XCTAssertEqual(mark.value as? String, "Read")

        tab("today", in: app).tap()
        let john = app.descendants(matching: .any)["progress-ring-john"]
        scrollTo(john, in: app)
        XCTAssertTrue((john.value as? String ?? "").contains("1 of 21"), "\(String(describing: john.value))")
        XCTAssertEqual(app.staticTexts["today-plan-assignment"].label, "John 1 — read")
    }

    func testScrollingToEndMarksChapterRead() throws {
        let app = launch()
        tab("read", in: app).tap()
        let book = app.buttons["reader-book-JHN"]
        if book.waitForExistence(timeout: 5) { book.tap() }
        let chapter = app.buttons["reader-chapter-1"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 8))
        chapter.tap()
        let mark = app.buttons["reader-mark-read"]
        var tries = 0
        while mark.value as? String != "Read" && tries < 20 { app.swipeUp(velocity: .fast); tries += 1 }
        XCTAssertEqual(mark.value as? String, "Read")
    }

    func testResetInSettings() throws {
        let app = launch()
        let start = app.buttons["today-plan-start-john-7"]
        scrollTo(start, in: app)
        start.tap()
        XCTAssertTrue(app.staticTexts["today-plan-assignment"].waitForExistence(timeout: 5))
        tab("settings", in: app).tap()
        let reset = app.buttons["settings-reset-progress"]
        scrollTo(reset, in: app)
        XCTAssertTrue(app.switches["settings-reading-reminder"].exists)
        reset.tap()
        let confirm = app.buttons.matching(identifier: "settings-reset-progress-confirm").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        tab("today", in: app).tap()
        let picker = app.buttons["today-plan-start-john-21"]
        scrollTo(picker, in: app)
        XCTAssertTrue(picker.exists)
    }
}
