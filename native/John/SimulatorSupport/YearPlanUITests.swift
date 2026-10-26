import XCTest

/// "A Year with the Fathers" (2.3.0): the Today card, the start screen, a day's reading and the library gate. Run:
/// `scripts/native/run-tests.sh YearPlanUITests`.
///
/// The feature clock (`-L14FeatureDate`) sets the day. 20 December 2026 is before the year; 10 February 2027 is
/// Ash Wednesday (Day 41); 8 January 2027 is Day 8, the first day that needs the library.
///
/// 1. Before 1 January, Today invites; "Begin now" starts Day 1, which reads free and can be marked read.
/// 2. On Ash Wednesday, "Join today" gives Day 41, St Leo on Lent (failure Y7).
/// 3. Day 8 shows the library purchase page without the library (failure Y4).
@MainActor
final class YearPlanUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testBeginNowInDecember() {
        let app = launch(date: "2026-12-20T17:00:00Z", access: "locked")
        let card = element(app, "today-year-plan")
        scrollTo(card, in: app)
        XCTAssertTrue(card.label.contains("Begins 1 January"), card.label)
        card.tap()
        XCTAssertTrue(element(app, "year-remind-january").waitForExistence(timeout: 10))
        attach(app, "year-start-december")
        element(app, "year-begin-now").tap()
        let readToday = element(app, "year-read-today")
        XCTAssertTrue(readToday.waitForExistence(timeout: 10))
        readToday.tap()
        XCTAssertTrue(element(app, "year-day-text").waitForExistence(timeout: 10), "Day 1 did not read")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'There are two ways'")).firstMatch.exists)
        let mark = element(app, "year-mark-read")
        scrollTo(mark, in: app)
        mark.tap()
        XCTAssertTrue(element(app, "year-read-state").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "year-mark-unread").exists)
        // One reading: the page title is not repeated as a heading.
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "Chapters I–VI")).count, 1)
        attach(app, "year-day-1-read")
    }

    func testJoinOnAshWednesday() {
        let app = launch(date: "2027-02-10T17:00:00Z", access: "purchased")
        let card = element(app, "today-year-plan")
        scrollTo(card, in: app)
        XCTAssertTrue(card.label.contains("Day 41 today"), card.label)
        card.tap()
        let join = element(app, "year-join-today")
        XCTAssertTrue(join.waitForExistence(timeout: 10))
        join.tap()
        XCTAssertTrue(app.staticTexts["DAY 41 OF 365"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["TODAY · ASH WEDNESDAY"].exists)
        // Joining on Day 41 leaves no missed days.
        XCTAssertFalse(element(app, "year-catch-up").exists)
        attach(app, "year-ash-wednesday")
        element(app, "year-read-today").tap()
        XCTAssertTrue(element(app, "year-day-text").waitForExistence(timeout: 10), "Day 41 did not read")
        XCTAssertTrue(app.staticTexts["On Lent, I"].exists)
        XCTAssertFalse(app.staticTexts["On Lent, I."].exists, "The section title repeats the page title")
        XCTAssertTrue(app.staticTexts["DAY 41 · ASH WEDNESDAY"].exists)
    }

    func testDayEightNeedsTheLibrary() {
        let app = launch(date: "2027-01-08T17:00:00Z", access: "locked")
        let card = element(app, "today-year-plan")
        scrollTo(card, in: app)
        card.tap()
        let join = element(app, "year-join-today")
        XCTAssertTrue(join.waitForExistence(timeout: 10))
        join.tap()
        let readToday = element(app, "year-read-today")
        XCTAssertTrue(readToday.waitForExistence(timeout: 10))
        readToday.tap()
        XCTAssertTrue(app.buttons["fathers-buy"].waitForExistence(timeout: 10), "Day 8 did not show the unlock page")
        XCTAssertFalse(element(app, "year-day-text").exists)
        attach(app, "year-day-8-locked")
    }

    // MARK: - Helpers

    private func launch(date: String, access: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnResetNativeState", "-JohnTabBarMinimize", "never", "-JohnNoReviewPrompt",
                                "-JohnFathersAccess", access, "-L14FeatureDate", date, "-L14FeatureTimeZone", "America/Toronto"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 15))
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    private func scrollTo(_ target: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<20 where !(target.exists && target.isHittable) { app.swipeUp() }
        XCTAssertTrue(target.waitForExistence(timeout: 10), "\(target) not found")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
