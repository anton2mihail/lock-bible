import XCTest

@MainActor
final class WorksSettingsUITests: XCTestCase {
    private let worksID = "chrysostom.homilies-on-the-gospel-of-john"
    private let worksTitle = "Homilies on the Gospel of John"
    private let collectionID = "chrysostom"
    private let sectionTitle = "Homily 10"
    private let sectionAnchor = "Homily 10 on the Gospel of John"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSettingsSaveEditionsRestoreAndReaderAppearanceAgree() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        tabButton(app, "tab-settings").tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 10))

        let groups: [(name: String, options: [String], changed: (String) -> String)] = [
            ("text-size", ["small", "default", "large", "extra-large"], { $0 == "large" ? "small" : "large" }),
            ("line-spacing", ["compact", "comfortable", "relaxed"], { $0 == "relaxed" ? "compact" : "relaxed" }),
            ("scripture-typeface", ["serif", "sans"], { $0 == "sans" ? "serif" : "sans" }),
            ("layout", ["paragraphs", "verse-by-verse"], { $0 == "verse-by-verse" ? "paragraphs" : "verse-by-verse" }),
            ("appearance", ["system", "light", "dark"], { $0 == "dark" ? "light" : "dark" }),
        ]
        var originalChoices: [String: String] = [:]
        var changedChoices: [String: String] = [:]
        for group in groups {
            let ids = group.options.map { "settings-\(group.name)-\($0)" }
            let original = try selectedIdentifier(ids, in: app)
            originalChoices[group.name] = original
            let suffix = String(original.dropFirst("settings-\(group.name)-".count))
            let changed = group.changed(suffix)
            let target = "settings-\(group.name)-\(changed)"
            changedChoices[group.name] = target
            tapAndWaitForSelection(target, in: app)
        }

        let scopeOptions = ["settings-scope-full", "settings-scope-ot", "settings-scope-nt"]
        let originalScopeID = try selectedIdentifier(scopeOptions, in: app)
        let changedScopeID = originalScopeID == "settings-scope-ot" ? "settings-scope-nt" : "settings-scope-ot"
        let originalScope = settingsRowLabel(originalScopeID)
        tapAndWaitForSelection(changedScopeID, in: app)

        let cadenceOptions = ["settings-interval-10", "settings-interval-15", "settings-interval-30", "settings-interval-60",
                              "settings-interval-180", "settings-interval-360", "settings-interval-720", "settings-interval-1440"]
        let originalCadenceID = try selectedIdentifier(cadenceOptions, in: app)
        let changedCadenceID = originalCadenceID == "settings-interval-10" ? "settings-interval-15" : "settings-interval-10"
        let originalCadence = settingsRowLabel(originalCadenceID)
        tapAndWaitForSelection(changedCadenceID, in: app)

        let editionRows: [(id: String, fullName: String, attribution: String, copyright: String)] = [
            ("web-ce", "World English Bible — Catholic Edition",
             "Scripture quotations are from the World English Bible (Catholic Edition), which is in the public domain.",
             "Public Domain. “World English Bible” is a trademark of eBible.org."),
            ("douay-rheims", "Douay–Rheims 1899 American Edition",
             "Scripture quotations are from the public-domain Douay–Rheims American Edition of 1899.",
             "Public Domain. Source files courtesy of eBible.org."),
            ("vulgate", "Clementine Vulgate 1598 — Latin",
             "Scripture text is from the public-domain Clementine Vulgate of 1598 in Latin.",
             "Public Domain. Source files courtesy of eBible.org."),
        ]
        let initialTranslation = try selectedIdentifier(editionRows.map { "translation-\($0.id)" }, in: app)
        for edition in editionRows {
            let row = "translation-\(edition.id)"
            tapAndWaitForSelection(row, in: app)
            XCTAssertTrue(app.staticTexts[edition.fullName].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts[edition.attribution].exists, "Missing attribution for \(edition.id)")
            XCTAssertTrue(app.staticTexts[edition.copyright].exists, "Missing copyright for \(edition.id)")
        }
        tapAndWaitForSelection(initialTranslation, in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Offline reading references:")).firstMatch.exists)
        let metadata = "Reading metadata: catholic-readings-api (MIT). Celebration calendar: romcal (MIT). Reflections stay on this device. Confession notes are never saved."
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", metadata)).firstMatch.exists)

        for group in groups.reversed() {
            if let original = originalChoices[group.name] {
                tapAndWaitForSelection(original, in: app)
            }
        }
        tapAndWaitForSelection(originalScopeID, in: app)
        tapAndWaitForSelection(originalCadenceID, in: app)

        NSLog("SETTINGS_EXPECTED changed=%@ restored=%@ translation=%@ scope=%@ interval=%@",
              changedChoices.description, originalChoices.description, initialTranslation, originalScope, originalCadence)

        openReaderBookList(in: app)
        let john = app.buttons["reader-book-JHN"]
        XCTAssertTrue(john.waitForExistence(timeout: 10))
        tapWhenReady(john, in: app)
        let chapter = app.buttons["reader-chapter-1"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 10))
        tapWhenReady(chapter, in: app)
        let appearance = app.buttons["reader-appearance-button"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 10))
        tapWhenReady(appearance, in: app)
        // The Aa sheet shows the same choice buttons as Settings (audit B2). The restored Settings choice must read
        // "Selected" there too. The Aa sheet has no edition control (the old Aa sheet had none).
        for group in groups {
            let identifier = originalChoices[group.name]!
            let choice = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            XCTAssertTrue(choice.waitForExistence(timeout: 5), "Missing Reader Aa control: \(identifier)")
            XCTAssertEqual(choice.value as? String, "Selected", "Reader Aa does not match \(identifier)")
        }
        tapWhenReady(app.buttons["reader-appearance-close"], in: app)
    }

    func testWorksContentsFooterStyleAnchorAndResume() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnResetNativeState"] // test isolation: no saved Works position
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        NSLog("WORKS_EXPECTED workID=%@ collectionID=%@ title=%@ sectionIndex=9 sectionTitle=%@ pageIndex=0 anchor={sectionIndex:9,paragraphIndex:0,utf16Offset:0}",
              worksID, collectionID, worksTitle, sectionTitle)

        openWorksLibrary(in: app)
        XCTAssertFalse(app.buttons["works-continue"].exists,
                       "Use a fresh task-only seed with no saved position for this work")
        tapWhenReady(app.buttons["collection-\(collectionID)"], in: app)
        tapWhenReady(app.buttons["work-\(worksID)"], in: app)
        let initialContents = app.buttons.matching(NSPredicate(format: "label == %@", "Contents, section 1 of 88")).firstMatch
        XCTAssertTrue(initialContents.waitForExistence(timeout: 15), "Fresh work must open at section 1")
        tapWhenReady(initialContents, in: app)
        let contentsList = app.collectionViews.firstMatch
        XCTAssertTrue(contentsList.waitForExistence(timeout: 10), "The work Contents list must be visible")
        let homilyTen = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Homily 10")).firstMatch
        scrollContentsUntilHittable(homilyTen, list: contentsList, in: app)
        XCTAssertTrue(homilyTen.isHittable)
        homilyTen.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@", "Contents, section 10 of 88")).firstMatch.waitForExistence(timeout: 12))

        let prose = app.descendants(matching: .any).matching(identifier: "works-prose").firstMatch
        XCTAssertTrue(prose.waitForExistence(timeout: 12))
        waitForTextLabel(in: app, containing: sectionAnchor)
        let footerLabels = ["Previous section", "Contents, section 10 of 88", "Next section"]
        let tab = tabButton(app, "tab-read")
        XCTAssertTrue(tab.isHittable)
        for label in footerLabels {
            let control = app.buttons[label]
            XCTAssertTrue(control.isHittable, "Works footer control is not hittable: \(label)")
            XCTAssertLessThanOrEqual(control.frame.maxY, tabBarTopEdge(in: app, within: app.frame) ?? tab.frame.minY,
                                     "Works footer overlaps the shared tab bar: \(label)")
        }

        prose.swipeLeft()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Page 2 of")).firstMatch.waitForExistence(timeout: 8))
        prose.swipeRight()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Page 1 of")).firstMatch.waitForExistence(timeout: 8))
        waitForTextLabel(in: app, containing: sectionAnchor)

        tabButton(app, "tab-settings").tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 8))
        let textSizeOptions = ["settings-text-size-small", "settings-text-size-default", "settings-text-size-large", "settings-text-size-extra-large"]
        let originalSize = try selectedIdentifier(textSizeOptions, in: app)
        let originalSuffix = String(originalSize.dropFirst("settings-text-size-".count))
        let changedSuffix = originalSuffix == "large" ? "small" : "large"
        tapAndWaitForSelection("settings-text-size-\(changedSuffix)", in: app)
        tabButton(app, "tab-read").tap()
        XCTAssertTrue(app.staticTexts[sectionTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Contents, section 10 of 88"].waitForExistence(timeout: 8))
        waitForTextLabel(in: app, containing: sectionAnchor)
        assertWorksFooter(footerLabels, above: tab, in: app)

        // The system glass back button replaced the reader's "Close the reader" and the page's "Back to the library".
        tapSystemBack(in: app, expecting: app.buttons["work-\(worksID)"]) // work reader back to the author page
        XCTAssertTrue(app.staticTexts[sectionTitle].waitForNonExistence(timeout: 8), "The reader must leave before the next back tap")
        tapSystemBack(in: app, expecting: app.buttons["collection-\(collectionID)"]) // author page back to the library
        let continueReading = app.buttons["works-continue"]
        XCTAssertTrue(continueReading.waitForExistence(timeout: 10))
        XCTAssertTrue(continueReading.label.contains("section 10"))

        app.terminate()
        app.launchArguments.removeAll { $0 == "-JohnResetNativeState" } // keep the state across the relaunch
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        openWorksLibrary(in: app)
        let resumed = app.buttons["works-continue"]
        XCTAssertTrue(resumed.waitForExistence(timeout: 12))
        XCTAssertTrue(resumed.label.contains(worksTitle))
        tapWhenReady(resumed, in: app)
        XCTAssertTrue(app.staticTexts[sectionTitle].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Contents, section 10 of 88"].waitForExistence(timeout: 10))
        let resumedProse = app.descendants(matching: .any).matching(identifier: "works-prose").firstMatch
        waitForTextLabel(in: app, containing: sectionAnchor)
        let resumedPage = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Page 1 of")).firstMatch
        XCTAssertTrue(resumedPage.waitForExistence(timeout: 8), "Resume must show the saved page")

        tabButton(app, "tab-settings").tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 8))
        tapAndWaitForSelection(originalSize, in: app)
        tabButton(app, "tab-read").tap()
        XCTAssertTrue(app.staticTexts[sectionTitle].waitForExistence(timeout: 10))
        waitForTextLabel(in: app, containing: sectionAnchor)
        NSLog("WORKS_RESUME_VISIBLE workID=%@ sectionIndex=9 page=1 sectionTextMarker=true", worksID)
    }

    func testWorksSystemBackBeforeSettingsRoundTrip() throws {
        let app = launchWorkReaderForBackCheck()
        verifyWorksBackToAuthor(in: app, caseName: "before-settings")
    }

    func testWorksSystemBackAfterSettingsRoundTripWithoutChange() throws {
        let app = launchWorkReaderForBackCheck()
        tabButton(app, "tab-settings").tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 8))
        attachWorksBackEvidence("settings-unchanged", app: app)
        tabButton(app, "tab-read").tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Contents, section "))
            .firstMatch.waitForExistence(timeout: 10), "Read tab must restore the current Works route")
        verifyWorksBackToAuthor(in: app, caseName: "after-settings-unchanged")
    }

    func testWorksSystemBackAfterSettingsTextSizeChange() throws {
        let app = launchWorkReaderForBackCheck()
        tabButton(app, "tab-settings").tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 8))
        let sizeOptions = ["settings-text-size-small", "settings-text-size-default",
                           "settings-text-size-large", "settings-text-size-extra-large"]
        let originalSize = try selectedIdentifier(sizeOptions, in: app)
        let originalSuffix = String(originalSize.dropFirst("settings-text-size-".count))
        let changedSuffix = originalSuffix == "large" ? "default" : "large"
        tapAndWaitForSelection("settings-text-size-\(changedSuffix)", in: app)
        attachWorksBackEvidence("settings-text-size-changed", app: app)
        tabButton(app, "tab-read").tap()
        let currentSection = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Contents, section ")).firstMatch
        XCTAssertTrue(currentSection.waitForExistence(timeout: 12),
                      "Read tab must restore the current Works route after a text-size change")
        attachWorksBackEvidence("reader-restored-after-size-change", app: app)
        verifyWorksBackToAuthor(in: app, caseName: "after-settings-size-change")
        tabButton(app, "tab-settings").tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 8))
        tapAndWaitForSelection(originalSize, in: app)
    }

    private func launchWorkReaderForBackCheck() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"]
        app.launch()
        openWorksLibrary(in: app)
        tapWhenReady(app.buttons["collection-\(collectionID)"], in: app)
        XCTAssertTrue(app.buttons["work-\(worksID)"].waitForExistence(timeout: 10),
                      "The Works collection must show the selected author’s work")
        tapWhenReady(app.buttons["work-\(worksID)"], in: app)
        let currentSection = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Contents, section ")).firstMatch
        XCTAssertTrue(currentSection.waitForExistence(timeout: 12), "The selected work must open in WorkReader")
        NSLog("WORKS_BACK_REPRO stage=reader-open workID=%@ sectionControl=%@", worksID, currentSection.label)
        attachWorksBackEvidence("reader-open", app: app)
        return app
    }

    private func verifyWorksBackToAuthor(in app: XCUIApplication, caseName: String) {
        let back = systemBack(in: app)
        XCTAssertTrue(back.waitForExistence(timeout: 10), "The system Back button must appear for \(caseName)")
        NSLog("WORKS_BACK_REPRO case=%@ button=%@ frame=%@", caseName, back.identifier,
              NSCoder.string(for: back.frame))
        back.tap()
        attachWorksBackEvidence("\(caseName)-after-back", app: app)
        let authorWork = app.buttons["work-\(worksID)"]
        XCTAssertTrue(authorWork.waitForExistence(timeout: 10),
                      "Back must return to the author’s Works list for \(caseName)")
        NSLog("WORKS_BACK_REPRO case=%@ parent=author-work-list visible=true", caseName)
    }

    private func attachWorksBackEvidence(_ name: String, app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "works-back-\(name)-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let accessibility = XCTAttachment(string: app.debugDescription)
        accessibility.name = "works-back-\(name)-accessibility"
        accessibility.lifetime = .keepAlways
        add(accessibility)
    }

    private func selectedIdentifier(_ identifiers: [String], in app: XCUIApplication) throws -> String {
        for identifier in identifiers {
            if element(identifier, in: app).value as? String == "Selected" { return identifier }
        }
        XCTFail("No selected value in: \(identifiers)")
        throw TestError.noSelection
    }

    private func tapAndWaitForSelection(_ identifier: String, in app: XCUIApplication) {
        let target = element(identifier, in: app)
        tapWhenReady(target, in: app)
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Selected"), object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 8), .completed, "Selection did not save: \(identifier)")
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let byIdentifier = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        if byIdentifier.exists { return byIdentifier }
        guard let label = fallbackLabel(for: identifier) else { return byIdentifier }
        let byButtonLabel = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        if byButtonLabel.exists { return byButtonLabel }
        return app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func fallbackLabel(for identifier: String) -> String? {
        switch identifier {
        case "settings-text-size-small": "Text size, Small"
        case "settings-text-size-default": "Text size, Default"
        case "settings-text-size-large": "Text size, Large"
        case "settings-text-size-extra-large": "Text size, Extra large"
        case "settings-line-spacing-compact": "Line spacing, Compact"
        case "settings-line-spacing-comfortable": "Line spacing, Comfortable"
        case "settings-line-spacing-relaxed": "Line spacing, Relaxed"
        case "settings-scripture-typeface-serif": "Scripture typeface, Serif"
        case "settings-scripture-typeface-sans": "Scripture typeface, Sans"
        case "settings-layout-paragraphs": "Layout, Paragraphs"
        case "settings-layout-verse-by-verse": "Layout, Verse by verse"
        case "settings-appearance-system": "Appearance, System"
        case "settings-appearance-light": "Appearance, Light"
        case "settings-appearance-dark": "Appearance, Dark"
        case "translation-web-ce": "World English Bible — Catholic Edition"
        case "translation-douay-rheims": "Douay–Rheims 1899 American Edition"
        case "translation-vulgate": "Clementine Vulgate 1598 — Latin"
        case "settings-scope-full": "Full Bible"
        case "settings-scope-ot": "Old Testament"
        case "settings-scope-nt": "New Testament"
        case "settings-interval-10": "Every 10 minutes"
        case "settings-interval-15": "Every 15 minutes"
        case "settings-interval-30": "Every 30 minutes"
        case "settings-interval-60": "Every hour"
        case "settings-interval-180": "Every 3 hours"
        case "settings-interval-360": "Every 6 hours"
        case "settings-interval-720": "Every 12 hours"
        case "settings-interval-1440": "Once a day"
        default: nil
        }
    }

    private func settingsRowLabel(_ identifier: String) -> String {
        switch identifier {
        case "settings-scope-full": "Full Bible"
        case "settings-scope-ot": "Old Testament"
        case "settings-scope-nt": "New Testament"
        case "settings-interval-10": "Every 10 minutes"
        case "settings-interval-15": "Every 15 minutes"
        case "settings-interval-30": "Every 30 minutes"
        case "settings-interval-60": "Every hour"
        case "settings-interval-180": "Every 3 hours"
        case "settings-interval-360": "Every 6 hours"
        case "settings-interval-720": "Every 12 hours"
        case "settings-interval-1440": "Once a day"
        default: identifier
        }
    }

    private func waitForTextLabel(in app: XCUIApplication, containing text: String) {
        let element = app.textViews.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 12),
                      "TextView label did not contain the expected anchor. Observed label: \(element.label)")
    }

    private func assertWorksFooter(_ labels: [String], above tab: XCUIElement, in app: XCUIApplication) {
        for label in labels {
            let control = app.buttons[label]
            XCTAssertTrue(control.isHittable, "Works footer control is not hittable: \(label)")
            XCTAssertLessThanOrEqual(control.frame.maxY, tabBarTopEdge(in: app, within: app.frame) ?? tab.frame.minY,
                                     "Works footer overlaps the shared tab bar: \(label)")
        }
    }

    private func openReaderBookList(in app: XCUIApplication) {
        tabButton(app, "tab-read").tap()
        for _ in 0..<3 where !app.staticTexts["reader-book-list-title"].exists {
            let back = app.buttons["reader-back"]
            guard back.exists else { break }
            tapWhenReady(back, in: app)
        }
        XCTAssertTrue(app.staticTexts["reader-book-list-title"].waitForExistence(timeout: 10))
    }

    private func openWorksLibrary(in app: XCUIApplication) {
        openReaderBookList(in: app)
        tapWhenReady(app.buttons["reader-works-link"], in: app)
    }

    /// The iOS 26 system glass back button of a pushed screen.
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

    /// Identity of the visible screen: the navigation bars, the page titles, and the number of back buttons.
    /// Taps Back and waits for the expected parent screen.
    private func tapSystemBack(in app: XCUIApplication, expecting parent: XCUIElement,
                               file: StaticString = #filePath, line: UInt = #line) {
        let back = systemBack(in: app)
        XCTAssertTrue(back.waitForExistence(timeout: 10), "Back control did not appear", file: file, line: line)
        back.tap()
        XCTAssertTrue(parent.waitForExistence(timeout: 10), "The parent screen must appear after Back", file: file, line: line)
    }

    private func tapWhenReady(_ element: XCUIElement, in app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 12), "Control did not appear", file: file, line: line)
        guard let scroll = scrollView(containing: element, in: app) else {
            guard element.isHittable, app.frame.contains(element.frame) else {
                XCTFail("Control has no containing scroll view and is not hittable inside the app: id=\(element.identifier) frame=\(NSCoder.string(for: element.frame)) app=\(NSCoder.string(for: app.frame))",
                        file: file, line: line)
                return
            }
            element.tap()
            return
        }

        var previousFrame = element.frame
        var stalledAttempts = 0
        for attempt in 0..<12 {
            guard element.exists else {
                XCTFail("Control disappeared while scrolling: \(element.identifier)", file: file, line: line)
                return
            }
            guard scroll.exists, scroll.isHittable else {
                XCTFail("Control scroll view disappeared or is not hittable: \(element.identifier)", file: file, line: line)
                return
            }
            let viewport = visibleViewport(for: scroll, in: app)
            guard viewport.height > 120 else {
                XCTFail("No safe visible scroll area: id=\(element.identifier) scroll=\(scroll.identifier) viewport=\(NSCoder.string(for: viewport))",
                        file: file, line: line)
                return
            }
            let targetFrame = element.frame
            if element.isHittable && viewport.contains(targetFrame) { break }
            let scrollDown = targetFrame.midY < viewport.midY
            let startFraction: CGFloat = scrollDown ? 0.25 : 0.75
            let endFraction: CGFloat = scrollDown ? 0.75 : 0.25
            let start = CGPoint(x: viewport.minX + 24, y: viewport.minY + viewport.height * startFraction)
            let end = CGPoint(x: viewport.minX + 24, y: viewport.minY + viewport.height * endFraction)
            NSLog("WORKS_TAP_SCROLL attempt=%d id=%@ scroll=%@ scrollFrame=%@ viewport=%@ target=%@ direction=%@ start=%@ end=%@",
                  attempt + 1, element.identifier, scroll.identifier, NSCoder.string(for: scroll.frame),
                  NSCoder.string(for: viewport), NSCoder.string(for: targetFrame), scrollDown ? "down" : "up",
                  String(describing: start), String(describing: end))
            app.coordinate(withNormalizedOffset: normalized(start, in: app))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(
                    withNormalizedOffset: normalized(end, in: app)))
            guard element.exists, scroll.exists else {
                XCTFail("Control or scroll view disappeared after drag: \(element.identifier)", file: file, line: line)
                return
            }
            let currentFrame = element.frame
            if abs(currentFrame.minY - previousFrame.minY) < 1 {
                stalledAttempts += 1
                NSLog("WORKS_TAP_SCROLL_NO_PROGRESS attempt=%d id=%@ scroll=%@ target=%@ viewport=%@ stalled=%d",
                      attempt + 1, element.identifier, scroll.identifier, NSCoder.string(for: currentFrame),
                      NSCoder.string(for: viewport), stalledAttempts)
            } else {
                stalledAttempts = 0
            }
            previousFrame = currentFrame
            if stalledAttempts >= 3 {
                XCTFail("Scroll made no progress after 3 drags: id=\(element.identifier) scroll=\(scroll.identifier) target=\(NSCoder.string(for: currentFrame)) viewport=\(NSCoder.string(for: viewport))",
                        file: file, line: line)
                break
            }
        }
        guard scroll.exists, scroll.isHittable else {
            XCTFail("Control scroll view disappeared before tap: id=\(element.identifier)", file: file, line: line)
            return
        }
        let finalViewport = visibleViewport(for: scroll, in: app)
        guard element.isHittable && finalViewport.contains(element.frame) else {
            XCTFail("Control is not safely hittable: id=\(element.identifier) scroll=\(scroll.identifier) frame=\(NSCoder.string(for: element.frame)) viewport=\(NSCoder.string(for: finalViewport))",
                    file: file, line: line)
            return
        }
        element.tap()
    }

    private func scrollView(containing element: XCUIElement, in app: XCUIApplication) -> XCUIElement? {
        guard !element.identifier.isEmpty else { return nil }
        let containingScroll = app.scrollViews.containing(.any, identifier: element.identifier).firstMatch
        return containingScroll.exists ? containingScroll : nil
    }

    private func visibleViewport(for scroll: XCUIElement, in app: XCUIApplication) -> CGRect {
        var viewport = scroll.frame.intersection(app.frame)
        guard viewport.width > 0, viewport.height > 0 else { return .zero }

        let topOverlays = [app.statusBars.firstMatch] + app.navigationBars.allElementsBoundByIndex
        let topOcclusion = topOverlays
            .filter { $0.exists && $0.frame.height > 0 && $0.frame.intersects(viewport) }
            .map(\.frame.maxY)
            .filter { $0 > viewport.minY && $0 < viewport.maxY }
            .max()
        if let topOcclusion {
            viewport.size.height -= topOcclusion - viewport.minY
            viewport.origin.y = topOcclusion
        }

        if let tabTop = tabBarTopEdge(in: app, within: viewport), tabTop > viewport.minY, tabTop < viewport.maxY {
            viewport.size.height = min(viewport.height, tabTop - viewport.minY)
        }
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists, keyboard.frame.height > 0, keyboard.frame.intersects(viewport),
           keyboard.frame.minY > viewport.minY {
            viewport.size.height = min(viewport.height, keyboard.frame.minY - viewport.minY)
        }
        return viewport
    }

    private func normalized(_ point: CGPoint, in app: XCUIApplication) -> CGVector {
        let frame = app.frame
        return CGVector(dx: (point.x - frame.minX) / frame.width,
                        dy: (point.y - frame.minY) / frame.height)
    }

    private func scrollContentsUntilHittable(_ target: XCUIElement, list: XCUIElement,
                                             in app: XCUIApplication,
                                             file: StaticString = #filePath, line: UInt = #line) {
        for attempt in 0..<14 where !target.exists || !target.isHittable {
            var viewport = list.frame.intersection(app.frame)
            let tabTop = tabBarTopEdge(in: app, within: viewport)
            if let tabTop { viewport.size.height = min(viewport.height, tabTop - viewport.minY) }
            XCTAssertGreaterThan(viewport.height, 160, "Contents list has no safe visible area", file: file, line: line)
            let wasPresent = target.exists
            let oldTarget = wasPresent ? target.frame : .zero
            let oldList = list.frame
            let x = viewport.midX
            let startY = viewport.minY + viewport.height * 0.75
            let endY = viewport.minY + viewport.height * 0.25
            NSLog("WORKS_CONTENTS_SCROLL attempt=%d viewport=%@ target=%@ direction=up",
                  attempt + 1, NSCoder.string(for: viewport), NSCoder.string(for: oldTarget))
            app.coordinate(withNormalizedOffset: normalized(CGPoint(x: x, y: startY), in: app))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(
                    withNormalizedOffset: normalized(CGPoint(x: x, y: endY), in: app)))
            let moved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                target.exists != wasPresent || (target.exists && target.frame != oldTarget) || list.frame != oldList
            }, object: target)
            XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 2), .completed,
                           "The Contents list or Homily 10 row must move after a bounded scroll", file: file, line: line)
        }
        XCTAssertTrue(target.exists, "Homily 10 must load in the actual Contents list", file: file, line: line)
        XCTAssertTrue(target.isHittable, "Homily 10 must be visible in the actual Contents list", file: file, line: line)
    }

    private enum TestError: Error { case noSelection }

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
