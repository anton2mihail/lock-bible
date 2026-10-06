import XCTest

/// Release-only workload measurements. Main owns the Release target, seed, and every run.
/// These tests measure user-visible automation latency, not repository CPU time.
@MainActor
final class ReleasePerformanceUITests: XCTestCase {
    private let timeout: TimeInterval = 30

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testL26ColdProcessLaunchShowsUsefulTodayContent() throws {
        let config = try configuration()
        var samples: [Double] = []
        for index in 0..<config.sampleCount {
            let app = application(bundleID: config.bundleID)
            if app.state != .notRunning { app.terminate() }
            let start = ProcessInfo.processInfo.systemUptime
            app.launch()
            let labels = try waitForUsefulToday(app)
            let elapsed = ProcessInfo.processInfo.systemUptime - start
            samples.append(elapsed)
            NSLog("L26_LAUNCH_SAMPLE index=%d seconds=%.6f title=%@ readings=%@ prayer=%@ verse=%@ verseVisible=%@",
                  index + 1, elapsed, labels.title, labels.readings, labels.prayer,
                  labels.verse, labels.verseVisible ? "true" : "false")
            app.terminate()
        }
        emitSummary("cold-process-useful-today-launch", samples: samples, config: config, warmups: 0)
    }

    func testL26ChapterAndSearchActionLatency() throws {
        let config = try configuration()
        var chapterSamples: [Double] = []
        var referenceSamples: [Double] = []
        var ftsSamples: [Double] = []

        // One untimed chapter and query warm-up is excluded from each distribution.
        for sampleIndex in -1..<config.sampleCount {
            let app = application(bundleID: config.bundleID)
            app.launch()
            navigateToChapterList("JHN", in: app)
            let chapterStart = ProcessInfo.processInfo.systemUptime
            app.buttons["reader-chapter-1"].tap()
            try waitForJohnOneContent(app)
            let chapterTime = ProcessInfo.processInfo.systemUptime - chapterStart
            if sampleIndex >= 0 { chapterSamples.append(chapterTime) }
            NSLog("L26_CHAPTER_SAMPLE index=%d excludedWarmup=%@ seconds=%.6f title=%@ firstVerse=%@ attribution=%@",
                  sampleIndex + 2, sampleIndex < 0 ? "true" : "false", chapterTime,
                  app.buttons["reader-title"].label, app.buttons["reader-verse-1"].label,
                  app.staticTexts["reader-edition-attribution"].label)

            app.buttons["reader-search-button"].tap()
            let search = app.textFields["search-query-input"]
            XCTAssertTrue(search.waitForExistence(timeout: timeout), "Search input must appear")
            let referenceStart = ProcessInfo.processInfo.systemUptime
            replaceQuery("John 3:16", in: search)
            let referenceResult = app.buttons["search-result-1"]
            waitForSearchResult(referenceResult, queryField: search, query: "John 3:16", resultPart: "John 3:16")
            let referenceTime = ProcessInfo.processInfo.systemUptime - referenceStart
            if sampleIndex >= 0 { referenceSamples.append(referenceTime) }
            NSLog("L26_SEARCH_SAMPLE kind=reference index=%d excludedWarmup=%@ seconds=%.6f query=%@ result=%@",
                  sampleIndex + 2, sampleIndex < 0 ? "true" : "false", referenceTime,
                  search.value as? String ?? "", referenceResult.label)

            let ftsStart = ProcessInfo.processInfo.systemUptime
            replaceQuery("faith", in: search)
            let ftsResult = app.buttons["search-result-1"]
            waitForSearchResult(ftsResult, queryField: search, query: "faith", resultPart: "Romans 3:3")
            XCTAssertTrue(ftsResult.label.contains("without faith"), ftsResult.label)
            let ftsTime = ProcessInfo.processInfo.systemUptime - ftsStart
            if sampleIndex >= 0 { ftsSamples.append(ftsTime) }
            NSLog("L26_SEARCH_SAMPLE kind=ordinary-fts index=%d excludedWarmup=%@ seconds=%.6f query=%@ result=%@",
                  sampleIndex + 2, sampleIndex < 0 ? "true" : "false", ftsTime,
                  search.value as? String ?? "", ftsResult.label)
            app.terminate()
        }
        emitSummary("chapter-open", samples: chapterSamples, config: config, warmups: 1)
        emitSummary("search-reference-user-action", samples: referenceSamples, config: config, warmups: 1)
        emitSummary("search-ordinary-fts-user-action", samples: ftsSamples, config: config, warmups: 1)
    }

    func testL26LongReaderScrollAndWorksPageProgression() throws {
        let config = try configuration()
        let app = application(bundleID: config.bundleID)
        app.launch()
        openBook("PSA", chapter: 119, in: app)
        let lastPsalmVerse = app.buttons["reader-verse-176"]
        XCTAssertTrue(lastPsalmVerse.waitForExistence(timeout: timeout), "Psalm 119:176 must load")
        attachScreenshot("reader-long-chapter-before", from: app)
        let readerScroll = app.scrollViews["reader-chapter-scroll"]
        XCTAssertTrue(readerScroll.waitForExistence(timeout: timeout), "Reader chapter scroll must be available")
        var attempts = 0
        while !lastPsalmVerse.isHittable && attempts < 24 {
            readerScroll.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(lastPsalmVerse.isHittable, "Psalm 119:176 must become visible after bounded scrolling")
        attachScreenshot("reader-long-chapter-after", from: app)
        NSLog("L26_LONG_READER chapter=PSA:119 laterVerse=%@ visible=%@",
              lastPsalmVerse.label, lastPsalmVerse.isHittable ? "true" : "false")
        // The Reader scroll can minimize the glass bar. Expand it and check the tab button before any later navigation.
        expandTabBar(in: app, expecting: "tab-read")

        app.buttons["reader-back"].tap() // chapter back to chapter list
        app.buttons["reader-back"].tap() // chapter list back to book list
        let works = app.buttons["reader-works-link"]
        XCTAssertTrue(works.waitForExistence(timeout: timeout), "Works entry must be visible")
        works.tap()
        let collection = app.buttons["collection-chrysostom"]
        XCTAssertTrue(collection.waitForExistence(timeout: timeout), "Chrysostom collection must load")
        collection.tap()
        let item = app.buttons["work-chrysostom.homilies-on-the-gospel-of-john"]
        XCTAssertTrue(item.waitForExistence(timeout: timeout), "Long work must be available")
        item.tap()
        let contents = app.buttons["Contents, section 1 of 88"]
        XCTAssertTrue(contents.waitForExistence(timeout: timeout), "Work contents must load")
        contents.tap()
        let section = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Homily 10")).firstMatch
        let contentsList = app.collectionViews.firstMatch
        XCTAssertTrue(contentsList.waitForExistence(timeout: timeout), "Work Contents list must appear")
        var contentSwipes = 0
        while !section.exists && contentSwipes < 12 {
            contentsList.swipeUp()
            contentSwipes += 1
        }
        XCTAssertTrue(section.waitForExistence(timeout: timeout), "Homily 10 must appear in Contents")
        section.tap()
        let prose = app.descendants(matching: .any).matching(identifier: "works-prose").firstMatch
        XCTAssertTrue(prose.waitForExistence(timeout: timeout), "Works prose must load")
        let firstPage = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Page 1 of")).firstMatch
        XCTAssertTrue(firstPage.waitForExistence(timeout: timeout), "Page 1 marker must appear")
        let firstBody = worksPageBody(in: app, prose: prose)
        let firstValue = firstBody.joined(separator: "\n")
        XCTAssertFalse(firstValue.isEmpty, "Works page must expose full body text")
        attachScreenshot("works-page-before", from: app)
        prose.swipeLeft()
        let secondPage = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Page 2 of")).firstMatch
        XCTAssertTrue(secondPage.waitForExistence(timeout: timeout), "Next page marker must appear")
        let deadline = Date().addingTimeInterval(timeout)
        var secondBody = worksPageBody(in: app, prose: prose)
        while secondBody.isEmpty || secondBody == firstBody, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            secondBody = worksPageBody(in: app, prose: prose)
        }
        let secondValue = secondBody.joined(separator: "\n")
        XCTAssertFalse(secondValue.isEmpty, "Page 2 must expose nonempty body text")
        XCTAssertNotEqual(firstBody, secondBody, "Visible Works body text must change after page progression")
        attachScreenshot("works-page-after", from: app)
        NSLog("L26_LONG_WORK workID=%@ section=%@ firstPage=%@ secondPage=%@ firstBodyUTF16=%lu secondBodyUTF16=%lu textChanged=true",
              "chrysostom.homilies-on-the-gospel-of-john", "Homily 10", firstPage.label, secondPage.label,
              firstValue.utf16.count, secondValue.utf16.count)
        app.terminate()
        NSLog("L26_LONG_TEXT captureCount=4 fpsClaims=false")
    }

    private func waitForUsefulToday(_ app: XCUIApplication) throws ->
        (title: String, readings: String, prayer: String, verse: String, verseVisible: Bool) {
        let title = app.staticTexts["today-title"]
        let readings = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Today’s readings")).firstMatch
        let morning = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "A morning offering")).firstMatch
        let evening = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "An evening examen")).firstMatch
        let verse = app.staticTexts["today-verse-card"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if title.exists, readings.exists, !readings.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               (morning.exists || evening.exists), verse.exists,
               !(verse.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                return (title.label, readings.label, morning.exists ? morning.label : evening.label,
                        verse.label, verse.isHittable)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        attachScreenshot("today-readiness-failure", from: app)
        XCTFail("Useful Today content did not load within \(timeout) seconds")
        return (title.label, readings.label, "", verse.label, verse.isHittable)
    }

    private func openBook(_ code: String, chapter: Int, in app: XCUIApplication) {
        navigateToChapterList(code, in: app)
        let chapterButton = app.buttons["reader-chapter-\(chapter)"]
        XCTAssertTrue(chapterButton.waitForExistence(timeout: timeout), "Chapter \(chapter) must be available")
        chapterButton.tap()
    }

    private func navigateToChapterList(_ code: String, in app: XCUIApplication) {
        tabButton(app, "tab-read").tap()
        navigateToBookList(app)
        let book = app.buttons["reader-book-\(code)"]
        XCTAssertTrue(book.waitForExistence(timeout: timeout), "Book \(code) must be available from the Reader book list")
        book.tap()
        XCTAssertTrue(app.buttons["reader-chapter-1"].waitForExistence(timeout: timeout), "Chapter list must be available")
    }

    private func worksPageBody(in app: XCUIApplication, prose: XCUIElement) -> [String] {
        app.textViews.allElementsBoundByIndex.compactMap { element in
            guard element.identifier != "works-prose",
                  element.frame.intersects(prose.frame) else { return nil }
            let label = element.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = (element.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let body = label.isEmpty ? value : label
            guard !body.isEmpty,
                  !body.hasPrefix("Homily 10 on the Gospel of John"),
                  !body.hasPrefix("John 1:11") else { return nil }
            return body
        }
    }

    private func navigateToBookList(_ app: XCUIApplication) {
        let bookListTitle = app.staticTexts["reader-book-list-title"]
        for _ in 0..<3 {
            if bookListTitle.waitForExistence(timeout: 2) { return }
            let back = app.buttons["reader-back"]
            XCTAssertTrue(back.waitForExistence(timeout: 4), "Reader must expose a Back control to the book list")
            back.tap()
        }
        XCTAssertTrue(bookListTitle.waitForExistence(timeout: timeout), "Reader book list must be reached through visible Back controls")
    }

    private func waitForSearchResult(_ result: XCUIElement, queryField: XCUIElement,
                                     query: String, resultPart: String) {
        let queryExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", query), object: queryField)
        let resultExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", resultPart), object: result)
        XCTAssertEqual(XCTWaiter.wait(for: [queryExpectation, resultExpectation], timeout: timeout), .completed,
                       "Search must show query \(query) with expected result \(resultPart)")
    }

    private func waitForJohnOneContent(_ app: XCUIApplication) throws {
        XCTAssertTrue(app.buttons["reader-title"].waitForExistence(timeout: timeout))
        let title = app.buttons["reader-title"]
        let verse = app.buttons["reader-verse-1"]
        let attribution = app.staticTexts["reader-edition-attribution"]
        let complete = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "John 1"), object: title)
        XCTAssertEqual(XCTWaiter.wait(for: [complete], timeout: timeout), .completed)
        XCTAssertTrue(verse.waitForExistence(timeout: timeout), "Canonical John 1:1 must load")
        XCTAssertTrue(verse.label.contains("In the beginning was the Word"), verse.label)
        XCTAssertTrue(attribution.waitForExistence(timeout: timeout), "Edition attribution must load")
        XCTAssertFalse(attribution.label.isEmpty)
    }

    private func replaceQuery(_ text: String, in field: XCUIElement) {
        field.tap()
        if let current = field.value as? String, !current.isEmpty, current != "Search Scripture" {
            let delete = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)
            field.typeText(delete)
        }
        field.typeText(text)
    }

    private func attachScreenshot(_ name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func configuration() throws -> Configuration {
        let environment = ProcessInfo.processInfo.environment
        guard let bundleID = environment["L26_RELEASE_BUNDLE_ID"],
              !bundleID.isEmpty, bundleID != "com.nrsv.verse" else {
            throw ConfigurationError.missing("explicit task-only Release bundle ID")
        }
        guard let seedID = environment["L26_TASK_SEED_ID"], !seedID.isEmpty else {
            throw ConfigurationError.missing("task-only seed identity")
        }
        guard environment["L26_SEED_TRANSLATION_ID"] == "web-ce" else {
            throw ConfigurationError.missing("task-only seed with WEB-CE selected")
        }
        guard environment["L26_SEED_HAS_WORKS_POSITION"] == "false" else {
            throw ConfigurationError.missing("task-only seed with no saved Works position")
        }
        guard environment["L26_BUILD_CONFIGURATION"] == "Release",
              let appHash = environment["L26_APP_BINARY_SHA256"], !appHash.isEmpty else {
            throw ConfigurationError.missing("Release build identity and app binary SHA-256")
        }
        guard let countText = environment["L26_SAMPLE_COUNT"] else {
            throw ConfigurationError.missing("L26_SAMPLE_COUNT set to 3 or 20")
        }
        guard let count = Int(countText), count == 3 || count == 20 else {
            throw ConfigurationError.missing("L26_SAMPLE_COUNT set to 3 or 20")
        }
        NSLog("L26_CONFIG bundleID=%@ seedID=%@ build=Release appSHA256=%@ sampleCount=%d classification=%@ coldMeaning=app-process-restart",
              bundleID, seedID, appHash, count, count == 3 ? "preflight-only" : "recorded-distribution")
        return Configuration(bundleID: bundleID, seedID: seedID, sampleCount: count)
    }

    private func application(bundleID: String) -> XCUIApplication {
        XCUIApplication(bundleIdentifier: bundleID)
    }

    private func emitSummary(_ name: String, samples: [Double], config: Configuration, warmups: Int) {
        XCTAssertEqual(samples.count, config.sampleCount)
        let sorted = samples.sorted()
        let median: Double
        if sorted.count.isMultiple(of: 2) {
            median = (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        } else {
            median = sorted[sorted.count / 2]
        }
        let p95Index = max(0, Int(ceil(0.95 * Double(sorted.count))) - 1)
        let className = config.sampleCount == 3 ? "preflight-only" : "recorded-distribution"
        NSLog("L26_SUMMARY workload=%@ classification=%@ samples=%d warmups=%d raw=%@ median=%.6f nearestRankP95=%.6f readinessTimeoutSeconds=%.0f",
              name, className, samples.count, warmups, samples.map { String(format: "%.6f", $0) }.joined(separator: ","), median,
              sorted[p95Index], timeout)
        NSLog("L26_LIMITS workload=%@ simulatorOnly=true proposedPhysicalTargets=median1s,p95_1.5s,query150ms budgetsApplied=false",
              name)
    }

    private struct Configuration {
        let bundleID: String
        let seedID: String
        let sampleCount: Int
    }

    private struct ConfigurationError: Error, CustomStringConvertible {
        let description: String
        static func missing(_ value: String) -> Self {
            Self(description: "Missing required L26 configuration: \(value)")
        }
    }

    /// The Liquid Glass tab bar minimizes while the Read tab scrolls. Release has no `-JohnTabBarMinimize never`
    /// (that argument exists only in Debug). Before a tab tap after a Reader scroll, expand the bar (tap the minimized
    /// bar, then scroll up) and check that the target tab button is hittable (Liquid-glass-tabview-review.md fix 5).
    private func expandTabBar(in app: XCUIApplication, expecting tabID: String) {
        let tab = tabButton(app, tabID)
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
