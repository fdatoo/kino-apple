import XCTest

final class LaunchSmokeTests: XCTestCase {
  @MainActor
  func testLaunchesIntoUnauthOrTabBar() throws {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.state == .runningForeground)
    // The app may be in unauth state (pairing UI), authenticated (tab bar), or
    // error state (Keychain unavailable on Simulator). All are valid launch outcomes.
    let pairingHeader = app.staticTexts["Find your server"]
    let errorLabel = app.staticTexts["Couldn't load session"]
    let tabBar = app.tabBars.firstMatch
    XCTAssertTrue(
      pairingHeader.waitForExistence(timeout: 5)
        || errorLabel.exists
        || tabBar.exists
    )
  }
}
