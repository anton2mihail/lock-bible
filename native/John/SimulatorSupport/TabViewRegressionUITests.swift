import UIKit
import XCTest

/// Focused runtime checks for the iOS 26 five-tab shell.
/// Run phone checks on the assigned iPhone 17 Pro and the iPad check on the assigned iPad.
@MainActor
final class TabViewRegressionUITests: XCTestCase {
    private let tabIDs = ["tab-today", "tab-read", "tab-saved", "tab-pray", "tab-settings"]
    private let tabLabels = ["Today", "Read", "Saved", "Pray", "Settings"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(minimizeNever: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        if minimizeNever { app.launchArguments += ["-JohnTabBarMinimize", "never"] }
        app.launch()
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 12))
        return app
    }

    private func tab(_ id: String, in app: XCUIApplication) -> XCUIElement {
        let name = id.hasPrefix("tab-") ? String(id.dropFirst(4)) : id
        let label = name.prefix(1).uppercased() + name.dropFirst()
        let identifierMatch = app.buttons.matching(identifier: id).firstMatch
        if identifierMatch.exists { return identifierMatch }
        let labelMatch = app.buttons.matching(NSPredicate(format: "label == %@", String(label))).firstMatch
        if labelMatch.exists { return labelMatch }
        return identifierMatch
    }

    private func waitForTab(_ id: String, in app: XCUIApplication,
                            file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let button = tab(id, in: app)
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Missing TabView button \(id)", file: file, line: line)
        XCTAssertTrue(button.isHittable, "TabView button \(id) must be hittable", file: file, line: line)
        return button
    }

    private func waitForSelected(_ button: XCUIElement,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed,
                       "The tab must become selected: \(button.identifier)", file: file, line: line)
    }

    private func becomesSelected(_ button: XCUIElement, timeout: TimeInterval) -> Bool {
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: button)
        return XCTWaiter.wait(for: [selected], timeout: timeout) == .completed
    }

    private func tabState(_ app: XCUIApplication) -> [(id: String, element: XCUIElement)] {
        tabIDs.map { ($0, tab($0, in: app)) }
    }

    private func logTabState(_ state: [(id: String, element: XCUIElement)], phase: String) {
        for item in state {
            // A minimized bar removes the other tabs. A missing element has no snapshot, so read it only when it exists.
            guard item.element.exists else {
                NSLog("R17_TAB_STATE phase=%@ id=%@ exists=0", phase, item.id)
                continue
            }
            NSLog("R17_TAB_STATE phase=%@ id=%@ exists=1 hittable=%d selected=%d frame=%@",
                  phase, item.id, item.element.isHittable ? 1 : 0,
                  item.element.isSelected ? 1 : 0, NSCoder.string(for: item.element.frame))
        }
    }

    private func isCompactReadState(_ state: [(id: String, element: XCUIElement)]) -> Bool {
        guard let read = state.first(where: { $0.id == "tab-read" }),
              read.element.exists, read.element.isSelected, read.element.isHittable else { return false }
        let otherTabs = state.filter { $0.id != "tab-read" }
        return !otherTabs.isEmpty && otherTabs.allSatisfy { !$0.element.isHittable }
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tabGeometry(_ app: XCUIApplication) -> [(String, CGRect)] {
        tabIDs.map { ($0, tab($0, in: app).frame) }
    }

    private func ensureJohnOne(in app: XCUIApplication) {
        let verse = app.descendants(matching: .any).matching(identifier: "reader-verse-1").firstMatch
        let title = app.buttons["reader-title"]
        // A scrolled Reader may have verse 1 off screen. John 1 is open when its title and scroll view exist.
        if title.waitForExistence(timeout: 3), title.label == "John 1",
           app.scrollViews["reader-chapter-scroll"].exists {
            return
        }

        let bookListTitle = app.staticTexts["reader-book-list-title"]
        if bookListTitle.waitForExistence(timeout: 3) {
            let book = app.buttons["reader-book-JHN"]
            XCTAssertTrue(book.waitForExistence(timeout: 5))
            book.tap()
        } else if !app.buttons["reader-chapter-1"].waitForExistence(timeout: 2) {
            let back = app.buttons["reader-back"]
            XCTAssertTrue(back.waitForExistence(timeout: 5), "Reader must expose its visible back control")
            back.tap()
            if bookListTitle.waitForExistence(timeout: 3) {
                let book = app.buttons["reader-book-JHN"]
                XCTAssertTrue(book.waitForExistence(timeout: 5))
                book.tap()
            }
        }
        let chapter = app.buttons["reader-chapter-1"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 8), "Reader must expose John chapter 1")
        chapter.tap()
        XCTAssertTrue(verse.waitForExistence(timeout: 10), "John 1 must expose verse 1")
    }

    func testTabIdentifiersLabelsFramesAndSelectedState() throws {
        let app = launch(minimizeNever: true)
        for (index, id) in tabIDs.enumerated() {
            let button = waitForTab(id, in: app)
            XCTAssertEqual(button.label, tabLabels[index], "Unexpected label for \(id)")
            button.tap()
            waitForSelected(button)
            for otherID in tabIDs where otherID != id {
                XCTAssertFalse(tab(otherID, in: app).isSelected, "Only \(id) must be selected")
            }
            NSLog("R17_TAB id=%@ label=%@ selected=%d frame=%@ tabBar=%@",
                  id, button.label, button.isSelected ? 1 : 0,
                  NSCoder.string(for: button.frame),
                  NSCoder.string(for: app.tabBars.firstMatch.frame))
        }
    }

    func testRetapPopsNestedRouteAndTabSwitchKeepsIt() throws {
        let app = launch(minimizeNever: true)
        let pray = waitForTab("tab-pray", in: app)
        pray.tap()
        waitForSelected(pray)

        let rosary = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Pray the Rosary")).firstMatch
        XCTAssertTrue(rosary.waitForExistence(timeout: 8))
        rosary.tap()
        let joyful = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "The Joyful Mysteries")).firstMatch
        XCTAssertTrue(joyful.waitForExistence(timeout: 8))
        joyful.tap()
        let firstStep = app.descendants(matching: .any).matching(identifier: "rosary-mystery-step-1").firstMatch
        XCTAssertTrue(firstStep.waitForExistence(timeout: 8), "The nested Rosary route must open")

        NSLog("R17_ROUTE beforeRetap=joyful step=%@", NSCoder.string(for: firstStep.frame))
        pray.tap()
        waitForSelected(pray)
        let novenaSearch = app.textFields.matching(NSPredicate(format: "label == %@", "Search novenas")).firstMatch
        XCTAssertTrue(novenaSearch.waitForExistence(timeout: 8),
                      "A real re-tap on Pray must pop its stack to PrayerHome")

        let rosaryHome = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Pray the Rosary")).firstMatch
        XCTAssertTrue(rosaryHome.waitForExistence(timeout: 8))
        rosaryHome.tap()
        XCTAssertTrue(app.staticTexts["Choose a mystery"].waitForExistence(timeout: 8))
        XCTAssertTrue(joyful.waitForExistence(timeout: 8))
        joyful.tap()
        XCTAssertTrue(firstStep.waitForExistence(timeout: 8))
        let today = waitForTab("tab-today", in: app)
        today.tap()
        waitForSelected(today)
        XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: 8))
        pray.tap()
        waitForSelected(pray)
        XCTAssertTrue(firstStep.waitForExistence(timeout: 8),
                      "Switching away and back must keep the pushed Rosary route")
        NSLog("R17_ROUTE switchedAwayAndBack=retained frame=%@", NSCoder.string(for: firstStep.frame))
    }

    func testTodayScrollPositionReturnsAfterTabSwitch() throws {
        let app = launch(minimizeNever: true)
        let title = app.staticTexts["today-title"]
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 8), "Today must expose its scroll view")
        let startY = title.frame.minY
        var moved = false
        for _ in 0..<4 where !moved {
            scroll.swipeUp()
            moved = title.frame.minY < startY - 30
        }
        XCTAssertTrue(moved, "Today must scroll before testing retained position")
        let scrolledY = title.frame.minY
        NSLog("R17_TODAY position=start:%.1f scrolled:%.1f", startY, scrolledY)

        waitForTab("tab-pray", in: app).tap()
        waitForSelected(tab("tab-pray", in: app))
        waitForTab("tab-today", in: app).tap()
        let firstToday = tab("tab-today", in: app)
        if !becomesSelected(firstToday, timeout: 5) {
            NSLog("R17_TAB_RETRY id=tab-today reason=first-delivery-not-selected frame=%@ hittable=%d",
                  NSCoder.string(for: firstToday.frame), firstToday.isHittable ? 1 : 0)
            let retryToday = waitForTab("tab-today", in: app)
            XCTAssertTrue(!retryToday.frame.isEmpty && app.frame.contains(retryToday.frame),
                          "The re-queried Today tab must be inside the app window")
            let retryPoint = retryToday.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            NSLog("R17_TAB_RETRY id=tab-today action=center-coordinate frame=%@",
                  NSCoder.string(for: retryToday.frame))
            retryPoint.tap()
            waitForSelected(retryToday)
        }
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        let restoredY = title.frame.minY
        XCTAssertEqual(restoredY, scrolledY, accuracy: 8,
                       "Returning to Today must restore its scroll position")
        NSLog("R17_TODAY position=restored:%.1f", restoredY)
    }

    func testReaderTabMinimizesExpandsAndKeepsSelectionAboveBar() throws {
        let app = launch(minimizeNever: false)
        let fullBar = app.tabBars.firstMatch
        XCTAssertTrue(fullBar.waitForExistence(timeout: 8))
        let initialBarFrame = fullBar.frame
        let initialTabFrames = tabGeometry(app)
        NSLog("R17_BAR state=full bar=%@ tabs=%@", NSCoder.string(for: fullBar.frame),
              initialTabFrames.map { "\($0.0):\(NSCoder.string(for: $0.1))" }.joined(separator: ";"))

        let read = waitForTab("tab-read", in: app)
        read.tap()
        waitForSelected(read)
        ensureJohnOne(in: app)
        let reader = app.scrollViews["reader-chapter-scroll"]
        XCTAssertTrue(reader.waitForExistence(timeout: 10))

        let verse = app.descendants(matching: .any).matching(identifier: "reader-verse-1").firstMatch
        XCTAssertTrue(verse.waitForExistence(timeout: 10))
        verse.tap()
        let selectionReference = app.staticTexts["reader-selection-reference"]
        XCTAssertTrue(selectionReference.waitForExistence(timeout: 8), "Selecting a verse must show its reference")
        XCTAssertEqual(selectionReference.label, "John 1:1")
        let lowerControl = app.buttons["reader-selection-note"]
        XCTAssertTrue(lowerControl.waitForExistence(timeout: 8), "The selection toolbar must expose the Note control")
        XCTAssertTrue(lowerControl.isHittable)
        XCTAssertLessThan(lowerControl.frame.maxY, fullBar.frame.minY,
                          "Reader selection controls must stay above the full tab bar")

        var minimized = false
        for _ in 0..<5 where !minimized {
            reader.swipeUp()
            let newFrame = fullBar.frame
            let liveTabs = tabState(app)
            logTabState(liveTabs, phase: "scroll")
            minimized = isCompactReadState(liveTabs)
            NSLog("R17_BAR state=scroll bar=%@", NSCoder.string(for: newFrame))
        }
        XCTAssertTrue(minimized, "Scrolling down in Read must minimize the tab bar")
        XCTAssertTrue(lowerControl.exists && lowerControl.isHittable,
                      "Reader selection controls must remain available with the minimized tab bar")
        XCTAssertLessThan(lowerControl.frame.maxY, fullBar.frame.minY,
                          "Reader selection controls must stay above the minimized tab bar")
        capture("R17-reader-minimized", app: app)

        let compactRead = tab("tab-read", in: app)
        XCTAssertTrue(compactRead.exists && compactRead.isSelected && compactRead.isHittable,
                      "The compact Read tab must expose a valid hittable element")
        XCTAssertTrue(app.frame.contains(compactRead.frame), "The compact Read tab must be inside the app window")
        NSLog("R17_TAB_EXPAND id=tab-read action=native-element-tap frame=%@ hittable=%d",
              NSCoder.string(for: compactRead.frame), compactRead.isHittable ? 1 : 0)
        compactRead.tap()
        let expandedTabs = tabState(app)
        let allTabsHittable = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in expandedTabs.allSatisfy { $0.element.isHittable } }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [allTabsHittable], timeout: 5), .completed,
                       "Tapping the compact Read tab must restore all five hittable tabs")
        logTabState(expandedTabs, phase: "tap-expanded")
        NSLog("R17_BAR state=tapExpanded bar=%@", NSCoder.string(for: fullBar.frame))

        let saved = waitForTab("tab-saved", in: app)
        saved.tap()
        waitForSelected(saved)
        let expandedFrame = fullBar.frame
        XCTAssertGreaterThan(expandedFrame.height, initialBarFrame.height - 8)
        XCTAssertTrue(tab("tab-saved", in: app).isHittable,
                      "Tapping the minimized bar must expand it and select Saved")
        NSLog("R17_BAR state=expanded bar=%@", NSCoder.string(for: expandedFrame))

        let readAfterSave = waitForTab("tab-read", in: app)
        readAfterSave.tap()
        waitForSelected(readAfterSave)
        ensureJohnOne(in: app)
        let selectionAfterTabChange = app.staticTexts["reader-selection-reference"]
        XCTAssertTrue(selectionAfterTabChange.waitForExistence(timeout: 8),
                      "The Reader selection must remain after switching away and back")
        XCTAssertEqual(selectionAfterTabChange.label, "John 1:1")
        let lowerControlAfterTabChange = app.buttons["reader-selection-note"]
        XCTAssertTrue(lowerControlAfterTabChange.waitForExistence(timeout: 8))
        XCTAssertTrue(lowerControlAfterTabChange.isHittable)
        XCTAssertLessThan(lowerControlAfterTabChange.frame.maxY, fullBar.frame.minY,
                          "Reader selection controls must stay above the full tab bar")
        NSLog("R17_LOWER_CONTROL id=reader-selection-note frame=%@ tabBar=%@ hittable=%d",
              NSCoder.string(for: lowerControlAfterTabChange.frame), NSCoder.string(for: fullBar.frame),
              lowerControlAfterTabChange.isHittable ? 1 : 0)
        capture("R17-reader-selection-above-tab-bar", app: app)
    }

    func testIPadTabBarIsTopAlignedWithoutSidebar() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("This capture must run on the assigned iPad simulator")
        }
        let app = launch(minimizeNever: true)
        var physicalFrames: [CGRect] = []
        for (index, id) in tabIDs.enumerated() {
            let matchingNodes = app.buttons.matching(identifier: id).allElementsBoundByIndex.filter(\.exists)
            XCTAssertFalse(matchingNodes.isEmpty, "The iPad must expose at least one node for \(id)")
            guard let physicalFrame = matchingNodes.first?.frame else { continue }
            XCTAssertTrue(matchingNodes.allSatisfy { $0.frame == physicalFrame },
                          "Nested iPad nodes for \(id) must describe one physical tab frame")
            let button = waitForTab(id, in: app)
            XCTAssertEqual(button.label, tabLabels[index], "Unexpected iPad label for \(id)")
            XCTAssertEqual(button.isSelected, id == "tab-today", "Unexpected initial iPad selection for \(id)")
            XCTAssertTrue(button.frame.minY < app.frame.midY,
                          "The iPad TabView button \(id) must be at the top of the window")
            XCTAssertTrue(app.frame.contains(button.frame),
                          "The iPad TabView button \(id) must be fully inside the window")
            physicalFrames.append(physicalFrame)
            NSLog("R17_IPAD_TAB id=%@ label=%@ selected=%d frame=%@",
                  id, button.label, button.isSelected ? 1 : 0, NSCoder.string(for: button.frame))
        }
        XCTAssertEqual(Set(physicalFrames.map { NSCoder.string(for: $0) }).count, 5,
                       "The five iPad tabs must have five distinct physical frames")
        let physicalUnion = physicalFrames.dropFirst().reduce(physicalFrames.first ?? .zero) { $0.union($1) }
        XCTAssertTrue(app.frame.contains(physicalUnion),
                      "The physical iPad tab-frame union must be fully inside the window")
        let centers = physicalFrames.map(\.midX)
        XCTAssertEqual(centers.count, 5)
        XCTAssertTrue(zip(centers, centers.dropFirst()).allSatisfy { $0 < $1 },
                      "The five TabView items must appear in order across the top edge")
        NSLog("R17_IPAD_VISUAL sidebarCheck=attached-screenshots physicalTabs=%@ union=%@",
              physicalFrames.map { NSCoder.string(for: $0) }.joined(separator: ";"),
              NSCoder.string(for: physicalUnion))
        capture("R17-iPad-Today", app: app)

        waitForTab("tab-read", in: app).tap()
        waitForSelected(tab("tab-read", in: app))
        XCTAssertTrue(app.staticTexts["reader-book-list-title"].waitForExistence(timeout: 8) ||
                      app.buttons["reader-title"].waitForExistence(timeout: 8))
        capture("R17-iPad-Read", app: app)

        let settings = waitForTab("tab-settings", in: app)
        settings.tap()
        waitForSelected(settings)
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: 8))
        capture("R17-iPad-Settings", app: app)
    }
}
