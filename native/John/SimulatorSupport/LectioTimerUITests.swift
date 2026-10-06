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
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))

        let prayerTab = app.buttons["tab-pray"]
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
            let tabTop = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tab-"))
                .allElementsBoundByIndex.filter { $0.exists && $0.frame.intersects(viewport) }
                .map(\.frame.minY).min()
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
}
