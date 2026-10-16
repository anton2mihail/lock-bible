import XCTest

/// Bounded UI checks for local prayer time, finite calendar coverage, and citation targets.
/// Main owns target membership, task-only seeds, and simulator execution.
@MainActor
final class CalendarBoundaryUITests: XCTestCase {
    private let zone = "America/Toronto"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPrayerChoiceOnBothSidesOfLocalSeventeenHundred() throws {
        let morning = launch(date: "2026-09-13T20:59:00Z") // 16:59 in Toronto.
        assertTodayDate("Sunday, September 13", in: morning)
        let morningPrayer = button(containing: "Morning Offering", in: morning)
        tapWhenReady(morningPrayer, in: morning)
        assertPageTitle("Morning Offering", in: morning)
        morning.terminate()

        let evening = launch(date: "2026-09-13T21:00:00Z") // 17:00 in Toronto.
        assertTodayDate("Sunday, September 13", in: evening)
        let eveningPrayer = button(containing: "Night Prayer", in: evening)
        tapWhenReady(eveningPrayer, in: evening)
        assertPageTitle("Night Prayer", in: evening)
        NSLog("CALENDAR_BOUNDARY prayer=16:59/Morning Offering,17:00/Night Prayer localDate=2026-09-13 zone=%@", zone)
    }

    func testOutOfCoverageDateShowsOfflineMissingReadings() throws {
        let app = launch(date: "2028-01-01T17:00:00Z") // 12:00 in Toronto.
        assertTodayDate("Saturday, January 1", in: app)
        let readings = button(containing: "Today’s readings", in: app)
        tapWhenReady(readings, in: app)
        assertPageTitle("Today’s readings", in: app)
        XCTAssertTrue(app.staticTexts["Jan 1, 2028"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts[
            "Reading references for this date aren’t in your offline library. Open the official readings when you’re connected."
        ].waitForExistence(timeout: 8))
        NSLog("CALENDAR_BOUNDARY coverage=outside date=2028-01-01 zone=%@ result=missing-offline-entry", zone)
    }

    func testJoelAndEstherCitationsKeepOriginalIdentityAndMapChapter() throws {
        assertCitation(
            date: "2025-10-11T16:00:00Z", localDate: "Saturday, October 11",
            reference: "Joel 4:12-21", expectedTitle: "Joel 3"
        )
        assertCitation(
            date: "2026-02-26T17:00:00Z", localDate: "Thursday, February 26",
            reference: "Esther C:12, 14-16, 23-25", expectedTitle: "Esther 4"
        )
    }

    private func assertCitation(date: String, localDate: String, reference: String,
                                expectedTitle: String, file: StaticString = #filePath,
                                line: UInt = #line) {
        let app = launch(date: date)
        assertTodayDate(localDate, in: app, file: file, line: line)
        tapWhenReady(button(containing: "Today’s readings", in: app), in: app, file: file, line: line)
        assertPageTitle("Today’s readings", in: app, file: file, line: line)
        tapWhenReady(button(containing: reference, in: app), in: app, file: file, line: line)
        assertPageTitle(expectedTitle, in: app, file: file, line: line)
        XCTAssertTrue(app.staticTexts["Reading reference: \(reference)"].waitForExistence(timeout: 8), file: file, line: line)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "WEB-CE · Complete chapter"))
            .firstMatch.waitForExistence(timeout: 8), file: file, line: line)
        NSLog("CALENDAR_BOUNDARY citation source=%@ target=%@ edition=WEB-CE localDate=%@ zone=%@",
              reference, expectedTitle, localDate, zone)
    }

    private func launch(date: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-L14FeatureDate", date, "-L14FeatureTimeZone", zone]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))
        return app
    }

    private func assertTodayDate(_ expected: String, in app: XCUIApplication,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let date = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[cd] %@", expected)).firstMatch
        guard date.waitForExistence(timeout: 8) else {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "calendar-boundary-date-missing"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "calendar-boundary-date-missing-ax"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            XCTFail("Today must show local date \(expected)", file: file, line: line)
            return
        }
        NSLog("CALENDAR_BOUNDARY observedDateLabel=%@", date.label)
    }

    private func assertPageTitle(_ expected: String, in app: XCUIApplication,
                                file: StaticString = #filePath, line: UInt = #line) {
        let title = app.staticTexts.matching(NSPredicate(
            format: "identifier == %@ AND label == %@", "content-page-title", expected
        )).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Expected destination title: \(expected)", file: file, line: line)
    }

    private func button(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func tapWhenReady(_ element: XCUIElement, in app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<10 {
            if element.exists && element.isHittable {
                element.tap()
                return
            }
            let viewport = visibleScrollViewport(in: app)
            XCTAssertGreaterThan(viewport.height, 120, "No visible scroll area", file: file, line: line)
            let oldFrame = element.exists ? element.frame : .zero
            let upward = !element.exists || oldFrame.midY >= viewport.midY
            let x = viewport.midX
            let startY = viewport.minY + viewport.height * (upward ? 0.75 : 0.25)
            let endY = viewport.minY + viewport.height * (upward ? 0.25 : 0.75)
            app.coordinate(withNormalizedOffset: CGVector(dx: x / app.frame.width, dy: startY / app.frame.height))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(
                    withNormalizedOffset: CGVector(dx: x / app.frame.width, dy: endY / app.frame.height)
                ))
        }
        XCTAssertTrue(element.exists, "Control did not appear after bounded scrolling", file: file, line: line)
        XCTAssertTrue(element.isHittable, "Control must be hittable", file: file, line: line)
        element.tap()
    }

    private func visibleScrollViewport(in app: XCUIApplication) -> CGRect {
        let scroll = app.scrollViews.allElementsBoundByIndex
            .filter { $0.exists && $0.isHittable }
            .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
        var viewport = (scroll?.frame ?? app.frame).intersection(app.frame)
        if app.keyboards.firstMatch.exists {
            viewport.size.height = min(viewport.height, app.keyboards.firstMatch.frame.minY - viewport.minY)
        }
        let tabTop = tabBarTopEdge(in: app, within: viewport)
        if let tabTop { viewport.size.height = min(viewport.height, tabTop - viewport.minY) }
        let navBottom = app.navigationBars.allElementsBoundByIndex
            .filter { $0.exists && $0.frame.intersects(viewport) }
            .map(\.frame.maxY).max()
        if let navBottom {
            let top = max(viewport.minY, navBottom)
            viewport = CGRect(x: viewport.minX, y: top, width: viewport.width, height: max(0, viewport.maxY - top))
        }
        return viewport
    }

    /// Top edge of the tab bar. The glass bar surface starts above its buttons, so use the bar element frame when it exists.
    /// Otherwise use the top of the tab buttons minus 12 pt (Liquid-glass-tabview-review.md fix 3).
    private func tabBarTopEdge(in app: XCUIApplication, within viewport: CGRect) -> CGFloat? {
        let nativeTabs = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tab-"))
        // Native evidence: a `tab-` identifier, or the exact label "Read" inside the tab bar (the identifier can be dropped).
        // The old app has neither (its labels are ordinal, for example "Read, tab, 2 of 5"); its rules stay as they were.
        guard nativeTabs.firstMatch.exists || app.tabBars.buttons["Read"].exists else { return nil }
        let bar = app.tabBars.firstMatch
        if bar.exists, bar.frame.height > 0 { return bar.frame.minY }
        let tops = (nativeTabs.allElementsBoundByIndex + app.tabBars.buttons.allElementsBoundByIndex)
            .filter { $0.exists && $0.frame.intersects(viewport) }.map(\.frame.minY)
        return tops.min().map { $0 - 12 }
    }
}
