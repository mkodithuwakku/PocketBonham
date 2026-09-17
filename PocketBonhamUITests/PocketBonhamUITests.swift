import XCTest

final class PocketBonhamUITests: XCTestCase {
  @MainActor func testOwnerKitNinePads() throws {
    let app = XCUIApplication()
    app.launchEnvironment["PB_TEST_SESSION"] = UUID().uuidString
    app.launch()
    XCTAssertTrue(app.buttons["Drum Kit 1"].waitForExistence(timeout: 10))
    app.buttons["Play Pads"].tap()
    XCTAssertTrue(app.buttons["pad-0"].waitForExistence(timeout: 5))
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
