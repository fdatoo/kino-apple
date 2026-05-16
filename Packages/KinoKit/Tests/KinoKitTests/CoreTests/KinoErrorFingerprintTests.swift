import Foundation
import XCTest

@testable import KinoKit

final class KinoErrorFingerprintTests: XCTestCase {
  func test_fingerprints() {
    XCTAssertEqual(String(describing: KinoError.unauthorized), "unauthorized")
    XCTAssertTrue(
      String(describing: KinoError.transport(URLError(.timedOut))).hasPrefix("transport(")
    )
    XCTAssertTrue(
      String(describing: KinoError.server(status: 500, body: ErrorResponse(error: "failed")))
        .hasPrefix("server(status: 500, body:")
    )
    XCTAssertTrue(String(describing: KinoError.pairing(.expired)).hasPrefix("pairing("))
    XCTAssertTrue(String(describing: KinoError.playback(.noPlayablePlan)).hasPrefix("playback("))
    XCTAssertTrue(String(describing: KinoError.decoding(DecodingFailure())).hasPrefix("decoding("))
  }
}

private struct DecodingFailure: Error {}
