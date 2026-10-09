import XCTest
import UIKit

@MainActor
final class NativeSmokeUITests: XCTestCase {
    func testReaderVerseWordPointDiagnostic() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))

        tabButton(app, "tab-settings").tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 8))
        let layout = app.buttons["settings-layout-verse-by-verse"]
        XCTAssertTrue(layout.waitForExistence(timeout: 8))
        if (layout.value as? String) != "Selected" { layout.tap() }
        let web = app.buttons["translation-web-ce"]
        XCTAssertTrue(web.waitForExistence(timeout: 8))
        if (web.value as? String) != "Selected" { web.tap() }
        tabButton(app, "tab-read").tap()

        let bookList = app.staticTexts["reader-book-list-title"]
        for _ in 0..<3 where !bookList.exists {
            let back = app.buttons["reader-back"]
            XCTAssertTrue(back.waitForExistence(timeout: 8))
            back.tap()
        }
        XCTAssertTrue(bookList.waitForExistence(timeout: 8))
        let john = app.buttons["reader-book-JHN"]
        XCTAssertTrue(john.waitForExistence(timeout: 8))
        john.tap()
        let chapter = app.buttons["reader-chapter-1"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 8))
        chapter.tap()
        XCTAssertTrue(app.buttons["reader-title"].waitForExistence(timeout: 8))

        for number in [10, 11, 12] {
            let verse = app.buttons["reader-verse-\(number)"]
            XCTAssertTrue(verse.waitForExistence(timeout: 8), "Missing JHN 1:\(number)")
            let scroll = app.scrollViews["reader-chapter-scroll"]
            XCTAssertTrue(scroll.waitForExistence(timeout: 8))
            var viewport = scroll.frame.intersection(app.frame)
            if let tabTop = tabBarTopEdge(in: app, within: viewport) {
                viewport.size.height = min(viewport.height, tabTop - viewport.minY)
            }
            for _ in 0..<12 {
                let frame = verse.frame
                if frame.minY >= viewport.minY + 8 && frame.maxY <= viewport.maxY - 8 { break }
                let above = frame.midY < viewport.midY
                let startFraction: CGFloat = above ? 0.25 : 0.75
                let endFraction: CGFloat = above ? 0.75 : 0.25
                let start = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * startFraction)
                let end = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * endFraction)
                app.coordinate(withNormalizedOffset: CGVector(dx: start.x / app.frame.width,
                                                               dy: start.y / app.frame.height))
                    .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(
                        dx: end.x / app.frame.width, dy: end.y / app.frame.height)))
                viewport = scroll.frame.intersection(app.frame)
                if let tabTop = tabBarTopEdge(in: app, within: viewport) {
                    viewport.size.height = min(viewport.height, tabTop - viewport.minY)
                }
            }
            XCTAssertTrue(verse.frame.minY >= viewport.minY + 8 && verse.frame.maxY <= viewport.maxY - 8,
                          "JHN 1:\(number) must be fully inside the Reader viewport")
            XCTAssertTrue(verse.isHittable)
            NSLog("READER_WORD_POINT id=%@ frame=%@ viewport=%@ label=%@",
                  verse.identifier, NSCoder.string(for: verse.frame), NSCoder.string(for: viewport), verse.label)
            verse.coordinate(withNormalizedOffset: CGVector(dx: 30 / verse.frame.width,
                                                              dy: 14 / verse.frame.height)).tap()
            let reference = app.staticTexts["reader-selection-reference"]
            let selected = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", "John 1:\(number)"), object: reference)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 8), .completed,
                           "The observed owned-word point must select exactly JHN 1:\(number)")
            attachScreenshot("reader-word-point-jhn-1-\(number)", app: app)
            app.buttons["reader-selection-close"].tap()
            XCTAssertTrue(app.staticTexts["reader-selection-reference"].waitForNonExistence(timeout: 5))
        }
    }

    func testSavedUndoGeometryProbe() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))
        tabButton(app, "tab-saved").tap()

        let bookmarkFilter = app.buttons["saved-filter-bookmark"]
        XCTAssertTrue(bookmarkFilter.waitForExistence(timeout: 5))
        bookmarkFilter.tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved-row-"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        let savedID = String(rows.firstMatch.identifier.dropFirst("saved-row-".count))
        app.buttons["saved-delete-\(savedID)"].tap()

        let undo = app.buttons["saved-undo-button"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        let savedTab = tabButton(app, "tab-saved")
        let settingsTab = tabButton(app, "tab-settings")
        NSLog("SAVED_UNDO_GEOMETRY undoFrame=%@ undoHittable=%@ savedTabFrame=%@ settingsTabFrame=%@",
              NSCoder.string(for: undo.frame), String(undo.isHittable),
              NSCoder.string(for: savedTab.frame), NSCoder.string(for: settingsTab.frame))
        attachScreenshot("saved-undo-geometry", app: app)
        XCTAssertTrue(undo.isHittable, "Undo must be visible above the tab bar")
        XCTAssertLessThanOrEqual(undo.frame.maxY, savedTab.frame.minY,
                                 "Undo must not overlap the tab bar")
        undo.tap()
        waitForRowCount(rows, 2)
        XCTAssertTrue(app.buttons["saved-row-\(savedID)"].exists,
                      "Undo must restore the exact deleted row")
    }

    func testValidLibrarySavedFiltersNoteEditDeleteAndUndo() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))

        tabButton(app, "tab-read").tap()
        let john = app.buttons["reader-book-JHN"]
        XCTAssertTrue(john.waitForExistence(timeout: 5))
        john.tap()
        let chapter = app.buttons["reader-chapter-1"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 5))
        chapter.tap()
        XCTAssertTrue(app.buttons["reader-verse-1"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["reader-title"].label.contains("John 1"))
        XCTAssertFalse(app.staticTexts["saved-status"].exists)
        attachScreenshot("valid-library-reader-john-1", app: app)

        tabButton(app, "tab-saved").tap()
        let allFilter = app.buttons["saved-filter-all"]
        XCTAssertTrue(allFilter.waitForExistence(timeout: 8))
        XCTAssertTrue(allFilter.isSelected)
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved-row-"))
        waitForRowCount(rows, 4)

        for (filter, expectedCount) in [("bookmark", 2), ("highlight", 1), ("note", 1)] {
            let button = app.buttons["saved-filter-\(filter)"]
            button.tap()
            XCTAssertTrue(button.isSelected, "The \(filter) filter must be selected")
            waitForRowCount(rows, expectedCount)
        }

        let noteRow = rows.firstMatch
        XCTAssertTrue(noteRow.label.contains("John 1:1"), "The note fixture must identify John 1:1: \(noteRow.label)")
        XCTAssertTrue(noteRow.label.contains("Note"))
        noteRow.tap()
        let editor = app.textViews["saved-note-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 8))
        XCTAssertEqual(editor.value as? String, "Synthetic migration fixture note.")
        editor.tap()
        editor.typeText(" UI-EDITED")
        app.buttons["saved-note-save"].tap()
        waitForDisappearance(editor)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved-row-")).firstMatch.waitForExistence(timeout: 8))

        let editedNoteRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved-row-")).firstMatch
        editedNoteRow.tap()
        let editedEditor = app.textViews["saved-note-editor"]
        XCTAssertTrue(editedEditor.waitForExistence(timeout: 8))
        XCTAssertTrue((editedEditor.value as? String ?? "").contains("UI-EDITED"), "The saved note must retain the edit")
        app.buttons["saved-note-delete"].tap()
        waitForDisappearance(editedEditor)
        waitForRowCount(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved-row-")), 0)
        XCTAssertTrue(app.staticTexts["saved-empty-state"].exists)
        attachScreenshot("valid-library-notes-after-delete", app: app)

        let bookmarkFilter = app.buttons["saved-filter-bookmark"]
        bookmarkFilter.tap()
        XCTAssertTrue(bookmarkFilter.isSelected)
        let bookmarkRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved-row-"))
        waitForRowCount(bookmarkRows, 2)
        let firstBookmark = bookmarkRows.firstMatch
        XCTAssertTrue(firstBookmark.label.contains("John 1:1") || firstBookmark.label.contains("John 3:16"))
        let savedID = String(firstBookmark.identifier.dropFirst("saved-row-".count))
        let deleteButton = app.buttons["saved-delete-\(savedID)"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()
        waitForRowCount(bookmarkRows, 1)
        let undo = app.buttons["saved-undo-button"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        NSLog("SAVED_UNDO_GEOMETRY undoFrame=%@ undoHittable=%@",
              NSCoder.string(for: undo.frame), String(undo.isHittable))
        guard undo.isHittable else {
            attachScreenshot("valid-library-undo-not-hittable", app: app)
            XCTFail("Undo must be visible and hittable above the tab bar")
            return
        }
        undo.tap()
        waitForRowCount(bookmarkRows, 2)
        attachScreenshot("valid-library-bookmarks-after-undo", app: app)

        let highlightFilter = app.buttons["saved-filter-highlight"]
        highlightFilter.tap()
        XCTAssertTrue(highlightFilter.isSelected)
        waitForRowCount(rows, 1)
        XCTAssertTrue(rows.firstMatch.label.contains("John 1:1"))

        allFilter.tap()
        XCTAssertTrue(allFilter.isSelected)
        waitForRowCount(rows, 3)
        XCTAssertFalse(app.staticTexts["saved-status"].exists)
    }

    func testSearchResultsAndSavedFilters() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))
        tabButton(app, "tab-read").tap()
        let searchButton = app.buttons["reader-search-button"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5))
        searchButton.tap()

        let field = app.textFields["search-query-input"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("in the beginning")
        let result = app.buttons["search-result-1"]
        XCTAssertTrue(result.waitForExistence(timeout: 10), "A Bible search must show a result.")
        XCTAssertTrue(app.staticTexts["search-result-count"].exists)
        let selectedReference = result.label.components(separatedBy: ".").first ?? ""
        XCTAssertFalse(selectedReference.isEmpty, "The first result must expose its reference.")
        let selectedBook = selectedReference.components(separatedBy: " ").first ?? ""
        attachScreenshot("L09-search-results", app: app)
        result.tap()
        XCTAssertTrue(app.buttons["reader-verse-1"].waitForExistence(timeout: 12), "A search result must open the Read root.")
        XCTAssertTrue(app.buttons["reader-title"].label.contains(selectedBook), "The Reader must open the selected search reference: \(selectedReference)")

        tabButton(app, "tab-saved").tap()
        XCTAssertTrue(app.buttons["saved-filter-all"].waitForExistence(timeout: 5))
        app.buttons["saved-filter-note"].tap()
        XCTAssertTrue(app.buttons["saved-filter-note"].isSelected)
        XCTAssertTrue(app.staticTexts["saved-empty-state"].exists ||
                      app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved-row-")).firstMatch.exists)
        attachScreenshot("L10-saved-empty-or-items", app: app)
    }

    func testVerseMomentReaderAndWorksFooter() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))

        let verseMomentAction = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Verse & lock screen widget")
        ).firstMatch
        XCTAssertTrue(verseMomentAction.waitForExistence(timeout: 8))
        verseMomentAction.tap()
        let pageTitle = app.staticTexts["content-page-title"]
        XCTAssertTrue(pageTitle.waitForExistence(timeout: 8))
        XCTAssertEqual(pageTitle.label, "Verse of the moment")
        let reference = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "^[1-3]?[A-Za-z ]+ [0-9]+:[0-9]+$")
        ).firstMatch
        XCTAssertTrue(reference.waitForExistence(timeout: 8), "The selected verse reference must be visible")
        let referenceParts = reference.label.split(separator: " ")
        let bookName = referenceParts.dropLast().joined(separator: " ")
        let coordinates = referenceParts.last?.split(separator: ":") ?? []
        XCTAssertEqual(coordinates.count, 2)
        let expectedChapter = coordinates.first.map(String.init) ?? ""
        let expectedVerse = coordinates.last.map(String.init) ?? ""
        XCTAssertTrue(app.buttons["verse-moment-read-context"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["verse-moment-scripture-card"].exists)
        attachScreenshot("L12-verse-moment", app: app)

        app.buttons["verse-moment-read-context"].tap()
        let readerTitle = app.buttons["reader-title"]
        XCTAssertTrue(readerTitle.waitForExistence(timeout: 12))
        XCTAssertEqual(readerTitle.label, "\(bookName) \(expectedChapter)")
        let requestedVerse = app.buttons["reader-verse-\(expectedVerse)"]
        XCTAssertTrue(requestedVerse.waitForExistence(timeout: 8), "Reader must show the requested verse")
        NSLog("L12_VERSE_MOMENT_READER title=%@ attribution=%@", readerTitle.label,
              app.staticTexts["reader-edition-attribution"].label)
        attachScreenshot("L08-reader-bottom-valid-library", app: app)
    }

    func testWorksReaderFooter() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(tabButton(app, "tab-read").waitForExistence(timeout: 10))
        tabButton(app, "tab-read").tap()
        let worksLink = app.buttons["reader-works-link"]
        XCTAssertTrue(worksLink.waitForExistence(timeout: 8))
        worksLink.tap()
        let collection = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "collection-")
        ).firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 12))
        collection.tap()

        let work = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "work-", "sections")
        ).firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 10), "Choose a work with multiple sections")
        work.tap()
        let prose = app.descendants(matching: .any).matching(identifier: "works-prose").firstMatch
        XCTAssertTrue(prose.waitForExistence(timeout: 15))
        let next = app.buttons["Next section"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        let savedTab = tabButton(app, "tab-saved")
        XCTAssertTrue(next.isHittable)
        XCTAssertLessThanOrEqual(next.frame.maxY, savedTab.frame.minY,
                                 "Works controls must stay above the shared tab bar")
        attachScreenshot("L20-works-reader-footer", app: app)
        let contents = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Contents, section 1 of")).firstMatch
        XCTAssertTrue(contents.exists)
        next.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Contents, section 2 of")).firstMatch.waitForExistence(timeout: 10))
    }

    func testScriptureCardExportsPNG() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Verse & lock screen widget")).firstMatch.tap()
        XCTAssertTrue(app.buttons["verse-moment-scripture-card"].waitForExistence(timeout: 10))
        app.buttons["verse-moment-scripture-card"].tap()
        XCTAssertTrue(app.staticTexts["content-page-title"].waitForExistence(timeout: 8))
        let export = app.buttons["scripture-card-share-image"]
        XCTAssertTrue(export.waitForExistence(timeout: 12))
        export.tap()
        NSLog("L19_SHARE_ACCESSIBILITY_TREE %@", app.debugDescription)
        let copyAction = app.cells.matching(NSPredicate(format: "label == %@", "Copy")).firstMatch
        XCTAssertTrue(copyAction.waitForExistence(timeout: 15), "The image share sheet must expose its Copy action")
        XCTAssertTrue(copyAction.isHittable, "The Copy action must be available in the share sheet")
        copyAction.tap()
        attachScreenshot("L19-scripture-card-share-sheet", app: app)
    }

    func testReaderSourceNavigationRangeAndVerseLayout() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        tabButton(app, "tab-settings").tap()
        app.buttons["translation-web-ce"].tap()
        app.buttons["settings-appearance-light"].tap()
        app.buttons["settings-text-size-default"].tap()
        app.buttons["settings-line-spacing-comfortable"].tap()
        app.buttons["settings-scripture-typeface-serif"].tap()
        app.buttons["settings-layout-paragraphs"].tap()
        tabButton(app, "tab-read").tap()

        app.buttons["reader-book-JHN"].tap()
        app.buttons["reader-chapter-1"].tap()
        let johnFirstVerse = app.buttons["reader-verse-1"]
        XCTAssertTrue(johnFirstVerse.waitForExistence(timeout: 12))
        attachScreenshot("L06-John-1", app: app)

        let expected = [
            ("10", "10–10", "9", ["10"]),
            ("12", "10–12", "9,10,11", ["10", "11", "12"]),
            ("8", "8–10", "7,8,9", ["8", "9", "10"]),
            ("8", "8–8", "7", ["8"]),
        ]
        for (label, range, indices, expectedSelectedLabels) in expected {
            let verse = app.buttons["reader-verse-\(label)"]
            XCTAssertTrue(verse.waitForExistence(timeout: 5))
            guard tapVerse(verse, in: app, horizontalFraction: label == "8" ? 0.90 : 0.50) else { return }
            XCTAssertTrue(app.buttons["reader-title"].exists, "A verse ink tap must keep the Reader open")
            let summary = app.staticTexts["reader-selection-summary"]
            XCTAssertTrue(summary.waitForExistence(timeout: 5))
            XCTAssertTrue(summary.label.contains(range), "Expected verse labels \(range), got \(summary.label)")
            let selectedLabels = (1...21).compactMap { value -> String? in
                let candidate = app.buttons["reader-verse-\(value)"]
                return candidate.exists && candidate.isSelected ? String(value) : nil
            }
            XCTAssertEqual(selectedLabels, expectedSelectedLabels,
                           "Expected selected verse labels \(expectedSelectedLabels), got \(selectedLabels)")
            NSLog("L06_RANGE expectedLabels=%@ expectedIndices=%@ observedSelectedLabels=%@",
                  range, indices, selectedLabels.joined(separator: ","))
        }
        guard tapVerse(app.buttons["reader-verse-8"], in: app, horizontalFraction: 0.90) else { return }
        XCTAssertFalse(app.staticTexts["reader-selection-summary"].exists)
        let clearedLabels = (1...21).compactMap { value -> String? in
            let candidate = app.buttons["reader-verse-\(value)"]
            return candidate.exists && candidate.isSelected ? String(value) : nil
        }
        XCTAssertTrue(clearedLabels.isEmpty, "The third tap on verse 8 must clear selection")

        guard tapVerse(app.buttons["reader-verse-10"], in: app) else { return }
        XCTAssertTrue(app.buttons["reader-verse-10"].isSelected)
        app.buttons["reader-appearance-button"].tap()
        // The Aa sheet uses the Settings choice buttons (audit B2), not a menu picker.
        let layout = app.buttons["settings-layout-verse-by-verse"]
        XCTAssertTrue(layout.waitForExistence(timeout: 5))
        layout.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Selected"), object: layout)], timeout: 6), .completed)
        app.buttons["reader-appearance-close"].tap()
        XCTAssertTrue(app.buttons["reader-verse-10"].isSelected, "Aa must retain the selected verse")
        attachScreenshot("L08-John-1-verse-layout-selected", app: app)

        app.buttons["reader-back"].tap()
        app.buttons["reader-back"].tap()
        let psalmsBook = app.buttons["reader-book-PSA"]
        XCTAssertTrue(psalmsBook.waitForExistence(timeout: 5))
        psalmsBook.tap()
        let psalm149 = app.buttons["reader-chapter-149"]
        XCTAssertTrue(psalm149.waitForExistence(timeout: 5))
        let chapterScroll = app.scrollViews["reader-chapter-grid-scroll"]
        for _ in 0..<16 where !chapterScroll.frame.contains(psalm149.frame) { chapterScroll.swipeUp() }
        XCTAssertTrue(chapterScroll.frame.contains(psalm149.frame), "The chapter grid must show Psalm 149 before the first tap")
        psalm149.tap()
        XCTAssertTrue(app.buttons["reader-verse-1"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["reader-title"].label.contains("149"))
        app.buttons["reader-back"].tap()
        XCTAssertTrue(app.buttons["reader-chapter-149"].waitForExistence(timeout: 5))
        let selected149 = app.buttons["reader-chapter-149"]
        XCTAssertTrue(selected149.isHittable, "Back must reveal the current Psalm chapter cell")
        XCTAssertTrue(selected149.isSelected, "Back must mark the current Psalm chapter")
        selected149.tap()
        XCTAssertTrue(app.buttons["reader-verse-1"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["reader-title"].label.contains("149"))
        attachScreenshot("L06-Psalm-149", app: app)
        app.buttons["reader-title"].tap()
        let goTo149 = app.buttons["go-to-chapter-PSA-149"]
        XCTAssertTrue(goTo149.waitForExistence(timeout: 5))
        XCTAssertTrue(goTo149.isHittable, "Go To must reveal the selected Psalm 149 cell")

        app.buttons["go-to-cancel"].tap()
        app.buttons["reader-back"].tap()
        app.buttons["reader-back"].tap()
        app.buttons["reader-book-SNG"].tap()
        app.buttons["reader-chapter-1"].tap()
        XCTAssertTrue(app.buttons["reader-verse-1"].waitForExistence(timeout: 10))
        attachScreenshot("L07-Song-1", app: app)
        XCTAssertTrue(app.staticTexts.matching(identifier: "reader-heading-sp").firstMatch.exists)
    }

    func testReaderRealVisibleVerseTapRange() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))
        tabButton(app, "tab-read").tap()
        XCTAssertTrue(app.buttons["reader-book-JHN"].waitForExistence(timeout: 5))
        app.buttons["reader-book-JHN"].tap()
        XCTAssertTrue(app.buttons["reader-chapter-1"].waitForExistence(timeout: 5))
        app.buttons["reader-chapter-1"].tap()
        XCTAssertTrue(app.buttons["reader-verse-1"].waitForExistence(timeout: 12))
        let expected = [
            ("10", "10–10", ["10"]),
            ("12", "10–12", ["10", "11", "12"]),
            ("8", "8–10", ["8", "9", "10"]),
            ("8", "8–8", ["8"]),
        ]
        for (label, range, expectedLabels) in expected {
            guard tapVerse(app.buttons["reader-verse-\(label)"], in: app,
                           horizontalFraction: label == "8" ? 0.90 : 0.50) else { return }
            XCTAssertTrue(app.buttons["reader-title"].exists, "A verse tap must keep the Reader open")
            let summary = app.staticTexts["reader-selection-summary"]
            XCTAssertTrue(summary.waitForExistence(timeout: 5))
            XCTAssertTrue(summary.label.contains(range), "Expected range \(range), got \(summary.label)")
            let selectedLabels = (1...21).compactMap { value -> String? in
                let candidate = app.buttons["reader-verse-\(value)"]
                return candidate.exists && candidate.isSelected ? String(value) : nil
            }
            XCTAssertEqual(selectedLabels, expectedLabels)
            NSLog("L06_RANGE labels=%@ observedSelectedLabels=%@", range, selectedLabels.joined(separator: ","))
        }
        guard tapVerse(app.buttons["reader-verse-8"], in: app, horizontalFraction: 0.90) else { return }
        XCTAssertFalse(app.staticTexts["reader-selection-summary"].exists)
        let selectedLabels = (1...21).compactMap { value -> String? in
            let candidate = app.buttons["reader-verse-\(value)"]
            return candidate.exists && candidate.isSelected ? String(value) : nil
        }
        XCTAssertTrue(selectedLabels.isEmpty, "The third tap on verse 8 must clear the range")
        guard tapVerse(app.buttons["reader-verse-1"], in: app, lineFraction: 0.72) else { return }
        XCTAssertTrue(app.staticTexts["reader-selection-summary"].label.contains("1–1"),
                      "A tap on the wrapped continuation must select its verse")
    }

    func testReaderSelectionBookmarkAndAllHighlightColors() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))
        tabButton(app, "tab-read").tap()
        XCTAssertTrue(app.buttons["reader-book-JHN"].waitForExistence(timeout: 8))
        app.buttons["reader-book-JHN"].tap()
        XCTAssertTrue(app.buttons["reader-chapter-1"].waitForExistence(timeout: 5))
        app.buttons["reader-chapter-1"].tap()
        XCTAssertTrue(app.buttons["reader-verse-1"].waitForExistence(timeout: 12))
        XCTAssertTrue(tapVerse(app.buttons["reader-verse-10"], in: app),
                      "Verse 10 must have a visible owned-text tap point")

        let summary = app.staticTexts["reader-selection-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.contains("10–10"))
        let bookmark = app.buttons["reader-selection-bookmark"]
        let note = app.buttons["reader-selection-note"]
        XCTAssertTrue(bookmark.waitForExistence(timeout: 5))
        XCTAssertTrue(note.exists)
        XCTAssertTrue(app.buttons["reader-selection-copy"].exists)
        XCTAssertTrue(app.buttons["reader-selection-share"].exists)
        XCTAssertTrue(app.buttons["reader-selection-pray"].exists)
        XCTAssertTrue(app.buttons["reader-selection-card"].exists)
        attachScreenshot("L08-selection-toolbar-John-1-10", app: app)

        let wasBookmarked = (bookmark.value as? String) == "Selected"
        bookmark.tap()
        let expectedBookmarkState = wasBookmarked ? "Not selected" : "Selected"
        let bookmarkChanged = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expectedBookmarkState), object: bookmark)
        XCTAssertEqual(XCTWaiter.wait(for: [bookmarkChanged], timeout: 8), .completed,
                       "The exact selected passage bookmark must change after the write")
        let bookmarkFeedback = app.staticTexts["reader-selection-feedback"]
        let expectedBookmarkFeedback = wasBookmarked ? "Bookmark removed" : "Bookmark saved"
        let feedbackChanged = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expectedBookmarkFeedback), object: bookmarkFeedback)
        XCTAssertEqual(XCTWaiter.wait(for: [feedbackChanged], timeout: 8), .completed)

        for color in ["gold", "sage", "rose", "blue"] {
            let swatch = app.buttons["reader-highlight-\(color)"]
            XCTAssertTrue(swatch.waitForExistence(timeout: 5))
            if (swatch.value as? String) == "Selected" {
                swatch.tap()
                let cleared = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "value == %@", "Not selected"), object: swatch)
                XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 8), .completed)
            }
            swatch.tap()
            let applied = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", "Selected"), object: swatch)
            XCTAssertEqual(XCTWaiter.wait(for: [applied], timeout: 8), .completed,
                           "The \(color) highlight must become selected after the write")
            NSLog("L08_SELECTION_ACTION passage=JHN:1:10 highlight=%@ saved=true", color)
        }
        app.buttons["reader-highlight-blue"].tap()
        let removed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"), object: app.buttons["reader-highlight-clear"])
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 8), .completed,
                       "The active swatch must remove the saved highlight")
        attachScreenshot("L08-selection-actions-complete", app: app)
        NSLog("L08_SELECTION_ACTION passage=JHN:1:10 bookmark=%@ highlight=all-four clear=true",
              wasBookmarked ? "removed" : "saved")
    }

    func testReaderAnchorReflowRestartAndLowerControls() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))
        tabButton(app, "tab-read").tap()
        let book = app.buttons["reader-book-JHN"]
        XCTAssertTrue(book.waitForExistence(timeout: 6))
        book.tap()
        let chapter = app.buttons["reader-chapter-1"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 6))
        chapter.tap()

        let reader = app.scrollViews["reader-chapter-scroll"]
        XCTAssertTrue(reader.waitForExistence(timeout: 12))
        let savedTab = tabButton(app, "tab-saved")
        let title = app.buttons["reader-title"]
        let safeTop = CGFloat((reader.value as? String).flatMap(Double.init) ?? -1)
        NSLog("L08_READER_GEOMETRY safeTop=%.1f viewport=%@ tabs=%@",
              safeTop, NSCoder.string(for: reader.frame),
              NSCoder.string(for: savedTab.frame))
        XCTAssertGreaterThan(safeTop, 0, "The process window must report its top safe-area inset")
        let visibleViewportBottom = tabBarTopEdge(in: app, within: app.frame) ?? savedTab.frame.minY
        XCTAssertGreaterThan(min(reader.frame.maxY, visibleViewportBottom) - reader.frame.minY, 0,
                             "Reader must have a visible scroll area above the tab bar")

        for _ in 0..<12 { reader.swipeUp() }
        let next = app.buttons["reader-next-chapter"]
        let previous = app.buttons["reader-previous-chapter"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        XCTAssertTrue(previous.exists)
        for _ in 0..<12 where !next.isHittable { reader.swipeUp() }
        XCTAssertTrue(next.isHittable, "The next control must be reachable at the end of the chapter")
        XCTAssertTrue(previous.isHittable, "The previous control must be reachable at the end of the chapter")
        XCTAssertLessThanOrEqual(next.frame.maxY, visibleViewportBottom)
        XCTAssertLessThanOrEqual(previous.frame.maxY, visibleViewportBottom)
        attachScreenshot("L08-reader-lower-controls-at-maximum-scroll", app: app)

        let anchorValue = waitForSavedAnchor(title)
        XCTAssertNotNil(anchorValue, "Idle scrolling must save a visible verse and UTF-16 anchor")
        guard let anchorValue,
              let token = anchorValue.components(separatedBy: "anchor=").last?.components(separatedBy: ";").first,
              let label = token.split(separator: ":").first,
              let verseNumber = Int(label) else { return }
        NSLog("L08_READER_ANCHOR after-footer-scroll=%@", anchorValue)
        XCTAssertGreaterThan(verseNumber, 1,
                             "The test must save an unselected anchor after scrolling past verse 1")

        tabButton(app, "tab-settings").tap()
        let defaultSize = app.buttons["settings-text-size-default"]
        let largeSize = app.buttons["settings-text-size-large"]
        XCTAssertTrue(defaultSize.waitForExistence(timeout: 6))
        XCTAssertTrue(largeSize.exists)
        let wasLarge = (largeSize.value as? String) == "Selected"
        let targetSize = wasLarge ? defaultSize : largeSize
        targetSize.tap()
        let committedSize = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Selected"), object: targetSize)
        XCTAssertEqual(XCTWaiter.wait(for: [committedSize], timeout: 6), .completed,
                       "The new text size must commit before the anchor check")
        XCTAssertNotEqual(wasLarge, (largeSize.value as? String) == "Selected",
                          "The test must change the committed text size")
        tabButton(app, "tab-read").tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue((title.value as? String ?? "").contains("anchor=\(token)"),
                      "Text-size reflow must keep the same saved verse and UTF-16 offset")
        let reflowVerse = app.buttons["reader-verse-\(verseNumber)"]
        XCTAssertTrue(reflowVerse.waitForExistence(timeout: 8))
        XCTAssertTrue(reader.frame.intersects(reflowVerse.frame), "The saved anchor verse must remain in the viewport after reflow")
        attachScreenshot("L08-reader-anchor-after-large-text", app: app)

        app.terminate()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))
        tabButton(app, "tab-read").tap()
        let continueReading = app.buttons["reader-continue-reading"]
        XCTAssertTrue(continueReading.waitForExistence(timeout: 8))
        continueReading.tap()
        let restoredTitle = app.buttons["reader-title"]
        XCTAssertTrue(restoredTitle.waitForExistence(timeout: 12))
        XCTAssertTrue((restoredTitle.value as? String ?? "").contains("anchor=\(token)"),
                      "A fresh process must restore the same verse and UTF-16 offset")
        let restoredVerse = app.buttons["reader-verse-\(verseNumber)"]
        XCTAssertTrue(restoredVerse.waitForExistence(timeout: 8))
        XCTAssertTrue(reader.frame.intersects(restoredVerse.frame))
        attachScreenshot("L08-reader-anchor-after-restart", app: app)
    }

    func testReaderTopSafeAreaAndSmallScrollProbe() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))
        tabButton(app, "tab-read").tap()
        let john = app.buttons["reader-book-JHN"]
        XCTAssertTrue(john.waitForExistence(timeout: 8))
        john.tap()
        let chapterOne = app.buttons["reader-chapter-1"]
        XCTAssertTrue(chapterOne.waitForExistence(timeout: 8))
        chapterOne.tap()

        let reader = app.scrollViews["reader-chapter-scroll"]
        XCTAssertTrue(reader.waitForExistence(timeout: 12))
        let title = app.buttons["reader-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        let firstVerse = app.buttons["reader-verse-1"]
        XCTAssertTrue(firstVerse.waitForExistence(timeout: 8))
        let safeTop = CGFloat((reader.value as? String).flatMap(Double.init) ?? -1)
        NSLog("L08_TOP_PROBE stage=top safeTop=%.1f viewport=%@ title=%@ verse1=%@",
              safeTop, NSCoder.string(for: reader.frame),
              NSCoder.string(for: title.frame), NSCoder.string(for: firstVerse.frame))
        XCTAssertGreaterThan(safeTop, 0)
        attachScreenshot("L08-reader-chapter-top", app: app)

        let initialVerseY = firstVerse.frame.minY
        let readerHeight = max(reader.frame.height, 1)
        let startFraction: CGFloat = 0.65
        let dragDistance: CGFloat = min(40, readerHeight * 0.4)
        let endFraction = max(0.05, startFraction - dragDistance / readerHeight)
        let start = reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startFraction))
        let end = reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endFraction))
        NSLog("L08_TOP_PROBE_DRAG distance=%.1f startFraction=%.3f endFraction=%.3f viewport=%@",
              readerHeight * (startFraction - endFraction), startFraction, endFraction,
              NSCoder.string(for: reader.frame))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
        let moved = NSPredicate { _, _ in firstVerse.frame.minY < initialVerseY - 1 }
        let movedWait = XCTNSPredicateExpectation(predicate: moved, object: firstVerse)
        XCTAssertEqual(XCTWaiter.wait(for: [movedWait], timeout: 3), .completed,
                       "The small upward drag must move the visible verse upward")
        NSLog("L08_TOP_PROBE stage=small-scroll viewport=%@ title=%@ verse1=%@",
              NSCoder.string(for: reader.frame), NSCoder.string(for: title.frame),
              NSCoder.string(for: firstVerse.frame))
        attachScreenshot("L08-reader-small-scroll", app: app)
    }

    func testReaderChapterGridGoToAndAaReachableAtSystemXXXL() throws {
        assertSystemXXXLProfile()
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))

        tabButton(app, "tab-read").tap()
        let psalms = app.buttons["reader-book-PSA"]
        let bookList = app.scrollViews["reader-book-list"]
        XCTAssertTrue(bookList.waitForExistence(timeout: 8), "Read must show the book list at XXXL")
        let bookViewport = try scrollTargetIntoVisibleArea(psalms, in: bookList, app: app,
                                                           avoidTabBar: true, allowLazyTarget: true)
        XCTAssertTrue(bookViewport.contains(psalms.frame), "Psalms must be fully visible before the tap at XXXL")
        XCTAssertTrue(psalms.isHittable, "Psalms must be reachable before the tap at XXXL")
        psalms.tap()
        let chapterScroll = app.scrollViews["reader-chapter-grid-scroll"]
        XCTAssertTrue(chapterScroll.waitForExistence(timeout: 8), "The Reader chapter grid must open at XXXL")
        let psalm149 = app.buttons["reader-chapter-149"]
        let chapterViewport = try scrollTargetIntoVisibleArea(psalm149, in: chapterScroll, app: app,
                                                              avoidTabBar: true, allowLazyTarget: true,
                                                              targetName: "reader-chapter-149")
        XCTAssertTrue(chapterViewport.contains(psalm149.frame),
                      "Psalm 149 must be fully visible above the tab bar at XXXL")
        XCTAssertTrue(psalm149.isHittable, "Psalm 149 must be reachable at XXXL")
        attachScreenshot("reader-chapter-grid-xxxl-psalm-149", app: app)
        psalm149.tap()
        XCTAssertTrue(app.buttons["reader-title"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["reader-title"].label.contains("149"),
                      "The selected chapter must open at XXXL")

        app.buttons["reader-title"].tap()
        let goTo149 = app.buttons["go-to-chapter-PSA-149"]
        XCTAssertTrue(goTo149.waitForExistence(timeout: 8), "Go To must expose Psalm 149 at XXXL")
        let goToScroll = app.scrollViews.containing(.any, identifier: goTo149.identifier).firstMatch
        XCTAssertTrue(goToScroll.waitForExistence(timeout: 5),
                      "Go To must use its foreground sheet scroll view")
        let goToViewport = try scrollTargetIntoVisibleArea(goTo149, in: goToScroll, app: app,
                                                           avoidTabBar: false)
        XCTAssertTrue(goToViewport.contains(goTo149.frame),
                      "The selected Go To chapter must be fully visible in the sheet at XXXL")
        XCTAssertTrue(goTo149.isHittable, "The selected Go To chapter must be reachable at XXXL")
        attachScreenshot("reader-go-to-grid-xxxl-psalm-149", app: app)
        app.buttons["go-to-cancel"].tap()

        let appearance = app.buttons["reader-appearance-button"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 8), "Reader Aa must be available at XXXL")
        appearance.tap()
        XCTAssertTrue(app.buttons["reader-appearance-close"].waitForExistence(timeout: 5),
                      "The Aa sheet must open at XXXL")
        attachScreenshot("reader-aa-sheet-xxxl", app: app)

        let appearanceIDs = [
            "settings-text-size-default",
            "settings-line-spacing-comfortable",
            "settings-scripture-typeface-serif",
            "settings-layout-paragraphs",
            "settings-appearance-system",
        ]
        for identifier in appearanceIDs {
            let control = app.buttons[identifier]
            XCTAssertTrue(control.waitForExistence(timeout: 5), "Missing Aa control at XXXL: \(identifier)")
            let sheetScroll = app.scrollViews.containing(.any, identifier: identifier).firstMatch
            XCTAssertTrue(sheetScroll.exists && sheetScroll.isHittable,
                          "Aa control must belong to the foreground sheet scroll: \(identifier)")
            let viewport = try scrollTargetIntoVisibleArea(control, in: sheetScroll, app: app,
                                                           avoidTabBar: false)
            XCTAssertTrue(viewport.contains(control.frame),
                          "Aa control must be fully visible when reached at XXXL: \(identifier)")
            XCTAssertTrue(control.isHittable, "Aa control must be reachable at XXXL: \(identifier)")
        }
        attachScreenshot("reader-aa-sheet-xxxl-controls-reached", app: app)
    }

    func testReaderAppearanceAccessibilityValues() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))
        tabButton(app, "tab-settings").tap()
        let layoutOptions = ["settings-layout-paragraphs", "settings-layout-verse-by-verse"]
        let selectedLayout = layoutOptions.first { app.buttons[$0].value as? String == "Selected" }
        XCTAssertNotNil(selectedLayout, "Full Settings must expose the committed layout choice")
        let expectedLayout = selectedLayout == "settings-layout-verse-by-verse" ? "Verse by verse" : "Paragraphs"

        tabButton(app, "tab-read").tap()
        let john = app.buttons["reader-book-JHN"]
        XCTAssertTrue(john.waitForExistence(timeout: 8))
        john.tap()
        let chapterOne = app.buttons["reader-chapter-1"]
        XCTAssertTrue(chapterOne.waitForExistence(timeout: 8))
        chapterOne.tap()
        let appearance = app.buttons["reader-appearance-button"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 8))
        appearance.tap()

        // The Aa sheet shows the Settings choice buttons (audit B2). The committed choice reads "Selected".
        // The sheet has no Bible edition control (the old Aa sheet had none). The edition stays in Settings.
        let expected = [
            "settings-text-size-default",
            "settings-line-spacing-comfortable",
            "settings-scripture-typeface-serif",
            selectedLayout ?? "settings-layout-paragraphs",
            "settings-appearance-system",
        ]
        for identifier in expected {
            let control = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            XCTAssertTrue(control.waitForExistence(timeout: 5), "Missing Reader appearance control: \(identifier)")
            XCTAssertEqual(control.value as? String, "Selected", "Wrong Reader appearance value: \(identifier)")
        }
        NSLog("READER_AA_EXPECTED layout=%@", expectedLayout)
        attachScreenshot("reader-appearance-accessibility-values", app: app)
    }

    func testPsalmTwoLoadedVerseGeometryDiagnostic() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))

        tabButton(app, "tab-settings").tap()
        let edition = app.buttons["translation-web-ce"]
        XCTAssertTrue(edition.waitForExistence(timeout: 8))
        if edition.value as? String != "Selected" { edition.tap() }
        let layout = app.buttons["settings-layout-verse-by-verse"]
        XCTAssertTrue(layout.waitForExistence(timeout: 8))
        if layout.value as? String != "Selected" { layout.tap() }

        tabButton(app, "tab-read").tap()
        let psalms = app.buttons["reader-book-PSA"]
        XCTAssertTrue(psalms.waitForExistence(timeout: 10))
        psalms.tap()
        let chapter = app.buttons["reader-chapter-2"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 10))
        chapter.tap()

        let first = app.buttons["reader-verse-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["reader-verse-12"].waitForExistence(timeout: 15))
        let reader = app.scrollViews["reader-chapter-scroll"]
        NSLog("CARD_GLYPH_PROBE reader=%@ verse1=%@ label=%@ selected=%@",
              NSCoder.string(for: reader.frame), NSCoder.string(for: first.frame),
              first.label, String(first.isSelected))
        attachScreenshot("psalm-2-loaded-verse-1-geometry", app: app)

        let point = CGPoint(x: 120, y: 195)
        NSLog("CARD_GLYPH_TAP point=%@ verse1=%@", NSCoder.string(for: point), NSCoder.string(for: first.frame))
        app.coordinate(withNormalizedOffset: CGVector(dx: point.x / app.frame.width,
                                                       dy: point.y / app.frame.height)).tap()
        XCTAssertTrue(app.staticTexts["reader-selection-summary"].waitForExistence(timeout: 5),
                      "The observed word point must activate verse 1")
        XCTAssertTrue(first.isSelected, "The observed word point must select verse 1")
    }

    func testPsalmTwoVerseTwelveGeometryDiagnostic() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))

        tabButton(app, "tab-settings").tap()
        let edition = app.buttons["translation-web-ce"]
        XCTAssertTrue(edition.waitForExistence(timeout: 8))
        if edition.value as? String != "Selected" { edition.tap() }
        let layout = app.buttons["settings-layout-verse-by-verse"]
        XCTAssertTrue(layout.waitForExistence(timeout: 8))
        if layout.value as? String != "Selected" { layout.tap() }

        tabButton(app, "tab-read").tap()
        let psalms = app.buttons["reader-book-PSA"]
        XCTAssertTrue(psalms.waitForExistence(timeout: 10))
        psalms.tap()
        let chapter = app.buttons["reader-chapter-2"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 10))
        chapter.tap()

        let reader = app.scrollViews["reader-chapter-scroll"]
        let last = app.buttons["reader-verse-12"]
        XCTAssertTrue(last.waitForExistence(timeout: 15))
        let tab = tabButton(app, "tab-saved")
        for _ in 0..<8 where last.frame.maxY > min(reader.frame.maxY, tab.frame.minY) - 12 {
            reader.swipeUp()
        }
        XCTAssertTrue(last.frame.minY >= reader.frame.minY && last.frame.maxY <= tab.frame.minY,
                      "Verse 12 must be fully visible above the tabs")
        NSLog("CARD_GLYPH_PROBE verse12 reader=%@ verse12=%@ label=%@ tab=%@",
              NSCoder.string(for: reader.frame), NSCoder.string(for: last.frame),
              last.label, NSCoder.string(for: tab.frame))
        attachScreenshot("psalm-2-loaded-verse-12-geometry", app: app)

        let point = CGPoint(x: 120, y: 324)
        NSLog("CARD_GLYPH_TAP verse12 point=%@ frame=%@", NSCoder.string(for: point), NSCoder.string(for: last.frame))
        app.coordinate(withNormalizedOffset: CGVector(dx: point.x / app.frame.width,
                                                       dy: point.y / app.frame.height)).tap()
        XCTAssertTrue(app.staticTexts["reader-selection-summary"].waitForExistence(timeout: 5),
                      "The observed word point must activate verse 12")
        XCTAssertTrue(last.isSelected, "The observed word point must select verse 12")
    }

    private func attachScreenshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertSystemXXXLProfile(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(ProcessInfo.processInfo.environment["L25_CONTENT_SIZE"],
                       "accessibility-extra-extra-extra-large", file: file, line: line)
        XCTAssertEqual(UITraitCollection.current.preferredContentSizeCategory,
                       .accessibilityExtraExtraExtraLarge,
                       "The UI test process must read back the system XXXL category", file: file, line: line)
    }

    private func scrollTargetIntoVisibleArea(_ target: XCUIElement, in scroll: XCUIElement,
                                             app: XCUIApplication, avoidTabBar: Bool,
                                             allowLazyTarget: Bool = false,
                                             targetName: String? = nil,
                                             file: StaticString = #filePath,
                                             line: UInt = #line) throws -> CGRect {
        let safeTargetName = targetName ?? (target.exists ? target.identifier : "unresolved-lazy-target")
        if !allowLazyTarget {
            XCTAssertTrue(target.waitForExistence(timeout: 8), "Missing scroll target: \(safeTargetName)",
                          file: file, line: line)
        }
        XCTAssertTrue(scroll.exists && scroll.isHittable,
                      "Target scroll view must be visible: target=\(safeTargetName) scroll=\(scroll.identifier)",
                      file: file, line: line)
        let initialFrame = target.exists ? target.frame : .zero
        var previousY = initialFrame.minY
        var hadTargetFrame = !initialFrame.isEmpty
        var stalled = 0
        for attempt in 0..<40 {
            let viewport = safeVisibleViewport(for: scroll, in: app, avoidTabBar: avoidTabBar).insetBy(dx: 4, dy: 4)
            let targetExists = target.exists
            let targetFrame = targetExists ? target.frame : .zero
            if targetExists && !targetFrame.isEmpty && viewport.contains(targetFrame) && target.isHittable {
                return viewport
            }
            XCTAssertGreaterThan(viewport.height, 100,
                                 "No safe visible scroll area for target \(safeTargetName): \(viewport)",
                                 file: file, line: line)
            let swipeUp = !targetExists || targetFrame.isEmpty || targetFrame.minY >= viewport.maxY
                || (targetFrame.intersects(viewport) && targetFrame.midY >= viewport.midY)
            let startFraction: CGFloat = swipeUp ? 0.75 : 0.25
            let endFraction: CGFloat = swipeUp ? 0.25 : 0.75
            let start = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * startFraction)
            let end = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * endFraction)
            NSLog("XXXL_SCROLL attempt=%d id=%@ scroll=%@ frame=%@ viewport=%@ direction=%@",
                  attempt, safeTargetName, scroll.identifier, NSCoder.string(for: targetFrame),
                  NSCoder.string(for: viewport), swipeUp ? "up" : "down")
            app.coordinate(withNormalizedOffset: normalized(start, in: app))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: normalized(end, in: app)))
            XCTAssertTrue(scroll.exists && scroll.isHittable,
                          "Foreground scroll disappeared after drag: \(scroll.identifier)", file: file, line: line)
            let currentExists = target.exists
            let currentFrame = currentExists ? target.frame : .zero
            if currentExists && !currentFrame.isEmpty {
                if hadTargetFrame && abs(currentFrame.minY - previousY) < 1 {
                    stalled += 1
                } else {
                    stalled = 0
                }
                previousY = currentFrame.minY
                hadTargetFrame = true
            } else {
                // A lazy grid can omit a far cell from accessibility until the scroll reaches it.
                stalled = 0
            }
            XCTAssertLessThan(stalled, 4,
                              "Scroll made no progress for target \(safeTargetName): frame=\(currentFrame)",
                              file: file, line: line)
        }
        let viewport = safeVisibleViewport(for: scroll, in: app, avoidTabBar: avoidTabBar).insetBy(dx: 4, dy: 4)
        let finalTargetExists = target.exists
        let finalTargetFrame = finalTargetExists ? target.frame : .zero
        let finalTargetIsHittable = finalTargetExists && target.isHittable
        XCTAssertTrue(finalTargetExists, "Target did not appear after bounded scroll: \(safeTargetName)",
                      file: file, line: line)
        XCTAssertTrue(finalTargetExists && viewport.contains(finalTargetFrame) && finalTargetIsHittable,
                      "Target did not become fully visible and hittable: id=\(safeTargetName) frame=\(finalTargetFrame) viewport=\(viewport)",
                      file: file, line: line)
        return viewport
    }

    private func safeVisibleViewport(for scroll: XCUIElement, in app: XCUIApplication,
                                     avoidTabBar: Bool) -> CGRect {
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
        if avoidTabBar, let tabTop = tabBarTopEdge(in: app, within: viewport),
           tabTop > viewport.minY, tabTop < viewport.maxY {
            viewport.size.height = min(viewport.height, tabTop - viewport.minY)
        }
        return viewport
    }

    private func normalized(_ point: CGPoint, in app: XCUIApplication) -> CGVector {
        let frame = app.frame
        return CGVector(dx: (point.x - frame.minX) / frame.width,
                        dy: (point.y - frame.minY) / frame.height)
    }

    private func waitForRowCount(_ rows: XCUIElementQuery, _ expected: Int,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(8)
        while rows.count != expected, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTAssertEqual(rows.count, expected, "Expected \(expected) Saved rows, found \(rows.count)", file: file, line: line)
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5,
                                      file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while element.exists, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTAssertFalse(element.exists, "The note editor sheet must close after the action", file: file, line: line)
    }

    private func waitForSavedAnchor(_ title: XCUIElement,
                                    timeout: TimeInterval = 8) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let value = title.value as? String ?? ""
            if value.range(of: #"anchor=[0-9]+:[0-9]+"#, options: .regularExpression) != nil {
                return value
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return nil
    }

    private func select(_ identifier: String, value: String) {
        let picker = XCUIApplication().buttons[identifier]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        XCUIApplication().buttons[value].tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 3))
    }

    private func tapVerse(_ verse: XCUIElement, in app: XCUIApplication,
                          lineFraction: CGFloat = 0.18, horizontalFraction: CGFloat = 0.50) -> Bool {
        let reader = app.scrollViews["reader-chapter-scroll"]
        let tabBar = tabButton(app, "tab-saved")
        for _ in 0..<12 {
            let content = visibleReaderRect(reader, tabBar: tabBar, in: app)
            let frame = verse.frame
            if content.insetBy(dx: 0, dy: 12).contains(frame) { break }
            if frame.maxY <= content.minY + 12 { reader.swipeDown() }
            else if frame.minY >= content.maxY - 12 { reader.swipeUp() }
            else { break }
        }
        let usableReader = visibleReaderRect(reader, tabBar: tabBar, in: app)
        let visible = usableReader.intersection(verse.frame)
        guard visible.height >= 30, visible.width > 0, visible.midX.isFinite, visible.minY.isFinite else {
            XCTFail("Verse \(verse.identifier) has no finite visible text area. Frame: \(verse.frame). Reader: \(usableReader)")
            return false
        }
        let screenPoint = CGPoint(x: visible.minX + visible.width * horizontalFraction,
                                  y: visible.minY + min(visible.height - 1, max(5, visible.height * lineFraction)))
        guard screenPoint.y < tabBar.frame.minY - 8 else {
            XCTFail("Verse tap point overlaps the tab bar: \(screenPoint), tab frame: \(tabBar.frame)")
            return false
        }
        NSLog("L06_TAP id=%@ verseFrame=%@ viewport=%@ tabBar=%@ visible=%@ point=%@",
              verse.identifier, String(describing: verse.frame), String(describing: reader.frame),
              String(describing: tabBar.frame), String(describing: visible), String(describing: screenPoint))
        app.coordinate(withNormalizedOffset: CGVector(dx: (screenPoint.x - app.frame.minX) / app.frame.width,
                                                       dy: (screenPoint.y - app.frame.minY) / app.frame.height)).tap()
        return true
    }

    private func visibleReaderRect(_ reader: XCUIElement, tabBar: XCUIElement, in app: XCUIApplication) -> CGRect {
        let frame = reader.frame
        var contentBottom = min(frame.maxY, tabBar.frame.minY - 12)
        // Scripture scrolls under the floating selection panel (audit B3). A verse tap must not land on the panel.
        let panel = app.descendants(matching: .any).matching(identifier: "reader-selection-panel").firstMatch
        if panel.exists, panel.frame.height > 0 { contentBottom = min(contentBottom, panel.frame.minY - 8) }
        return CGRect(x: frame.minX, y: frame.minY, width: frame.width,
                      height: max(0, contentBottom - frame.minY))
    }

    func testPrimaryTabsAndSharedReaderAppearance() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 10))

        let readTab = tabButton(app, "tab-read")
        XCTAssertTrue(readTab.waitForExistence(timeout: 5))
        readTab.tap()
        XCTAssertTrue(app.staticTexts["reader-book-list-title"].waitForExistence(timeout: 5))
        app.buttons["reader-book-JHN"].tap()
        XCTAssertTrue(app.buttons["reader-chapter-1"].waitForExistence(timeout: 5))
        app.buttons["reader-chapter-1"].tap()
        XCTAssertTrue(app.buttons["reader-appearance-button"].waitForExistence(timeout: 10))
        let verse = app.buttons["reader-verse-1"]
        XCTAssertTrue(verse.waitForExistence(timeout: 10))
        verse.tap()
        XCTAssertTrue(app.staticTexts["reader-selection-summary"].waitForExistence(timeout: 5))

        app.buttons["reader-appearance-button"].tap()
        // The Aa sheet uses the Settings choice buttons (audit B2), not a menu picker.
        let readerSize = app.buttons["settings-text-size-large"]
        XCTAssertTrue(readerSize.waitForExistence(timeout: 5))
        readerSize.tap()
        let largeCommitted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Selected"), object: readerSize)
        XCTAssertEqual(XCTWaiter.wait(for: [largeCommitted], timeout: 6), .completed)
        app.buttons["reader-appearance-close"].tap()

        tabButton(app, "tab-settings").tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings-text-size-large"].isSelected)

        for (tab, title) in [
            ("tab-saved", "page-title-saved"),
            ("tab-pray", "page-title-pray"),
            ("tab-today", "today-title")
        ] {
            let button = tabButton(app, tab)
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing tab: \(tab)")
            button.tap()
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: title).firstMatch.waitForExistence(timeout: 5), "Missing root: \(title)")
        }
    }

    func testColdAndRepeatedURLsAndDurableReadingSize() throws {
        let app = XCUIApplication()
        let readURL = URL(string: "nrsv://read?book=JHN&chapter=1&verse=1")!
        app.launchArguments = ["-L04TestStartupDelaySeconds", "5"]
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["Loading saved data."].waitForExistence(timeout: 3))
        app.open(readURL)
        XCTAssertTrue(app.buttons["reader-verse-1"].waitForExistence(timeout: 15), "Queued URL must open after saved state loads")

        let settingsTab = tabButton(app, "tab-settings")
        settingsTab.tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 5))
        app.open(readURL)
        XCTAssertTrue(app.buttons["reader-verse-1"].waitForExistence(timeout: 10), "First ready URL must open the Reader")
        settingsTab.tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 5))
        app.open(readURL)
        XCTAssertTrue(app.buttons["reader-verse-1"].waitForExistence(timeout: 10), "Repeated equal URL must open the Reader again")

        settingsTab.tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 5))
        let extraLarge = app.buttons["settings-text-size-extra-large"]
        extraLarge.tap()
        XCTAssertTrue(extraLarge.isSelected)
        app.terminate()

        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 15))
        settingsTab.tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings-text-size-extra-large"].isSelected, "Aa value must survive a fresh process")
    }

    func testSameIDReleasePreferenceSurvivesFreshProcess() throws {
        let app = XCUIApplication(bundleIdentifier: "com.nrsv.verse")
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 15))
        tabButton(app, "tab-settings").tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "page-title-settings").firstMatch.waitForExistence(timeout: 5))

        let textSize = app.buttons["settings-text-size"]
        XCTAssertTrue(textSize.waitForExistence(timeout: 5))
        textSize.tap()
        app.buttons["Large"].tap()
        let largeSaved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Large"), object: textSize)
        XCTAssertEqual(XCTWaiter.wait(for: [largeSaved], timeout: 10), .completed)
        NSLog("L04_SAME_ID_RELEASE_NATIVE_SIZE_UPDATED value=Large")
        app.terminate()

        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 15))
        tabButton(app, "tab-settings").tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "page-title-settings").firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["settings-text-size"].value as? String, "Large", "Native state must win over the unchanged legacy MMKV value")
        NSLog("L04_SAME_ID_RELEASE_NATIVE_SIZE_RESTORED value=Large")
    }

    func testSameProcessRepeatedReadyURLs() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-JohnTabBarMinimize", "never"] // full tab bar: no Read-tab minimize (Liquid-glass-tabview-review.md fix 2)
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 15))
        tabButton(app, "tab-settings").tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 5))

        NSLog("L04_READY_URL_PHASE_1")
        let firstReader = app.buttons["reader-verse-1"]
        XCTAssertTrue(firstReader.waitForExistence(timeout: 45), "Host must send the first URL to the running app")
        let readerTitle = app.buttons["reader-title"]
        XCTAssertTrue(readerTitle.waitForExistence(timeout: 5))
        let firstRequestID = try XCTUnwrap(readerTitle.value as? String)
        XCTAssertFalse(firstRequestID.isEmpty)
        NSLog("L04_READY_URL_PHASE_1_REQUEST id=%@", firstRequestID)
        tabButton(app, "tab-settings").tap()
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 5))

        NSLog("L04_READY_URL_PHASE_2")
        let newRequest = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == YES AND value != %@ AND value != ''", firstRequestID),
            object: readerTitle
        )
        XCTAssertEqual(XCTWaiter.wait(for: [newRequest], timeout: 45), .completed,
                       "Repeated equal URL must create a new Reader request in the same process")
        let secondRequestID = try XCTUnwrap(readerTitle.value as? String)
        XCTAssertNotEqual(firstRequestID, secondRequestID)
        XCTAssertEqual(readerTitle.label, "John 1")
        XCTAssertTrue(firstReader.waitForExistence(timeout: 5))
        NSLog("L04_READY_URL_PHASE_2_DELIVERED firstID=%@ secondID=%@", firstRequestID, secondRequestID)
        Thread.sleep(forTimeInterval: 15)
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
