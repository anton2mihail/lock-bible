import XCTest

/// F3 manual-check sweep. The host script sets dark mode, content size and Reduce Motion with `simctl`.
/// This test visits the main screens, saves screenshots, and checks VoiceOver labels on every button.
/// Env: `F3_SHOT_DIR` (default /tmp/f3-shots), `F3_TAG` (file name prefix), `F3_LANDSCAPE=1`.
@MainActor
final class F3QualityUITests: XCTestCase {
    private var report: [String] = []

    override func setUpWithError() throws { continueAfterFailure = true }

    func testScreensKeepLabelsAndFit() throws {
        let env = ProcessInfo.processInfo.environment
        let tag = env["F3_TAG"] ?? "default"
        let dir = env["F3_SHOT_DIR"] ?? "/tmp/f3-shots"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        XCUIDevice.shared.orientation = env["F3_LANDSCAPE"] == "1" ? .landscapeLeft : .portrait

        let app = XCUIApplication()
        app.launchArguments = ["-JohnResetNativeState", "-JohnTabBarMinimize", "never",
                               "-L14FeatureDate", "2026-09-13T16:00:00Z", "-L14FeatureTimeZone", "America/Toronto"]
        app.launch()
        XCTAssertTrue(tabButton(app, "today").waitForExistence(timeout: 20))

        for id in ["today", "read", "saved", "pray", "settings"] {
            let tab = tabButton(app, id)
            guard tab.exists else { report.append("MISSING TAB \(id)"); continue }
            tab.tap()
            Thread.sleep(forTimeInterval: 1.5)
            check("tab-\(id)", app: app, dir: dir, tag: tag)
        }
        // Subscreens under Pray and Settings.
        tabButton(app, "pray").tap()
        for text in ["Pray the Rosary", "St. Padre Pio Novena", "Pray with Scripture"] {
            let button = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
            if button.waitForExistence(timeout: 6) {
                button.tap()
                Thread.sleep(forTimeInterval: 1.5)
                check("pray-\(text.replacingOccurrences(of: " ", with: "_"))", app: app, dir: dir, tag: tag)
                let back = app.navigationBars.buttons.firstMatch
                if back.exists { back.tap() }
                Thread.sleep(forTimeInterval: 0.8)
            } else { report.append("MISSING \(text)") }
        }
        tabButton(app, "settings").tap()
        let calendar = app.buttons["settings-calendar-notifications"]
        if calendar.waitForExistence(timeout: 6) {
            calendar.tap()
            Thread.sleep(forTimeInterval: 1.5)
            check("settings-calendar-notifications", app: app, dir: dir, tag: tag)
            let back = app.navigationBars.buttons.firstMatch
            if back.exists { back.tap() }
        } else { report.append("MISSING settings-calendar-notifications") }

        tabButton(app, "read").tap()
        let book = app.buttons["reader-book-JHN"]
        if book.waitForExistence(timeout: 6) {
            book.tap()
            let chapter = app.buttons["reader-chapter-1"]
            if chapter.waitForExistence(timeout: 6) { chapter.tap() }
            Thread.sleep(forTimeInterval: 2)
            check("reader-john-1", app: app, dir: dir, tag: tag)
            let title = app.buttons["reader-title"]
            if title.exists {
                title.tap()
                Thread.sleep(forTimeInterval: 1.5)
                check("reader-go-to", app: app, dir: dir, tag: tag)
            }
        } else { report.append("MISSING reader-book-JHN") }

        let text = report.joined(separator: "\n")
        try? text.write(toFile: "\(dir)/\(tag)-report.txt", atomically: true, encoding: .utf8)
        let attachment = XCTAttachment(string: text)
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertFalse(report.contains { $0.hasPrefix("NOLABEL") }, "Buttons without VoiceOver label:\n\(text)")
    }

    private func tabButton(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let label = id.prefix(1).uppercased() + id.dropFirst()
        let bar = app.tabBars.firstMatch
        return [bar.buttons["tab-\(id)"], bar.buttons[label], app.buttons["tab-\(id)"]].map(\.firstMatch).first { $0.exists } ?? bar.buttons[label].firstMatch
    }

    private func check(_ name: String, app: XCUIApplication, dir: String, tag: String) {
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(tag)-\(name).png"))
        let window = app.windows.firstMatch.frame
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons where button.exists {
            let label = button.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let id = button.identifier
            if label.isEmpty && id.isEmpty == false || label.isEmpty {
                report.append("NOLABEL \(name) id=\(id) frame=\(button.frame)")
            }
            let f = button.frame
            if f.width > 0, f.height > 0, button.isHittable, !window.insetBy(dx: -1, dy: -1).contains(f) {
                report.append("OFFSCREEN \(name) label=\(label) frame=\(f)")
            }
        }
        report.append("OK \(name) buttons=\(buttons.count)")
    }
}
