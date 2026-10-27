import XCTest

/// Lent, Holy Week and the Stations of the Cross (2.3.0). Run: `scripts/native/run-tests.sh LentUITests`.
///
/// The feature clock (`-L14FeatureDate`) sets the day: 11 February 2027 is the Thursday after Ash Wednesday,
/// 12 February a Friday of Lent, 26 March Good Friday, 9 February Shrove Tuesday.
///
/// 1. In Lent, Today's row opens the Lent page with the Collect of the day; Leo's sermon reads without the purchase.
/// 2. On a Friday of Lent the row opens the Stations; Next moves to Station 1.
/// 3. On Good Friday the row opens Holy Week with Good Friday first.
/// 4. Before Ash Wednesday there is no Lent row.
@MainActor
final class LentUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testLentPageAndLeoFree() {
        let app = launch(date: "2027-02-11T17:00:00Z")
        let row = element(app, "today-lent")
        scrollTo(row, in: app)
        row.tap()
        let collect = element(app, "lent-collect")
        scrollTo(collect, in: app)
        XCTAssertTrue(collect.label.contains("Thursday after Ash Wednesday") || app.staticTexts["Thursday after Ash Wednesday"].exists)
        attach(app, "lent-11-february")
        let leo = element(app, "lent-leo-191")
        scrollTo(leo, in: app)
        leo.tap()
        XCTAssertTrue(app.descendants(matching: .any)["works-prose"].waitForExistence(timeout: 10), "Leo's sermon did not read in Lent")
    }

    func testStationsOnFriday() {
        let app = launch(date: "2027-02-12T17:00:00Z")
        let row = element(app, "today-lent")
        scrollTo(row, in: app)
        XCTAssertTrue(row.label.contains("Stations"), row.label)
        row.tap()
        XCTAssertTrue(element(app, "stations-controls").waitForExistence(timeout: 10))
        app.buttons["Next"].tap()
        XCTAssertTrue(element(app, "station-1").waitForExistence(timeout: 10))
        attach(app, "station-1")
    }

    func testHolyWeekOnGoodFriday() {
        let app = launch(date: "2027-03-26T17:00:00Z")
        let row = element(app, "today-holy-week")
        scrollTo(row, in: app)
        XCTAssertTrue(row.label.contains("Good Friday"), row.label)
        row.tap()
        let today = element(app, "holy-week-good-fri")
        scrollTo(today, in: app)
        XCTAssertTrue(app.staticTexts["Today: Good Friday"].exists)
        attach(app, "holy-week-good-friday")
    }

    func testBeforeLent() {
        let app = launch(date: "2027-02-09T17:00:00Z")
        scrollTo(element(app, "today-fathers-excerpt"), in: app)
        XCTAssertFalse(element(app, "today-lent").exists)
    }

    // MARK: - Helpers

    private func launch(date: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnResetNativeState", "-JohnTabBarMinimize", "never", "-JohnNoReviewPrompt",
                                "-JohnFathersAccess", "locked", "-L14FeatureDate", date, "-L14FeatureTimeZone", "America/Toronto"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 15))
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    private func scrollTo(_ target: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<14 where !(target.exists && target.isHittable) { app.swipeUp() }
        XCTAssertTrue(target.waitForExistence(timeout: 10), "\(target) not found")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
