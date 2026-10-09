import Foundation
import UIKit
import XCTest

/// Sets or verifies a system accessibility setting through the Settings app.
///
/// Run the `set` and `verify` phases in separate `xcodebuild test-without-building`
/// invocations. The verify phase checks UIAccessibility before it opens Settings.
/// Required environment:
/// - JOHN_SYSTEM_ACCESSIBILITY_SETTING=reduceMotion|reduceTransparency
/// - JOHN_SYSTEM_ACCESSIBILITY_VALUE=on|off
/// - JOHN_SYSTEM_ACCESSIBILITY_PHASE=set|verify
/// - JOHN_SYSTEM_ACCESSIBILITY_SET_PROCESS_ID=<PID from the set attachment> (verify only)
@MainActor
final class SystemAccessibilityUITests: XCTestCase {
    private enum Setting: String {
        case reduceMotion
        case reduceTransparency

        var label: String {
            switch self {
            case .reduceMotion: "Reduce Motion"
            case .reduceTransparency: "Reduce Transparency"
            }
        }

        var path: [String] {
            switch self {
            case .reduceMotion: ["Accessibility", "Motion"]
            case .reduceTransparency: ["Accessibility", "Display & Text Size"]
            }
        }

        var readback: Bool {
            switch self {
            case .reduceMotion: UIAccessibility.isReduceMotionEnabled
            case .reduceTransparency: UIAccessibility.isReduceTransparencyEnabled
            }
        }
    }

    private enum Phase: String {
        case set
        case verify
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRequestedAccessibilitySwitchState() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let settingValue = environment["JOHN_SYSTEM_ACCESSIBILITY_SETTING"],
              let setting = Setting(rawValue: settingValue),
              let stateValue = environment["JOHN_SYSTEM_ACCESSIBILITY_VALUE"],
              ["on", "off"].contains(stateValue),
              let phaseValue = environment["JOHN_SYSTEM_ACCESSIBILITY_PHASE"],
              let phase = Phase(rawValue: phaseValue) else {
            XCTFail("Set JOHN_SYSTEM_ACCESSIBILITY_SETTING, JOHN_SYSTEM_ACCESSIBILITY_VALUE, and JOHN_SYSTEM_ACCESSIBILITY_PHASE.")
            return
        }

        let expected = stateValue == "on"
        let processID = ProcessInfo.processInfo.processIdentifier
        let previousProcessID = environment["JOHN_SYSTEM_ACCESSIBILITY_SET_PROCESS_ID"].flatMap { Int32($0) }
        let readbackBeforeSettings = setting.readback
        let readbackBeforeSettingsConfirmed = phase == .verify
            ? waitForReadback(setting, expected: expected)
            : false

        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        if settings.state == .runningForeground || settings.state == .runningBackground {
            settings.terminate()
        }
        settings.launch()
        let toggle: XCUIElement
        let switchState: Bool
        let switchReachedRequestedValue: Bool
        let readbackAfterSettingsConfirmed: Bool
        do {
            try returnToSettingsRoot(settings)
            for label in setting.path {
                try tapExactLabel(label, in: settings)
            }

            toggle = try findExactSwitch(setting.label, in: settings)
            let stateBeforeChange = try exactSwitchValue(toggle, label: setting.label)
            if phase == .set && stateBeforeChange != expected {
                try tapExactSwitch(toggle, label: setting.label, in: settings)
            }

            let switchResult = try waitForSwitchValue(toggle, label: setting.label, expected: expected)
            switchState = switchResult.value
            switchReachedRequestedValue = switchResult.reachedExpectedValue
            readbackAfterSettingsConfirmed = waitForReadback(setting, expected: expected)
        } catch {
            attachEvidence([
                "setting": setting.rawValue,
                "settingsPath": (["Settings"] + setting.path).joined(separator: " > "),
                "switchLabel": setting.label,
                "requestedValue": stateValue,
                "phase": phase.rawValue,
                "testProcessID": processID,
                "previousSetProcessID": previousProcessID.map { $0 as Any } ?? NSNull(),
                "failure": String(describing: error),
                "uiAccessibilityBeforeSettings": readbackBeforeSettings,
            ], settings: settings)
            XCTFail("System accessibility setup failed: \(error)")
            return
        }

        let readbackAfterSettings = setting.readback
        let evidence = [
            "setting": setting.rawValue,
            "settingsPath": (["Settings"] + setting.path).joined(separator: " > "),
            "switchLabel": setting.label,
            "requestedValue": stateValue,
            "phase": phase.rawValue,
            "switchValue": switchState ? "on" : "off",
            "switchReachedRequestedValue": switchReachedRequestedValue,
            "uiAccessibilityBeforeSettings": readbackBeforeSettings,
            "uiAccessibilityBeforeSettingsConfirmed": readbackBeforeSettingsConfirmed,
            "uiAccessibilityAfterSettings": readbackAfterSettings,
            "uiAccessibilityAfterSettingsConfirmed": readbackAfterSettingsConfirmed,
            "testProcessID": processID,
            "previousSetProcessID": previousProcessID.map { $0 as Any } ?? NSNull(),
        ] as [String: Any]

        attachEvidence(evidence, settings: settings)

        if phase == .verify {
            XCTAssertNotNil(previousProcessID,
                            "The verify phase needs the process ID from the separate set invocation.")
            if let previousProcessID {
                XCTAssertNotEqual(processID, previousProcessID,
                                  "The verify phase must run in a fresh test process.")
            }
            XCTAssertTrue(readbackBeforeSettingsConfirmed,
                          "UIAccessibility must report the requested value in the fresh process before Settings opens.")
        }
        XCTAssertTrue(switchReachedRequestedValue,
                      "The exact Settings switch must change to the requested state.")
        XCTAssertEqual(switchState, expected,
                       "The exact Settings switch must show the requested state.")
        XCTAssertTrue(readbackAfterSettingsConfirmed,
                      "UIAccessibility must report the requested system setting within 8 seconds.")
        XCTAssertEqual(readbackAfterSettings, expected,
                       "UIAccessibility must report the requested system setting.")
    }

    private func returnToSettingsRoot(_ app: XCUIApplication) throws {
        for _ in 0..<8 {
            if app.navigationBars.staticTexts["Settings"].exists {
                return
            }
            let back = app.navigationBars.buttons.firstMatch
            guard back.waitForExistence(timeout: 1), back.isHittable else {
                break
            }
            back.tap()
        }

        guard app.navigationBars.staticTexts["Settings"].waitForExistence(timeout: 5) else {
            throw SetupError.settingsRootNotFound
        }
    }

    private func tapExactLabel(_ label: String, in app: XCUIApplication) throws {
        let predicate = NSPredicate(format: "label == %@", label)
        for _ in 0..<6 {
            let matches = app.descendants(matching: .any).matching(predicate).allElementsBoundByIndex
            if let target = matches.first(where: { $0.exists && $0.isHittable }) {
                target.tap()
                return
            }
            app.swipeUp()
        }

        throw SetupError.settingsPathItemNotFound(label)
    }

    private func findExactSwitch(_ label: String, in app: XCUIApplication) throws -> XCUIElement {
        let query = app.switches.matching(NSPredicate(format: "label == %@", label))
        for _ in 0..<6 {
            if query.count == 1, query.firstMatch.isHittable {
                return query.firstMatch
            }
            if query.count > 1 {
                break
            }
            app.swipeUp()
        }

        throw SetupError.exactSwitchNotFound(label)
    }

    private func tapExactSwitch(_ toggle: XCUIElement, label: String, in app: XCUIApplication) throws {
        let frame = toggle.frame
        let appFrame = app.frame
        let point = frame.width > 100
            ? CGPoint(x: frame.maxX - 28, y: frame.midY)
            : CGPoint(x: frame.midX, y: frame.midY)
        guard frame.width > 0, frame.height > 0,
              appFrame.width > 0, appFrame.height > 0,
              frame.contains(point), appFrame.contains(point) else {
            throw SetupError.switchTapPointUnsafe(label)
        }
        NSLog("SYSTEM_ACCESSIBILITY_SWITCH_TAP label=%@ frame=%@ point=%@",
              label, NSCoder.string(for: frame), NSCoder.string(for: point))
        let normalized = CGVector(dx: (point.x - appFrame.minX) / appFrame.width,
                                  dy: (point.y - appFrame.minY) / appFrame.height)
        app.coordinate(withNormalizedOffset: normalized).tap()
    }

    private func exactSwitchValue(_ toggle: XCUIElement, label: String) throws -> Bool {
        guard let value = booleanValue(toggle.value) else {
            XCTFail("The \(label) switch must expose an exact on/off value. Found: \(String(describing: toggle.value))")
            throw SetupError.switchValueNotReadable(label)
        }
        return value
    }

    private func waitForSwitchValue(
        _ toggle: XCUIElement,
        label: String,
        expected: Bool
    ) throws -> (value: Bool, reachedExpectedValue: Bool) {
        let expectedString = expected ? "1" : "0"
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expectedString),
            object: toggle
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: 8)
        return (try exactSwitchValue(toggle, label: label), result == .completed)
    }

    private func waitForReadback(_ setting: Setting, expected: Bool) -> Bool {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if setting.readback == expected {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return setting.readback == expected
    }

    private func booleanValue(_ value: Any?) -> Bool? {
        if let string = value as? String {
            switch string.lowercased() {
            case "1", "on", "enabled": true
            case "0", "off", "disabled": false
            default: nil
            }
        } else if let number = value as? NSNumber {
            number.boolValue
        } else {
            nil
        }
    }

    private func attachEvidence(_ evidence: [String: Any], settings: XCUIApplication) {
        XCTContext.runActivity(named: "System accessibility setting proof") { activity in
            let json = (try? JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])) ?? Data()
            let facts = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
            facts.name = "system-accessibility-proof.json"
            facts.lifetime = .keepAlways
            activity.add(facts)

            let screenshot = XCTAttachment(screenshot: settings.screenshot())
            screenshot.name = "settings-accessibility-switch.png"
            screenshot.lifetime = .keepAlways
            activity.add(screenshot)

            let tree = XCTAttachment(string: settings.debugDescription)
            tree.name = "settings-accessibility-switch-ax.txt"
            tree.lifetime = .keepAlways
            activity.add(tree)
        }
    }

    private enum SetupError: Error {
        case settingsRootNotFound
        case settingsPathItemNotFound(String)
        case exactSwitchNotFound(String)
        case switchValueNotReadable(String)
        case switchTapPointUnsafe(String)
    }
}
