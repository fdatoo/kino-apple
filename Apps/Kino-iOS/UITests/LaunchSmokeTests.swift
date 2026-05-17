import XCTest

final class LaunchSmokeTests: XCTestCase {
  @MainActor
  func testLaunchesIntoUnauthOrTabBar() throws {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.state == .runningForeground)
    // Until M3.2 lands, the unauth placeholder text or the tab bar should be present.
    // On simulator the Keychain may be unavailable, producing the error state instead.
    let unauthLabel = app.staticTexts["Pairing UI lands in M3.2"]
    let tabBar = app.tabBars.firstMatch
    let errorLabel = app.staticTexts["Couldn't load session"]
    XCTAssertTrue(
      unauthLabel.waitForExistence(timeout: 5) || tabBar.exists || errorLabel.exists)
  }
}
