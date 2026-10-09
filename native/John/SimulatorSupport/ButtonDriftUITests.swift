import XCTest

/// A0 investigation: samples button frames after a screen appears. Reports buttons whose frame moves.
@MainActor
final class ButtonDriftUITests: XCTestCase {
    private struct Sample { let t: TimeInterval; let frames: [String: CGRect] }
    private var report: [String] = []

    override func setUpWithError() throws { continueAfterFailure = true }

    func testButtonDriftOnKeyScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-L14FeatureDate", "2026-09-13T16:00:00Z",
            "-L14FeatureTimeZone", "America/Toronto",
            "-JohnTabBarMinimize", "never",
        ]
        let launchStart = Date()
        app.launch()
        // Cold launch: Today.
        record("Today (cold launch)", sampleAfter: nil, app: app, start: launchStart)

        for (name, tab) in [("Read", "read"), ("Saved", "saved"), ("Pray", "pray"), ("Settings", "settings")] {
            record("\(name) tab", sampleAfter: { self.tab(app, tab).tap() }, app: app)
        }
        record("Today tab (return)", sampleAfter: { self.tab(app, "today").tap() }, app: app)
        tab(app, "pray").tap()
        _ = app.staticTexts["Pray the Rosary"].waitForExistence(timeout: 8)
        for (name, text) in [("Rosary", "Pray the Rosary"), ("Novena", "St. Padre Pio Novena"), ("Lectio", "Pray with Scripture")] {
            if !app.tabBars.firstMatch.buttons["Pray"].isSelected { tab(app, "pray").tap() }
            let target = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
            guard target.waitForExistence(timeout: 8) else { report.append("## \(name)\nSKIPPED: button not found\n"); continue }
            record(name, sampleAfter: { target.tap() }, app: app)
            if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
            Thread.sleep(forTimeInterval: 1)
        }
        let attachment = XCTAttachment(string: report.joined(separator: "\n"))
        attachment.lifetime = .keepAlways
        add(attachment)
        print("A0DRIFT_BEGIN\n" + report.joined(separator: "\n") + "\nA0DRIFT_END")
    }

    private func tab(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let label = id.prefix(1).uppercased() + id.dropFirst()
        let bar = app.tabBars.firstMatch
        return [bar.buttons["tab-\(id)"], bar.buttons[label], app.buttons["tab-\(id)"]].first { $0.exists } ?? bar.buttons[label]
    }

    /// Taps on a background queue so the test does not wait for app idle. Then takes rapid screenshots.
    /// Reports when the picture last changed. A late change means motion after first appear.
    private func record(_ name: String, sampleAfter action: (() -> Void)?, app: XCUIApplication, start: Date = Date()) {
        let t0 = Date()
        if let action {
            nonisolated(unsafe) let run = action
            DispatchQueue.global().async { DispatchQueue.main.async { run() } }
        }
        var shots: [(TimeInterval, [UInt8])] = []
        repeat {
            let image = XCUIScreen.main.screenshot().image
            shots.append((Date().timeIntervalSince(t0), Self.tiny(image)))
            Thread.sleep(forTimeInterval: 0.05)
        } while Date().timeIntervalSince(t0) < 2.5
        var changes: [String] = []
        var lastChange: TimeInterval = 0
        for i in 1..<shots.count {
            let d = zip(shots[i].1, shots[i-1].1).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
            let pct = Double(d) / Double(shots[i].1.count * 255) * 100
            if pct > 0.05 { lastChange = shots[i].0; changes.append(String(format: "%.2f s:%.1f%%", shots[i].0, pct)) }
        }
        report.append("## \(name)")
        report.append("shots: \(shots.count), spacing ≈ \(String(format: "%.2f", shots.last!.0 / Double(shots.count))) s")
        report.append("last visual change at \(String(format: "%.2f", lastChange)) s; changed frames: \(changes.count)")
        report.append("changes (time:%diff): " + changes.joined(separator: ", ") + "\n")
        // After motion stops, also log final button frames for the record.
        Thread.sleep(forTimeInterval: 0.5)
        report.append("final buttons: \(buttonFrames(app).count)\n")
    }

    private static func tiny(_ image: UIImage) -> [UInt8] {
        let w = 48, h = 104
        var px = [UInt8](repeating: 0, count: w * h)
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        if let cg = image.cgImage { ctx?.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h)) }
        return px
    }

    private func fmt(_ r: CGRect) -> String { "(\(Int(r.minX)),\(Int(r.minY)) \(Int(r.width))x\(Int(r.height)))" }

    private func buttonFrames(_ app: XCUIApplication) -> [String: CGRect] {
        guard let snap = try? app.snapshot() else { return [:] }
        var out: [String: CGRect] = [:]
        func walk(_ e: XCUIElementSnapshot) {
            if e.elementType == .button {
                let key = !e.identifier.isEmpty ? e.identifier : (!e.label.isEmpty ? e.label : "unnamed")
                var k = key, i = 2
                while out[k] != nil { k = "\(key)#\(i)"; i += 1 }
                out[k] = e.frame
            }
            e.children.forEach { walk($0) }
        }
        walk(snap)
        return out
    }
}
