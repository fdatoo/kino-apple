import XCTest

@testable import KinoKit

final class ResolvedServerCodableTests: XCTestCase {
  func test_roundTrip() throws {
    let server = ResolvedServer(
      instanceID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
      host: "kino.local",
      port: 7000,
      apiVersion: "v1",
      serverVersion: "0.1.0"
    )

    let data = try JSONEncoder().encode(server)
    let decoded = try JSONDecoder().decode(ResolvedServer.self, from: data)

    XCTAssertEqual(decoded, server)
  }
}
