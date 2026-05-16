import XCTest

@testable import KinoKit

final class ClientPlatformTests: XCTestCase {
  /// The wire form is lowercase to match the kino server's enum
  /// (`ios | tvos | macos`). Surfaced by manual probe acceptance: the default
  /// Swift-case raw values made `POST /api/v1/pairings` fail with HTTP 400.
  func test_rawValuesAreLowercase() {
    XCTAssertEqual(ClientPlatform.iOS.rawValue, "ios")
    XCTAssertEqual(ClientPlatform.tvOS.rawValue, "tvos")
    XCTAssertEqual(ClientPlatform.macOS.rawValue, "macos")
  }

  func test_encodesAsLowercaseString() throws {
    let data = try JSONEncoder().encode(ClientPlatform.macOS)
    XCTAssertEqual(String(data: data, encoding: .utf8), "\"macos\"")
  }

  func test_decodesFromLowercaseString() throws {
    let decoded = try JSONDecoder().decode(ClientPlatform.self, from: Data("\"tvos\"".utf8))
    XCTAssertEqual(decoded, .tvOS)
  }
}
