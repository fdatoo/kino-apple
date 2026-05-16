import XCTest

@testable import KinoKit

final class AuthorizedSessionCodableTests: XCTestCase {
  func test_roundTrip() throws {
    let session = AuthorizedSession(
      serverInstanceID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
      baseURL: URL(string: "http://kino.local:7000")!,
      tokenID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
      token: "tok_test_abc",
      userID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
      deviceName: "Living Room TV",
      createdAt: Date(timeIntervalSince1970: 1_700_000_000),
      isAdmin: true
    )

    let data = try JSONEncoder().encode(session)
    let decoded = try JSONDecoder().decode(AuthorizedSession.self, from: data)

    XCTAssertEqual(decoded, session)
  }

  func test_decodeDefaultsMissingIsAdminToFalse() throws {
    let json = """
      {
        "serverInstanceID": "00000000-0000-0000-0000-000000000001",
        "baseURL": "http:\\/\\/kino.local:7000",
        "tokenID": "00000000-0000-0000-0000-000000000002",
        "token": "tok_test_abc",
        "userID": "00000000-0000-0000-0000-000000000003",
        "deviceName": "Living Room TV",
        "createdAt": 1700000000
      }
      """

    let decoded = try JSONDecoder().decode(AuthorizedSession.self, from: Data(json.utf8))

    XCTAssertFalse(decoded.isAdmin)
  }
}
