import Foundation
import HTTPTypes
import OpenAPIRuntime
import XCTest

@testable import KinoKit

final class AuthInterceptorTests: XCTestCase {
  func test_addsBearerTokenWhenPresent() async throws {
    let interceptor = AuthInterceptor(token: { "tok_xyz" })
    let observed = try await observedRequest(from: interceptor)

    XCTAssertEqual(observed.headerFields[.authorization], "Bearer tok_xyz")
  }

  func test_omitsAuthorizationWhenTokenIsMissing() async throws {
    let interceptor = AuthInterceptor(token: { nil })
    let observed = try await observedRequest(from: interceptor)

    XCTAssertNil(observed.headerFields[.authorization])
  }

  private func observedRequest(from interceptor: AuthInterceptor) async throws -> HTTPRequest {
    let request = HTTPRequest(method: .get, url: URL(string: "http://stub.local/test")!)
    let recorder = RequestRecorder()

    _ = try await interceptor.intercept(
      request,
      body: nil,
      baseURL: URL(string: "http://stub.local")!,
      operationID: "test"
    ) { request, _, _ in
      await recorder.record(request)
      return (
        HTTPResponse(status: .ok),
        nil
      )
    }

    let observed = await recorder.current
    return try XCTUnwrap(observed)
  }
}

private actor RequestRecorder {
  private var observed: HTTPRequest?

  var current: HTTPRequest? {
    observed
  }

  func record(_ request: HTTPRequest) {
    observed = request
  }
}
