import XCTest

@testable import KinoKit

final class PlaceholderTests: XCTestCase {
  func testPlaceholderTrue() {
    XCTAssertEqual(1, 1)
  }

  func testKinoKitVersionIsNotEmpty() {
    XCTAssertFalse(KinoKit.version.isEmpty)
  }
}
