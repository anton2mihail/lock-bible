import XCTest

/// Advent with the Fathers (2.2.0): the Today card, the Fathers on today's Gospel, and the Advent page. Run:
/// `scripts/native/run-tests.sh AdventUITests`.
///
/// The feature clock (`-L14FeatureDate`) sets the day. 5 December 2026 has a Matthew Gospel (Catena Aurea);
/// 17 December has the first O Antiphon; 22 November (Christ the King, Matthew 25) is before Advent.
///
/// 1. In Advent, Today shows the Advent card and one Father's comment on the Gospel.
/// 2. Locked: the comment's button opens the Catena section on the unlock page; purchased: it reads.
/// 3. On 17 December the card names O Wisdom, and the Advent page marks it "Tonight".
/// 4. Before Advent there is no Advent card, but the Fathers on the Gospel are still on Today.
@MainActor
final class AdventUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testTodayInAdventLocked() {
        let app = launch(date: "2026-12-05T17:00:00Z", access: "locked")
        XCTAssertTrue(element(app, "today-advent").exists)
        let excerpt = element(app, "today-fathers-excerpt")
        scrollTo(excerpt, in: app)
        XCTAssertTrue(excerpt.label.contains("miracles"), excerpt.label)
        attach(app, "today-5-december")
        let open = element(app, "today-fathers-open")
        scrollTo(open, in: app)
        open.tap()
        XCTAssertTrue(app.buttons["fathers-buy"].waitForExistence(timeout: 10), "The Catena section did not show the unlock page")
    }

    func testFathersOpenPurchased() {
        let app = launch(date: "2026-12-05T17:00:00Z", access: "purchased")
        let open = element(app, "today-fathers-open")
        scrollTo(open, in: app)
        open.tap()
        XCTAssertTrue(app.descendants(matching: .any)["works-prose"].waitForExistence(timeout: 10), "The Catena section did not read")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Matthew 9:3'")).firstMatch.exists)
    }

    func testAntiphonOn17December() {
        let app = launch(date: "2026-12-17T17:00:00Z", access: "locked")
        let card = element(app, "today-advent")
        scrollTo(card, in: app)
        XCTAssertTrue(card.label.contains("O Wisdom"), card.label)
        card.tap()
        let wisdom = element(app, "advent-antiphon-17")
        scrollTo(wisdom, in: app)
        XCTAssertTrue(wisdom.label.contains("Tonight") || app.staticTexts["17 December · Tonight"].exists)
        attach(app, "advent-17-december")
    }

    func testBeforeAdvent() {
        let app = launch(date: "2026-11-22T17:00:00Z", access: "locked")
        scrollTo(element(app, "today-fathers-excerpt"), in: app)
        XCTAssertFalse(element(app, "today-advent").exists)
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
        for _ in 0..<12 where !(target.exists && target.isHittable) { app.swipeUp() }
        XCTAssertTrue(target.waitForExistence(timeout: 10), "\(target) not found")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
