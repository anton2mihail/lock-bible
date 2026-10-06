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
        tap(app.buttons["content-back"])

        openCalendarSettings(in: app)
        XCTAssertTrue(calendarEnabled.exists)
        XCTAssertTrue(calendarEnabled.value as? String == "1", "Calendar must remain enabled after re-entry")
        tap(app.buttons["calendar-notifications-delivery-time"])
        assertTime(hour: 9, minute: 15, in: app)
        tap(app.buttons["content-back"])

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
        tap(app.buttons["rosary-reminder-back"])

        openRosaryReminder(in: app)
        XCTAssertEqual(rosaryEnabled.value as? String, "1")
        XCTAssertTrue(app.buttons["rosary-reminder-frequency-weekly"].isSelected)
        XCTAssertTrue(app.buttons["rosary-reminder-weekday-2"].isSelected)
        tap(compactPicker(in: app))
        assertTime(hour: 8, minute: 30, in: app)
        dismissCompactPicker(in: app)
        tap(app.buttons["rosary-reminder-back"])

        openRosaryReminder(in: app)
        tap(app.buttons["rosary-reminder-frequency-daily"])
        setTime(hour: 8, minute: 35, in: app, compactPickerID: "rosary-reminder-time")
        tap(app.buttons["rosary-reminder-save"])
        let daily835 = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Saved · Every day at ")).firstMatch
        XCTAssertTrue(daily835.waitForExistence(timeout: timeout))
        NSLog("NOTICE_STAGE rosary-daily-0835 observed=%@", daily835.label)
        stage("rosary-daily-0835")
        tap(app.buttons["rosary-reminder-back"])

        openRosaryReminder(in: app)
        XCTAssertEqual(rosaryEnabled.value as? String, "1")
        XCTAssertTrue(app.buttons["rosary-reminder-frequency-daily"].isSelected)
        tap(compactPicker(in: app))
        assertTime(hour: 8, minute: 35, in: app)
        dismissCompactPicker(in: app)
        setSwitch(rosaryEnabled, on: false)
        tap(app.buttons["rosary-reminder-save"])
        XCTAssertTrue(app.staticTexts["Reminder turned off"].waitForExistence(timeout: timeout))
        stage("rosary-off")
        tap(app.buttons["rosary-reminder-back"])

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
        tap(app.buttons["content-back"])
        openCalendarSettings(in: app)
        XCTAssertEqual(enabled.value as? String, "0", "Denied permission must leave committed Calendar notifications disabled")
        NSLog("NOTICE_UI_ONLY journey=notDetermined-deny seed=%@ bundle=%@; Main must verify zero durable and pending-request changes",
              seedID, bundleID)
    }

    private func launch(configuration: String) throws -> XCUIApplication {
        let authorizedBundleID = try requiredEnvironment("L22_NOTICE_BUNDLE_ID")
        _ = try requiredEnvironment("L22_NOTICE_SEED_ID")
        let initialAuthorization = try requiredEnvironment("L22_NOTICE_INITIAL_AUTHORIZATION")
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
        app.launch()
        XCTAssertTrue(app.buttons["tab-today"].waitForExistence(timeout: timeout), "The task-only app must reach its root")
        let seedID = configuration == "authorized"
            ? try requiredEnvironment("L22_NOTICE_SEED_ID")
            : try requiredEnvironment("L22_NOTICE_DENY_SEED_ID")
        NSLog("NOTICE_LAUNCH journey=%@ bundle=%@ seed=%@ declaredAuthorization=%@",
              configuration, bundleID, seedID, initialAuthorization)
        return app
    }

    private func openCalendarSettings(in app: XCUIApplication) {
        tap(app.buttons["tab-settings"])
        XCTAssertTrue(app.staticTexts["settings-title"].waitForExistence(timeout: timeout))
        tap(app.buttons["settings-calendar-notifications"])
        XCTAssertTrue(app.staticTexts["content-page-title"].waitForExistence(timeout: timeout))
        XCTAssertEqual(app.staticTexts["content-page-title"].label, "A day in the Church")
    }

    private func openRosaryReminder(in app: XCUIApplication) {
        let reminderRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Rosary reminder.")).firstMatch
        let rosaryHomeVisible = app.staticTexts.matching(NSPredicate(format: "label == %@", "Pray the Rosary")).firstMatch.exists
        if !reminderRow.exists || !rosaryHomeVisible {
            tap(app.buttons["tab-pray"])
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
            tap(compactPicker)
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
        XCTAssertFalse(alert.waitForExistence(timeout: 2), "The system permission alert must close after Allow")
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
        } else {
            XCTFail("No visible native DatePicker was found for the requested time")
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
        return current.replacingCharacters(in: range, with: target)
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
            let x = viewport.midX
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
        let tabTop = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tab-"))
            .allElementsBoundByIndex.filter { $0.exists && $0.frame.intersects(viewport) }
            .map(\.frame.minY).min()
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
}
