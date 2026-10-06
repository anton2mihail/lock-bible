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
        throw XCTSkip("Psalms 2 owned-word points are verified only on iPhone 17 Pro. Capture iPad points before this journey.")
    }

    private func openLongWebPassage(in app: XCUIApplication) {
        app.launch()
        setReadingProfile(in: app)
        app.buttons["tab-read"].tap()
        openReaderBookList(in: app)
        tapWhenReady(app.buttons["reader-book-PSA"], in: app)
        tapWhenReady(app.buttons["reader-chapter-2"], in: app)

        let first = app.buttons["reader-verse-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 12))
        if !first.isSelected {
            tapOwnedWord(CGPoint(x: 88, y: 19), in: first, label: "Psalms 2:1", app: app)
        }
        XCTAssertTrue(app.staticTexts["reader-selection-summary"].waitForExistence(timeout: 5))
        assertReference("Psalms 2:1", in: app)

        let last = app.buttons["reader-verse-12"]
        tapOwnedWord(CGPoint(x: 96, y: 28), in: last, label: "Psalms 2:12", app: app)
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

    private func setReadingProfile(in app: XCUIApplication) {
        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 8))
        let choices = [
            ("settings-text-size-default", "Default"),
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
                              app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(verse.waitForExistence(timeout: 10), "Missing verse control: \(label)", file: file, line: line)
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .phone,
                       "Verified verse word points apply only to the iPhone 17 Pro profile", file: file, line: line)
        XCTAssertEqual(app.frame.width, 402, accuracy: 1,
                       "Verified verse word points require the observed iPhone 17 Pro width", file: file, line: line)
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
