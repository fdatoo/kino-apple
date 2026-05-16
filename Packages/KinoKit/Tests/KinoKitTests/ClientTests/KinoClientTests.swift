import Foundation
import XCTest

@testable import KinoKit

final class KinoClientTests: XCTestCase {
  override func tearDown() {
    StubURLProtocol.reset()
    super.tearDown()
  }

  func test_adminIsNilForNonAdminSession() {
    XCTAssertNil(testClient(isAdmin: false).admin)
  }

  func test_adminIsAvailableForAdminSession() {
    XCTAssertNotNil(testClient(isAdmin: true).admin)
  }

  func test_imagesUsesSessionTokenForInternalImages() async throws {
    let url = URL(string: "http://stub.local/api/v1/library/items/1/images/poster")!
    nonisolated(unsafe) var authorization: String?
    StubURLProtocol.push(
      when: { request in
        authorization = request.value(forHTTPHeaderField: "Authorization")
        return request.url == url
      },
      .init(status: 200, headers: [:], body: Data([0x01]))
    )

    let data = try await testClient().images.loadImage(url: url, isInternal: true)

    XCTAssertEqual(data, Data([0x01]))
    XCTAssertEqual(authorization, "Bearer tok_xyz")
  }
}
