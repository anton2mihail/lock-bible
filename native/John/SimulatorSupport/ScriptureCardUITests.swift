import XCTest
import UIKit

/// Uses the bundled WEB-CE Psalms 2:1–12 passage, whose joined text is 1,043 UTF-16 units.
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
        NSLog("CARD_LONG_EXPORT passage=WEB-CE:Psalms:2:1-12 utf16=1043 references=\"Psalms 2:1–12\" presets=ivory,plum captures=ivory,plum,plum-repeat cancel=system-share-panel")
    }

    func testLongCardSharePresentationOnIPadWhereSupported() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("This test checks the iPad share presentation only.")
        }
        let app = XCUIApplication()
        openLongWebPassage(in: app)
        tapWhenReady(app.buttons["reader-selection-card"], in: app)
        tapWhenReady(app.buttons["Evening plum"], in: app)
        let shareButton = app.buttons["scripture-card-share-image"]
        tapWhenReady(shareButton, in: app)
        let copyAction = app.cells.matching(NSPredicate(format: "label == %@", "Copy")).firstMatch
        XCTAssertTrue(copyAction.waitForExistence(timeout: 15), "The native share surface must show Copy")
        XCTAssertTrue(copyAction.isHittable)
        let sheet = app.sheets.firstMatch
        let popover = app.popovers.firstMatch
        NSLog("CARD_IPAD_SHARE surface=%@ sheet=%@ popover=%@ copyHittable=%@",
              sheet.exists ? "sheet" : "other", String(sheet.exists), String(popover.exists), String(copyAction.isHittable))
        attachScreenshot("card-ipad-native-share-surface", app: app)
        dismissShareSurface(in: app, copyAction: copyAction)
        XCTAssertTrue(shareButton.waitForExistence(timeout: 8))
        XCTAssertTrue(shareButton.isHittable)
        NSLog("CARD_IPAD_SHARE dismissed=true routeAlive=true")
    }

    private func openLongWebPassage(in app: XCUIApplication) {
        app.launch()
        setEdition("web-ce", in: app)
        setVerseLayout(in: app)
        app.buttons["tab-read"].tap()
        tapWhenReady(app.buttons["reader-book-PSA"], in: app)
        tapWhenReady(app.buttons["reader-chapter-2"], in: app)

        let first = app.buttons["reader-verse-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 12))
        if !first.isSelected { tapWhenReady(first, in: app) }
        XCTAssertTrue(app.staticTexts["reader-selection-summary"].waitForExistence(timeout: 5))

        let last = app.buttons["reader-verse-12"]
        scrollToVisible(last, in: app)
        tapWhenReady(last, in: app)
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
        NSLog("CARD_SELECTED_RANGE reference=Psalms2:1-12 translation=web-ce utf16=1043")
    }

    private func setEdition(_ edition: String, in app: XCUIApplication) {
        app.buttons["tab-settings"].tap()
        let control = app.buttons["translation-\(edition)"]
        XCTAssertTrue(control.waitForExistence(timeout: 8))
        if control.value as? String != "Selected" {
            control.tap()
            waitForSelected(control)
        }
        app.buttons["tab-read"].tap()
    }

    private func setVerseLayout(in app: XCUIApplication) {
        app.buttons["tab-settings"].tap()
        let control = app.buttons["settings-layout-verse-by-verse"]
        XCTAssertTrue(control.waitForExistence(timeout: 8))
        if control.value as? String != "Selected" {
            control.tap()
            waitForSelected(control)
        }
        app.buttons["tab-read"].tap()
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
            let down = prior.midY < viewport.minY + 12
            let x = viewport.midX
            let y1 = down ? viewport.minY + 28 : viewport.maxY - 28
            let y2 = down ? viewport.maxY - 28 : viewport.minY + 28
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
        XCTAssertTrue(element.isHittable, "Control is not hittable", file: file, line: line)
        element.tap()
    }

    private func attachScreenshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
