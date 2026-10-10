import XCTest

/// Source-backed Reader checks. Main owns target membership, fresh task-only seeds, and simulator runs.
@MainActor
final class ReaderParityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBaselineNavigationControlsReconnaissance() throws {
        let bundleID = CaptureMetadata.value("READER_PARITY_BASELINE_BUNDLE_ID")
        guard bundleID != "unprovided" else {
            throw XCTSkip("Skipped: this test needs READER_PARITY_BASELINE_BUNDLE_ID (the installed baseline app). See native/reviews/test-runbook.md.")
        }

        let app = XCUIApplication(bundleIdentifier: bundleID)
        app.launch()
        baselineSnapshot("baseline-app-launch", app: app)
        let initialReadTab = baselineTab("Read", in: app)
        XCTAssertTrue(initialReadTab.waitForExistence(timeout: 10), "Baseline must expose its observed Read tab")
        initialReadTab.tap()
        let bookListTitle = app.staticTexts.matching(NSPredicate(format: "label == %@", "Read the Bible")).firstMatch
        let chapterBack = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Back to ")).firstMatch
        XCTAssertTrue(bookListTitle.waitForExistence(timeout: 8) || chapterBack.waitForExistence(timeout: 8),
                      "Baseline Read must start at its book list or a chapter")
        baselineSnapshot("baseline-reader-start", app: app)

        let clearSelection = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Clear passage selection")
        ).firstMatch
        if clearSelection.exists {
            XCTAssertTrue(clearSelection.isHittable, "Visible selection control must be hittable")
            clearSelection.tap()
            baselineSnapshot("baseline-reader-selection-closed", app: app)
        } else {
            NSLog("BASELINE_RECON selectionControl=absent; gold verse fill is not treated as active selection")
        }

        let settingsTab = baselineTab("Settings", in: app)
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10), "Baseline must expose its observed Settings tab")
        settingsTab.tap()
        baselineSnapshot("baseline-settings-top", app: app)
        logBaselineChoiceControls(app)

        for index in 1...3 {
            guard let viewport = largestVisibleScrollViewport(in: app) else {
                NSLog("BASELINE_RECON settingsScroll=%d unavailable=no-visible-scroll-viewport", index)
                break
            }
            let before = app.debugDescription
            boundedScroll(in: viewport, direction: .up, app: app)
            let after = app.debugDescription
            baselineSnapshot("baseline-settings-scroll-\(index)", app: app)
            logBaselineChoiceControls(app)
            if before == after { break }
        }

        let readTab = baselineTab("Read", in: app)
        XCTAssertTrue(readTab.waitForExistence(timeout: 10), "Baseline must expose its observed Read tab")
        readTab.tap()
        baselineSnapshot("baseline-return-read", app: app)

        let clearAfterReturn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Clear passage selection")
        ).firstMatch
        if clearAfterReturn.exists {
            XCTAssertTrue(clearAfterReturn.isHittable)
            clearAfterReturn.tap()
            baselineSnapshot("baseline-return-read-selection-closed", app: app)
        }

        let bookList = app.staticTexts.matching(NSPredicate(format: "label == %@", "Read the Bible")).firstMatch
        for index in 1...3 where !bookList.exists {
            let back = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Back to ")).firstMatch
            guard back.waitForExistence(timeout: 6), back.isHittable else {
                NSLog("BASELINE_RECON back=%d unavailable=visible-back-control-not-found", index)
                break
            }
            NSLog("BASELINE_RECON back=%d role=Button label=%@ value=%@ selected=%d",
                  index, back.label, String(describing: back.value), back.isSelected ? 1 : 0)
            back.tap()
            baselineSnapshot("baseline-back-\(index)", app: app)
        }
        if bookList.exists {
            baselineSnapshot("baseline-book-list", app: app)
        } else {
            NSLog("BASELINE_RECON bookList=unresolved afterAtMost3BackActions")
        }
    }

    func testBibleRepositoryCasesAcrossEditions() throws {
        let variant = CaptureVariant.current
        let baselineNavigation = ProcessInfo.processInfo.environment["READER_PARITY_BASELINE_NAVIGATION"] ?? "book-list"
        if variant == .baseline && baselineNavigation != "book-list" && baselineNavigation != "public-url" {
            XCTFail("Unsupported READER_PARITY_BASELINE_NAVIGATION: \(baselineNavigation). Use book-list or public-url.")
            return
        }
        let usePublicBaselineURL = variant == .baseline && baselineNavigation == "public-url"
        let allSamples = Edition.allCases.flatMap { samples(for: $0) }
        let topOnly = ProcessInfo.processInfo.environment["READER_PARITY_TOP_ONLY"] == "1"
        // READER_PARITY_CASE accepts one exact key or a comma-separated list. The list order is the run order.
        let caseValue = CaptureMetadata.value("READER_PARITY_CASE")
        if topOnly && caseValue == "unprovided" {
            XCTFail("READER_PARITY_TOP_ONLY=1 requires an explicit READER_PARITY_CASE so this partial capture has a clear scope")
            return
        }
        let selectedSamples: [BibleCase]
        if caseValue == "unprovided" {
            selectedSamples = allSamples
        } else {
            var chosen: [BibleCase] = []
            for rawKey in caseValue.split(separator: ",") {
                let caseKey = rawKey.trimmingCharacters(in: .whitespaces)
                guard let sample = allSamples.first(where: { $0.key == caseKey }) else {
                    XCTFail("Unknown Reader parity case: \(caseKey)")
                    return
                }
                if !chosen.contains(where: { $0.key == sample.key }) { chosen.append(sample) }
            }
            guard !chosen.isEmpty else {
                XCTFail("READER_PARITY_CASE has no case key")
                return
            }
            selectedSamples = chosen
        }
        if topOnly {
            NSLog("READER_PARITY_MODE coverage=top-only-partial selectedCases=%@ endText=skipped footerAttribution=skipped",
                  selectedSamples.map(\.key).joined(separator: ","))
        } else {
            NSLog("READER_PARITY_MODE coverage=full selectedCases=%@",
                  selectedSamples.map(\.key).joined(separator: ","))
        }
        guard let textSize = requestedTextSize() else {
            XCTFail("Unsupported READER_PARITY_TEXT_SIZE: \(CaptureMetadata.value("READER_PARITY_TEXT_SIZE")). Use Default or Extra large.")
            return
        }
        let app = launch(variant: variant)

        for (sampleIndex, sample) in selectedSamples.enumerated() {
            let profile = applyCaptureProfile(edition: sample.edition, textSize: textSize, in: app, variant: variant)
            if usePublicBaselineURL {
                let contextRequest = String(Int(Date().timeIntervalSince1970 * 1_000) + sampleIndex)
                var components = URLComponents()
                components.scheme = "nrsv"
                components.host = "read"
                components.queryItems = [
                    URLQueryItem(name: "book", value: sample.code),
                    URLQueryItem(name: "chapter", value: String(sample.chapter)),
                    URLQueryItem(name: "verse", value: String(sample.firstVerseNumber)),
                    URLQueryItem(name: "contextRequest", value: contextRequest),
                ]
                guard let url = components.url else {
                    XCTFail("Could not construct the public Reader URL for \(sample.key)")
                    return
                }
                NSLog("READER_PARITY_BASELINE_NAVIGATION path=public-url excludesBookList=1 case=%@ url=%@",
                      sample.key, url.absoluteString)
                app.open(url)
            } else {
                if variant == .baseline {
                    NSLog("READER_PARITY_BASELINE_NAVIGATION path=book-list excludesBookList=0 case=%@", sample.key)
                }
                openCaptureBookList(in: app, variant: variant)
                let book = captureBookControl(sample, in: app, variant: variant)
                tapWhenReady(book, in: app)

                let chapter = captureChapterControl(sample, in: app, variant: variant)
                tapWhenReady(chapter, in: app)
            }
            let title = captureTitleControl(sample, in: app, variant: variant)
            waitForLabel(title, equals: "\(sample.bookName) \(sample.chapter)")

            let attribution = captureAttributionControl(sample.edition, in: app, variant: variant)
            if variant == .native {
                assertNativeFirstVerseAtTop(sample, in: app)
            } else {
                // The old app splits a poetry verse across line labels. One label does not hold the full verse.
                let firstSpan = requireBaselineVerseSpan(sample.firstVerseText, in: app, key: sample.key, role: "first")
                XCTAssertTrue(firstSpan.head.isHittable, "Baseline chapter top \(sample.key)")
                XCTAssertTrue(firstSpan.normalizedText.contains(normalizedCaptureText(sample.firstVerseText)),
                              "First verse differs from source: \(sample.key)")
            }
            attachScreenshot("reader-parity-\(variant.rawValue)-\(sample.key)-top", app: app)
            attachAXTreeIfRequested("reader-parity-\(variant.rawValue)-\(sample.key)-top", app: app)

            if topOnly {
                NSLog("READER_PARITY_PARTIAL case=%@ coverage=top-only-partial title=passed firstVerse=passed endText=skipped footerAttribution=skipped",
                      sample.key)
                continue
            }

            if variant == .native {
                let lastVerse = captureVerseControl(sample.lastVerseNumber, text: sample.lastVerseText,
                                                    in: app, variant: variant)
                scrollToLastVerseTail(lastVerse, in: app, key: sample.key)
                XCTAssertTrue(lastVerse.label.contains(sample.lastVerseText), "Last verse differs from source: \(sample.key)")
            } else {
                let lastSpan = scrollBaselineVerseTail(sample.lastVerseText, in: app, key: sample.key)
                XCTAssertTrue(lastSpan.normalizedText.contains(normalizedCaptureText(sample.lastVerseText)),
                              "Last verse differs from source: \(sample.key)")
            }
            attachScreenshot("reader-parity-\(variant.rawValue)-\(sample.key)-end-text", app: app)
            attachAXTreeIfRequested("reader-parity-\(variant.rawValue)-\(sample.key)-end-text", app: app)

            scrollToAttribution(attribution, in: app, key: sample.key)
            waitForLabel(attribution, equals: sample.edition.attribution)
            attachScreenshot("reader-parity-\(variant.rawValue)-\(sample.key)-end-footer", app: app)
            attachAXTreeIfRequested("reader-parity-\(variant.rawValue)-\(sample.key)-end-footer", app: app)
            NSLog("READER_PARITY case=%@ coverage=full variant=%@ edition=%@ book=%@ chapter=%d first=%d last=%d attribution=%@ requestedProfile=%@ verifiedProfile=%@ appearancePreference=%@ effectiveAppearance=%@ appVersion=%@ device=%@ seed=%@",
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
        XCTAssertEqual(app.frame.width, 402, "Observed word points apply only to the verified 402pt phone profile")
        openChapter("JHN", number: 1, in: app)

        selectVerse(10, expectedSummary: "Selected: verses 10–10", reference: "John 1:10", in: app)
        selectVerse(12, expectedSummary: "Selected: verses 10–12", reference: "John 1:10–12", in: app)
        selectVerse(8, expectedSummary: "Selected: verses 8–10", reference: "John 1:8–10", in: app)
        selectVerse(11, expectedSummary: "Selected: verses 8–11", reference: "John 1:8–11", in: app)
        attachAXTree("reader-parity-selected-range-8-11", app: app)

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
        NSLog("READER_PARITY verseLayoutRange=10,10-12,8-10,8-11 repeatedRange=kept singleton=cleared")
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
        // Native only: keep the full tab bar (no Read-tab minimize). Never for the old app (Liquid-glass-tabview-review.md fix 2).
        if variant == .native { app.launchArguments += ["-JohnTabBarMinimize", "never"] }
        app.launch()
        if variant == .native {
            XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))
        } else {
            let readTab = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Read, tab")).firstMatch
            XCTAssertTrue(readTab.waitForExistence(timeout: 12), "Baseline must expose its Read tab")
            readTab.tap()
            let bookList = app.staticTexts.matching(NSPredicate(format: "label == %@", "Read the Bible")).firstMatch
            let back = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Back to ")).firstMatch
            XCTAssertTrue(bookList.waitForExistence(timeout: 8) || back.waitForExistence(timeout: 8),
                          "Baseline Read must open at its book list or a restored chapter")
        }
        return app
    }

    private func applyProfile(edition: Edition, layout: String, textSize: String = "Default",
                              in app: XCUIApplication) -> String {
        tabButton(app, "tab-settings").tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 8))
        for (identifier, selectedValue) in [
            ("settings-text-size-\(textSize.lowercased().replacingOccurrences(of: " ", with: "-"))", "Text size, \(textSize)"),
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
        waitForTranslationCommit(translation, in: app)
        let observedAppearance = ["system", "light", "dark"].first { name in
            (app.buttons["settings-appearance-\(name)"].value as? String) == "Selected"
        } ?? "unresolved"
        XCTAssertNotEqual(observedAppearance, "unresolved", "The Settings screen must expose the current appearance")
        NSLog("READER_PARITY_PROFILE size=%@ spacing=Comfortable typeface=Serif layout=%@ edition=%@ appearancePreference=%@",
              textSizeName(textSize), layout, edition.id, observedAppearance)
        tabButton(app, "tab-read").tap()
        return observedAppearance
    }

    private func applyCaptureProfile(edition: Edition, textSize: String, in app: XCUIApplication,
                                     variant: CaptureVariant) -> CaptureProfileObservation {
        let sizeName = textSizeName(textSize)
        if variant == .native {
            let appearance = applyProfile(edition: edition, layout: "Paragraphs", textSize: textSize, in: app)
            return CaptureProfileObservation(requested: "\(sizeName)/Comfortable/Serif/Paragraphs/\(edition.id)",
                                             verified: "\(sizeName)/Comfortable/Serif/Paragraphs/\(edition.id)",
                                             appearancePreference: appearance)
        }

        let settingsTab = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Settings, tab")).firstMatch
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 8), "Baseline must expose Settings")
        settingsTab.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8))
        let requestedChoices = [
            "Text size, \(textSize)", "Line spacing, Comfortable",
            "Scripture typeface, Serif", "Layout, Paragraphs", edition.fullName,
        ]
        var observedChoices: [String] = []
        for label in requestedChoices {
            let choice = app.otherElements.matching(NSPredicate(format: "label == %@", label)).firstMatch
            XCTAssertTrue(choice.waitForExistence(timeout: 8), "Baseline is missing source control: \(label)")
            let current = baselineRadioValue(choice)
            XCTAssertNotNil(current, "Baseline control must report a radio checked state: \(label)")
            if current == "radio button, unchecked" {
                tapWhenReady(choice, in: app)
                waitForValue(choice, equals: "radio button, checked")
            }
            XCTAssertEqual(baselineRadioValue(choice), "radio button, checked",
                           "Baseline choice must be checked after selection: \(label)")
            observedChoices.append("\(label)=radio button, checked")
        }
        let appearanceOptions = ["System", "Light", "Dark"].map { mode in
            app.otherElements.matching(NSPredicate(format: "label == %@", "Appearance, \(mode)")).firstMatch
        }
        let selectedAppearance = appearanceOptions.first { baselineRadioValue($0) == "radio button, checked" }
        XCTAssertNotNil(selectedAppearance, "Baseline must expose one checked appearance choice")
        let appearancePreference = selectedAppearance?.label.replacingOccurrences(of: "Appearance, ", with: "") ?? "unresolved"
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Read, tab")).firstMatch.tap()
        return CaptureProfileObservation(
            requested: "\(sizeName)/Comfortable/Serif/Paragraphs/\(edition.id)",
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
        let book = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(sample.bookName), ")).firstMatch
        scrollBaselineBookIntoView(book, key: sample.key, in: app)
        return book
    }

    /// The baseline Reader keeps the selected tab's prior list offset. At large text sizes,
    /// the book-list title can exist far above the viewport while later sections are visible.
    /// Drag only inside the visible Read content until the exact requested book row appears.
    private func scrollBaselineBookIntoView(_ book: XCUIElement, key: String, in app: XCUIApplication,
                                            file: StaticString = #filePath, line: UInt = #line) {
        let title = app.staticTexts.matching(NSPredicate(format: "label == %@", "Read the Bible")).firstMatch
        guard title.exists else {
            XCTFail("Baseline book list is not open for \(key)", file: file, line: line)
            return
        }

        let statusBar = app.statusBars.firstMatch
        let topInset = statusBar.exists && statusBar.frame.height > 0
            ? statusBar.frame.maxY + 8 : app.frame.minY + 64
        var viewport = app.frame.intersection(CGRect(x: app.frame.minX, y: topInset,
                                                       width: app.frame.width, height: app.frame.maxY - topInset))
        let tabs = ["Today", "Read", "Saved", "Pray", "Settings"]
            .map { baselineTab($0, in: app) }
            .filter { $0.exists && $0.frame.intersects(app.frame) }
        if let tabTop = tabs.map(\.frame.minY).min() {
            viewport.size.height = min(viewport.height, tabTop - 8 - viewport.minY)
        }
        viewport = viewport.insetBy(dx: 8, dy: 4)
        NSLog("BASELINE_BOOK_VIEWPORT key=%@ app=%@ statusBar=%@ viewport=%@ tabTop=%@",
              key, NSCoder.string(for: app.frame), statusBar.exists ? NSCoder.string(for: statusBar.frame) : "unavailable",
              NSCoder.string(for: viewport), tabs.map { NSCoder.string(for: $0.frame) }.joined(separator: ";"))
        guard viewport.height > 120 else {
            baselineSnapshot("baseline-book-\(key)-unsafe-viewport", app: app)
            XCTFail("Baseline Reader has no safe visible content area for \(key): \(NSCoder.string(for: viewport))",
                    file: file, line: line)
            return
        }

        let continueLabel = app.staticTexts.matching(NSPredicate(format: "label == %@", "Continue reading")).firstMatch
        let progressAnchor = continueLabel.exists ? continueLabel : title
        let anchorPosition: () -> String = {
            guard progressAnchor.exists else { return "absent" }
            return String(describing: progressAnchor.frame.minY)
        }
        let visibleContentSignature: () -> String = {
            app.staticTexts.allElementsBoundByIndex
                .filter { $0.exists && !$0.label.isEmpty && $0.frame.intersects(viewport) }
                .map { "\($0.label):\(Int($0.frame.minY.rounded()))" }
                .joined(separator: "|")
        }
        var previousProgress = book.exists
            ? String(describing: book.frame.minY) : visibleContentSignature() + "|anchor:\(anchorPosition())"
        var stalledAttempts = 0
        for attempt in 0..<120 {
            if book.exists && book.isHittable && book.frame.intersects(viewport) {
                NSLog("BASELINE_BOOK_VISIBLE key=%@ attempt=%d frame=%@ viewport=%@",
                      key, attempt, NSCoder.string(for: book.frame), NSCoder.string(for: viewport))
                return
            }
            // An absent row is a lazy baseline list item. The visible heading shows list movement.
            // When the exact row exists, use its frame to choose the direction directly.
            let dragDown = book.exists && book.frame.midY < viewport.midY
            let startFraction: CGFloat = dragDown ? 0.20 : 0.85
            let endFraction: CGFloat = dragDown ? 0.85 : 0.20
            let start = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * startFraction)
            let end = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * endFraction)
            app.coordinate(withNormalizedOffset: normalized(start, in: app))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: normalized(end, in: app)))

            let currentProgress = book.exists
                ? String(describing: book.frame.minY) : visibleContentSignature() + "|anchor:\(anchorPosition())"
            stalledAttempts = currentProgress == previousProgress ? stalledAttempts + 1 : 0
            NSLog("BASELINE_BOOK_SCROLL key=%@ attempt=%d exists=%d hittable=%d frame=%@ viewport=%@ stalled=%d",
                  key, attempt, book.exists ? 1 : 0, book.isHittable ? 1 : 0,
                  NSCoder.string(for: book.exists ? book.frame : (progressAnchor.exists ? progressAnchor.frame : .zero)),
                  NSCoder.string(for: viewport), stalledAttempts)
            previousProgress = currentProgress
            if stalledAttempts >= 3 { break }
        }

        baselineSnapshot("baseline-book-\(key)-scroll-failure", app: app)
        let finalBookFrame = book.exists ? NSCoder.string(for: book.frame) : "absent"
        XCTFail("Baseline book row did not become visible: key=\(key) exists=\(book.exists) hittable=\(book.isHittable) frame=\(finalBookFrame) viewport=\(NSCoder.string(for: viewport)) stalls=\(stalledAttempts)",
                file: file, line: line)
    }

    private func captureChapterControl(_ sample: BibleCase, in app: XCUIApplication,
                                       variant: CaptureVariant) -> XCUIElement {
        if variant == .native {
            let chapter = app.buttons["reader-chapter-\(sample.chapter)"]
            scrollNativeChapterGridTargetIntoView(chapter, sample: sample, app: app)
            return chapter
        }
        return app.buttons.matching(NSPredicate(format: "label == %@", "\(sample.bookName) chapter \(sample.chapter)")).firstMatch
    }

    /// The native chapter grid uses lazy cells. A distant chapter can be absent from accessibility
    /// until the grid scrolls near it. Keep this gesture inside that grid and stop on no progress.
    private func scrollNativeChapterGridTargetIntoView(_ target: XCUIElement, sample: BibleCase,
                                                       app: XCUIApplication) {
        let scroll = app.scrollViews["reader-chapter-grid-scroll"]
        guard scroll.waitForExistence(timeout: 8), scroll.exists, scroll.isHittable else {
            NSLog("READER_PARITY_CHAPTER_REACH case=%@ result=failed reason=grid-unavailable", sample.key)
            attachScreenshot("reader-parity-chapter-reach-failure-\(sample.key)", app: app)
            attachAXTree("reader-parity-chapter-reach-failure-\(sample.key)", app: app)
            XCTFail("Native chapter grid missing or not hittable for \(sample.key)")
            return
        }

        var previousSignature = ""
        var stalledAttempts = 0
        var finalViewport = CGRect.zero
        for attempt in 0..<40 {
            var viewport = scroll.frame.intersection(app.frame)
            let topOverlays = [app.statusBars.firstMatch] + app.navigationBars.allElementsBoundByIndex
            let topOcclusion = topOverlays
                .filter { $0.exists && $0.frame.height > 0 && $0.frame.intersects(viewport) }
                .map(\.frame.maxY)
                .max()
            if let topOcclusion = topOcclusion {
                let bottom = viewport.maxY
                viewport.origin.y = max(viewport.minY, topOcclusion + 4)
                viewport.size.height = max(0, bottom - viewport.minY)
            }
            if let tabTop = tabBarTopEdge(in: app, within: viewport) {
                viewport.size.height = min(viewport.height, tabTop - viewport.minY)
            }
            viewport = viewport.insetBy(dx: 4, dy: 4)
            finalViewport = viewport
            let targetFrame = target.exists ? target.frame : .zero
            if target.exists && !targetFrame.isEmpty && viewport.contains(targetFrame)
                && viewport.contains(CGPoint(x: targetFrame.midX, y: targetFrame.midY)) && target.isHittable {
                NSLog("READER_PARITY_CHAPTER_REACH case=%@ attempt=%d result=visible frame=%@ viewport=%@",
                      sample.key, attempt, NSCoder.string(for: targetFrame), NSCoder.string(for: viewport))
                attachScreenshot("reader-parity-chapter-reach-\(sample.key)", app: app)
                attachAXTreeIfRequested("reader-parity-chapter-reach-\(sample.key)", app: app)
                return
            }
            guard viewport.height > 100 else {
                NSLog("READER_PARITY_CHAPTER_REACH case=%@ result=failed reason=unsafe-viewport viewport=%@",
                      sample.key, NSCoder.string(for: viewport))
                attachScreenshot("reader-parity-chapter-reach-failure-\(sample.key)", app: app)
                attachAXTree("reader-parity-chapter-reach-failure-\(sample.key)", app: app)
                XCTFail("No safe chapter-grid viewport for \(sample.key): \(viewport)")
                return
            }

            let scrollDown = target.exists && !targetFrame.isEmpty && targetFrame.minY < viewport.minY
            let startFraction: CGFloat = scrollDown ? 0.25 : 0.75
            let endFraction: CGFloat = scrollDown ? 0.75 : 0.25
            let start = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * startFraction)
            let end = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * endFraction)
            NSLog("READER_PARITY_CHAPTER_REACH case=%@ attempt=%d targetExists=%d frame=%@ viewport=%@ direction=%@",
                  sample.key, attempt, target.exists ? 1 : 0, NSCoder.string(for: targetFrame),
                  NSCoder.string(for: viewport), scrollDown ? "down" : "up")
            app.coordinate(withNormalizedOffset: normalized(start, in: app))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: normalized(end, in: app)))
            XCTAssertTrue(scroll.exists && scroll.isHittable,
                          "Native chapter grid left the foreground for \(sample.key)")

            let visibleCells = app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "reader-chapter-")
            ).allElementsBoundByIndex
            let signature = visibleCells.map {
                "\($0.identifier):\(Int($0.frame.minY))"
            }.joined(separator: "|")
            stalledAttempts = signature == previousSignature ? stalledAttempts + 1 : 0
            previousSignature = signature
            NSLog("READER_PARITY_CHAPTER_REACH_PROGRESS case=%@ attempt=%d cells=%d stalled=%d",
                  sample.key, attempt, visibleCells.count, stalledAttempts)
            if stalledAttempts >= 4 { break }
        }

        let finalTargetFrame = target.exists ? target.frame : .zero
        let reached = target.exists && !finalTargetFrame.isEmpty && finalViewport.contains(finalTargetFrame)
            && finalViewport.contains(CGPoint(x: finalTargetFrame.midX, y: finalTargetFrame.midY))
            && target.isHittable
        guard reached else {
            NSLog("READER_PARITY_CHAPTER_REACH case=%@ result=failed exists=%d hittable=%d frame=%@ viewport=%@ stalls=%d",
                  sample.key, target.exists ? 1 : 0, target.isHittable ? 1 : 0,
                  NSCoder.string(for: finalTargetFrame), NSCoder.string(for: finalViewport), stalledAttempts)
            attachScreenshot("reader-parity-chapter-reach-failure-\(sample.key)", app: app)
            attachAXTree("reader-parity-chapter-reach-failure-\(sample.key)", app: app)
            XCTFail("Chapter did not become fully visible and hittable in the bounded native grid scroll: \(sample.key)")
            return
        }
    }

    private func captureTitleControl(_ sample: BibleCase, in app: XCUIApplication,
                                    variant: CaptureVariant) -> XCUIElement {
        if variant == .native { return app.buttons["reader-title"] }
        return app.buttons.matching(NSPredicate(format: "label == %@", "\(sample.bookName) \(sample.chapter)")).firstMatch
    }

    /// The chapter header and verse 1 must both sit under the status bar.
    /// A carried scroll offset can leave a short chapter's verse hittable while the header has left the screen.
    /// The source text keeps a stale `reader-verse-1` from the previous chapter from passing this check.
    private func assertNativeFirstVerseAtTop(_ sample: BibleCase, in app: XCUIApplication,
                                             file: StaticString = #filePath, line: UInt = #line) {
        let verse = app.buttons.matching(NSPredicate(
            format: "identifier == %@ AND label CONTAINS %@",
            "reader-verse-\(sample.firstVerseNumber)", sample.firstVerseText
        )).firstMatch
        NSLog("READER_PARITY_TOP_ENTER case=%@", sample.key)
        XCTAssertTrue(verse.waitForExistence(timeout: 10), "Missing native first verse: \(sample.key)", file: file, line: line)
        let title = app.buttons["reader-title"]
        let scroll = app.scrollViews["reader-chapter-scroll"]
        if sample.key == "web-ce-PSA-23" {
            let heading = app.descendants(matching: .any).matching(identifier: "reader-heading-d").firstMatch
            let headingExists = heading.waitForExistence(timeout: 10)
            let safeTop = CGFloat(Double(scroll.value as? String ?? "") ?? 0)
            let deadline = Date().addingTimeInterval(3)
            var titleFrame = CGRect.null
            var headingFrame = CGRect.null
            var verseFrame = CGRect.null
            var exactHeading = false
            var titleVisible = false
            var headingAtTop = false
            var verseFollowsHeading = false
            var sourceVerseMatches = false
            var settled = false
            while headingExists && Date() < deadline {
                titleFrame = title.frame
                headingFrame = heading.frame
                verseFrame = verse.frame
                exactHeading = heading.label == "A Psalm by David."
                titleVisible = title.exists && titleFrame.minY >= safeTop - 24 && titleFrame.maxY > safeTop
                headingAtTop = exactHeading && headingFrame.height > 1
                    && headingFrame.minY >= titleFrame.maxY - 16
                    && headingFrame.minY <= titleFrame.maxY + 96
                    && headingFrame.maxY > titleFrame.maxY
                verseFollowsHeading = verseFrame.height > 1
                    && verseFrame.minY >= headingFrame.maxY
                    && verseFrame.minY <= headingFrame.maxY + 96
                sourceVerseMatches = verse.label.contains(sample.firstVerseText)
                settled = titleVisible && headingAtTop && verseFollowsHeading && sourceVerseMatches
                    && verse.isHittable
                if settled { break }
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
            let detail = "heading=\(NSCoder.string(for: headingFrame)) title=\(NSCoder.string(for: titleFrame)) verse=\(NSCoder.string(for: verseFrame)) safeTop=\(safeTop) exactHeading=\(exactHeading) hittable=\(verse.isHittable) sourceVerseMatches=\(sourceVerseMatches)"
            NSLog("READER_PARITY_TOP case=%@ firstContent=source-heading %@", sample.key, detail)
            guard settled else {
                attachScreenshot("reader-parity-native-\(sample.key)-top-failure", app: app)
                attachAXTree("reader-parity-native-\(sample.key)-top-failure", app: app)
                XCTFail("Native chapter top with source heading \(sample.key) \(detail)", file: file, line: line)
                return
            }
            return
        }
        let deadline = Date().addingTimeInterval(3)
        var atTop = false
        var lastFrame = CGRect.null
        var titleFrame = CGRect.null
        var safeTop: CGFloat = 0
        while Date() < deadline {
            lastFrame = verse.frame
            titleFrame = title.frame
            safeTop = CGFloat(Double(scroll.value as? String ?? "") ?? 0)
            let headerVisible = title.exists && titleFrame.minY >= safeTop - 24 && titleFrame.maxY > safeTop
            let underHeader = lastFrame.height > 1
                && lastFrame.minY >= titleFrame.maxY - 16
                && lastFrame.minY <= titleFrame.maxY + 96
            atTop = headerVisible && underHeader
            if atTop { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        let detail = "frame=\(NSCoder.string(for: lastFrame)) title=\(NSCoder.string(for: titleFrame)) safeTop=\(safeTop) hittable=\(verse.isHittable) label=\(verse.label.prefix(60))"
        NSLog("READER_PARITY_TOP case=%@ %@", sample.key, detail)
        XCTAssertTrue(atTop, "Native chapter top \(sample.key) \(detail)", file: file, line: line)
        XCTAssertTrue(verse.label.contains(sample.firstVerseText), "First verse differs from source: \(sample.key)", file: file, line: line)
    }

    private func captureVerseControl(_ number: Int, text: String, in app: XCUIApplication,
                                     variant: CaptureVariant) -> XCUIElement {
        if variant == .native { return app.buttons["reader-verse-\(number)"] }
        return app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private struct BaselineVerseSpan {
        let head: XCUIElement
        let tail: XCUIElement
        let normalizedText: String
    }

    /// Joins consecutive old-app line labels. A poetry verse is not one StaticText.
    /// The first line must contain the start of the source verse, so a heading cannot open the match.
    private func baselineVerseSpan(_ text: String, in app: XCUIApplication) -> BaselineVerseSpan? {
        let target = normalizedCaptureText(text)
        guard !target.isEmpty else { return nil }
        let prefixCount = min(16, target.count)
        let prefix = String(target.prefix(prefixCount))
        let nodes = baselineTextNodes(in: app)
        let labels = nodes.map { normalizedCaptureText($0.label) }
        for start in labels.indices where labels[start].contains(prefix) {
            var joined = ""
            let endLimit = min(labels.count - 1, start + 11)
            for end in start...endLimit {
                joined = joined.isEmpty ? labels[end] : "\(joined) \(labels[end])"
                if joined.contains(target) {
                    return BaselineVerseSpan(head: nodes[start], tail: nodes[end], normalizedText: joined)
                }
            }
        }
        return nil
    }

    private func requireBaselineVerseSpan(_ text: String, in app: XCUIApplication, key: String, role: String,
                                          file: StaticString = #filePath, line: UInt = #line) -> BaselineVerseSpan {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if let span = baselineVerseSpan(text, in: app) { return span }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        if let span = baselineVerseSpan(text, in: app) { return span }
        XCTFail("Missing \(role) verse: \(key)", file: file, line: line)
        return BaselineVerseSpan(head: app.staticTexts.firstMatch, tail: app.staticTexts.firstMatch, normalizedText: "")
    }

    private func scrollBaselineVerseTail(_ text: String, in app: XCUIApplication, key: String,
                                         file: StaticString = #filePath, line: UInt = #line) -> BaselineVerseSpan {
        var span = requireBaselineVerseSpan(text, in: app, key: key, role: "final", file: file, line: line)
        // One full label scan is enough. Each later scan cost about 30 seconds and made 12 drags miss a long chapter.
        // Douay-Rheims John 1 moved about 350 points per drag and still sat 682 points below the viewport after 11 drags.
        for attempt in 0..<24 {
            let viewport = visibleViewport(for: span.tail, in: app).insetBy(dx: 4, dy: 4)
            let verseFrame = span.tail.frame
            let verseTailVisible = verseFrame.intersects(viewport) && verseFrame.maxY <= viewport.maxY
            NSLog("READER_PARITY_END_TEXT case=%@ attempt=%d viewport=%@ verse=%@ tailVisible=%d",
                  key, attempt, NSCoder.string(for: viewport), NSCoder.string(for: verseFrame), verseTailVisible ? 1 : 0)
            if verseTailVisible { return span }

            XCTAssertGreaterThan(viewport.height, 120, "No safe Reader viewport for final verse tail: \(key)", file: file, line: line)
            let needsScrollDown = verseFrame.maxY < viewport.minY
            let startFraction: CGFloat = needsScrollDown ? 0.25 : 0.75
            let endFraction: CGFloat = needsScrollDown ? 0.75 : 0.25
            let start = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * startFraction)
            let end = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * endFraction)
            app.coordinate(withNormalizedOffset: normalized(start, in: app))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: normalized(end, in: app)))
            let moved = span.tail.frame
            if abs(moved.minY - verseFrame.minY) < 1 {
                span = requireBaselineVerseSpan(text, in: app, key: key, role: "final", file: file, line: line)
            }
        }

        let viewport = visibleViewport(for: span.tail, in: app).insetBy(dx: 4, dy: 4)
        XCTAssertTrue(span.tail.frame.intersects(viewport) && span.tail.frame.maxY <= viewport.maxY,
                      "The final verse tail must be above the tab boundary before capture: \(key)", file: file, line: line)
        return span
    }

    private func baselineTextNodes(in app: XCUIApplication) -> [XCUIElement] {
        var seen = Set<String>()
        var nodes: [XCUIElement] = []
        for element in app.staticTexts.allElementsBoundByIndex where element.exists {
            let label = element.label
            guard !label.isEmpty else { continue }
            let frame = element.frame
            let key = "\(label)|\(Int(frame.minX.rounded()))|\(Int(frame.minY.rounded()))|\(Int(frame.width.rounded()))|\(Int(frame.height.rounded()))"
            if seen.insert(key).inserted {
                nodes.append(element)
            }
        }
        return nodes.sorted { lhs, rhs in
            if abs(lhs.frame.minY - rhs.frame.minY) > 1 { return lhs.frame.minY < rhs.frame.minY }
            return lhs.frame.minX < rhs.frame.minX
        }
    }

    private func normalizedCaptureText(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\u{00A0}", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private func captureAttributionControl(_ edition: Edition, in app: XCUIApplication,
                                          variant: CaptureVariant) -> XCUIElement {
        if variant == .native { return app.staticTexts["reader-edition-attribution"] }
        return app.staticTexts.matching(NSPredicate(format: "label == %@", edition.attribution)).firstMatch
    }

    private func openBookList(in app: XCUIApplication) {
        if app.staticTexts["reader-book-list-title"].exists { return }
        tabButton(app, "tab-read").tap()
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
            if element.identifier.hasPrefix("translation-") {
                scrollToVisible(element, in: app)
                let viewport = visibleViewport(for: element, in: app).insetBy(dx: 4, dy: 4)
                let tapPoint = CGPoint(x: element.frame.midX, y: element.frame.midY)
                let normalizedTapPoint = normalized(tapPoint, in: app)
                guard element.isHittable, viewport.contains(element.frame) else {
                    XCTFail("Translation target is not fully safe to tap: id=\(element.identifier) frame=\(NSCoder.string(for: element.frame)) viewport=\(NSCoder.string(for: viewport))")
                    return
                }
                NSLog("READER_PARITY_TRANSLATION_TAP id=%@ target=%@ viewport=%@ point=%@ normalized=%@",
                      element.identifier, NSCoder.string(for: element.frame), NSCoder.string(for: viewport),
                      String(describing: tapPoint), String(describing: normalizedTapPoint))
                app.coordinate(withNormalizedOffset: normalizedTapPoint).tap()
            } else {
                tapWhenReady(element, in: app)
            }
        }
    }

    private func selectVerse(_ number: Int, expectedSummary: String, reference: String,
                             in app: XCUIApplication) {
        tapVerse(number, in: app)
        assertSelection(summary: expectedSummary, reference: reference, in: app)
    }

    private func tapVerse(_ number: Int, in app: XCUIApplication) {
        let verse = app.buttons["reader-verse-\(number)"]
        let offset: CGPoint
        switch number {
        case 2, 8: offset = CGPoint(x: 20, y: 14)
        case 10, 11, 12: offset = CGPoint(x: 30, y: 14)
        default:
            XCTFail("No observed owned-word point is available for JHN 1:\(number)")
            return
        }
        XCTAssertTrue(verse.waitForExistence(timeout: 10), "Verse \(number) must be present")
        var viewport = visibleViewport(for: verse, in: app)
        var point = CGPoint(x: verse.frame.minX + offset.x, y: verse.frame.minY + offset.y)
        for _ in 0..<12 {
            let safeViewport = viewport.insetBy(dx: 4, dy: 4)
            if verse.isHittable, safeViewport.contains(point) { break }
            XCTAssertGreaterThan(viewport.height, 120, "No safe Reader scroll area for verse \(number)")
            let above = point.y < safeViewport.minY
            let startFraction: CGFloat = above ? 0.25 : 0.75
            let endFraction: CGFloat = above ? 0.75 : 0.25
            let start = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * startFraction)
            let end = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * endFraction)
            NSLog("READER_PARITY_WORD_SCROLL verse=%d frame=%@ point=%@ viewport=%@ start=%@ end=%@",
                  number, NSCoder.string(for: verse.frame), String(describing: point),
                  NSCoder.string(for: viewport), String(describing: start), String(describing: end))
            app.coordinate(withNormalizedOffset: normalized(start, in: app))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: normalized(end, in: app)))
            viewport = visibleViewport(for: verse, in: app)
            point = CGPoint(x: verse.frame.minX + offset.x, y: verse.frame.minY + offset.y)
        }
        let safeViewport = viewport.insetBy(dx: 4, dy: 4)
        XCTAssertTrue(verse.isHittable, "Verse \(number) must be visible before selection")
        XCTAssertTrue(verse.frame.contains(point), "Owned-word point must remain inside the verse frame")
        XCTAssertTrue(safeViewport.contains(point), "Owned-word point must remain inside the safe visible Reader viewport")
        NSLog("READER_PARITY_WORD_TAP verse=%d frame=%@ offset=%@ point=%@ viewport=%@",
              number, NSCoder.string(for: verse.frame), String(describing: offset),
              String(describing: point), NSCoder.string(for: viewport))
        verse.coordinate(withNormalizedOffset: CGVector(dx: offset.x / verse.frame.width,
                                                          dy: offset.y / verse.frame.height)).tap()
    }

    private func assertSelection(summary: String, reference: String, in app: XCUIApplication) {
        waitForLabel(app.staticTexts["reader-selection-summary"], equals: summary)
        waitForLabel(app.staticTexts["reader-selection-reference"], equals: reference)
    }

    private func scrollToVisible(_ element: XCUIElement, in app: XCUIApplication,
                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing visible target: \(element.identifier)", file: file, line: line)
        // Extra large John 1 leaves the Back control about 7700 pt above the footer. Twelve drags cannot reach it.
        let requiresFullVisibility = element.identifier.hasPrefix("translation-")
        var previousFrame = element.frame
        var stalledAttempts = 0
        for attempt in 0..<24 {
            let safeViewport = requiresFullVisibility
                ? visibleViewport(for: element, in: app).insetBy(dx: 4, dy: 4)
                : .zero
            if element.isHittable && (!requiresFullVisibility || safeViewport.contains(element.frame)) { break }
            guard element.exists else {
                XCTFail("Target disappeared while scrolling: \(element.identifier)", file: file, line: line)
                return
            }
            guard let scroll = scrollView(containing: element, in: app), scroll.exists, scroll.isHittable else {
                XCTFail("Target scroll view disappeared or is not hittable: \(element.identifier)", file: file, line: line)
                return
            }
            let viewport = visibleViewport(for: element, in: app)
            XCTAssertGreaterThan(viewport.height, 120, "No safe visible scroll area", file: file, line: line)
            let above = element.frame.midY < viewport.midY
            let startFraction: CGFloat = above ? 0.25 : 0.75
            let endFraction: CGFloat = above ? 0.75 : 0.25
            let start = CGPoint(x: viewport.minX + 24, y: viewport.minY + viewport.height * startFraction)
            let end = CGPoint(x: viewport.minX + 24, y: viewport.minY + viewport.height * endFraction)
            NSLog("READER_PARITY_SCROLL attempt=%d id=%@ scroll=%@ viewport=%@ target=%@ start=%@ end=%@",
                  attempt, element.identifier, scroll.identifier, String(describing: viewport), String(describing: element.frame),
                  String(describing: start), String(describing: end))
            app.coordinate(withNormalizedOffset: normalized(start, in: app))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: normalized(end, in: app)))
            guard element.exists, scroll.exists else {
                XCTFail("Target or scroll view disappeared after drag: \(element.identifier)", file: file, line: line)
                return
            }
            let currentFrame = element.frame
            if abs(currentFrame.minY - previousFrame.minY) < 1 {
                stalledAttempts += 1
                NSLog("READER_PARITY_SCROLL_NO_PROGRESS attempt=%d id=%@ scroll=%@ frame=%@ viewport=%@ stalled=%d",
                      attempt, element.identifier, scroll.identifier, NSCoder.string(for: currentFrame),
                      NSCoder.string(for: viewport), stalledAttempts)
            } else {
                stalledAttempts = 0
            }
            previousFrame = currentFrame
            if stalledAttempts >= 3 {
                XCTFail("Scroll made no progress after 3 drags: id=\(element.identifier) scroll=\(scroll.identifier) frame=\(NSCoder.string(for: currentFrame)) viewport=\(NSCoder.string(for: viewport))",
                        file: file, line: line)
                break
            }
        }
        XCTAssertTrue(element.isHittable, "Target must be visible and hittable", file: file, line: line)
        if requiresFullVisibility {
            let safeViewport = visibleViewport(for: element, in: app).insetBy(dx: 4, dy: 4)
            XCTAssertTrue(safeViewport.contains(element.frame),
                          "Translation target must be fully inside the safe visible viewport: id=\(element.identifier) frame=\(NSCoder.string(for: element.frame)) viewport=\(NSCoder.string(for: safeViewport))",
                          file: file, line: line)
        }
    }

    private func scrollToLastVerseTail(_ lastVerse: XCUIElement,
                                       in app: XCUIApplication,
                                       key: String,
                                       file: StaticString = #filePath,
                                       line: UInt = #line) {
        XCTAssertTrue(lastVerse.waitForExistence(timeout: 10), "Missing final verse: \(key)", file: file, line: line)
        let initialViewport = visibleViewport(for: lastVerse, in: app).insetBy(dx: 4, dy: 4)
        let initialFrame = lastVerse.frame
        let initialDistance: CGFloat
        if initialFrame.maxY > initialViewport.maxY {
            initialDistance = initialFrame.maxY - initialViewport.maxY
        } else if initialFrame.maxY < initialViewport.minY {
            initialDistance = initialViewport.minY - initialFrame.maxY
        } else {
            initialDistance = 0
        }
        let estimatedProgressPerDrag = max(1, initialViewport.height * 0.55)
        let marginAttempts = 12
        let derivedAttempts = Int(ceil(initialDistance / estimatedProgressPerDrag)) + marginAttempts
        let maxAttempts = min(180, max(1, derivedAttempts))
        guard let scroll = scrollView(containing: lastVerse, in: app) else {
            XCTFail("No Reader scroll view contains final verse \(key)", file: file, line: line)
            return
        }
        NSLog("READER_PARITY_END_TEXT_BOUND case=%@ distance=%.1f viewportHeight=%.1f estimatedPerDrag=%.1f margin=%d attempts=%d cap=180",
              key, initialDistance, initialViewport.height, estimatedProgressPerDrag, marginAttempts, maxAttempts)

        var stalledBatches = 0
        var batchCount = 0
        var totalGestures = 0
        var previousFrame = initialFrame
        var previousScrollValue = String(describing: scroll.value ?? "nil")
        while totalGestures < maxAttempts {
            let viewport = visibleViewport(for: lastVerse, in: app).insetBy(dx: 4, dy: 4)
            let verseFrame = lastVerse.frame
            let verseTailVisible = verseFrame.intersects(viewport) && verseFrame.maxY <= viewport.maxY
            let scrollValue = String(describing: scroll.value ?? "nil")
            NSLog("READER_PARITY_END_TEXT case=%@ batch=%d totalGestures=%d viewport=%@ verse=%@ scrollFrame=%@ scrollValue=%@ tailVisible=%d",
                  key, batchCount, totalGestures, NSCoder.string(for: viewport), NSCoder.string(for: verseFrame),
                  NSCoder.string(for: scroll.frame), scrollValue, verseTailVisible ? 1 : 0)
            if verseTailVisible { break }

            XCTAssertGreaterThan(viewport.height, 120, "No safe Reader viewport for final verse tail: \(key)", file: file, line: line)
            let needsScrollDown = verseFrame.maxY < viewport.minY
            let remainingDistance = needsScrollDown
                ? viewport.minY - verseFrame.maxY
                : verseFrame.maxY - viewport.maxY
            let remainingGestureBudget = maxAttempts - totalGestures
            let gestureBatch = min(remainingGestureBudget,
                                   remainingDistance > 8 * viewport.height ? 8 : 1)
            let startFraction: CGFloat = needsScrollDown ? 0.1 : 0.9
            let endFraction: CGFloat = needsScrollDown ? 0.9 : 0.1
            let start = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * startFraction)
            let end = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * endFraction)
            NSLog("READER_PARITY_END_TEXT_BATCH case=%@ batch=%d gestures=%d totalBefore=%d remainingDistance=%.1f viewportHeight=%.1f",
                  key, batchCount, gestureBatch, totalGestures, remainingDistance, viewport.height)
            for _ in 0..<gestureBatch {
                app.coordinate(withNormalizedOffset: normalized(start, in: app))
                    .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: normalized(end, in: app)))
            }
            totalGestures += gestureBatch
            batchCount += 1

            let currentFrame = lastVerse.frame
            let currentScrollValue = String(describing: scroll.value ?? "nil")
            let frameProgress = abs(currentFrame.minY - previousFrame.minY) > 1
            let scrollProgress = currentScrollValue != previousScrollValue
            if frameProgress || scrollProgress {
                stalledBatches = 0
            } else {
                stalledBatches += 1
                NSLog("READER_PARITY_END_TEXT_STALL case=%@ stalledBatches=%d batch=%d totalGestures=%d frame=%@ scrollFrame=%@ scrollValue=%@",
                      key, stalledBatches, batchCount, totalGestures, NSCoder.string(for: currentFrame),
                      NSCoder.string(for: scroll.frame), currentScrollValue)
            }
            previousFrame = currentFrame
            previousScrollValue = currentScrollValue
            if stalledBatches >= 3 {
                XCTFail("Reader stopped scrolling before final verse tail was visible: case=\(key) batches=\(batchCount) totalGestures=\(totalGestures) frame=\(NSCoder.string(for: currentFrame)) scrollFrame=\(NSCoder.string(for: scroll.frame)) scrollValue=\(currentScrollValue)",
                        file: file, line: line)
                break
            }
        }

        let viewport = visibleViewport(for: lastVerse, in: app).insetBy(dx: 4, dy: 4)
        let finalFrame = lastVerse.frame
        let finalScrollValue = String(describing: scroll.value ?? "nil")
        XCTAssertTrue(finalFrame.intersects(viewport) && finalFrame.maxY <= viewport.maxY,
                      "The final verse tail must be above the tab boundary before capture: case=\(key) frame=\(NSCoder.string(for: finalFrame)) viewport=\(NSCoder.string(for: viewport)) scrollFrame=\(NSCoder.string(for: scroll.frame)) scrollValue=\(finalScrollValue)",
                      file: file, line: line)
    }

    private func scrollToAttribution(_ attribution: XCUIElement,
                                    in app: XCUIApplication,
                                    key: String,
                                    file: StaticString = #filePath,
                                    line: UInt = #line) {
        XCTAssertTrue(attribution.waitForExistence(timeout: 10), "Missing edition attribution: \(key)", file: file, line: line)
        for attempt in 0..<12 {
            let viewport = visibleViewport(for: attribution, in: app).insetBy(dx: 4, dy: 4)
            let frame = attribution.frame
            let visible = viewport.contains(frame)
            NSLog("READER_PARITY_END_FOOTER case=%@ attempt=%d viewport=%@ attribution=%@ visible=%d",
                  key, attempt, NSCoder.string(for: viewport), NSCoder.string(for: frame), visible ? 1 : 0)
            if visible { break }

            XCTAssertGreaterThan(viewport.height, 120, "No safe Reader viewport for attribution: \(key)", file: file, line: line)
            let needsScrollDown = frame.minY < viewport.minY
            let startFraction: CGFloat = needsScrollDown ? 0.25 : 0.75
            let endFraction: CGFloat = needsScrollDown ? 0.75 : 0.25
            let start = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * startFraction)
            let end = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * endFraction)
            app.coordinate(withNormalizedOffset: normalized(start, in: app))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: normalized(end, in: app)))
        }

        let viewport = visibleViewport(for: attribution, in: app).insetBy(dx: 4, dy: 4)
        XCTAssertTrue(viewport.contains(attribution.frame),
                      "Complete edition attribution must be visible before footer capture: \(key)", file: file, line: line)
    }

    private func tapWhenReady(_ element: XCUIElement, in app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        scrollToVisible(element, in: app, file: file, line: line)
        element.tap()
    }

    private func scrollView(containing element: XCUIElement, in app: XCUIApplication) -> XCUIElement? {
        let identifier = element.identifier
        let isGoToTarget = identifier.hasPrefix("go-to-book-") || identifier.hasPrefix("go-to-chapter-")
        if !identifier.isEmpty {
            // Go To is a sheet. Its underlying Reader scroll view can still exist while the sheet is foreground.
            let containingScroll = app.scrollViews.containing(.any, identifier: identifier).firstMatch
            if containingScroll.exists, containingScroll.isHittable {
                return containingScroll
            }
            if isGoToTarget { return nil }
        } else if isGoToTarget {
            return nil
        }

        let chapterScroll = app.scrollViews["reader-chapter-scroll"]
        if chapterScroll.exists, chapterScroll.isHittable { return chapterScroll }
        return app.scrollViews.allElementsBoundByIndex
            .filter { $0.exists && $0.isHittable }
            .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
    }

    private func visibleViewport(for element: XCUIElement, in app: XCUIApplication) -> CGRect {
        guard let scroll = scrollView(containing: element, in: app), scroll.exists, scroll.isHittable else {
            XCTFail("No visible scroll view contains target: id=\(element.identifier) frame=\(NSCoder.string(for: element.frame))")
            return .zero
        }
        let isReaderScroll = scroll.identifier == "reader-chapter-scroll"
        var viewport = scroll.frame.intersection(app.frame)
        if isReaderScroll {
            let safeTop = Double(scroll.value as? String ?? "") ?? 0
            viewport.origin.y = max(viewport.minY, safeTop + 8)
            let title = app.buttons["reader-title"]
            if title.exists, title.frame.maxY > viewport.minY {
                viewport.origin.y = max(viewport.minY, title.frame.maxY + 8)
            }
        }
        // Native: the tab bar element edge, else the tab button tops minus 12 pt. The old app keeps its button-top rule.
        if let top = tabBarTopEdge(in: app, within: viewport) {
            viewport.size.height = min(viewport.height, top - viewport.minY)
        }
        if isReaderScroll {
            // Native: Scripture scrolls under the floating selection panel (audit B3). Keep taps above the panel.
            let panel = app.descendants(matching: .any).matching(identifier: "reader-selection-panel").firstMatch
            if panel.exists, panel.frame.height > 0, panel.frame.minY > viewport.minY {
                viewport.size.height = min(viewport.height, panel.frame.minY - 8 - viewport.minY)
            }
        }
        let baselineTabs = ["Today", "Read", "Saved", "Pray", "Settings"]
            .map { baselineTab($0, in: app) }
            .filter { $0.exists && $0.frame.intersects(viewport) }
        if let top = baselineTabs.map(\.frame.minY).min() {
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

    private func waitForTranslationCommit(_ element: XCUIElement, in app: XCUIApplication,
                                          file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Selected"),
                                                     object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: 10)
        if result != .completed {
            attachScreenshot("reader-parity-\(element.identifier)-commit-failure", app: app)
            attachAXTree("reader-parity-\(element.identifier)-commit-failure", app: app)
        }
        XCTAssertEqual(result, .completed,
                       "Expected committed value: Selected, observed: \(String(describing: element.value))",
                       file: file, line: line)
    }

    private func baselineRadioValue(_ element: XCUIElement) -> String? {
        guard element.elementType == .other, let value = element.value as? String,
              value == "radio button, checked" || value == "radio button, unchecked" else { return nil }
        return value
    }

    /// READER_PARITY_TEXT_SIZE: Default (unset) or Extra large. Other values return nil.
    private func requestedTextSize() -> String? {
        let raw = CaptureMetadata.value("READER_PARITY_TEXT_SIZE")
        if raw == "unprovided" { return "Default" }
        switch raw.trimmingCharacters(in: .whitespaces).lowercased()
            .replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "") {
        case "default": return "Default"
        case "extralarge": return "Extra large"
        default: return nil
        }
    }

    /// The log name for the default size stays "Medium", as before.
    private func textSizeName(_ textSize: String) -> String { textSize == "Default" ? "Medium" : textSize }

    /// READER_PARITY_AX_TREE=1 attaches `XCUIApplication.debugDescription` next to each screenshot.
    private func attachAXTreeIfRequested(_ name: String, app: XCUIApplication) {
        guard CaptureMetadata.value("READER_PARITY_AX_TREE") == "1" else { return }
        attachAXTree(name, app: app)
    }

    private func attachAXTree(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = "\(name)-ax"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func attachScreenshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func baselineTab(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "\(name), tab")).firstMatch
    }

    private func baselineSnapshot(_ name: String, app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "\(name)-screenshot"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "\(name)-accessibility"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        NSLog("BASELINE_RECON snapshot=%@ appFrame=%@", name, NSCoder.string(for: app.frame))
    }

    private func logBaselineChoiceControls(_ app: XCUIApplication) {
        let choiceTerms = ["text size", "line spacing", "typeface", "layout", "appearance", "world english",
                           "douay", "vulgate", "translation", "paragraph", "verse"]
        for element in app.descendants(matching: .any).allElementsBoundByIndex {
            let label = element.label
            guard !label.isEmpty,
                  choiceTerms.contains(where: { label.localizedCaseInsensitiveContains($0) }) else { continue }
            NSLog("BASELINE_RECON choice role=%@ label=%@ value=%@ selected=%d hittable=%d",
                  String(describing: element.elementType), label, String(describing: element.value),
                  element.isSelected ? 1 : 0, element.isHittable ? 1 : 0)
        }
    }

    private func largestVisibleScrollViewport(in app: XCUIApplication) -> CGRect? {
        let frame = app.frame
        let scrolls = app.scrollViews.allElementsBoundByIndex
            .filter { $0.exists && $0.isHittable && $0.frame.width > 0 && $0.frame.height > 0 }
        guard let scroll = scrolls.max(by: { $0.frame.height < $1.frame.height }) else { return nil }
        var viewport = scroll.frame.intersection(frame)
        let visibleTabs = ["Today", "Read", "Saved", "Pray", "Settings"]
            .map { baselineTab($0, in: app) }
            .filter { $0.exists && $0.frame.intersects(viewport) }
        if let tabTop = visibleTabs.map(\.frame.minY).min() {
            viewport.size.height = min(viewport.height, tabTop - viewport.minY)
        }
        guard viewport.width > 80, viewport.height > 120 else { return nil }
        return viewport
    }

    private func boundedScroll(in viewport: CGRect, direction: ScrollDirection, app: XCUIApplication) {
        let x = viewport.midX
        let startY = direction == .up ? viewport.minY + viewport.height * 0.75 : viewport.minY + viewport.height * 0.25
        let endY = direction == .up ? viewport.minY + viewport.height * 0.25 : viewport.minY + viewport.height * 0.75
        app.coordinate(withNormalizedOffset: normalized(CGPoint(x: x, y: startY), in: app))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: normalized(CGPoint(x: x, y: endY), in: app)))
    }

    private enum ScrollDirection {
        case up
        case down
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

    }

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
