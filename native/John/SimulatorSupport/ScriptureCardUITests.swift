import XCTest
import UIKit

/// Uses bundled WEB-CE Psalms 2:1–12. Its joined canonical verse text is 1,043 UTF-16 units.
/// A separate host watcher captures each generated PNG while the native share panel is open.
@MainActor
final class ScriptureCardUITests: XCTestCase {
    private let firstVerseStart = "Why do the nations rage, and the peoples plot a vain thing?"
    private let lastVerseEnd = "Blessed are all those who take refuge in him."

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLongSelectedPassageExportsIvoryPlumAndRepeatAfterCancel() throws {
        let app = XCUIApplication()
        openLongWebPassage(in: app)
        tapWhenReady(app.buttons["reader-selection-card"], in: app)

        let warmIvory = app.buttons["Warm ivory"]
        XCTAssertTrue(warmIvory.waitForExistence(timeout: 8))
        assertCardPreview(in: app)
        attachScreenshot("card-long-ivory-preview", app: app)
        exportAndCancel(label: "ivory", in: app)

        let eveningPlum = app.buttons["Evening plum"]
        tapWhenReady(eveningPlum, in: app)
        assertCardPreview(in: app)
        attachScreenshot("card-long-plum-preview", app: app)
        exportAndCancel(label: "plum", in: app)

        // The second plum export checks that the route can create another temporary image
        // after the first panel is cancelled and the first image is released.
        exportAndCancel(label: "plum-repeat", in: app)
        NSLog("CARD_LONG_EXPORT passage=WEB-CE:Psalms:2:1-12 canonicalRawUTF16=1043 references=\"Psalms 2:1–12\" presets=ivory,plum captures=ivory,plum,plum-repeat cancel=system-share-panel")
    }

    func testLongCardSharePresentationOnIPadWhereSupported() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("This test checks the iPad share presentation only.")
        }
        // Step 7: Main measures the points with testStep7MeasureOwnedWordPointsForCurrentDevice and passes them as
        // STEP7_IPAD_WORD_POINTS="x1,y1;x12,y12" (offsets in points from each verse frame origin).
        guard let raw = ProcessInfo.processInfo.environment["STEP7_IPAD_WORD_POINTS"] else {
            throw XCTSkip("Psalms 2 owned-word points are verified only on iPhone 17 Pro. Capture iPad points before this journey.")
        }
        let pairs = raw.split(separator: ";").map { $0.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) } }
        guard pairs.count == 2, pairs.allSatisfy({ $0.count == 2 }) else {
            XCTFail("STEP7_IPAD_WORD_POINTS must look like x1,y1;x12,y12")
            return
        }
        let app = XCUIApplication()
        openLongWebPassage(in: app,
                           points: (CGPoint(x: pairs[0][0], y: pairs[0][1]), CGPoint(x: pairs[1][0], y: pairs[1][1])),
                           verifiedPhone: false)
        tapWhenReady(app.buttons["reader-selection-card"], in: app)
        XCTAssertTrue(app.buttons["Warm ivory"].waitForExistence(timeout: 8))
        assertCardPreview(in: app)
        attachScreenshot("card-ipad-ivory-preview", app: app)
        exportAndCancel(label: "ipad-ivory", in: app)
        NSLog("STEP7_CARD_IPAD window=%@ points=%@ popoverSeenDuringExport=see CARD_PNG_HOLD",
              NSCoder.string(for: app.frame), raw)
    }

    // MARK: Step 7 checks
    // Each test runs only when STEP7_CASES lists its case name. Default runs skip them.

    private func requireStep7(_ name: String) throws {
        let listed = (ProcessInfo.processInfo.environment["STEP7_CASES"] ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard listed.contains(name) else { throw XCTSkip("Set STEP7_CASES=\(name) to run this Step 7 check.") }
    }

    /// Opens the Scripture card from Today, then Verse Moment. It needs no owned-word point, so it works on every device.
    private func openCardFromVerseMoment(in app: XCUIApplication) {
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))
        tapWhenReady(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Verse & lock screen widget")).firstMatch, in: app)
        tapWhenReady(app.buttons["verse-moment-scripture-card"], in: app)
        let title = app.staticTexts["content-page-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "A word worth sharing")
    }

    // MARK: Share panel observation (Step 7)
    //
    // On the iOS 26.5 simulator the text share panel shows Reminders, More, and Save to Files and has no `Copy` cell
    // (step7-card-text-fallback-01/manual-text-share-panel.png). The helper therefore accepts the system share panel
    // as opened when it appears. Observed elements: `ActivityListView`, `ShareSheet.RemoteContainerView`,
    // `shareSheet.activity.contentView`, the collection view `activityCollectionView`, cells `shareCell` and
    // `actionGroupCell`, and the dismiss region `PopoverDismissRegion`. `Copy` is optional. The helper never claims
    // the payload: it records "share panel observed; payload not verified".

    private struct SharePanelObservation {
        let root: XCUIElement
        let activityLabels: [String]
        let hasCopy: Bool
    }

    private func shareCopyCell(_ app: XCUIApplication) -> XCUIElement {
        app.cells.matching(NSPredicate(format: "label == %@", "Copy")).firstMatch
    }

    private func sharePanelRoot(_ app: XCUIApplication) -> XCUIElement? {
        [app.otherElements["ActivityListView"], app.collectionViews["activityCollectionView"],
         app.otherElements["shareSheet.activity.contentView"], shareCopyCell(app)].first { $0.exists }
    }

    /// Waits for the system share panel. Returns the observation, or nil if no panel appeared within the timeout.
    private func waitForSharePanel(_ app: XCUIApplication, timeout: TimeInterval) -> SharePanelObservation? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let root = sharePanelRoot(app) {
                let cells = app.cells.matching(NSPredicate(format: "identifier IN %@", ["shareCell", "actionGroupCell"]))
                _ = cells.firstMatch.waitForExistence(timeout: 4) // let the activity cells load
                var labels = cells.allElementsBoundByIndex.filter(\.exists).map(\.label)
                let copy = shareCopyCell(app)
                if copy.exists, !labels.contains("Copy") { labels.append("Copy") }
                return SharePanelObservation(root: root, activityLabels: labels, hasCopy: copy.exists)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        return nil
    }

    private func recordSharePanel(_ context: String, _ observation: SharePanelObservation, app: XCUIApplication) {
        let payload = observation.hasCopy
            ? "Copy cell present; this helper does not read the payload; payload not verified"
            : "share panel observed; payload not verified"
        NSLog("STEP7_CARD_SHARE_PANEL context=%@ activities=%@ copy=%d popover=%d payload=%@", context,
              observation.activityLabels.joined(separator: "|"), observation.hasCopy ? 1 : 0,
              app.popovers.firstMatch.exists ? 1 : 0, payload)
        let record: [String: Any] = ["context": context, "panel": "observed", "activityLabels": observation.activityLabels,
                                     "copyCellPresent": observation.hasCopy, "payload": payload]
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) {
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "step7-share-panel-\(context).json"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func step7DismissSharePanel(_ observation: SharePanelObservation, in app: XCUIApplication) {
        let root = observation.root
        let close = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Close", "Cancel")).firstMatch
        if close.exists && close.isHittable {
            close.tap()
        } else {
            // A tap above a bottom sheet (outside it) closes it. The observed dismiss region covers the window.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        }
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: root)
        if XCTWaiter.wait(for: [gone], timeout: 6) != .completed {
            // An iPad share popover closes when the user taps outside it.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.02)).tap()
        }
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 8), .completed, "The share panel must close without a share action")
    }

    /// Text fallback: "Share text instead" opens the system share panel (ScriptureCardView.swift shareText).
    /// The image share still works after it. The panel is accepted when it appears. Copy is optional.
    /// This helper does not verify the shared text. The expected text format is
    /// `<text>\n\n<ref> (<abbr>)\nJohn 1:1 · Scripture & Prayer` (`ShareCardScreen.tsx:43-46`).
    func testStep7CardShareTextFallbackAndImageStillWork() throws {
        try requireStep7("card-text-fallback")
        let app = XCUIApplication()
        openCardFromVerseMoment(in: app)
        let textShare = app.buttons.matching(NSPredicate(format: "label == %@", "Share text instead")).firstMatch
        tapWhenReady(textShare, in: app)
        let panel = waitForSharePanel(app, timeout: 15)
        XCTAssertNotNil(panel, "The native share panel must open for the text")
        guard let panel else { return }
        NSLog("STEP7_CARD_TEXT_SHARE opened idiom=%@ popover=%d window=%@",
              UIDevice.current.userInterfaceIdiom == .pad ? "pad" : "phone", app.popovers.firstMatch.exists ? 1 : 0,
              NSCoder.string(for: app.frame))
        recordSharePanel("text", panel, app: app)
        attachScreenshot("step7-card-text-share", app: app)
        step7DismissSharePanel(panel, in: app)

        tapWhenReady(app.buttons["scripture-card-share-image"], in: app)
        let imagePanel = waitForSharePanel(app, timeout: 20)
        XCTAssertNotNil(imagePanel, "The image share must still open after the text share")
        XCTAssertFalse(app.staticTexts["scripture-card-share-error"].exists)
        guard let imagePanel else { return }
        recordSharePanel("image-after-text", imagePanel, app: app)
        attachScreenshot("step7-card-image-share-after-text", app: app)
        step7DismissSharePanel(imagePanel, in: app)
    }

    /// PNG write failure. Main makes the app data container's tmp folder read-only while the app is stopped.
    /// Expected (ScriptureCardView.swift prepareImageShare, after Sol's copy fix): the old app's exact message
    /// (src/screens/companion/ShareCardScreen.tsx:63), no share panel, the button works again, and "Share text instead"
    /// still opens the share panel. This is a fault-injected check: tmp is read-only; not a natural failure.
    func testStep7CardPNGWriteFailureShowsMessageAndKeepsTextShare() throws {
        try requireStep7("card-png-fault")
        let app = XCUIApplication()
        openCardFromVerseMoment(in: app)
        let imageButton = app.buttons["scripture-card-share-image"]
        tapWhenReady(imageButton, in: app)
        let error = app.staticTexts["scripture-card-share-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 15), "A failed PNG write must show the share error")
        XCTAssertEqual(error.label, "The card could not be shared. Please try again, or share the text.")
        XCTAssertNil(waitForSharePanel(app, timeout: 3), "No share panel may open after the failure")
        XCTAssertFalse(app.otherElements["scripture-card-share-busy"].exists)
        XCTAssertTrue(imageButton.isHittable && imageButton.isEnabled, "The image button must work again")
        attachScreenshot("step7-card-png-failure", app: app)
        tapWhenReady(app.buttons.matching(NSPredicate(format: "label == %@", "Share text instead")).firstMatch, in: app)
        let panel = waitForSharePanel(app, timeout: 15)
        XCTAssertNotNil(panel, "The text share must still open")
        if let panel {
            recordSharePanel("text-after-png-fault", panel, app: app)
            step7DismissSharePanel(panel, in: app)
        }
        NSLog("STEP7_CARD_FAULT pngWriteFailure=observed")
    }

    /// Measures owned-word offsets for the current device and text size. It taps a grid inside each verse and records
    /// the points where a selection starts. Output: NSLog lines STEP7_WORD_POINT and one attachment.
    /// Use the John 1:1 offset as L25_VERSE1_TAP_OFFSET. Use the Psalms 2:1 and 2:12 offsets as STEP7_IPAD_WORD_POINTS.
    /// STEP7_TEXT_SIZE="Extra large" measures that text size. The default is Default.
    func testStep7MeasureOwnedWordPointsForCurrentDevice() throws {
        try requireStep7("measure-word-points")
        let extraLarge = ProcessInfo.processInfo.environment["STEP7_TEXT_SIZE"] == "Extra large"
        let app = XCUIApplication()
        app.launch()
        setReadingProfile(in: app,
                          textSizeIdentifier: extraLarge ? "settings-text-size-extra-large" : "settings-text-size-default",
                          textSizeName: extraLarge ? "Extra large" : "Default")
        app.buttons["tab-read"].tap()
        openReaderBookList(in: app)
        var lines: [String] = []
        tapWhenReady(app.buttons["reader-book-JHN"], in: app)
        tapWhenReady(app.buttons["reader-chapter-1"], in: app)
        lines.append(probeOwnedWordPoints(app.buttons["reader-verse-1"], label: "John 1:1", verseNumber: 1, app: app))
        for _ in 0..<2 {
            let back = app.buttons["reader-back"]
            XCTAssertTrue(back.waitForExistence(timeout: 8))
            back.tap()
        }
        tapWhenReady(app.buttons["reader-book-PSA"], in: app)
        tapWhenReady(app.buttons["reader-chapter-2"], in: app)
        lines.append(probeOwnedWordPoints(app.buttons["reader-verse-1"], label: "Psalms 2:1", verseNumber: 1, app: app))
        lines.append(probeOwnedWordPoints(app.buttons["reader-verse-12"], label: "Psalms 2:12", verseNumber: 12, app: app))
        let header = "device=\(UIDevice.current.userInterfaceIdiom == .pad ? "pad" : "phone") window=\(NSCoder.string(for: app.frame)) textSize=\(extraLarge ? "Extra large" : "Default")"
        let report = ([header] + lines).joined(separator: "\n")
        NSLog("STEP7_WORD_POINTS %@", report)
        let attachment = XCTAttachment(string: report)
        attachment.name = "step7-word-points"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// A point counts only when the selection reads "Selected: verses N–N" for the probed verse.
    /// Any other selection is logged as wrong-verse and not counted.
    private func probeOwnedWordPoints(_ verse: XCUIElement, label: String, verseNumber: Int, app: XCUIApplication) -> String {
        XCTAssertTrue(verse.waitForExistence(timeout: 12), "Missing verse control: \(label)")
        if !verse.isHittable { scrollToVisible(verse, in: app) }
        let frame = verse.frame
        var found: [CGPoint] = []
        var wrongVerse: [String] = []
        var attempts = 0
        var y: CGFloat = 8
        outer: while y < frame.height - 4 {
            var x: CGFloat = 12
            while x < frame.width - 8 {
                attempts += 1
                if attempts > 90 { break outer }
                let point = CGPoint(x: frame.minX + x, y: frame.minY + y)
                if visibleScrollViewport(in: app).contains(point) {
                    app.coordinate(withNormalizedOffset: CGVector(dx: point.x / app.frame.width,
                                                                   dy: point.y / app.frame.height)).tap()
                    let summary = app.staticTexts["reader-selection-summary"]
                    if summary.waitForExistence(timeout: 1.0) {
                        if summary.label == "Selected: verses \(verseNumber)–\(verseNumber)" {
                            found.append(CGPoint(x: x, y: y))
                        } else {
                            wrongVerse.append("\(summary.label) at (\(Int(x)),\(Int(y)))")
                        }
                        app.buttons["reader-selection-close"].tap()
                        _ = summary.waitForNonExistence(timeout: 3)
                        if found.count >= 3 { break outer }
                    }
                }
                x += 28
            }
            y += 14
        }
        let text = found.map { String(format: "(%.0f,%.0f)", $0.x, $0.y) }.joined(separator: " ")
        let line = "STEP7_WORD_POINT label=\(label) verseFrame=\(NSCoder.string(for: frame)) attempts=\(attempts) successOffsets=\(text.isEmpty ? "none" : text) wrong-verse=\(wrongVerse.isEmpty ? "none" : wrongVerse.joined(separator: "; "))"
        NSLog("%@", line)
        XCTAssertFalse(found.isEmpty, "No owned-word point found for \(label)")
        return line
    }

    private func openLongWebPassage(in app: XCUIApplication, points: (CGPoint, CGPoint)? = nil,
                                    verifiedPhone: Bool = true) {
        app.launch()
        setReadingProfile(in: app)
        app.buttons["tab-read"].tap()
        openReaderBookList(in: app)
        tapWhenReady(app.buttons["reader-book-PSA"], in: app)
        tapWhenReady(app.buttons["reader-chapter-2"], in: app)

        let first = app.buttons["reader-verse-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 12))
        if !first.isSelected {
            tapOwnedWord(points?.0 ?? CGPoint(x: 88, y: 19), in: first, label: "Psalms 2:1", app: app,
                         verifiedPhone: verifiedPhone)
        }
        XCTAssertTrue(app.staticTexts["reader-selection-summary"].waitForExistence(timeout: 5))
        assertReference("Psalms 2:1", in: app)

        let last = app.buttons["reader-verse-12"]
        tapOwnedWord(points?.1 ?? CGPoint(x: 96, y: 28), in: last, label: "Psalms 2:12", app: app,
                     verifiedPhone: verifiedPhone)
        let summary = app.staticTexts["reader-selection-summary"]
        let range = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Selected: verses 1–12"), object: summary)
        XCTAssertEqual(XCTWaiter.wait(for: [range], timeout: 8), .completed,
                       "The Reader must select the complete source range before opening the card")
        let reference = app.staticTexts["reader-selection-reference"]
        let referenceReady = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Psalms 2:1–12"), object: reference)
        XCTAssertEqual(XCTWaiter.wait(for: [referenceReady], timeout: 8), .completed,
                       "The selected reference must identify the complete Psalm range")
        NSLog("CARD_SELECTED_RANGE reference=Psalms2:1-12 translation=web-ce canonicalRawUTF16=1043")
    }

    private func setReadingProfile(in app: XCUIApplication, textSizeIdentifier: String = "settings-text-size-default",
                                   textSizeName: String = "Default") {
        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 8))
        let choices = [
            (textSizeIdentifier, textSizeName),
            ("settings-line-spacing-comfortable", "Comfortable"),
            ("settings-scripture-typeface-serif", "Serif"),
            ("settings-layout-verse-by-verse", "Verse by verse"),
            ("translation-web-ce", "WEB-CE"),
        ]
        for (identifier, name) in choices {
            let control = app.buttons[identifier]
            XCTAssertTrue(control.waitForExistence(timeout: 8), "Missing reading choice: \(name)")
            if control.value as? String != "Selected" {
                control.tap()
                waitForSelected(control)
            }
            XCTAssertEqual(control.value as? String, "Selected", "Reading choice must be committed: \(name)")
        }
        NSLog("CARD_READER_PROFILE textSize=Default lineSpacing=Comfortable typeface=Serif layout=VerseByVerse edition=WEB-CE")
    }

    private func assertReference(_ expected: String, in app: XCUIApplication) {
        let reference = app.staticTexts["reader-selection-reference"]
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expected), object: reference)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed,
                       "The selected verse reference must be exact")
    }

    private func tapOwnedWord(_ offset: CGPoint, in verse: XCUIElement, label: String,
                              app: XCUIApplication, verifiedPhone: Bool = true,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(verse.waitForExistence(timeout: 10), "Missing verse control: \(label)", file: file, line: line)
        if verifiedPhone {
            XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .phone,
                           "Verified verse word points apply only to the iPhone 17 Pro profile", file: file, line: line)
            XCTAssertEqual(app.frame.width, 402, accuracy: 1,
                           "Verified verse word points require the observed iPhone 17 Pro width", file: file, line: line)
        }
        scrollToOwnedPoint(offset, in: verse, label: label, app: app, file: file, line: line)
        let point = CGPoint(x: verse.frame.minX + offset.x, y: verse.frame.minY + offset.y)
        let viewport = visibleScrollViewport(in: app)
        XCTAssertTrue(verse.frame.contains(point), "Owned word point is outside \(label): \(point) / \(verse.frame)", file: file, line: line)
        XCTAssertTrue(viewport.contains(point), "Owned word point is outside the visible Reader viewport: \(point) / \(viewport)", file: file, line: line)
        XCTAssertTrue(verse.isHittable, "Verse is not hittable at the verified word point: \(label)", file: file, line: line)
        NSLog("CARD_OWNED_WORD label=%@ offset=(%.1f,%.1f) point=(%.1f,%.1f) verseFrame=%@ viewport=%@ profile=Default/Comfortable/Serif/VerseByVerse device=iPhone17Pro",
              label, offset.x, offset.y,
              point.x, point.y, NSCoder.string(for: verse.frame), NSCoder.string(for: viewport))
        app.coordinate(withNormalizedOffset: CGVector(dx: point.x / app.frame.width,
                                                       dy: point.y / app.frame.height)).tap()
    }

    private func scrollToOwnedPoint(_ offset: CGPoint, in element: XCUIElement, label: String,
                                    app: XCUIApplication,
                                    file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<8 {
            let frame = element.frame
            let point = CGPoint(x: frame.minX + offset.x, y: frame.minY + offset.y)
            let viewport = visibleScrollViewport(in: app)
            if frame.contains(point) && viewport.contains(point) && element.isHittable { return }
            XCTAssertGreaterThan(viewport.height, 80, "Reader viewport is not visible", file: file, line: line)
            let above = point.y < viewport.minY
            let x = viewport.midX
            let y1 = viewport.minY + viewport.height * (above ? 0.25 : 0.75)
            let y2 = viewport.minY + viewport.height * (above ? 0.75 : 0.25)
            app.coordinate(withNormalizedOffset: CGVector(dx: x / app.frame.width, dy: y1 / app.frame.height))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(
                    withNormalizedOffset: CGVector(dx: x / app.frame.width, dy: y2 / app.frame.height)))
            let moved = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in element.frame != frame }, object: element)
            XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 2), .completed,
                           "Scroll must move \(label) toward its verified word point", file: file, line: line)
        }
        let frame = element.frame
        let point = CGPoint(x: frame.minX + offset.x, y: frame.minY + offset.y)
        XCTAssertTrue(frame.contains(point), "Owned word point is outside \(label): \(point) / \(frame)", file: file, line: line)
        XCTAssertTrue(visibleScrollViewport(in: app).contains(point),
                      "Owned word point is outside the visible Reader viewport: \(point)", file: file, line: line)
        XCTAssertTrue(element.isHittable, "Verse is not hittable at the verified word point: \(label)", file: file, line: line)
    }

    private func waitForSelected(_ element: XCUIElement,
                                 file: StaticString = #filePath,
                                 line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Selected"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed,
                       "The setting must be committed before the Reader opens", file: file, line: line)
    }

    private func assertCardPreview(in app: XCUIApplication,
                                   file: StaticString = #filePath,
                                   line: UInt = #line) {
        let first = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", firstVerseStart)).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 8), "The card must show the first source text", file: file, line: line)
        let label = first.label
        XCTAssertTrue(label.contains(lastVerseEnd), "The long preview is missing its final text: \(label)", file: file, line: line)
        XCTAssertTrue(label.contains("Psalms 2:1–12"), "The preview reference must match the selection: \(label)", file: file, line: line)
        XCTAssertTrue(label.contains("WEB-CE"), "The preview must retain the selected edition: \(label)", file: file, line: line)
    }

    private func exportAndCancel(label: String, in app: XCUIApplication) {
        let export = app.buttons["scripture-card-share-image"]
        XCTAssertTrue(export.waitForExistence(timeout: 8))
        NSLog("CARD_PNG_ARM label=%@ reference=Psalms2:1-12 edition=WEB-CE", label)
        Thread.sleep(forTimeInterval: 8)
        tapWhenReady(export, in: app)
        let copyAction = app.cells.matching(NSPredicate(format: "label == %@", "Copy")).firstMatch
        XCTAssertTrue(copyAction.waitForExistence(timeout: 15), "The native share panel must open for \(label)")
        XCTAssertTrue(copyAction.isHittable, "The share panel must expose Copy for \(label)")
        NSLog("CARD_PNG_HOLD label=%@ reference=Psalms2:1-12 edition=WEB-CE; capture the new PNG from the app tmp path now", label)
        attachScreenshot("card-share-\(label)", app: app)
        Thread.sleep(forTimeInterval: 12)
        dismissShareSurface(in: app, copyAction: copyAction)
        XCTAssertTrue(export.waitForExistence(timeout: 8))
        XCTAssertTrue(export.isHittable, "Card export must work again after cancellation")
    }

    private func dismissShareSurface(in app: XCUIApplication, copyAction: XCUIElement) {
        let close = app.buttons.matching(NSPredicate(
            format: "label == %@ OR label == %@", "Close", "Cancel"
        )).firstMatch
        if close.exists && close.isHittable {
            close.tap()
        } else {
            copyAction.swipeDown()
        }
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: copyAction)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 10), .completed,
                       "The share panel must dismiss without selecting Copy")
    }

    private func scrollToVisible(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        for _ in 0..<8 where !element.isHittable {
            let viewport = visibleScrollViewport(in: app)
            XCTAssertGreaterThan(viewport.height, 80, "Reader scroll area is not visible")
            let prior = element.frame
            let down = prior.midY < viewport.minY
            let x = viewport.midX
            let y1 = down ? viewport.minY + viewport.height * 0.25 : viewport.minY + viewport.height * 0.75
            let y2 = down ? viewport.minY + viewport.height * 0.75 : viewport.minY + viewport.height * 0.25
            app.coordinate(withNormalizedOffset: CGVector(dx: x / app.frame.width, dy: y1 / app.frame.height))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(
                    withNormalizedOffset: CGVector(dx: x / app.frame.width, dy: y2 / app.frame.height)))
            let moved = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in element.frame != prior }, object: element)
            XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 2), .completed,
                           "The verse must move after a Reader scroll")
        }
        XCTAssertTrue(element.isHittable, "The final verse must be visible and hittable")
    }

    private func visibleScrollViewport(in app: XCUIApplication) -> CGRect {
        let scroll = app.scrollViews.allElementsBoundByIndex
            .filter { $0.exists && $0.isHittable }
            .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
        var visible = (scroll?.frame ?? app.frame).intersection(app.frame)
        let tabs = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tab-"))
            .allElementsBoundByIndex.filter { $0.exists && $0.frame.intersects(visible) }
        if let top = tabs.map(\.frame.minY).min() {
            visible.size.height = min(visible.height, top - visible.minY)
        }
        let navBottom = app.navigationBars.allElementsBoundByIndex
            .filter { $0.exists && $0.frame.intersects(visible) }
            .map(\.frame.maxY).max()
        if let navBottom {
            let top = max(visible.minY, navBottom)
            visible = CGRect(x: visible.minX, y: top, width: visible.width,
                             height: max(0, visible.maxY - top))
        }
        return visible
    }

    private func tapWhenReady(_ element: XCUIElement,
                              in app: XCUIApplication,
                              file: StaticString = #filePath,
                              line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing control", file: file, line: line)
        if !element.isHittable { scrollToVisible(element, in: app) }
        XCTAssertTrue(element.isHittable, "Control is not hittable", file: file, line: line)
        element.tap()
    }

    private func openReaderBookList(in app: XCUIApplication) {
        let book = app.buttons["reader-book-PSA"]
        for _ in 0..<3 where !book.exists {
            let back = app.buttons["reader-back"]
            XCTAssertTrue(back.waitForExistence(timeout: 8), "Reader must expose its real back control")
            tapWhenReady(back, in: app)
        }
        XCTAssertTrue(book.waitForExistence(timeout: 10),
                      "The card capture seed must start at Reader books, or return through Reader back controls")
    }

    private func attachScreenshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
