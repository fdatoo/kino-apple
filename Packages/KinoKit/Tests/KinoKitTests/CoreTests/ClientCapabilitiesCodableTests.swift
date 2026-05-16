import XCTest

@testable import KinoKit

final class ClientCapabilitiesCodableTests: XCTestCase {
  func test_roundTrip() throws {
    let capabilities = ClientCapabilities(
      codecs: [.h264, .hevc, .av1],
      hdr: [.hdr10, .dolbyVision, .hlg],
      maxHeight: 2160,
      surroundAudio: true,
      atmos: true
    )

    let data = try JSONEncoder().encode(capabilities)
    let decoded = try JSONDecoder().decode(ClientCapabilities.self, from: data)

    XCTAssertEqual(decoded, capabilities)
  }
}
