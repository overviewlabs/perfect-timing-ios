import XCTest

final class PerfectTimingUITests: XCTestCase {
  private func launch(onboarded: Bool = false) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [onboarded ? "-uiTestOnboarded" : "-uiTestFirstLaunch"]
    app.launch()
    return app
  }
  func testFirstLaunchAndOnboarding() {
    let app = launch()
    XCTAssertTrue(app.staticTexts["Perfect Timing"].waitForExistence(timeout: 5))
    if app.buttons["Skip"].exists { app.buttons["Skip"].tap() }
  }
  func testStartClassicTapEndAndRestart() {
    let app = launch(onboarded: true)
    XCTAssertTrue(app.buttons["play-button"].waitForExistence(timeout: 5))
    app.buttons["play-button"].tap()
    sleep(2)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    if app.buttons["End Run"].waitForExistence(timeout: 2) { app.buttons["End Run"].tap() }
    if app.buttons["PLAY AGAIN"].waitForExistence(timeout: 2) { app.buttons["PLAY AGAIN"].tap() }
  }
  func testShopInventorySettingsRestore() {
    let app = launch(onboarded: true)
    app.buttons["Shop"].tap()
    XCTAssertTrue(app.navigationBars["Shop"].exists)
    app.navigationBars.buttons.firstMatch.tap()
    app.buttons["Inventory"].tap()
    XCTAssertTrue(app.navigationBars["Inventory"].exists)
    app.navigationBars.buttons.firstMatch.tap()
    app.buttons["Settings"].tap()
    XCTAssertTrue(app.buttons["Restore Purchases"].exists)
  }
}
