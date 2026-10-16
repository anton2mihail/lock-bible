import XCTest

/// Slice B1c. Performance metrics and the Dynamic Type header check.
@MainActor
final class AccessibilityPerfB1cUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testLaunchPerformance() throws {
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTApplicationLaunchMetric()], options: options) {
            let app = XCUIApplication()
            app.launchArguments += ["-JohnTabBarMinimize", "never", "-JohnReaderMode", "scroll"]
            app.launch()
        }
    }

    func testReaderScrollPerformance() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never", "-JohnReaderMode", "scroll", "-JohnResetNativeState"]
        app.launch()
        openJohnOne(in: app)
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
            let window = app.windows.firstMatch
            window.swipeUp(velocity: .fast)
            window.swipeDown(velocity: .fast)
        }
    }

    func testReaderHeaderGrowsAtAccessibility5() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never", "-JohnReaderMode", "scroll", "-JohnResetNativeState",
                                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        openJohnOne(in: app)
        let title = app.buttons["reader-title"]
        XCTAssertGreaterThanOrEqual(title.frame.height, 44)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(title.frame), "\(title.frame)")
        XCTAssertGreaterThanOrEqual(app.buttons["reader-search-button"].frame.height, 44)
    }

    private func openJohnOne(in app: XCUIApplication) {
        let read = app.tabBars.buttons["Read"]
        XCTAssertTrue(read.waitForExistence(timeout: 10))
        read.tap()
        let book = app.buttons["reader-book-JHN"]
        if book.waitForExistence(timeout: 2) { book.tap() }
        let chapter = app.buttons["reader-chapter-1"]
        if chapter.waitForExistence(timeout: 8) { chapter.tap() }
        XCTAssertTrue(app.buttons["reader-title"].waitForExistence(timeout: 10))
    }
}
