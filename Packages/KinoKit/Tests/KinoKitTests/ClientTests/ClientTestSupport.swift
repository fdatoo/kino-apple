import Foundation
import XCTest

@testable import KinoKit

func testSession(isAdmin: Bool = false) -> AuthorizedSession {
  AuthorizedSession(
    serverInstanceID: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
    baseURL: URL(string: "http://stub.local")!,
    tokenID: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
    token: "tok_xyz",
    userID: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
    deviceName: "Test Device",
    createdAt: Date(timeIntervalSince1970: 1_800_000_000),
    isAdmin: isAdmin
  )
}

func testClient(isAdmin: Bool = false) -> KinoClient {
  KinoClient(
    session: testSession(isAdmin: isAdmin),
    transport: .mock(.stubbed, token: { "tok_xyz" })
  )
}

func json(_ string: String) -> Data {
  Data(string.utf8)
}

func queryValue(_ name: String, in request: URLRequest) -> String? {
  URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
    .queryItems?
    .first { $0.name == name }?
    .value
}

func requestBody(_ request: URLRequest) -> Data? {
  if let httpBody = request.httpBody {
    return httpBody
  }

  guard let stream = request.httpBodyStream else {
    return nil
  }

  stream.open()
  defer { stream.close() }

  var data = Data()
  let bufferSize = 1024
  let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
  defer { buffer.deallocate() }

  while stream.hasBytesAvailable {
    let count = stream.read(buffer, maxLength: bufferSize)
    if count < 0 {
      return nil
    }
    if count == 0 {
      break
    }
    data.append(buffer, count: count)
  }
  return data
}

func assertAuthorized(_ request: URLRequest, file: StaticString = #filePath, line: UInt = #line) {
  XCTAssertEqual(
    request.value(forHTTPHeaderField: "Authorization"),
    "Bearer tok_xyz",
    file: file,
    line: line
  )
}
