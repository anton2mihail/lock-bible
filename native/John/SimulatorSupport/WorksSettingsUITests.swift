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
        app.buttons["tab-settings"].tap()
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
        let readerValues = [
            ("settings-text-size", readerTextSizeLabel(originalChoices["text-size"]!)),
            ("settings-line-spacing", choiceLabel(originalChoices["line-spacing"]!)),
            ("settings-scripture-typeface", choiceLabel(originalChoices["scripture-typeface"]!)),
            ("settings-reading-layout", choiceLabel(originalChoices["layout"]!)),
            ("settings-appearance", choiceLabel(originalChoices["appearance"]!)),
            ("settings-translation", readerTranslationLabel(initialTranslation)),
        ]
        for (identifier, expected) in readerValues {
            let picker = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            XCTAssertTrue(picker.waitForExistence(timeout: 5), "Missing Reader Aa control: \(identifier)")
            XCTAssertEqual(picker.value as? String, expected, "Reader Aa does not match \(identifier)")
        }
        tapWhenReady(app.buttons["reader-appearance-close"], in: app)
    }

    func testWorksContentsFooterStyleAnchorAndResume() throws {
        let app = XCUIApplication()
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
        let tab = app.buttons["tab-read"]
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

        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 8))
        let textSizeOptions = ["settings-text-size-small", "settings-text-size-default", "settings-text-size-large", "settings-text-size-extra-large"]
        let originalSize = try selectedIdentifier(textSizeOptions, in: app)
        let originalSuffix = String(originalSize.dropFirst("settings-text-size-".count))
        let changedSuffix = originalSuffix == "large" ? "small" : "large"
        tapAndWaitForSelection("settings-text-size-\(changedSuffix)", in: app)
        app.buttons["tab-read"].tap()
        XCTAssertTrue(app.staticTexts[sectionTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Contents, section 10 of 88"].waitForExistence(timeout: 8))
        waitForTextLabel(in: app, containing: sectionAnchor)
        assertWorksFooter(footerLabels, above: tab, in: app)

        tapWhenReady(app.buttons["Close the reader"], in: app)
        tapWhenReady(app.buttons["Back to the library"], in: app)
        let continueReading = app.buttons["works-continue"]
        XCTAssertTrue(continueReading.waitForExistence(timeout: 10))
        XCTAssertTrue(continueReading.label.contains("section 10"))

        app.terminate()
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

        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 8))
        tapAndWaitForSelection(originalSize, in: app)
        app.buttons["tab-read"].tap()
        XCTAssertTrue(app.staticTexts[sectionTitle].waitForExistence(timeout: 10))
        waitForTextLabel(in: app, containing: sectionAnchor)
        NSLog("WORKS_RESUME_VISIBLE workID=%@ sectionIndex=9 page=1 sectionTextMarker=true", worksID)
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

    private func choiceLabel(_ identifier: String) -> String {
        let prefixes = ["settings-text-size-", "settings-line-spacing-", "settings-scripture-typeface-",
                        "settings-layout-", "settings-appearance-"]
        guard let prefix = prefixes.first(where: identifier.hasPrefix) else { return "" }
        let suffix = String(identifier.dropFirst(prefix.count))
        return switch suffix {
        case "small": "Small"
        case "default": "Default"
        case "large": "Large"
        case "extra-large": "Extra large"
        case "compact": "Compact"
        case "comfortable": "Comfortable"
        case "relaxed": "Relaxed"
        case "serif": "Serif"
        case "sans": "Sans"
        case "paragraphs": "Paragraphs"
        case "verse-by-verse": "Verse by verse"
        case "system": "System"
        case "light": "Light"
        case "dark": "Dark"
        default: ""
        }
    }

    private func readerTranslationLabel(_ identifier: String) -> String {
        switch identifier {
        case "translation-web-ce": "WEB"
        case "translation-douay-rheims": "Douay-Rheims"
        case "translation-vulgate": "Vulgate"
        default: ""
        }
    }

    private func readerTextSizeLabel(_ identifier: String) -> String {
        let suffix = String(identifier.dropFirst("settings-text-size-".count))
        return suffix == "default" ? "Medium" : choiceLabel(identifier)
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
        app.buttons["tab-read"].tap()
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

    private func tapWhenReady(_ element: XCUIElement, in app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 12), "Control did not appear", file: file, line: line)
        for _ in 0..<8 where !element.isHittable {
            let scroll = app.scrollViews.allElementsBoundByIndex
                .filter { $0.exists && $0.isHittable }
                .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
            let frame = scroll?.frame ?? app.frame
            if element.frame.maxY < frame.minY { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable, "Control is not hittable", file: file, line: line)
        element.tap()
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
            app.coordinate(withNormalizedOffset: CGVector(dx: x / app.frame.width, dy: startY / app.frame.height))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(
                    withNormalizedOffset: CGVector(dx: x / app.frame.width, dy: endY / app.frame.height)))
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
        guard nativeTabs.firstMatch.exists else { return nil } // the old app has no `tab-` identifiers; its rules stay as they were
        let bar = app.tabBars.firstMatch
        if bar.exists, bar.frame.height > 0 { return bar.frame.minY }
        let tops = nativeTabs.allElementsBoundByIndex.filter { $0.exists && $0.frame.intersects(viewport) }.map(\.frame.minY)
        return tops.min().map { $0 - 12 }
    }
}
