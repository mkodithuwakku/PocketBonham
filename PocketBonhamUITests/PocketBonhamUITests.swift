import XCTest

final class PocketBonhamUITests: XCTestCase {
  @MainActor func testChassisStaysAtScreenTopWhileScrollingAndChangingTabs() throws {
    let app = XCUIApplication()
    app.launchEnvironment["PB_TEST_SESSION"] = UUID().uuidString
    app.launch()
    let cap = app.descendants(matching: .any)["instrumentTopCap"].firstMatch
    XCTAssertTrue(cap.waitForExistence(timeout: 10))
    let topFrame = cap.frame
    XCTAssertEqual(topFrame.minY, app.frame.minY, accuracy: 1,
      "The casing must extend through the top safe area")
    XCTAssertGreaterThanOrEqual(app.staticTexts["PocketBonham"].frame.minY, topFrame.maxY,
      "The wordmark must be fully below the casing")
    XCTAssertGreaterThanOrEqual(app.buttons["savePattern"].frame.minY, topFrame.maxY,
      "The casing cannot cover the editor header")
    XCTAssertGreaterThan(topFrame.height, 60, "The end cap must enclose the camera area")
    XCTAssertLessThan(topFrame.height, 110, "Controls must remain below a compact end cap")
    let initial = XCTAttachment(screenshot: app.screenshot())
    initial.name = "Fixed enclosure — screen top"
    initial.lifetime = .keepAlways
    add(initial)
    app.scrollViews.firstMatch.swipeUp()
    XCTAssertEqual(cap.frame, topFrame, "The physical top cannot move with the editor")
    let scrolled = XCTAttachment(screenshot: app.screenshot())
    scrolled.name = "Fixed enclosure — editor scrolled"
    scrolled.lifetime = .keepAlways
    add(scrolled)
    for tab in ["Library", "Chains", "Pattern"] {
      app.tabBars.buttons[tab].tap()
      XCTAssertEqual(cap.frame, topFrame, "The enclosure must stay fixed in \(tab)")
    }
  }

  @MainActor func testInstrumentDropdownPreservesIndependentSteps() throws {
    let app = XCUIApplication()
    app.launchEnvironment["PB_TEST_SESSION"] = UUID().uuidString
    app.launch()
    let selector = app.buttons["instrumentSelector"]
    XCTAssertTrue(selector.waitForExistence(timeout: 10))
    app.buttons["step-1"].tap()
    selector.tap()
    for role in ["kick", "snare", "closedHat", "closedHat2", "openHat", "tomExtra1", "tomExtra2", "tomExtra3", "ride"] {
      XCTAssertTrue(app.buttons["instrument-option-\(role)"].exists, "Menu must contain \(role)")
    }
    let menu = XCTAttachment(screenshot: app.screenshot())
    menu.name = "Instrument dropdown — complete kit"
    menu.lifetime = .keepAlways
    add(menu)
    app.buttons["instrument-option-ride"].tap()
    XCTAssertEqual(selector.value as? String, "Ride")
    XCTAssertTrue(app.buttons["step-1"].label.contains("disabled"))
    app.buttons["step-1"].tap()
    selector.tap()
    app.buttons["instrument-option-kick"].tap()
    XCTAssertTrue(app.buttons["step-1"].label.contains("kick, step 1, enabled"))
    selector.tap()
    app.buttons["instrument-option-ride"].tap()
    XCTAssertTrue(app.buttons["step-1"].label.contains("ride, step 1, enabled"))
    app.buttons["Play Pads"].tap()
    XCTAssertTrue(app.buttons["pad-0"].label.contains("Ride"))
    selector.tap()
    app.buttons["instrument-option-closedHat2"].tap()
    XCTAssertEqual(selector.value as? String, "Closed Hat 2")
    XCTAssertTrue(app.buttons["pad-3"].label.contains("Closed Hat 2"))
  }
  @MainActor func testHoldSlideVelocityIsPerNoteUndoableAndSaved() throws {
    let app = XCUIApplication()
    app.launchEnvironment["PB_TEST_SESSION"] = UUID().uuidString
    app.launch()
    XCTAssertTrue(app.buttons["step-5"].waitForExistence(timeout: 10))
    app.buttons["step-5"].tap() // Kick and snare share step five.
    app.buttons["instrumentSelector"].tap()
    app.buttons["instrument-option-snare"].tap()
    let pad = app.buttons["step-5"]
    pad.tap()
    let center = pad.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    center.press(forDuration: 0.5, thenDragTo: center.withOffset(CGVector(dx: 0, dy: 65)),
      withVelocity: .slow, thenHoldForDuration: 0.3)
    XCTAssertTrue(pad.label.contains("snare, step 5, enabled"))
    XCTAssertFalse(pad.label.contains("level 100,"))
    XCTAssertFalse(app.navigationBars["Step Details"].exists)
    XCTAssertFalse(app.otherElements["velocityFader"].exists, "Release dismisses the fader")
    app.buttons["undo"].tap()
    XCTAssertTrue(pad.label.contains("level 100,"), "One Undo restores the entire drag")
    center.press(forDuration: 0.5, thenDragTo: center.withOffset(CGVector(dx: 0, dy: -170)),
      withVelocity: .slow, thenHoldForDuration: 0.3)
    XCTAssertTrue(pad.label.contains("level 127,"), "Upward drag clamps to maximum")
    center.press(forDuration: 0.5, thenDragTo: center.withOffset(CGVector(dx: 0, dy: 175)),
      withVelocity: .slow, thenHoldForDuration: 0.3)
    XCTAssertTrue(pad.label.contains("level 1,"), "Downward drag clamps without disabling the note")
    XCTAssertTrue(app.buttons["step-6"].label.contains("disabled, level 100,"))
    app.buttons["instrumentSelector"].tap()
    app.buttons["instrument-option-kick"].tap()
    XCTAssertTrue(pad.label.contains("kick, step 5, enabled, level 100,"))
    app.buttons["savePattern"].tap()
    app.alerts.textFields.firstMatch.clearAndEnter("Velocity Groove")
    app.alerts.buttons["Save"].tap()
    app.terminate()
    app.launch()
    XCTAssertTrue(app.buttons["instrumentSelector"].waitForExistence(timeout: 10))
    app.tabBars.buttons["Library"].tap()
    app.buttons.containing(.staticText, identifier: "Velocity Groove").firstMatch.tap()
    app.buttons["instrumentSelector"].tap()
    app.buttons["instrument-option-snare"].tap()
    XCTAssertTrue(pad.label.contains("snare, step 5, enabled, level 1,"))
    pad.tap()
    XCTAssertTrue(pad.label.contains("disabled"), "A normal tap still toggles")
  }
  @MainActor func testOwnerKitNinePads() throws {
    let app = XCUIApplication()
    app.launchEnvironment["PB_TEST_SESSION"] = UUID().uuidString
    app.launch()
    XCTAssertTrue(app.buttons["Drum Kit 1"].waitForExistence(timeout: 10))
    app.buttons["Play Pads"].tap()
    XCTAssertTrue(app.buttons["pad-0"].waitForExistence(timeout: 5))
    XCTAssertLessThanOrEqual(app.buttons["pad-7"].frame.maxY,
      app.buttons["transportPlay"].frame.minY, "All eight pads should fit above the transport")
    for i in 0..<8 {
      XCTAssertTrue(app.buttons["pad-\(i)"].exists)
      app.buttons["pad-\(i)"].tap()
    }
    app.buttons["Next pad page"].tap()
    XCTAssertTrue(app.buttons["pad-0"].label.contains("Ride"))
    app.buttons["pad-0"].tap()
    XCTAssertFalse(app.buttons["pad-1"].exists)
    app.buttons["Previous pad page"].tap()
    XCTAssertTrue(app.buttons["pad-2"].label.contains("Closed Hat 1"))
    XCTAssertTrue(app.buttons["pad-3"].label.contains("Closed Hat 2"))
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Drum Kit 1 — both closed hats and numbered toms"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  @MainActor func testPatternSaveChainAndRelaunch() throws {
    let app = XCUIApplication()
    app.launchEnvironment["PB_TEST_SESSION"] = UUID().uuidString
    app.launch()
    if app.buttons["Later"].waitForExistence(timeout: 2) { app.buttons["Later"].tap() }
    XCTAssertTrue(app.buttons["step-1"].waitForExistence(timeout: 10))
    app.buttons["step-1"].tap()
    app.buttons["step-5"].tap()
    app.buttons["savePattern"].tap()
    let name = "UI Groove \(Int(Date().timeIntervalSince1970))"
    let field = app.alerts.textFields.firstMatch
    field.tap()
    field.clearAndEnter(name)
    app.alerts.buttons["Save"].tap()
    app.buttons["transportPlay"].tap()
    XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 10))
    sleep(3)
    app.buttons["transportPlay"].tap()
    app.tabBars.buttons["Chains"].tap()
    app.buttons["addPattern"].tap()
    app.buttons.containing(.staticText, identifier: name).firstMatch.tap()
    app.buttons["saveChain"].tap()
    app.alerts.textFields.firstMatch.clearAndEnter("UI Chain")
    app.alerts.buttons["Save"].tap()
    app.buttons["transportPlay"].tap()
    XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 10))
    app.buttons["transportPlay"].tap()
    app.terminate()
    app.launch()
    if app.buttons["Later"].waitForExistence(timeout: 2) { app.buttons["Later"].tap() }
    app.tabBars.buttons["Library"].tap()
    XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  @MainActor func testDetailsUndoRecordingAndLifecycle() throws {
    let app = XCUIApplication()
    app.launchEnvironment["PB_TEST_SESSION"] = UUID().uuidString
    app.launch()
    XCTAssertTrue(app.buttons["step-16"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      app.buttons["step-16"].isHittable, "All 16 steps should be visible at standard text size")
    let initial = XCTAttachment(screenshot: app.screenshot())
    initial.name = "Pattern — 16-step layout"
    initial.lifetime = .keepAlways
    add(initial)
    app.buttons["step-1"].tap()
    XCTAssertTrue(app.buttons["step-1"].label.contains("enabled"))
    app.buttons["undo"].tap()
    XCTAssertTrue(app.buttons["step-1"].label.contains("disabled"))
    app.buttons["step-1"].press(forDuration: 0.8)
    XCTAssertTrue(app.navigationBars["Step Details"].waitForExistence(timeout: 3))
    app.switches["Override Pitch"].tap()
    app.buttons["Done"].tap()
    app.buttons["Play Pads"].tap()
    XCTAssertTrue(app.buttons["pad-0"].waitForExistence(timeout: 3))
    app.buttons["Arm Record"].tap()
    app.buttons["transportPlay"].tap()
    XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 8))
    sleep(3)
    app.buttons["pad-0"].tap()
    app.buttons["pad-1"].tap()
    app.buttons["transportPlay"].tap()
    app.buttons["Steps"].tap()
    XCTAssertTrue(app.buttons["undo"].isEnabled)
    XCTAssertTrue((1...16).contains { app.buttons["step-\($0)"].label.contains(", enabled,") })
    app.buttons["transportPlay"].tap()
    XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 8))
    XCUIDevice.shared.press(.home)
    app.activate()
    XCTAssertTrue(
      app.buttons["Play"].waitForExistence(timeout: 5), "Foreground return must remain stopped")
  }
  @MainActor func testAccessibilitySizeKeepsTransportAndSaveReachable() throws {
    let app = XCUIApplication()
    app.launchEnvironment["PB_TEST_SESSION"] = UUID().uuidString
    app.launchArguments = [
      "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
    ]
    app.launch()
    XCTAssertTrue(app.buttons["transportPlay"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["transportPlay"].isHittable)
    XCTAssertTrue(app.buttons["savePattern"].isHittable)
    XCTAssertTrue(app.buttons["undo"].exists)
    XCTAssertTrue(app.buttons["instrumentSelector"].isHittable)
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Accessibility text size"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

}
extension XCUIElement {
  func clearAndEnter(_ value: String) {
    tap()
    let old = (self.value as? String) ?? ""
    typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
    typeText(value)
  }
}
