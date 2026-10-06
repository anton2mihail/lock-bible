import CryptoKit
import Foundation
import UIKit
import XCTest

/// L25 route captures. This file uses visible controls only. Main owns target membership and runs.
@MainActor
final class AllRouteCaptureUITests: XCTestCase {
    private var activeApp: XCUIApplication?
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
        let expectedEdition: String
        let expectedTextSize: String
        let expectedSpacing: String
        let expectedTypeface: String
        let expectedLayout: String
        let statusBarProfile: String
        let suppliedDate: String?
        let suppliedTimeZone: String?
        var routeStatus = "captured"
        var resolvedIdentity = ""
        let seedStateDescription: String
        let seedManifestHash: String
        let nativeArtifact: String
        let javascriptSourceVersion: String

        init(app: XCUIApplication, variant: Variant, bundleID: String, appVersion: String,
             build: String, sourceVersion: String, seedID: String,
             expectedAppearance: String, expectedEdition: String, expectedTextSize: String,
             expectedSpacing: String, expectedTypeface: String, expectedLayout: String,
             statusBarProfile: String, suppliedDate: String?, suppliedTimeZone: String?,
             seedStateDescription: String, seedManifestHash: String,
             nativeArtifact: String, javascriptSourceVersion: String) {
            self.app = app; self.variant = variant; self.bundleID = bundleID
            self.appVersion = appVersion; self.build = build; self.sourceVersion = sourceVersion
            self.seedID = seedID; self.expectedAppearance = expectedAppearance
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
    func testL25Route04PrayerHome() throws { try capture("/pray", identity: "PrayerHome") { c in try openTab("pray", label: "Pray", context: c); try waitForAny(c.app, ["Pray the Rosary"]) } }
    func testL25Route05Settings() throws { try capture("/settings", identity: "Settings; matched reader preferences") { c in try prepareSettings(c); XCTAssertTrue(button(c, nativeID: "settings-text-size-default", baselineLabel: "Text size, Default").exists) } }
    func testL25Route06GoTo() throws { try capture("/go-to", identity: "GoTo; current JHN 1") { c in try openJohnOne(c); try tap(button(c, nativeID: "reader-title", baselineLabel: "John 1")); try waitForAny(c.app, ["Go to", "Go To", "Choose a book"]) } }
    func testL25Route07Search() throws { try capture("/search", identity: "Search Scripture") { c in try openJohnOne(c); try tap(button(c, nativeID: "reader-search-button", baselineLabel: "Search Scripture")); try waitForAny(c.app, ["Search Scripture", "Search by reference, keyword, or exact phrase."]) } }
    func testL25Route08NoteEditor() throws { try capture("/note", identity: "Selected WEB-CE JHN 1:1 note editor") { c in try selectJHN11(c); try tap(button(c, nativeID: "reader-selection-note", baselineLabel: "Note John 1:1")); if c.variant == .native { XCTAssertTrue(c.app.textViews["saved-note-editor"].waitForExistence(timeout: 12)) } else { try waitForAny(c.app, ["Write a private note…"]) } } }
    func testL25Route09VerseMoment() throws { try capture("/verse", identity: "Verse of the moment") { c in try openTab("today", label: "Today", context: c); try tap(button(c, nativeID: "today-verse-card", baselineLabel: "Verse & lock screen widget")); try waitForAny(c.app, ["Verse of the moment", "No verse available."]) } }
    func testL25Route10DailyReadings() throws { try capture("/daily?date=…", identity: "Daily readings; caller date or current local date") { c in try openTab("today", label: "Today", context: c); try tap(button(c, nativeID: "today-readings-card", baselineLabel: "Today’s readings")); try waitForAny(c.app, ["Today’s readings"]) } }
    func testL25Route11SundayPreparation() throws { try capture("/sunday", identity: "Sunday preparation; caller date or upcoming Sunday") { c in try openTab("today", label: "Today", context: c); try tap(button(c, nativeID: "today-sunday", baselineLabel: "Come ready for Sunday")); try waitForAny(c.app, ["Come ready for Sunday"]) } }
    func testL25Route12PassageContext() throws { try capture("/passage?reference=…", identity: "Caller-supplied L25_READING_REFERENCE") { c in try openConfiguredReading(c) } }
    func testL25Route13Lectio() throws { try capture("/lectio", identity: "WEB-CE JHN 1:1 selected passage") { c in try selectJHN11(c); try tap(button(c, nativeID: "reader-selection-pray", baselineLabel: "Pray John 1:1")); try waitForAny(c.app, ["Read slowly", "Pray with Scripture"]) } }
    func testL25Route14PrayerLibrary() throws { try capture("/prayers", identity: "Prayer library") { c in try openTab("pray", label: "Pray", context: c); try tap(button(c, nativeID: "prayer-library", baselineLabel: "Everyday prayers")); try waitForAny(c.app, ["Prayer for every day", "Find a prayer…"]) } }
    func testL25Route15PrayerDetail() throws { try capture("/prayer?id=…", identity: "Prayer id morning") { c in try openTab("pray", label: "Pray", context: c); try tap(button(c, nativeID: "prayer-library", baselineLabel: "Everyday prayers")); try tap(button(c, nativeID: "prayer-morning", baselineLabel: "Morning offering")); try waitForAny(c.app, ["Morning offering"]) } }
    func testL25Route16TeachingLibrary() throws { try capture("/learn", identity: "Teaching library") { c in try openTab("today", label: "Today", context: c); try tap(button(c, nativeID: "today-learn", baselineLabel: "Explore the Catholic faith")); try waitForAny(c.app, ["Faith, rooted in Scripture"]) } }
    func testL25Route17TeachingDetail() throws { try capture("/teaching?id=…", identity: "Teaching id eucharist") { c in try openTab("today", label: "Today", context: c); try tap(button(c, nativeID: "today-learn", baselineLabel: "Explore the Catholic faith")); try tap(button(c, nativeID: "teaching-eucharist", baselineLabel: "The Eucharist")); try waitForAny(c.app, ["The Eucharist"]) } }
    func testL25Route18Confession() throws { try capture("/confession", identity: "Confession guide initial step") { c in try openTab("today", label: "Today", context: c); try tap(button(c, nativeID: "today-confession", baselineLabel: "Prepare for Confession")); try waitForAny(c.app, ["Prepare for Confession", "Prepare"]) } }
    func testL25Route19ScriptureCard() throws { try capture("/share-card", identity: "Selected WEB-CE JHN 1:1 card") { c in try selectJHN11(c); try tap(button(c, nativeID: "reader-selection-card", baselineLabel: "Create card John 1:1")); try waitForAny(c.app, ["A word worth sharing"]) } }
    func testL25Route20CalendarNotifications() throws { try capture("/calendar-notifications", identity: "Calendar notification settings") { c in try prepareSettings(c); try tap(button(c, nativeID: "settings-calendar-notifications", baselineLabel: "Calendar notifications")); try waitForAny(c.app, [c.variant == .native ? "A day in the Church" : "Calendar notifications"]) } }
    func testL25Route21NovenaDetail() throws { try capture("/pray/[id]", identity: "Novena id st-padre-pio") { c in try openTab("pray", label: "Pray", context: c); try tap(button(c, nativeID: "novena-st-padre-pio", baselineLabel: "St. Padre Pio Novena")); try waitForAny(c.app, ["St. Padre Pio Novena"]) } }
    func testL25Route22RosaryHome() throws { try capture("/pray/rosary", identity: "Rosary home") { c in try openTab("pray", label: "Pray", context: c); try tap(button(c, nativeID: "prayer-home-rosary", baselineLabel: "Pray the Rosary")); try waitForAny(c.app, ["Choose a mystery"]) } }
    func testL25Route23RosaryGuide() throws { try capture("/pray/rosary-guide?set=…", identity: "Named Joyful set") { c in try openRosary(c); try tap(button(c, nativeID: "rosary-set-joyful", baselineLabel: "The Joyful Mysteries")); try waitForAny(c.app, ["Joyful"]) } }
    func testL25Route24RosaryReminder() throws { try capture("/pray/rosary-reminder", identity: "Rosary reminder settings") { c in try openRosary(c); try tap(button(c, nativeID: "rosary-reminder", baselineLabel: "Rosary reminder")); try waitForAny(c.app, ["Rosary reminder"]) } }
    func testL25Route25RosaryMedia() throws { try capture("/pray/rosary-media?episode=…", identity: "Rosary media episode resolved from visible series entry") { c in
        try openRosary(c)
        try waitForAny(c.app, ["The Rosary with Bishop Barron"])
        let media = c.app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Bishop Robert Barron")).firstMatch
        if media.waitForExistence(timeout: 2) && !media.label.localizedCaseInsensitiveContains("opens on YouTube") {
            let entryLabel = media.label
            try tap(media)
            try waitForAny(c.app, ["WORD ON FIRE SERIES"])
            let ids = ["why-pray", "how-to-pray", "joyful", "sorrowful", "glorious", "luminous"]
            let selectedID = ids.first { id in
                let choice = c.app.buttons["rosary-media-episode-\(id)"]
                return choice.exists && selectionState(choice) == true
            }
            XCTAssertNotNil(selectedID, "The media route must expose a selected source episode")
            c.resolvedIdentity = "Rosary media episode=\(selectedID ?? "unobserved"); entry=\(entryLabel)"
        } else {
            c.resolvedIdentity = "Rosary media unresolved; visible Release action is external"
            recordUnresolved(c, reason: "The visible Release control opens an external website. This route was not opened.")
        }
    } }
    func testL25Route26WorksLibrary() throws { try capture("/works", identity: "Works library from Reader chapter and book controls") { c in try openWorks(c) } }
    func testL25Route27WorksCollection() throws { try capture("/works/author/[id]", identity: "Collection augustine") { c in try openWorks(c); try tap(button(c, nativeID: "collection-augustine", baselineLabel: "Augustine")); try waitForAny(c.app, ["Augustine"]) } }
    func testL25Route28WorkReader() throws { try capture("/works/[id]?section=…", identity: "Work augustine.the-confessions, section 0") { c in try openWorks(c); try tap(button(c, nativeID: "collection-augustine", baselineLabel: "Augustine")); try tap(button(c, nativeID: "work-augustine.the-confessions", baselineLabel: "The Confessions")); try waitForAny(c.app, ["The Confessions"]) } }
    func testL25Route29ChapterCommentary() throws { try capture("/commentary/[book]/[chapter]", identity: "JHN 1; all 30 readings") { c in try openJohnOne(c); try tap(button(c, nativeID: "reader-commentary-all", baselineLabel: "All 30 readings on this chapter")); try waitForAny(c.app, ["Chapter Commentary", "All 30 readings"]) } }

    private func capture(_ route: String, identity: String, enter: (CaptureContext) throws -> Void) throws {
        let env = ProcessInfo.processInfo.environment
        guard (env["L25_APPEARANCE"] ?? "light") == "light",
              (env["L25_EDITION"] ?? "WEB-CE") == "WEB-CE",
              (env["L25_TEXT_SIZE"] ?? "Default") == "Default",
              (env["L25_SPACING"] ?? "Comfortable") == "Comfortable",
              (env["L25_TYPEFACE"] ?? "Serif") == "Serif",
              (env["L25_LAYOUT"] ?? "Verse by verse") == "Verse by verse" else {
            throw XCTSkip("This capture file applies one matched profile: Light, WEB-CE, Default, Comfortable, Serif, Verse by verse.")
        }
        guard let variantRaw = env["L25_VARIANT"], let variant = Variant(rawValue: variantRaw),
              let bundleID = env["L25_APP_BUNDLE_ID"], !bundleID.isEmpty,
              let appVersion = env["L25_APP_VERSION"], let build = env["L25_APP_BUILD"],
              let sourceVersion = env["L25_SOURCE_VERSION"], let seedID = env["L25_SEED_ID"],
              let seedState = env["L25_SEED_STATE"], let seedHash = env["L25_SEED_MANIFEST_SHA256"] else {
            throw XCTSkip("Set variant, installed app identity, source identity, and seed identity before capture.")
        }
        let app = XCUIApplication(bundleIdentifier: bundleID)
        activeApp = app
        app.launchArguments += ["-L25CaptureMode", "1"]
        app.launchEnvironment["L25_VARIANT"] = variant.rawValue
        app.launch()
        let context = CaptureContext(app: app, variant: variant, bundleID: bundleID,
            appVersion: appVersion, build: build, sourceVersion: sourceVersion, seedID: seedID,
            expectedAppearance: env["L25_APPEARANCE"] ?? "light",
            expectedEdition: env["L25_EDITION"] ?? "WEB-CE",
            expectedTextSize: env["L25_TEXT_SIZE"] ?? "Default",
            expectedSpacing: env["L25_SPACING"] ?? "Comfortable",
            expectedTypeface: env["L25_TYPEFACE"] ?? "Serif",
            expectedLayout: env["L25_LAYOUT"] ?? "Verse by verse",
            statusBarProfile: env["L25_STATUS_BAR_PROFILE"] ?? "caller-supplied; not changed by this test",
            suppliedDate: env["L25_LOCAL_DATE"], suppliedTimeZone: env["L25_TIME_ZONE"],
            seedStateDescription: seedState, seedManifestHash: seedHash,
            nativeArtifact: env["L25_NATIVE_ARTIFACT"] ?? "caller-supplied installed artifact",
            javascriptSourceVersion: env["L25_JS_SOURCE_VERSION"] ?? sourceVersion)

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        if route != "/settings" { try prepareSettings(context) }
        try enter(context)
        let png = app.screenshot().pngRepresentation
        let digest = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
        let attachmentName = "L25-\(routeSlug(route))-\(variant.rawValue).png"
        let imageAttachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        imageAttachment.name = attachmentName
        imageAttachment.lifetime = .keepAlways
        add(imageAttachment)

        let captureDate = Date()
        let actualDate = ISO8601DateFormatter().string(from: captureDate)
        let tz = TimeZone.current
        let localDateFormatter = DateFormatter()
        localDateFormatter.calendar = Calendar(identifier: .gregorian)
        localDateFormatter.timeZone = tz
        localDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        localDateFormatter.dateFormat = "yyyy-MM-dd"
        let manifest: [String: Any] = [
            "schema": "l25-route-capture-v1", "routeKey": route, "resolvedIdentity": context.resolvedIdentity.isEmpty ? identity : context.resolvedIdentity,
            "entryPath": entryPath(route), "routeStatus": context.routeStatus,
            "variant": variant.rawValue, "bundleID": bundleID, "appVersion": appVersion, "build": build,
            "sourceVersion": sourceVersion, "nativeArtifact": context.nativeArtifact,
            "javascriptSourceVersion": context.javascriptSourceVersion,
            "seedID": seedID, "seedState": context.seedStateDescription,
            "seedManifestSHA256": context.seedManifestHash, "appearance": context.expectedAppearance,
            "appearanceOrigin": "requested through visible Settings controls; selection-state evidence is in routeStatus",
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
            "orientation": String(describing: XCUIDevice.shared.orientation),
            "systemVersion": UIDevice.current.systemVersion,
            "statusBarProfile": context.statusBarProfile, "attachment": attachmentName,
            "sha256": digest, "byteCount": png.count, "captureUTC": actualDate
        ]
        let json = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
        let metadata = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
        metadata.name = "L25-\(routeSlug(route))-\(variant.rawValue).json"
        metadata.lifetime = .keepAlways
        add(metadata)
        NSLog("L25_CAPTURE_MANIFEST %@", String(data: json, encoding: .utf8) ?? "{}")
    }

    private func openTab(_ name: String, label: String, context c: CaptureContext) throws {
        let element = button(c, nativeID: "tab-\(name)", baselineLabel: label)
        try tap(element)
    }

    private func prepareSettings(_ c: CaptureContext) throws {
        try openTab("settings", label: "Settings", context: c)
        let selections: [(String, String, String)] = [
            ("settings-text-size-default", "Text size, Default", "Default"),
            ("settings-line-spacing-comfortable", "Line spacing, Comfortable", "Comfortable"),
            ("settings-scripture-typeface-serif", "Scripture typeface, Serif", "Serif"),
            ("settings-layout-verse-by-verse", "Layout, Verse by verse", "Verse by verse"),
            ("settings-appearance-light", "Appearance, Light", "Light"),
            ("translation-web-ce", "World English Bible — Catholic Edition", "WEB-CE")
        ]
        for (id, baselineLabel, logLabel) in selections {
            let element: XCUIElement
            if c.variant == .native {
                element = button(c, nativeID: id, baselineLabel: baselineLabel)
            } else {
                element = c.app.descendants(matching: .any).matching(
                    NSPredicate(format: "label == %@ OR label CONTAINS[c] %@", baselineLabel, baselineLabel)
                ).firstMatch
            }
            XCTAssertTrue(element.waitForExistence(timeout: 8), "Missing common preference choice: \(logLabel)")
            if !isSelected(element) { try tap(element) }
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
                guard let choice = object as? XCUIElement else { return false }
                return self.selectionState(choice) != nil
            }, object: element)
            let observed = XCTWaiter.wait(for: [selected], timeout: 8) == .completed
            if observed, isSelected(element) { continue }
            if c.variant == .baseline && !observed {
                recordUnresolved(c, reason: "Baseline AX does not expose selected state for preference \(logLabel). Do not compare this profile as verified.")
                continue
            }
            XCTAssertTrue(observed && isSelected(element), "The common preference must be committed: \(logLabel)")
        }
    }

    private func waitForPageTitle(_ c: CaptureContext, nativeID: String, baselineTitle: String) throws {
        let title: XCUIElement
        if c.variant == .native {
            title = c.app.staticTexts[nativeID]
        } else {
            title = c.app.staticTexts.matching(NSPredicate(format: "label == %@", baselineTitle)).firstMatch
        }
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Expected the visible page title: \(baselineTitle)")
        XCTAssertEqual(title.label, baselineTitle)
    }

    private func openJohnOne(_ c: CaptureContext) throws {
        try openTab("read", label: "Read", context: c)
        let currentTitle = c.variant == .native
            ? c.app.buttons["reader-title"]
            : c.app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "John 1")).firstMatch
        if currentTitle.exists, currentTitle.label.localizedCaseInsensitiveContains("John 1") { return }
        if currentTitle.exists,
           currentTitle.label.range(of: #"^John [0-9]+$"#, options: .regularExpression) != nil {
            try tap(button(c, nativeID: "reader-back", baselineLabel: "Back to John chapters"))
        }
        let book = button(c, nativeID: "reader-book-JHN", baselineLabel: "John")
        if book.waitForExistence(timeout: 2) { try tap(book) }
        let chapter = button(c, nativeID: "reader-chapter-1", baselineLabel: "John chapter 1")
        if chapter.waitForExistence(timeout: 8) { try tap(chapter) }
        try waitForAny(c.app, ["John 1", "JOHN 1"])
    }

    private func selectJHN11(_ c: CaptureContext) throws {
        try openJohnOne(c)
        let verse = button(c, nativeID: "reader-verse-1", baselineLabel: "Verse 1")
        try tap(verse)
        let toolbar = button(c, nativeID: "reader-selection-note", baselineLabel: "Note John 1:1")
        XCTAssertTrue(toolbar.waitForExistence(timeout: 8), "Select JHN 1:1 using the visible Reader control.")
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
        XCTAssertTrue(subtitle.waitForExistence(timeout: 10), "The destination must retain the selected reading identity")
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
        XCTAssertTrue(title.waitForExistence(timeout: 10), "The citation route title must identify \(expectedTitle)")
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
            if value == "Selected" || value.lowercased() == "checked" { return true }
            if value == "Not selected" || value.lowercased() == "unchecked" { return false }
        }
        if let value = element.value as? NSNumber { return value.boolValue }
        return nil
    }

    private func isSelected(_ element: XCUIElement) -> Bool { selectionState(element) == true }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) throws {
        for _ in 0..<6 {
            if element.exists && element.isHittable { element.tap(); return }
            if element.exists { scrollToVisible(element) }
            else { scrollForLazyRow(element) }
        }
        XCTAssertTrue(element.exists, "Expected a route control", file: file, line: line)
        XCTAssertTrue(element.isHittable, "Route control must be hittable", file: file, line: line)
        element.tap()
    }

    private func scrollForLazyRow(_ element: XCUIElement) {
        let viewport = visibleScrollViewport()
        guard viewport.height > 160 else { return }
        // Lazy lists can scroll before the requested row exists in the accessibility tree.
        drag(in: viewport, upward: true, oldFrame: .zero, element: element, allowUnmaterializedTarget: true)
    }

    private func scrollToVisible(_ element: XCUIElement) {
        let viewport = visibleScrollViewport()
        guard viewport.height > 160 else { return }
        let frame = element.frame
        let upward = frame.midY >= viewport.midY
        drag(in: viewport, upward: upward, oldFrame: frame, element: element)
    }

    private func visibleScrollViewport() -> CGRect {
        guard let app = activeApp else { return .zero }
        let scroll = app.scrollViews.allElementsBoundByIndex
            .filter { $0.exists && $0.isHittable }
            .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
        var viewport = (scroll?.frame ?? app.frame).intersection(app.frame)
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists { viewport.size.height = min(viewport.height, keyboard.frame.minY - viewport.minY) }
        let tabTop = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tab-"))
            .allElementsBoundByIndex.filter { $0.exists && $0.frame.intersects(viewport) }
            .map(\.frame.minY).min()
        if let tabTop { viewport.size.height = min(viewport.height, tabTop - viewport.minY) }
        let navBottom = app.navigationBars.allElementsBoundByIndex
            .filter { $0.exists && $0.frame.intersects(viewport) }.map(\.frame.maxY).max()
        if let navBottom {
            let top = max(viewport.minY, navBottom)
            viewport = CGRect(x: viewport.minX, y: top, width: viewport.width, height: max(0, viewport.maxY - top))
        }
        return viewport
    }

    private func drag(in viewport: CGRect, upward: Bool, oldFrame: CGRect, element: XCUIElement, allowUnmaterializedTarget: Bool = false) {
        guard let app = activeApp else { return }
        let oldExists = element.exists
        let oldKeyboard = app.keyboards.firstMatch
        let oldKeyboardFrame = oldKeyboard.exists ? oldKeyboard.frame : nil
        let x = viewport.midX
        let from = viewport.minY + viewport.height * (upward ? 0.75 : 0.25)
        let to = viewport.minY + viewport.height * (upward ? 0.25 : 0.75)
        NSLog("L25_SCROLL viewport=%@ target=%@ direction=%@ keyboard=%@",
              NSCoder.string(for: viewport), NSCoder.string(for: oldFrame), upward ? "up" : "down",
              oldKeyboardFrame.map(NSCoder.string(for:)) ?? "none")
        app.coordinate(withNormalizedOffset: CGVector(dx: x / app.frame.width, dy: from / app.frame.height))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: x / app.frame.width, dy: to / app.frame.height)))
        let moved = NSPredicate { _, _ in
            element.exists != oldExists || element.frame != oldFrame ||
            (oldKeyboard.exists ? oldKeyboard.frame : nil) != oldKeyboardFrame
        }
        let expectation = XCTNSPredicateExpectation(predicate: moved, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: 2)
        if !(allowUnmaterializedTarget && !oldExists && !element.exists) {
            XCTAssertEqual(result, .completed,
                           "The route target, scroll view, or keyboard must move after the gesture")
        }
    }

    private func waitForAny(_ app: XCUIApplication, _ labels: [String]) throws {
        let predicate = NSPredicate(format: "label IN %@", labels)
        let visible = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(visible.waitForExistence(timeout: 12), "Expected route content: \(labels.joined(separator: ", "))")
    }

    private func recordUnresolved(_ c: CaptureContext, reason: String) {
        c.routeStatus = "unresolved: \(reason)"
        NSLog("L25_UNRESOLVED variant=%@ reason=%@", c.variant.rawValue, reason)
        let attachment = XCTAttachment(string: reason)
        attachment.name = "L25-unresolved-rosary-media-\(c.variant.rawValue).txt"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func routeSlug(_ route: String) -> String {
        route.lowercased().unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }
            .joined().split(separator: "-").joined(separator: "-")
    }

    private func entryPath(_ route: String) -> String {
        switch route {
        case "/": "Today tab"
        case "/read": "Read tab; seeded at JHN 1"
        case "/saved": "Saved tab"
        case "/pray": "Pray tab"
        case "/settings", "/calendar-notifications": "Settings tab; then visible Calendar notifications row"
        case "/go-to": "Read JHN 1; tap Reader chapter title"
        case "/search": "Read; tap Search Scripture"
        case "/note", "/lectio", "/share-card": "Read JHN 1:1; select verse 1; tap the named toolbar action"
        case "/verse": "Today; tap Verse & lock screen widget"
        case "/daily?date=…", "/sunday": "Today; tap the visible readings or Sunday card"
        case "/passage?reference=…": "Today readings; tap caller-supplied installed reading"
        case "/prayers", "/prayer?id=…": "Pray; tap Everyday prayers; optional Morning offering"
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
}
