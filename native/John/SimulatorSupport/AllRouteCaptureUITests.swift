import CryptoKit
import Foundation
import UIKit
import XCTest

/// L25 route captures. This file uses visible controls only. Main owns target membership and runs.
@MainActor
final class AllRouteCaptureUITests: XCTestCase {
    private var activeApp: XCUIApplication?
    private var activeVariant: Variant?
    private var activeContext: CaptureContext?
    private enum Variant: String { case baseline, native }

    private final class CaptureContext {
        let app: XCUIApplication
        let variant: Variant
        let bundleID: String
        let appVersion: String
        let build: String
        let sourceVersion: String
        let seedID: String
        let expectedAppearance: String
        let effectiveDeviceAppearance: String
        let expectedEdition: String
        let expectedTextSize: String
        let expectedSpacing: String
        let expectedTypeface: String
        let expectedLayout: String
        let statusBarProfile: String
        let suppliedDate: String?
        let suppliedTimeZone: String?
        var routeStatus = "captured"
        var route = "supplement-or-unset"
        var baselineOpenJohnPath = "not-used"
        /// Old-app coordinate taps (label, frame, route). Empty for native runs and for old-app runs without one.
        var baselineCoordinateTaps: [[String: Any]] = []
        var resolvedIdentity = ""
        var observedPreferences: [String: String] = [:]
        let seedStateDescription: String
        let seedManifestHash: String
        let nativeArtifact: String
        let javascriptSourceVersion: String
        // Optional profile hooks. Missing environment values keep the earlier behavior.
        var keyboardRequested = false
        var axTreeRequested = false
        var auditRequested = false
        var selectedPassageProfileMeasured = false
        var verse1TapOffset: CGPoint?
        var selectedPassageTap = "not-applicable"
        var callerFacts: [String: String] = [:]
        var keyboardRecord: [String: Any] = ["requested": false, "status": "not-requested"]

        init(app: XCUIApplication, variant: Variant, bundleID: String, appVersion: String,
             build: String, sourceVersion: String, seedID: String,
             expectedAppearance: String, effectiveDeviceAppearance: String,
             expectedEdition: String, expectedTextSize: String,
             expectedSpacing: String, expectedTypeface: String, expectedLayout: String,
             statusBarProfile: String, suppliedDate: String?, suppliedTimeZone: String?,
             seedStateDescription: String, seedManifestHash: String,
             nativeArtifact: String, javascriptSourceVersion: String) {
            self.app = app; self.variant = variant; self.bundleID = bundleID
            self.appVersion = appVersion; self.build = build; self.sourceVersion = sourceVersion
            self.seedID = seedID; self.expectedAppearance = expectedAppearance
            self.effectiveDeviceAppearance = effectiveDeviceAppearance
            self.expectedEdition = expectedEdition; self.expectedTextSize = expectedTextSize
            self.expectedSpacing = expectedSpacing; self.expectedTypeface = expectedTypeface
            self.expectedLayout = expectedLayout; self.statusBarProfile = statusBarProfile
            self.suppliedDate = suppliedDate; self.suppliedTimeZone = suppliedTimeZone
            self.seedStateDescription = seedStateDescription; self.seedManifestHash = seedManifestHash
            self.nativeArtifact = nativeArtifact; self.javascriptSourceVersion = javascriptSourceVersion
        }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testL25Route01Today() throws { try capture("/", identity: "Today") { c in try openTab("today", label: "Today", context: c); try waitForPageTitle(c, nativeID: "today-title", baselineTitle: "A little closer to God.") } }
    func testL25Route02Reader() throws { try capture("/read", identity: "WEB-CE JHN 1:1; reader root") { c in try openJohnOne(c) } }
    func testL25Route03Saved() throws { try capture("/saved", identity: "Saved all filter; seeded rows") { c in try openTab("saved", label: "Saved", context: c); try waitForAny(c.app, ["All", "All saved passages"]) } }
    func testL25Route04PrayerHome() throws { try capture("/pray", identity: "PrayerHome") { c in try openTab("pray", label: "Pray", context: c); try waitForAny(c.app, ["Pray the Rosary"], contains: c.variant == .baseline) } }
    func testL25Route05Settings() throws { try capture("/settings", identity: "Settings; matched reader preferences") { c in try prepareSettings(c); try verifyTextSizeChoice(c) } }
    func testL25SettingsTopHeading() throws {
        try capture("/settings", identity: "Settings heading at top of screen") { c in
            try openTab("settings", label: "Settings", context: c)
            let title = c.app.staticTexts["settings-title"]
            XCTAssertTrue(title.waitForExistence(timeout: 10), "The Settings heading must be visible at the top")
            XCTAssertTrue(title.isHittable)
            XCTAssertLessThan(title.frame.minY, c.app.frame.midY,
                              "The Settings heading must appear in the upper half of the screen")
        }
    }
    func testL25Route06GoTo() throws { try capture("/go-to", identity: "GoTo; current JHN 1") { c in try openJohnOne(c); try tap(button(c, nativeID: "reader-title", baselineLabel: "John 1")); try waitForAny(c.app, ["Go to", "Go To", "Choose a book"]) } }
    func testL25Route07Search() throws { try capture("/search", identity: "Search Scripture") { c in
        try openJohnOne(c)
        try tap(button(c, nativeID: "reader-search-button", baselineLabel: "Search Scripture"))
        try waitForAny(c.app, ["Search Scripture", "Search by reference, keyword, or exact phrase."])
        if c.variant == .native {
            let title = c.app.staticTexts.matching(NSPredicate(format: "label == %@", "Search Scripture")).firstMatch
            XCTAssertTrue(title.waitForExistence(timeout: 10), "The complete Search Scripture title must remain accessible at XXXL")
            XCTAssertEqual(title.label, "Search Scripture")
        }
    } }
    func testL25Route08NoteEditor() throws { try capture("/note", identity: "Selected WEB-CE JHN 1:1 note editor") { c in try selectJHN11(c); try tap(button(c, nativeID: "reader-selection-note", baselineLabel: "Note John 1:1")); try verifyNoteEditor(c) } }
    func testL25Route09VerseMoment() throws { try capture("/verse", identity: "Verse of the moment") { c in try openTab("today", label: "Today", context: c); try tap(button(c, nativeID: "today-verse-card", baselineLabel: "Verse & lock screen widget")); try waitForAny(c.app, ["Verse of the moment", "No verse available."]) } }
    func testL25Route10DailyReadings() throws { try capture("/daily?date=…", identity: "Daily readings; caller date or current local date") { c in try openTab("today", label: "Today", context: c); try tap(button(c, nativeID: "today-readings-card", baselineLabel: "Today’s readings")); try waitForAny(c.app, ["Today’s readings"]) } }
    func testL25Route11SundayPreparation() throws { try capture("/sunday", identity: "Sunday preparation; caller date or upcoming Sunday") { c in try openTab("today", label: "Today", context: c); try tap(button(c, nativeID: "today-sunday", baselineLabel: "Come ready for Sunday")); try waitForAny(c.app, ["Come ready for Sunday"]) } }
    func testL25Route12PassageContext() throws { try capture("/passage?reference=…", identity: "Caller-supplied L25_READING_REFERENCE") { c in try openConfiguredReading(c) } }
    func testL25Route13Lectio() throws { try capture("/lectio", identity: "WEB-CE JHN 1:1 selected passage") { c in try selectJHN11(c); try tap(button(c, nativeID: "reader-selection-pray", baselineLabel: "Pray John 1:1")); try waitForAny(c.app, ["Read slowly", "Pray with Scripture"]) } }
    func testL25Route14PrayerLibrary() throws { try capture("/prayers", identity: "Prayer library") { c in try openTab("pray", label: "Pray", context: c); try tap(button(c, nativeID: "prayer-library", baselineLabel: "Everyday prayers")); try waitForAny(c.app, ["Prayer for every day", "Find a prayer…"]) } }
    func testL25Route15PrayerDetail() throws { try capture("/prayer?id=…", identity: "Prayer id morning") { c in try openTab("pray", label: "Pray", context: c); try tap(button(c, nativeID: "prayer-library", baselineLabel: "Everyday prayers")); try tap(button(c, nativeID: "prayer-morning", baselineLabel: "Morning Offering")); try waitForAny(c.app, ["Morning Offering"]) } }
    func testL25Route16TeachingLibrary() throws { try capture("/learn", identity: "Teaching library") { c in try openTab("today", label: "Today", context: c); try tap(button(c, nativeID: "today-learn", baselineLabel: "Explore the Catholic faith")); try waitForAny(c.app, ["Faith, rooted in Scripture"]) } }
    func testL25Route17TeachingDetail() throws { try capture("/teaching?id=…", identity: "Teaching id eucharist") { c in try openTab("today", label: "Today", context: c); try tap(button(c, nativeID: "today-learn", baselineLabel: "Explore the Catholic faith")); try tap(button(c, nativeID: "teaching-eucharist", baselineLabel: "The Eucharist")); try waitForAny(c.app, ["The Eucharist"]) } }
    func testL25Route18Confession() throws { try capture("/confession", identity: "Confession guide initial step") { c in try openTab("today", label: "Today", context: c); try tap(button(c, nativeID: "today-confession", baselineLabel: "Prepare for Confession")); try waitForAny(c.app, ["Prepare for Confession", "Prepare"]) } }
    func testL25Route19ScriptureCard() throws { try capture("/share-card", identity: "Selected WEB-CE JHN 1:1 card") { c in try selectJHN11(c); try tap(button(c, nativeID: "reader-selection-card", baselineLabel: "Create card John 1:1")); try waitForAny(c.app, ["A word worth sharing"]) } }
    func testL25Route20CalendarNotifications() throws { try capture("/calendar-notifications", identity: "Calendar notification settings") { c in try prepareSettings(c)
        // Old row: ActionRow title "Saints, feasts & daily readings" under the "Calendar notifications" section header
        // (src/screens/SettingsScreen.tsx:151-153). Its label is "<title>. <subtitle>" (src/components/companion/Companion.tsx:135).
        // Old destination title: "A day in the Church" (src/screens/companion/CalendarNotificationsScreen.tsx:43).
        try tap(button(c, nativeID: "settings-calendar-notifications",
                       baselineLabel: c.variant == .native ? "Calendar notifications" : "Saints, feasts & daily readings"))
        try waitForAny(c.app, ["A day in the Church"]) } }
    func testL25Route21NovenaDetail() throws { try capture("/pray/[id]", identity: "Novena id st-padre-pio") { c in try openTab("pray", label: "Pray", context: c); try tap(button(c, nativeID: "novena-st-padre-pio", baselineLabel: "St. Padre Pio Novena")); try waitForAny(c.app, ["St. Padre Pio Novena"]) } }
    func testL25Route22RosaryHome() throws { try capture("/pray/rosary", identity: "Rosary home") { c in try openTab("pray", label: "Pray", context: c); try tap(button(c, nativeID: "prayer-home-rosary", baselineLabel: "Pray the Rosary")); try waitForAny(c.app, ["Choose a mystery"]) } }
    func testL25Route23RosaryGuide() throws { try capture("/pray/rosary-guide?set=…", identity: "Named Joyful set") { c in
        try openRosary(c)
        try tap(button(c, nativeID: "rosary-set-joyful", baselineLabel: "The Joyful Mysteries"))
        try waitForAny(c.app, ["Joyful"])
        if c.variant == .native {
            let expected = ["Annunciation", "Visitation", "Nativity", "Presentation", "Finding in the Temple"]
            for (index, label) in expected.enumerated() {
                let step = c.app.descendants(matching: .any)
                    .matching(identifier: "rosary-mystery-step-\(index + 1)").firstMatch
                for _ in 0..<8 where !step.exists || !step.isHittable {
                    if step.exists { scrollToVisible(step, assertProgress: false) }
                    else { scrollForLazyRow(step, assertProgress: false) }
                }
                XCTAssertTrue(step.exists && step.isHittable,
                              "Rosary step \(index + 1) must be accessible: \(label)")
                XCTAssertEqual(step.label, label, "The complete Rosary step name must remain available at XXXL")
            }
        }
    } }
    func testL25Route24RosaryReminder() throws { try capture("/pray/rosary-reminder", identity: "Rosary reminder settings") { c in try openRosary(c); try tap(button(c, nativeID: "rosary-reminder", baselineLabel: "Rosary reminder")); try waitForAny(c.app, ["Rosary reminder"]) } }
    func testL25Route25RosaryMedia() throws { try capture("/pray/rosary-media?episode=…", identity: "Rosary media episode resolved from visible series entry") { c in
        try openRosary(c)
        try waitForAny(c.app, ["The Rosary with Bishop Barron"])
        let media = c.app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "rosary-media-entry-")).firstMatch
        if c.variant == .native {
            XCTAssertTrue(media.waitForExistence(timeout: 15), "Rosary home must show a named series entry")
            let entryID = media.identifier
            let prefix = "rosary-media-entry-"
            XCTAssertTrue(entryID.hasPrefix(prefix), "The selected media entry must identify its source episode")
            let expectedID = String(entryID.dropFirst(prefix.count))
            try tap(media)
            try waitForAny(c.app, ["WORD ON FIRE SERIES"])
            let ids = ["why-pray", "how-to-pray", "joyful", "sorrowful", "glorious", "luminous"]
            let selectedID = ids.first { id in
                let choice = c.app.buttons["rosary-media-episode-\(id)"]
                return choice.exists && selectionState(choice) == true
            }
            XCTAssertNotNil(selectedID, "The media route must expose a selected source episode")
            XCTAssertEqual(selectedID, expectedID, "The media route must open the episode for the tapped mystery set")
            c.resolvedIdentity = "Rosary media episode=\(selectedID ?? "unobserved"); entry=\(expectedID)"
        } else {
            c.resolvedIdentity = "Rosary media unresolved; visible Release action is external"
            recordUnresolved(c, reason: "The visible Release control opens an external website. This route was not opened.")
        }
    } }
    func testL25Route26WorksLibrary() throws { try capture("/works", identity: "Works library from Reader chapter and book controls") { c in try openWorks(c) } }
    func testL25Route27WorksCollection() throws { try capture("/works/author/[id]", identity: "Collection augustine") { c in try openWorks(c); try tap(button(c, nativeID: "collection-augustine", baselineLabel: "Augustine"))
        // Old collection page: author heading "St Augustine of Hippo" (works-collection-screen.tsx, `collection.author`), which the
        // library row also shows, so the destination is identified by its back control "Back to the library"
        // (works-collection-screen.tsx accessibilityLabel). Native heading is collection.author, "St Augustine of Hippo".
        try waitForAny(c.app, [c.variant == .native ? "St Augustine of Hippo" : "Back to the library"]) } }
    func testL25Route28WorkReader() throws { try capture("/works/[id]?section=…", identity: "Work augustine.the-confessions, section 0") { c in try openWorks(c); try tap(button(c, nativeID: "collection-augustine", baselineLabel: "Augustine")); try tap(button(c, nativeID: "work-augustine.the-confessions", baselineLabel: "The Confessions")); try waitForAny(c.app, ["The Confessions"]) } }
    func testL25Route29ChapterCommentary() throws {
        try capture("/commentary/[book]/[chapter]", identity: "JHN 1; all 30 readings") { c in
            try openJohnOne(c)
            let allReadings = button(c, nativeID: "reader-commentary-all", baselineLabel: "All 30 readings on this chapter")
            try tap(allReadings)
            if c.variant == .baseline {
                // Old row: a ListItem with role button and the text "All 30 readings on this chapter" (ReaderScreen.tsx:766-777).
                // Its onPress pushes /commentary/[book]/[chapter]. The destination back control is "Back to John 1"
                // (chapter-commentary-screen.tsx:76). "John 1" alone is not enough: the Reader also shows that text.
                let destination = c.app.buttons.matching(NSPredicate(format: "label == %@", "Back to John 1")).firstMatch
                if !destination.waitForExistence(timeout: 6) {
                    NSLog("L25_RETRY_TAP all-readings row: the destination did not appear after the first tap")
                    try tap(allReadings)
                }
                XCTAssertTrue(destination.waitForExistence(timeout: 30), "The old chapter commentary screen must open (Back to John 1)")
            }
            let chapterTitle = c.app.staticTexts.matching(NSPredicate(format: "label == %@", "John 1")).firstMatch
            // John 1 commentary is two collections: Augustine and Chrysostom.
            // catalog.json and the installed 1.2.2 screen both show this label.
            let count = c.app.staticTexts.matching(NSPredicate(format: "label == %@", "30 readings · 2 authors")).firstMatch
            XCTAssertTrue(chapterTitle.waitForExistence(timeout: 30), "The chapter commentary destination must show John 1")
            XCTAssertEqual(chapterTitle.label, "John 1")
            XCTAssertTrue(count.waitForExistence(timeout: 30), "The chapter commentary destination must show its exact source count")
            c.resolvedIdentity = "Chapter commentary title=\(chapterTitle.label); count=\(count.label)"
        }
    }

    // MARK: Native-only supplements
    // These run only with L25_ENABLE_SUPPLEMENTS=1 and the native variant. Run one method at a time
    // with -only-testing, after the matched initial route image exists. Main owns the seed and restore.

    /// Natural 60 s Lectio expiry. Start after the matched route 13 images. It does not tap "End the timer".
    func testL25Supplement01LectioNaturalExpiry() throws {
        try requireSupplements()
        let c = try makeContext(nativeOnly: true)
        XCTAssertTrue(c.app.wait(for: .runningForeground, timeout: 30))
        try prepareSettings(c)
        guard selectedPassageEntryAllowed(c, windowWidth: c.app.windows.firstMatch.frame.size.width) else {
            throw XCTSkip("Selected-passage entry has no reviewed tap point for this profile.")
        }
        try selectJHN11(c)
        try tap(button(c, nativeID: "reader-selection-pray", baselineLabel: "Pray John 1:1"))
        try waitForAny(c.app, ["Read slowly"])
        for step in ["Stay with a word", "Speak to God", "Rest in his presence"] {
            try tap(c.app.buttons["Continue"])
            XCTAssertTrue(c.app.staticTexts[step].waitForExistence(timeout: 30), "Expected Lectio step: \(step)")
        }
        let countdown = c.app.staticTexts.matching(NSPredicate(
            format: "label MATCHES %@", "^([1-9]|[1-5][0-9]|60)s of quiet$"
        )).firstMatch
        try tap(c.app.buttons["Begin one quiet minute"])
        XCTAssertTrue(countdown.waitForExistence(timeout: 5), "The quiet countdown must start")
        let started = Date()
        let firstLabel = countdown.label
        c.resolvedIdentity = "Lectio supplement: timer running"
        try emitCapture(route: "/lectio#natural-expiry-running", slug: "lectio-natural-expiry-running",
                        identity: "Lectio timer running", entryPath: "Read JHN 1:1; verse 1; Pray with this passage; Continue x3; Begin one quiet minute",
                        context: c, extra: ["supplement": "lectio-natural-expiry", "timerFirstLabel": firstLabel],
                        captureKind: "supplement")
        let gone = countdown.waitForNonExistence(timeout: 90)
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertTrue(gone, "The countdown must end by itself within 90 seconds")
        let stillness = c.app.staticTexts["A moment of stillness"]
        let stillnessVisible = stillness.waitForExistence(timeout: 5)
        let buttons = c.app.buttons.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }.map(\.label)
        c.resolvedIdentity = "Lectio supplement: after natural expiry"
        try emitCapture(route: "/lectio#natural-expiry-end", slug: "lectio-natural-expiry-end",
                        identity: "Lectio after natural expiry", entryPath: "Same journey; wait for the countdown to end",
                        context: c,
                        extra: ["supplement": "lectio-natural-expiry", "timerFirstLabel": firstLabel,
                                "elapsedSecondsFromBeginTapToCountdownGone": elapsed,
                                "elapsedNote": "Runner clock. Includes polling latency. Not a fixed content clock.",
                                "stillnessTextVisible": stillnessVisible, "visibleButtonLabels": buttons],
                        captureKind: "supplement")
    }

    /// Part A: open The Confessions and page to the middle. The test ends there so Main can copy the
    /// stopped-app envelope (saved Works position) before part B.
    func testL25Supplement02aWorksMiddlePage() throws {
        try requireSupplements()
        let c = try makeContext(nativeOnly: true)
        XCTAssertTrue(c.app.wait(for: .runningForeground, timeout: 30))
        try prepareSettings(c)
        try openWorks(c)
        try tap(button(c, nativeID: "collection-augustine", baselineLabel: "Augustine"))
        try tap(button(c, nativeID: "work-augustine.the-confessions", baselineLabel: "The Confessions"))
        try waitForAny(c.app, ["The Confessions"])
        let prose = worksProse(c)
        XCTAssertTrue(prose.waitForExistence(timeout: 30), "Work prose must appear")
        let initial = try XCTUnwrap(worksPage(c), "Page label must appear")
        c.resolvedIdentity = "Works supplement: initial page \(initial.label)"
        try emitCapture(route: "/works/[id]#initial", slug: "works-supplement-initial-page",
                        identity: "Works initial page", entryPath: "Works; Augustine; The Confessions",
                        context: c, extra: worksExtra(c, label: initial.label), captureKind: "supplement")
        XCTAssertGreaterThanOrEqual(initial.total, 3, "The section needs at least 3 pages for a middle page")
        let target = (initial.total + 1) / 2
        var current = initial.page
        var currentLabel = initial.label
        var swipes = 0
        while current < target && swipes < initial.total + 2 {
            prose.swipeLeft()
            swipes += 1
            let expectedPage = current + 1
            let pageCount = c.app.staticTexts["works-page-count"]
            let nextPage = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard pageCount.exists, let observed = self.parseWorksPageLabel(pageCount.label) else { return false }
                return observed.page == expectedPage && observed.total == initial.total
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [nextPage], timeout: 30), .completed,
                           "Expected page \(expectedPage) of \(initial.total) after the swipe")
            guard pageCount.exists, let observed = parseWorksPageLabel(pageCount.label),
                  observed.page == expectedPage, observed.total == initial.total else { break }
            current = observed.page
            currentLabel = observed.label
        }
        XCTAssertEqual(current, target, "The middle page was not reached")
        let label = currentLabel
        c.resolvedIdentity = "Works supplement: middle page \(label)"
        try emitCapture(route: "/works/[id]#middle-page", slug: "works-supplement-middle-page",
                        identity: "Works middle page", entryPath: "Same journey; swipe to the middle page",
                        context: c, extra: worksExtra(c, label: label), captureKind: "supplement")
    }

    /// Part B: relaunch, resume the saved Works position, rotate to landscape (width change), rotate back.
    /// Start it after part A and after Main copied the envelope. Do not reseed between A and B.
    func testL25Supplement02bWorksResumeAndWidthChange() throws {
        try requireSupplements()
        let c = try makeContext(nativeOnly: true)
        XCTAssertTrue(c.app.wait(for: .runningForeground, timeout: 30))
        try prepareSettings(c)
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        try openWorks(c)
        let resume = c.app.buttons["works-continue"]
        XCTAssertTrue(resume.waitForExistence(timeout: 30), "Run part A first. A saved Works position must exist.")
        try tap(resume)
        XCTAssertTrue(worksProse(c).waitForExistence(timeout: 30), "Resumed work prose must appear")
        let resumed = try XCTUnwrap(worksPage(c), "Page label must appear after resume")
        let resumedBody = worksBodySnapshot(c)
        let resumedViewport = worksProse(c).frame
        c.resolvedIdentity = "Works supplement: resumed \(resumed.label)"
        try emitCapture(route: "/works/[id]#resumed-portrait", slug: "works-supplement-resumed-portrait",
                        identity: "Works resumed", entryPath: "Works library; Continue reading",
                        context: c, extra: worksExtra(c, label: resumed.label), captureKind: "supplement")

        XCUIDevice.shared.orientation = .landscapeLeft
        waitForOrientation(c, landscape: true)
        let landscape = try XCTUnwrap(worksPage(c), "Page label must appear in landscape")
        let landscapeBody = worksBodySnapshot(c)
        let landscapeViewport = worksProse(c).frame
        c.resolvedIdentity = "Works supplement: landscape \(landscape.label)"
        try emitCapture(route: "/works/[id]#landscape", slug: "works-supplement-landscape",
                        identity: "Works landscape", entryPath: "Same journey; rotate to landscape",
                        context: c, extra: worksExtra(c, label: landscape.label), captureKind: "supplement")

        XCUIDevice.shared.orientation = .portrait
        waitForOrientation(c, landscape: false)
        let restoredInTime = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let page = c.app.staticTexts["works-page-count"]
            return page.exists && page.label == resumed.label && self.worksBodySnapshot(c) == resumedBody
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [restoredInTime], timeout: 15), .completed,
                       "Portrait reflow must restore the saved page and body after layout settles")
        let restored = try XCTUnwrap(worksPage(c), "Page label must appear after rotating back")
        let restoredBody = worksBodySnapshot(c)
        let restoredViewport = worksProse(c).frame
        XCTAssertEqual(restored.page, resumed.page,
                       "Returning to the original portrait width must restore the same page")
        XCTAssertEqual(restoredBody, resumedBody,
                       "Returning to the original portrait width must restore the same visible Works text")
        XCTAssertEqual(restoredViewport.size.width, resumedViewport.size.width, accuracy: 1,
                       "Portrait reflow must restore the original text viewport width")
        XCTAssertEqual(restoredViewport.size.height, resumedViewport.size.height, accuracy: 1,
                       "Portrait reflow must restore the original text viewport height")
        c.resolvedIdentity = "Works supplement: restored portrait \(restored.label)"
        var extra = worksExtra(c, label: restored.label)
        extra["resumedPageLabel"] = resumed.label
        extra["landscapePageLabel"] = landscape.label
        extra["restoredLabelEqualsResumed"] = restored.label == resumed.label
        extra["resumedBodySHA256"] = worksBodyHash(resumedBody)
        extra["landscapeBodySHA256"] = worksBodyHash(landscapeBody)
        extra["restoredBodySHA256"] = worksBodyHash(restoredBody)
        extra["resumedViewportFrame"] = rectDictionary(resumedViewport)
        extra["landscapeViewportFrame"] = rectDictionary(landscapeViewport)
        extra["restoredViewportFrame"] = rectDictionary(restoredViewport)
        try emitCapture(route: "/works/[id]#restored-portrait", slug: "works-supplement-restored-portrait",
                        identity: "Works restored portrait", entryPath: "Same journey; rotate back to portrait",
                        context: c, extra: extra, captureKind: "supplement")
    }

    /// At the system XXXL profile, edit the seeded John 1:1 note and confirm that Save persists the new text.
    func testL25Supplement03NoteEditSaveAtXXXL() throws {
        try requireSupplements()
        let c = try makeContext(nativeOnly: true)
        XCTAssertTrue(c.app.wait(for: .runningForeground, timeout: 30))
        assertSystemXXXLProfile()
        try prepareSettings(c)
        try selectJHN11(c)
        try tap(button(c, nativeID: "reader-selection-note", baselineLabel: "Note John 1:1"))

        let editor = c.app.textViews["saved-note-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 15), "The John 1:1 note editor must open")
        XCTAssertTrue(c.app.staticTexts.matching(NSPredicate(format: "label == %@", "John 1:1")).firstMatch.exists,
                       "The editor must show the selected John 1:1 reference")
        let marker = "L25 Oct7 XXXL saved-note check-" + String(repeating: "0123456789", count: 32)
        editor.tap()
        editor.typeText(" \(marker)")
        let keyboard = c.app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 8), "The on-screen keyboard must appear for note editing")
        XCTAssertTrue((editor.value as? String ?? "").contains(marker), "Typed text must appear before Save")
        let keyboardTop = keyboard.frame.minY
        let windowFrame = c.app.windows.firstMatch.frame
        let navigationBar = c.app.navigationBars.firstMatch
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5), "The note editor navigation bar must remain visible")
        let usableTop = max(windowFrame.minY, navigationBar.frame.maxY)
        let usableFrame = CGRect(x: windowFrame.minX, y: usableTop,
                                 width: windowFrame.width,
                                 height: max(0, keyboardTop - usableTop))
        let visibleEditorFrame = editor.frame.intersection(usableFrame)
        XCTAssertTrue(editor.isHittable, "The note editor must be hittable while the keyboard is open")
        XCTAssertGreaterThanOrEqual(visibleEditorFrame.width, 200,
                                    "The note editor must keep a visible writing width above the keyboard")
        XCTAssertGreaterThanOrEqual(visibleEditorFrame.height, 120,
                                    "The note editor must keep a usable visible height above the keyboard")
        try emitCapture(route: "/note#keyboard-xxxl", slug: "note-edit-keyboard-xxxl",
                        identity: "Supplement: note editor with XXXL keyboard",
                        entryPath: "Read John 1; select verse 1; edit note before Save",
                        context: c, extra: ["typedMarker": marker,
                                            "keyboard": keyboardSnapshot(c.app),
                                            "keyboardFrame": rectDictionary(keyboard.frame),
                                            "editorFrame": rectDictionary(editor.frame),
                                            "visibleEditorFrame": rectDictionary(visibleEditorFrame)],
                        captureKind: "supplement")
        let save = c.app.buttons["saved-note-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Save must stay available while the keyboard is open")
        try tap(save)
        XCTAssertTrue(editor.waitForNonExistence(timeout: 15), "Save must close the note editor")

        try tap(tabButton(c.app, "tab-saved"))
        try tap(c.app.buttons["saved-filter-note"])
        let row = c.app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "saved-row-", "John 1:1")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "The saved John 1:1 note must appear in Notes")
        try tap(row)
        let reopened = c.app.textViews["saved-note-editor"]
        XCTAssertTrue(reopened.waitForExistence(timeout: 15), "The saved note must reopen")
        XCTAssertTrue((reopened.value as? String ?? "").contains(marker),
                      "The note editor must keep the text that was saved")
        c.resolvedIdentity = "Supplement: John 1:1 note edit and save at system XXXL"
        try emitCapture(route: "/note#saved-xxxl", slug: "note-edit-save-xxxl",
                        identity: c.resolvedIdentity, entryPath: "Read John 1; select verse 1; edit and save note",
                        context: c, extra: ["savedMarker": marker, "keyboard": keyboardSnapshot(c.app)],
                        captureKind: "supplement")
    }

    func testL25Supplement06EmptyNoteAtXXXL() throws {
        try assertNewNotePlaceholder(contentSize: "accessibility-extra-extra-extra-large",
                                     category: .accessibilityExtraExtraExtraLarge,
                                     slug: "note-empty-xxxl")
    }

    func testL25Supplement07EmptyNoteAtLarge() throws {
        try assertNewNotePlaceholder(contentSize: "large", category: .large, slug: "note-empty-large")
    }

    private func assertNewNotePlaceholder(contentSize: String, category: UIContentSizeCategory,
                                         slug: String) throws {
        try requireSupplements()
        let c = try makeContext(nativeOnly: true)
        XCTAssertTrue(c.app.wait(for: .runningForeground, timeout: 30))
        XCTAssertEqual(ProcessInfo.processInfo.environment["L25_CONTENT_SIZE"], contentSize)
        XCTAssertEqual(UITraitCollection.current.preferredContentSizeCategory, category)
        try prepareSettings(c)
        try selectJHN11(c)
        try tap(button(c, nativeID: "reader-selection-note", baselineLabel: "Note John 1:1"))

        let editor = c.app.textViews["saved-note-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 15), "The John 1:1 note editor must open")
        // The clean fixture starts with the known migration note. Delete it through the app, then reopen
        // the same measured verse so this check uses a deterministic XXXL tap point and a truly empty note.
        let priorText = (editor.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !priorText.isEmpty {
            let delete = c.app.buttons["saved-note-delete"]
            XCTAssertTrue(delete.waitForExistence(timeout: 10), "The fixture note must expose Delete")
            try tap(delete)
            XCTAssertTrue(editor.waitForNonExistence(timeout: 15), "Delete must close the existing note")
            try selectJHN11(c)
            try tap(button(c, nativeID: "reader-selection-note", baselineLabel: "Note John 1:1"))
            XCTAssertTrue(editor.waitForExistence(timeout: 15), "A new empty note editor must open")
        }
        XCTAssertEqual((editor.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines), "",
                       "The new note must start empty")
        editor.tap()
        let keyboard = c.app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 8), "The keyboard must appear when editing a new note")
        let navigationBar = c.app.navigationBars.firstMatch
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))
        let windowFrame = c.app.windows.firstMatch.frame
        let top = max(windowFrame.minY, navigationBar.frame.maxY)
        let visible = editor.frame.intersection(CGRect(x: windowFrame.minX, y: top,
                                                       width: windowFrame.width,
                                                       height: max(0, keyboard.frame.minY - top)))
        XCTAssertTrue(editor.isHittable, "The empty editor must be hittable")
        XCTAssertGreaterThanOrEqual(visible.height, 120, "The empty editor must have usable visible space")
        c.resolvedIdentity = "New John 1:1 note placeholder at system \(contentSize)"
        try emitCapture(route: "/note#empty-\(contentSize)", slug: slug,
                        identity: c.resolvedIdentity, entryPath: "Read John 1; select verse 1; open a new note",
                        context: c, extra: ["editorFrame": rectDictionary(editor.frame),
                                            "visibleEditorFrame": rectDictionary(visible),
                                            "keyboardFrame": rectDictionary(keyboard.frame),
                                            "emptyNotePlaceholderVisualReviewRequired": true],
                        captureKind: "supplement")
        try tap(c.app.buttons["saved-note-cancel"])
    }

    /// At the system XXXL profile, scroll the Lectio action above the tab bar and open its next step.
    func testL25Supplement04LectioContinueAtXXXL() throws {
        try requireSupplements()
        let c = try makeContext(nativeOnly: true)
        XCTAssertTrue(c.app.wait(for: .runningForeground, timeout: 30))
        assertSystemXXXLProfile()
        try prepareSettings(c)
        try selectJHN11(c)
        try tap(button(c, nativeID: "reader-selection-pray", baselineLabel: "Pray John 1:1"))
        let currentTitle = c.app.staticTexts.matching(NSPredicate(format: "label == %@", "Read slowly")).firstMatch
        XCTAssertTrue(currentTitle.waitForExistence(timeout: 15), "Lectio must open for John 1:1")

        let next = c.app.buttons["Continue"]
        let (nextFrame, nextViewport) = try scrollControlFullyAboveTabBar(next)
        next.tap()
        let nextTitle = c.app.staticTexts["content-page-title"]
        let exactNextTitle = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Stay with a word"), object: nextTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [exactNextTitle], timeout: 12), .completed,
                       "Lectio must show the next step after Continue")
        c.resolvedIdentity = "Supplement: Lectio next step at system XXXL"
        try emitCapture(route: "/lectio#continue-xxxl", slug: "lectio-continue-xxxl",
                        identity: c.resolvedIdentity, entryPath: "Read John 1:1; select Pray; scroll to Continue",
                        context: c, extra: ["nextButtonFrameBeforeTap": rectDictionary(nextFrame),
                                            "visibleViewportBeforeTap": rectDictionary(nextViewport)],
                        captureKind: "supplement")
    }

    /// At the system XXXL profile, scroll to the Scripture card image action and open the system share panel.
    func testL25Supplement05ScriptureCardShareAtXXXL() throws {
        try requireSupplements()
        let c = try makeContext(nativeOnly: true)
        XCTAssertTrue(c.app.wait(for: .runningForeground, timeout: 30))
        assertSystemXXXLProfile()
        try prepareSettings(c)
        try selectJHN11(c)
        try tap(button(c, nativeID: "reader-selection-card", baselineLabel: "Create card John 1:1"))
        let shareImage = c.app.buttons["scripture-card-share-image"]
        let (shareFrame, shareViewport) = try scrollControlFullyAboveTabBar(shareImage)
        shareImage.tap()
        let sharePanel = [c.app.otherElements["ActivityListView"],
                          c.app.collectionViews["activityCollectionView"],
                          c.app.cells.matching(NSPredicate(format: "label == %@", "Copy")).firstMatch]
            .first { $0.waitForExistence(timeout: 20) }
        XCTAssertNotNil(sharePanel, "The Scripture card action must open the system share panel")
        c.resolvedIdentity = "Supplement: Scripture card share action at system XXXL"
        try emitCapture(route: "/share-card#share-xxxl", slug: "scripture-card-share-xxxl",
                        identity: c.resolvedIdentity, entryPath: "Read John 1:1; select card; scroll to image share",
                        context: c, extra: ["shareActionFrameBeforeTap": rectDictionary(shareFrame),
                                            "visibleViewportBeforeTap": rectDictionary(shareViewport),
                                            "sharePanelOpened": sharePanel != nil],
                        captureKind: "supplement")
    }

    private func assertSystemXXXLProfile(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(ProcessInfo.processInfo.environment["L25_CONTENT_SIZE"],
                       "accessibility-extra-extra-extra-large", file: file, line: line)
        XCTAssertEqual(UITraitCollection.current.preferredContentSizeCategory,
                       .accessibilityExtraExtraExtraLarge,
                       "The UI test process must read back the system XXXL category", file: file, line: line)
    }

    private func scrollControlFullyAboveTabBar(_ element: XCUIElement,
                                               file: StaticString = #filePath,
                                               line: UInt = #line) throws -> (CGRect, CGRect) {
        for _ in 0..<60 {
            guard element.exists else {
                scrollForLazyRow(element)
                continue
            }
            let frame = element.frame
            let viewport = visibleScrollViewport()
            if element.isHittable && viewport.contains(frame) {
                return (frame, viewport)
            }
            scrollToVisible(element)
        }
        let exists = element.exists
        let frame = exists ? element.frame : .zero
        let viewport = visibleScrollViewport()
        XCTAssertTrue(exists && element.isHittable && viewport.contains(frame),
                      "The control must be fully visible above the tab bar: exists=\(exists) frame=\(NSCoder.string(for: frame)) viewport=\(NSCoder.string(for: viewport))",
                      file: file, line: line)
        return (frame, viewport)
    }

    private func worksProse(_ c: CaptureContext) -> XCUIElement {
        c.app.descendants(matching: .any).matching(identifier: "works-prose").firstMatch
    }

    private func worksBodySnapshot(_ c: CaptureContext) -> String {
        let prose = worksProse(c)
        return prose.label + "|" + String(describing: prose.value ?? "")
    }

    private func worksBodyHash(_ body: String) -> String {
        SHA256.hash(data: Data(body.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func worksPage(_ c: CaptureContext) -> (label: String, page: Int, total: Int)? {
        let element = c.app.staticTexts["works-page-count"]
        guard element.waitForExistence(timeout: 30) else { return nil }
        return parseWorksPageLabel(element.label)
    }

    private func parseWorksPageLabel(_ label: String) -> (label: String, page: Int, total: Int)? {
        let parts = label.components(separatedBy: " of ")
        guard parts.count == 2, parts[0].hasPrefix("Page ") else { return nil }
        let pageText = String(parts[0].dropFirst("Page ".count))
        let totalText = parts[1]
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.isLenient = false
        guard let pageValue = formatter.number(from: pageText),
              let totalValue = formatter.number(from: totalText) else { return nil }
        let page = pageValue.intValue
        let total = totalValue.intValue
        guard page > 0, page <= total,
              formatter.string(from: NSNumber(value: page)) == pageText,
              formatter.string(from: NSNumber(value: total)) == totalText else { return nil }
        return (label, page, total)
    }

    private func waitForOrientation(_ c: CaptureContext, landscape: Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let size = c.app.windows.firstMatch.frame.size
            return landscape ? size.width > size.height : size.height > size.width
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 30), .completed,
                       "The window did not reach the requested orientation")
    }

    private func worksExtra(_ c: CaptureContext, label: String) -> [String: Any] {
        let prose = worksProse(c)
        let body = prose.label + "|" + String(describing: prose.value ?? "")
        let tab = tabButton(c.app, "tab-read")
        let tabEdge = tabBarTopEdge(in: c.app, within: c.app.frame) // same edge as the viewport helpers
        var controls: [String: Any] = [:]
        for (name, prefix) in [("previous", "Previous"), ("contents", "Contents, section"), ("next", "Next")] {
            let control = c.app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
            controls[name] = ["exists": control.exists, "hittable": control.exists && control.isHittable,
                              "label": control.exists ? control.label : "",
                              "aboveTabs": control.exists && tab.exists ? control.frame.maxY <= (tabEdge ?? tab.frame.minY) : false] as [String: Any]
        }
        return [
            "supplement": "works-middle-page-width-change", "pageLabel": label, "tabBar": tabBarRecord(c.app),
            "bodyLabelPrefix": String(prose.label.prefix(160)),
            "bodySHA256": SHA256.hash(data: Data(body.utf8)).map { String(format: "%02x", $0) }.joined(),
            "bodyLength": body.count, "lowerControls": controls,
            "savedAnchorNote": "The app has no export. Main copies the stopped-app envelope (worksPositions) between steps.",
        ]
    }

    private func capture(_ route: String, identity: String, enter: (CaptureContext) throws -> Void) throws {
        let context = try makeContext()
        context.route = route
        XCTAssertTrue(context.app.wait(for: .runningForeground, timeout: 30))
        if route != "/settings" { try prepareSettings(context) }
        try enterRoute(route, context: context, enter: enter)
        try emitCapture(route: route, slug: routeSlug(route), identity: identity, entryPath: entryPath(route), context: context)
    }

    /// Reads the caller environment, launches the app, and returns the capture context.
    /// `nativeOnly` skips before launch when the variant is not native.
    private func makeContext(nativeOnly: Bool = false) throws -> CaptureContext {
        let env = ProcessInfo.processInfo.environment
        let appearance = normalizedAppearance(env["L25_APPEARANCE"] ?? "light", allowSystem: true)
        let textSize = normalizedTextSize(env["L25_TEXT_SIZE"] ?? "Default")
        let layout = normalizedLayout(env["L25_LAYOUT"] ?? "Verse by verse")
        let deviceAppearance = normalizedAppearance(env["L25_EFFECTIVE_DEVICE_APPEARANCE"] ?? "", allowSystem: false)
        guard let appearance, let textSize, let layout, let deviceAppearance,
              (env["L25_EDITION"] ?? "WEB-CE") == "WEB-CE",
              (env["L25_SPACING"] ?? "Comfortable") == "Comfortable",
              (env["L25_TYPEFACE"] ?? "Serif") == "Serif" else {
            throw XCTSkip("Set a supported profile: Light, Dark, or System appearance preference, WEB-CE, Default or Extra large, Comfortable, Serif, Verse by verse or Paragraphs, and effective device appearance (light or dark).")
        }
        guard let variantRaw = env["L25_VARIANT"], let variant = Variant(rawValue: variantRaw),
              let bundleID = env["L25_APP_BUNDLE_ID"], !bundleID.isEmpty,
              let appVersion = env["L25_APP_VERSION"], let build = env["L25_APP_BUILD"],
              let sourceVersion = env["L25_SOURCE_VERSION"], let seedID = env["L25_SEED_ID"],
              let seedState = env["L25_SEED_STATE"], let seedHash = env["L25_SEED_MANIFEST_SHA256"] else {
            throw XCTSkip("Set variant, installed app identity, source identity, and seed identity before capture.")
        }
        if nativeOnly && variant != .native {
            throw XCTSkip("This supplement is native-only.")
        }
        let app = XCUIApplication(bundleIdentifier: bundleID)
        activeApp = app
        activeVariant = variant
        app.launchArguments += ["-L25CaptureMode", "1"]
        app.launchEnvironment["L25_VARIANT"] = variant.rawValue
        // Native only: keep the full tab bar (no Read-tab minimize). Never for the old app (Liquid-glass-tabview-review.md fix 2).
        if variant == .native { app.launchArguments += ["-JohnTabBarMinimize", "never"] }
        app.launch()
        if variant == .baseline {
            // The Expo app can show only its splash color for tens of seconds on a loaded host. Wait for its tab bar.
            let todayTab = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Today, tab")).firstMatch
            XCTAssertTrue(todayTab.waitForExistence(timeout: 90), "Baseline must show its tab bar after launch")
        }
        let context = CaptureContext(app: app, variant: variant, bundleID: bundleID,
            appVersion: appVersion, build: build, sourceVersion: sourceVersion, seedID: seedID,
            expectedAppearance: appearance,
            effectiveDeviceAppearance: deviceAppearance,
            expectedEdition: env["L25_EDITION"] ?? "WEB-CE",
            expectedTextSize: textSize,
            expectedSpacing: env["L25_SPACING"] ?? "Comfortable",
            expectedTypeface: env["L25_TYPEFACE"] ?? "Serif",
            expectedLayout: layout,
            statusBarProfile: env["L25_STATUS_BAR_PROFILE"] ?? "caller-supplied; not changed by this test",
            suppliedDate: env["L25_LOCAL_DATE"], suppliedTimeZone: env["L25_TIME_ZONE"],
            seedStateDescription: seedState, seedManifestHash: seedHash,
            nativeArtifact: env["L25_NATIVE_ARTIFACT"] ?? "caller-supplied installed artifact",
            javascriptSourceVersion: env["L25_JS_SOURCE_VERSION"] ?? sourceVersion)
        activeContext = context
        context.keyboardRequested = env["L25_KEYBOARD"] == "1"
        context.axTreeRequested = env["L25_AX_TREE"] == "1"
        context.auditRequested = env["L25_A11Y_AUDIT"] == "1"
        context.selectedPassageProfileMeasured = env["L25_SELECTED_PASSAGE_PROFILE_MEASURED"] == "1"
        if let raw = env["L25_VERSE1_TAP_OFFSET"] {
            let parts = raw.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count == 2, parts[0] >= 0, parts[1] >= 0 { context.verse1TapOffset = CGPoint(x: parts[0], y: parts[1]) }
        }
        for key in ["L25_CONTENT_SIZE", "L25_REDUCE_MOTION", "L25_INCREASE_CONTRAST", "L25_HARDWARE_KEYBOARD"] {
            if let value = env[key], !value.isEmpty { context.callerFacts[key] = value }
        }
        return context
    }

    private func requireSupplements() throws {
        guard ProcessInfo.processInfo.environment["L25_ENABLE_SUPPLEMENTS"] == "1" else {
            throw XCTSkip("Native-only supplements run only when L25_ENABLE_SUPPLEMENTS=1. Run one method at a time with -only-testing.")
        }
    }

    private func enterRoute(_ route: String, context: CaptureContext, enter: (CaptureContext) throws -> Void) throws {
        let windowSize = context.app.windows.firstMatch.frame.size
        var entered = false
        if isSelectedPassageRoute(route) && !selectedPassageEntryAllowed(context, windowWidth: windowSize.width) {
            let reason = context.expectedLayout == "Paragraphs"
                ? "Selected-passage route entry needs verse controls. Paragraph layout has no reviewed owned-text tap point."
                : "Selected-passage route entry has no reviewed owned-text tap point for this text size or window width."
            recordUnresolved(context, reason: reason)
            context.resolvedIdentity = "Selected passage route entry unresolved; no inherited Default/402pt tap point was used."
            context.selectedPassageTap = "skipped"
        } else {
            try enter(context)
            entered = true
        }
        if context.keyboardRequested {
            if entered { attemptKeyboard(route, context) }
            else { context.keyboardRecord = ["requested": true, "status": "route-entry-unresolved"] }
        }
    }

    /// Native default: the measured 402 pt, Default size, Verse by verse profile.
    /// Main sets L25_SELECTED_PASSAGE_PROFILE_MEASURED=1 after it measures another profile.
    private func selectedPassageEntryAllowed(_ c: CaptureContext, windowWidth: CGFloat) -> Bool {
        if c.expectedLayout == "Paragraphs" { return false }
        if c.selectedPassageProfileMeasured { return c.variant == .baseline || c.verse1TapOffset != nil }
        return c.expectedTextSize != "Extra large" && abs(windowWidth - 402) <= 1
    }

    private func emitCapture(route: String, slug: String, identity: String, entryPath entry: String,
                             context: CaptureContext, extra: [String: Any] = [:],
                             captureKind: String = "route") throws {
        let app = context.app
        let variant = context.variant
        if !context.baselineCoordinateTaps.isEmpty && context.routeStatus == "captured" {
            context.routeStatus = "passed-with-baseline-coordinate-tap"
        }
        let windowSize = app.windows.firstMatch.frame.size
        let png = app.screenshot().pngRepresentation
        let digest = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
        let attachmentName = "L25-\(slug)-\(variant.rawValue).png"
        let imageAttachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        imageAttachment.name = attachmentName
        imageAttachment.lifetime = .keepAlways
        add(imageAttachment)

        var axInfo: [String: Any] = ["attached": false, "origin": "not requested; set L25_AX_TREE=1"]
        if context.axTreeRequested {
            let tree = Data(app.debugDescription.utf8)
            let treeAttachment = XCTAttachment(data: tree, uniformTypeIdentifier: "public.plain-text")
            treeAttachment.name = "L25-\(slug)-\(variant.rawValue)-ax.txt"
            treeAttachment.lifetime = .keepAlways
            add(treeAttachment)
            axInfo = ["attached": true, "attachment": treeAttachment.name ?? "",
                      "sha256": SHA256.hash(data: tree).map { String(format: "%02x", $0) }.joined(),
                      "byteCount": tree.count, "origin": "XCUIApplication.debugDescription at capture time"]
        }
        var auditInfo: [String: Any] = ["status": "not requested; set L25_A11Y_AUDIT=1"]
        if context.auditRequested { auditInfo = runAccessibilityAudit(context, slug: slug) }

        var keyboard = context.keyboardRecord
        for (key, value) in keyboardSnapshot(app) { keyboard[key] = value }

        let captureDate = Date()
        let actualDate = ISO8601DateFormatter().string(from: captureDate)
        let tz = TimeZone.current
        let localDateFormatter = DateFormatter()
        localDateFormatter.calendar = Calendar(identifier: .gregorian)
        localDateFormatter.timeZone = tz
        localDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        localDateFormatter.dateFormat = "yyyy-MM-dd"
        var manifest: [String: Any] = [
            "schema": "l25-route-capture-v1", "captureKind": captureKind,
            "routeKey": route, "resolvedIdentity": context.resolvedIdentity.isEmpty ? identity : context.resolvedIdentity,
            "entryPath": entry, "routeStatus": context.routeStatus,
            "variant": variant.rawValue, "bundleID": context.bundleID, "appVersion": context.appVersion, "build": context.build,
            "sourceVersion": context.sourceVersion, "nativeArtifact": context.nativeArtifact,
            "javascriptSourceVersion": context.javascriptSourceVersion,
            "seedID": context.seedID, "seedState": context.seedStateDescription,
            "seedManifestSHA256": context.seedManifestHash,
            "appearancePreference": context.expectedAppearance,
            "appearancePreferenceOrigin": "requested and checked through the visible app setting; selection evidence is in observedPreferences",
            "effectiveDeviceAppearance": context.effectiveDeviceAppearance,
            "effectiveDeviceAppearanceOrigin": "caller-supplied simulator appearance; not inferred from app preference",
            "observedPreferences": context.observedPreferences,
            "preferenceProfileOrigin": "applied and checked through visible Settings controls; selection-state evidence is in routeStatus",
            "appIdentityOrigin": "caller-verified installed bundle, version, and build",
            "sourceIdentityOrigin": "caller-supplied source or archive identity",
            "edition": context.expectedEdition, "textSize": context.expectedTextSize,
            "lineSpacing": context.expectedSpacing, "typeface": context.expectedTypeface,
            "layout": context.expectedLayout, "localDate": localDateFormatter.string(from: captureDate),
            "localDateOrigin": "device-clock",
            "comparisonDate": context.suppliedDate as Any? ?? NSNull(),
            "timeZone": tz.identifier, "timeZoneOrigin": "device-time-zone",
            "comparisonTimeZone": context.suppliedTimeZone as Any? ?? NSNull(),
            "device": UIDevice.current.name, "deviceClass": UIDevice.current.model,
            "windowPoints": ["width": windowSize.width, "height": windowSize.height],
            "orientation": String(describing: XCUIDevice.shared.orientation),
            "systemVersion": UIDevice.current.systemVersion,
            "statusBarProfile": context.statusBarProfile, "attachment": attachmentName,
            "sha256": digest, "byteCount": png.count, "captureUTC": actualDate,
            "callerFacts": context.callerFacts,
            "callerFactsOrigin": "caller-supplied values; the test does not set or prove them",
            "runnerReadback": [
                "preferredContentSizeCategory": UITraitCollection.current.preferredContentSizeCategory.rawValue,
                "reduceMotionEnabled": UIAccessibility.isReduceMotionEnabled,
                "origin": "UI test runner process values; not proof of the app setting",
            ] as [String: Any],
            "selectedPassageTap": context.selectedPassageTap,
            "tabBar": tabBarRecord(app),
            "baselineOpenJohnPath": context.baselineOpenJohnPath,
            "baselineCoordinateTaps": context.baselineCoordinateTaps,
            "baselineCoordinateTapsOrigin": "old-app taps at the center of a visible, not hittable control; empty for native and for runs without one",
            "keyboard": keyboard, "axTree": axInfo, "accessibilityAudit": auditInfo,
        ]
        for (key, value) in extra { manifest[key] = value }
        let json = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
        let metadata = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
        metadata.name = "L25-\(slug)-\(variant.rawValue).json"
        metadata.lifetime = .keepAlways
        add(metadata)
        NSLog("L25_CAPTURE_MANIFEST %@", String(data: json, encoding: .utf8) ?? "{}")
    }

    /// The tab bar frame and the edge that the viewport helpers use (Liquid-glass-tabview-review.md fix 3).
    private func tabBarRecord(_ app: XCUIApplication) -> [String: Any] {
        let bar = app.tabBars.firstMatch
        var record: [String: Any] = ["barElementExists": bar.exists,
                                     "edgeRule": "tab bar element frame minY; else tab button tops minus 12 pt; none for the old app"]
        if bar.exists { record["barFrame"] = rectDictionary(bar.frame) }
        var buttons: [String: Any] = [:]
        for name in ["tab-today", "tab-read", "tab-saved", "tab-pray", "tab-settings"] {
            let button = tabButton(app, name)
            if button.exists { buttons[name] = rectDictionary(button.frame) }
        }
        record["buttonFrames"] = buttons
        record["edgeUsed"] = tabBarTopEdge(in: app, within: app.frame).map { Double($0) } as Any? ?? NSNull()
        return record
    }

    private func rectDictionary(_ rect: CGRect) -> [String: Double] {
        ["x": rect.minX, "y": rect.minY, "width": rect.width, "height": rect.height]
    }

    /// Records the software keyboard frame and the text inputs that report `hasFocus`.
    /// `hasFocus` is the iOS XCTest attribute. Main must confirm on the first run that it is true for a tapped field.
    /// A connected hardware keyboard can hide the software keyboard. The record says what appeared.
    private func keyboardSnapshot(_ app: XCUIApplication) -> [String: Any] {
        let keyboard = app.keyboards.firstMatch
        let visible = keyboard.exists
        var focused: [String] = []
        let inputs = app.textViews.allElementsBoundByIndex + app.textFields.allElementsBoundByIndex
            + app.searchFields.allElementsBoundByIndex
        for input in inputs where input.exists && input.hasFocus {
            focused.append(input.identifier.isEmpty ? input.label : input.identifier)
        }
        return [
            "softwareKeyboardVisible": visible,
            "softwareKeyboardFrame": visible ? rectDictionary(keyboard.frame) as Any : NSNull(),
            "focusedInputs": focused,
            "keyboardNote": "No software keyboard frame can mean a connected hardware keyboard. The setting is host-wide and the test does not change it.",
        ]
    }

    private func keyboardInputCandidates(_ route: String, _ c: CaptureContext) -> [(String, XCUIElement)] {
        switch route {
        case "/search":
            return [("search-query-input", c.app.textFields["search-query-input"]),
                    ("first search field", c.app.searchFields.firstMatch),
                    ("first text field", c.app.textFields.firstMatch)]
        case "/note":
            return [("saved-note-editor", c.app.textViews["saved-note-editor"]),
                    ("first text view", c.app.textViews.firstMatch),
                    ("first text field", c.app.textFields.firstMatch)]
        case "/confession", "/pray/[id]":
            return [("first text view", c.app.textViews.firstMatch), ("first text field", c.app.textFields.firstMatch)]
        default:
            return []
        }
    }

    /// Optional (L25_KEYBOARD=1). It never fails the test. It records what it did and what appeared.
    private func attemptKeyboard(_ route: String, _ c: CaptureContext) {
        let candidates = keyboardInputCandidates(route, c)
        guard !candidates.isEmpty else {
            c.keyboardRecord = ["requested": true, "status": "route-has-no-keyboard-input"]
            return
        }
        let keyboard = c.app.keyboards.firstMatch
        var chosen: (String, XCUIElement)?
        for candidate in candidates where candidate.1.waitForExistence(timeout: 3) { chosen = candidate; break }
        guard let (name, input) = chosen else {
            c.keyboardRecord = ["requested": true, "status": "input-not-found", "inputsTried": candidates.map(\.0)]
            return
        }
        var status = "input-already-focused-or-keyboard-visible"
        if !keyboard.exists {
            if input.isHittable {
                input.tap()
                status = "input-tapped"
            } else {
                status = "input-not-hittable"
            }
            _ = keyboard.waitForExistence(timeout: 4)
        }
        c.keyboardRecord = ["requested": true, "status": status, "input": name,
                            "keyboardAppearedAfterAction": keyboard.exists]
    }

    private func runAccessibilityAudit(_ c: CaptureContext, slug: String) -> [String: Any] {
        var issues: [String] = []
        do {
            try c.app.performAccessibilityAudit { issue in
                issues.append("type=\(issue.auditType.rawValue) | \(issue.compactDescription) | element=\(issue.element?.label ?? "")")
                return true
            }
        } catch {
            return ["status": "error: \(error)"]
        }
        let attachment = XCTAttachment(string: issues.joined(separator: "\n"))
        attachment.name = "L25-\(slug)-\(c.variant.rawValue)-audit.txt"
        attachment.lifetime = .keepAlways
        add(attachment)
        return ["status": "completed", "issueCount": issues.count, "attachment": attachment.name ?? ""]
    }

    private func openTab(_ name: String, label: String, context c: CaptureContext) throws {
        let element: XCUIElement
        if c.variant == .baseline, let baselineTabLabel = baselineTabLabels[name] {
            element = c.app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", baselineTabLabel)).firstMatch
        } else {
            element = tabButton(c.app, "tab-\(name)")
        }
        try tap(element)
        guard name == "settings" else { return }
        // The first Settings tab tap can be lost while the app is still settling (route series B1: routes 16, 19, 27).
        // Native title: settings-title (FullSettingsView.swift:26). Old title: heading "Settings" (SettingsScreen.tsx:72).
        let title: XCUIElement = c.variant == .native
            ? c.app.staticTexts["settings-title"]
            : c.app.staticTexts.matching(NSPredicate(format: "label == %@", "Settings")).firstMatch
        if !title.waitForExistence(timeout: 10) {
            NSLog("L25_RETRY settings tab tap; the Settings title did not appear in 10 s")
            try tap(element)
        }
        XCTAssertTrue(title.waitForExistence(timeout: 30), "The Settings title must appear after tapping the Settings tab")
    }

    private let baselineTabLabels: [String: String] = [
        "today": "Today, tab",
        "read": "Read, tab",
        "saved": "Saved, tab",
        "pray": "Pray, tab",
        "settings": "Settings, tab",
    ]

    private func prepareSettings(_ c: CaptureContext) throws {
        try openTab("settings", label: "Settings", context: c)
        let selections: [(String, String, String)] = [
            (textSizePreferenceID(c.expectedTextSize), "Text size, \(c.expectedTextSize)", "Text size: \(c.expectedTextSize)"),
            ("settings-line-spacing-comfortable", "Line spacing, Comfortable", "Comfortable"),
            ("settings-scripture-typeface-serif", "Scripture typeface, Serif", "Serif"),
            ("settings-layout-\(c.expectedLayout.lowercased().replacingOccurrences(of: " ", with: "-"))",
             "Layout, \(c.expectedLayout)", c.expectedLayout),
            ("settings-appearance-\(c.expectedAppearance.lowercased())", "Appearance, \(c.expectedAppearance)", "Appearance: \(c.expectedAppearance)"),
            ("translation-web-ce", "World English Bible — Catholic Edition", "WEB-CE")
        ]
        for (id, baselineLabel, logLabel) in selections {
            let element: XCUIElement
            if c.variant == .native {
                element = button(c, nativeID: id, baselineLabel: baselineLabel)
            } else {
                element = c.app.otherElements.matching(NSPredicate(format: "label == %@", baselineLabel)).firstMatch
            }
            XCTAssertTrue(element.waitForExistence(timeout: 30), "Missing common preference choice: \(logLabel)")
            let currentSelection = selectionState(element)
            if c.variant == .baseline {
                XCTAssertNotNil(currentSelection,
                                "Baseline preference must expose an observed checked value: \(logLabel)")
            }
            if currentSelection != true { try tap(element) }
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
                guard let choice = object as? XCUIElement else { return false }
                return self.selectionState(choice) == true
            }, object: element)
            let observedSelected = XCTWaiter.wait(for: [selected], timeout: 30) == .completed
            if observedSelected, isSelected(element) {
                c.observedPreferences[logLabel] = "selected"
                continue
            }
            if c.variant == .baseline && selectionState(element) == nil {
                c.observedPreferences[logLabel] = "unresolved"
                recordUnresolved(c, reason: "Baseline AX does not expose selected state for preference \(logLabel). Do not compare this profile as verified.")
                continue
            }
            XCTAssertTrue(observedSelected && isSelected(element), "The common preference must be committed: \(logLabel)")
        }
    }

    /// Route 8 check. The seeded John 1:1 note ("L00 synthetic migration fixture note.") exists in both apps, so the
    /// editor opens with that text and the placeholder is absent. The editor is accepted by its stable controls and,
    /// when present, the seeded note text.
    /// Old editor (src/screens/NoteEditorScreen.tsx:121-167): buttons "Cancel" and "Save" (or "Saving…"), the reference
    /// "John 1:1", the passage text, the multiline field (label "Note for John 1:1"), and "Delete note" when the note is not empty.
    /// Native editor (SavedView.swift:360-402): `saved-note-cancel`, `saved-note-save`, `saved-note-editor`, `saved-note-delete`.
    private func verifyNoteEditor(_ c: CaptureContext) throws {
        let seeded = "L00 synthetic migration fixture note."
        let cancel: XCUIElement, save: XCUIElement, delete: XCUIElement, reference: XCUIElement
        if c.variant == .native {
            XCTAssertTrue(c.app.textViews["saved-note-editor"].waitForExistence(timeout: 30), "The native note editor must open")
            cancel = c.app.buttons["saved-note-cancel"]
            save = c.app.buttons["saved-note-save"]
            delete = c.app.buttons["saved-note-delete"]
        } else {
            try waitForAny(c.app, ["Cancel"])
            cancel = c.app.buttons.matching(NSPredicate(format: "label == %@", "Cancel")).firstMatch
            save = c.app.buttons.matching(NSPredicate(format: "label == %@", "Save")).firstMatch
            delete = c.app.buttons.matching(NSPredicate(format: "label == %@", "Delete note")).firstMatch
        }
        reference = c.app.staticTexts.matching(NSPredicate(format: "label == %@", "John 1:1")).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 30), "The note editor must show Cancel")
        XCTAssertTrue(save.waitForExistence(timeout: 10), "The note editor must show Save")
        XCTAssertTrue(reference.waitForExistence(timeout: 10), "The note editor must show the reference John 1:1")
        XCTAssertTrue(delete.waitForExistence(timeout: 10), "The seeded note makes Delete note appear")
        let text = c.app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ OR value CONTAINS %@", seeded, seeded)).firstMatch
        let seededShown = text.waitForExistence(timeout: 5)
        c.resolvedIdentity = "Note editor John 1:1; seeded note \(seededShown ? "shown" : "text not exposed"); controls Cancel, Save, Delete note"
    }

    /// Route 5 check. Native keeps its existing control query. The old app exposes each choice as an `Other` element
    /// with the exact label "Text size, Default" and the exact value `radio button, checked` or `radio button, unchecked`
    /// (src/components/PreferencePicker.tsx:38-41; handoff AX facts). The exact equality in `selectionState` keeps the
    /// `unchecked` trap closed.
    private func verifyTextSizeChoice(_ c: CaptureContext) throws {
        if c.variant == .native {
            XCTAssertTrue(button(c, nativeID: textSizePreferenceID(c.expectedTextSize),
                                 baselineLabel: "Text size, \(c.expectedTextSize)").exists)
            return
        }
        let choice = c.app.otherElements.matching(NSPredicate(format: "label == %@", "Text size, \(c.expectedTextSize)")).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 30), "The old Settings screen must expose the Text size choice")
        XCTAssertEqual(choice.value as? String, "radio button, checked",
                       "The requested Text size choice must be checked (exact value)")
        XCTAssertEqual(selectionState(choice), true)
    }

    /// `allowSystem` is true only for the app appearance preference. The device appearance is Light or Dark.
    private func normalizedAppearance(_ value: String, allowSystem: Bool) -> String? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "light": "Light"
        case "dark": "Dark"
        case "system": allowSystem ? "System" : nil
        default: nil
        }
    }

    private func normalizedLayout(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        return switch normalized {
        case "versebyverse": "Verse by verse"
        case "paragraphs": "Paragraphs"
        default: nil
        }
    }

    private func normalizedTextSize(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        return switch normalized {
        case "default": "Default"
        case "extralarge": "Extra large"
        default: nil
        }
    }

    private func textSizePreferenceID(_ value: String) -> String {
        "settings-text-size-\(value.lowercased().replacingOccurrences(of: " ", with: "-"))"
    }

    private func isSelectedPassageRoute(_ route: String) -> Bool {
        ["/note", "/lectio", "/share-card"].contains(route)
    }

    private func waitForPageTitle(_ c: CaptureContext, nativeID: String, baselineTitle: String) throws {
        let title: XCUIElement
        if c.variant == .native {
            title = c.app.staticTexts[nativeID]
        } else {
            title = c.app.staticTexts.matching(NSPredicate(format: "label == %@", baselineTitle)).firstMatch
        }
        XCTAssertTrue(title.waitForExistence(timeout: 30), "Expected the visible page title: \(baselineTitle)")
        XCTAssertEqual(title.label, baselineTitle)
    }

    private func openJohnOne(_ c: CaptureContext) throws {
        try openTab("read", label: "Read", context: c)
        let exactJohnOne = c.variant == .native
            ? c.app.buttons.matching(NSPredicate(format: "label == %@", "John 1")).firstMatch
            : c.app.buttons.matching(NSPredicate(format: "label == %@", "John 1")).firstMatch
        if exactJohnOne.exists { c.baselineOpenJohnPath = c.variant == .baseline ? "already-open" : "not-used"; return }

        let bookList = c.variant == .native
            ? c.app.staticTexts["reader-book-list-title"]
            : c.app.staticTexts.matching(NSPredicate(format: "label == %@", "Read the Bible")).firstMatch
        for _ in 0..<3 where !bookList.exists {
            let back: XCUIElement
            if c.variant == .native {
                back = c.app.buttons["reader-back"]
            } else {
                back = c.app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Back to ")).firstMatch
            }
            XCTAssertTrue(back.waitForExistence(timeout: 30),
                          "A restored Reader route must expose Back to chapters or Back to books")
            try tap(back)
        }
        XCTAssertTrue(bookList.waitForExistence(timeout: 30), "Reader must reach the actual book list before selecting John")
        if c.variant == .native {
            try tap(c.app.buttons["reader-book-JHN"])
            try tap(c.app.buttons["reader-chapter-1"])
            try waitForAny(c.app, ["John 1"])
            XCTAssertEqual(c.app.buttons["reader-title"].label, "John 1")
        } else {
            // Old Read screen (src/screens/ReaderScreen.tsx:607-620): the saved location shows a "Continue reading" button
            // labelled "Continue reading <book> chapter <n>". It restores the saved scrollY (ReaderScreen.tsx:354-357).
            // The seed saves John 1 with scrollY 0, so it should open at the natural top. The helper checks that
            // (Sol required fix 1) and otherwise goes back and uses the chapter grid.
            let continueJohn = c.app.buttons.matching(NSPredicate(format: "label == %@", "Continue reading John chapter 1")).firstMatch
            var notAtTopReason: String?
            if continueJohn.waitForExistence(timeout: 10) {
                try tap(continueJohn)
                let openedTitle = c.app.buttons.matching(NSPredicate(format: "label == %@", "John 1")).firstMatch
                try waitForAny(c.app, ["John 1"])
                XCTAssertEqual(openedTitle.label, "John 1")
                if oldReaderIsAtTop(c) {
                    c.baselineOpenJohnPath = "continue-reading"
                    NSLog("L25_OPEN_JOHN1 baseline path=continue-reading")
                    return
                }
                notAtTopReason = "not-at-top"
                for _ in 0..<2 {
                    let back = c.app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Back to ")).firstMatch
                    XCTAssertTrue(back.waitForExistence(timeout: 30), "A Back control must return to the book list")
                    try tap(back)
                }
                XCTAssertTrue(bookList.waitForExistence(timeout: 30), "The book list must return before the chapter-grid path")
            }
            c.baselineOpenJohnPath = "chapter-grid"
            NSLog("L25_OPEN_JOHN1 baseline path=chapter-grid reason=%@", notAtTopReason ?? "no-continue-reading-button")
            let john = c.app.buttons.matching(NSPredicate(format: "label == %@", "John, 21 chapters")).firstMatch
            try tap(john)
            let chapter = c.app.buttons.matching(NSPredicate(format: "label == %@", "John chapter 1")).firstMatch
            try tap(chapter)
            let chapterTitle = c.app.buttons.matching(NSPredicate(format: "label == %@", "John 1")).firstMatch
            try waitForAny(c.app, ["John 1"])
            XCTAssertEqual(chapterTitle.label, "John 1")
        }
    }

    /// Old Reader natural top (Sol required fix 1). Check where the first verse starts in the visible scroll area.
    /// Its center can be far below the viewport at accessibility XXXL because the verse label is very tall.
    /// Verse by verse: button label "Verse 1. <text>" (src/components/ChapterText.tsx:308).
    /// Paragraphs: the first paragraph text starts with "1 In the beginning".
    private func oldReaderIsAtTop(_ c: CaptureContext) -> Bool {
        let first = c.app.descendants(matching: .any).matching(NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "label BEGINSWITH %@", "Verse 1. "),
            NSPredicate(format: "label BEGINSWITH %@", "1 In the beginning"),
        ])).firstMatch
        guard first.waitForExistence(timeout: 15) else { return false }
        let deadline = Date().addingTimeInterval(5)
        while !first.isHittable && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.25)) }
        let viewport = visibleScrollViewport()
        guard viewport.height > 160 else { return false }
        let firstFrame = first.frame
        NSLog("L25_BASELINE_TOP label=%@ frame=%@ viewport=%@ hittable=%@", first.label,
              NSCoder.string(for: firstFrame), NSCoder.string(for: viewport), first.isHittable.description)
        guard first.isHittable else { return false }
        return firstFrame.intersects(viewport)
            && firstFrame.minY >= viewport.minY - 24
            && firstFrame.minY <= viewport.minY + viewport.height * 0.35
    }

    private func selectJHN11(_ c: CaptureContext) throws {
        try openJohnOne(c)
        let verse = button(c, nativeID: "reader-verse-1", baselineLabel: "Verse 1")
        if c.variant == .native, let offset = c.verse1TapOffset {
            // Main-measured owned-word point (L25_VERSE1_TAP_OFFSET), relative to the verse 1 frame origin.
            XCTAssertTrue(verse.waitForExistence(timeout: 30), "Verse 1 must be present")
            for _ in 0..<6 where !verse.isHittable { scrollToVisible(verse) }
            XCTAssertTrue(verse.isHittable, "Verse 1 must be visible before the measured tap")
            let size = verse.frame.size
            XCTAssertTrue(offset.x < size.width && offset.y < size.height, "The measured tap point must stay inside the verse 1 frame")
            verse.coordinate(withNormalizedOffset: CGVector(dx: offset.x / size.width, dy: offset.y / size.height)).tap()
            c.selectedPassageTap = "offset \(offset.x),\(offset.y)"
        } else {
            try tap(verse)
            c.selectedPassageTap = "center"
        }
        let toolbar = button(c, nativeID: "reader-selection-note", baselineLabel: "Note John 1:1")
        XCTAssertTrue(toolbar.waitForExistence(timeout: 30), "Select JHN 1:1 using the visible Reader control.")
    }

    private func openConfiguredReading(_ c: CaptureContext) throws {
        guard let reference = ProcessInfo.processInfo.environment["L25_READING_REFERENCE"], !reference.isEmpty else {
            throw XCTSkip("Main must set L25_READING_REFERENCE to a local installed reading reference.")
        }
        try openTab("today", label: "Today", context: c)
        let readings = button(c, nativeID: "today-readings-card", baselineLabel: "Today’s readings")
        try tap(readings)
        let reading = c.app.buttons.matching(NSPredicate(format: "label CONTAINS %@", reference)).firstMatch
        try tap(reading)
        let subtitle = c.app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@", "Reading reference: \(reference)"
        )).firstMatch
        XCTAssertTrue(subtitle.waitForExistence(timeout: 30), "The destination must retain the selected reading identity")
        guard let range = reference.range(of: #"^(.+?)\s+([0-9]+)(?::|$)"#, options: .regularExpression) else {
            c.resolvedIdentity = "Passage context reference=\(reference); chapter title not parsed"
            return
        }
        let matched = String(reference[range])
        let pieces = matched.range(of: #"([0-9]+)(?::|$)"#, options: .regularExpression)!
        let chapterText = String(matched[pieces]).split(separator: ":", omittingEmptySubsequences: true).first!
        let bookText = String(matched[..<pieces.lowerBound]).trimmingCharacters(in: .whitespaces)
        let expectedTitle = "\(bookText) \(chapterText)"
        let title: XCUIElement
        if c.variant == .native {
            title = c.app.staticTexts["content-page-title"]
        } else {
            title = c.app.staticTexts.matching(NSPredicate(format: "label == %@", expectedTitle)).firstMatch
        }
        XCTAssertTrue(title.waitForExistence(timeout: 30), "The citation route title must identify \(expectedTitle)")
        XCTAssertEqual(title.label, expectedTitle)
        c.resolvedIdentity = "Passage context title=\(title.label); reference=\(reference); edition=WEB-CE"
    }

    private func openRosary(_ c: CaptureContext) throws {
        try openTab("pray", label: "Pray", context: c)
        try tap(button(c, nativeID: "prayer-home-rosary", baselineLabel: "Pray the Rosary"))
    }

    private func openWorks(_ c: CaptureContext) throws {
        try openJohnOne(c)
        try tap(button(c, nativeID: "reader-back", baselineLabel: "Back to John chapters"))
        try tap(button(c, nativeID: "reader-back", baselineLabel: "Back to books"))
        try waitForAny(c.app, ["Read the Bible"])
        try tap(button(c, nativeID: "reader-works-link", baselineLabel: "The Fathers and Doctors"))
        try waitForAny(c.app, ["The Fathers & Doctors"])
    }

    private func button(_ c: CaptureContext, nativeID: String, baselineLabel: String) -> XCUIElement {
        switch c.variant {
        case .native:
            let identified = c.app.buttons[nativeID]
            if identified.exists { return identified }
            return c.app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", baselineLabel)).firstMatch
        case .baseline:
            return c.app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", baselineLabel)).firstMatch
        }
    }

    private func selectionState(_ element: XCUIElement) -> Bool? {
        if element.isSelected { return true }
        if let value = element.value as? String {
            if value == "Selected" || value == "radio button, checked" || value == "checked" { return true }
            if value == "Not selected" || value == "radio button, unchecked" || value == "unchecked" { return false }
        }
        if let value = element.value as? NSNumber { return value.boolValue }
        return nil
    }

    private func isSelected(_ element: XCUIElement) -> Bool { selectionState(element) == true }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) throws {
        if activeVariant == .baseline {
            try baselineTap(element, file: file, line: line)
            return
        }
        // Native rows can sit far below the viewport at XXXL. Estimate a bounded reach from the
        // current frame, then update the bound as the target moves. A few no-motion gestures can
        // occur during scroll settling, so retry them before reporting a final reach failure.
        let initialViewport = visibleScrollViewport()
        let initialFrame = element.exists ? element.frame : .zero
        let initialDistance = max(0, max(initialFrame.midY - initialViewport.maxY,
                                         initialViewport.minY - initialFrame.midY))
        let initialEstimate = initialViewport.height > 160
            ? Int(ceil(initialDistance / (initialViewport.height * 0.4))) + 6
            : 24
        var dragLimit = min(180, max(24, initialEstimate))
        var dragCount = 0
        var stalledCount = 0
        while dragCount < dragLimit {
            if element.exists && element.isHittable { element.tap(); return }
            let moved = element.exists
                ? scrollToVisible(element, assertProgress: false)
                : scrollForLazyRow(element, assertProgress: false)
            dragCount += 1
            stalledCount = moved ? 0 : stalledCount + 1

            let viewport = visibleScrollViewport()
            if element.exists && viewport.height > 160 {
                let frame = element.frame
                let distance = max(0, max(frame.midY - viewport.maxY, viewport.minY - frame.midY))
                let remainingEstimate = Int(ceil(distance / (viewport.height * 0.4))) + 4
                dragLimit = min(180, max(dragLimit, dragCount + remainingEstimate))
            }
            if stalledCount >= 3 { break }
        }
        let finalViewport = visibleScrollViewport()
        let finalFrame = element.exists ? NSCoder.string(for: element.frame) : "absent"
        guard element.exists else {
            XCTFail("Route control remains absent after \(dragCount) bounded scrolls; viewport=\(NSCoder.string(for: finalViewport)); stalled=\(stalledCount)", file: file, line: line)
            return
        }
        guard element.isHittable else {
            XCTFail("Route control remains not hittable after \(dragCount) bounded scrolls; frame=\(finalFrame) viewport=\(NSCoder.string(for: finalViewport)); stalled=\(stalledCount)", file: file, line: line)
            return
        }
        element.tap()
    }

    private enum BaselineReach { case hittable, visibleNotHittable, missing, unreachable }

    /// Old-app tap. The old lists are virtualized React Native lists with many rows (the Read book list, the Works
    /// collection list), so six drags are not enough. Existing off-screen controls get a drag bound based on their
    /// distance from the viewport. The loop stops after two drags that make no progress. If the control is visible but
    /// reports not hittable (a transient state while the app settles), it waits up to 5 s before a center tap.
    private func baselineTap(_ element: XCUIElement, file: StaticString, line: UInt) throws {
        _ = element.waitForExistence(timeout: 5)
        switch baselineReach(element) {
        case .hittable:
            baselineWaitUntilStable(element) // a tap during scroll momentum can be ignored by the old app
            element.tap()
        case .visibleNotHittable:
            let viewport = visibleScrollViewport()
            let frame = element.frame
            let center = CGPoint(x: frame.midX, y: frame.midY)
            guard viewport.height > 160 && viewport.contains(center) else {
                XCTAssertTrue(false,
                              "Route control moved outside the viewport before the coordinate tap: frame=\(NSCoder.string(for: frame)) viewport=\(NSCoder.string(for: viewport))",
                              file: file, line: line)
                return
            }
            NSLog("L25_COORDINATE_TAP element visible but not hittable after 5 s: %@ frame=%@ viewport=%@", element.label,
                  NSCoder.string(for: frame), NSCoder.string(for: viewport))
            activeContext?.baselineCoordinateTaps.append([
                "label": element.label, "frame": rectDictionary(frame), "route": activeContext?.route ?? "unknown",
            ])
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        case .missing:
            XCTAssertTrue(element.exists, "Expected a route control", file: file, line: line)
            XCTAssertTrue(element.isHittable, "Route control must be hittable", file: file, line: line)
        case .unreachable:
            let viewport = visibleScrollViewport()
            XCTAssertTrue(false,
                          "Route control remains off-screen after scrolling: frame=\(NSCoder.string(for: element.frame)) viewport=\(NSCoder.string(for: viewport))",
                          file: file, line: line)
        }
    }

    /// Waits until the element frame has not moved for 0.6 s (at most 3 s).
    private func baselineWaitUntilStable(_ element: XCUIElement) {
        var last = element.frame
        var stableSince = Date()
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            let now = element.frame
            if now != last { last = now; stableSince = Date() }
            else if Date().timeIntervalSince(stableSince) >= 0.6 { return }
        }
    }

    private func baselineReach(_ element: XCUIElement) -> BaselineReach {
        guard let app = activeApp else { return .missing }
        var stalled = 0
        var reversed = false
        let initialViewport = visibleScrollViewport()
        let initialFrame = element.exists ? element.frame : .zero
        let distanceToViewport = max(0, max(initialFrame.midY - initialViewport.maxY,
                                             initialViewport.minY - initialFrame.midY))
        let estimatedDrags = initialViewport.height > 160
            ? Int(ceil(distanceToViewport / (initialViewport.height * 0.65))) + 6
            : 40
        var dragLimit = element.exists ? min(180, max(40, estimatedDrags)) : 180
        var dragCount = 0
        while dragCount < dragLimit {
            dragCount += 1
            if element.exists && element.isHittable { return .hittable }
            let viewport = visibleScrollViewport()
            if element.exists, viewport.height > 160, viewport.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)) {
                let deadline = Date().addingTimeInterval(5)
                while Date() < deadline {
                    if element.isHittable { return .hittable }
                    RunLoop.current.run(until: Date().addingTimeInterval(0.25))
                }
                return element.isHittable ? .hittable : .visibleNotHittable
            }
            guard viewport.height > 160 else { return .missing }
            let targetFrameBefore = element.exists ? element.frame : nil
            let before = targetFrameBefore == nil ? scrollSignature(app, viewport) : nil
            let towardEnd = element.exists ? element.frame.midY >= viewport.midY : !reversed
            let from = viewport.minY + viewport.height * (towardEnd ? 0.85 : 0.15)
            let to = viewport.minY + viewport.height * (towardEnd ? 0.15 : 0.85)
            let x = viewport.midX / app.frame.width
            app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: from / app.frame.height))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: to / app.frame.height)))
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
            let madeProgress: Bool
            if let targetFrameBefore, element.exists {
                madeProgress = abs(element.frame.midY - targetFrameBefore.midY) > 1
            } else {
                madeProgress = scrollSignature(app, viewport) != before
            }
            if !madeProgress {
                stalled += 1
                if stalled >= 2 {
                    if !element.exists && !reversed { reversed = true; stalled = 0 } else { break }
                }
            } else {
                stalled = 0
            }
            if element.exists, viewport.height > 160 {
                let frame = element.frame
                let remaining = max(0, max(frame.midY - viewport.maxY, viewport.minY - frame.midY))
                let estimate = Int(ceil(remaining / (viewport.height * 0.65))) + 6
                dragLimit = min(180, max(dragLimit, dragCount + estimate))
            }
        }
        if element.exists && element.isHittable { return .hittable }
        guard element.exists else { return .missing }
        let finalViewport = visibleScrollViewport()
        guard finalViewport.height > 160 else { return .unreachable }
        let frame = element.frame
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return finalViewport.contains(center) ? .visibleNotHittable : .unreachable
    }

    /// Labels and vertical positions of the first buttons and static texts in the viewport. A change means the list moved.
    private func scrollSignature(_ app: XCUIApplication, _ viewport: CGRect) -> String {
        var parts: [String] = []
        for query in [app.buttons, app.staticTexts] {
            var found = 0
            for item in query.allElementsBoundByIndex.prefix(80) where item.exists {
                let frame = item.frame
                guard frame.intersects(viewport) else { continue }
                parts.append("\(item.label.prefix(30))@\(Int(frame.minY))")
                found += 1
                if found >= 8 { break }
            }
        }
        return parts.joined(separator: "|")
    }

    @discardableResult
    private func scrollForLazyRow(_ element: XCUIElement, assertProgress: Bool = true) -> Bool {
        let viewport = visibleScrollViewport()
        guard viewport.height > 160 else { return false }
        // Lazy lists can scroll before the requested row exists in the accessibility tree.
        return drag(in: viewport, upward: true, oldFrame: .zero, element: element,
                    allowUnmaterializedTarget: true, assertProgress: assertProgress)
    }

    @discardableResult
    private func scrollToVisible(_ element: XCUIElement, assertProgress: Bool = true) -> Bool {
        let viewport = visibleScrollViewport()
        guard viewport.height > 160 else { return false }
        let frame = element.frame
        let upward = frame.midY >= viewport.midY
        return drag(in: viewport, upward: upward, oldFrame: frame, element: element,
                    assertProgress: assertProgress)
    }

    private func visibleScrollViewport() -> CGRect {
        guard let app = activeApp else { return .zero }
        let scroll = app.scrollViews.allElementsBoundByIndex
            .filter { $0.exists && $0.isHittable }
            .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
        var viewport = (scroll?.frame ?? app.frame).intersection(app.frame)
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists { viewport.size.height = min(viewport.height, keyboard.frame.minY - viewport.minY) }
        let tabTop = tabBarTopEdge(in: app, within: viewport)
        if let tabTop { viewport.size.height = min(viewport.height, tabTop - viewport.minY) }
        let navBottom = app.navigationBars.allElementsBoundByIndex
            .filter { $0.exists && $0.frame.intersects(viewport) }.map(\.frame.maxY).max()
        if let navBottom {
            let top = max(viewport.minY, navBottom)
            viewport = CGRect(x: viewport.minX, y: top, width: viewport.width, height: max(0, viewport.maxY - top))
        }
        return viewport
    }

    private func drag(in viewport: CGRect, upward: Bool, oldFrame: CGRect, element: XCUIElement,
                     allowUnmaterializedTarget: Bool = false, assertProgress: Bool = true) -> Bool {
        guard let app = activeApp else { return false }
        let oldExists = element.exists
        let oldKeyboard = app.keyboards.firstMatch
        let oldKeyboardFrame = oldKeyboard.exists ? oldKeyboard.frame : nil
        let oldSignature = oldExists ? nil : scrollSignature(app, viewport)
        let x = viewport.midX
        let from = viewport.minY + viewport.height * (upward ? 0.75 : 0.25)
        let to = viewport.minY + viewport.height * (upward ? 0.25 : 0.75)
        NSLog("L25_SCROLL viewport=%@ target=%@ direction=%@ keyboard=%@",
              NSCoder.string(for: viewport), NSCoder.string(for: oldFrame), upward ? "up" : "down",
              oldKeyboardFrame.map(NSCoder.string(for:)) ?? "none")
        app.coordinate(withNormalizedOffset: CGVector(dx: x / app.frame.width, dy: from / app.frame.height))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: x / app.frame.width, dy: to / app.frame.height)))
        let moved = NSPredicate { _, _ in
            let currentExists = element.exists
            let targetMoved = currentExists != oldExists || (currentExists && element.frame != oldFrame)
            return targetMoved ||
            (oldKeyboard.exists ? oldKeyboard.frame : nil) != oldKeyboardFrame ||
            (oldSignature != nil && self.scrollSignature(app, viewport) != oldSignature)
        }
        let expectation = XCTNSPredicateExpectation(predicate: moved, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: 2)
        let didMove = result == .completed
        if assertProgress && !(allowUnmaterializedTarget && !oldExists && !element.exists) {
            XCTAssertEqual(result, .completed,
                           "The route target, scroll view, or keyboard must move after the gesture")
        }
        return didMove
    }

    /// `contains` is used only for the old app, where a card label is longer than the visible title.
    private func waitForAny(_ app: XCUIApplication, _ labels: [String], contains: Bool = false) throws {
        let predicate: NSPredicate
        if contains {
            predicate = NSCompoundPredicate(orPredicateWithSubpredicates: labels.map { NSPredicate(format: "label CONTAINS %@", $0) })
        } else {
            predicate = NSPredicate(format: "label IN %@", labels)
        }
        let visible = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(visible.waitForExistence(timeout: 30), "Expected route content: \(labels.joined(separator: ", "))")
    }

    private func recordUnresolved(_ c: CaptureContext, reason: String) {
        c.routeStatus = "unresolved: \(reason)"
        NSLog("L25_UNRESOLVED variant=%@ reason=%@", c.variant.rawValue, reason)
        let attachment = XCTAttachment(string: reason)
        attachment.name = "L25-unresolved-\(c.variant.rawValue).txt"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func routeSlug(_ route: String) -> String {
        let slug = route.lowercased().unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }
            .joined().split(separator: "-").joined(separator: "-")
        return slug.isEmpty ? "today" : slug // Route "/" has an empty slug.
    }

    private func entryPath(_ route: String) -> String {
        switch route {
        case "/": "Today tab"
        case "/read": "Read tab; seeded at JHN 1"
        case "/saved": "Saved tab"
        case "/pray": "Pray tab"
        case "/settings": "Settings tab"
        case "/calendar-notifications": "Settings tab; then the Calendar notifications row (old app row title: Saints, feasts & daily readings)"
        case "/go-to": "Read JHN 1; tap Reader chapter title"
        case "/search": "Read; tap Search Scripture"
        case "/note", "/lectio", "/share-card": "Read JHN 1:1; select verse 1; tap the named toolbar action"
        case "/verse": "Today; tap Verse & lock screen widget"
        case "/daily?date=…", "/sunday": "Today; tap the visible readings or Sunday card"
        case "/passage?reference=…": "Today readings; tap caller-supplied installed reading"
        case "/prayers", "/prayer?id=…": "Pray; tap Everyday prayers; optional Morning Offering"
        case "/learn", "/teaching?id=…": "Today; tap Explore the Catholic faith; optional The Eucharist"
        case "/confession": "Today; tap Prepare for Confession"
        case "/pray/[id]": "Pray; tap St. Padre Pio Novena"
        case "/pray/rosary", "/pray/rosary-guide?set=…", "/pray/rosary-reminder", "/pray/rosary-media?episode=…": "Pray; tap Pray the Rosary; then the named visible control"
        case "/works": "Read JHN 1; Reader Back to chapters; Reader Back to books; Fathers and Doctors row"
        case "/works/author/[id]", "/works/[id]?section=…": "Reader back controls; Works library; Augustine collection; optional The Confessions"
        case "/commentary/[book]/[chapter]": "Read JHN 1; tap All 30 readings on this chapter"
        default: "Visible controls only"
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
            let barIdentifier = bar.buttons.matching(identifier: identifier).firstMatch
            let barLabel = bar.buttons.matching(NSPredicate(format: "label == %@", String(label))).firstMatch
            let appIdentifier = app.buttons.matching(identifier: identifier).firstMatch
            let appLabel = app.buttons.matching(NSPredicate(format: "label == %@", String(label))).firstMatch
            return [barIdentifier, barLabel, appIdentifier, appLabel].first { $0.exists }
        }
        if let found = find() { return found }
        if bar.exists, bar.isHittable {
            bar.tap()
            _ = bar.buttons.matching(NSPredicate(format: "label == %@", String(label))).firstMatch
                .waitForExistence(timeout: 2)
            if let found = find() { return found }
        }
        return app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@",
                                                identifier, String(label))).firstMatch
    }
}
