import XCTest

/// The Fathers and Doctors purchase (2.1.0): what each access state shows. Run:
/// `scripts/native/run-tests.sh FathersUnlockUITests`.
///
/// The Debug launch argument `-JohnFathersAccess` forces the state, because command-line UI tests do not get the
/// local StoreKit configuration (only a Run from Xcode does). The real purchase and restore are checked on
/// TestFlight with a sandbox account; see `docs/john/release-2.1.0.md`.
///
/// 1. Locked: section 1 of a paid work reads; section 2 shows the unlock page with Buy and Restore Purchases.
/// 2. Purchased: section 2 reads, and no unlock page appears.
/// 3. Grandfathered: Settings says the library is unlocked and why, and the library shows no unlock card.
@MainActor
final class FathersUnlockUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testLockedSampleThenUnlockPage() {
        let app = launch(access: "locked")
        openSermonOnTheMount(app)
        XCTAssertTrue(prose(app).waitForExistence(timeout: 10), "The free first section did not read")
        goToSection(2, in: app)
        XCTAssertTrue(app.buttons["fathers-buy"].waitForExistence(timeout: 10), "Section 2 did not show the unlock page")
        XCTAssertTrue(app.buttons["fathers-restore"].exists)
        XCTAssertFalse(prose(app).exists)
        attach(app, "locked-section-2")
    }

    func testPurchasedReadsPastSample() {
        let app = launch(access: "purchased")
        openSermonOnTheMount(app)
        goToSection(2, in: app)
        XCTAssertTrue(prose(app).waitForExistence(timeout: 10), "Section 2 did not read after a purchase")
        XCTAssertFalse(app.buttons["fathers-buy"].exists)
        attach(app, "purchased-section-2")
    }

    func testGrandfatheredSettingsAndLibrary() {
        let app = launch(access: "grandfathered")
        tabButton(app, "tab-settings").tap()
        let row = app.buttons["settings-fathers"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        for _ in 0..<8 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.label.contains("The full library is unlocked"), row.label)
        XCTAssertTrue(row.label.contains("installed before"), row.label)
        attach(app, "grandfathered-settings")

        tabButton(app, "tab-read").tap()
        openLibrary(app)
        XCTAssertTrue(app.buttons["collection-augustine"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["works-unlock-card"].exists)
    }

    // MARK: - Helpers

    private func launch(access: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnResetNativeState", "-JohnTabBarMinimize", "never", "-JohnNoReviewPrompt",
                                "-JohnFathersAccess", access]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 15))
        return app
    }

    private func prose(_ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any)["works-prose"] }

    private func openLibrary(_ app: XCUIApplication) {
        let back = app.buttons["reader-back"]
        let link = app.buttons["reader-works-link"]
        for _ in 0..<3 where !link.exists && back.exists { back.tap() }
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        link.tap()
    }

    private func openSermonOnTheMount(_ app: XCUIApplication) {
        tabButton(app, "tab-read").tap()
        openLibrary(app)
        let augustine = app.buttons["collection-augustine"]
        XCTAssertTrue(augustine.waitForExistence(timeout: 10))
        augustine.tap()
        let work = app.buttons["work-augustine.our-lord-s-sermon-on-the-mount"]
        XCTAssertTrue(work.waitForExistence(timeout: 10))
        work.tap()
    }

    private func goToSection(_ number: Int, in app: XCUIApplication) {
        let contents = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Contents'")).firstMatch
        XCTAssertTrue(contents.waitForExistence(timeout: 10))
        let next = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Next'")).firstMatch
        for _ in 0..<number where !contents.label.contains(" \(number) of ") { next.tap() }
        XCTAssertTrue(contents.label.contains(" \(number) of "), contents.label)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func tabButton(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let name = identifier.hasPrefix("tab-") ? String(identifier.dropFirst(4)) : identifier
        let label = name.prefix(1).uppercased() + name.dropFirst()
        let bar = app.tabBars.firstMatch
        let candidates = [bar.buttons[identifier], bar.buttons[label], app.buttons[identifier]]
        if let found = candidates.first(where: { $0.waitForExistence(timeout: 2) }) { return found }
        return bar.buttons[label]
    }
}
