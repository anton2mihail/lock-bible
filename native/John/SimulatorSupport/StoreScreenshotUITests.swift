import CryptoKit
import Foundation
import UIKit
import XCTest

/// L28 App Store screenshot capture. Main owns target membership, the build, the seed, the device, and every run.
///
/// The helper uses visible controls only. It has no launch argument, no launch environment, and no DEBUG hook.
/// It chooses the app by bundle ID, so it can capture the task-only Release copy (for example `com.nrsv.verse.l26`).
/// It takes the full device screen (status bar included), flattens it to an opaque PNG, attaches it with
/// `.keepAlways`, and attaches a JSON manifest for each image. Nothing is written outside the xcresult.
///
/// Every case is gated by `STORE_CASES`. Without it, every test skips. See StoreScreenshotUITests-README.md.
@MainActor
final class StoreScreenshotUITests: XCTestCase {
    private let timeout: TimeInterval = 20

    /// Case, output order number, and output slug. Number 01 stays free for the lock-screen slide (user step).
    private enum StoreCase: String, CaseIterable {
        case today, daily, pray, read, settings
        var number: Int {
            switch self {
            case .today: return 2
            case .daily: return 3
            case .pray: return 4
            case .read: return 5
            case .settings: return 6
            }
        }
        var slug: String {
            switch self {
            case .today: return "today"
            case .daily: return "daily-readings"
            case .pray: return "pray"
            case .read: return "read-john-1"
            case .settings: return "settings"
            }
        }
    }

    /// Accepted portrait pixel sizes (Apple "Screenshot specifications", read 6 October 2026).
    /// Confirm them in App Store Connect before submission.
    private static let iPhoneSizes: [String: [(Int, Int)]] = [
        "iphone-6.9in": [(1260, 2736), (1290, 2796), (1320, 2868)],
        "iphone-6.5in": [(1284, 2778), (1242, 2688)],
        "iphone-6.3in": [(1179, 2556), (1206, 2622)],
        "iphone-6.1in": [(1170, 2532), (1125, 2436), (1080, 2340)],
    ]
    private static let iPadSizes: [String: [(Int, Int)]] = [
        "ipad-13in": [(2064, 2752), (2048, 2732)],
        "ipad-11in": [(1488, 2266), (1668, 2420), (1668, 2388), (1640, 2360)],
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testStoreToday() throws { try run(.today) }
    func testStoreDailyReadings() throws { try run(.daily) }
    func testStorePray() throws { try run(.pray) }
    func testStoreReadJohnOne() throws { try run(.read) }
    func testStoreSettings() throws { try run(.settings) }

    // MARK: - Case flow

    private func run(_ storeCase: StoreCase) throws {
        let env = ProcessInfo.processInfo.environment
        let listed = (env["STORE_CASES"] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard listed.contains(storeCase.rawValue) || listed.contains("all") else {
            throw XCTSkip("Set STORE_CASES=\(storeCase.rawValue) (or all) to run this store screenshot case.")
        }
        let config = try configuration(env)
        XCUIDevice.shared.orientation = .portrait

        let app = XCUIApplication(bundleIdentifier: config.bundleID)
        if app.state != .notRunning { app.terminate() }
        app.launch() // No arguments and no environment: the app starts as a user would start it.
        defer { app.terminate() }

        switch storeCase {
        case .today:
            try waitForToday(app)
            XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Continue reading")).firstMatch.exists,
                           "Today must not show a leftover Continue reading card. Use a fresh seed and run read last.")
        case .daily:
            try waitForToday(app)
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Today’s readings")).firstMatch.tap()
            expectGone(app.staticTexts["today-title"], "The daily readings screen must replace Today")
        case .pray:
            tapTab("pray", in: app)
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Pray the Rosary")).firstMatch.waitForExistence(timeout: timeout), "Prayer home must show the Rosary entry")
        case .read:
            try openJohnOne(app)
        case .settings:
            tapTab("settings", in: app)
            XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: timeout), "Settings title must appear")
        }
        Thread.sleep(forTimeInterval: 2) // Let animation and image loading finish before the capture.
        try capture(storeCase, config: config)
    }

    private func waitForToday(_ app: XCUIApplication) throws {
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: timeout), "Today title must appear")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Today’s readings")).firstMatch.waitForExistence(timeout: timeout), "Readings card must appear")
        XCTAssertTrue(app.staticTexts["today-verse-card"].waitForExistence(timeout: timeout), "Verse card must appear")
    }

    private func tapTab(_ name: String, in app: XCUIApplication) {
        let tab = app.buttons["tab-\(name)"]
        XCTAssertTrue(tab.waitForExistence(timeout: timeout), "Tab \(name) must exist")
        expandTabBar(in: app, expecting: "tab-\(name)")
        tab.tap()
    }

    private func openJohnOne(_ app: XCUIApplication) throws {
        tapTab("read", in: app)
        let bookListTitle = app.staticTexts["reader-book-list-title"]
        for _ in 0..<3 {
            if bookListTitle.waitForExistence(timeout: 2) { break }
            let back = app.buttons["reader-back"]
            XCTAssertTrue(back.waitForExistence(timeout: 4), "Reader must expose a Back control to the book list")
            back.tap()
        }
        XCTAssertTrue(bookListTitle.waitForExistence(timeout: timeout), "Book list must be reached through visible Back controls")
        let book = app.buttons["reader-book-JHN"]
        XCTAssertTrue(book.waitForExistence(timeout: timeout), "John must be in the book list")
        book.tap()
        let chapter = app.buttons["reader-chapter-1"]
        XCTAssertTrue(chapter.waitForExistence(timeout: timeout), "Chapter 1 must be listed")
        chapter.tap()
        let title = app.buttons["reader-title"]
        XCTAssertTrue(title.waitForExistence(timeout: timeout), "Reader title must appear")
        let exact = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "John 1"), object: title)
        XCTAssertEqual(XCTWaiter.wait(for: [exact], timeout: timeout), .completed, "Reader must show John 1")
        let verse = app.buttons["reader-verse-1"]
        XCTAssertTrue(verse.waitForExistence(timeout: timeout), "John 1:1 must load")
        XCTAssertTrue(verse.label.contains("In the beginning was the Word"), verse.label)
    }

    private func expectGone(_ element: XCUIElement, _ message: String) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: timeout), .completed, message)
    }

    // MARK: - Capture and manifest

    private struct Configuration {
        let bundleID: String
        let seedID: String
        let expectedDate: String
        let timeZone: String
        let statusBarProfile: String
        let appearance: String
        let binarySHA256: String
    }

    private func configuration(_ env: [String: String]) throws -> Configuration {
        func required(_ key: String) throws -> String {
            guard let value = env[key], !value.isEmpty else { throw ConfigurationError.missing(key) }
            return value
        }
        let bundleID = try required("STORE_BUNDLE_ID")
        guard !bundleID.hasSuffix(".dev"), !bundleID.hasSuffix(".uitests") else {
            throw ConfigurationError.invalid("STORE_BUNDLE_ID must name a Release app. A Debug bundle shows scenario controls.")
        }
        guard try required("STORE_BUILD_CONFIGURATION") == "Release" else {
            throw ConfigurationError.invalid("STORE_BUILD_CONFIGURATION must be Release")
        }
        let appearance = try required("STORE_APPEARANCE")
        guard appearance == "light" || appearance == "dark" else {
            throw ConfigurationError.invalid("STORE_APPEARANCE must be light or dark")
        }
        let config = Configuration(
            bundleID: bundleID, seedID: try required("STORE_SEED_ID"), expectedDate: try required("STORE_EXPECTED_DATE"),
            timeZone: try required("STORE_TIME_ZONE"), statusBarProfile: try required("STORE_STATUS_BAR_PROFILE"),
            appearance: appearance, binarySHA256: try required("STORE_APP_BINARY_SHA256"))
        guard TimeZone.current.identifier == config.timeZone else {
            throw ConfigurationError.invalid("Device time zone \(TimeZone.current.identifier) differs from STORE_TIME_ZONE \(config.timeZone)")
        }
        let today = localDate(Date())
        guard today == config.expectedDate else {
            throw ConfigurationError.invalid("Device date \(today) differs from STORE_EXPECTED_DATE \(config.expectedDate)")
        }
        return config
    }

    private func localDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func sizeClass(width: Int, height: Int) -> (deviceClass: String, sizeClass: String)? {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let table = isPad ? Self.iPadSizes : Self.iPhoneSizes
        for (name, sizes) in table where sizes.contains(where: { $0.0 == width && $0.1 == height }) {
            return (isPad ? "ipad" : "iphone", name)
        }
        return nil
    }

    private func capture(_ storeCase: StoreCase, config: Configuration) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let image = screenshot.image
        guard let raw = image.cgImage else { XCTFail("Screenshot has no bitmap"); return }
        let width = raw.width, height = raw.height
        let rawHasAlpha = ![CGImageAlphaInfo.none, .noneSkipFirst, .noneSkipLast].contains(raw.alphaInfo)

        // Flatten to an opaque image. App Store Connect rejects an alpha channel.
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let flat = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in image.draw(at: .zero) }
        guard let png = flat.pngData(), let flatCG = UIImage(data: png)?.cgImage else { XCTFail("PNG encoding failed"); return }
        XCTAssertEqual(flatCG.width, width, "Flattening must keep the pixel width")
        XCTAssertEqual(flatCG.height, height, "Flattening must keep the pixel height")
        let flatHasAlpha = ![CGImageAlphaInfo.none, .noneSkipFirst, .noneSkipLast].contains(flatCG.alphaInfo)
        XCTAssertFalse(flatHasAlpha, "The attached PNG must have no alpha channel")

        let classification = sizeClass(width: width, height: height)
        XCTAssertNotNil(classification, "Pixel size \(width)x\(height) is not an accepted portrait App Store size for this device idiom")
        let deviceClass = classification?.deviceClass ?? "unknown"
        let name = String(format: "store-%@-%dx%d-%02d-%@.png", deviceClass, width, height, storeCase.number, storeCase.slug)
        let digest = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()

        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let now = Date()
        let manifest: [String: Any] = [
            "schema": "store-screenshot-v1", "case": storeCase.rawValue, "attachment": name,
            "sha256": digest, "byteCount": png.count,
            "pixelWidth": width, "pixelHeight": height, "scale": image.scale,
            "pointWidth": image.size.width, "pointHeight": image.size.height,
            "deviceClass": deviceClass, "sizeClass": classification?.sizeClass ?? "unaccepted",
            "rawScreenshotHadAlpha": rawHasAlpha, "attachedPNGHasAlpha": flatHasAlpha,
            "device": UIDevice.current.name, "systemVersion": UIDevice.current.systemVersion,
            "orientation": String(describing: XCUIDevice.shared.orientation),
            "bundleID": config.bundleID, "buildConfiguration": "Release",
            "appBinarySHA256": config.binarySHA256, "appBinaryOrigin": "caller-supplied; the test does not read the binary",
            "seedID": config.seedID, "seedOrigin": "caller-supplied; the test does not create or prove the seed",
            "captureUTC": ISO8601DateFormatter().string(from: now), "localDate": localDate(now),
            "expectedDate": config.expectedDate, "timeZone": TimeZone.current.identifier,
            "statusBarProfile": config.statusBarProfile,
            "statusBarOrigin": "caller-supplied simctl status_bar override; the test does not set or prove it",
            "appearance": config.appearance, "appearanceOrigin": "caller-supplied simctl ui appearance",
            "runnerReadback": [
                "userInterfaceStyleRaw": UITraitCollection.current.userInterfaceStyle.rawValue,
                "preferredContentSizeCategory": UITraitCollection.current.preferredContentSizeCategory.rawValue,
                "origin": "UI test runner process values; not proof of the app state",
            ] as [String: Any],
            "navigation": "visible accessibility identifiers only; no launch argument; no launch environment",
        ]
        let json = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys, .prettyPrinted])
        let jsonAttachment = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
        jsonAttachment.name = name.replacingOccurrences(of: ".png", with: ".json")
        jsonAttachment.lifetime = .keepAlways
        add(jsonAttachment)
        NSLog("STORE_CAPTURE name=%@ size=%dx%d sha256=%@ alpha=%@ class=%@", name, width, height, digest,
              flatHasAlpha ? "true" : "false", classification?.sizeClass ?? "unaccepted")
    }

    private struct ConfigurationError: Error, CustomStringConvertible {
        let description: String
        static func missing(_ key: String) -> Self { Self(description: "Missing required store screenshot configuration: \(key)") }
        static func invalid(_ text: String) -> Self { Self(description: text) }
    }

    /// The Liquid Glass tab bar minimizes while the Read tab scrolls. Release has no `-JohnTabBarMinimize never`
    /// (that argument exists only in Debug). Before a tab tap after a Reader scroll, expand the bar (tap the minimized
    /// bar, then scroll up) and check that the target tab button is hittable (Liquid-glass-tabview-review.md fix 5).
    private func expandTabBar(in app: XCUIApplication, expecting tabID: String) {
        let tab = app.buttons[tabID]
        for attempt in 0..<4 {
            if tab.exists && tab.isHittable { return }
            if attempt % 2 == 0 {
                let bar = app.tabBars.firstMatch
                if bar.exists && bar.isHittable { bar.tap() }
            } else {
                let scroll = app.scrollViews.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
                    .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
                scroll?.swipeDown()
            }
            _ = tab.waitForExistence(timeout: 2)
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertTrue(tab.exists && tab.isHittable, "\(tabID) must be hittable after the tab bar expands")
    }
}
