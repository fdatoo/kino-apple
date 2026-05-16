import Foundation
import XCTest

@testable import KinoKit

final class PlaybackAPITests: XCTestCase {
  override func tearDown() {
    StubURLProtocol.reset()
    super.tearDown()
  }

  func test_reportProgressMapsToRecordProgress() async throws {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    nonisolated(unsafe) var observed: URLRequest?
    StubURLProtocol.push(
      when: { request in
        observed = request
        return request.url?.path == "/api/v1/playback/progress"
      },
      .init(status: 204, headers: [:], body: Data())
    )

    try await testClient().playback.reportProgress(itemID: id, seconds: 42.9)

    let request = try XCTUnwrap(observed)
    XCTAssertEqual(request.httpMethod, "POST")
    assertAuthorized(request)
    let body = try XCTUnwrap(requestBody(request))
    let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
    XCTAssertEqual(object?["media_item_id"] as? String, id.uuidString)
    XCTAssertEqual(object?["position_seconds"] as? Int, 42)
  }

  func test_markWatchedMapsToMarkWatched() async throws {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    nonisolated(unsafe) var observed: URLRequest?
    StubURLProtocol.push(
      when: { request in
        observed = request
        return request.url?.path == "/api/v1/playback/watched/\(id.uuidString)"
      },
      .init(status: 204, headers: [:], body: Data())
    )

    try await testClient().playback.markWatched(itemID: id)

    let request = try XCTUnwrap(observed)
    XCTAssertEqual(request.httpMethod, "POST")
    assertAuthorized(request)
  }

  func test_playbackAPIConformsToPlaybackReporting() async throws {
    let reporter: any PlaybackReporting = testClient().playback
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    StubURLProtocol.push(
      when: { $0.url?.path == "/api/v1/playback/watched/\(id.uuidString)" },
      .init(status: 204, headers: [:], body: Data())
    )

    try await reporter.markWatched(itemID: id)
  }
}
