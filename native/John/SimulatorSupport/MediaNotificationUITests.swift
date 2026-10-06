import XCTest

@MainActor
final class MediaNotificationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    #if DEBUG
    func testDebugMediaModeEpisodeAndRouteReturnAfterActivation() throws {
        let app = XCUIApplication()
        openMedia(in: app)
        XCTAssertTrue(app.staticTexts["WORD ON FIRE SERIES"].waitForExistence(timeout: 10))

        let video = app.buttons["rosary-media-mode-video"]
        let audio = app.buttons["rosary-media-mode-audio"]
        XCTAssertTrue(video.waitForExistence(timeout: 8))
        XCTAssertEqual(video.value as? String, "Selected")
        tapWhenReady(audio, in: app)
        XCTAssertEqual(audio.value as? String, "Selected")
        XCTAssertEqual(video.value as? String, "Not selected")

        let sourceEpisodeIDs = ["why-pray", "how-to-pray", "joyful", "sorrowful", "glorious", "luminous"]
        for id in sourceEpisodeIDs {
            XCTAssertTrue(app.buttons["rosary-media-episode-\(id)"].waitForExistence(timeout: 8), "Missing media entry \(id)")
        }
        let otherEpisode = app.buttons["rosary-media-episode-why-pray"]
        tapWhenReady(otherEpisode, in: app)
        XCTAssertTrue(app.staticTexts["Why Pray the Rosary?"].waitForExistence(timeout: 8))
        let selectedEpisode = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: otherEpisode)
        XCTAssertEqual(XCTWaiter.wait(for: [selectedEpisode], timeout: 5), .completed)

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.staticTexts["WORD ON FIRE SERIES"].waitForExistence(timeout: 8))
        tapWhenReady(app.buttons["Back to Rosary"], in: app)
        XCTAssertTrue(app.staticTexts["The Rosary with Bishop Barron"].waitForExistence(timeout: 8))
        NSLog("MEDIA_DEBUG mode=audio episodeID=why-pray episodeTitle=Why Pray the Rosary? afterActivation=true routeReturn=true")
    }
    #endif

    #if !DEBUG
    func testReleaseUnapprovedMediaUsesExternalFallback() throws {
        let app = XCUIApplication()
        openRosaryHome(in: app)
        let externalMediaAction = button(containing: "opens on YouTube", in: app)
        XCTAssertTrue(externalMediaAction.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["rosary-media-mode-video"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "More from the series")).firstMatch.exists)
        NSLog("MEDIA_RELEASE sourceCatalog=ROSARY_MEDIA_EPISODES noApprovedMediaURIs=true playerModes=absent externalAction=available seriesLink=true")
    }
    #endif

    func testNotificationScreensShowDisabledSaveFeedback() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["tab-settings"].tap()
        tapWhenReady(app.buttons["settings-calendar-notifications"], in: app)
        XCTAssertTrue(app.staticTexts["A day in the Church"].waitForExistence(timeout: 10))

        let calendarEnabled = app.switches["calendar-notifications-enabled"]
        XCTAssertTrue(calendarEnabled.waitForExistence(timeout: 8))
        if calendarEnabled.value as? String == "1" { tapWhenReady(calendarEnabled, in: app) }
        tapWhenReady(app.buttons["calendar-notifications-save"], in: app)
        XCTAssertTrue(app.staticTexts["Calendar notifications are off."].waitForExistence(timeout: 8))

        tapWhenReady(app.buttons["content-back"], in: app)
        app.buttons["tab-pray"].tap()
        tapWhenReady(button(containing: "Pray the Rosary", in: app), in: app)
        tapWhenReady(button(containing: "Rosary reminder", in: app), in: app)
        XCTAssertTrue(app.staticTexts["Rosary reminder"].waitForExistence(timeout: 8))

        let reminderEnabled = app.switches["rosary-reminder-enabled"]
        XCTAssertTrue(reminderEnabled.waitForExistence(timeout: 8))
        if reminderEnabled.value as? String == "1" { tapWhenReady(reminderEnabled, in: app) }
        let save = app.buttons["rosary-reminder-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 8))
        XCTAssertEqual(save.label, "Turn reminder off")
        tapWhenReady(save, in: app)
        XCTAssertTrue(app.staticTexts["Reminder turned off"].waitForExistence(timeout: 8))
        NSLog("NOTIFICATION_UI calendarDisabledFeedback=true rosaryDisabledFeedback=true")
    }

    private func openMedia(in app: XCUIApplication) {
        openRosaryHome(in: app)
        let mediaEntry = button(containing: "Bishop Robert Barron · Word on Fire", in: app)
        tapWhenReady(mediaEntry, in: app)
    }

    private func openRosaryHome(in app: XCUIApplication) {
        app.launch()
        XCTAssertTrue(app.buttons["tab-pray"].waitForExistence(timeout: 12))
        app.buttons["tab-pray"].tap()
        tapWhenReady(button(containing: "Pray the Rosary", in: app), in: app)
        XCTAssertTrue(button(containing: "Rosary reminder", in: app).waitForExistence(timeout: 8))
    }

    private func button(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func tapWhenReady(_ element: XCUIElement, in app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Control did not appear", file: file, line: line)
        for _ in 0..<8 where !element.isHittable {
            let viewport = app.scrollViews.allElementsBoundByIndex
                .filter { $0.exists && $0.isHittable }
                .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
            let viewportFrame = viewport?.frame ?? app.frame
            if element.frame.maxY < viewportFrame.minY { app.swipeDown() }
            else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable, "Control is not hittable", file: file, line: line)
        element.tap()
    }
}
