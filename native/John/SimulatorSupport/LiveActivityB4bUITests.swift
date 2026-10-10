import XCTest

/// Slice B4b: the Live Activity state for the Lectio timer, and the Lectio route that the Control Center control uses.
@MainActor
final class LiveActivityB4bUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func tapWhenReady(_ element: XCUIElement) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { element.tap(); return }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("Element did not become hittable: \(element)")
    }

    func testLectioTimerStartsAndEndsLiveActivity() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnResetNativeState", "-JohnTabBarMinimize", "never",
                                "-JohnOpenURL", "nrsv://pray/lectio"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Read slowly"].waitForExistence(timeout: 25))
        let state = app.descendants(matching: .any)["liveActivityState"]
        XCTAssertTrue(state.waitForExistence(timeout: 5))
        XCTAssertEqual(state.label, "idle")
        for _ in 0..<3 { tapWhenReady(app.buttons["Continue"]) }
        tapWhenReady(app.buttons["Begin one quiet minute"])
        let started = NSPredicate(format: "label == 'active' OR label == 'unavailable'")
        let startedExpectation = XCTNSPredicateExpectation(predicate: started, object: state)
        XCTAssertEqual(XCTWaiter.wait(for: [startedExpectation], timeout: 8), .completed)
        NSLog("LIVE_ACTIVITY_B4B state_after_start=%@", state.label)
        XCTAssertEqual(state.label, "active", "The simulator must allow Live Activities")
        tapWhenReady(app.buttons["End the timer"])
        let ended = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'idle'"), object: state)
        XCTAssertEqual(XCTWaiter.wait(for: [ended], timeout: 8), .completed)
    }
}
