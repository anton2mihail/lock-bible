import XCTest

/// A fresh PrayerHome entry for the Lectio timer. It does not repeat Rosary journeys.
@MainActor
final class LectioTimerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPrayerHomeLectioTimerStartsDecreasesAndEnds() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-L14FeatureDate", "2026-09-13T16:00:00Z",
            "-L14FeatureTimeZone", "America/Toronto",
        ]
        app.launchArguments += ["-JohnTabBarMinimize", "never", "-JohnReaderMode", "scroll"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))

        let prayerTab = tabButton(app, "tab-pray")
        XCTAssertTrue(prayerTab.waitForExistence(timeout: 8))
        tapWhenReady(prayerTab, in: app)
        let lectio = button(containing: "Pray with Scripture", in: app)
        tapWhenReady(lectio, in: app)
        XCTAssertTrue(app.staticTexts["Read slowly"].waitForExistence(timeout: 10))

        for expectedStep in ["Stay with a word", "Speak to God", "Rest in his presence"] {
            tapWhenReady(app.buttons["Continue"], in: app)
            XCTAssertTrue(app.staticTexts[expectedStep].waitForExistence(timeout: 8))
        }

        let countdown = app.staticTexts.matching(NSPredicate(
            format: "label MATCHES %@", "^([1-9]|[1-5][0-9]|60)s of quiet$"
        )).firstMatch
        tapWhenReady(app.buttons["Begin one quiet minute"], in: app)
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        let initialSeconds = Int(countdown.label.split(separator: "s").first ?? "")
        let decreased = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard countdown.exists, let initialSeconds,
                  let current = Int(countdown.label.split(separator: "s").first ?? "") else { return false }
            return current < initialSeconds
        }, object: countdown)
        XCTAssertEqual(XCTWaiter.wait(for: [decreased], timeout: 5), .completed,
                       "The displayed timer value must decrease")
        tapWhenReady(app.buttons["End the timer"], in: app)
        XCTAssertTrue(app.staticTexts["A moment of stillness"].waitForExistence(timeout: 5))
        NSLog("LECTIO_TIMER entry=PrayerHome passage=TodayModel.verse timer=start,decrease,end naturalExpiry=untested")
    }

    private func button(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func tapWhenReady(_ element: XCUIElement, in app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<8 {
            if element.exists && element.isHittable {
                element.tap()
                return
            }
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
            XCTAssertGreaterThan(viewport.height, 120, "No visible scroll area", file: file, line: line)
            let frame = element.exists ? element.frame : .zero
            let upward = !element.exists || frame.midY >= viewport.midY
            let x = viewport.midX
            let start = viewport.minY + viewport.height * (upward ? 0.72 : 0.28)
            let end = viewport.minY + viewport.height * (upward ? 0.28 : 0.72)
            app.coordinate(withNormalizedOffset: CGVector(dx: x / app.frame.width, dy: start / app.frame.height))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(
                    withNormalizedOffset: CGVector(dx: x / app.frame.width, dy: end / app.frame.height)
                ))
        }
        XCTAssertTrue(element.exists, "Control did not appear after bounded scrolling", file: file, line: line)
        XCTAssertTrue(element.isHittable, "Control must be hittable", file: file, line: line)
        element.tap()
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

    /// Tab bar button that survives a missing `tab-*` identifier (the system TabView sometimes drops it; the labels
    /// Today, Read, Saved, Pray, Settings are always present). Order: `tabBars.buttons[identifier]`,
    /// `tabBars.buttons[label]` (exact), `buttons[identifier]`. If none exists and the bar is minimized (one bubble),
    /// tap the bar to expand it and look again. If the bar does not exist yet, the returned query waits on the label.
    private func tabButton(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let name = identifier.hasPrefix("tab-") ? String(identifier.dropFirst(4)) : identifier
        let label = name.prefix(1).uppercased() + name.dropFirst()
        let bar = app.tabBars.firstMatch
        func find() -> XCUIElement? {
            [bar.buttons[identifier], bar.buttons[label], app.buttons[identifier]].first { $0.exists }
        }
        if let found = find() { return found }
        if bar.exists, bar.isHittable {
            bar.tap()
            _ = bar.buttons[label].waitForExistence(timeout: 2)
            if let found = find() { return found }
        }
        return bar.buttons[label]
    }
}
