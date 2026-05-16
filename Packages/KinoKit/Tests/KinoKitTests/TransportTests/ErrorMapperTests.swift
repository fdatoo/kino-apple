import Foundation
import XCTest

@testable import KinoKit

final class ErrorMapperTests: XCTestCase {
  func test_401_mapsToUnauthorized() {
    let mapped = ErrorMapper.map(httpStatus: 401, body: nil)

    guard case .unauthorized = mapped else {
      return XCTFail("Expected unauthorized, got \(mapped)")
    }
  }

  func test_500WithErrorBody_mapsToServer() {
    let body = ErrorResponse(error: "boom")
    let mapped = ErrorMapper.map(httpStatus: 500, body: body)

    guard case .server(let status, let responseBody) = mapped else {
      return XCTFail("Expected server, got \(mapped)")
    }
    XCTAssertEqual(status, 500)
    XCTAssertEqual(responseBody?.error, "boom")
  }

  func test_urlErrorMapsToTransport() {
    let mapped = ErrorMapper.mapTransport(URLError(.timedOut))

    guard case .transport(let error) = mapped else {
      return XCTFail("Expected transport, got \(mapped)")
    }
    XCTAssertEqual(error.code, .timedOut)
  }
}
