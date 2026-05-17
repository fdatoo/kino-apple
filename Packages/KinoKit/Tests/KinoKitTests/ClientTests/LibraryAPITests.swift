import Foundation
import XCTest

@testable import KinoKit

final class LibraryAPITests: XCTestCase {
  override func tearDown() {
    StubURLProtocol.reset()
    super.tearDown()
  }

  func test_listMapsToListCatalogItems() async throws {
    nonisolated(unsafe) var observed: URLRequest?
    StubURLProtocol.push(
      when: { request in
        observed = request
        return request.url?.path == "/api/v1/library/items"
      },
      .init(status: 200, headers: ["Content-Type": "application/json"], body: catalogListJSON)
    )

    let items = try await testClient().library.list(limit: 10, offset: 2, q: "arrival")

    let request = try XCTUnwrap(observed)
    XCTAssertEqual(request.httpMethod, "GET")
    assertAuthorized(request)
    XCTAssertEqual(queryValue("limit", in: request), "10")
    XCTAssertEqual(queryValue("offset", in: request), "2")
    XCTAssertEqual(queryValue("q", in: request), "arrival")
    XCTAssertEqual(items.count, 1)
    XCTAssertEqual(items.first?.title, "Arrival")
    XCTAssertEqual(items.first?.sourceFiles.count, 1)
    XCTAssertEqual(items.first?.transcodeOutputs.count, 1)
    XCTAssertEqual(items.first?.subtitleTracks.count, 1)
  }

  func test_listWithKindFiltersToKind() async throws {
    nonisolated(unsafe) var observed: URLRequest?
    StubURLProtocol.push(
      when: { request in
        observed = request
        return request.url?.path == "/api/v1/library/items"
      },
      .init(status: 200, headers: ["Content-Type": "application/json"], body: catalogListJSON)
    )

    let items = try await testClient().library.list(kind: "movie", limit: 1)

    let request = try XCTUnwrap(observed)
    XCTAssertEqual(request.httpMethod, "GET")
    assertAuthorized(request)
    XCTAssertEqual(queryValue("kind", in: request), "movie")
    XCTAssertEqual(queryValue("limit", in: request), "1")
    XCTAssertEqual(items.count, 1)
  }

  func test_listWithSortFiltersToSort() async throws {
    nonisolated(unsafe) var observed: URLRequest?
    StubURLProtocol.push(
      when: { request in
        observed = request
        return request.url?.path == "/api/v1/library/items"
      },
      .init(status: 200, headers: ["Content-Type": "application/json"], body: catalogListJSON)
    )

    let items = try await testClient().library.list(sort: "recently_added", limit: 1)

    let request = try XCTUnwrap(observed)
    XCTAssertEqual(request.httpMethod, "GET")
    assertAuthorized(request)
    XCTAssertEqual(queryValue("sort", in: request), "recently_added")
    XCTAssertEqual(queryValue("limit", in: request), "1")
    XCTAssertEqual(items.count, 1)
  }

  func test_getMapsToGetCatalogItem() async throws {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    nonisolated(unsafe) var observed: URLRequest?
    StubURLProtocol.push(
      when: { request in
        observed = request
        return request.url?.path == "/api/v1/library/items/\(id.uuidString)"
      },
      .init(status: 200, headers: ["Content-Type": "application/json"], body: catalogItemJSON)
    )

    let item = try await testClient().library.get(id: id)

    let request = try XCTUnwrap(observed)
    XCTAssertEqual(request.httpMethod, "GET")
    assertAuthorized(request)
    XCTAssertEqual(item.id, id)
    XCTAssertEqual(item.title, "Arrival")
  }
}

private let catalogListJSON = json(
  """
  {
    "items": [
      \(catalogItemJSONString)
    ],
    "next_cursor": null,
    "next_offset": null
  }
  """
)

private let catalogItemJSON = json(catalogItemJSONString)

private let catalogItemJSONString =
  """
  {
    "id": "00000000-0000-0000-0000-000000000101",
    "media_kind": "movie",
    "cast": [],
    "artwork": {},
    "variants": [
      {
        "variant_id": "00000000-0000-0000-0000-000000000201",
        "kind": "source",
        "capabilities": {
          "codec": "hevc",
          "container": "mp4",
          "hdr": "hdr10",
          "resolution": "2160p"
        },
        "stream_url": "/api/v1/stream/sourcefile/00000000-0000-0000-0000-000000000201/file.mp4"
      },
      {
        "variant_id": "00000000-0000-0000-0000-000000000301",
        "kind": "transcoded",
        "capabilities": {
          "codec": "h264",
          "container": "hls",
          "resolution": "1080p"
        },
        "stream_url": "/api/v1/stream/transcodes/00000000-0000-0000-0000-000000000301/master.m3u8"
      }
    ],
    "source_files": [],
    "subtitle_tracks": [
      {
        "id": "00000000-0000-0000-0000-000000000401",
        "track_index": 2,
        "label": "English",
        "language": "en",
        "forced": false,
        "format": "srt",
        "provenance": "text"
      }
    ],
    "title": "Arrival",
    "created_at": "2026-05-16T00:00:00Z",
    "updated_at": "2026-05-16T00:00:00Z"
  }
  """
