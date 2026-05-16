import Foundation
import XCTest

@testable import KinoKit

final class AdminAPITests: XCTestCase {
  override func tearDown() {
    StubURLProtocol.reset()
    super.tearDown()
  }

  func test_listPendingPairingsMapsToListPairings() async throws {
    nonisolated(unsafe) var observed: URLRequest?
    StubURLProtocol.push(
      when: { request in
        observed = request
        return request.url?.path == "/api/v1/admin/pairings"
      },
      .init(status: 200, headers: ["Content-Type": "application/json"], body: pairingsJSON)
    )

    let pairings = try await testClient(isAdmin: true).admin?.listPendingPairings()

    let request = try XCTUnwrap(observed)
    XCTAssertEqual(request.httpMethod, "GET")
    assertAuthorized(request)
    XCTAssertEqual(pairings?.count, 1)
    XCTAssertEqual(pairings?.first?.deviceName, "Living Room")
  }

  func test_approveMapsToApprovePairing() async throws {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000601")!
    nonisolated(unsafe) var observed: URLRequest?
    StubURLProtocol.push(
      when: { request in
        observed = request
        return request.url?.path == "/api/v1/admin/pairings/\(id.uuidString)/approve"
      },
      .init(status: 200, headers: ["Content-Type": "application/json"], body: approveJSON)
    )

    let response = try await testClient(isAdmin: true).admin?.approve(pairingID: id)

    let request = try XCTUnwrap(observed)
    XCTAssertEqual(request.httpMethod, "POST")
    assertAuthorized(request)
    XCTAssertEqual(response?.pairingId, id.uuidString)
    XCTAssertEqual(response?.tokenPreview, "abc123")
  }

  func test_rejectMapsToRejectPairing() async throws {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000601")!
    nonisolated(unsafe) var observed: URLRequest?
    StubURLProtocol.push(
      when: { request in
        observed = request
        return request.url?.path == "/api/v1/admin/pairings/\(id.uuidString)/reject"
      },
      .init(status: 204, headers: [:], body: Data())
    )

    try await testClient(isAdmin: true).admin?.reject(pairingID: id)

    let request = try XCTUnwrap(observed)
    XCTAssertEqual(request.httpMethod, "POST")
    assertAuthorized(request)
  }
}

private let pairingsJSON = json(
  """
  {
    "pairings": [
      {
        "pairing_id": "00000000-0000-0000-0000-000000000601",
        "code": "123456",
        "device_name": "Living Room",
        "platform": "tvos",
        "created_at": "2026-05-16T00:00:00Z",
        "expires_at": "2026-05-16T00:05:00Z"
      }
    ]
  }
  """
)

private let approveJSON = json(
  """
  {
    "pairing_id": "00000000-0000-0000-0000-000000000601",
    "token_preview": "abc123"
  }
  """
)
