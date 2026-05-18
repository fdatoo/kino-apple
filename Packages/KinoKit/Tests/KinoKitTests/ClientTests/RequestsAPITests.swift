import Foundation
import XCTest

@testable import KinoKit

final class RequestsAPITests: XCTestCase {
  override func tearDown() {
    StubURLProtocol.reset()
    super.tearDown()
  }

  func test_createMapsToCreateRequest() async throws {
    nonisolated(unsafe) var observed: URLRequest?
    StubURLProtocol.push(
      when: { request in
        observed = request
        return request.url?.path == "/api/v1/requests"
      },
      .init(status: 201, headers: ["Content-Type": "application/json"], body: requestDetailJSON)
    )

    let detail = try await testClient().requests.create(query: "Fight Club 1999")

    let request = try XCTUnwrap(observed)
    XCTAssertEqual(request.httpMethod, "POST")
    assertAuthorized(request)
    let body = try XCTUnwrap(requestBody(request))
    let object = try JSONSerialization.jsonObject(with: body) as? [String: String]
    XCTAssertEqual(object?["target"], "Fight Club 1999")
    XCTAssertEqual(detail.request.id, "00000000-0000-0000-0000-000000000501")
  }

  func test_listMapsToListRequests() async throws {
    nonisolated(unsafe) var observed: URLRequest?
    StubURLProtocol.push(
      when: { request in
        observed = request
        return request.url?.path == "/api/v1/requests"
      },
      .init(status: 200, headers: ["Content-Type": "application/json"], body: requestListJSON)
    )

    let requests = try await testClient().requests.list()

    let request = try XCTUnwrap(observed)
    XCTAssertEqual(request.httpMethod, "GET")
    assertAuthorized(request)
    XCTAssertEqual(requests.count, 1)
    XCTAssertEqual(requests.first?.target.rawQuery, "tmdb:movie:123")
  }

  func test_getRequestReturnsDetail() async throws {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000501")!
    nonisolated(unsafe) var observed: URLRequest?
    StubURLProtocol.push(
      when: { request in
        observed = request
        return request.url?.path == "/api/v1/requests/\(id.uuidString)"
      },
      .init(status: 200, headers: ["Content-Type": "application/json"], body: requestDetailJSON)
    )

    let detail = try await testClient().requests.get(id: id)

    let request = try XCTUnwrap(observed)
    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.url?.path, "/api/v1/requests/\(id.uuidString)")
    assertAuthorized(request)
    XCTAssertEqual(detail.request.id, "00000000-0000-0000-0000-000000000501")
  }

  func test_cancelRequestPostsCancel() async throws {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000501")!
    nonisolated(unsafe) var observed: URLRequest?
    StubURLProtocol.push(
      when: { request in
        observed = request
        return request.url?.path == "/api/v1/requests/\(id.uuidString)/cancel"
      },
      .init(
        status: 200, headers: ["Content-Type": "application/json"], body: requestDetailCancelledJSON
      )
    )

    let detail = try await testClient().requests.cancel(id: id)

    let request = try XCTUnwrap(observed)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.url?.path, "/api/v1/requests/\(id.uuidString)/cancel")
    assertAuthorized(request)
    XCTAssertEqual(detail.request.state, .cancelled)
  }
}

private let requestListJSON = json(
  """
  {
    "limit": 50,
    "offset": 0,
    "next_offset": null,
    "requests": [
      \(requestJSON)
    ]
  }
  """
)

private let requestDetailJSON = json(
  """
  {
    "request": \(requestJSON),
    "plan_history": [],
    "status_events": [],
    "identity_versions": [],
    "candidates": []
  }
  """
)

private let requestDetailCancelledJSON = json(
  """
  {
    "request": \(requestCancelledJSON),
    "plan_history": [],
    "status_events": [],
    "identity_versions": [],
    "candidates": []
  }
  """
)

private let requestJSON =
  """
  {
    "id": "00000000-0000-0000-0000-000000000501",
    "requester": "anonymous",
    "target": {
      "raw_query": "tmdb:movie:123"
    },
    "state": "pending",
    "created_at": "2026-05-16T00:00:00Z",
    "updated_at": "2026-05-16T00:00:00Z"
  }
  """

private let requestCancelledJSON =
  """
  {
    "id": "00000000-0000-0000-0000-000000000501",
    "requester": "anonymous",
    "target": {
      "raw_query": "tmdb:movie:123"
    },
    "state": "cancelled",
    "created_at": "2026-05-16T00:00:00Z",
    "updated_at": "2026-05-16T00:00:00Z"
  }
  """
