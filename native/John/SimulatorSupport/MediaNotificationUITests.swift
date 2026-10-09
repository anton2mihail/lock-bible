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
        tapSystemBack(in: app, expecting: app.staticTexts.matching(NSPredicate(format: "label == %@", "The Rosary with Bishop Barron")).firstMatch)
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
        let entryID = externalMediaAction.identifier
        let entryPrefix = "rosary-media-entry-"
        XCTAssertTrue(entryID.hasPrefix(entryPrefix), "The external action must identify its Rosary set")
        let setID = String(entryID.dropFirst(entryPrefix.count))
        let destinations: [String: (videoID: String, title: String)] = [
            "joyful": ("ckUJRg04jyg", "The Joyful Mysteries"),
            "sorrowful": ("ry7FbjkN-p0", "The Sorrowful Mysteries"),
            "glorious": ("WoJ1hQTVdSo", "The Glorious Mysteries"),
            "luminous": ("b2EjBt2PFpc", "The Luminous Mysteries")
        ]
        guard let expected = destinations[setID] else {
            XCTFail("The visible Release action has no reviewed destination for set \(setID)")
            return
        }
        XCTAssertFalse(app.buttons["rosary-media-mode-video"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "More from the series")).firstMatch.exists)
        tapWhenReady(externalMediaAction, in: app)
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 20),
                      "The Release action must open its public official media destination")
        let expectedVideo = safari.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@", expected.videoID, expected.videoID)).firstMatch
        let expectedTitle = safari.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@", expected.title, expected.title)).firstMatch
        let videoIDVisible = expectedVideo.waitForExistence(timeout: 20)
        let exactTitleVisible = videoIDVisible ? false : expectedTitle.waitForExistence(timeout: 5)
        XCTAssertTrue(videoIDVisible || exactTitleVisible,
                      "Safari must show the selected catalog video ID \(expected.videoID) or exact episode title \(expected.title)")
        NSLog("MEDIA_RELEASE sourceCatalog=ROSARY_MEDIA_EPISODES setID=%@ expectedVideoID=%@ expectedTitle=%@ observedVideoID=%@ observedTitle=%@ playerPlayback=not-claimed",
              setID, expected.videoID, expected.title,
              videoIDVisible ? expected.videoID : "not-exposed",
              exactTitleVisible ? expectedTitle.label : "not-exposed")
    }
    #endif


    /// The iOS 26 system glass back button of a pushed screen. It replaced the in-page "Back to Rosary" link and `content-back`.
    private func systemBack(in app: XCUIApplication) -> XCUIElement {
        // `navigationBars.buttons.firstMatch` can return a trailing button or the button of another bar. Prefer the
        // `BackButton` identifier (the front-most one when two bars are on screen during a push). Otherwise use the
        // left-most hittable button of the front-most navigation bar.
        let named = app.navigationBars.buttons.matching(identifier: "BackButton")
        if named.count > 0 { return named.element(boundBy: named.count - 1) }
        let bars = app.navigationBars.allElementsBoundByIndex.filter { $0.exists }
        if let bar = bars.last(where: { $0.isHittable }) ?? bars.last {
            let buttons = bar.buttons.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
            if let leftmost = buttons.min(by: { $0.frame.minX < $1.frame.minX }) { return leftmost }
        }
        return app.navigationBars.buttons.firstMatch
    }

    /// Taps Back and waits for the expected parent screen.
    private func tapSystemBack(in app: XCUIApplication, expecting parent: XCUIElement,
                               file: StaticString = #filePath, line: UInt = #line) {
        let back = systemBack(in: app)
        XCTAssertTrue(back.waitForExistence(timeout: 10), "Back control did not appear", file: file, line: line)
        back.tap()
        XCTAssertTrue(parent.waitForExistence(timeout: 10), "The parent screen must appear after Back", file: file, line: line)
    }

    /// Leaves the media page and checks that the Rosary home appears (Step 7 media-lifecycle).
    /// The page is a pushed screen. Its one exit is the system glass back button at the top left; the in-page
    /// "Back to Rosary" link was removed (audit item B1, `RosaryMediaView.swift`). After playback the page can sit
    /// scrolled, but the system bar stays on screen.
    /// Order: tap the navigation back control (the first button of the navigation bar, identifier `BackButton` on some
    /// builds); then the swipe-back gesture from 8 pt inside the left edge (more than 4 pt, so it is not the system
    /// edge gesture of the Simulator tool). Each step is logged.
    private func leaveMediaPageToRosaryHome(in app: XCUIApplication) {
        let rosaryHome = app.staticTexts["The Rosary with Bishop Barron"]
        let navBack = systemBack(in: app)
        if navBack.exists && navBack.isHittable {
            navBack.tap()
            if rosaryHome.waitForExistence(timeout: 5) { NSLog("STEP7_MEDIA_EXIT method=navigation-back"); return }
        }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 8 / app.frame.width, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        NSLog("STEP7_MEDIA_EXIT method=swipe-back")
        XCTAssertTrue(rosaryHome.waitForExistence(timeout: 8), "The Rosary home must appear after leaving the media page")
    }

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

        leaveMediaPageToRosaryHome(in: app)
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
        tapSystemBack(in: app, expecting: app.staticTexts.matching(NSPredicate(format: "label == %@", "The Rosary with Bishop Barron")).firstMatch)
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
        tabButton(app, "tab-settings").tap()
        tapWhenReady(app.buttons["settings-calendar-notifications"], in: app)
        XCTAssertTrue(app.staticTexts["A day in the Church"].waitForExistence(timeout: 10))

        let calendarEnabled = app.switches["calendar-notifications-enabled"]
        XCTAssertTrue(calendarEnabled.waitForExistence(timeout: 8))
        if calendarEnabled.value as? String == "1" { tapWhenReady(calendarEnabled, in: app) }
        tapWhenReady(app.buttons["calendar-notifications-save"], in: app)
        XCTAssertTrue(app.staticTexts["Calendar notifications are off."].waitForExistence(timeout: 8))

        tapSystemBack(in: app, expecting: app.staticTexts["settings-title"])
        tabButton(app, "tab-pray").tap()
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
        XCTAssertTrue(tabButton(app, "tab-pray").waitForExistence(timeout: 12))
        tabButton(app, "tab-pray").tap()
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
