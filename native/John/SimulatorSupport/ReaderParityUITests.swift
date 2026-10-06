import XCTest

/// Source-backed Reader checks. Main owns target membership, fresh task-only seeds, and simulator runs.
@MainActor
final class ReaderParityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBibleRepositoryCasesAcrossEditions() throws {
        let variant = CaptureVariant.current
        let allSamples = Edition.allCases.flatMap { samples(for: $0) }
        let caseKey = CaptureMetadata.value("READER_PARITY_CASE")
        let selectedSamples: [BibleCase]
        if caseKey == "unprovided" {
            selectedSamples = allSamples
        } else if let sample = allSamples.first(where: { $0.key == caseKey }) {
            selectedSamples = [sample]
        } else {
            XCTFail("Unknown Reader parity case: \(caseKey)")
            return
        }
        let app = launch(variant: variant)

        for sample in selectedSamples {
            let profile = applyCaptureProfile(edition: sample.edition, in: app, variant: variant)
            openCaptureBookList(in: app, variant: variant)
            let book = captureBookControl(sample, in: app, variant: variant)
            tapWhenReady(book, in: app)

            let chapter = captureChapterControl(sample, in: app, variant: variant)
            tapWhenReady(chapter, in: app)
            let title = captureTitleControl(sample, in: app, variant: variant)
            waitForLabel(title, equals: "\(sample.bookName) \(sample.chapter)")

            let attribution = captureAttributionControl(sample.edition, in: app, variant: variant)
            let firstVerse = captureVerseControl(sample.firstVerseNumber, in: app, variant: variant)
            XCTAssertTrue(firstVerse.waitForExistence(timeout: 10), "Missing first verse: \(sample.key)")
            XCTAssertTrue(firstVerse.isHittable, "The chapter must open at its natural top: \(sample.key)")
            XCTAssertTrue(firstVerse.label.contains(sample.firstVerseText), "First verse differs from source: \(sample.key)")
            attachScreenshot("reader-parity-\(variant.rawValue)-\(sample.key)-top", app: app)

            let lastVerse = captureVerseControl(sample.lastVerseNumber, in: app, variant: variant)
            scrollToVisible(lastVerse, in: app)
            XCTAssertTrue(lastVerse.label.contains(sample.lastVerseText), "Last verse differs from source: \(sample.key)")
            waitForLabel(attribution, equals: sample.edition.attribution)
            attachScreenshot("reader-parity-\(variant.rawValue)-\(sample.key)-end", app: app)
            NSLog("READER_PARITY case=%@ variant=%@ edition=%@ book=%@ chapter=%d first=%d last=%d attribution=%@ requestedProfile=%@ verifiedProfile=%@ appearancePreference=%@ effectiveAppearance=%@ appVersion=%@ device=%@ seed=%@",
                  sample.key, variant.rawValue, sample.edition.id, sample.bookName, sample.chapter,
                  sample.firstVerseNumber, sample.lastVerseNumber, sample.edition.abbreviation,
                  profile.requested, profile.verified, profile.appearancePreference,
                  CaptureMetadata.value("READER_PARITY_EFFECTIVE_APPEARANCE"),
                  CaptureMetadata.value("READER_PARITY_APP_VERSION"),
                  CaptureMetadata.value("READER_PARITY_DEVICE"),
                  CaptureMetadata.value("READER_PARITY_SEED"))
        }
    }

    func testGoToExpandsCurrentChapterAndReturnsThroughVisibleControls() throws {
        let app = launch(variant: .native)
        _ = applyProfile(edition: .web, layout: "Paragraphs", in: app)
        openChapter("JHN", number: 1, in: app)

        tapWhenReady(app.buttons["reader-title"], in: app)
        XCTAssertTrue(app.staticTexts["Go to"].waitForExistence(timeout: 8))
        let john = app.buttons["go-to-book-JHN"]
        waitForValue(john, equals: "Expanded")
        XCTAssertTrue(app.buttons["go-to-chapter-JHN-1"].waitForExistence(timeout: 8),
                      "Go To must show the current chapter marker")
        attachScreenshot("reader-parity-go-to-current-john-1", app: app)

        let psalms = app.buttons["go-to-book-PSA"]
        tapWhenReady(psalms, in: app)
        waitForValue(psalms, equals: "Expanded")
        let psalm23 = app.buttons["go-to-chapter-PSA-23"]
        tapWhenReady(psalm23, in: app)

        waitForLabel(app.buttons["reader-title"], equals: "Psalms 23")
        let backToChapters = app.buttons["reader-back"]
        waitForLabel(backToChapters, equals: "Back to Psalms chapters")
        backToChapters.tap()
        XCTAssertTrue(app.scrollViews["reader-chapter-grid-scroll"].waitForExistence(timeout: 8))
        let backToBooks = app.buttons["reader-back"]
        waitForLabel(backToBooks, equals: "Back to books")
        backToBooks.tap()
        XCTAssertTrue(app.staticTexts["reader-book-list-title"].waitForExistence(timeout: 8))
        attachScreenshot("reader-parity-go-to-back-to-books", app: app)
        NSLog("READER_PARITY goTo=current=JHN:1 selected=PSA:23 back=chapters,books Aa=not-claimed")
    }

    func testVerseLayoutRangeTransitionsAndSameEndRules() throws {
        let app = launch(variant: .native)
        _ = applyProfile(edition: .web, layout: "Verse by verse", in: app)
        openChapter("JHN", number: 1, in: app)

        selectVerse(10, expectedSummary: "Selected: verses 10–10", reference: "John 1:10", in: app)
        selectVerse(12, expectedSummary: "Selected: verses 10–12", reference: "John 1:10–12", in: app)
        selectVerse(8, expectedSummary: "Selected: verses 8–12", reference: "John 1:8–12", in: app)
        selectVerse(11, expectedSummary: "Selected: verses 8–11", reference: "John 1:8–11", in: app)

        // A repeated endpoint keeps a multi-verse range. Source clears a repeated singleton only.
        tapVerse(11, in: app)
        assertSelection(summary: "Selected: verses 8–11", reference: "John 1:8–11", in: app)
        app.buttons["reader-selection-close"].tap()
        XCTAssertTrue(app.staticTexts["reader-selection-summary"].waitForNonExistence(timeout: 5))

        selectVerse(11, expectedSummary: "Selected: verses 11–11", reference: "John 1:11", in: app)
        tapVerse(11, in: app)
        XCTAssertTrue(app.staticTexts["reader-selection-summary"].waitForNonExistence(timeout: 5),
                      "Tapping the same selected singleton must clear it")
        XCTAssertFalse(app.staticTexts["reader-selection-reference"].exists)
        NSLog("READER_PARITY verseLayoutRange=10,10-12,8-12,8-11 repeatedRange=kept singleton=cleared")
    }

    private func launch(variant: CaptureVariant) -> XCUIApplication {
        let bundleID = CaptureMetadata.value(variant == .baseline ?
                                             "READER_PARITY_BASELINE_BUNDLE_ID" :
                                             "READER_PARITY_NATIVE_BUNDLE_ID")
        if variant == .baseline && bundleID == "unprovided" {
            XCTFail("Baseline runs require an explicit installed bundle ID")
            return XCUIApplication(bundleIdentifier: "invalid.baseline.bundle.id")
        }
        let app = bundleID == "unprovided" ? XCUIApplication() : XCUIApplication(bundleIdentifier: bundleID)
        app.launch()
        if variant == .native {
            XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))
        } else {
            let readTab = app.buttons.matching(NSPredicate(format: "label == %@", "Read")).firstMatch
            XCTAssertTrue(readTab.waitForExistence(timeout: 12), "Baseline must expose its Read tab")
            readTab.tap()
            XCTAssertTrue(app.staticTexts["Read the Bible"].waitForExistence(timeout: 12),
                          "Baseline Read screen must expose its source title")
        }
        return app
    }

    private func applyProfile(edition: Edition, layout: String, in app: XCUIApplication) -> String {
        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 8))
        for (identifier, selectedValue) in [
            ("settings-text-size-default", "Text size, Default"),
            ("settings-line-spacing-comfortable", "Line spacing, Comfortable"),
            ("settings-scripture-typeface-serif", "Scripture typeface, Serif"),
            ("settings-layout-\(layout.lowercased().replacingOccurrences(of: " ", with: "-"))", "Layout, \(layout)"),
        ] {
            let control = app.buttons[identifier]
            tapIfNotSelected(control, in: app)
            waitForValue(control, equals: "Selected")
            XCTAssertEqual(control.label, selectedValue)
        }
        let translation = app.buttons["translation-\(edition.id)"]
        tapIfNotSelected(translation, in: app)
        waitForValue(translation, equals: "Selected")
        let observedAppearance = ["system", "light", "dark"].first { name in
            (app.buttons["settings-appearance-\(name)"].value as? String) == "Selected"
        } ?? "unresolved"
        XCTAssertNotEqual(observedAppearance, "unresolved", "The Settings screen must expose the current appearance")
        NSLog("READER_PARITY_PROFILE size=Medium spacing=Comfortable typeface=Serif layout=%@ edition=%@ appearancePreference=%@",
              layout, edition.id, observedAppearance)
        app.buttons["tab-read"].tap()
        return observedAppearance
    }

    private func applyCaptureProfile(edition: Edition, in app: XCUIApplication,
                                     variant: CaptureVariant) -> CaptureProfileObservation {
        if variant == .native {
            let appearance = applyProfile(edition: edition, layout: "Paragraphs", in: app)
            return CaptureProfileObservation(requested: "Medium/Comfortable/Serif/Paragraphs/\(edition.id)",
                                             verified: "Medium/Comfortable/Serif/Paragraphs/\(edition.id)",
                                             appearancePreference: appearance)
        }

        let settingsTab = app.buttons.matching(NSPredicate(format: "label == %@", "Settings")).firstMatch
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 8), "Baseline must expose Settings")
        settingsTab.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8))
        let requestedChoices = [
            "Text size, Default", "Line spacing, Comfortable",
            "Scripture typeface, Serif", "Layout, Paragraphs", edition.fullName,
        ]
        var observedChoices: [String] = []
        for label in requestedChoices {
            let choice = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", label)).firstMatch
            XCTAssertTrue(choice.waitForExistence(timeout: 8), "Baseline is missing source control: \(label)")
            tapWhenReady(choice, in: app)
            observedChoices.append("\(label)=\(CaptureMetadata.selectionValue(choice))")
        }
        let appearance = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Appearance, System")).firstMatch
        let appearancePreference = appearance.exists ? CaptureMetadata.selectionValue(appearance) : "unresolved"
        app.buttons.matching(NSPredicate(format: "label == %@", "Read")).firstMatch.tap()
        return CaptureProfileObservation(
            requested: "Medium/Comfortable/Serif/Paragraphs/\(edition.id)",
            verified: observedChoices.joined(separator: ";"),
            appearancePreference: appearancePreference
        )
    }

    private func openCaptureBookList(in app: XCUIApplication, variant: CaptureVariant) {
        if variant == .native {
            openBookList(in: app)
            return
        }
        let bookListTitle = app.staticTexts["Read the Bible"]
        if bookListTitle.exists { return }
        for _ in 0..<3 where !bookListTitle.exists {
            let back = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Back to ")).firstMatch
            XCTAssertTrue(back.waitForExistence(timeout: 8), "Baseline Reader must expose its visible Back action")
            tapWhenReady(back, in: app)
        }
        XCTAssertTrue(bookListTitle.waitForExistence(timeout: 8))
    }

    private func captureBookControl(_ sample: BibleCase, in app: XCUIApplication,
                                    variant: CaptureVariant) -> XCUIElement {
        if variant == .native { return app.buttons["reader-book-\(sample.code)"] }
        return app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(sample.bookName), ")).firstMatch
    }

    private func captureChapterControl(_ sample: BibleCase, in app: XCUIApplication,
                                       variant: CaptureVariant) -> XCUIElement {
        if variant == .native { return app.buttons["reader-chapter-\(sample.chapter)"] }
        return app.buttons.matching(NSPredicate(format: "label == %@", "\(sample.bookName) chapter \(sample.chapter)")).firstMatch
    }

    private func captureTitleControl(_ sample: BibleCase, in app: XCUIApplication,
                                    variant: CaptureVariant) -> XCUIElement {
        if variant == .native { return app.buttons["reader-title"] }
        return app.buttons.matching(NSPredicate(format: "label == %@", "\(sample.bookName) \(sample.chapter)")).firstMatch
    }

    private func captureVerseControl(_ number: Int, in app: XCUIApplication,
                                     variant: CaptureVariant) -> XCUIElement {
        if variant == .native { return app.buttons["reader-verse-\(number)"] }
        return app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Verse \(number). ")).firstMatch
    }

    private func captureAttributionControl(_ edition: Edition, in app: XCUIApplication,
                                          variant: CaptureVariant) -> XCUIElement {
        if variant == .native { return app.staticTexts["reader-edition-attribution"] }
        return app.staticTexts.matching(NSPredicate(format: "label == %@", edition.attribution)).firstMatch
    }

    private func openBookList(in app: XCUIApplication) {
        if app.staticTexts["reader-book-list-title"].exists { return }
        app.buttons["tab-read"].tap()
        for _ in 0..<3 where !app.staticTexts["reader-book-list-title"].exists {
            let back = app.buttons["reader-back"]
            XCTAssertTrue(back.waitForExistence(timeout: 8), "Reader must expose visible Back controls")
            tapWhenReady(back, in: app)
        }
        XCTAssertTrue(app.staticTexts["reader-book-list-title"].waitForExistence(timeout: 8))
    }

    private func openChapter(_ code: String, number: Int, in app: XCUIApplication) {
        openBookList(in: app)
        tapWhenReady(app.buttons["reader-book-\(code)"], in: app)
        tapWhenReady(app.buttons["reader-chapter-\(number)"], in: app)
        let expected = samples(for: .web).first { $0.code == code && $0.chapter == number }?.bookName
            ?? (code == "JHN" ? "John" : "Psalms")
        waitForLabel(app.buttons["reader-title"], equals: "\(expected) \(number)")
    }

    private func tapIfNotSelected(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing Settings control: \(element.identifier)")
        if (element.value as? String) != "Selected" {
            tapWhenReady(element, in: app)
        }
    }

    private func selectVerse(_ number: Int, expectedSummary: String, reference: String,
                             in app: XCUIApplication) {
        tapVerse(number, in: app)
        assertSelection(summary: expectedSummary, reference: reference, in: app)
    }

    private func tapVerse(_ number: Int, in app: XCUIApplication) {
        let verse = app.buttons["reader-verse-\(number)"]
        scrollToVisible(verse, in: app)
        XCTAssertTrue(verse.isHittable, "Verse \(number) must be visible before selection")
        verse.tap()
    }

    private func assertSelection(summary: String, reference: String, in app: XCUIApplication) {
        waitForLabel(app.staticTexts["reader-selection-summary"], equals: summary)
        waitForLabel(app.staticTexts["reader-selection-reference"], equals: reference)
    }

    private func scrollToVisible(_ element: XCUIElement, in app: XCUIApplication,
                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing visible target: \(element.identifier)", file: file, line: line)
        for _ in 0..<12 where !element.isHittable {
            let viewport = visibleViewport(for: element, in: app)
            XCTAssertGreaterThan(viewport.height, 120, "No safe visible scroll area", file: file, line: line)
            let above = element.frame.midY < viewport.midY
            let startFraction: CGFloat = above ? 0.25 : 0.75
            let endFraction: CGFloat = above ? 0.75 : 0.25
            let start = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * startFraction)
            let end = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * endFraction)
            NSLog("READER_PARITY_SCROLL id=%@ viewport=%@ target=%@ start=%@ end=%@",
                  element.identifier, String(describing: viewport), String(describing: element.frame),
                  String(describing: start), String(describing: end))
            app.coordinate(withNormalizedOffset: normalized(start, in: app))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: normalized(end, in: app)))
        }
        XCTAssertTrue(element.isHittable, "Target must be visible and hittable", file: file, line: line)
    }

    private func tapWhenReady(_ element: XCUIElement, in app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        scrollToVisible(element, in: app, file: file, line: line)
        element.tap()
    }

    private func visibleViewport(for element: XCUIElement, in app: XCUIApplication) -> CGRect {
        let chapterScroll = app.scrollViews["reader-chapter-scroll"]
        let scroll = chapterScroll.exists ? chapterScroll :
            app.scrollViews.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
                .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
        var viewport = (scroll?.frame ?? app.frame).intersection(app.frame)
        if chapterScroll.exists {
            let title = app.buttons["reader-title"]
            if title.exists { viewport.origin.y = max(viewport.minY, title.frame.maxY + 8) }
        }
        let tabs = ["tab-today", "tab-read", "tab-pray", "tab-saved", "tab-settings"]
            .map { app.buttons[$0] }
            .filter { $0.exists && $0.frame.intersects(viewport) }
        if let top = tabs.map(\.frame.minY).min() {
            viewport.size.height = min(viewport.height, top - viewport.minY)
        }
        return viewport
    }

    private func normalized(_ point: CGPoint, in app: XCUIApplication) -> CGVector {
        CGVector(dx: point.x / app.frame.width, dy: point.y / app.frame.height)
    }

    private func waitForLabel(_ element: XCUIElement, equals value: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed,
                       "Expected label: \(value), observed: \(element.label)", file: file, line: line)
    }

    private func waitForValue(_ element: XCUIElement, equals value: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed,
                       "Expected committed value: \(value), observed: \(String(describing: element.value))",
                       file: file, line: line)
    }

    private func attachScreenshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func samples(for edition: Edition) -> [BibleCase] {
        BibleCase.all.filter { $0.edition == edition }
    }

    private enum Edition: String, CaseIterable, Equatable {
        case web = "web-ce"
        case douayRheims = "douay-rheims"
        case vulgate

        var id: String { rawValue }
        var fullName: String {
            switch self {
            case .web: "World English Bible — Catholic Edition"
            case .douayRheims: "Douay–Rheims 1899 American Edition"
            case .vulgate: "Clementine Vulgate 1598 — Latin"
            }
        }
        var abbreviation: String {
            switch self { case .web: "WEB-CE"; case .douayRheims: "DRB"; case .vulgate: "VUL" }
        }
        var attribution: String {
            switch self {
            case .web: "Scripture quotations are from the World English Bible (Catholic Edition), which is in the public domain."
            case .douayRheims: "Scripture quotations are from the public-domain Douay–Rheims American Edition of 1899."
            case .vulgate: "Scripture text is from the public-domain Clementine Vulgate of 1598 in Latin."
            }
        }
    }

    private struct BibleCase {
        let edition: Edition
        let code: String
        let bookName: String
        let chapter: Int
        let firstVerseNumber: Int
        let lastVerseNumber: Int
        let firstVerseText: String
        let lastVerseText: String

        var key: String { "\(edition.id)-\(code)-\(chapter)" }

        static let all: [BibleCase] = [
            .init(edition: .web, code: "JHN", bookName: "John", chapter: 1, firstVerseNumber: 1, lastVerseNumber: 51,
                  firstVerseText: "In the beginning was the Word, and the Word was with God, and the Word was God.",
                  lastVerseText: "He said to him, “Most certainly, I tell you all, hereafter you will see heaven opened, and the angels of God ascending and descending on the Son of Man.”"),
            .init(edition: .web, code: "PSA", bookName: "Psalms", chapter: 23, firstVerseNumber: 1, lastVerseNumber: 6,
                  firstVerseText: "The LORD is my shepherd; I shall lack nothing.",
                  lastVerseText: "Surely goodness and loving kindness shall follow me all the days of my life, and I will dwell in the LORD’s house forever."),
            .init(edition: .web, code: "SNG", bookName: "Song of Solomon", chapter: 1, firstVerseNumber: 1, lastVerseNumber: 17,
                  firstVerseText: "The Song of songs, which is Solomon’s.",
                  lastVerseText: "The beams of our house are cedars. Our rafters are firs."),
            .init(edition: .douayRheims, code: "JHN", bookName: "John", chapter: 1, firstVerseNumber: 1, lastVerseNumber: 51,
                  firstVerseText: "In the beginning was the Word, and the Word was with God, and the Word was God.",
                  lastVerseText: "And he saith to him: Amen, amen I say to you, you shall see the heaven opened, and the angels of God ascending and descending upon the Son of man."),
            .init(edition: .douayRheims, code: "PSA", bookName: "Psalms", chapter: 23, firstVerseNumber: 1, lastVerseNumber: 10,
                  firstVerseText: "On the first day of the week, a psalm for David. The earth is the Lord’s and the fulness thereof: the world, and all they that dwell therein.",
                  lastVerseText: "Who is this King of Glory? the Lord of hosts, he is the King of Glory."),
            .init(edition: .douayRheims, code: "SNG", bookName: "Song of Solomon", chapter: 1, firstVerseNumber: 1, lastVerseNumber: 16,
                  firstVerseText: "Let him kiss me with the kiss of his mouth: for thy breasts are better than wine,",
                  lastVerseText: "The beams of our houses are of cedar, our rafters of cypress trees."),
            .init(edition: .vulgate, code: "JHN", bookName: "IOHANNEM", chapter: 1, firstVerseNumber: 1, lastVerseNumber: 51,
                  firstVerseText: "[In principio erat Verbum, et Verbum erat apud Deum, et Deus erat Verbum.",
                  lastVerseText: "Et dicit ei: Amen, amen dico vobis, videbitis cælum apertum, et angelos Dei ascendentes, et descendentes supra Filium hominis."),
            .init(edition: .vulgate, code: "PSA", bookName: "PSALMORUM", chapter: 23, firstVerseNumber: 1, lastVerseNumber: 10,
                  firstVerseText: "Prima sabbati. Psalmus David. [Domini est terra, et plenitudo ejus; orbis terrarum, et universi qui habitant in eo.",
                  lastVerseText: "Quis est iste rex gloriæ? Dominus virtutum ipse est rex gloriæ.]"),
            .init(edition: .vulgate, code: "SNG", bookName: "CANTICUM CANTICORUM", chapter: 1, firstVerseNumber: 1, lastVerseNumber: 16,
                  firstVerseText: "[Sponsa Osculetur me osculo oris sui; quia meliora sunt ubera tua vino,",
                  lastVerseText: "Tigna domorum nostrarum cedrina, laquearia nostra cypressina.]"),
        ]
    }

    private enum CaptureVariant: String {
        case baseline
        case native

        static var current: CaptureVariant {
            CaptureVariant(rawValue: ProcessInfo.processInfo.environment["READER_PARITY_VARIANT"] ?? "native") ?? .native
        }
    }

    private struct CaptureProfileObservation {
        let requested: String
        let verified: String
        let appearancePreference: String
    }

    @MainActor
    private enum CaptureMetadata {
        static func value(_ key: String) -> String {
            ProcessInfo.processInfo.environment[key] ?? "unprovided"
        }

        static func selectionValue(_ element: XCUIElement) -> String {
            if element.isSelected { return "selected" }
            if let value = element.value { return String(describing: value) }
            return "unresolved"
        }
    }
}
