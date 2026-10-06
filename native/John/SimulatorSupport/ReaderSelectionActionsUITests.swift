import XCTest

/// Uses a fresh task-only WEB-CE seed for each method.
/// Main owns the seed, project membership, and simulator run.
@MainActor
final class ReaderSelectionActionsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRemoveExistingVerseBookmark() throws {
        let app = XCUIApplication()
        openSeededJohnOne(in: app)
        selectVerseOne(in: app)

        let bookmark = app.buttons["reader-selection-bookmark"]
        XCTAssertTrue(bookmark.waitForExistence(timeout: 8))
        waitForValue(bookmark, equals: "Selected")
        bookmark.tap()
        waitForValue(bookmark, equals: "Not selected")
        XCTAssertTrue(app.staticTexts["reader-selection-reference"].label.contains("John 1:1"))
        NSLog("READER_SELECTION_ACTION removedBookmark=JHN:1:1 seedRequiresExistingBookmark=true")
    }

    func testClearMixedRangeHighlights() throws {
        let app = XCUIApplication()
        openSeededJohnOne(in: app)
        selectVerseOne(in: app)
        let second = app.buttons["reader-verse-2"]
        XCTAssertTrue(second.waitForExistence(timeout: 8))
        tapObservedWord(second, offset: CGPoint(x: 20, y: 14), in: app)

        let reference = app.staticTexts["reader-selection-reference"]
        XCTAssertTrue(reference.waitForExistence(timeout: 5))
        XCTAssertTrue(reference.label.contains("John 1:1–2"), reference.label)
        let clear = app.buttons["reader-highlight-clear"]
        XCTAssertTrue(clear.waitForExistence(timeout: 8), "Different saved colors must expose Remove highlight")
        clear.tap()
        XCTAssertTrue(clear.waitForNonExistence(timeout: 8), "Clear must remove every highlight in the selected range")
        for color in ["gold", "sage", "rose", "blue"] {
            waitForValue(app.buttons["reader-highlight-\(color)"], equals: "Not selected")
        }
        NSLog("READER_SELECTION_ACTION clearedMixedHighlights=JHN:1:1-2 seedRequiresGoldVerse1AndSageVerse2=true")
    }

    func testCopySelectedVerseText() throws {
        let app = XCUIApplication()
        openSeededJohnOne(in: app)
        let verse = app.buttons["reader-verse-1"]
        XCTAssertTrue(verse.waitForExistence(timeout: 8))
        let verseText = "In the beginning was the Word, and the Word was with God, and the Word was God."
        XCTAssertTrue(verse.label.contains(verseText), verse.label)
        selectVerseOne(in: app)

        let copy = app.buttons["reader-selection-copy"]
        XCTAssertTrue(copy.waitForExistence(timeout: 8))
        copy.tap()
        let feedback = app.staticTexts["reader-selection-feedback"]
        let copied = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS[c] %@", "copied"), object: feedback)
        XCTAssertEqual(XCTWaiter.wait(for: [copied], timeout: 8), .completed)
        XCTAssertTrue(feedback.label.contains("Passage copied"), feedback.label)
        NSLog("READER_SELECTION_ACTION copied=JHN:1:1 feedback=PassageCopied expectedPayload=1 \(verseText)\nJohn 1:1 (WEB-CE); Main checks simulator pasteboard")
    }

    private func openSeededJohnOne(in app: XCUIApplication) {
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        let read = app.buttons["tab-read"]
        XCTAssertTrue(read.waitForExistence(timeout: 10))
        read.tap()

        let book = app.buttons["reader-book-JHN"]
        if book.waitForExistence(timeout: 2) {
            book.tap()
        } else {
            let title = app.buttons["reader-title"]
            if title.waitForExistence(timeout: 3), !title.label.contains("John 1"),
               !app.buttons["reader-chapter-1"].exists {
                let back = app.buttons["reader-back"]
                XCTAssertTrue(back.waitForExistence(timeout: 8), "Reader must expose a visible back control")
                back.tap()
            }
        }
        let chapter = app.buttons["reader-chapter-1"]
        if chapter.waitForExistence(timeout: 8) { chapter.tap() }
        let title = app.buttons["reader-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(title.label.contains("John 1"), "Enter JHN 1 through visible Reader controls")
    }

    private func selectVerseOne(in app: XCUIApplication) {
        let verse = app.buttons["reader-verse-1"]
        XCTAssertTrue(verse.waitForExistence(timeout: 8))
        XCTAssertFalse(verse.isSelected, "Each fresh seed must start with no active Reader selection")
        verse.tap()
        let reference = app.staticTexts["reader-selection-reference"]
        let exact = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "John 1:1"), object: reference)
        XCTAssertEqual(XCTWaiter.wait(for: [exact], timeout: 8), .completed,
                       "The visible selection must be exactly JHN 1:1")
    }

    private func tapObservedWord(_ verse: XCUIElement, offset: CGPoint, in app: XCUIApplication) {
        XCTAssertTrue(verse.isHittable, "Verse must be visible before the owned-word tap")
        let point = CGPoint(x: verse.frame.minX + offset.x, y: verse.frame.minY + offset.y)
        XCTAssertTrue(verse.frame.contains(point), "Observed word point must stay inside the verse frame")
        XCTAssertTrue(app.frame.contains(point), "Observed word point must stay inside the app viewport")
        NSLog("READER_SELECTION_WORD_TAP id=%@ frame=%@ offset=%@ point=%@",
              verse.identifier, NSCoder.string(for: verse.frame), NSCoder.string(for: offset), NSCoder.string(for: point))
        verse.coordinate(withNormalizedOffset: CGVector(dx: offset.x / verse.frame.width,
                                                          dy: offset.y / verse.frame.height)).tap()
    }

    private func waitForValue(_ element: XCUIElement, equals value: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed,
                       "Expected committed accessibility value: \(value)", file: file, line: line)
    }
}
