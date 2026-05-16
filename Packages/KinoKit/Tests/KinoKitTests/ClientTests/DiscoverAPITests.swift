import Foundation
import XCTest

@testable import KinoKit

final class DiscoverAPITests: XCTestCase {
  override func tearDown() {
    StubURLProtocol.reset()
    super.tearDown()
  }

  func test_searchMapsToDiscover() async throws {
    nonisolated(unsafe) var observed: URLRequest?
    StubURLProtocol.push(
      when: { request in
        observed = request
        return request.url?.path == "/api/v1/discover"
      },
      .init(status: 200, headers: ["Content-Type": "application/json"], body: discoverJSON)
    )

    let response = try await testClient().discover.search(q: "arrival", kind: .movie, page: 2)

    let request = try XCTUnwrap(observed)
    XCTAssertEqual(request.httpMethod, "GET")
    assertAuthorized(request)
    XCTAssertEqual(queryValue("q", in: request), "arrival")
    XCTAssertEqual(queryValue("kind", in: request), "movie")
    XCTAssertEqual(queryValue("page", in: request), "2")
    XCTAssertEqual(response.candidates.count, 1)
    XCTAssertEqual(response.candidates.first?.tmdbId, 329_865)
  }
}

private let discoverJSON = json(
  """
  {
    "candidates": [
      {
        "tmdb_id": 329865,
        "kind": "movie",
        "title": "Arrival",
        "year": 2016,
        "overview": "A linguist works with the military.",
        "poster_url": "https://image.tmdb.org/t/p/original/poster.jpg",
        "backdrop_url": null,
        "popularity": 42.5
      }
    ],
    "page": 2,
    "has_more": true
  }
  """
)
