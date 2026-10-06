import XCTest

/// Step 7 widget checks. They read and tap widgets that Main already added to the first home screen page.
/// They never add a widget. Main adds the Daily Verse, Verse Countdown, and Daily Reading widgets by hand
/// (see docs/native/reviews/Step7-remaining-feature-checks-plan.md). Each test runs only when STEP7_CASES lists its case.
///
/// What this can prove: the text that a widget renders (accessibility labels in SpringBoard), its frame in points,
/// and that a tap opens the expected app destination. What it cannot prove: effective App Group access
/// (see the shared probe in the plan), widget gallery behavior, timeline reload timing, or a physical device.
@MainActor
final class WidgetHomeScreenUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func requireStep7(_ name: String) throws {
        let listed = (ProcessInfo.processInfo.environment["STEP7_CASES"] ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard listed.contains(name) else { throw XCTSkip("Set STEP7_CASES=\(name) to run this Step 7 check.") }
    }

    private func showHomeScreen() -> XCUIApplication {
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(springboard.wait(for: .runningForeground, timeout: 10), "SpringBoard must be in the foreground")
        return springboard
    }

    /// Collect every labeled element of the home screen. STEP7_WIDGET_EXPECT lists strings separated by "||".
    /// Each string must appear in some label. The test logs each match with its frame (the rendered size).
    /// STEP7_WIDGET_WAIT_SECONDS (default 3) waits for the timeline to render.
    func testStep7WidgetRenderedTextOnHomeScreen() throws {
        try requireStep7("widget-render")
        let env = ProcessInfo.processInfo.environment
        let expected = (env["STEP7_WIDGET_EXPECT"] ?? "").components(separatedBy: "||").filter { !$0.isEmpty }
        guard !expected.isEmpty else { XCTFail("Set STEP7_WIDGET_EXPECT to strings separated by ||"); return }
        let springboard = showHomeScreen()
        Thread.sleep(forTimeInterval: Double(env["STEP7_WIDGET_WAIT_SECONDS"] ?? "") ?? 3)
        var rows: [(label: String, line: String)] = []
        for element in springboard.descendants(matching: .any).allElementsBoundByIndex where element.exists {
            let label = element.label
            guard !label.isEmpty else { continue }
            rows.append((label, "type=\(element.elementType.rawValue) frame=\(NSCoder.string(for: element.frame)) label=\(label)"))
        }
        let screenshot = XCTAttachment(screenshot: springboard.screenshot())
        screenshot.name = "step7-widget-home-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let dump = XCTAttachment(string: rows.map(\.line).joined(separator: "\n"))
        dump.name = "step7-widget-home-labels"
        dump.lifetime = .keepAlways
        add(dump)
        for text in expected {
            let matches = rows.filter { $0.label.contains(text) }
            NSLog("STEP7_WIDGET_TEXT expected=%@ matches=%d first=%@", text, matches.count, matches.first?.line ?? "none")
            XCTAssertFalse(matches.isEmpty, "No home screen label contains: \(text)")
        }
    }

    /// Tap the widget whose label contains STEP7_WIDGET_TAP_LABEL_CONTAINS. Then check the destination.
    /// Reader destination: STEP7_WIDGET_EXPECT_READER_TITLE (for example "2 Timothy 2") and STEP7_WIDGET_EXPECT_VERSE ("23").
    /// Daily destination: STEP7_WIDGET_EXPECT_DAILY_DATE (for example "Oct 6, 2026").
    /// STEP7_WIDGET_COLD=1 stops the app first, so the tap is a cold launch.
    func testStep7WidgetTapOpensExpectedDestination() throws {
        try requireStep7("widget-tap")
        let env = ProcessInfo.processInfo.environment
        guard let needle = env["STEP7_WIDGET_TAP_LABEL_CONTAINS"], !needle.isEmpty else {
            XCTFail("Set STEP7_WIDGET_TAP_LABEL_CONTAINS"); return
        }
        let app = XCUIApplication()
        if env["STEP7_WIDGET_COLD"] == "1", app.state != .notRunning { app.terminate() }
        let springboard = showHomeScreen()
        let widget = springboard.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
        XCTAssertTrue(widget.waitForExistence(timeout: 10), "No widget label contains: \(needle)")
        NSLog("STEP7_WIDGET_TAP target=%@ frame=%@ cold=%d", widget.label, NSCoder.string(for: widget.frame),
              env["STEP7_WIDGET_COLD"] == "1" ? 1 : 0)
        widget.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25), "The widget tap must open the app")
        if let title = env["STEP7_WIDGET_EXPECT_READER_TITLE"] {
            let readerTitle = app.buttons["reader-title"]
            XCTAssertTrue(readerTitle.waitForExistence(timeout: 20), "The Reader must open")
            XCTAssertEqual(readerTitle.label, title)
            if let verse = env["STEP7_WIDGET_EXPECT_VERSE"] {
                let summary = app.staticTexts["reader-selection-summary"]
                XCTAssertTrue(summary.waitForExistence(timeout: 12), "The displayed verse must be selected")
                XCTAssertEqual(summary.label, "Selected: verses \(verse)–\(verse)")
            }
        } else if let date = env["STEP7_WIDGET_EXPECT_DAILY_DATE"] {
            let page = app.staticTexts["content-page-title"]
            XCTAssertTrue(page.waitForExistence(timeout: 20))
            XCTAssertEqual(page.label, "Today’s readings")
            XCTAssertTrue(app.staticTexts[date].waitForExistence(timeout: 8), "The Daily route must show \(date)")
        } else {
            XCTFail("Set STEP7_WIDGET_EXPECT_READER_TITLE or STEP7_WIDGET_EXPECT_DAILY_DATE")
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "step7-widget-tap-destination"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Launch the app with the proposed DEBUG shared-container probe argument. Main copies the output file afterward.
    /// Needs the proposed hook. Set STEP7_PROBE_HOOK_PRESENT=1 only on a build that has it.
    /// STEP7_PROBE_RELATIVE_PATH is relative to the app's Documents folder, for example Step7Probe/run-01.json.
    func testStep7LaunchSharedContainerProbe() throws {
        try requireStep7("shared-probe")
        let env = ProcessInfo.processInfo.environment
        guard env["STEP7_PROBE_HOOK_PRESENT"] == "1" else {
            throw XCTSkip("This check needs the proposed -L29SharedProbeRelativePath hook. Set STEP7_PROBE_HOOK_PRESENT=1 on a build that has it.")
        }
        guard let path = env["STEP7_PROBE_RELATIVE_PATH"], !path.isEmpty else {
            XCTFail("Set STEP7_PROBE_RELATIVE_PATH"); return
        }
        let app = XCUIApplication()
        app.launchArguments += ["-L29SharedProbeRelativePath", path]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 8)
        NSLog("STEP7_SHARED_PROBE launched relativePath=%@", path)
    }
}
