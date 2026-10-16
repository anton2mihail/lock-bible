import XCTest
import UIKit

/// Slice B1a. Each test starts from the default native state (`-JohnResetNativeState`).
@MainActor
final class ReaderEnhanceB1aUITests: XCTestCase {
    private let verseOne = "In the beginning was the Word, and the Word was with God, and the Word was God."

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCopyPutsVerseWithReferenceOnPasteboard() throws {
        let app = launch(reset: true)
        openJohnOne(in: app)
        selectVerseOne(in: app)
        app.buttons["reader-selection-copy"].tap()
        XCTAssertTrue(app.staticTexts["reader-selection-feedback"].waitForExistence(timeout: 8))
        // The runner cannot read another app's pasteboard. Paste into the note editor and read the result.
        app.buttons["reader-selection-note"].tap()
        let editor = app.textViews["saved-note-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 8))
        editor.tap()
        let paste = app.menuItems["Paste"]
        if !paste.waitForExistence(timeout: 3) { editor.tap() }
        if paste.waitForExistence(timeout: 5) { paste.tap() }
        let allow = app.buttons["Allow Paste"]
        if allow.waitForExistence(timeout: 2) { allow.tap() }
        let value = editor.value as? String ?? ""
        XCTAssertTrue(value.contains(verseOne), value)
        XCTAssertTrue(value.hasSuffix(" — John 1:1 (WEB-CE)"), value)
        XCTAssertFalse(value.contains("\n"), value)
    }

    func testSelectionPanelOffersHighlightNoteShareCopy() throws {
        let app = launch(reset: true)
        openJohnOne(in: app)
        selectVerseOne(in: app)
        XCTAssertTrue(app.buttons["reader-highlight-gold"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["reader-selection-note"].exists)
        XCTAssertTrue(app.buttons["reader-selection-copy"].exists)
        XCTAssertTrue(app.buttons["reader-selection-share"].exists)
    }

    func testReaderShareLinkOpensShareSheet() throws {
        let app = launch(reset: true)
        openJohnOne(in: app)
        selectVerseOne(in: app)
        let share = app.buttons["reader-selection-share"]
        XCTAssertTrue(share.waitForExistence(timeout: 8))
        share.tap()
        let copy = app.cells.matching(NSPredicate(format: "label == %@", "Copy")).firstMatch
        let sheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 15) || copy.waitForExistence(timeout: 5),
                      "The Reader share link must open the system share sheet")
    }

    func testPinchChangesTextSizeAndPersists() throws {
        let app = launch(reset: true)
        openJohnOne(in: app)
        let verse = app.buttons["reader-verse-1"]
        XCTAssertTrue(verse.waitForExistence(timeout: 8))
        let before = verse.frame.height
        app.scrollViews.firstMatch.pinch(withScale: 1.5, velocity: 2)
        let grew = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in verse.frame.height > before + 1 }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [grew], timeout: 8), .completed,
                       "Pinch out must enlarge the text one step")
        let after = verse.frame.height
        app.terminate()

        let relaunched = launch(reset: false)
        openJohnOne(in: relaunched)
        let again = relaunched.buttons["reader-verse-1"]
        XCTAssertTrue(again.waitForExistence(timeout: 10))
        XCTAssertEqual(again.frame.height, after, accuracy: 2, "The new size must persist")
    }

    private func launch(reset: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never", "-JohnReaderMode", "scroll"]
        if reset { app.launchArguments += ["-JohnResetNativeState"] }
        app.launch()
        return app
    }

    private func openJohnOne(in app: XCUIApplication) {
        let read = app.tabBars.buttons["Read"]
        XCTAssertTrue(read.waitForExistence(timeout: 10))
        read.tap()
        let book = app.buttons["reader-book-JHN"]
        if book.waitForExistence(timeout: 2) { book.tap() }
        let chapter = app.buttons["reader-chapter-1"]
        if chapter.waitForExistence(timeout: 8) { chapter.tap() }
        let title = app.buttons["reader-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(title.label.contains("John 1"))
    }

    private func selectVerseOne(in app: XCUIApplication) {
        let verse = app.buttons["reader-verse-1"]
        XCTAssertTrue(verse.waitForExistence(timeout: 8))
        verse.tap()
        XCTAssertTrue(app.staticTexts["reader-selection-reference"].waitForExistence(timeout: 8))
    }
}
