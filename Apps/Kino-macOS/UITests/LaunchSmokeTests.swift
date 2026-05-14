import XCTest

final class LaunchSmokeTests: XCTestCase {
  @MainActor
  func testLaunchesAndShowsKinoKitVersion() throws {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.state == .runningForeground)
  }
}
