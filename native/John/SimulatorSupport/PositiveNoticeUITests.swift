import XCTest

/// UI-only notice journeys. Main owns task-only seeds, system permission state,
/// request snapshots, target membership, and every simulator run.
@MainActor
final class PositiveNoticeUITests: XCTestCase {
    private let timeout: TimeInterval = 12
    private var activeApp: XCUIApplication?
    private var activeBundleID: String?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAuthorizedCalendarAndRosaryNoticeSettings() throws {
        let seedID = try requiredEnvironment("L22_NOTICE_SEED_ID")
        let bundleID = try requiredEnvironment("L22_NOTICE_BUNDLE_ID")
        let app = try launch(configuration: "authorized")
        let calendarEnabled = app.switches["calendar-notifications-enabled"]

        openCalendarSettings(in: app)
        setSwitch(calendarEnabled, on: true)
        tap(app.buttons["calendar-notifications-delivery-time"])
        setTime(hour: 9, minute: 15, in: app)
        tap(app.buttons["calendar-notifications-save"])
        if ProcessInfo.processInfo.environment["L22_NOTICE_INITIAL_AUTHORIZATION"] == "notDetermined" {
            allowCalendarPermission(in: app)
        }
        XCTAssertTrue(app.staticTexts["Calendar notifications are on."].waitForExistence(timeout: timeout))
        stage("calendar-on-0915")
        tapSystemBack(in: app, expecting: app.staticTexts["settings-title"])

        openCalendarSettings(in: app)
        XCTAssertTrue(calendarEnabled.exists)
        XCTAssertTrue(calendarEnabled.value as? String == "1", "Calendar must remain enabled after re-entry")
        tap(app.buttons["calendar-notifications-delivery-time"])
        assertTime(hour: 9, minute: 15, in: app)
        tapSystemBack(in: app, expecting: app.staticTexts["settings-title"])

        openRosaryReminder(in: app)
        let rosaryEnabled = app.switches["rosary-reminder-enabled"]
        setSwitch(rosaryEnabled, on: true)
        tap(app.buttons["rosary-reminder-frequency-weekly"])
        tap(app.buttons["rosary-reminder-weekday-2"])
        setTime(hour: 8, minute: 30, in: app, compactPickerID: "rosary-reminder-time")
        tap(app.buttons["rosary-reminder-save"])
        let monday830 = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Saved · Every Monday at ")).firstMatch
        XCTAssertTrue(monday830.waitForExistence(timeout: timeout))
        NSLog("NOTICE_STAGE rosary-weekly-monday-0830 observed=%@ rawWeekday=2", monday830.label)
        stage("rosary-weekly-monday-0830")
        tapSystemBack(in: app, expecting: app.staticTexts.matching(NSPredicate(format: "label == %@", "Pray the Rosary")).firstMatch)

        openRosaryReminder(in: app)
        XCTAssertEqual(rosaryEnabled.value as? String, "1")
        XCTAssertTrue(app.buttons["rosary-reminder-frequency-weekly"].isSelected)
        XCTAssertTrue(app.buttons["rosary-reminder-weekday-2"].isSelected)
        openCompactPicker(compactPicker(in: app))
        assertTime(hour: 8, minute: 30, in: app)
        dismissCompactPicker(in: app)
        tapSystemBack(in: app, expecting: app.staticTexts.matching(NSPredicate(format: "label == %@", "Pray the Rosary")).firstMatch)

        openRosaryReminder(in: app)
        tap(app.buttons["rosary-reminder-frequency-daily"])
        setTime(hour: 8, minute: 35, in: app, compactPickerID: "rosary-reminder-time")
        tap(app.buttons["rosary-reminder-save"])
        let daily835 = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Saved · Every day at ")).firstMatch
        XCTAssertTrue(daily835.waitForExistence(timeout: timeout))
        NSLog("NOTICE_STAGE rosary-daily-0835 observed=%@", daily835.label)
        stage("rosary-daily-0835")
        tapSystemBack(in: app, expecting: app.staticTexts.matching(NSPredicate(format: "label == %@", "Pray the Rosary")).firstMatch)

        openRosaryReminder(in: app)
        XCTAssertEqual(rosaryEnabled.value as? String, "1")
        XCTAssertTrue(app.buttons["rosary-reminder-frequency-daily"].isSelected)
        openCompactPicker(compactPicker(in: app))
        assertTime(hour: 8, minute: 35, in: app)
        dismissCompactPicker(in: app)
        setSwitch(rosaryEnabled, on: false)
        tap(app.buttons["rosary-reminder-save"])
        XCTAssertTrue(app.staticTexts["Reminder turned off"].waitForExistence(timeout: timeout))
        stage("rosary-off")
        tapSystemBack(in: app, expecting: app.staticTexts.matching(NSPredicate(format: "label == %@", "Pray the Rosary")).firstMatch)

        openCalendarSettings(in: app)
        setSwitch(calendarEnabled, on: false)
        tap(app.buttons["calendar-notifications-save"])
        XCTAssertTrue(app.staticTexts["Calendar notifications are off."].waitForExistence(timeout: timeout))
        stage("calendar-off")
        NSLog("NOTICE_UI_ONLY journey=authorized seed=%@ bundle=%@; pending requests and committed storage are not asserted here",
              seedID, bundleID)
    }

    func testFreshUndeterminedCalendarPermissionDenialKeepsSettingOff() throws {
        let seedID = try requiredEnvironment("L22_NOTICE_DENY_SEED_ID")
        let app = try launch(configuration: "notDetermined-deny")
        let bundleID = activeBundleID ?? ""
        openCalendarSettings(in: app)
        let enabled = app.switches["calendar-notifications-enabled"]
        XCTAssertEqual(enabled.value as? String, "0", "Fresh denial seed must start disabled")
        setSwitch(enabled, on: true)
        tap(app.buttons["calendar-notifications-save"])

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 15), "Fresh notDetermined seed must show the actual system permission alert")
        NSLog("NOTICE_PERMISSION_ALERT label=%@", alert.label)
        let deny = alert.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Don’t Allow", "Don't Allow")).firstMatch
        XCTAssertTrue(deny.waitForExistence(timeout: 5), "The system alert must expose the real Don't Allow action")
        deny.tap()

        XCTAssertTrue(app.staticTexts[
            "Allow notifications in your device settings to receive calendar events."
        ].waitForExistence(timeout: timeout))
        NSLog("NOTICE_STAGE calendar-denied-visible-feedback")
        stage("calendar-denied-visible-feedback")
        tapSystemBack(in: app, expecting: app.staticTexts["settings-title"])
        openCalendarSettings(in: app)
        XCTAssertEqual(enabled.value as? String, "0", "Denied permission must leave committed Calendar notifications disabled")
        NSLog("NOTICE_UI_ONLY journey=notDetermined-deny seed=%@ bundle=%@; Main must verify zero durable and pending-request changes",
              seedID, bundleID)
    }

    #if DEBUG
    /// Host-driven remote-push notices test the real SpringBoard tap and notification delegate callback.
    /// They do not test local reminder scheduling. The host driver waits for each marker and sends one push.
    func testSimulatedNotificationResponsesRouteAcrossTabs() throws {
        let authorization = try requiredEnvironment("L22_NOTICE_INITIAL_AUTHORIZATION")
        XCTAssertEqual(authorization, "authorized", "Notification response test requires an authorized task-only app seed")
        guard authorization == "authorized" else { return }
        let app = try launch(configuration: "authorized")
        let dateKey = try requiredEnvironment("NOTICE_ROUTE_DATE")
        let runID = try requiredEnvironment("NOTICE_ROUTE_RUN_ID")
        let parsedDate = Self.routeDateFormatter.date(from: dateKey)
        XCTAssertNotNil(parsedDate, "NOTICE_ROUTE_DATE must use yyyy-MM-dd")
        guard let parsedDate else { return }
        XCTAssertEqual(Self.routeDateFormatter.string(from: parsedDate), dateKey,
                       "NOTICE_ROUTE_DATE must be a valid Gregorian date")

        let cases: [(key: String, start: String, tab: String, route: String)] = [
            ("daily-today", "today", "tab-today", "/daily?date=\(dateKey)"),
            ("daily-pray", "pray", "tab-pray", "/daily?date=\(dateKey)"),
            ("daily-read-pushed", "read-pushed", "tab-read", "/daily?date=\(dateKey)"),
            ("rosary-pray", "pray", "tab-pray", "/pray/rosary"),
            ("rosary-today", "today", "tab-today", "/pray/rosary"),
            ("rosary-read-pushed", "read-pushed", "tab-read", "/pray/rosary")
        ]

        for routeCase in cases {
            prepareNotificationStart(routeCase.start, tab: routeCase.tab, in: app)
            XCUIDevice.shared.press(.home)
            let noticeTitle = "NATIVE ROUTE TEST \(runID) \(routeCase.key)"
            NSLog("NOTICE_ROUTE_WAIT run=%@ case=%@ start=%@ route=%@ title=%@",
                  runID, routeCase.key, routeCase.start, routeCase.route, noticeTitle)
            tapInjectedNotice(title: noticeTitle)
            assertNotificationDestination(routeCase.route, date: parsedDate, in: app)

            Thread.sleep(forTimeInterval: 10)
            assertNotificationDestination(routeCase.route, date: parsedDate, in: app)
            attachNotificationDestinationEvidence(routeCase.key, app: app)
            NSLog("NOTICE_ROUTE_DONE run=%@ case=%@ start=%@ route=%@ stableSeconds=10",
                  runID, routeCase.key, routeCase.start, routeCase.route)
        }
    }
    #endif

    private func launch(configuration: String) throws -> XCUIApplication {
        let authorizedBundleID = try requiredEnvironment("L22_NOTICE_BUNDLE_ID")
        _ = try requiredEnvironment("L22_NOTICE_SEED_ID")
        let initialAuthorization = try requiredEnvironment("L22_NOTICE_INITIAL_AUTHORIZATION")
        let snapshotRelativePath = try requiredEnvironment("L22_NOTICE_SNAPSHOT_RELATIVE_PATH")
        let bundleID: String
        if configuration == "authorized" {
            XCTAssertTrue(["authorized", "notDetermined"].contains(initialAuthorization))
            bundleID = authorizedBundleID
        } else {
            let denialSeed = try requiredEnvironment("L22_NOTICE_DENY_SEED_ID")
            let authorizedSeed = try requiredEnvironment("L22_NOTICE_SEED_ID")
            XCTAssertNotEqual(denialSeed, authorizedSeed, "Use an independent fresh denial seed")
            bundleID = ProcessInfo.processInfo.environment["L22_NOTICE_DENY_BUNDLE_ID"] ?? authorizedBundleID
            XCTAssertEqual(initialAuthorization, "notDetermined", "Denial journey requires a fresh, notDetermined task seed")
        }
        let app = XCUIApplication(bundleIdentifier: bundleID)
        XCTAssertNotEqual(bundleID, "com.nrsv.verse", "Notice checks must use a task-only bundle, not the preserved production-ID fixture")
        activeApp = app
        activeBundleID = bundleID
        app.launchArguments += ["-L22NoticeSnapshotRelativePath", snapshotRelativePath]
        app.launch()
        XCTAssertTrue(tabButton(app, "tab-today").waitForExistence(timeout: timeout), "The task-only app must reach its root")
        let seedID = configuration == "authorized"
            ? try requiredEnvironment("L22_NOTICE_SEED_ID")
            : try requiredEnvironment("L22_NOTICE_DENY_SEED_ID")
        NSLog("NOTICE_LAUNCH journey=%@ bundle=%@ seed=%@ declaredAuthorization=%@ snapshotRelativePath=%@",
              configuration, bundleID, seedID, initialAuthorization, snapshotRelativePath)
        return app
    }

    private func openCalendarSettings(in app: XCUIApplication) {
        tap(tabButton(app, "tab-settings"))
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: timeout))
        tap(app.buttons["settings-calendar-notifications"])
        XCTAssertTrue(app.staticTexts["content-page-title"].waitForExistence(timeout: timeout))
        XCTAssertEqual(app.staticTexts["content-page-title"].label, "A day in the Church")
    }

    private func openRosaryReminder(in app: XCUIApplication) {
        let reminderRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Rosary reminder.")).firstMatch
        let rosaryHomeVisible = app.staticTexts.matching(NSPredicate(format: "label == %@", "Pray the Rosary")).firstMatch.exists
        if !reminderRow.exists || !rosaryHomeVisible {
            tap(tabButton(app, "tab-pray"))
            if !rosaryHomeVisible {
                tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Pray the Rosary")).firstMatch)
                XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", "Pray the Rosary")).firstMatch.waitForExistence(timeout: timeout))
            }
        }
        tap(reminderRow)
        XCTAssertTrue(app.staticTexts["Rosary reminder"].waitForExistence(timeout: timeout))
    }

    private func setSwitch(_ element: XCUIElement, on desired: Bool) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        let current = element.value as? String
        guard (current == "1") != desired else { return }
        element.tap()
        let predicate = NSPredicate(format: "value == %@", desired ? "1" : "0")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

    /// Set wheels by the observed PickerWheel value suffixes. The hour wheel has no label.
    private func setTime(hour: Int, minute: Int, in app: XCUIApplication, compactPickerID: String? = nil) {
        if let compactPickerID {
            let compactPicker = app.descendants(matching: .any)
                .matching(identifier: compactPickerID).firstMatch
            openCompactPicker(compactPicker)
            // The compact picker presents its wheels after an animation. Wait before scoping the wheels.
            XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 10),
                          "The compact picker popup must expose PickerWheels")
        }
        let wheels = timeWheels(in: app, preferredPickerID: compactPickerID ?? "calendar-notifications-time-picker")
        let hourWheel = wheels.hour
        let minuteWheel = wheels.minute
        XCTAssertTrue(hourWheel.waitForExistence(timeout: 8), "Expected a PickerWheel value ending in ‘o’clock’")
        XCTAssertTrue(minuteWheel.waitForExistence(timeout: 8), "Expected a PickerWheel value ending in ‘minutes’")

        let hourValues = hourWheel.value as? String ?? ""
        let minuteValues = minuteWheel.value as? String ?? ""
        let hourTarget = wheelTargetValue(number: hour % 12 == 0 ? 12 : hour % 12, current: hourValues)
        let minuteTarget = wheelTargetValue(number: minute, current: minuteValues)
        hourWheel.adjust(toPickerWheelValue: hourTarget)
        minuteWheel.adjust(toPickerWheelValue: minuteTarget)
        let meridiem = wheels.meridiem
        if meridiem.exists {
            let meridiemValue = (hour < 12) ? "AM" : "PM"
            meridiem.adjust(toPickerWheelValue: meridiemValue)
            XCTAssertEqual(meridiem.value as? String, meridiemValue)
        }

        let displayedHour = hour % 12 == 0 ? 12 : hour % 12
        XCTAssertTrue(waitWheel(hourWheel, equalsNumber: displayedHour, timeout: 5), "Hour wheel must read back the requested local hour")
        XCTAssertTrue(waitWheel(minuteWheel, equalsNumber: minute, timeout: 5), "Minute wheel must read back the requested local minute")
        NSLog("NOTICE_PICKER observedHourLabel=%@ hour=%@ observedMinuteLabel=%@ minute=%@ locale=%@",
              hourWheel.label, hourWheel.value as? String ?? "", minuteWheel.label,
              minuteWheel.value as? String ?? "", Locale.current.identifier)
        if meridiem.exists {
            NSLog("NOTICE_PICKER observedMeridiemLabel=%@ value=%@", meridiem.label, meridiem.value as? String ?? "")
        }
        if compactPickerID != nil { dismissCompactPicker(in: app) }
    }

    private func assertTime(hour: Int, minute: Int, in app: XCUIApplication) {
        let wheels = timeWheels(in: app, preferredPickerID: "calendar-notifications-time-picker")
        let hourWheel = wheels.hour
        let minuteWheel = wheels.minute
        XCTAssertTrue(hourWheel.waitForExistence(timeout: 8))
        XCTAssertTrue(waitWheel(hourWheel, equalsNumber: hour % 12 == 0 ? 12 : hour % 12, timeout: 3))
        XCTAssertTrue(waitWheel(minuteWheel, equalsNumber: minute, timeout: 3))
        let meridiem = wheels.meridiem
        if meridiem.exists {
            XCTAssertEqual(meridiem.value as? String, hour < 12 ? "AM" : "PM")
        }
    }

    /// The observed DatePicker frame is wider than its time pill. The pill sits at the trailing edge, and
    /// the element center misses it by a few points. Tap the trailing part of the frame.
    private func openCompactPicker(_ picker: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(picker.waitForExistence(timeout: timeout), "Missing compact picker", file: file, line: line)
        XCTAssertTrue(picker.isHittable, "Compact picker is not hittable", file: file, line: line)
        NSLog("NOTICE_PICKER compactFrame=%@ value=%@", NSCoder.string(for: picker.frame),
              String(describing: picker.value))
        picker.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)).tap()
    }

    private func compactPicker(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "rosary-reminder-time").firstMatch
    }

    private func dismissCompactPicker(in app: XCUIApplication) {
        let hourWheel = timeWheels(in: app, preferredPickerID: "rosary-reminder-time").hour
        guard hourWheel.exists else { return }
        let heading = app.staticTexts.matching(NSPredicate(format: "label == %@", "Rosary reminder")).firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 4), "Use the visible heading to dismiss the native picker popup")
        tap(heading)
        XCTAssertFalse(hourWheel.waitForExistence(timeout: 2), "Picker popup must close before the next save or route action")
        NSLog("NOTICE_PICKER popupDismissed=true method=visible-screen-heading")
    }

    private func allowCalendarPermission(in app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 15), "A declared notDetermined seed must show the system alert")
        NSLog("NOTICE_PERMISSION_ALERT label=%@", alert.label)
        let allow = alert.buttons.matching(NSPredicate(format: "label == %@", "Allow")).firstMatch
        XCTAssertTrue(allow.waitForExistence(timeout: 5), "The actual notification alert must expose Allow")
        allow.tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: alert)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 10), .completed, "The system permission alert must close after Allow")
    }

    private func timeWheels(in app: XCUIApplication, preferredPickerID: String) -> TimeWheels {
        let preferred = app.datePickers.matching(identifier: preferredPickerID).firstMatch
        let visiblePickers = app.datePickers.allElementsBoundByIndex
            .filter {
                $0.exists && $0.frame.intersects(app.frame) &&
                    $0.descendants(matching: .pickerWheel).count > 0
            }
        let picker: XCUIElement
        if preferred.exists && preferred.frame.intersects(app.frame) &&
            preferred.descendants(matching: .pickerWheel).count > 0 {
            picker = preferred
        } else if let visiblePicker = visiblePickers.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }) {
            picker = visiblePicker
        } else if app.pickerWheels.count > 0 {
            // A compact picker popup can place its wheels outside the DatePicker element. Record the tree.
            NSLog("NOTICE_PICKER_POPUP_OUTSIDE_DATEPICKER appWheels=%d values=%@ tree=%@", app.pickerWheels.count,
                  app.pickerWheels.allElementsBoundByIndex.map { String(describing: $0.value) }.joined(separator: "|"),
                  app.debugDescription)
            picker = app
        } else {
            XCTFail("No visible native DatePicker was found for the requested time")
            NSLog("NOTICE_PICKER_NOT_FOUND tree=%@", app.debugDescription)
            picker = app
        }
        let wheels = picker.descendants(matching: .pickerWheel)
        let hour = wheels.matching(NSPredicate(format: "value ENDSWITH[c] %@", "o’clock"))
        let minute = wheels.matching(NSPredicate(format: "value ENDSWITH[c] %@", "minutes"))
        let meridiem = wheels.matching(NSPredicate(format: "value == %@ OR value == %@", "AM", "PM"))
        NSLog("NOTICE_PICKER_HIERARCHY pickerID=%@ wheelCount=%d values=%@ locale=%@",
              picker.identifier, wheels.count,
              wheels.allElementsBoundByIndex.map { String(describing: $0.value) }.joined(separator: "|"),
              Locale.current.identifier)
        XCTAssertEqual(hour.count, 1, "The visible picker must expose one hour wheel with the observed suffix")
        XCTAssertEqual(minute.count, 1, "The visible picker must expose one minute wheel with the observed suffix")
        if hour.count == 1 && minute.count == 1 {
            XCTAssertEqual(meridiem.count, 1, "The observed picker uses an AM/PM wheel")
        }
        return TimeWheels(hour: hour.firstMatch, minute: minute.firstMatch, meridiem: meridiem.firstMatch)
    }

    private func wheelTargetValue(number: Int, current: String) -> String {
        guard let range = current.range(of: "[0-9]+", options: .regularExpression) else {
            XCTFail("Picker wheel value has no numeric field: \(current)")
            return current
        }
        let width = current[range].count
        let target = String(format: "%0*d", width, number)
        // The accessibility value reads "8 o’clock", but adjust only accepts the wheel data values ("8", "09").
        return target
    }

    private func waitWheel(_ wheel: XCUIElement, equalsNumber expected: Int, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let value = (object as? XCUIElement)?.value as? String else { return false }
            let digits = value.filter(\.isNumber)
            return Int(digits) == expected
        }, object: wheel)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private struct TimeWheels {
        let hour: XCUIElement
        let minute: XCUIElement
        let meridiem: XCUIElement
    }

    /// The iOS 26 system glass back button of a pushed screen. It replaced `content-back` and `rosary-reminder-back`.
    private func systemBack(in app: XCUIApplication) -> XCUIElement {
        // `navigationBars.buttons.firstMatch` can return a trailing button or the button of another bar. Prefer the
        // `BackButton` identifier (the front-most one when two bars are on screen during a push). Otherwise use the
        // left-most hittable button of the front-most navigation bar.
        let named = app.navigationBars.buttons.matching(identifier: "BackButton")
        if named.count > 0 { return named.element(boundBy: named.count - 1) }
        let bars = app.navigationBars.allElementsBoundByIndex.filter { $0.exists }
        if let bar = bars.last(where: { $0.isHittable }) ?? bars.last {
            let buttons = bar.buttons.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
            if let leftmost = buttons.min(by: { $0.frame.minX < $1.frame.minX }) { return leftmost }
        }
        return app.navigationBars.buttons.firstMatch
    }

    /// Taps Back and waits for the expected parent screen.
    private func tapSystemBack(in app: XCUIApplication, expecting parent: XCUIElement,
                               file: StaticString = #filePath, line: UInt = #line) {
        let back = systemBack(in: app)
        XCTAssertTrue(back.waitForExistence(timeout: 10), "Back control did not appear", file: file, line: line)
        back.tap()
        XCTAssertTrue(parent.waitForExistence(timeout: 10), "The parent screen must appear after Back", file: file, line: line)
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard let app = activeApp else {
            XCTFail("Launch the explicit task-only app before tapping controls", file: file, line: line)
            return
        }
        for _ in 0..<8 {
            if element.exists && element.isHittable {
                element.tap()
                return
            }
            let viewport = visibleScrollViewport(in: app)
            guard viewport.height > 100 else { break }
            let frame = element.exists ? element.frame : .zero
            let movingUp = !element.exists || frame.midY >= viewport.midY
            // Drag in the left gutter. A centered drag lands on the inline Calendar spinner and changes the time.
            let x = viewport.minX + 14
            let startY = viewport.minY + viewport.height * (movingUp ? 0.75 : 0.25)
            let endY = viewport.minY + viewport.height * (movingUp ? 0.25 : 0.75)
            app.coordinate(withNormalizedOffset: CGVector(dx: x / app.frame.width, dy: startY / app.frame.height))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(
                    withNormalizedOffset: CGVector(dx: x / app.frame.width, dy: endY / app.frame.height)
                ))
        }
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing control: \(element)", file: file, line: line)
        XCTAssertTrue(element.isHittable, "Control is not hittable: \(element)", file: file, line: line)
        element.tap()
    }

    private func visibleScrollViewport(in app: XCUIApplication) -> CGRect {
        let scroll = app.scrollViews.allElementsBoundByIndex
            .filter { $0.exists && $0.isHittable }
            .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
        var viewport = (scroll?.frame ?? app.frame).intersection(app.frame)
        if app.statusBars.firstMatch.exists {
            let top = app.statusBars.firstMatch.frame.maxY
            viewport = CGRect(x: viewport.minX, y: max(viewport.minY, top), width: viewport.width,
                              height: max(0, viewport.maxY - max(viewport.minY, top)))
        }
        let navBottom = app.navigationBars.allElementsBoundByIndex
            .filter { $0.exists && $0.frame.intersects(viewport) }
            .map(\.frame.maxY).max()
        if let navBottom {
            let top = max(viewport.minY, navBottom)
            viewport = CGRect(x: viewport.minX, y: top, width: viewport.width,
                              height: max(0, viewport.maxY - top))
        }
        if app.keyboards.firstMatch.exists {
            viewport.size.height = min(viewport.height, app.keyboards.firstMatch.frame.minY - viewport.minY)
        }
        let tabTop = tabBarTopEdge(in: app, within: viewport)
        if let tabTop { viewport.size.height = min(viewport.height, tabTop - viewport.minY) }
        return viewport
    }

    private func stage(_ name: String) {
        NSLog("NOTICE_STAGE_READY %@; Main may capture same-process requests and state now", name)
        Thread.sleep(forTimeInterval: 8)
    }

    private func requiredEnvironment(_ key: String) throws -> String {
        guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else {
            XCTFail("Main must provide explicit task-only environment value \(key)")
            throw NSError(domain: "PositiveNoticeUITests.Preflight", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing required environment value: \(key)"])
        }
        return value
    }

    #if DEBUG
    private static let routeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func prepareNotificationStart(_ start: String, tab: String, in app: XCUIApplication) {
        let tabControl = tabButton(app, tab)
        XCTAssertTrue(tabControl.waitForExistence(timeout: timeout), "Missing start tab \(tab)")
        tabControl.tap()
        tabControl.tap() // A second tap returns a retained stack to its root.

        switch start {
        case "today":
            XCTAssertTrue(app.staticTexts["today-title"].waitForExistence(timeout: timeout),
                          "Today must be the route start root")
        case "pray":
            XCTAssertTrue(app.textFields["Search novenas"].waitForExistence(timeout: timeout),
                          "Pray must be the route start root")
        case "read-pushed":
            let bookListTitle = app.staticTexts["reader-book-list-title"]
            for _ in 0..<5 where !bookListTitle.exists {
                let back = app.buttons["reader-back"]
                XCTAssertTrue(back.waitForExistence(timeout: 5),
                              "Reader must expose its visible Back action before opening the Works page")
                XCTAssertTrue(back.isHittable, "Reader Back must be visible before returning to the book list")
                back.tap()
            }
            XCTAssertTrue(bookListTitle.waitForExistence(timeout: timeout),
                          "Read must return to its book list before the Works page is pushed")
            let worksLink = app.buttons["reader-works-link"]
            XCTAssertTrue(worksLink.waitForExistence(timeout: timeout), "Read must show its Works link")
            tap(worksLink)
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "The Fathers"))
                .firstMatch.waitForExistence(timeout: timeout), "Read must have a pushed Works page")
        default:
            XCTFail("Unknown notification start: \(start)")
        }
        NSLog("NOTICE_ROUTE_START_READY start=%@ selectedTab=%@", start, tab)
    }

    private func tapInjectedNotice(title: String) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let notice = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        var found = notice.waitForExistence(timeout: 20)
        if !found {
            let start = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02))
            let end = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
            start.press(forDuration: 0.1, thenDragTo: end)
            found = notice.waitForExistence(timeout: 10)
        }
        guard found else {
            attachSpringBoardEvidence(title, phase: "missing", app: springboard)
            NSLog("NOTICE_ROUTE_MISSING title=%@ springboardTree=%@", title, springboard.debugDescription)
            XCTFail("SpringBoard did not show the injected notification \(title); no callback is claimed")
            return
        }
        guard notice.isHittable else {
            attachSpringBoardEvidence(title, phase: "not-hittable", app: springboard)
            XCTFail("Injected SpringBoard notification must be hittable: \(title)")
            return
        }
        NSLog("NOTICE_ROUTE_TAP title=%@ role=%@ frame=%@",
              title, String(describing: notice.elementType), NSCoder.string(for: notice.frame))
        attachSpringBoardEvidence(title, phase: "before-tap", app: springboard)
        notice.tap()
    }

    private func attachSpringBoardEvidence(_ title: String, phase: String, app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "notification-\(title)-springboard-\(phase)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "notification-\(title)-springboard-\(phase)-ax"
        tree.lifetime = .keepAlways
        add(tree)
    }

    private func assertNotificationDestination(_ route: String, date: Date, in app: XCUIApplication) {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 12), "The notification tap must foreground John")
        let expectedTab: String
        if route == "/pray/rosary" {
            expectedTab = "tab-pray"
            XCTAssertTrue(app.staticTexts["Pray the Rosary"].waitForExistence(timeout: timeout),
                          "Rosary notice must open the Rosary home")
        } else {
            expectedTab = "tab-today"
            let pageTitle = app.staticTexts["content-page-title"]
            XCTAssertTrue(pageTitle.waitForExistence(timeout: timeout), "Daily notice must open its readings page")
            XCTAssertEqual(pageTitle.label, "Today’s readings")
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.calendar = Calendar(identifier: .gregorian)
            dateFormatter.timeZone = .autoupdatingCurrent
            dateFormatter.dateFormat = "MMM d, yyyy"
            let expectedDate = dateFormatter.string(from: date)
            XCTAssertTrue(app.staticTexts[expectedDate].waitForExistence(timeout: timeout),
                          "Daily notice must open the requested date \(expectedDate)")
        }
        let selectedTab = tabButton(app, expectedTab)
        XCTAssertTrue(selectedTab.exists, "Destination tab must exist: \(expectedTab)")
        XCTAssertTrue(selectedTab.isSelected, "Notification route must select \(expectedTab)")
        XCTAssertTrue(app.navigationBars.buttons["BackButton"].exists,
                      "The notification destination must be a pushed page")
    }

    private func attachNotificationDestinationEvidence(_ key: String, app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "notification-route-\(key)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "notification-route-\(key)-ax"
        tree.lifetime = .keepAlways
        add(tree)
    }
    #endif

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
