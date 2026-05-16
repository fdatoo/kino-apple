import Foundation
import XCTest

@testable import KinoKit

final class ImageLoaderTests: XCTestCase {
  override func tearDown() {
    StubURLProtocol.reset()
    super.tearDown()
  }

  func test_200ReturnsBytes() async throws {
    let url = URL(string: "http://stub.local/images/poster.jpg")!
    let bytes = Data([0x01, 0x02, 0x03])
    StubURLProtocol.push(
      when: { $0.url == url },
      .init(status: 200, headers: [:], body: bytes)
    )

    let loader = ImageLoader(session: .stubbed, token: { "tok_xyz" })
    let loaded = try await loader.loadImage(url: url, isInternal: true)

    XCTAssertEqual(loaded, bytes)
  }

  func test_internalURLAddsBearerToken() async throws {
    let url = URL(string: "http://stub.local/images/poster.jpg")!
    nonisolated(unsafe) var authorization: String?
    StubURLProtocol.push(
      when: { request in
        authorization = request.value(forHTTPHeaderField: "Authorization")
        return request.url == url
      },
      .init(status: 200, headers: [:], body: Data())
    )

    let loader = ImageLoader(session: .stubbed, token: { "tok_xyz" })
    _ = try await loader.loadImage(url: url, isInternal: true)

    XCTAssertEqual(authorization, "Bearer tok_xyz")
  }

  func test_externalURLDoesNotAddBearerToken() async throws {
    let url = URL(string: "https://image.tmdb.org/t/p/original/poster.jpg")!
    nonisolated(unsafe) var authorization: String?
    StubURLProtocol.push(
      when: { request in
        authorization = request.value(forHTTPHeaderField: "Authorization")
        return request.url == url
      },
      .init(status: 200, headers: [:], body: Data())
    )

    let loader = ImageLoader(session: .stubbed, token: { "tok_xyz" })
    _ = try await loader.loadImage(url: url, isInternal: false)

    XCTAssertNil(authorization)
  }

  func test_401ThrowsUnauthorized() async throws {
    let url = URL(string: "http://stub.local/images/poster.jpg")!
    StubURLProtocol.push(
      when: { $0.url == url },
      .init(status: 401, headers: [:], body: Data())
    )

    let loader = ImageLoader(session: .stubbed)

    do {
      _ = try await loader.loadImage(url: url, isInternal: true)
      XCTFail("Expected unauthorized")
    } catch KinoError.unauthorized {
    } catch {
      XCTFail("Expected unauthorized, got \(error)")
    }
  }
}
