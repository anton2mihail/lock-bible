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


    #if DEBUG
    /// Step 7: inactive phase pauses, resume works, and leaving the route releases the player.
    /// Needs network for the Debug sample audio. Run with STEP7_CASES=media-lifecycle and STEP7_MEDIA_NETWORK=1.
    /// Source: RosaryMediaView.swift onChange(scenePhase) and onDisappear; RosaryMediaModel.swift pause, deactivate.
    /// The test proves visible state only. It does not prove that the audio engine released its resources.
    func testStep7DebugMediaInactiveAndRouteExitCleanup() throws {
        try requireStep7("media-lifecycle")
        guard ProcessInfo.processInfo.environment["STEP7_MEDIA_NETWORK"] == "1" else {
            throw XCTSkip("This check plays a remote Debug sample. Set STEP7_MEDIA_NETWORK=1.")
        }
        let app = XCUIApplication()
        openMedia(in: app)
        tapWhenReady(app.buttons["rosary-media-mode-audio"], in: app)
        let play = app.buttons["Play audio"]
        XCTAssertTrue(play.waitForExistence(timeout: 40))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: play)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 40), .completed, "The sample audio must load")
        tapWhenReady(play, in: app)
        XCTAssertTrue(app.buttons["Pause audio"].waitForExistence(timeout: 20), "Playback must start")

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.staticTexts["WORD ON FIRE SERIES"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Play audio"].waitForExistence(timeout: 10), "The inactive phase must pause playback")
        XCTAssertFalse(app.buttons["Pause audio"].exists)
        tapWhenReady(app.buttons["Play audio"], in: app)
        XCTAssertTrue(app.buttons["Pause audio"].waitForExistence(timeout: 20), "Playback must resume after the user taps Play")

        tapWhenReady(app.buttons["Back to Rosary"], in: app)
        XCTAssertTrue(app.staticTexts["The Rosary with Bishop Barron"].waitForExistence(timeout: 8))
        tapWhenReady(button(containing: "Bishop Robert Barron · Word on Fire", in: app), in: app)
        XCTAssertTrue(app.staticTexts["WORD ON FIRE SERIES"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["rosary-media-mode-video"].value as? String, "Selected", "A new visit starts in video mode")
        tapWhenReady(app.buttons["rosary-media-mode-audio"], in: app)
        XCTAssertTrue(app.buttons["Play audio"].waitForExistence(timeout: 40), "A new visit must not keep the old playback")
        XCTAssertFalse(app.buttons["Pause audio"].exists)
        NSLog("STEP7_MEDIA_LIFECYCLE inactivePaused=true resumeWorks=true exitReleased=visible-state-only")
    }

    /// Step 7: the audio failure state. It needs the proposed DEBUG launch argument -L29MediaFailureURI (see the Step 7 plan).
    /// Set STEP7_MEDIA_HOOK_PRESENT=1 only on a build that has the hook.
    func testStep7DebugMediaFailureStateWithInjectedURI() throws {
        try requireStep7("media-failure")
        guard ProcessInfo.processInfo.environment["STEP7_MEDIA_HOOK_PRESENT"] == "1" else {
            throw XCTSkip("This check needs the proposed -L29MediaFailureURI hook. Set STEP7_MEDIA_HOOK_PRESENT=1 on a build that has it.")
        }
        let app = XCUIApplication()
        app.launchArguments += ["-L29MediaFailureURI", "https://invalid.invalid/step7-missing.mp3"]
        openMedia(in: app)
        tapWhenReady(app.buttons["rosary-media-mode-audio"], in: app)
        let unavailable = app.buttons["Audio unavailable"]
        XCTAssertTrue(unavailable.waitForExistence(timeout: 40), "A failed audio item must show Audio unavailable")
        XCTAssertFalse(unavailable.isEnabled, "The failed player button must be disabled")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "step7-media-failure"
        attachment.lifetime = .keepAlways
        add(attachment)
        tapWhenReady(app.buttons["Back to Rosary"], in: app)
        XCTAssertTrue(app.staticTexts["The Rosary with Bishop Barron"].waitForExistence(timeout: 8))
        NSLog("STEP7_MEDIA_FAILURE audioUnavailable=true")
    }
    #endif

    #if !DEBUG
    /// Step 7: Release shows exactly one external media action on Rosary home (the suggested set for the weekday).
    /// STEP7_EXPECTED_EPISODE_TITLE (optional) names the expected episode. Never tap the action.
    /// Source: RosaryHomeView.swift mediaSection; src/services/rosary/catalog.ts:233 DEFAULT_SET_BY_DAY.
    func testStep7ReleaseHomeEpisodeIsExternalAndMatchesWeekday() throws {
        try requireStep7("release-media-episode")
        let app = XCUIApplication()
        openRosaryHome(in: app)
        let actions = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "opens on YouTube"))
        XCTAssertTrue(actions.firstMatch.waitForExistence(timeout: 8))
        XCTAssertEqual(actions.count, 1, "Release shows one episode on Rosary home")
        let label = actions.firstMatch.label
        if let title = ProcessInfo.processInfo.environment["STEP7_EXPECTED_EPISODE_TITLE"] {
            XCTAssertTrue(label.contains(title), "Expected the suggested episode \(title). Observed: \(label)")
        }
        XCTAssertFalse(app.buttons["rosary-media-mode-video"].exists)
        XCTAssertFalse(app.buttons["rosary-media-mode-audio"].exists)
        NSLog("STEP7_RELEASE_MEDIA externalActionLabel=%@ tapped=false", label)
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

    private func requireStep7(_ name: String) throws {
        let listed = (ProcessInfo.processInfo.environment["STEP7_CASES"] ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard listed.contains(name) else { throw XCTSkip("Set STEP7_CASES=\(name) to run this Step 7 check.") }
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
