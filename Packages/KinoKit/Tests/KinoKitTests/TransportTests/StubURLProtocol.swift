import Foundation

final class StubURLProtocol: URLProtocol {
  struct Stub {
    let status: Int
    let headers: [String: String]
    let body: Data
  }

  static let lock = NSLock()
  nonisolated(unsafe) static var queue: [(matcher: (URLRequest) -> Bool, stub: Stub)] = []

  static func push(when matcher: @escaping (URLRequest) -> Bool, _ stub: Stub) {
    lock.lock()
    defer { lock.unlock() }
    queue.append((matcher, stub))
  }

  static func reset() {
    lock.lock()
    defer { lock.unlock() }
    queue.removeAll()
  }

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    let stub: Stub? = {
      Self.lock.lock()
      defer { Self.lock.unlock() }
      guard let index = Self.queue.firstIndex(where: { $0.matcher(self.request) }) else {
        return nil
      }
      return Self.queue.remove(at: index).stub
    }()

    guard let stub else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }

    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: stub.status,
      httpVersion: "HTTP/1.1",
      headerFields: stub.headers
    )!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: stub.body)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

extension URLSession {
  static var stubbed: URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: configuration)
  }
}
